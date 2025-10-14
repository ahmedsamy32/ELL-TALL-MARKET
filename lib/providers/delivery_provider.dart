import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/delivery_service.dart';
import '../models/delivery_model.dart';
import '../core/logger.dart';

/// مزود إدارة حالة التوصيلات
/// يتكامل مع DeliveryService ويوفر واجهة تفاعلية للـ UI
class DeliveryProvider with ChangeNotifier {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // معلمات حساب تكلفة التوصيل
  final double _baseCost = 10.0; // التكلفة الأساسية
  final double _costPerKm = 2.0; // التكلفة لكل كيلومتر
  final double _minCost = 15.0; // الحد الأدنى للتكلفة

  // حالة التحميل
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // معلومات التوصيل الحالي
  DeliveryModel? _currentDelivery;
  DeliveryModel? get currentDelivery => _currentDelivery;

  // قائمة التوصيلات
  List<DeliveryModel> _deliveries = [];
  List<DeliveryModel> get deliveries => _deliveries;

  // تحديث حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ===== حساب تكلفة التوصيل =====
  Future<double> calculateDeliveryCost({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    _setLoading(true);
    try {
      final cost = await DeliveryService.calculateDeliveryCost(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        baseCost: _baseCost,
        costPerKm: _costPerKm,
        minCost: _minCost,
      );
      AppLogger.info('تم حساب تكلفة التوصيل: $cost');
      return cost;
    } catch (e) {
      AppLogger.error('خطأ في حساب تكلفة التوصيل', e);
      return _minCost;
    } finally {
      _setLoading(false);
    }
  }

  // ===== البحث عن كابتن متاح =====
  Future<Map<String, dynamic>?> findAvailableCaptain({
    required double pickupLat,
    required double pickupLng,
    double radiusKm = 5.0,
  }) async {
    try {
      final captains = await DeliveryService.getNearbyCaptains(
        lat: pickupLat,
        lng: pickupLng,
        radiusKm: radiusKm,
        availableOnly: true,
      );

      if (captains.isNotEmpty) {
        AppLogger.info('تم العثور على ${captains.length} كابتن متاح');
        return captains.first;
      }
      AppLogger.warning('لا يوجد كباتن متاحين في نطاق $radiusKm كم');
      return null;
    } catch (e) {
      AppLogger.error('خطأ في البحث عن كابتن متاح', e);
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
          'message': 'لا يوجد كباتن متاحين حالياً',
        };
      }

      // حساب المسافة من الكابتن إلى نقطة الاستلام
      final distanceToCaptain = captain['distance'] as double;

      // حساب المسافة من نقطة الاستلام إلى نقطة التوصيل
      final deliveryDistance = await DeliveryService.calculateDistance(
        lat1: pickupLat,
        lng1: pickupLng,
        lat2: deliveryLat,
        lng2: deliveryLng,
      );

      // تقدير الوقت (بافتراض متوسط سرعة 30 كم/ساعة)
      final timeToPickup = (distanceToCaptain / 30) * 60; // بالدقائق
      final timeToDelivery = (deliveryDistance / 30) * 60; // بالدقائق
      final totalTime =
          timeToPickup + timeToDelivery + 10; // إضافة 10 دقائق للتحميل والتفريغ

      return {
        'status': 'available',
        'estimated_time': totalTime.ceil(),
        'captain_distance': distanceToCaptain,
        'delivery_distance': deliveryDistance,
        'captain': captain,
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
        return {'success': false, 'message': 'لا يوجد كباتن متاحين حالياً'};
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
            'pickup_location': {'lat': pickupLat, 'lng': pickupLng},
            // Use JSONB column added in migration
            'delivery_location_json': {'lat': deliveryLat, 'lng': deliveryLng},
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
      AppLogger.error('خطأ في جدولة التوصيل', e);
      return {'success': false, 'message': 'حدث خطأ في جدولة التوصيل'};
    }
  }

