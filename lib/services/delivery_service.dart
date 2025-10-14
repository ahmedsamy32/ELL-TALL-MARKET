import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_model.dart';
import '../core/logger.dart';

/// خدمة التوصيلات المحسنة
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
/// تدعم تتبع التوصيلات الفورية وإدارة الكباتن
///
/// الصلاحيات:
/// - العملاء: يمكنهم مشاهدة توصيلاتهم فقط
/// - الكباتن: يمكنهم مشاهدة وتحديث التوصيلات المخصصة لهم
/// - التجار: يمكنهم مشاهدة توصيلات متاجرهم
/// - الـ Admin: صلاحية كاملة على جميع التوصيلات
class DeliveryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ===== حساب المسافة بين نقطتين =====
  static Future<double> calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) async {
    try {
      final response = await _supabase.rpc(
        'calculate_distance',
        params: {'lat1': lat1, 'lng1': lng1, 'lat2': lat2, 'lng2': lng2},
      );
      return (response as num).toDouble();
    } catch (e) {
      AppLogger.warning('لم يتم العثور على RPC function، استخدام Haversine', e);
      // حساب المسافة باستخدام معادلة Haversine كنسخة احتياطية
      return _calculateHaversineDistance(lat1, lng1, lat2, lng2);
    }
  }

  // ===== حساب تكلفة التوصيل =====
  static Future<double> calculateDeliveryCost({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    double baseCost = 10.0,
    double costPerKm = 2.5,
    double minCost = 10.0,
  }) async {
    try {
      // استخدام Database Function الموجودة في Schema
      final response = await _supabase.rpc(
        'calculate_delivery_cost',
        params: {
          'pickup_latitude': pickupLat,
          'pickup_longitude': pickupLng,
          'delivery_latitude': deliveryLat,
          'delivery_longitude': deliveryLng,
        },
      );
      final cost = (response as num).toDouble();
      AppLogger.info('تكلفة التوصيل المحسوبة من DB: $cost');
      return cost;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حساب التكلفة: ${e.message}', e);
      // حساب بديل محلي
      final distance = await calculateDistance(
        lat1: pickupLat,
        lng1: pickupLng,
        lat2: deliveryLat,
        lng2: deliveryLng,
      );
      final cost = baseCost + (distance * costPerKm);
      return cost > minCost ? cost : minCost;
    } catch (e) {
      AppLogger.error('خطأ في حساب تكلفة التوصيل', e);
      return minCost;
    }
  }

  // ===== البحث عن الكباتن القريبين =====
  static Future<List<Map<String, dynamic>>> getNearbyCaptains({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    bool availableOnly = true,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_nearby_captains',
        params: {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          'available_only': availableOnly,
        },
      );
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      AppLogger.error('خطأ في جلب الكباتن القريبين', e);
      return [];
    }
  }

  // ===== العثور على أقرب كابتن متاح =====
  static Future<Map<String, dynamic>?> findAvailableCaptain({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    try {
      final captains = await getNearbyCaptains(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        availableOnly: true,
      );

      if (captains.isNotEmpty) {
        // ترتيب حسب المسافة وإرجاع الأقرب
        captains.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );
        return captains.first;
      }
      return null;
    } catch (e) {
      AppLogger.error('خطأ في العثور على كابتن متاح', e);
      return null;
    }
  }

  // ===== تقدير وقت التوصيل =====
  static Future<Map<String, dynamic>> estimateDeliveryTime({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    double averageSpeed = 30.0, // km/h
    int loadingTime = 10, // minutes
  }) async {
    try {
      // البحث عن كابتن متاح
      final captain = await findAvailableCaptain(
        lat: pickupLat,
        lng: pickupLng,
      );

      if (captain == null) {
        return {
          'status': 'no_captain',
          'estimated_time': null,
          'message': 'لا يوجد كباتن متاحين حالياً',
        };
      }

      // حساب المسافات
      final distanceToCaptain = captain['distance'] as double;
      final deliveryDistance = await calculateDistance(
        lat1: pickupLat,
        lng1: pickupLng,
        lat2: deliveryLat,
        lng2: deliveryLng,
      );

      // حساب الأوقات
      final timeToPickup = (distanceToCaptain / averageSpeed) * 60; // minutes
      final timeToDelivery = (deliveryDistance / averageSpeed) * 60; // minutes
      final totalTime = timeToPickup + timeToDelivery + loadingTime;

      return {
        'status': 'available',
        'estimated_time': totalTime.ceil(),
        'captain_distance': distanceToCaptain,
        'delivery_distance': deliveryDistance,
        'captain_id': captain['captain_id'],
        'captain_name': captain['name'],
        'captain_phone': captain['phone'],
      };
    } catch (e) {
      AppLogger.error('خطأ في تقدير وقت التوصيل', e);
      return {
        'status': 'error',
        'estimated_time': null,
        'message': 'حدث خطأ في تقدير وقت التوصيل',
      };
    }
  }

  // ===== إنشاء مهمة توصيل =====
  static Future<Map<String, dynamic>> createDeliveryTask({
    required String orderId,
    required String captainId,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    String? notes,
    DateTime? scheduledTime,
  }) async {
    try {
      final deliveryData = {
        'order_id': orderId,
        'captain_id': captainId,
        'pickup_location': {'lat': pickupLat, 'lng': pickupLng},
        'delivery_location': {'lat': deliveryLat, 'lng': deliveryLng},
        'status': 'pending',
        'notes': notes,
        'scheduled_at': scheduledTime?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('deliveries')
          .insert(deliveryData)
          .select()
          .single();

      return {'success': true, 'delivery_id': response['id'], 'data': response};
    } catch (e) {
      AppLogger.error('خطأ في إنشاء مهمة التوصيل', e);
      return {
        'success': false,
        'message': 'فشل في إنشاء مهمة التوصيل',
        'error': e.toString(),
      };
    }
  }

  // ===== تحديث حالة التوصيل =====
  static Future<bool> updateDeliveryStatus({
    required String deliveryId,
    required String status,
    String? notes,
    Map<String, dynamic>? location,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null) updateData['notes'] = notes;
      if (location != null) updateData['current_location'] = location;

      // إضافة أوقات محددة حسب الحالة
      switch (status) {
        case 'picked_up':
          updateData['picked_up_at'] = DateTime.now().toIso8601String();
          break;
        case 'delivered':
          updateData['delivered_at'] = DateTime.now().toIso8601String();
          break;
        case 'cancelled':
          updateData['cancelled_at'] = DateTime.now().toIso8601String();
          break;
      }

      await _supabase
          .from('deliveries')
          .update(updateData)
          .eq('id', deliveryId);

      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة التوصيل', e);
      return false;
    }
  }

  // ===== تتبع التوصيل =====
  static Future<Map<String, dynamic>?> trackDelivery(String deliveryId) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select('''
            *,
            orders (
              id,
              order_number,
              customer_name,
              customer_phone
            ),
            captains (
              id,
              name,
              phone,
              vehicle_type,
              license_plate
            )
          ''')
          .eq('id', deliveryId)
          .single();

      return response;
    } catch (e) {
      AppLogger.error('خطأ في تتبع التوصيل', e);
      return null;
    }
  }

  // ===== الحصول على تاريخ التوصيل للكابتن =====
  static Future<List<Map<String, dynamic>>> getCaptainDeliveryHistory({
    required String captainId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select('''
            *,
            orders (
              id,
              order_number,
              total_amount
            )
          ''')
          .eq('captain_id', captainId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب تاريخ توصيلات الكابتن', e);
      return [];
    }
  }

  // ===== حساب المسافة باستخدام Haversine (نسخة احتياطية) =====
  static double _calculateHaversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // ===== إنشاء طلب توصيل =====
  static Future<DeliveryModel?> createDelivery(DeliveryModel delivery) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .insert(delivery.toMap())
          .select()
          .single();

      return DeliveryModel.fromMap(response);
    } catch (e) {
      AppLogger.error('خطأ في إنشاء التوصيل', e);
      return null;
    }
  }

  // ===== جلب تفاصيل التوصيل =====
  static Future<DeliveryModel?> getDelivery(String deliveryId) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select()
          .eq('id', deliveryId)
          .single();

      return DeliveryModel.fromMap(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب تفاصيل التوصيل', e);
      return null;
    }
  }

  // ===== جلب توصيلات الكابتن =====
  static Future<List<DeliveryModel>> getCaptainDeliveries(
    String captainId,
  ) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select()
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      return response
          .map<DeliveryModel>((data) => DeliveryModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب توصيلات الكابتن', e);
      return [];
    }
  }

  // ===== تحديث موقع الكابتن =====
  static Future<bool> updateCaptainLocation({
    required String captainId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _supabase
          .from('captains')
          .update({
            'current_location': {'lat': lat, 'lng': lng},
            'last_location_update': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث موقع الكابتن', e);
      return false;
    }
  }

  // ===== تخصيص توصيل لكابتن =====
  static Future<bool> assignDeliveryToCaptain({
    required String deliveryId,
    required String captainId,
  }) async {
    try {
      await _supabase
          .from('deliveries')
          .update({
            'captain_id': captainId,
            'status': 'assigned',
            'assigned_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', deliveryId);

      return true;
    } catch (e) {
      AppLogger.error('خطأ في تخصيص الكابتن للتوصيل', e);
      return false;
    }
  }

  // ===== إلغاء توصيل =====
  static Future<bool> cancelDelivery({
    required String deliveryId,
    required String reason,
  }) async {
    try {
      await _supabase
          .from('deliveries')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', deliveryId);

      return true;
    } catch (e) {
      AppLogger.error('خطأ في إلغاء التوصيل', e);
      return false;
    }
  }

  // ===== الحصول على توصيلات متوفرة =====
  static Future<List<DeliveryModel>> getAvailableDeliveries({
    double? lat,
    double? lng,
    double radiusKm = 10.0,
  }) async {
    try {
      var query = _supabase
          .from('deliveries')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      // إذا تم تحديد الموقع، البحث ضمن نطاق محدد
      if (lat != null && lng != null) {
        // استخدام SQL function للبحث الجغرافي
        final response = await _supabase.rpc(
          'get_nearby_deliveries',
          params: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
        );

        return response
            .map<DeliveryModel>((data) => DeliveryModel.fromMap(data))
            .toList();
      }

      final response = await query;
      return response
          .map<DeliveryModel>((data) => DeliveryModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب التوصيلات المتاحة', e);
      return [];
    }
  }
}
