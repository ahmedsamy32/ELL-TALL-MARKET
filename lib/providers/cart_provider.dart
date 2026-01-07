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
  final Map<String, double> _storeMinimums = {};
  final Map<String, double> _storeSubtotals = {};
  final Map<String, String> _storeNames = {};

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
  Map<String, double> get storeMinimums => Map.unmodifiable(_storeMinimums);
  Map<String, double> get storeSubtotals => Map.unmodifiable(_storeSubtotals);
  Map<String, String> get storeNames => Map.unmodifiable(_storeNames);
  List<StoreMinimumStatus> get storeMinimumStatuses => _storeMinimums.entries
      .map(
        (entry) => StoreMinimumStatus(
          storeId: entry.key,
          storeName: _storeNames[entry.key] ?? 'المتجر',
          minimum: entry.value,
          subtotal: _storeSubtotals[entry.key] ?? 0.0,
        ),
      )
      .toList();
  List<StoreMinimumStatus> get unmetMinimumStores =>
      storeMinimumStatuses.where((status) => !status.isMet).toList();
  bool get meetsMinimumOrder => unmetMinimumStores.isEmpty;
  bool get canCheckout => hasItems && meetsMinimumOrder;

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
        final rawItems = await CartService.getCartItemsWithDetails(_cart!.id);

        // إعادة تنسيق البيانات: نقل products إلى product
        _cartItems = rawItems.map((item) {
          // إذا كان products موجود كـ nested object، انقله إلى product
          if (item['products'] != null && item['product'] == null) {
            item['product'] = item['products'];
            item.remove('products');
          }
          return item;
        }).toList();

        _rebuildStoreMinimums();

        // حساب الإجماليات
        await _updateCartTotal();

        AppLogger.info('تم تحميل السلة بنجاح: ${_cartItems.length} عنصر');
      } else {
        _cartItems = [];
        _cartTotal = null;
        _resetStoreMinimums();
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

  /// التحقق من توافق نظام التوصيل قبل إضافة منتج (نسخة سريعة محسّنة)
  /// يمنع إضافة منتجات من متاجر مختلفة في حالات معينة
  Future<DeliveryModeConflict?> checkDeliveryModeConflict(
    String productId,
  ) async {
    try {
      // إذا كانت السلة فارغة، لا يوجد تعارض (فحص سريع)
      if (_cartItems.isEmpty) return null;

      // الحصول على معلومات المتجر الحالي من السلة (بدون استدعاء قاعدة بيانات)
      final firstItem = _cartItems.first;
      final currentProduct = firstItem['product'] as Map<String, dynamic>?;
      if (currentProduct == null) return null;

      final currentStore = currentProduct['stores'] as Map<String, dynamic>?;
      if (currentStore == null) return null;

      final currentStoreDeliveryMode = currentStore['delivery_mode'] as String?;
      final currentStoreName = currentStore['name'] as String?;
      final currentStoreId = currentStore['id'] as String?;

      // جلب معلومات المنتج والمتجر الجديد
      final productInfo = await CartService.getProductWithStore(productId);
      if (productInfo == null) return null;

      final newStoreId = productInfo['store_id'] as String?;

      // إذا كان نفس المتجر، لا يوجد تعارض (فحص سريع)
      if (currentStoreId == newStoreId) return null;

      final newStoreDeliveryMode = productInfo['delivery_mode'] as String?;
      final newStoreName = productInfo['store_name'] as String?;

      // ✅ التحقق من التعارض:
      // 1. إذا كان المتجر الحالي "store" → لا يمكن إضافة من متجر آخر (حتى لو store)
      // 2. إذا كان المتجر الحالي "app" والجديد "store" → تعارض
      // 3. إذا كان كلاهما "app" → مسموح (نفس نظام التوصيل الموحد)

      final hasConflict =
          currentStoreDeliveryMode == 'store' ||
          (currentStoreDeliveryMode == 'app' &&
              newStoreDeliveryMode == 'store');

      if (hasConflict) {
        return DeliveryModeConflict(
          currentStoreName: currentStoreName ?? 'المتجر الحالي',
          currentDeliveryMode: currentStoreDeliveryMode ?? 'store',
          newStoreName: newStoreName ?? 'المتجر الجديد',
          newDeliveryMode: newStoreDeliveryMode ?? 'store',
        );
      }

      return null;
    } catch (e) {
      AppLogger.error('خطأ في فحص تعارض نظام التوصيل', e);
      return null;
    }
  }

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

    // 🚀 تحديث فوري للواجهة قبل الاتصال بقاعدة البيانات
    final itemIndex = _cartItems.indexWhere((item) => item['id'] == cartItemId);
    if (itemIndex != -1) {
      final oldQuantity = _cartItems[itemIndex]['quantity'] as int;

      // تحديث الكمية مؤقتاً في الواجهة
      _cartItems[itemIndex]['quantity'] = newQuantity;

      // إعادة حساب total_price للعنصر
      final product = _cartItems[itemIndex]['product'] as Map<String, dynamic>?;
      if (product != null) {
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;
        _cartItems[itemIndex]['total_price'] = price * newQuantity;
      }

      notifyListeners(); // تحديث الواجهة فوراً

      try {
        // تحديث في قاعدة البيانات في الخلفية
        final updatedItem = await CartService.updateItemQuantity(
          userId: _clientId,
          cartItemId: cartItemId,
          newQuantity: newQuantity,
        );

        if (updatedItem != null) {
          // إعادة تحميل السلة للتأكد من التزامن
          await loadCart();
          AppLogger.info('تم تحديث كمية المنتج');
          return true;
        } else {
          // إذا فشل، استرجع الكمية القديمة
          _cartItems[itemIndex]['quantity'] = oldQuantity;
          if (product != null) {
            final price = (product['price'] as num?)?.toDouble() ?? 0.0;
            _cartItems[itemIndex]['total_price'] = price * oldQuantity;
          }
          notifyListeners();
          _setError('فشل تحديث كمية المنتج');
          return false;
        }
      } catch (e) {
        // إذا حدث خطأ، استرجع الكمية القديمة
        _cartItems[itemIndex]['quantity'] = oldQuantity;
        if (product != null) {
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          _cartItems[itemIndex]['total_price'] = price * oldQuantity;
        }
        notifyListeners();

        // استخراج رسالة الخطأ الواضحة
        String errorMessage = 'خطأ في تحديث الكمية';
        final errorString = e.toString();

        // التحقق من خطأ تجاوز المخزون
        if (errorString.contains('الكمية المطلوبة تتجاوز المخزون المتاح')) {
          final match = RegExp(
            r'المخزون المتاح \((\d+)\)',
          ).firstMatch(errorString);
          if (match != null) {
            final stock = match.group(1);
            errorMessage = 'المخزون المتاح فقط $stock';
          } else {
            errorMessage = 'الكمية المطلوبة تتجاوز المخزون المتاح';
          }
        } else if (errorString.contains('Exception:')) {
          // استخراج رسالة الاستثناء فقط
          errorMessage = errorString.replaceAll('Exception:', '').trim();
          if (errorMessage.startsWith('فشل تحديث كمية المنتج:')) {
            errorMessage = errorMessage
                .replaceFirst('فشل تحديث كمية المنتج:', '')
                .trim();
          }
        }

        _setError(errorMessage);
        return false;
      }
    }

    _setError('العنصر غير موجود في السلة');
    return false;
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
        _resetStoreMinimums();
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

  void _rebuildStoreMinimums() {
    _storeMinimums.clear();
    _storeSubtotals.clear();
    _storeNames.clear();

    for (final item in _cartItems) {
      final product = item['products'] as Map<String, dynamic>?;
      if (product == null) continue;

      final store = product['stores'] as Map<String, dynamic>?;
      final storeId = store?['id'] as String?;
      if (storeId == null) continue;

      final storeName = store?['name'] as String? ?? 'المتجر';
      _storeNames[storeId] = storeName;

      final minOrder = (store?['min_order'] as num?)?.toDouble() ?? 0.0;
      if (!_storeMinimums.containsKey(storeId) || minOrder > 0) {
        _storeMinimums[storeId] = minOrder;
      }

      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final lineTotal = price * quantity;
      _storeSubtotals[storeId] = (_storeSubtotals[storeId] ?? 0.0) + lineTotal;
    }
  }

  void _resetStoreMinimums() {
    _storeMinimums.clear();
    _storeSubtotals.clear();
    _storeNames.clear();
  }

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
    _resetStoreMinimums();
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

class StoreMinimumStatus {
  final String storeId;
  final String storeName;
  final double minimum;
  final double subtotal;

  const StoreMinimumStatus({
    required this.storeId,
    required this.storeName,
    required this.minimum,
    required this.subtotal,
  });

  bool get isMet => minimum <= 0 || subtotal >= minimum;
  double get remaining => isMet ? 0 : (minimum - subtotal);
}

/// معلومات تعارض نظام التوصيل
class DeliveryModeConflict {
  final String currentStoreName;
  final String currentDeliveryMode;
  final String newStoreName;
  final String newDeliveryMode;

  const DeliveryModeConflict({
    required this.currentStoreName,
    required this.currentDeliveryMode,
    required this.newStoreName,
    required this.newDeliveryMode,
  });

  String get currentDeliveryModeLabel =>
      currentDeliveryMode == 'store' ? 'توصيل المتجر' : 'توصيل التطبيق';

  String get newDeliveryModeLabel =>
      newDeliveryMode == 'store' ? 'توصيل المتجر' : 'توصيل التطبيق';

  String get message {
    // رسالة مختصرة وواضحة
    return 'بدء سلة جديدة؟\n\n'
        'عند بدء طلب جديد ستتم إزالة سلة مشترياتك من "$currentStoreName"';
  }
}
