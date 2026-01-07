import 'dart:async';
import 'dart:convert';

import 'package:ell_tall_market/config/env.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Google Maps Web APIs wrapper (HTTP).
///
/// This file is intentionally backend-agnostic (Supabase is used elsewhere).
///
/// APIs used:
/// - Geocoding API (reverse geocoding) => formatted Arabic address components.
/// - Directions API (polyline) => route drawing.
/// - Distance Matrix API => real road distance + ETA.
/// - Roads API (Snap to Roads) => snap GPS points to road.
///
/// SECURITY NOTE:
/// For production, do NOT ship unrestricted keys. Use per-platform restrictions
/// in Google Cloud Console (Android SHA-1 + package, iOS bundle id, etc).
class GoogleMapsApiService {
  GoogleMapsApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _geocodeHost = 'maps.googleapis.com';
  static const _placesHost = 'maps.googleapis.com';
  static const int _maxDisplayParts = 4;

  String get _apiKey => Env.googleMapsApiKey;

  String _canonicalForDedup(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    // Remove Arabic tatweel.
    s = s.replaceAll('\u0640', '');

    // Strip common Arabic administrative prefixes.
    s = s
        .replaceFirst(RegExp(r'^\s*محافظة\s+'), '')
        .replaceFirst(RegExp(r'^\s*مركز\s+'), '')
        .replaceFirst(RegExp(r'^\s*مدينة\s+'), '')
        .replaceFirst(RegExp(r'^\s*قرية\s+'), '')
        .replaceFirst(RegExp(r'^\s*حي\s+'), '');

    // Normalize punctuation/spaces.
    s = s
        // Unify dash variants to spaces to dedup strings like "X - Y".
        .replaceAll(RegExp(r'[\-–—‑]+'), ' ')
        .replaceAll(RegExp(r'\s*(،|,)\s*'), ' ')
        .replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    return s;
  }

  void _debugLogAddressComponents(
    List<Map<String, dynamic>> components, {
    required String tag,
  }) {
    if (!kDebugMode) return;
    if (components.isEmpty) return;

    final lines = <String>[];
    for (final c in components) {
      final name = (c['long_name'] as String?)?.trim();
      final types = (c['types'] as List?)?.cast<String>();
      if (name == null || name.isEmpty) continue;
      lines.add('${types?.join('|') ?? ''}: $name');
    }

    if (lines.isEmpty) return;
    AppLogger.info('🧭 [$tag] address_components:\n${lines.join('\n')}');
  }

