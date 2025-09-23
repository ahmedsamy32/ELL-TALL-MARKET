import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // معلمات حساب تكلفة التوصيل
  final double _baseCost = 10.0; // التكلفة الأساسية
  final double _costPerKm = 2.0; // التكلفة لكل كيلومتر
  final double _minCost = 15.0; // الحد الأدنى للتكلفة

  // ===== حساب تكلفة التوصيل =====
  Future<double> calculateDeliveryCost({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    try {
      final response = await _supabase.rpc('calculate_delivery_cost', params: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        'base_cost': _baseCost,
        'cost_per_km': _costPerKm,
        'min_cost': _minCost,
      });

      return (response as num).toDouble();
    } catch (e) {
      if (kDebugMode) print('❌ Error calculating delivery cost: $e');
      // إرجاع القيمة الافتراضية في حالة الخطأ
      return _minCost;
    }
  }

  // ===== البحث عن كابتن متاح =====
  Future<Map<String, dynamic>?> findAvailableCaptain({
    required double pickupLat,
    required double pickupLng,
    double radiusKm = 5.0,
  }) async {
    try {
      final response = await _supabase.rpc('get_nearby_captains', params: {
        'lat': pickupLat,
        'lng': pickupLng,
        'radius_km': radiusKm,
      });

      if (response != null && (response as List).isNotEmpty) {
        // إرجاع أقرب كابتن متاح
        return response.first;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error finding available captain: $e');
      return null;
    }
  }

  // ===== تقدير وقت التوصيل =====
  Future<Map<String, dynamic>> estimateDeliveryTime({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    try {
      // البحث عن كابتن متاح
      final captain = await findAvailableCaptain(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
      );

      if (captain == null) {
        return {
          'status': 'no_captain',
          'estimated_time': null,
          'message': 'لا يوجد كباتن متاحين حالياً'
        };
      }

      // حساب المسافة من الكابتن إلى نقطة الاستلام
      final distanceToCaptain = captain['distance'] as double;

      // حساب المسافة من نقطة الاستلام إلى نقطة التوصيل
      final deliveryDistance = await _supabase.rpc('calculate_distance', params: {
        'lat1': pickupLat,
        'lng1': pickupLng,
        'lat2': deliveryLat,
        'lng2': deliveryLng,
      });

      // تقدير الوقت (بافتراض متوسط سرعة 30 كم/ساعة)
      final timeToPickup = (distanceToCaptain / 30) * 60; // بالدقائق
      final timeToDelivery = (deliveryDistance / 30) * 60; // بالدقائق
      final totalTime = timeToPickup + timeToDelivery + 10; // إضافة 10 دقائق للتحميل والتفريغ

      return {
        'status': 'available',
        'estimated_time': totalTime.ceil(),
        'captain_distance': distanceToCaptain,
        'delivery_distance': deliveryDistance,
        'captain': captain,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error estimating delivery time: $e');
      return {
        'status': 'error',
        'estimated_time': null,
        'message': 'حدث خطأ في تقدير وقت التوصيل'
      };
    }
  }

  // ===== جدولة توصيل =====
  Future<Map<String, dynamic>> scheduleDelivery({
    required String orderId,
    required String storeId,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required DateTime scheduledTime,
  }) async {
    try {
      // التحقق من وجود كباتن متاحين
      final captain = await findAvailableCaptain(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
      );

      if (captain == null) {
        return {
          'success': false,
          'message': 'لا يوجد كباتن متاحين حالياً'
        };
      }

      // حساب تكلفة التوصيل
      final deliveryCost = await calculateDeliveryCost(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
      );

      // تحديث الطلب بمعلومات التوصيل
      await _supabase
          .from('orders')
          .update({
            'captain_id': captain['captain_id'],
            'delivery_cost': deliveryCost,
            'scheduled_delivery_time': scheduledTime.toIso8601String(),
            'pickup_location': {
              'lat': pickupLat,
              'lng': pickupLng,
            },
            // Use JSONB column added in migration
            'delivery_location_json': {
              'lat': deliveryLat,
              'lng': deliveryLng,
            },
            'delivery_status': 'scheduled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      return {
        'success': true,
        'delivery_cost': deliveryCost,
        'captain': captain,
        'scheduled_time': scheduledTime.toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling delivery: $e');
      return {
        'success': false,
        'message': 'حدث خطأ في جدولة التوصيل'
      };
    }
  }
}
