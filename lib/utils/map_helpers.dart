import 'dart:math' show sqrt, asin, pi;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// 🛠️ Map Helper Functions
///
/// مجموعة من الدوال المساعدة للعمل مع الخرائط
/// مبنية على أفضل الممارسات من:
/// - Flutter Gems
/// - Google Maps Flutter Best Practices
/// - Awesome Flutter

class MapHelpers {
  MapHelpers._(); // Private constructor to prevent instantiation

  // ============================================================================
  // 📏 حسابات المسافة
  // ============================================================================

  /// حساب المسافة بين نقطتين باستخدام Haversine Formula
  ///
  /// Returns: المسافة بالكيلومتر
  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        ) /
        1000; // تحويل من متر إلى كيلومتر
  }

  /// حساب المسافة باستخدام Haversine Formula (يدوي)
  ///
  /// مفيد عند عدم توفر geolocator
  static double calculateDistanceManual(LatLng from, LatLng to) {
    const double earthRadius = 6371.0; // كم

    final double lat1Rad = _toRadians(from.latitude);
    final double lat2Rad = _toRadians(to.latitude);
    final double dLat = _toRadians(to.latitude - from.latitude);
    final double dLon = _toRadians(to.longitude - from.longitude);

    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2));

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * (pi / 180);
  static double sin(double x) =>
      (x - (x * x * x) / 6 + (x * x * x * x * x) / 120);
  static double cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;

  // ============================================================================
  // 💰 حسابات التكلفة
  // ============================================================================

  /// حساب تكلفة التوصيل بناءً على المسافة
  static double calculateDeliveryFee({
    required double distanceInKm,
    double basePrice = 10.0,
    double pricePerKm = 5.0,
    double freeDeliveryRadius = 5.0,
  }) {
    if (distanceInKm <= freeDeliveryRadius) {
      return basePrice;
    }
    return basePrice + ((distanceInKm - freeDeliveryRadius) * pricePerKm);
  }

  /// حساب تكلفة مع نطاقات مختلفة
  static double calculateTieredDeliveryFee(double distanceInKm) {
    if (distanceInKm <= 3) return 10.0;
    if (distanceInKm <= 5) return 15.0;
    if (distanceInKm <= 10) return 25.0;
    if (distanceInKm <= 15) return 35.0;
    return 50.0;
  }

  // ============================================================================
  // ⏱️ حسابات الوقت
  // ============================================================================

  /// تقدير الوقت المطلوب للوصول
  ///
  /// Returns: الوقت بالدقائق
  static double estimateDeliveryTime({
    required double distanceInKm,
    double averageSpeedKmh = 40.0, // سرعة متوسطة في المدن
  }) {
    return (distanceInKm / averageSpeedKmh) * 60; // تحويل لدقائق
  }

  /// تقدير الوقت مع مراعاة حركة المرور
  static double estimateTimeWithTraffic({
    required double distanceInKm,
    required TrafficLevel trafficLevel,
  }) {
    double baseSpeed = 40.0;

    switch (trafficLevel) {
      case TrafficLevel.low:
        baseSpeed = 50.0;
        break;
      case TrafficLevel.moderate:
        baseSpeed = 35.0;
        break;
      case TrafficLevel.high:
        baseSpeed = 20.0;
        break;
      case TrafficLevel.severe:
        baseSpeed = 10.0;
        break;
    }

    return (distanceInKm / baseSpeed) * 60;
  }

  /// تنسيق الوقت لعرضه للمستخدم
  static String formatDeliveryTime(double minutes) {
    if (minutes < 1) return 'أقل من دقيقة';
    if (minutes < 60) return '${minutes.toInt()} دقيقة';

    final hours = minutes ~/ 60;
    final remainingMinutes = (minutes % 60).toInt();

    if (remainingMinutes == 0) {
      return '$hours ساعة';
    }
    return '$hours ساعة و $remainingMinutes دقيقة';
  }

  // ============================================================================
  // 🎯 التحقق من النطاق
  // ============================================================================

  /// التحقق من أن الموقع ضمن نطاق التوصيل
  static bool isWithinDeliveryRange({
    required LatLng storeLocation,
    required LatLng customerLocation,
    required double maxRadiusKm,
  }) {
    final distance = calculateDistance(storeLocation, customerLocation);
    return distance <= maxRadiusKm;
  }

  /// الحصول على أقرب متجر للعميل
  static LatLng? getNearestStore({
    required LatLng customerLocation,
    required List<LatLng> storeLocations,
    double? maxRadiusKm,
  }) {
    if (storeLocations.isEmpty) return null;

    LatLng? nearestStore;
    double minDistance = double.infinity;

    for (final store in storeLocations) {
      final distance = calculateDistance(customerLocation, store);

      if (distance < minDistance) {
        if (maxRadiusKm == null || distance <= maxRadiusKm) {
          minDistance = distance;
          nearestStore = store;
        }
      }
    }

    return nearestStore;
  }

  // ============================================================================
  // 📍 تحويل الإحداثيات
  // ============================================================================

  /// تحويل LatLng إلى Map
  static Map<String, double> latLngToMap(LatLng position) {
    return {'latitude': position.latitude, 'longitude': position.longitude};
  }

  /// تحويل Map إلى LatLng
  static LatLng mapToLatLng(Map<String, dynamic> map) {
    return LatLng(map['latitude'] as double, map['longitude'] as double);
  }

  /// تحويل `List<LatLng>` إلى `List<Map>`
  static List<Map<String, double>> latLngListToMapList(List<LatLng> positions) {
    return positions.map((pos) => latLngToMap(pos)).toList();
  }

  // ============================================================================
  // 🗺️ إدارة حدود الخريطة
  // ============================================================================

  /// الحصول على حدود تحتوي على نقاط متعددة
  static LatLngBounds getBoundsForMultiplePoints(List<LatLng> points) {
    assert(points.isNotEmpty, 'يجب توفير نقطة واحدة على الأقل');

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// توسيع الحدود بنسبة معينة (padding)
  static LatLngBounds expandBounds(LatLngBounds bounds, double paddingPercent) {
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;

    final latPadding = latDiff * paddingPercent;
    final lngPadding = lngDiff * paddingPercent;

    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latPadding,
        bounds.southwest.longitude - lngPadding,
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latPadding,
        bounds.northeast.longitude + lngPadding,
      ),
    );
  }

  // ============================================================================
  // 🧭 حسابات الاتجاه
  // ============================================================================

  /// حساب الزاوية (bearing) بين نقطتين
  ///
  /// Returns: الزاوية بالدرجات (0-360)
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final bearing = atan2(y, x);
    return (bearing * (180 / pi) + 360) % 360;
  }

  static double atan2(double y, double x) {
    if (x > 0) return atan(y / x);
    if (x < 0 && y >= 0) return atan(y / x) + pi;
    if (x < 0 && y < 0) return atan(y / x) - pi;
    if (x == 0 && y > 0) return pi / 2;
    if (x == 0 && y < 0) return -pi / 2;
    return 0; // undefined
  }

  static double atan(double x) {
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }

  /// تحويل الزاوية إلى اتجاه نصي (شمال، جنوب، شرق، غرب)
  static String bearingToDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'شمال';
    if (bearing >= 22.5 && bearing < 67.5) return 'شمال شرق';
    if (bearing >= 67.5 && bearing < 112.5) return 'شرق';
    if (bearing >= 112.5 && bearing < 157.5) return 'جنوب شرق';
    if (bearing >= 157.5 && bearing < 202.5) return 'جنوب';
    if (bearing >= 202.5 && bearing < 247.5) return 'جنوب غرب';
    if (bearing >= 247.5 && bearing < 292.5) return 'غرب';
    return 'شمال غرب';
  }

  // ============================================================================
  // 📊 إحصائيات متقدمة
  // ============================================================================

  /// حساب المركز الجغرافي لمجموعة من النقاط
  static LatLng calculateCenter(List<LatLng> points) {
    assert(points.isNotEmpty, 'يجب توفير نقطة واحدة على الأقل');

    double sumLat = 0;
    double sumLng = 0;

    for (final point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// حساب نقطة على مسافة وزاوية معينة من نقطة أخرى
  static LatLng getPointAtDistanceAndBearing({
    required LatLng origin,
    required double distanceKm,
    required double bearingDegrees,
  }) {
    const earthRadius = 6371.0;
    final bearing = _toRadians(bearingDegrees);
    final lat1 = _toRadians(origin.latitude);
    final lng1 = _toRadians(origin.longitude);

    final lat2 = asin(
      sin(lat1) * cos(distanceKm / earthRadius) +
          cos(lat1) * sin(distanceKm / earthRadius) * cos(bearing),
    );

    final lng2 =
        lng1 +
        atan2(
          sin(bearing) * sin(distanceKm / earthRadius) * cos(lat1),
          cos(distanceKm / earthRadius) - sin(lat1) * sin(lat2),
        );

    return LatLng(lat2 * (180 / pi), lng2 * (180 / pi));
  }

  // ============================================================================
  // 🎨 تنسيق العرض
  // ============================================================================

  /// تنسيق المسافة للعرض
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} متر';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  /// تنسيق الإحداثيات للعرض
  static String formatCoordinates(LatLng position, {int decimals = 6}) {
    return '${position.latitude.toStringAsFixed(decimals)}, '
        '${position.longitude.toStringAsFixed(decimals)}';
  }

  // ============================================================================
  // 🔍 التحقق من الصحة
  // ============================================================================

  /// التحقق من صحة الإحداثيات
  static bool isValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// التحقق من أن النقطة داخل مضلع
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final vertex1 = polygon[i];
      final vertex2 = polygon[(i + 1) % polygon.length];

      if (_rayIntersectsSegment(point, vertex1, vertex2)) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1; // فردي = داخل
  }

  static bool _rayIntersectsSegment(LatLng point, LatLng a, LatLng b) {
    if (a.latitude > b.latitude) {
      final temp = a;
      a = b;
      b = temp;
    }

    if (point.latitude == a.latitude || point.latitude == b.latitude) {
      point = LatLng(point.latitude + 0.0000001, point.longitude);
    }

    if (point.latitude < a.latitude || point.latitude > b.latitude) {
      return false;
    }

    if (point.longitude >= max(a.longitude, b.longitude)) {
      return false;
    }

    if (point.longitude < min(a.longitude, b.longitude)) {
      return true;
    }

    final red = (point.latitude - a.latitude) / (b.latitude - a.latitude);
    final blue = (b.longitude - a.longitude) * red + a.longitude;

    return point.longitude < blue;
  }

  static double max(double a, double b) => a > b ? a : b;
  static double min(double a, double b) => a < b ? a : b;
}

