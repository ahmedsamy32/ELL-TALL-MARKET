import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/cart_model.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/services/cart_service.dart';
import 'package:ell_tall_market/core/logger.dart';

/// مزود حالة سلة التسوق
/// يعمل مع CartService لإدارة حالة السلة في واجهة المستخدم
class CartProvider with ChangeNotifier {
  final String _clientId;

  // حالة السلة
  CartModel? _cart;
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _cartTotal;

  // حالة الكوبون
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0.0;

  // حالة التحميل والأخطاء
  bool _isLoading = false;
  String? _error;

  CartProvider(this._clientId);

  // ================================
  // Getters
  // ================================

  CartModel? get cart => _cart;
  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_cartItems);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // معلومات السلة
  bool get isEmpty => _cartItems.isEmpty;
  bool get hasItems => _cartItems.isNotEmpty;
  int get itemCount => _cartTotal?['totalItems'] ?? 0;
  int get uniqueProductsCount => _cartTotal?['uniqueProducts'] ?? 0;

  // المبالغ المالية
  double get subtotal => (_cartTotal?['subtotal'] ?? 0.0).toDouble();
  double get deliveryFee => (_cartTotal?['deliveryFee'] ?? 0.0).toDouble();
  double get tax => (_cartTotal?['tax'] ?? 0.0).toDouble();
  double get discount => _couponDiscount;
  double get total => subtotal + deliveryFee + tax - discount;

  // معلومات الكوبون
  bool get hasCoupon => _appliedCoupon != null;
  CouponModel? get appliedCoupon => _appliedCoupon;
  String? get couponCode => _appliedCoupon?.code;

  // ================================
  // تهيئة السلة
  // ================================

  /// تهيئة وتحميل السلة
  Future<void> initialize() async {
    await loadCart();
  }

  /// تحميل السلة من قاعدة البيانات
  Future<void> loadCart() async {
    _setLoading(true);
    _clearError();

    try {
      // الحصول على السلة أو إنشاؤها
      _cart = await CartService.getUserCart(_clientId);

      if (_cart != null) {
        // تحميل العناصر مع تفاصيل المنتجات
        _cartItems = await CartService.getCartItemsWithDetails(_cart!.id);

        // حساب الإجماليات
        await _updateCartTotal();

        AppLogger.info('تم تحميل السلة بنجاح: ${_cartItems.length} عنصر');
      } else {
        _cartItems = [];
        _cartTotal = null;
        AppLogger.warning('لم يتم العثور على سلة للمستخدم');
      }
    } catch (e) {
      _setError('فشل تحميل السلة: ${e.toString()}');
      AppLogger.error('خطأ في تحميل السلة', e);
    } finally {
      _setLoading(false);
    }
  }

  // ================================
  // إدارة عناصر السلة
  // ================================

  /// إضافة منتج للسلة
  Future<bool> addToCart({required String productId, int quantity = 1}) async {
    _clearError();

    try {
      final cartItem = await CartService.addToCart(
        userId: _clientId,
        productId: productId,
        quantity: quantity,
      );

      if (cartItem != null) {
        await loadCart(); // إعادة تحميل السلة
        AppLogger.info('تم إضافة المنتج للسلة بنجاح');
        return true;
      }

      _setError('فشل إضافة المنتج للسلة');
      return false;
    } catch (e) {
      _setError('خطأ في إضافة المنتج: ${e.toString()}');
      AppLogger.error('خطأ في إضافة المنتج للسلة', e);
      return false;
    }
  }

  /// تحديث كمية منتج في السلة
  Future<bool> updateQuantity({
    required String cartItemId,
    required int newQuantity,
  }) async {
    _clearError();

    try {
      final updatedItem = await CartService.updateItemQuantity(
        userId: _clientId,
        cartItemId: cartItemId,
        newQuantity: newQuantity,
      );

      if (updatedItem != null) {
        await loadCart(); // إعادة تحميل السلة
        AppLogger.info('تم تحديث كمية المنتج');
        return true;
      }

      _setError('فشل تحديث كمية المنتج');
      return false;
    } catch (e) {
      _setError('خطأ في تحديث الكمية: ${e.toString()}');
      AppLogger.error('خطأ في تحديث كمية المنتج', e);
      return false;
    }
  }

  /// زيادة كمية منتج
  Future<bool> increaseQuantity(String cartItemId) async {
    final item = _cartItems.firstWhere(
      (item) => item['id'] == cartItemId,
      orElse: () => {},
    );

    if (item.isEmpty) return false;

    final currentQuantity = item['quantity'] as int;
    return await updateQuantity(
      cartItemId: cartItemId,
      newQuantity: currentQuantity + 1,
    );
  }

  /// تقليل كمية منتج
  Future<bool> decreaseQuantity(String cartItemId) async {
    final item = _cartItems.firstWhere(
      (item) => item['id'] == cartItemId,
      orElse: () => {},
    );

    if (item.isEmpty) return false;

    final currentQuantity = item['quantity'] as int;

    if (currentQuantity <= 1) {
      // حذف المنتج إذا كانت الكمية 1
      return await removeItem(cartItemId);
    }

    return await updateQuantity(
      cartItemId: cartItemId,
      newQuantity: currentQuantity - 1,
    );
  }

  /// حذف منتج من السلة
  Future<bool> removeItem(String cartItemId) async {
    _clearError();

    try {
      final success = await CartService.removeFromCart(
        userId: _clientId,
        cartItemId: cartItemId,
      );

      if (success) {
        await loadCart(); // إعادة تحميل السلة
        AppLogger.info('تم حذف المنتج من السلة');
        return true;
      }

      _setError('فشل حذف المنتج من السلة');
      return false;
    } catch (e) {
      _setError('خطأ في حذف المنتج: ${e.toString()}');
      AppLogger.error('خطأ في حذف المنتج من السلة', e);
      return false;
    }
  }

  /// تفريغ السلة بالكامل
  Future<bool> clearCart() async {
    _clearError();

    try {
      final success = await CartService.clearCart(_clientId);

      if (success) {
        _cartItems.clear();
        _cartTotal = null;
        _appliedCoupon = null;
        _couponDiscount = 0.0;
        notifyListeners();

        AppLogger.info('تم تفريغ السلة بنجاح');
        return true;
      }

      _setError('فشل تفريغ السلة');
      return false;
    } catch (e) {
      _setError('خطأ في تفريغ السلة: ${e.toString()}');
      AppLogger.error('خطأ في تفريغ السلة', e);
      return false;
    }
  }

  // ================================
  // إدارة الكوبونات
  // ================================

  /// تطبيق كوبون خصم
  Future<bool> applyCoupon(String couponCode) async {
    _clearError();

    if (isEmpty) {
      _setError('لا يمكن تطبيق الكوبون على سلة فارغة');
      return false;
    }

    try {
      final coupon = await _validateCoupon(couponCode);

      if (coupon != null && coupon.isValid) {
        _appliedCoupon = coupon;
        _calculateCouponDiscount();
        notifyListeners();

        AppLogger.info('تم تطبيق الكوبون: ${coupon.code}');
        return true;
      }

      _setError('الكوبون غير صالح أو منتهي الصلاحية');
      return false;
    } catch (e) {
      _setError('خطأ في تطبيق الكوبون: ${e.toString()}');
      AppLogger.error('خطأ في تطبيق الكوبون', e);
      return false;
    }
  }

  /// إلغاء الكوبون
  void removeCoupon() {
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    notifyListeners();
    AppLogger.info('تم إلغاء الكوبون');
  }

  /// التحقق من صلاحية الكوبون
  Future<CouponModel?> _validateCoupon(String code) async {
    try {
      // هنا يمكنك إضافة منطق للتحقق من الكوبون من قاعدة البيانات
      // مؤقتاً سنعيد null
      return null;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من الكوبون', e);
      return null;
    }
  }

  /// حساب قيمة خصم الكوبون
  void _calculateCouponDiscount() {
    if (_appliedCoupon == null) {
      _couponDiscount = 0.0;
      return;
    }

    if (_appliedCoupon!.couponType == CouponType.percentage) {
      // خصم بالنسبة المئوية
      _couponDiscount = subtotal * (_appliedCoupon!.discountValue / 100);

      // تطبيق الحد الأقصى للخصم إن وجد
      if (_appliedCoupon!.maximumDiscountAmount != null) {
        _couponDiscount = _couponDiscount.clamp(
          0,
          _appliedCoupon!.maximumDiscountAmount!,
        );
      }
    } else {
      // خصم بقيمة ثابتة
      _couponDiscount = _appliedCoupon!.discountValue;
    }

    // التأكد من أن الخصم لا يتجاوز المجموع الفرعي
    _couponDiscount = _couponDiscount.clamp(0, subtotal);
  }

  // ================================
  // عمليات مساعدة
  // ================================

  /// تحديث إجماليات السلة
  Future<void> _updateCartTotal() async {
    try {
      _cartTotal = await CartService.calculateCartTotal(_clientId);

      // إعادة حساب خصم الكوبون إذا كان مطبقاً
      if (_appliedCoupon != null) {
        _calculateCouponDiscount();
      }
    } catch (e) {
      AppLogger.error('خطأ في حساب إجماليات السلة', e);
    }
  }

  /// الحصول على منتج من السلة
  Map<String, dynamic>? getCartItem(String cartItemId) {
    try {
      return _cartItems.firstWhere((item) => item['id'] == cartItemId);
    } catch (e) {
      return null;
    }
  }

  /// التحقق من وجود منتج في السلة
  bool isProductInCart(String productId) {
    return _cartItems.any((item) => item['product_id'] == productId);
  }

  /// الحصول على كمية منتج في السلة
  int getProductQuantity(String productId) {
    try {
      final item = _cartItems.firstWhere(
        (item) => item['product_id'] == productId,
      );
      return item['quantity'] as int;
    } catch (e) {
      return 0;
    }
  }

  /// إعادة المحاولة بعد حدوث خطأ
  Future<void> retry() async {
    await loadCart();
  }

  /// تحديث السلة (إعادة التحميل)
  Future<void> refresh() async {
    await loadCart();
  }

  // ================================
  // إدارة الحالة
  // ================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    if (value != null) {
      AppLogger.error('خطأ في CartProvider: $value');
    }
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// إعادة تعيين الحالة
  void resetState() {
    _cart = null;
    _cartItems = [];
    _cartTotal = null;
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    _isLoading = false;
    _error = null;
    notifyListeners();
    AppLogger.info('تم إعادة تعيين حالة السلة');
  }

  @override
  void dispose() {
    // تنظيف الموارد
    super.dispose();
  }
}