  /// Google Places Autocomplete (Arabic).
  ///
  /// NOTE: For best practice, use a session token per user selection flow.
  Future<List<PlaceAutocompletePrediction>> placesAutocompleteArabic({
    required String input,
    String? sessionToken,
    LatLng? locationBias,
  }) async {
    final trimmed = input.trim();
    if (trimmed.length < 3) return const [];

    final params = <String, String>{
      'input': trimmed,
      'key': _apiKey,
      'language': 'ar',
      'components': 'country:eg',
    };

    if (sessionToken != null && sessionToken.isNotEmpty) {
      params['sessiontoken'] = sessionToken;
    }

    // Optional bias to nearby results.
    if (locationBias != null) {
      params['location'] = '${locationBias.latitude},${locationBias.longitude}';
      params['radius'] = '50000'; // 50km bias (not a strict filter)
    }

    final uri = Uri.https(
      _placesHost,
      '/maps/api/place/autocomplete/json',
      params,
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      AppLogger.warning(
        'Places autocomplete HTTP ${res.statusCode}: ${res.body}',
      );
      return const [];
    }

    final jsonMap = json.decode(res.body) as Map<String, dynamic>;
    final status = jsonMap['status'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      AppLogger.warning('Places autocomplete status=$status body=${res.body}');
      return const [];
    }

    final predictions =
        (jsonMap['predictions'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];

    return predictions
        .map((p) {
          final placeId = (p['place_id'] as String?) ?? '';
          final description = (p['description'] as String?) ?? '';
          if (placeId.isEmpty || description.trim().isEmpty) return null;
          return PlaceAutocompletePrediction(
            placeId: placeId,
            description: description.trim(),
          );
        })
        .whereType<PlaceAutocompletePrediction>()
        .toList(growable: false);
  }

  /// Fetch place details and return coordinates + structured address.
  Future<PlaceDetailsResult?> placeDetailsArabic({
    required String placeId,
    String? sessionToken,
  }) async {
    final params = <String, String>{
      'place_id': placeId,
      'key': _apiKey,
      'language': 'ar',
      'fields': 'geometry,address_components,formatted_address',
    };
    if (sessionToken != null && sessionToken.isNotEmpty) {
      params['sessiontoken'] = sessionToken;
    }

    final uri = Uri.https(_placesHost, '/maps/api/place/details/json', params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      AppLogger.warning('Place details HTTP ${res.statusCode}: ${res.body}');
      return null;
    }

    final jsonMap = json.decode(res.body) as Map<String, dynamic>;
    final status = jsonMap['status'] as String?;
    if (status != 'OK') {
      AppLogger.warning('Place details status=$status body=${res.body}');
      return null;
    }

    final result = (jsonMap['result'] as Map?)?.cast<String, dynamic>();
    if (result == null) return null;

    final geometry = (result['geometry'] as Map?)?.cast<String, dynamic>();
    final location = (geometry?['location'] as Map?)?.cast<String, dynamic>();
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final formattedRaw = (result['formatted_address'] as String?) ?? '';
    final formatted = _stripLeadingPlusCode(formattedRaw);
    final components =
        (result['address_components'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];

    _debugLogAddressComponents(components, tag: 'PlaceDetails');

    final parsed = _parseAddressComponents(components);

    final street = _cleanAndValidate(parsed.street);
    final neighborhood = _cleanAndValidate(parsed.neighborhood);
    final city = _cleanAndValidate(parsed.city);
    final governorate = _cleanAndValidate(parsed.governorate);
    final country = _cleanAndValidate(parsed.country);

    final parts = <String>[];
    void addDedup(String? v) {
      if (v == null) return;
      final cv = _canonicalForDedup(v);
      if (cv.isEmpty) return;
      if (parts.any((p) => _canonicalForDedup(p) == cv)) return;
      parts.add(v);
    }

    addDedup(street);
    addDedup(neighborhood);
    if (city != null &&
        _canonicalForDedup(city) != _canonicalForDedup(governorate ?? '')) {
      addDedup(city);
    }
    addDedup(governorate);
    addDedup(country);

    final displayParts = parts.take(_maxDisplayParts).toList(growable: false);

    String display;
    if (displayParts.isEmpty) {
      display = _cleanAndValidate(formatted) ?? 'موقع محدد';
    } else if (street == null && (city != null || governorate != null)) {
      display = 'موقع في ${displayParts.join('، ')}';
    } else {
      display = displayParts.join('، ');
    }

    return PlaceDetailsResult(
      position: LatLng(lat, lng),
      address: ReverseGeocodeResult(
        displayAddress: display,
        formattedAddress: _cleanAndValidate(formatted),
        street: street,
        neighborhood: neighborhood,
        city: city,
        governorate: governorate,
        country: country,
      ),
    );
  }

  /// Reverse geocode using Google Geocoding API.
  ///
  /// - Uses `language=ar` to prefer Arabic names.
  /// - Avoids returning Plus Codes.
  /// - Builds a deduplicated Arabic address string: street, neighborhood, city, governorate.
  Future<ReverseGeocodeResult?> reverseGeocodeArabic(LatLng position) async {
    final uri = Uri.https(_geocodeHost, '/maps/api/geocode/json', {
      'latlng': '${position.latitude},${position.longitude}',
      'key': _apiKey,
      'language': 'ar',
      // Asking for rooftop sometimes improves quality, but we keep default.
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      AppLogger.warning('Geocode HTTP ${res.statusCode}: ${res.body}');
      return null;
    }

    final jsonMap = json.decode(res.body) as Map<String, dynamic>;
    final status = jsonMap['status'] as String?;
    if (status != 'OK') {
      AppLogger.warning('Geocode status=$status body=${res.body}');
      return null;
    }

    final results =
        (jsonMap['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (results.isEmpty) return null;

    // Prefer results that are not plus_code-only.
    Map<String, dynamic>? best = results.first;

    // If the first result is a plus_code or contains a plus code, try another.
    for (final r in results) {
      final formatted = (r['formatted_address'] as String?) ?? '';
      if (!_looksLikePlusCodePrefix(formatted)) {
        best = r;
        break;
      }
    }

    final formattedRaw = (best?['formatted_address'] as String?) ?? '';
    final formatted = _stripLeadingPlusCode(formattedRaw);
    final components =
        (best?['address_components'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];

    _debugLogAddressComponents(components, tag: 'ReverseGeocode');

    final parsed = _parseAddressComponents(components);

    final street = _cleanAndValidate(parsed.street);
    final neighborhood = _cleanAndValidate(parsed.neighborhood);
    final city = _cleanAndValidate(parsed.city);
    final governorate = _cleanAndValidate(parsed.governorate);
    final country = _cleanAndValidate(parsed.country);

    final parts = <String>[];
    void addDedup(String? v) {
      if (v == null) return;
      final cv = _canonicalForDedup(v);
      if (cv.isEmpty) return;
      if (parts.any((p) => _canonicalForDedup(p) == cv)) return;
      parts.add(v);
    }

    // Build the best human address.
    addDedup(street);
    addDedup(neighborhood);

    // Avoid city==governorate duplicates.
    if (city != null &&
        _canonicalForDedup(city) != _canonicalForDedup(governorate ?? '')) {
      addDedup(city);
    }
    addDedup(governorate);
    addDedup(country);

    final displayParts = parts.take(_maxDisplayParts).toList(growable: false);

    String display;
    if (displayParts.isEmpty) {
      display = _cleanAndValidate(formatted) ?? 'موقع محدد';
    } else if (street == null && (city != null || governorate != null)) {
      display = 'موقع في ${displayParts.join('، ')}';
    } else {
      display = displayParts.join('، ');
    }

    return ReverseGeocodeResult(
      displayAddress: display,
      street: street,
      neighborhood: neighborhood,
      city: city,
      governorate: governorate,
      country: country,
      formattedAddress: _cleanAndValidate(formatted),
    );
  }

  bool _looksLikePlusCodePrefix(String input) {
    return _stripLeadingPlusCode(input).trim() != input.trim();
  }

  String _stripLeadingPlusCode(String input) {
    final s = input.trim();
    // Common google plus code shapes: HQ5J+JV8 ...
    return s.replaceFirst(
      RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}\s*(?:,|،)?\s*'),
      '',
    );
  }

  /// Clean and validate to avoid plus codes and garbage labels.
  String? _cleanAndValidate(String? text) {
    if (text == null) return null;
    var cleaned = _stripLeadingPlusCode(text).trim();
    if (cleaned.isEmpty) return null;

    // Reject Plus Codes.
    if (RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}$').hasMatch(cleaned)) return null;

    // Remove postal codes (often noisy in Arabic formatted addresses).
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?<![0-9\u0660-\u0669])[0-9\u0660-\u0669]{5,7}(?![0-9\u0660-\u0669])',
      ),
      '',
    );

    // Normalize separators.
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*(،|,)\s*'), '، ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'(،\s*){2,}'), '، ')
        .trim();

    // Reject only symbols.
    if (RegExp(r'^[^\u0600-\u06FFa-zA-Z\s]+$').hasMatch(cleaned)) return null;

    // Reject digits-only.
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return null;

    // Reject very short.
    if (cleaned.length < 2) return null;

    final lower = cleaned.toLowerCase();
    if (lower == 'unnamed road' ||
        lower == 'unnamed' ||
        cleaned == 'طريق بدون اسم') {
      return null;
    }

    return cleaned;
  }

