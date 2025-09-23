import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/models/cart_model.dart';

class CartProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  final List<CartItem> _items = [];
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0.0;
  final String _userId;
  bool _isLoading = false;
  String? _error;
  final double _deliveryFee = 15.0; // Default delivery fee

  CartProvider(this._userId);

  // ===== Getters =====
  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get total => subtotal;
  double get deliveryFee => _deliveryFee;
  double get discount => _couponDiscount;
  double get finalTotal => total + deliveryFee - discount;
  bool get hasItems => _items.isNotEmpty;
  bool get hasCoupon => _appliedCoupon != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get couponCode => _appliedCoupon?.code;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ===== تهيئة السلة =====
  Future<void> initialize() async {
    await _loadCartFromSupabase();
  }

  // ===== تحميل السلة من Supabase =====
  Future<void> _loadCartFromSupabase() async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('cart')
          .eq('id', _userId)
          .single();

      if (response['cart'] != null) {
        final cartData = List<Map<String, dynamic>>.from(response['cart']);
        _items.clear();

        for (var item in cartData) {
          final productResponse = await _supabase
              .from('products')
              .select()
              .eq('id', item['productId'])
              .single();

          final product = ProductModel.fromJson(productResponse);
          _items.add(CartItem(
            product: product,
            quantity: item['quantity'],
          ));
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading cart: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== إضافة منتج للسلة =====
  Future<void> addItem(ProductModel product, {int quantity = 1}) async {
    try {
      final existingItemIndex = _items.indexWhere((item) => item.product.id == product.id);

      if (existingItemIndex != -1) {
        final existingItem = _items[existingItemIndex];
        _items[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + quantity
        );
      } else {
        _items.add(CartItem(product: product, quantity: quantity));
      }

      await _saveCartToSupabase();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error adding item to cart: $e');
      _setError(e.toString());
    }
  }

  // ===== زيادة كمية منتج =====
  Future<void> increaseQuantity(String productId) async {
    try {
      final index = _items.indexWhere((item) => item.product.id == productId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = item.copyWith(quantity: item.quantity + 1);
        await _saveCartToSupabase();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error increasing quantity: $e');
      _setError(e.toString());
    }
  }

  // ===== تقليل كمية منتج =====
  Future<void> decreaseQuantity(String productId) async {
    try {
      final index = _items.indexWhere((item) => item.product.id == productId);
      if (index != -1) {
        final item = _items[index];
        if (item.quantity > 1) {
          _items[index] = item.copyWith(quantity: item.quantity - 1);
        } else {
          _items.removeAt(index);
        }
        await _saveCartToSupabase();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error decreasing quantity: $e');
      _setError(e.toString());
    }
  }

  // ===== إزالة منتج من السلة =====
  Future<void> removeItem(String productId) async {
    try {
      _items.removeWhere((item) => item.product.id == productId);
      await _saveCartToSupabase();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error removing item: $e');
      _setError(e.toString());
    }
  }

  // ===== حفظ السلة في Supabase =====
  Future<void> _saveCartToSupabase() async {
    try {
      final cartData = _items.map((item) => item.toMap()).toList();
      await _supabase
          .from('profiles')
          .update({'cart': cartData})
          .eq('id', _userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error saving cart: $e');
      _setError(e.toString());
    }
  }

  // ===== تفريغ السلة =====
  Future<void> clear() async {
    _items.clear();
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    notifyListeners();
    await _saveCartToSupabase();
  }

  // ===== تطبيق كوبون خصم =====
  Future<bool> applyCoupon(String code) async {
    try {
      final response = await _supabase
          .from('coupons')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .single();

      final coupon = CouponModel.fromJson(response);

      if (coupon.isValid) {
        _appliedCoupon = coupon;
        _calculateDiscount();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error applying coupon: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== إلغاء الكوبون =====
  void removeCoupon() {
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    notifyListeners();
  }

  // ===== حساب قيمة الخصم =====
  void _calculateDiscount() {
    if (_appliedCoupon == null) {
      _couponDiscount = 0.0;
      return;
    }

    if (_appliedCoupon!.type == 'percentage') {
      _couponDiscount = subtotal * (_appliedCoupon!.value / 100);
    } else {
      _couponDiscount = _appliedCoupon!.value;
    }

    // Apply maximum discount if applicable (assuming max_value in the coupon)
    final maxValue = _appliedCoupon!.value;
    if (maxValue > 0) {
      _couponDiscount = _couponDiscount.clamp(0, maxValue);
    }
  }

  // ===== تفريغ السل�� =====
  Future<void> clearCart() async {
    _items.clear();
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    await _saveCartToSupabase();
    notifyListeners();
  }
}