  // ===== إنشاء توصيل جديد =====
  Future<DeliveryModel?> createDelivery({
    required String orderId,
    required String storeId,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    String? pickupAddress,
    String? deliveryAddress,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      final cost = await calculateDeliveryCost(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
      );

      final delivery = DeliveryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: orderId,
        trackingNumber: 'DEL${DateTime.now().millisecondsSinceEpoch}',
        status: DeliveryStatus.pending,
        pickupAddress: pickupAddress ?? '',
        pickupLatitude: pickupLat,
        pickupLongitude: pickupLng,
        deliveryAddress: deliveryAddress ?? '',
        deliveryLatitude: deliveryLat,
        deliveryLongitude: deliveryLng,
        deliveryFee: cost,
        customerNotes: notes,
        createdAt: DateTime.now(),
      );

      final result = await DeliveryService.createDelivery(delivery);
      if (result != null) {
        _deliveries.insert(0, result);
        _currentDelivery = result;
        AppLogger.info('✅ تم إنشاء التوصيل: ${result.id}');
        notifyListeners();
      }
      return result;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء التوصيل', e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحديث حالة التوصيل =====
  Future<bool> updateDeliveryStatus(
    String deliveryId,
    DeliveryStatus status,
  ) async {
    _setLoading(true);
    try {
      final success = await DeliveryService.updateDeliveryStatus(
        deliveryId: deliveryId,
        status: _getStatusString(status),
      );

      if (success) {
        // تحديث القائمة المحلية
        final index = _deliveries.indexWhere((d) => d.id == deliveryId);
        if (index != -1) {
          _deliveries[index] = _deliveries[index].copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );

          if (_currentDelivery?.id == deliveryId) {
            _currentDelivery = _deliveries[index];
          }
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة التوصيل', e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _getStatusString(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'pending';
      case DeliveryStatus.assigned:
        return 'assigned';
      case DeliveryStatus.pickedUp:
        return 'picked_up';
      case DeliveryStatus.inTransit:
        return 'in_transit';
      case DeliveryStatus.arrived:
        return 'arrived';
      case DeliveryStatus.delivered:
        return 'delivered';
      case DeliveryStatus.cancelled:
        return 'cancelled';
      case DeliveryStatus.failed:
        return 'failed';
    }
  }

  // ===== جلب جميع التوصيلات =====
  Future<void> loadAllDeliveries() async {
    _setLoading(true);
    try {
      // استخدام Supabase مباشرة لجلب جميع التوصيلات
      final response = await _supabase
          .from('deliveries')
          .select()
          .order('created_at', ascending: false);

      _deliveries = response
          .map<DeliveryModel>((data) => DeliveryModel.fromMap(data))
          .toList();

      AppLogger.info('تم تحميل ${_deliveries.length} توصيل');
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في تحميل التوصيلات', e);
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب توصيلات محددة =====
  Future<void> loadDeliveriesByStatus(DeliveryStatus status) async {
    _setLoading(true);
    try {
      final statusString = _getStatusString(status);
      final response = await _supabase
          .from('deliveries')
          .select()
          .eq('status', statusString)
          .order('created_at', ascending: false);

      _deliveries = response
          .map<DeliveryModel>((data) => DeliveryModel.fromMap(data))
          .toList();

      AppLogger.info(
        'تم تحميل ${_deliveries.length} توصيل بحالة $statusString',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في تحميل التوصيلات بحالة معينة', e);
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب توصيلات الكابتن =====
  Future<void> loadCaptainDeliveries(String captainId) async {
    _setLoading(true);
    try {
      final deliveries = await DeliveryService.getCaptainDeliveries(captainId);
      _deliveries = deliveries;
      AppLogger.info('تم تحميل ${deliveries.length} توصيل للكابتن $captainId');
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في تحميل توصيلات الكابتن', e);
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب توصيل محدد =====
  Future<DeliveryModel?> getDeliveryById(String deliveryId) async {
    _setLoading(true);
    try {
      final delivery = await DeliveryService.getDelivery(deliveryId);
      if (delivery != null) {
        AppLogger.info('تم جلب التوصيل: $deliveryId');
      }
      return delivery;
    } catch (e) {
      AppLogger.error('خطأ في جلب التوصيل', e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== تعيين توصيل حالي =====
  void setCurrentDelivery(DeliveryModel? delivery) {
    _currentDelivery = delivery;
    notifyListeners();
  }

  // ===== إعادة تعيين البيانات =====
  void reset() {
    _deliveries.clear();
    _currentDelivery = null;
    _isLoading = false;
    notifyListeners();
  }

  // ===== تتبع التوصيل الفوري =====
  Stream<DeliveryModel?> trackDeliveryRealTime(String deliveryId) {
    return _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('id', deliveryId)
        .map((data) {
          if (data.isNotEmpty) {
            final deliveryData = data.first;
            final delivery = DeliveryModel.fromMap(deliveryData);

            // تحديث التوصيل المحلي إذا كان هو نفسه
            if (_currentDelivery?.id == delivery.id) {
              _currentDelivery = delivery;
              notifyListeners();
            }

            return delivery;
          }
          return null;
        });
  }

  // ===== إحصائيات التوصيل =====
  Map<String, int> get deliveryStats {
    final stats = <String, int>{
      'total': _deliveries.length,
      'pending': 0,
      'assigned': 0,
      'picked_up': 0,
      'in_transit': 0,
      'delivered': 0,
      'cancelled': 0,
    };

    for (final delivery in _deliveries) {
      switch (delivery.status) {
        case DeliveryStatus.pending:
          stats['pending'] = (stats['pending'] ?? 0) + 1;
          break;
        case DeliveryStatus.assigned:
          stats['assigned'] = (stats['assigned'] ?? 0) + 1;
          break;
        case DeliveryStatus.pickedUp:
          stats['picked_up'] = (stats['picked_up'] ?? 0) + 1;
          break;
        case DeliveryStatus.inTransit:
          stats['in_transit'] = (stats['in_transit'] ?? 0) + 1;
          break;
        case DeliveryStatus.arrived:
          stats['arrived'] = (stats['arrived'] ?? 0) + 1;
          break;
        case DeliveryStatus.delivered:
          stats['delivered'] = (stats['delivered'] ?? 0) + 1;
          break;
        case DeliveryStatus.cancelled:
          stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
          break;
        case DeliveryStatus.failed:
          stats['failed'] = (stats['failed'] ?? 0) + 1;
          break;
      }
    }

    return stats;
  }
}
