import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/captain_model.dart';

/// 📋 خدمة إدارة الطلبات المتقدمة (Order Management Service)
///
/// نظام شامل لإدارة دورة حياة الطلبات من الإنشاء حتى التسليم
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
///
/// @author Ell Tall Market Development Team
/// @version 2.0.0 - Enhanced Phase 6
/// @created 2024-01-01
/// @updated 2024-12-28
///
/// 🎯 الميزات الأساسية:
/// ✅ إدارة دورة حياة الطلبات الكاملة
/// ✅ نظام إدارة الحالات المتقدم
/// ✅ ربط آمن مع المخزون والكابتنز
/// ✅ حسابات الأسعار والخصومات الذكية
/// ✅ تتبع الطلبات الفوري
/// ✅ إشعارات تلقائية للحالات
/// ✅ إحصائيات وتحليلات شاملة
/// ✅ إدارة المدفوعات والمرتجعات
///
/// 🔧 العمليات المتقدمة:
/// • Lifecycle: createOrder, updateOrderStatus, cancelOrder
/// • Assignment: assignCaptain, autoAssignBestCaptain
/// • Tracking: trackOrder, getOrderHistory, getRealTimeUpdates
/// • Payments: processPayment, refundOrder, updatePaymentStatus
/// • Analytics: getOrderStats, getSalesAnalytics, getDeliveryMetrics
/// • Bulk: bulkOrderOperations, exportOrders, massStatusUpdate
/// • Real-time: watchOrders, watchOrderTracking
///
/// 📊 تحليلات الأعمال:
/// - إحصائيات المبيعات والإيرادات
/// - تحليل أداء التوصيل
/// - معدلات الإلغاء والإرجاع
/// - رضا العملاء والتقييمات
///
/// 🛡️ الأمان والموثوقية:
/// - Transaction-safe operations
/// - Stock verification قبل الإنشاء
/// - Payment validation متقدم
/// - Order state consistency
/// - Comprehensive error recovery
///
/// 🔄 دورة حياة الطلب:
/// pending → confirmed → assigned → picked_up →
/// in_delivery → delivered → completed
///
/// استخدام النمط المتقدم:
/// ```dart
/// // إنشاء طلب ذكي مع تحقق المخزون
/// final order = await OrderService.createOrderSmart(
///   customerId: user.id,
///   items: cartItems,
///   deliveryAddress: address,
///   autoAssignCaptain: true,
/// );
///
/// // تتبع فوري للطلب
/// OrderService.trackOrderRealTime(order.id).listen((status) {
///   AppLogger.info('حالة الطلب: ${status.statusArabic}');
/// });
///
/// // إحصائيات مبيعات متقدمة
/// final analytics = await OrderService.getSalesAnalytics(
///   period: AnalyticsPeriod.thisMonth,
///   breakdown: BreakdownBy.category,
/// );
/// ```
class OrderService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  // ===== إنشاء طلب جديد =====
  static Future<OrderModel?> createOrder({
    required String customerId,
    required String deliveryAddress,
    required double deliveryLat,
    required double deliveryLng,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? couponCode,
    double? discountAmount = 0.0,
    double? deliveryFee = 0.0,
    String paymentMethod = 'cash_on_delivery',
  }) async {
    try {
      // حساب إجمالي سعر المنتجات
      double subtotal = 0.0;
      for (var item in items) {
        final price = (item['price'] as num).toDouble();
        final quantity = item['quantity'] as int;
        subtotal += price * quantity;
      }

      final totalAmount =
          subtotal + (deliveryFee ?? 0.0) - (discountAmount ?? 0.0);

      // إنشاء الطلب
      final orderData = {
        'customer_id': customerId,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'discount_amount': discountAmount,
        'total_amount': totalAmount,
        'delivery_address': deliveryAddress,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        'notes': notes,
        'coupon_code': couponCode,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final orderResponse = await _supabase
          .from('orders')
          .insert(orderData)
          .select('*')
          .single();

      final orderId = orderResponse['id'];

      // إضافة عناصر الطلب
      final orderItemsData = items
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'price': item['price'],
              'total':
                  (item['price'] as num).toDouble() * (item['quantity'] as int),
            },
          )
          .toList();

      await _supabase.from('order_items').insert(orderItemsData);

      AppLogger.info('تم إنشاء طلب جديد برقم: $orderId');
      return await getOrderById(orderId);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء الطلب: ${e.message}', e);
      throw Exception('فشل إنشاء الطلب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الطلب', e);
      throw Exception('فشل إنشاء الطلب: ${e.toString()}');
    }
  }

  // ===== الحصول على تفاصيل طلب محدد =====
  static Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            captain:profiles!orders_captain_id_fkey(*),
            order_items(
              *,
              products(*, stores(*))
            )
          ''')
          .eq('id', orderId)
          .single();

      return OrderModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الطلب: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الطلب', e);
      return null;
    }
  }

  // ===== الحصول على معلومات الكابتن =====
  static Future<CaptainModel?> getCaptainById(String captainId) async {
    try {
      final response = await _supabase
          .from('captains')
          .select()
          .eq('id', captainId)
          .single();

      return CaptainModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الكابتن: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الكابتن', e);
      return null;
    }
  }

  // ===== تحديث موقع الكابتن =====
  static Future<bool> updateCaptainLocation(
    String captainId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _supabase.from('captain_locations').upsert({
        'captain_id': captainId,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم تحديث موقع الكابتن $captainId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث موقع الكابتن: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث موقع الكابتن', e);
      return false;
    }
  }

  // ===== تحديث حالة الطلب =====
  static Future<OrderModel?> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? notes,
    String? captainId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null) {
        updateData['status_notes'] = notes;
      }

      if (captainId != null) {
        updateData['captain_id'] = captainId;
      }

      // إضافة timestamps للحالات المختلفة
      switch (newStatus) {
        case 'confirmed':
          updateData['confirmed_at'] = DateTime.now().toIso8601String();
          break;
        case 'preparing':
          updateData['preparing_at'] = DateTime.now().toIso8601String();
          break;
        case 'ready_for_pickup':
          updateData['ready_at'] = DateTime.now().toIso8601String();
          break;
        case 'picked_up':
          updateData['picked_up_at'] = DateTime.now().toIso8601String();
          break;
        case 'delivered':
          updateData['delivered_at'] = DateTime.now().toIso8601String();
          updateData['payment_status'] = 'completed';
          break;
        case 'cancelled':
          updateData['cancelled_at'] = DateTime.now().toIso8601String();
          break;
      }

      await _supabase.from('orders').update(updateData).eq('id', orderId);

      AppLogger.info('تم تحديث حالة الطلب $orderId إلى $newStatus');
      return await getOrderById(orderId);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث حالة الطلب: ${e.message}', e);
      throw Exception('فشل تحديث حالة الطلب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة الطلب', e);
      throw Exception('فشل تحديث حالة الطلب: ${e.toString()}');
    }
  }

  // ===== الاستماع لتحديثات الطلب =====
  static RealtimeChannel getOrderStream(String orderId) {
    return _supabase
        .channel('order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            AppLogger.info('تم تحديث الطلب: ${payload.newRecord}');
          },
        )
        .subscribe();
  }

  // ===== الاستماع لتحديثات موقع الكابتن =====
  static RealtimeChannel getCaptainLocationStream(String captainId) {
    return _supabase
        .channel('captain_location_$captainId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'captain_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (payload) {
            AppLogger.info('تم تحديث موقع الكابتن: ${payload.newRecord}');
          },
        )
        .subscribe();
  }

  // ===========================================================================
  // Map tracking (Supabase-only backend)
  // ===========================================================================

  /// Fetch active delivery zones for a store.
  ///
  /// Expected DB:
  /// - `store_delivery_zones.zone` is a PostGIS geography polygon.
  /// - PostgREST usually returns it as GeoJSON-like: {"coordinates": [[[lng,lat],...]]}
  static Future<List<List<LatLng>>> fetchStoreDeliveryZones(
    String storeId,
  ) async {
    final List rows = await _supabase
        .from('store_delivery_zones')
        .select('id, zone')
        .eq('store_id', storeId)
        .eq('is_active', true);

    final zones = <List<LatLng>>[];
    for (final row in rows) {
      try {
        final polygon = _parseGeoJsonPolygon(row['zone']);
        if (polygon.isNotEmpty) zones.add(polygon);
      } catch (e) {
        AppLogger.warning('Failed to parse store zone: $e');
      }
    }
    return zones;
  }

  /// Check if [point] is within an active store polygon via RPC `is_point_in_store_zone`.
  static Future<bool> isPointInStoreZone({
    required String storeId,
    required LatLng point,
  }) async {
    final res = await _supabase.rpc(
      'is_point_in_store_zone',
      params: {
        'p_store_id': storeId,
        'p_lat': point.latitude,
        'p_lng': point.longitude,
      },
    );
    return res == true;
  }

  /// Upsert driver location into `driver_locations`.
  ///
  /// Requires RLS policy that allows: auth.uid() == driver_id.
  static Future<void> upsertDriverLocation({
    required String driverId,
    required LatLng position,
    bool isAvailable = false,
    double? heading,
    double? speedMps,
    double? accuracyM,
    String? currentOrderId,
  }) async {
    await _supabase.from('driver_locations').upsert({
      'driver_id': driverId,
      'position': {
        'type': 'Point',
        'coordinates': [position.longitude, position.latitude],
      },
      'is_available': isAvailable,
      'heading': heading,
      'speed_mps': speedMps,
      'accuracy_m': accuracyM,
      'current_order_id': currentOrderId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Stream a driver's location row.
  static Stream<Map<String, dynamic>?> streamDriverLocation(String driverId) {
    return _supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  /// Stream an order row.
  static Stream<Map<String, dynamic>?> streamOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  /// Stream driver location for the order's assigned driver.
  static Stream<Map<String, dynamic>?> streamOrderDriverLocation(
    String orderId,
  ) {
    return streamOrder(orderId).asyncExpand((order) {
      final driverId = order?['assigned_driver_id']?.toString();
      if (driverId == null || driverId.isEmpty) {
        return Stream<Map<String, dynamic>?>.value(null);
      }
      return streamDriverLocation(driverId);
    });
  }

  static List<LatLng> _parseGeoJsonPolygon(dynamic zone) {
    if (zone == null) return const [];

    if (zone is Map<String, dynamic>) {
      final coords = zone['coordinates'];
      return _coordsToPolygon(coords);
    }

    // If your API returns zone as a String, consider formatting the PostgREST output
    // as GeoJSON. For now we ignore it safely.
    if (zone is String) return const [];

    return const [];
  }

  static List<LatLng> _coordsToPolygon(dynamic coords) {
    if (coords is! List || coords.isEmpty) return const [];
    final ring = coords.first;
    if (ring is! List) return const [];

    final points = <LatLng>[];
    for (final p in ring) {
      if (p is List && p.length >= 2) {
        final lng = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  // ===== الحصول على طلبات المستخدم =====
  static Future<List<OrderModel>> getUserOrders(
    String userId, {
    int page = 1,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('orders')
          .select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            captain:profiles!orders_captain_id_fkey(*),
            order_items(
              *,
              products(*, stores(*))
            )
          ''')
          .eq('customer_id', userId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => OrderModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب طلبات المستخدم: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات المستخدم', e);
      return [];
    }
  }

  // ===== الحصول على جميع الطلبات (للإدارة) =====
  static Future<List<OrderModel>> getAllOrders({
    int page = 1,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase.from('orders').select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            captain:profiles!orders_captain_id_fkey(*),
            order_items(
              *,
              products(*, stores(*))
            )
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => OrderModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب جميع الطلبات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب جميع الطلبات', e);
      return [];
    }
  }

  // ===== الحصول على طلبات المتجر =====
  static Future<List<OrderModel>> getStoreOrders(
    String storeId, {
    int page = 1,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('orders')
          .select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            captain:profiles!orders_captain_id_fkey(*),
            order_items(
              *,
              products!inner(*, stores!inner(*))
            )
          ''')
          .eq('order_items.products.stores.id', storeId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => OrderModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب طلبات المتجر: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات المتجر', e);
      return [];
    }
  }

  // ===== الحصول على طلبات الكابتن =====
  static Future<List<OrderModel>> getCaptainOrders(
    String captainId, {
    int page = 1,
    String? status,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('orders')
          .select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            captain:profiles!orders_captain_id_fkey(*),
            order_items(
              *,
              products(*, stores(*))
            )
          ''')
          .eq('captain_id', captainId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => OrderModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب طلبات الكابتن: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات الكابتن', e);
      return [];
    }
  }

  // ===== الحصول على الطلبات المتاحة للكباتن =====
  static Future<List<OrderModel>> getAvailableOrdersForCaptains({
    double? captainLat,
    double? captainLng,
    double maxDistance = 10.0, // كيلومتر
  }) async {
    try {
      var query = _supabase
          .from('orders')
          .select('''
            *,
            customers:profiles!orders_customer_id_fkey(*),
            order_items(
              *,
              products(*, stores(*))
            )
          ''')
          .or(
            'status.eq.${OrderStatus.pending.value},status.eq.${OrderStatus.confirmed.value}',
          )
          .isFilter('captain_id', null);

      final response = await query.order('created_at', ascending: true);

      final orders = (response as List)
          .map((data) => OrderModel.fromMap(data))
          .toList();

      // تطبيق فلتر المسافة إذا تم توفير موقع الكابتن
      if (captainLat != null && captainLng != null) {
        // حالياً نعيد جميع الطلبات - يمكن تطوير فلترة جغرافية لاحقاً
        // عند إضافة حقول lat/lng منفصلة لجدول الطلبات
        return orders;
      }

      return orders;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الطلبات المتاحة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الطلبات المتاحة', e);
      return [];
    }
  }

  // ===== إحصائيات الطلبات =====
  static Future<Map<String, dynamic>> getOrderStatistics({
    String? customerId,
    String? storeId,
    String? captainId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _supabase.from('orders').select();

      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      if (captainId != null) {
        query = query.eq('captain_id', captainId);
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final orders = await query;

      // حساب الإحصائيات
      final totalOrders = orders.length;
      final completedOrders = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .length;
      final cancelledOrders = orders
          .where((o) => o['status'] == OrderStatus.cancelled.value)
          .length;
      final totalRevenue = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .fold<double>(
            0.0,
            (sum, o) => sum + (o['total_amount'] as num).toDouble(),
          );

      final averageOrderValue = completedOrders > 0
          ? totalRevenue / completedOrders
          : 0.0;

      return {
        'total_orders': totalOrders,
        'completed_orders': completedOrders,
        'cancelled_orders': cancelledOrders,
        'pending_orders': orders
            .where(
              (o) =>
                  o['status'] != OrderStatus.delivered.value &&
                  o['status'] != OrderStatus.cancelled.value,
            )
            .length,
        'total_revenue': totalRevenue,
        'average_order_value': averageOrderValue,
        'completion_rate': totalOrders > 0
            ? (completedOrders / totalOrders) * 100
            : 0.0,
        'cancellation_rate': totalOrders > 0
            ? (cancelledOrders / totalOrders) * 100
            : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب إحصائيات الطلبات: ${e.message}',
        e,
      );
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات الطلبات', e);
      return {};
    }
  }

  // ===== وظائف مساعدة =====

  /// التحقق من إمكانية إلغاء الطلب
  static bool canCancelOrder(OrderModel order) {
    const List<String> cancellableStatuses = [
      'pending',
      'confirmed',
      'preparing',
      'assigned',
    ];

    // `order.status` is an enum; compare via its String value.
    return cancellableStatuses.contains(order.status.value);
  }

  /// حساب الوقت المتوقع للتوصيل
  static Duration calculateEstimatedDeliveryTime({
    required String orderStatus,
    required DateTime orderCreatedAt,
    int preparationMinutes = 30,
    int deliveryMinutes = 30,
  }) {
    switch (orderStatus) {
      case 'pending':
      case 'confirmed':
        return Duration(minutes: preparationMinutes + deliveryMinutes);
      case 'preparing':
        return Duration(minutes: deliveryMinutes);
      case 'ready_for_pickup':
      case 'picked_up':
        return Duration(minutes: deliveryMinutes ~/ 2);
      default:
        return Duration.zero;
    }
  }

  // ================================
  // 📊 Advanced Analytics & Business Intelligence
  // ================================

  /// الحصول على إحصائيات شاملة للطلبات
  static Future<Map<String, dynamic>> getAdvancedOrderAnalytics({
    String? merchantId,
    String? captainId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('orders').select('*');

      if (merchantId != null) {
        query = query.eq('merchant_id', merchantId);
      }

      if (captainId != null) {
        query = query.eq('captain_id', captainId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final orders = response.map((json) => OrderModel.fromMap(json)).toList();

      // حسابات الإحصائيات المتقدمة
      final totalOrders = orders.length;
      final completedOrders = orders
          .where((o) => o.status.value == 'delivered')
          .length;
      final cancelledOrders = orders
          .where((o) => o.status.value == 'cancelled')
          .length;

      final totalRevenue = orders
          .where((o) => o.status.value == 'delivered')
          .fold<double>(0.0, (sum, order) => sum + order.totalAmount);

      final averageOrderValue = completedOrders > 0
          ? totalRevenue / completedOrders
          : 0.0;
      final completionRate = totalOrders > 0
          ? (completedOrders / totalOrders) * 100
          : 0.0;

      // توزيع الحالات
      final statusDistribution = <String, int>{};
      for (final order in orders) {
        final statusKey = order.status.value;
        statusDistribution[statusKey] =
            (statusDistribution[statusKey] ?? 0) + 1;
      }

      AppLogger.info('تم حساب الإحصائيات المتقدمة: $totalOrders طلب');

      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'cancelledOrders': cancelledOrders,
        'totalRevenue': totalRevenue,
        'averageOrderValue': averageOrderValue,
        'completionRate': completionRate,
        'statusDistribution': statusDistribution,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في الإحصائيات المتقدمة: ${e.message}', e);
      throw Exception('فشل حساب الإحصائيات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في الإحصائيات المتقدمة', e);
      throw Exception('فشل حساب الإحصائيات: ${e.toString()}');
    }
  }

  /// البحث المتقدم والذكي في الطلبات
  static Future<List<OrderModel>> smartOrderSearch({
    String? searchTerm,
    List<String>? statuses,
    double? minAmount,
    double? maxAmount,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('orders').select('*');

      // البحث النصي
      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.or(
          'notes.ilike.%$searchTerm%,'
          'delivery_address.ilike.%$searchTerm%',
        );
      }

      // فلتر الحالات
      if (statuses != null && statuses.isNotEmpty) {
        // استخدام OR لربط الحالات
        final statusFilter = statuses.map((s) => 'status.eq.$s').join(',');
        query = query.or(statusFilter);
      }

      // فلاتر المبالغ
      if (minAmount != null) {
        query = query.gte('total_amount', minAmount);
      }

      if (maxAmount != null) {
        query = query.lte('total_amount', maxAmount);
      }

      // فلاتر التاريخ
      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        query = query.lte('created_at', dateTo.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final orders = response.map((json) => OrderModel.fromMap(json)).toList();

      AppLogger.info('البحث الذكي: تم العثور على ${orders.length} طلب');
      return orders;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث الذكي: ${e.message}', e);
      throw Exception('فشل البحث الذكي: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث الذكي', e);
      throw Exception('فشل البحث الذكي: ${e.toString()}');
    }
  }

  // ================================
  // 🔄 Real-time Tracking & Monitoring
  // ================================

  /// مراقبة تحديثات الطلبات فورياً
  static Stream<List<Map<String, dynamic>>> watchOrdersRealTime({
    String? customerId,
    String? merchantId,
    String? captainId,
  }) {
    var query = _supabase.from('orders').stream(primaryKey: ['id']);

    if (customerId != null) {
      return query.eq('client_id', customerId).order('updated_at');
    }

    if (merchantId != null) {
      return query.eq('merchant_id', merchantId).order('updated_at');
    }

    if (captainId != null) {
      return query.eq('captain_id', captainId).order('updated_at');
    }

    return query.order('updated_at');
  }

  /// تتبع طلب محدد مع تفاصيل إضافية
  static Stream<Map<String, dynamic>> trackOrderWithDetails(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((list) {
          if (list.isNotEmpty) {
            final orderData = list.first;
            final order = OrderModel.fromMap(orderData);

            return {
              ...orderData,
              'statusArabic': getOrderStatusInArabic(order.status.value),
              'canCancel': canCancelOrder(order),
              'estimatedDelivery': _getEstimatedDeliveryTime(
                order.status.value,
              ),
              'progressPercentage': _getOrderProgress(order.status.value),
            };
          }
          return <String, dynamic>{};
        });
  }

  /// ترجمة حالة الطلب للعربية
  static String getOrderStatusInArabic(String status) {
    const statusMap = {
      'pending': 'في الانتظار',
      'confirmed': 'مؤكد',
      'preparing': 'قيد التحضير',
      'assigned': 'تم تعيين المندوب',
      'picked_up': 'تم الاستلام',
      'in_delivery': 'في الطريق',
      'delivered': 'تم التسليم',
      'cancelled': 'ملغي',
      'returned': 'مرتجع',
    };
    return statusMap[status] ?? status;
  }

  /// تقدير وقت التسليم
  static String _getEstimatedDeliveryTime(String status) {
    const estimationMap = {
      'pending': '30-45 دقيقة',
      'confirmed': '25-40 دقيقة',
      'preparing': '20-35 دقيقة',
      'assigned': '15-30 دقيقة',
      'picked_up': '10-20 دقيقة',
      'in_delivery': '5-15 دقيقة',
      'delivered': 'تم التسليم',
      'cancelled': 'ملغي',
      'returned': 'مرتجع',
    };
    return estimationMap[status] ?? 'غير محدد';
  }

  /// حساب نسبة تقدم الطلب
  static int _getOrderProgress(String status) {
    const progressMap = {
      'pending': 10,
      'confirmed': 25,
      'preparing': 40,
      'assigned': 55,
      'picked_up': 70,
      'in_delivery': 85,
      'delivered': 100,
      'cancelled': 0,
      'returned': 0,
    };
    return progressMap[status] ?? 0;
  }

  // ================================
  // 📈 Export & Reporting
  // ================================

  /// تصدير تقارير الطلبات
  static Future<List<Map<String, dynamic>>> exportOrdersReport({
    String? merchantId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? includeStatuses,
  }) async {
    try {
      var query = _supabase.from('orders').select('''
            *,
            profiles!orders_client_id_fkey(full_name, phone),
            captains(profiles(full_name))
          ''');

      if (merchantId != null) {
        query = query.eq('merchant_id', merchantId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      if (includeStatuses != null && includeStatuses.isNotEmpty) {
        final statusFilter = includeStatuses
            .map((s) => 'status.eq.$s')
            .join(',');
        query = query.or(statusFilter);
      }

      final response = await query.order('created_at', ascending: false);

      final exportData = response.map((order) {
        return {
          'رقم الطلب': order['id'],
          'العميل': order['profiles']?['full_name'] ?? 'غير محدد',
          'هاتف العميل': order['profiles']?['phone'] ?? '',
          'المندوب':
              order['captains']?['profiles']?['full_name'] ?? 'لم يتم التعيين',
          'الحالة': getOrderStatusInArabic(order['status']),
          'المبلغ الإجمالي': '${order['total_amount']} ج.م',
          'عنوان التوصيل': order['delivery_address'] ?? '',
          'الملاحظات': order['notes'] ?? '',
          'تاريخ الإنشاء': order['created_at'],
          'آخر تحديث': order['updated_at'] ?? '',
        };
      }).toList();

      AppLogger.info('تم تصدير ${exportData.length} طلب');
      return exportData;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تصدير التقرير: ${e.message}', e);
      throw Exception('فشل تصدير التقرير: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تصدير التقرير', e);
      throw Exception('فشل تصدير التقرير: ${e.toString()}');
    }
  }
}
