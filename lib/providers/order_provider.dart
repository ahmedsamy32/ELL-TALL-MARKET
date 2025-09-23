import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:ell_tall_market/core/api_client.dart';

import '../models/cart_model.dart';
import '../models/shipping_address.dart';

class OrderProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
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

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  OrderProvider() {
    _initRealtimeSubscription();
  }

  void _initRealtimeSubscription() {
    _ordersChannel = _supabase
        .channel('orders_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (PostgresChangePayload payload) {
            final record = payload.newRecord;
            final oldRecord = payload.oldRecord;

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleNewOrder(record);
                break;
              case PostgresChangeEvent.update:
                _handleOrderUpdate(record);
                break;
              case PostgresChangeEvent.delete:
                _handleOrderDelete(oldRecord['id'] as String);
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
      final orders = await _apiClient.getUserOrders(userId);
      _orders = orders.map((o) => OrderModel.fromJson(o)).toList();
      _categorizeOrders();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user orders: $e');
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
          .select('*, profiles!orders_user_id_fkey(*)')
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromJson(o)).toList();
      _categorizeOrders();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching all orders: $e');
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
          .select('*, profiles!orders_user_id_fkey(*)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      _orders = (response as List).map((o) => OrderModel.fromJson(o)).toList();
      _categorizeOrders();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching store orders: $e');
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
          .select('*, profiles!orders_user_id_fkey(*)')
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      _captainOrders = (response as List).map((o) => OrderModel.fromJson(o)).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching captain orders: $e');
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

      _orders = response.map((o) => OrderModel.fromJson(o)).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching merchant orders: $e');
      _setError(e.toString());
      _orders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء طلب جديد =====
  Future<bool> createOrder(OrderModel order) async {
    try {
      final response = await _apiClient.createOrder(order.toJson());
      final newOrder = OrderModel.fromJson(response);
      _orders.insert(0, newOrder);
      _categorizeOrders();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error creating order: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== تحديث حالة الطلب =====
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status.toString()})
          .eq('id', orderId);

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(status: status);
        _categorizeOrders();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error updating order status: $e');
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
          .select('*, profiles!orders_user_id_fkey(*)')
          .eq('id', orderId)
          .single();
      _selectedOrder = OrderModel.fromJson(response);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('�� Error fetching order by ID: $e');
      _setError(e.toString());
      _selectedOrder = null;
    } finally {
      _setLoading(false);
    }
  }

  // ===== تصنيف الطلبات =====
  void _categorizeOrders() {
    _currentOrders = _orders.where((order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList();

    _pastOrders = _orders.where((order) =>
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled
    ).toList();
    notifyListeners();
  }

  // ===== معالجة التحديثات في الوقت الحقيقي =====
  void _handleNewOrder(Map<String, dynamic> orderData) {
    final newOrder = OrderModel.fromJson(orderData);
    _orders.insert(0, newOrder);
    _categorizeOrders();
  }

  void _handleOrderUpdate(Map<String, dynamic> orderData) {
    final updatedOrder = OrderModel.fromJson(orderData);
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

  List<OrderModel> getOrdersByStatus(OrderStatus status) {
    return _captainOrders.where((order) => order.status == status).toList();
  }

  Future<void> startOrderTracking(String orderId) async {
    try {
      // Subscribe to order updates
      _ordersChannel = _supabase
          .channel('order_tracking_$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: orderId,
            ),
            callback: (payload) async {
              // Refresh order details when changes occur
              await getOrderById(orderId);
            },
          )
          .subscribe();

      // Subscribe to captain location updates if order has a captain
      if (_selectedOrder?.captainId != null) {
        _ordersChannel = _supabase
            .channel('captain_location_${_selectedOrder!.captainId}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'captain_locations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'captain_id',
                value: _selectedOrder!.captainId,
              ),
              callback: (payload) async {
                // Update captain's location
                await updateCaptainLocation(orderId);
              },
            )
            .subscribe();
      }
    } catch (e) {
      debugPrint('Error starting order tracking: $e');
      _setError('حدث خطأ في تتبع الطلب');
    }
  }

  Future<void> updateCaptainLocation(String orderId) async {
    try {
      if (_selectedOrder?.captainId == null) return;

      final response = await _supabase
          .from('captain_locations')
          .select()
          .eq('captain_id', _selectedOrder!.captainId!)
          .single();

      // Update captain model with new location
      _selectedOrderCaptain = _selectedOrderCaptain?.copyWith(
        currentLocation: Location(
          latitude: response['latitude'] as double,
          longitude: response['longitude'] as double,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating captain location: $e');
    }
  }

  // ===== إنشاء طلب من السلة =====
  Future<void> createOrderFromCart(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Get cart items from Supabase
      final cartItems = await _supabase
          .from('cart_items')
          .select('*, products(*)')
          .eq('user_id', userId);

      if ((cartItems as List).isEmpty) {
        throw 'السلة فارغة';
      }

      // Group items by store
      final storeGroups = <String, List<Map<String, dynamic>>>{};
      for (final item in cartItems) {
        final storeId = item['products']['store_id'] as String;
        if (!storeGroups.containsKey(storeId)) {
          storeGroups[storeId] = [];
        }
        storeGroups[storeId]!.add(item);
      }

      // Create an order for each store
      for (final entry in storeGroups.entries) {
        final storeId = entry.key;
        final items = entry.value;

        // Calculate totals
        double subtotal = 0;
        final orderItems = items.map((item) {
          final product = item['products'];
          final quantity = item['quantity'] as int;
          final price = product['price'] as double;
          final total = price * quantity;
          subtotal += total;

          return {
            'product_id': item['product_id'],
            'quantity': quantity,
            'unit_price': price,
            'total_price': total,
          };
        }).toList();

        // Get user's address and payment method
        final userProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();

        // Create the order
        await _supabase.from('orders').insert({
          'user_id': userId,
          'store_id': storeId,
          'status': 'pending',
          'total_amount': subtotal,
          'delivery_fee': 10.0, // Fixed delivery fee
          'final_amount': subtotal + 10.0,
          'payment_method': userProfile['preferred_payment_method'] ?? 'cash_on_delivery',
          'payment_status': 'pending',
          'items': orderItems,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Clear cart after creating orders
      await _supabase
          .from('cart_items')
          .delete()
          .eq('user_id', userId);

      // Refresh orders list
      await fetchUserOrders(userId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء طلب جديد مع المعلمات الصحيحة =====
  Future<OrderModel> createOrderFromCheckout({
    required List<CartItem> cartItems,
    required ShippingAddress shippingAddress,
    required PaymentMethod paymentMethod,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate order totals
      double subtotal = cartItems.fold(0.0, (sum, item) => sum + (item.quantity * item.product.price));
      const double deliveryFee = 10.0; // Fixed delivery fee
      final double totalAmount = subtotal + deliveryFee;

      final orderData = {
        'user_id': user.id,
        'store_id': cartItems.first.product.storeId, // Assuming all items are from same store
        'status': OrderStatus.pending.toString().split('.').last,
        'delivery_address': shippingAddress.formattedAddress,
        'delivery_location': shippingAddress.coordinates != null
            ? '${shippingAddress.coordinates!['lat']},${shippingAddress.coordinates!['lng']}'
            : null,
        'notes': notes,
        'payment_method': paymentMethod.toString().split('.').last,
        'payment_status': PaymentStatus.pending.toString().split('.').last,
        'total_amount': subtotal,
        'delivery_fee': deliveryFee,
        'final_amount': totalAmount,
        'items': cartItems.map((item) => {
          'product_id': item.product.id,
          'quantity': item.quantity,
          'unit_price': item.product.price,
          'total_price': item.quantity * item.product.price,
        }).toList(),
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
      return newOrder;
    } catch (e) {
      _setError('Failed to create order: $e');
      throw Exception('Failed to create order');
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
