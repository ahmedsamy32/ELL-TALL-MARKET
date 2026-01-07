import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// خدمة إدارة المواقع والبحث الجغرافي
class LocationService {
  static final _supabase = Supabase.instance.client;

  /// جلب المتاجر القريبة من موقع العميل
  static Future<List<Map<String, dynamic>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 20,
    String? categoryFilter,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_nearby_stores',
        params: {
          'customer_lat': latitude,
          'customer_lng': longitude,
          'max_distance_km': maxDistanceKm,
          'category_filter': categoryFilter,
        },
      );

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('❌ خطأ في جلب المتاجر القريبة: $e');
      return [];
    }
  }

  /// التحقق من إمكانية توصيل متجر معين لموقع العميل
  static Future<Map<String, dynamic>?> canDeliverToLocation({
    required String storeId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _supabase.rpc(
        'can_deliver_to_location',
        params: {
          'store_id_param': storeId,
          'customer_lat': latitude,
          'customer_lng': longitude,
        },
      );

      if (response != null && (response as List).isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
      return null;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من إمكانية التوصيل: $e');
      return null;
    }
  }

  /// جلب المتاجر حسب المحافظة والمدينة (احتياطي)
  static Future<List<Map<String, dynamic>>> getStoresByArea({
    required String governorate,
    String? city,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_stores_by_area',
        params: {'governorate_param': governorate, 'city_param': city},
      );

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('❌ خطأ في جلب المتاجر حسب المنطقة: $e');
      return [];
    }
  }

  /// حساب المسافة بين نقطتين (Haversine Formula) - احتياطي
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const R = 6371; // نصف قطر الأرض بالكيلومتر
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// تحديث موقع المتجر (يحدث latitude, longitude, location دفعة واحدة)
  static Future<bool> updateStoreLocation({
    required String storeId,
    required double latitude,
    required double longitude,
    double? deliveryRadiusKm,
  }) async {
    try {
      // استخدام RPC function لتحديث الموقع الجغرافي تلقائياً
      await _supabase.rpc(
        'sync_store_location',
        params: {'store_id_param': storeId, 'lat': latitude, 'lng': longitude},
      );

      // تحديث delivery_radius_km إذا تم تمريره
      if (deliveryRadiusKm != null) {
        await _supabase
            .from('stores')
            .update({'delivery_radius_km': deliveryRadiusKm})
            .eq('id', storeId);
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث موقع المتجر: $e');
      return false;
    }
  }

  /// تحديث موقع العنوان (يحدث latitude, longitude, location دفعة واحدة)
  static Future<bool> updateAddressLocation({
    required String addressId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // استخدام RPC function لتحديث الموقع الجغرافي تلقائياً
      await _supabase.rpc(
        'sync_address_location',
        params: {
          'address_id_param': addressId,
          'lat': latitude,
          'lng': longitude,
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث موقع العنوان: $e');
      return false;
    }
  }

  /// حساب وقت التوصيل المتوقع
  static int calculateEstimatedDeliveryTime(double distanceKm) {
    // متوسط سرعة 30 كم/ساعة + 20 دقيقة إعداد
    return ((distanceKm / 30) * 60 + 20).round();
  }

  /// تحويل LatLng إلى Map
  static Map<String, double> latLngToMap(LatLng position) {
    return {'latitude': position.latitude, 'longitude': position.longitude};
  }

  /// تحويل Map إلى LatLng
  static LatLng? mapToLatLng(Map<String, dynamic>? data) {
    if (data == null) return null;
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat == null || lng == null) return null;
    return LatLng((lat as num).toDouble(), (lng as num).toDouble());
  }
}
