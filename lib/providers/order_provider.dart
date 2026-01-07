import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/captain_model.dart';
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
  RealtimeChannel? _ordersChannel;

  // Getters
  List<OrderModel> get orders => _orders;
  List<OrderModel> get currentOrders => _currentOrders;
  List<OrderModel> get pastOrders => _pastOrders;
  List<OrderModel> get captainOrders => _captainOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderModel? get selectedOrder => _selectedOrder;
  CaptainModel? get selectedOrderCaptain => _selectedOrderCaptain;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  String _friendlyMessageFromException(Object e) {
    if (e is SocketException) {
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

  // ===== جلب طلبات المستخدم =====
  Future<void> fetchUserOrders(String userId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('orders')
          .select('*')
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
          .select('*')
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
          .select('*')
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      _captainOrders = (response as List)
          .map((o) => OrderModel.fromMap(o))
          .toList();
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات الكابتن', e);
      _setError(_friendlyMessageFromException(e));
      _captainOrders = [];
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
          .select('*, store:stores!inner(*)')
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
      return newOrder.id;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الطلب', e);
      _setError(_friendlyMessageFromException(e));
      return null;
    }
  }

  // ===== تحديث حالة الطلب =====
  Future<bool> updateOrderStatus(String orderId, dynamic status) async {
    try {
      String statusString = status is String ? status : status.toString();

      AppLogger.info('🔄 بدء تحديث الطلب $orderId إلى الحالة: $statusString');

      // محاولة التحديث المباشر أولاً
      final response = await _supabase
          .from('orders')
          .update({
            'status': statusString,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .select('id, status')
          .maybeSingle();

      // التحقق من نجاح التحديث
      if (response == null) {
        AppLogger.warning('⚠️ فشل التحديث المباشر - جاري تجربة RPC function');
        final rpcResult = await _tryUpdateViaRpc(orderId, statusString);
        if (rpcResult == null) {
          AppLogger.error('❌ فشل التحديث عبر RPC أيضاً');
          _setError('ليس لديك صلاحية لتحديث هذا الطلب');
          return false;
        }
      }

      _setError(null);

      // تحديث محلي
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: OrderStatus.fromString(statusString),
          updatedAt: DateTime.now(),
        );
        _categorizeOrders();
      }

      // تحديث الطلب المحدد إذا كان هو نفسه
      if (_selectedOrder?.id == orderId) {
        _selectedOrder = _selectedOrder!.copyWith(
          status: OrderStatus.fromString(statusString),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      AppLogger.info('✅ تم تحديث حالة الطلب $orderId إلى $statusString');
      return true;
    } on PostgrestException catch (e) {
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
      AppLogger.error('❌ خطأ في تحديث حالة الطلب', e);
      _setError(_friendlyMessageFromException(e));
      return false;
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

      // محاولة التحديث المباشر أولاً
      final response = await _supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .select('id, status')
          .maybeSingle();

      // التحقق من نجاح التحديث
      if (response == null) {
        AppLogger.warning('⚠️ فشل الإلغاء المباشر - جاري تجربة RPC function');
        final rpcResult = await _tryUpdateViaRpc(
          orderId,
          'cancelled',
          cancelReason: cancelReason,
        );
        if (rpcResult == null) {
          AppLogger.error('❌ فشل إلغاء الطلب - لا توجد صلاحية');
          _setError('فشل إلغاء الطلب - تحقق من الصلاحيات');
          return false;
        }
      }

      _setError(null);

      // تحديث محلي
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );
        _categorizeOrders();
      }

      // تحديث الطلب المحدد إذا كان هو نفسه
      if (_selectedOrder?.id == orderId) {
        _selectedOrder = _selectedOrder!.copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      AppLogger.info('✅ تم إلغاء الطلب بنجاح');
      return true;
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
          .select('*')
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
  void _handleNewOrder(Map<String, dynamic> orderData) {
    final newOrder = OrderModel.fromMap(orderData);
    _orders.insert(0, newOrder);
    _categorizeOrders();
  }

  void _handleOrderUpdate(Map<String, dynamic> orderData) {
    final updatedOrder = OrderModel.fromMap(orderData);
    final index = _orders.indexWhere((o) => o.id == updatedOrder.id);
    if (index != -1) {
      _orders[index] = updatedOrder;
      _categorizeOrders();
    }
  }

  void _handleOrderDelete(String orderId) {
    _orders.removeWhere((o) => o.id == orderId);
    _categorizeOrders();
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
    _unsubscribeChannel();
    notifyListeners();
  }

  // ===== تحديث موقع الكابتن =====
  Future<void> updateCaptainLocation({
    required String captainId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _supabase
          .from('captains')
          .update({
            'current_location': {'lat': latitude, 'lng': longitude},
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

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

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }
}
