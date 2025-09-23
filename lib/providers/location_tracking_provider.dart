import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationTrackingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _trackingChannel;
  final Map<String, Position> _captainsLocations = {};
  final Map<String, StreamSubscription<Position>> _locationSubscriptions = {};
  bool _isTracking = false;

  Map<String, Position> get captainsLocations => _captainsLocations;
  bool get isTracking => _isTracking;

  // ===== بدء تتبع موقع الكابتن =====
  Future<void> startTracking(String captainId) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // بالأمتار
      );

      _locationSubscriptions[captainId] =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) async {
            await _updateCaptainLocation(captainId, position);
          });

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error starting location tracking: $e');
      rethrow;
    }
  }

  // ===== إيقاف تتبع موقع الكابتن =====
  Future<void> stopTracking(String captainId) async {
    try {
      await _locationSubscriptions[captainId]?.cancel();
      _locationSubscriptions.remove(captainId);
      _captainsLocations.remove(captainId);

      _isTracking = _locationSubscriptions.isNotEmpty;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error stopping location tracking: $e');
      rethrow;
    }
  }

  // ===== تحديث موقع الكابتن =====
  Future<void> _updateCaptainLocation(
    String captainId,
    Position position,
  ) async {
    try {
      await _supabase.from('captain_locations').upsert({
        'captain_id': captainId,
        'lat': position.latitude,
        'lng': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _captainsLocations[captainId] = position;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error updating captain location: $e');
    }
  }

  // ===== الاشتراك في تحديثات مواقع الكباتن =====
  void subscribeToLocationUpdates(List<String> captainIds) {
    _trackingChannel =
        _supabase
            .channel('captain_locations')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'captain_locations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'captain_id',
                value: captainIds.join(','),
              ),
              callback: (payload) {
                final lat = payload.newRecord['lat'] as double;
                final lng = payload.newRecord['lng'] as double;
                final captainId = payload.newRecord['captain_id'] as String;

                _captainsLocations[captainId] = Position(
                  latitude: lat,
                  longitude: lng,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );
                notifyListeners();
              },
            )
          ..subscribe();
  }

  // ===== إلغاء الاشتراك في تحديثات المواقع =====
  void unsubscribeFromLocationUpdates() {
    _trackingChannel?.unsubscribe();
    _captainsLocations.clear();
    notifyListeners();
  }

  // ===== جلب موقع كابتن =====
  Future<Position?> getCaptainLocation(String captainId) async {
    try {
      final response = await _supabase
          .from('captain_locations')
          .select()
          .eq('captain_id', captainId)
          .single();

      return Position(
        latitude: response['lat'],
        longitude: response['lng'],
        timestamp: DateTime.parse(response['updated_at']),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching captain location: $e');
      return null;
    }
  }

  // ===== حساب المسافة بين نقطتين =====
  double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  @override
  void dispose() {
    for (var subscription in _locationSubscriptions.values) {
      subscription.cancel();
    }
    _locationSubscriptions.clear();
    _trackingChannel?.unsubscribe();
    super.dispose();
  }
}
