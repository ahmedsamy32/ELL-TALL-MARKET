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

  // Places Web Service calls may be denied due to API key restrictions.
  // Cache denial so we don't keep retrying and slowing down UX.
  bool _placesNearbyDenied = false;

  // كاش لنتائج reverse geocode — يوفر طلبات API المتكررة
  // المفتاح: إحداثيات مقربة لـ 4 خانات عشرية (~11 متر دقة)
  static const int _maxCacheSize = 100;
  final Map<String, ReverseGeocodeResult> _geocodeCache = {};
  final List<String> _cacheKeys = []; // LRU order

  String _cacheKey(double lat, double lng, String lang) {
    // تقريب لـ 4 خانات عشرية (~11م دقة)
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}_$lang';
  }

  void _putCache(String key, ReverseGeocodeResult result) {
    if (_geocodeCache.containsKey(key)) {
      _cacheKeys.remove(key);
    } else if (_cacheKeys.length >= _maxCacheSize) {
      final oldest = _cacheKeys.removeAt(0);
      _geocodeCache.remove(oldest);
    }
    _cacheKeys.add(key);
    _geocodeCache[key] = result;
  }

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
    final landmark = _cleanAndValidate(parsed.landmark);
    final neighborhood = _cleanAndValidate(parsed.neighborhood);
    final city = _cleanAndValidate(parsed.city);
    final governorate = _cleanAndValidate(parsed.governorate);
    final country = _cleanAndValidate(parsed.country);

    final parts = <String>[];
    void addDedup(String? v) {
      if (v == null) return;
      final cv = _canonicalForDedup(v);
      if (cv.isEmpty) return;
      // تحقق من التطابق الكامل أو الجزئي
      for (final p in parts) {
        final cp = _canonicalForDedup(p);
        if (cp == cv || cp.contains(cv) || cv.contains(cp)) return;
      }
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
        landmark: landmark,
        neighborhood: neighborhood,
        city: city,
        governorate: governorate,
        country: country,
      ),
    );
  }

  /// Reverse geocode using Google Geocoding API (localized).
  ///
  /// - Uses `language` to prefer localized names.
  /// - Avoids returning Plus Codes.
  /// - Builds a deduplicated address string: street, neighborhood, city, governorate.
  Future<ReverseGeocodeResult?> _reverseGeocode(
    LatLng position, {
    required String language,
  }) async {
    // فحص الكاش أولاً
    final key = _cacheKey(position.latitude, position.longitude, language);
    if (_geocodeCache.containsKey(key)) {
      return _geocodeCache[key];
    }

    final uri = Uri.https(_geocodeHost, '/maps/api/geocode/json', {
      'latlng': '${position.latitude},${position.longitude}',
      'key': _apiKey,
      'language': language,
      // Asking for rooftop sometimes improves quality, but we keep default.
    });

    http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Network failures or key restrictions shouldn't break the UI; callers can fall back.
      AppLogger.warning('Geocode request failed: $e');
      return null;
    }

    if (res.statusCode != 200) {
      AppLogger.warning('Geocode HTTP ${res.statusCode}: ${res.body}');
      return null;
    }

    Map<String, dynamic> jsonMap;
    try {
      jsonMap = json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning('Geocode JSON decode failed: $e');
      return null;
    }
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
    final landmark = _cleanAndValidate(parsed.landmark);
    final neighborhood = _cleanAndValidate(parsed.neighborhood);
    final city = _cleanAndValidate(parsed.city);
    final governorate = _cleanAndValidate(parsed.governorate);
    final country = _cleanAndValidate(parsed.country);

    final parts = <String>[];
    void addDedup(String? v) {
      if (v == null) return;
      final cv = _canonicalForDedup(v);
      if (cv.isEmpty) return;
      // تحقق من التطابق الكامل أو الجزئي
      for (final p in parts) {
        final cp = _canonicalForDedup(p);
        if (cp == cv || cp.contains(cv) || cv.contains(cp)) return;
      }
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

    final result = ReverseGeocodeResult(
      displayAddress: display,
      street: street,
      landmark: landmark,
      neighborhood: neighborhood,
      city: city,
      governorate: governorate,
      country: country,
      formattedAddress: _cleanAndValidate(formatted),
    );

    // حفظ في الكاش
    _putCache(key, result);

    return result;
  }

  /// Reverse geocode using Google Geocoding API (Arabic).
  Future<ReverseGeocodeResult?> reverseGeocodeArabic(LatLng position) async {
    return _reverseGeocode(position, language: 'ar');
  }

  /// Reverse geocode using Google Geocoding API (English).
  Future<ReverseGeocodeResult?> reverseGeocodeEnglish(LatLng position) async {
    return _reverseGeocode(position, language: 'en');
  }

  /// Get a nearby landmark name using Google Places Nearby Search.
  ///
  /// This is best-effort: if Places API isn't enabled/restricted, returns null.
  Future<String?> nearbyLandmarkArabic({
    required LatLng position,
    int timeoutSeconds = 8,
  }) async {
    if (_placesNearbyDenied) return null;

    final uri = Uri.https(_placesHost, '/maps/api/place/nearbysearch/json', {
      'location': '${position.latitude},${position.longitude}',
      // Rank by distance gives the closest result. (Cannot use radius with rankby=distance)
      'rankby': 'distance',
      'type': 'point_of_interest',
      'language': 'ar',
      'key': _apiKey,
    });

    http.Response res;
    try {
      res = await _client.get(uri).timeout(Duration(seconds: timeoutSeconds));
    } catch (e) {
      AppLogger.warning('Places nearby request failed: $e');
      return null;
    }

    if (res.statusCode != 200) {
      AppLogger.warning('Places nearby HTTP ${res.statusCode}: ${res.body}');
      return null;
    }

    Map<String, dynamic> jsonMap;
    try {
      jsonMap = json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning('Places nearby JSON decode failed: $e');
      return null;
    }

    final status = jsonMap['status'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      if (status == 'REQUEST_DENIED') {
        _placesNearbyDenied = true;
        AppLogger.warning(
          'Places nearby REQUEST_DENIED (will skip further Places calls). '
          'Check Google Cloud: enable Places API + adjust key restrictions. '
          'body=${res.body}',
        );
      } else {
        AppLogger.warning('Places nearby status=$status body=${res.body}');
      }
      return null;
    }

    final results =
        (jsonMap['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (results.isEmpty) return null;

    final name = (results.first['name'] as String?)?.trim();
    return _cleanAndValidate(name);
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

    // A nearby point-of-interest name (landmark) when available.
    final landmark = place;

    // ═══════════════════════════════════════════════════════════════════════
    // Google Geocoding API components mapping for Egypt:
    // وفقاً لتوثيق pub.dev/packages/geocoding:
    // - administrativeArea (admin_level_1) = المحافظة (Governorate)
    // - subAdministrativeArea (admin_level_2) = المركز (Center/District)
    // - locality = المدينة (City) - في مصر غالباً نفس المركز
    // - subLocality = القرية/الحي (Village/Neighborhood)
    // ═══════════════════════════════════════════════════════════════════════
    final adminLevel1 = findByType('administrative_area_level_1'); // المحافظة
    final adminLevel2 = findByType('administrative_area_level_2'); // المركز
    final adminLevel3 = findByType('administrative_area_level_3');
    final adminLevel4 = findByType('administrative_area_level_4');
    final locality = findByType('locality');
    final sublocality =
        findByType('sublocality_level_2') ??
        findByType('sublocality_level_1') ??
        findByType('sublocality');
    final neighborhoodType = findByType('neighborhood');

    // ═══════════════════════════════════════════════════════════════════════
    // 🏛️ المركز (City/Center):
    // في مصر: admin_level_2 هو المركز (مثل "مركز الطود")
    // إذا لم يوجد، نستخدم locality
    // ═══════════════════════════════════════════════════════════════════════
    String? city = adminLevel2 ?? locality;

    // ═══════════════════════════════════════════════════════════════════════
    // 🏘️ القرية/الحي (Village/Neighborhood):
    // في مصر: sublocality أو admin_level_3/4 هي القرية
    // الأولوية: sublocality > admin_level_4 > admin_level_3 > neighborhood
    // نتجنب استخدام locality إذا تم استخدامه كمركز
    // ═══════════════════════════════════════════════════════════════════════
    String? neighborhoodRaw;

    // 1. أولاً: sublocality (الأدق للقرى والأحياء في مصر)
    if (sublocality != null) {
      neighborhoodRaw = sublocality;
    }
    // 2. ثانياً: admin_level_4 (القرى الصغيرة)
    else if (adminLevel4 != null) {
      neighborhoodRaw = adminLevel4;
    }
    // 3. ثالثاً: admin_level_3
    else if (adminLevel3 != null) {
      neighborhoodRaw = adminLevel3;
    }
    // 4. رابعاً: neighborhood type
    else if (neighborhoodType != null) {
      neighborhoodRaw = neighborhoodType;
    }
    // 5. locality فقط إذا لم يُستخدم كمركز وكان admin_level_2 موجوداً
    else if (locality != null && adminLevel2 != null) {
      final locCanon = _canonicalForDedup(locality);
      final cityCanon = _canonicalForDedup(adminLevel2);
      if (locCanon != cityCanon &&
          !locCanon.contains(cityCanon) &&
          !cityCanon.contains(locCanon)) {
        neighborhoodRaw = locality;
      }
    }

    // Governorate: admin_area_level_1.
    final governorate = adminLevel1;

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

      // إزالة neighborhood إذا كان مكرراً أو جزءاً من حقل آخر
      if (n.isEmpty ||
          n == st ||
          n == ct ||
          n == gv ||
          st.contains(n) ||
          n.contains(st) ||
          ct.contains(n) ||
          n.contains(ct)) {
        neighborhood = null;
      }
    }

    // إزالة street إذا كان مكرراً مع city
    if (street != null && city != null) {
      final st = _canonicalForDedup(street);
      final ct = _canonicalForDedup(city);
      if (st == ct || st.contains(ct) || ct.contains(st)) {
        street = null;
      }
    }

    // Debug logging للتحقق من القيم
    if (kDebugMode) {
      AppLogger.info('🔍 _parseAddressComponents:');
      AppLogger.info('   - adminLevel1 (المحافظة): $adminLevel1');
      AppLogger.info('   - adminLevel2 (المركز): $adminLevel2');
      AppLogger.info('   - adminLevel3 (قرية): $adminLevel3');
      AppLogger.info('   - adminLevel4 (قرية): $adminLevel4');
      AppLogger.info('   - locality: $locality');
      AppLogger.info('   - sublocality: $sublocality');
      AppLogger.info('   - ═══════════════════════════════');
      AppLogger.info('   - city (المركز - final): $city');
      AppLogger.info('   - neighborhood (القرية - final): $neighborhood');
      AppLogger.info('   - governorate (المحافظة - final): $governorate');
    }

    return _ParsedAddress(
      street: street,
      landmark: landmark,
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
  final String? landmark;
  final String? neighborhood;
  final String? city;
  final String? governorate;
  final String? country;

  const ReverseGeocodeResult({
    required this.displayAddress,
    this.formattedAddress,
    this.street,
    this.landmark,
    this.neighborhood,
    this.city,
    this.governorate,
    this.country,
  });
}

class _ParsedAddress {
  final String? street;
  final String? landmark;
  final String? neighborhood;
  final String? city;
  final String? governorate;
  final String? country;

  const _ParsedAddress({
    required this.street,
    required this.landmark,
    required this.neighborhood,
    required this.city,
    required this.governorate,
    required this.country,
  });
}