// ============================================================================
// 🎯 Enums & Models
// ============================================================================

/// مستويات حركة المرور
enum TrafficLevel {
  low, // خفيفة
  moderate, // متوسطة
  high, // عالية
  severe, // شديدة
}

/// معلومات المسار
class RouteInfo {
  final double distanceKm;
  final double durationMinutes;
  final double deliveryFee;
  final List<LatLng> polylinePoints;
  final String formattedDistance;
  final String formattedDuration;

  RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.deliveryFee,
    required this.polylinePoints,
  }) : formattedDistance = MapHelpers.formatDistance(distanceKm),
       formattedDuration = MapHelpers.formatDeliveryTime(durationMinutes);

  @override
  String toString() {
    return 'RouteInfo(distance: $formattedDistance, '
        'duration: $formattedDuration, '
        'fee: $deliveryFee جنيه)';
  }
}

/// معلومات الموقع
class LocationInfo {
  final LatLng position;
  final String address;
  final String? city;
  final String? governorate;
  final DateTime timestamp;

  LocationInfo({
    required this.position,
    required this.address,
    this.city,
    this.governorate,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': address,
      'city': city,
      'governorate': governorate,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      position: LatLng(map['latitude'] as double, map['longitude'] as double),
      address: map['address'] as String,
      city: map['city'] as String?,
      governorate: map['governorate'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