  _ParsedAddress _parseAddressComponents(
    List<Map<String, dynamic>> components,
  ) {
    String? findByType(String type) {
      for (final c in components) {
        final types = (c['types'] as List?)?.cast<String>() ?? const [];
        if (types.contains(type)) return c['long_name'] as String?;
      }
      return null;
    }

    // Street components.
    // NOTE: We intentionally prefer a street name only (route) without numbers.
    // Building/apartment are captured separately in the UI.
    final route = findByType('route');

    // Place name (useful when route is missing).
    final place =
        findByType('point_of_interest') ??
        findByType('establishment') ??
        findByType('premise');

    final locality = findByType('locality');

    // City/Center ("المركز"): in Egypt this is very often admin_area_level_2.
    final city = findByType('administrative_area_level_2') ?? locality;

    // Neighborhood / district / village ("القرية / الحي").
    // Prefer sublocality/neighborhood (more granular), then admin 3/4.
    // As a last resort, fall back to locality (when it's not the same as city/center).
    final neighborhoodRaw =
        findByType('sublocality_level_2') ??
        findByType('sublocality_level_1') ??
        findByType('sublocality') ??
        findByType('neighborhood') ??
        findByType('administrative_area_level_4') ??
        findByType('administrative_area_level_3') ??
        locality;

    // Governorate: admin_area_level_1.
    final governorate = findByType('administrative_area_level_1');

    // Country.
    final country = findByType('country');

    // Street name only.
    String? street = route ?? place;

    // Avoid duplicates like neighborhood == street/city/governorate.
    String? neighborhood = neighborhoodRaw;
    if (neighborhood != null) {
      final n = _canonicalForDedup(neighborhood);
      final st = _canonicalForDedup(street ?? '');
      final ct = _canonicalForDedup(city ?? '');
      final gv = _canonicalForDedup(governorate ?? '');

      if (n.isEmpty || n == st || n == ct || n == gv) {
        neighborhood = null;
      }
    }

    return _ParsedAddress(
      street: street,
      neighborhood: neighborhood,
      city: city,
      governorate: governorate,
      country: country,
    );
  }

  void dispose() {
    _client.close();
  }
}

class PlaceAutocompletePrediction {
  final String placeId;
  final String description;

  const PlaceAutocompletePrediction({
    required this.placeId,
    required this.description,
  });
}

class PlaceDetailsResult {
  final LatLng position;
  final ReverseGeocodeResult address;

  const PlaceDetailsResult({required this.position, required this.address});
}

class ReverseGeocodeResult {
  final String displayAddress;
  final String? formattedAddress;
  final String? street;
  final String? neighborhood;
  final String? city;
  final String? governorate;
  final String? country;

  const ReverseGeocodeResult({
    required this.displayAddress,
    this.formattedAddress,
    this.street,
    this.neighborhood,
    this.city,
    this.governorate,
    this.country,
  });
}

class _ParsedAddress {
  final String? street;
  final String? neighborhood;
  final String? city;
  final String? governorate;
  final String? country;

  const _ParsedAddress({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.governorate,
    required this.country,
  });
}
