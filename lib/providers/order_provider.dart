import 'dart:async';
// Removed dart:io for Web compatibility
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderService;
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:ell_tall_market/services/order_service.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/services/supabase_service.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import '../core/logger.dart';

class OrderProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<OrderModel> _orders = [];
  List<OrderModel> _currentOrders = [];
  List<OrderModel> _pastOrders = [];
  List<OrderModel> _captainOrders = [];
  bool _isLoading = false;
  String? _error;
  OrderModel? _selectedOrder;
  CaptainModel? _selectedOrderCaptain;
  int _availableOrdersCount = 0;
  List<OrderModel> _availableOrders = [];
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _captainChannel;
  RealtimeChannel? _deliveryDashboardChannel;
  String? _activeCaptainId;

  /// ⏱️ مهلة قبول الكابتن (90 ثانية)
  static const Duration captainAcceptTimeout = Duration(seconds: 90);

  /// مؤقتات المهلة لكل طلب: orderId → Timer
  final Map<String, Timer> _captainTimeouts = {};

  /// تتبع الكباتن المرفوضين لكل طلب: orderId → [captainIds]
  final Map<String, List<String>> _rejectedCaptains = {};

  // Getters
  List<OrderModel> get orders => _orders;
  List<OrderModel> get currentOrders => _currentOrders;
  List<OrderModel> get pastOrders => _pastOrders;
  List<OrderModel> get captainOrders => _captainOrders;
  List<OrderModel> get captainCurrentOrders => _captainOrders
      .where(
        (o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled,
      )
      .toList(growable: false);
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderModel? get selectedOrder => _selectedOrder;
  CaptainModel? get selectedOrderCaptain => _selectedOrderCaptain;
  int get availableOrdersCount => _availableOrdersCount;
  List<OrderModel> get availableOrders => _availableOrders;

  /// هل الكابتن لديه طلبات نشطة حالياً؟ (يُستخدم لمنع الذهاب أوفلاين)
  bool get hasCaptainActiveOrders => _captainOrders.any(
    (o) =>
        o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled,
  );

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// إعادة تعيين حالة الخطأ (للاستخدام قبل إعادة المحاولة)
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyMessageFromException(Object e) {
    if (e.toString().contains('SocketException')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجددًا.';
    }
    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجددًا.';
    }
    if (e is PostgrestException) {
      return 'حدث خطأ في الخادم. حاول لاحقًا.';
    }
    return 'حدث خطأ غير متوقع. حاول مجددًا.';
  }

  // ===== إلغاء الاشتراك في أي قناة حالية =====
  Future<void> _unsubscribeChannel() async {
    try {
      await _ordersChannel?.unsubscribe();
    } catch (_) {}
    _ordersChannel = null;
  }

  Future<void> _unsubscribeDeliveryDashboardChannel() async {
    try {
      await _deliveryDashboardChannel?.unsubscribe();
    } catch (_) {}
    _deliveryDashboardChannel = null;
  }

  /// اشتراك مباشر لواجهة شركة التوصيل على كل الطلبات
  Future<void> subscribeToDeliveryDashboardOrders() async {
    await _unsubscribeDeliveryDashboardChannel();

    _deliveryDashboardChannel = _supabase
        .channel('delivery-company-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            AppLogger.info(
              '🔄 Delivery dashboard order event: ${payload.eventType}',
            );
            await fetchAllOrders();
          },
        )
        .subscribe();
  }

  // ===== تهيئة قناة Realtime للطلبات =====
  void initializeOrdersChannel(String userId) {
    _ordersChannel = _supabase
        .channel('orders-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final eventType = payload.eventType;
            final data = payload.newRecord;

            switch (eventType) {
              case PostgresChangeEvent.insert:
                _handleNewOrder(data);
                break;
              case PostgresChangeEvent.update:
                _handleOrderUpdate(data);
                break;
              case PostgresChangeEvent.delete:
                final oldData = payload.oldRecord;
                if (oldData['id'] != null) {
                  _handleOrderDelete(oldData['id']);
                }
                break;
              default:
                break;
            }
          },
        )
        .subscribe();
  }

  // ===== الاشتراك في تحديثات الطلبات لمتجر محدد (Realtime) =====
  Future<void> subscribeToStoreOrders(String storeId) async {
    await _unsubscribeChannel();

    _ordersChannel = _supabase
        .channel('orders-store-$storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _handleNewOrder(data);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _handleOrderUpdate(data);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            final oldData = payload.oldRecord;
            if (oldData['id'] != null) {
              _handleOrderDelete(oldData['id']);
            }
          },
        )
        .subscribe();

    if (kDebugMode) {
      print('🔌 تم الاشتراك في Realtime لطلبات المتجر: $storeId');
    }
  }

  // ===== الاشتراك في تحديثات الطلبات لكابتن محدد (Realtime) =====
  // يستخدم قناة منفصلة (_captainChannel) حتى لا يتعارض مع قنوات الطلبات الأخرى
  Future<void> subscribeToCaptainOrders(String captainId) async {
    // لا تعيد الاشتراك إذا كان نفس الكابتن والقناة نشطة
    if (_activeCaptainId == captainId && _captainChannel != null) {
      AppLogger.info('🔌 قناة الكابتن $captainId نشطة بالفعل — تخطي الاشتراك');
      return;
    }

    // إلغاء القناة القديمة إن وُجدت
    await _unsubscribeCaptainChannel();
    _activeCaptainId = captainId;

    _captainChannel = _supabase
        .channel('orders-captain-$captainId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (payload) {
            final eventType = payload.eventType;
            final data = payload.newRecord;

            switch (eventType) {
              case PostgresChangeEvent.insert:
                _handleNewOrder(data);
                break;
              case PostgresChangeEvent.update:
                _handleOrderUpdate(data);
                break;
              case PostgresChangeEvent.delete:
                final oldData = payload.oldRecord;
                if (oldData['id'] != null) {
                  _handleOrderDelete(oldData['id']);
                }
                break;
              default:
                break;
            }
          },
        )
        .subscribe();

    AppLogger.info('🔌 تم الاشتراك في Realtime لطلبات الكابتن: $captainId');
  }

  // إلغاء اشتراك قناة الكابتن
  Future<void> _unsubscribeCaptainChannel() async {
    try {
      await _captainChannel?.unsubscribe();
    } catch (_) {}
    _captainChannel = null;
  }

  // ===== جلب طلبات المستخدم =====
  Future<void> fetchUserOrders(String userId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, store:stores(name), client:profiles!client_id(full_name, phone)',
          )
          .eq('client_id', userId)
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromMap(o)).toList();
      _categorizeOrders();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات المستخدم', e);
      _setError(_friendlyMessageFromException(e));
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب جميع الطلبات =====
  Future<void> fetchAllOrders() async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select('*')
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromMap(o)).toList();
      _categorizeOrders();
    } catch (e) {
      AppLogger.error('خطأ في جلب جميع الطلبات', e);
      _setError(_friendlyMessageFromException(e));
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب طلبات المتجر =====
  Future<void> fetchStoreOrders(String storeId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select('*, client:profiles!client_id(full_name, phone)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromMap(o)).toList();
      _categorizeOrders();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات المتجر', e);
      _setError(_friendlyMessageFromException(e));
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب طلبات الكابتن =====
  Future<void> fetchCaptainOrders(String captainId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, client:profiles!client_id(full_name, phone), store:stores!store_id(name, address, phone, latitude, longitude)',
          )
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      _captainOrders = (response as List)
          .map((o) => OrderModel.fromMap(o))
          .toList();

      // توحيد المصدر المستخدم في الشاشات الحالية (current/past)
      _orders = List<OrderModel>.from(_captainOrders);
      _categorizeOrders();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات الكابتن', e);
      _setError(_friendlyMessageFromException(e));
      _orders = [];
      _currentOrders = [];
      _pastOrders = [];
      _captainOrders = [];
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب طلبات التاجر =====
  Future<void> fetchMerchantOrders(String merchantId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, client:profiles!client_id(full_name, phone), store:stores!inner(name), order_items:order_items(*)',
          )
          .eq('stores.merchant_id', merchantId)
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromMap(o)).toList();
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات التاجر', e);
      _setError(_friendlyMessageFromException(e));
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء طلب جديد =====
  Future<String?> createOrder(OrderModel order) async {
    try {
      final orderData = {
        'client_id': order.clientId,
        'store_id': order.storeId,
        'captain_id': order.captainId,
        'order_group_id': order.orderGroupId,
        'total_amount': order.totalAmount,
        'delivery_fee': order.deliveryFee,
        'tax_amount': order.taxAmount,
        'delivery_address': order.deliveryAddress,
        'delivery_latitude': order.deliveryLatitude,
        'delivery_longitude': order.deliveryLongitude,
        'delivery_notes': order.deliveryNotes,
        'status': order.status.value,
        'payment_method': order.paymentMethod.value,
        'payment_status': order.paymentStatus.value,
      };

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final newOrder = OrderModel.fromMap(response);
      _orders.insert(0, newOrder);
      _categorizeOrders();
      AppLogger.info('تم إنشاء الطلب بنجاح: ${newOrder.id}');

      // ❌ لم نعد نعين كابتن هنا - الكابتن يُعين بعد قبول التاجر
      // سيتم تعيين الكابتن تلقائياً عند تأكيد التاجر للطلب (confirmed)

      // جلب اسم المتجر (إذا توفر)
      String storeName = 'متجر';
      try {
        final storeData = await _supabase
            .from('stores')
            .select('name')
            .eq('id', order.storeId)
            .maybeSingle();
        if (storeData != null) storeName = storeData['name'] ?? 'متجر';
      } catch (_) {}

      // إرسال إشعار للتاجر بالطلب الجديد
      NotificationServiceEnhanced.instance.notifyMerchantOfNewOrder(
        storeId: order.storeId,
        orderId: newOrder.id,
        totalAmount: order.totalAmount,
      );

      // إرسال إشعار للأدمن
      NotificationServiceEnhanced.instance.notifyAdminOfNewOrder(
        orderId: newOrder.id,
        storeName: storeName,
        totalAmount: order.totalAmount,
      );

      return newOrder.id;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الطلب', e);
      _setError(_friendlyMessageFromException(e));
      return null;
    }
  }

  // ===== تحديث حالة الطلب =====
  Future<bool> updateOrderStatus(
    String orderId,
    dynamic status, {
    String? captainId,
  }) async {
    try {
      String statusString = status is String ? status : status.toString();

      AppLogger.info(
        '🔵 PROVIDER DEBUG: بدء updateOrderStatus للطلب: $orderId مع الحالة: $statusString',
      );
      AppLogger.info('🔄 بدء تحديث الطلب $orderId إلى الحالة: $statusString');

      AppLogger.info(
        '🔵 PROVIDER DEBUG: استدعاء OrderService.updateOrderStatus...',
      );
      final updatedOrder = await OrderService.updateOrderStatus(
        orderId,
        statusString,
        captainId: captainId,
      );

      AppLogger.info(
        '🔵 PROVIDER DEBUG: نتيجة updateOrderStatus = ${updatedOrder != null ? "النجاح ✅ - تم الحصول على الطلب" : "الفشل ❌ - null returned"}',
      );
      if (updatedOrder != null) {
        AppLogger.info(
          '🟢 PROVIDER DEBUG: الطلب المحدث موجود - ID: ${updatedOrder.id}, Status: ${updatedOrder.status}',
        );
        _setError(null);
        // التحديث المحلي تم بالفعل داخل acceptOrder أو سيتم عبر Realtime
        // ولكن للتأكد من التحديث الفوري في الواجهة:
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = updatedOrder;
          _categorizeOrders();
        }
        if (_selectedOrder?.id == orderId) {
          _selectedOrder = updatedOrder;
          notifyListeners();
        }

        _syncCaptainOrderCache(updatedOrder);
        if (_activeCaptainId != null) {
          _orders = List<OrderModel>.from(_captainOrders);
          _categorizeOrders();
        }

        // إرسال إشعار للعميل بتغيير الحالة
        NotificationServiceEnhanced.instance.notifyClientOfOrderStatusChange(
          clientId: updatedOrder.clientId,
          orderId: orderId,
          newStatus: statusString,
          storeName: updatedOrder.storeName,
        );

        // إذا اكتمل الطلب، نعيد الكابتن لحالة "متصل" ليدخل في طابور الانتظار من جديد
        if (statusString == OrderStatus.delivered.value &&
            updatedOrder.captainId != null) {
          final otherActiveOrders = await _supabase
              .from('orders')
              .select('id')
              .eq('captain_id', updatedOrder.captainId!)
              .neq('id', orderId)
              .or(
                'status.eq.${OrderStatus.pending.value},status.eq.${OrderStatus.confirmed.value},status.eq.${OrderStatus.preparing.value},status.eq.${OrderStatus.ready.value},status.eq.${OrderStatus.pickedUp.value},status.eq.${OrderStatus.inTransit.value}',
              )
              .limit(1);

          if ((otherActiveOrders as List).isEmpty) {
            await SupabaseService.updateCaptainStatus(
              updatedOrder.captainId!,
              'online',
            );
          }
        }

        // 🚚 عندما يصبح الطلب جاهزاً، ينتقل إلى طابور شركة التوصيل
        // تعيين الكابتن يتم يدوياً من لوحة شركة التوصيل أو تلقائياً من هناك فقط.
        if (statusString == OrderStatus.ready.value &&
            updatedOrder.captainId == null) {
          AppLogger.info(
            '🚚 الطلب جاهز للتسليم وينتظر تعيين كابتن من شركة التوصيل',
          );
        }

        // إذا تم تعيين كابتن يدوياً، نرسل له إشعار
        if (updatedOrder.captainId != null && captainId != null) {
          NotificationServiceEnhanced.instance.notifyCaptainOfOrderAssignment(
            captainId: updatedOrder.captainId!,
            orderId: orderId,
            storeName: updatedOrder.storeName ?? 'المتجر',
          );
        }

        return true;
      }
      AppLogger.warning(
        '❌ PROVIDER DEBUG: updatedOrder رجعت null - فشل التحديث',
      );
      return false;
    } on PostgrestException catch (e) {
      AppLogger.error(
        '❌ PROVIDER DEBUG: PostgrestException - Code: ${e.code}, Message: ${e.message}',
      );
      AppLogger.error(
        '❌ خطأ Supabase في تحديث حالة الطلب: ${e.code} - ${e.message}',
        e,
      );

      final isRlsBlocked =
          e.code == '406' ||
          e.code == '42501' ||
          e.message.contains('PGRST116') ||
          e.message.contains('0 rows') ||
          e.message.toLowerCase().contains('row-level security');

      if (isRlsBlocked) {
        AppLogger.warning('⚠️ RLS منع التحديث المباشر - تجربة RPC function');
        final String statusString = status is String
            ? status
            : status.toString();
        final rpcResult = await _tryUpdateViaRpc(orderId, statusString);
        if (rpcResult != null) {
          // تحديث محلي
          final index = _orders.indexWhere((o) => o.id == orderId);
          if (index != -1) {
            _orders[index] = _orders[index].copyWith(
              status: OrderStatus.fromString(statusString),
              updatedAt: DateTime.now(),
            );
            _categorizeOrders();
          }
          if (_selectedOrder?.id == orderId) {
            _selectedOrder = _selectedOrder!.copyWith(
              status: OrderStatus.fromString(statusString),
              updatedAt: DateTime.now(),
            );
            notifyListeners();
          }
          _setError(null);
          AppLogger.info('✅ تم تحديث الطلب عبر RPC');
          return true;
        }
        _setError('ليس لديك صلاحية لتحديث هذا الطلب');
        return false;
      }

      _setError('حدث خطأ أثناء تحديث الطلب');
      return false;
    } catch (e) {
      AppLogger.error(
        '❌ PROVIDER DEBUG: General Exception: ${e.toString()}',
        e,
      );
      AppLogger.error('❌ خطأ في تحديث حالة الطلب', e);
      _setError(_friendlyMessageFromException(e));
      return false;
    }
  }

  // ===== ⏱️ مؤقت مهلة قبول الكابتن =====

  /// بدء مؤقت المهلة — إذا انتهى بدون قبول يُرفض تلقائياً
  void _startCaptainTimeout(
    String orderId,
    String captainId,
    String storeId,
    String storeName,
  ) {
    // إلغاء أي مؤقت سابق لنفس الطلب
    _captainTimeouts[orderId]?.cancel();

    AppLogger.info(
      '⏱️ بدأ مؤقت المهلة للطلب $orderId - الكابتن $captainId - مهلة: ${captainAcceptTimeout.inSeconds}ث',
    );

    _captainTimeouts[orderId] = Timer(captainAcceptTimeout, () async {
      AppLogger.warning(
        '⏰ انتهت مهلة الكابتن $captainId للطلب $orderId - رفض تلقائي',
      );

      // التحقق أن الطلب لازال معين لنفس الكابتن (لم يقبل/يرفض يدوياً)
      try {
        final currentOrder = await OrderService.getOrderById(orderId);
        if (currentOrder == null) return;

        // إذا الكابتن تغير أو الطلب تقدم (يعني الكابتن قبل) - لا نعمل شي
        if (currentOrder.captainId != captainId) {
          AppLogger.info('ℹ️ الكابتن تغير للطلب $orderId - تجاهل المهلة');
          return;
        }

        // إذا الطلب تقدم لحالة أعلى من confirmed (يعني الكابتن بدأ العمل)
        final statusValue = currentOrder.status.value.toLowerCase();
        // في النظام الحالي: الطلب المعيّن ينتظر قبول الكابتن وهو في ready
        // إذا خرج من ready فهذا يعني أنه قُبل/تقدم في الرحلة، فلا نرفض تلقائياً
        if (statusValue != OrderStatus.ready.value) {
          AppLogger.info(
            'ℹ️ الطلب $orderId تقدم لحالة $statusValue - الكابتن قبل بالفعل',
          );
          return;
        }

        // رفض تلقائي
        await rejectOrder(orderId, captainId);
      } catch (e) {
        AppLogger.error('❌ خطأ في الرفض التلقائي للطلب $orderId', e);
      } finally {
        _captainTimeouts.remove(orderId);
      }
    });
  }

  /// إلغاء مؤقت المهلة (عند قبول أو رفض يدوي)
  void _cancelCaptainTimeout(String orderId) {
    final timer = _captainTimeouts.remove(orderId);
    if (timer != null) {
      timer.cancel();
      AppLogger.info('✅ تم إلغاء مؤقت المهلة للطلب $orderId');
    }
  }

  /// تنظيف سجل الكباتن المرفوضين لطلب معين
  void _clearRejectedCaptains(String orderId) {
    _rejectedCaptains.remove(orderId);
  }

  /// قبول طلب من قبل الكابتن
  Future<bool> acceptOrder(String orderId, String captainId) async {
    _setLoading(true);
    try {
      final currentOrder = await OrderService.getOrderById(orderId);
      if (currentOrder == null) {
        _setError('لم يتم العثور على الطلب');
        return false;
      }

      if (currentOrder.status != OrderStatus.ready) {
        _setError('لا يمكن قبول الطلب إلا بعد أن يصبح جاهزاً');
        return false;
      }

      if (currentOrder.captainId != captainId) {
        _setError('هذا الطلب غير مُعين لك');
        return false;
      }

      // ✅ إلغاء مؤقت المهلة — الكابتن قبل
      _cancelCaptainTimeout(orderId);
      _clearRejectedCaptains(orderId);

      final updatedOrder = await OrderService.updateOrderStatus(
        orderId,
        'confirmed',
        captainId: captainId,
      );

      if (updatedOrder != null) {
        await SupabaseService.updateCaptainStatus(captainId, 'busy');

        // تحديث محلي
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = updatedOrder;
          _categorizeOrders();
        } else {
          _orders.insert(0, updatedOrder);
          _categorizeOrders();
        }

        if (_selectedOrder?.id == orderId) {
          _selectedOrder = updatedOrder;
          notifyListeners();
        }

        AppLogger.info(
          '✅ تم قبول الطلب $orderId بنجاح من قبل الكابتن $captainId',
        );

        // إرسال إشعار للعميل
        NotificationServiceEnhanced.instance.notifyClientOfOrderStatusChange(
          clientId: updatedOrder.clientId,
          orderId: orderId,
          newStatus: 'confirmed',
          storeName: updatedOrder.storeName,
        );

        // إرسال إشعار للتاجر
        NotificationServiceEnhanced.instance.notifyMerchantOfOrderStatusChange(
          storeId: updatedOrder.storeId,
          orderId: orderId,
          newStatus: 'confirmed',
        );

        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في قبول الطلب', e);
      _setError('فشل قبول الطلب: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== إلغاء الطلب =====
  Future<bool> cancelOrder(String orderId, {String? cancelReason}) async {
    try {
      AppLogger.info('🚫 بدء إلغاء الطلب: $orderId');

      // التحقق من حالة الطلب الحالية
      OrderModel? order;
      try {
        order = _orders.firstWhere((o) => o.id == orderId);
      } catch (_) {
        order = _selectedOrder;
      }

      if (order != null) {
        // السماح بالإلغاء فقط للطلبات في حالة pending أو confirmed
        final statusValue = order.status.value.toLowerCase();
        if (statusValue != 'pending' && statusValue != 'confirmed') {
          _setError('لا يمكن إلغاء الطلب في هذه المرحلة');
          return false;
        }
      }

      final updatedOrder = await OrderService.updateOrderStatus(
        orderId,
        'cancelled',
      );

      if (updatedOrder != null) {
        _setError(null);
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = updatedOrder;
          _categorizeOrders();
        }
        if (_selectedOrder?.id == orderId) {
          _selectedOrder = updatedOrder;
          notifyListeners();
        }
        AppLogger.info('✅ تم إلغاء الطلب بنجاح');

        // إرسال إشعار للعميل
        NotificationServiceEnhanced.instance.notifyClientOfOrderStatusChange(
          clientId: updatedOrder.clientId,
          orderId: orderId,
          newStatus: 'cancelled',
          storeName: updatedOrder.storeName,
        );

        // إرسال إشعار للتاجر
        NotificationServiceEnhanced.instance.notifyMerchantOfOrderStatusChange(
          storeId: updatedOrder.storeId,
          orderId: orderId,
          newStatus: 'cancelled',
        );

        return true;
      }
      return false;
    } on PostgrestException catch (e) {
      AppLogger.error(
        '❌ خطأ Supabase في إلغاء الطلب: ${e.code} - ${e.message}',
        e,
      );

      final isRlsBlocked =
          e.code == '406' ||
          e.code == '42501' ||
          e.message.contains('PGRST116') ||
          e.message.contains('0 rows') ||
          e.message.toLowerCase().contains('row-level security');

      if (isRlsBlocked) {
        AppLogger.warning('⚠️ RLS منع الإلغاء المباشر - تجربة RPC function');
        final rpcResult = await _tryUpdateViaRpc(
          orderId,
          'cancelled',
          cancelReason: cancelReason,
        );
        if (rpcResult != null) {
          // تحديث محلي
          final index = _orders.indexWhere((o) => o.id == orderId);
          if (index != -1) {
            _orders[index] = _orders[index].copyWith(
              status: OrderStatus.cancelled,
              updatedAt: DateTime.now(),
            );
            _categorizeOrders();
          }
          if (_selectedOrder?.id == orderId) {
            _selectedOrder = _selectedOrder!.copyWith(
              status: OrderStatus.cancelled,
              updatedAt: DateTime.now(),
            );
            notifyListeners();
          }
          _setError(null);
          AppLogger.info('✅ تم إلغاء الطلب عبر RPC');
          return true;
        }
        _setError('ليس لديك صلاحية لإلغاء هذا الطلب');
        return false;
      }

      _setError('حدث خطأ أثناء إلغاء الطلب');
      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في إلغاء الطلب', e);
      _setError(_friendlyMessageFromException(e));
      return false;
    }
  }

  /// تعيين كابتن لطلب جاهز مع منع تعيين كابتن مشغول أو غير متصل
  Future<bool> assignCaptainToOrder({
    required String orderId,
    required String captainId,
  }) async {
    _setLoading(true);
    try {
      OrderModel? currentOrder;
      for (final order in _orders) {
        if (order.id == orderId) {
          currentOrder = order;
          break;
        }
      }
      currentOrder ??= await OrderService.getOrderById(orderId);

      if (currentOrder == null) {
        _setError('لم يتم العثور على الطلب');
        return false;
      }

      if (currentOrder.status != OrderStatus.ready) {
        _setError('لا يمكن تعيين كابتن إلا للطلبات الجاهزة للتسليم');
        return false;
      }

      if (currentOrder.captainId != null) {
        _setError('الطلب مُعين بالفعل لكابتن آخر');
        return false;
      }

      final captainRecord = await _supabase
          .from('captains')
          .select('id, status, is_available, is_online')
          .eq('id', captainId)
          .maybeSingle();

      if (captainRecord == null) {
        _setError('لم يتم العثور على الكابتن');
        return false;
      }

      final captainStatus = captainRecord['status'] as String? ?? 'offline';
      final isAvailable = captainRecord['is_available'] as bool? ?? false;
      final isOnline = captainRecord['is_online'] as bool? ?? false;

      if (captainStatus == 'busy' || !isAvailable || !isOnline) {
        _setError('هذا الكابتن مشغول أو غير متصل حالياً');
        return false;
      }

      // Rule: الكابتن لا يحمل أكثر من طلب نشط
      final captainActiveOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('captain_id', captainId)
          .or(
            'status.eq.${OrderStatus.pending.value},status.eq.${OrderStatus.confirmed.value},status.eq.${OrderStatus.preparing.value},status.eq.${OrderStatus.ready.value},status.eq.${OrderStatus.pickedUp.value},status.eq.${OrderStatus.inTransit.value}',
          )
          .limit(1);

      if ((captainActiveOrders as List).isNotEmpty) {
        _setError('لا يمكن تعيين الطلب: الكابتن لديه طلب نشط بالفعل');
        return false;
      }

      final updatedOrder = await OrderService.updateOrderStatus(
        orderId,
        currentOrder.status.value,
        captainId: captainId,
      );

      if (updatedOrder == null) {
        _setError('فشل تعيين الكابتن للطلب');
        return false;
      }

      final captainMarkedBusy = await SupabaseService.updateCaptainStatus(
        captainId,
        'busy',
      );
      if (!captainMarkedBusy) {
        // Rollback لتجنب طلب معلّق بكابتن غير مشغول في النظام
        await _supabase
            .from('orders')
            .update({'captain_id': null})
            .eq('id', orderId);
        _setError('فشل تحديث حالة الكابتن، تم إلغاء التعيين تلقائياً');
        return false;
      }

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = updatedOrder;
        _categorizeOrders();
      }

      if (_selectedOrder?.id == orderId) {
        _selectedOrder = updatedOrder;
        notifyListeners();
      }

      _syncCaptainOrderCache(updatedOrder);

      NotificationServiceEnhanced.instance.notifyCaptainOfOrderAssignment(
        captainId: captainId,
        orderId: orderId,
        storeName: updatedOrder.storeName ?? 'المتجر',
      );

      NotificationServiceEnhanced.instance.notifyClientOfOrderStatusChange(
        clientId: updatedOrder.clientId,
        orderId: orderId,
        newStatus: 'captain_assigned',
        storeName: updatedOrder.storeName,
      );

      _startCaptainTimeout(
        orderId,
        captainId,
        updatedOrder.storeId,
        updatedOrder.storeName ?? 'المتجر',
      );

      _setError(null);
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تعيين الكابتن للطلب', e);
      _setError(_friendlyMessageFromException(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// محاولة تحديث الطلب عبر RPC function
  Future<Map<String, dynamic>?> _tryUpdateViaRpc(
    String orderId,
    String newStatus, {
    String? cancelReason,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.warning('⚠️ المستخدم غير مسجل - لا يمكن استخدام RPC');
        return null;
      }

      // استدعاء الـ RPC function
      final result = await _supabase.rpc(
        'update_order_status',
        params: {
          'p_order_id': orderId,
          'p_new_status': newStatus,
          'p_changed_by': currentUser.id,
          'p_notes': 'تحديث من التطبيق',
          'p_cancellation_reason': cancelReason,
        },
      );

      // التحقق من النتيجة
      if (result != null && result is Map) {
        final success = result['success'] as bool? ?? false;
        if (success) {
          AppLogger.info('✅ تم تحديث الطلب عبر RPC: $result');
          return Map<String, dynamic>.from(result);
        } else {
          final error = result['error'] as String? ?? 'خطأ غير معروف';
          AppLogger.warning('⚠️ فشل RPC: $error');
          return null;
        }
      }

      AppLogger.info('✅ تم تحديث الطلب عبر RPC');
      return {'success': true};
    } on PostgrestException catch (e) {
      AppLogger.warning('⚠️ خطأ في RPC: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      AppLogger.warning('⚠️ RPC function غير متوفرة أو فشلت: $e');
      return null;
    }
  }

  // ===== جلب طلب حسب المعرف =====
  Future<void> getOrderById(String orderId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('orders')
          .select('*, client:profiles!client_id(full_name, phone)')
          .eq('id', orderId)
          .single();
      _selectedOrder = OrderModel.fromMap(response);
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب الطلب بالمعرف', e);
      _setError(e.toString());
      _selectedOrder = null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب طلب حسب رقم الطلب =====
  Future<void> getOrderByNumber(String orderNumber) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('orders')
          .select('*, client:profiles!client_id(full_name, phone)')
          .eq('order_number', orderNumber)
          .maybeSingle();

      if (response == null) {
        // إذا لم نجد رقم طلب مطابق، نحاول البحث في المعرف (UUID)
        if (orderNumber.length >= 32) {
          await getOrderById(orderNumber);
          return;
        }
        _selectedOrder = null;
        _setError('لم يتم العثور على الطلب رقم $orderNumber');
      } else {
        _selectedOrder = OrderModel.fromMap(response);
        _setError(null);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب الطلب برقم الطلب', e);
      _setError(_friendlyMessageFromException(e));
      _selectedOrder = null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== تصنيف الطلبات =====
  void _categorizeOrders() {
    _currentOrders = _orders
        .where(
          (order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled,
        )
        .toList();

    _pastOrders = _orders
        .where(
          (order) =>
              order.status == OrderStatus.delivered ||
              order.status == OrderStatus.cancelled,
        )
        .toList();
    notifyListeners();
  }

  // ===== معالجة التحديثات في الوقت الحقيقي =====
  Future<void> _handleNewOrder(Map<String, dynamic> orderData) async {
    final orderId = orderData['id'] as String;
    // جلب تفاصيل الطلب كاملة مع العلاقات (العميل، المتجر، إلخ)
    final fullOrder = await OrderService.getOrderById(orderId);

    if (fullOrder != null) {
      // التحقق مما إذا كان الطلب موجوداً بالفعل لتجنب التكرار
      final index = _orders.indexWhere((o) => o.id == fullOrder.id);
      if (index == -1) {
        _orders.insert(0, fullOrder);
      } else {
        _orders[index] = fullOrder;
      }

      _syncCaptainOrderCache(fullOrder);
      if (_activeCaptainId != null) {
        _orders = List<OrderModel>.from(_captainOrders);
      }

      _categorizeOrders();
      notifyListeners();
    }
  }

  Future<void> _handleOrderUpdate(Map<String, dynamic> orderData) async {
    final orderId = orderData['id'] as String;
    // جلب تفاصيل الطلب كاملة مع العلاقات
    final fullOrder = await OrderService.getOrderById(orderId);

    if (fullOrder != null) {
      final index = _orders.indexWhere((o) => o.id == fullOrder.id);
      if (index != -1) {
        _orders[index] = fullOrder;
      } else {
        _orders.insert(0, fullOrder);
      }

      _syncCaptainOrderCache(fullOrder);
      if (_activeCaptainId != null) {
        _orders = List<OrderModel>.from(_captainOrders);
      }

      _categorizeOrders();
      notifyListeners();
    }
  }

  void _handleOrderDelete(String orderId) {
    _orders.removeWhere((o) => o.id == orderId);
    _captainOrders.removeWhere((o) => o.id == orderId);
    if (_activeCaptainId != null) {
      _orders = List<OrderModel>.from(_captainOrders);
    }
    _categorizeOrders();
  }

  void _syncCaptainOrderCache(OrderModel order) {
    if (_activeCaptainId == null) return;

    final index = _captainOrders.indexWhere((o) => o.id == order.id);
    final belongsToActiveCaptain = order.captainId == _activeCaptainId;

    if (belongsToActiveCaptain) {
      if (index == -1) {
        _captainOrders.insert(0, order);
      } else {
        _captainOrders[index] = order;
      }
      return;
    }

    if (index != -1) {
      _captainOrders.removeAt(index);
    }
  }

  // ===== اختيار طلب =====
  void selectOrder(OrderModel order) {
    _selectedOrder = order;
    notifyListeners();
  }

  void clearSelectedOrder() {
    _selectedOrder = null;
    _selectedOrderCaptain = null;
    notifyListeners();
  }

  /// Clear all orders data (called on logout)
  void clearOrders() {
    _orders = [];
    _currentOrders = [];
    _pastOrders = [];
    _captainOrders = [];
    _selectedOrder = null;
    _selectedOrderCaptain = null;
    _error = null;
    _activeCaptainId = null;
    _unsubscribeChannel();
    _unsubscribeCaptainChannel();
    notifyListeners();
  }

  // ===== تحديث موقع الكابتن =====
  Future<void> updateCaptainLocation({
    required String captainId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await CaptainService.updateCaptainLocation(
        captainId: captainId,
        latitude: latitude,
        longitude: longitude,
      );

      AppLogger.info('تم تحديث موقع الكابتن');
    } catch (e) {
      AppLogger.error('خطأ في تحديث موقع الكابتن', e);
      _setError(e.toString());
    }
  }

  // ===== إعادة تعيين البيانات =====
  void reset() {
    _orders = [];
    _currentOrders = [];
    _pastOrders = [];
    _captainOrders = [];
    _isLoading = false;
    _error = null;
    _selectedOrder = null;
    _selectedOrderCaptain = null;
    notifyListeners();
  }

  // ===== إنشاء طلب بسيط =====
  Future<OrderModel?> createSimpleOrder({
    required String clientId,
    required String merchantId,
    required double totalAmount,
    required String deliveryAddress,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      final orderData = {
        'client_id': clientId,
        'merchant_id': merchantId,
        'status': 'pending',
        'total_amount': totalAmount,
        'delivery_address': deliveryAddress,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final newOrder = OrderModel.fromMap(response);
      _orders.add(newOrder);
      _categorizeOrders();
      AppLogger.info('تم إنشاء الطلب بنجاح: ${newOrder.id}');
      return newOrder;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الطلب', e);
      _setError('Failed to create order: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب عدد الطلبات المتاحة في منطقة الكابتن =====
  Future<void> fetchAvailableOrdersCount({
    required double lat,
    required double lng,
  }) async {
    try {
      final availableOrders = await OrderService.getAvailableOrdersForCaptains(
        captainLat: lat,
        captainLng: lng,
      );
      _availableOrders = availableOrders;
      _availableOrdersCount = availableOrders.length;
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب عدد الطلبات المتاحة', e);
    }
  }

  @override
  void notifyListeners() {
    if (!hasListeners) return;

    final scheduler = SchedulerBinding.instance;
    final phase = scheduler.schedulerPhase;

    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      super.notifyListeners();
    } else {
      scheduler.addPostFrameCallback((_) {
        if (hasListeners) {
          super.notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _captainChannel?.unsubscribe();
    _deliveryDashboardChannel?.unsubscribe();
    // إلغاء جميع مؤقتات المهلة
    for (final timer in _captainTimeouts.values) {
      timer.cancel();
    }
    _captainTimeouts.clear();
    _rejectedCaptains.clear();
    super.dispose();
  }

  /// رفض الكابتن للطلب → البحث عن كابتن آخر
  Future<bool> rejectOrder(String orderId, String captainId) async {
    _setLoading(true);
    try {
      // ✅ إلغاء مؤقت المهلة — الكابتن رفض يدوياً
      _cancelCaptainTimeout(orderId);

      // تتبع الكباتن المرفوضين لهذا الطلب
      _rejectedCaptains.putIfAbsent(orderId, () => []);
      _rejectedCaptains[orderId]!.add(captainId);

      AppLogger.info('🚫 الكابتن $captainId يرفض الطلب $orderId');

      // إعادة الطلب لطابور الجاهز + إزالة الكابتن
      await _supabase
          .from('orders')
          .update({'captain_id': null, 'status': OrderStatus.ready.value})
          .eq('id', orderId);

      // إعادة الكابتن لحالة "متصل"
      await SupabaseService.updateCaptainStatus(captainId, 'online');

      // تحديث محلي — نعيد جلب الطلب من DB لأن copyWith لا يمكنه تعيين captainId = null
      final refreshedOrder = await OrderService.getOrderById(orderId);
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        if (refreshedOrder != null) {
          _orders[index] = refreshedOrder;
          _syncCaptainOrderCache(refreshedOrder);
        }
        _categorizeOrders();
      }

      if (_activeCaptainId != null) {
        _orders = List<OrderModel>.from(_captainOrders);
        _categorizeOrders();
      }

      AppLogger.info('✅ تم رفض الطلب وإعادته إلى طابور الجاهز للتعيين اليدوي');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في رفض الطلب', e);
      _setError('فشل رفض الطلب: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
