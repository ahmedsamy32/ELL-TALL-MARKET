import 'dart:async';
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
      _setError(e.toString());
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
      _setError(e.toString());
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
      _setError(e.toString());
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
      _setError(e.toString());
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
          .select('*, store:stores(*)')
          .eq('store.merchant_id', merchantId)
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromMap(o)).toList();
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات التاجر', e);
      _setError(e.toString());
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء طلب جديد =====
  Future<bool> createOrder(OrderModel order) async {
    try {
      final orderData = {
        'client_id': order.clientId,
        'merchant_id': order.merchantId,
        'captain_id': order.captainId,
        'status': order.status,
        'total_amount': order.totalAmount,
        'delivery_address': order.deliveryAddress,
        'notes': order.notes,
        'created_at': DateTime.now().toIso8601String(),
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
      return true;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الطلب', e);
      _setError(e.toString());
      return false;
    }
  }

  // ===== تحديث حالة الطلب =====
  Future<bool> updateOrderStatus(String orderId, dynamic status) async {
    try {
      String statusString = status is String ? status : status.toString();

      await _supabase
          .from('orders')
          .update({'status': statusString})
          .eq('id', orderId);

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: OrderStatus.fromString(statusString),
        );
        _categorizeOrders();
      }
      AppLogger.info('تم تحديث حالة الطلب $orderId إلى $statusString');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة الطلب', e);
      _setError(e.toString());
      return false;
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
          (order) => order.status != 'delivered' && order.status != 'cancelled',
        )
        .toList();

    _pastOrders = _orders
        .where(
          (order) => order.status == 'delivered' || order.status == 'cancelled',
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
