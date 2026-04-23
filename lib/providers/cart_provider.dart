import 'dart:async';

import 'package:flutter/material.dart';
import '../core/logger.dart';
import '../services/cart_service.dart';
import '../services/location_service.dart';

class DeliveryModeConflict {
  final String message;
  final String? existingMode;
  final String? newMode;

  const DeliveryModeConflict({
    required this.message,
    this.existingMode,
    this.newMode,
  });
}

class StoreMinimumStatus {
  final String storeId;
  final String storeName;
  final double minimum;
  final double currentTotal;

  const StoreMinimumStatus({
    required this.storeId,
    required this.storeName,
    required this.minimum,
    required this.currentTotal,
  });

  double get remaining => (minimum - currentTotal).clamp(0, double.infinity);
}

class CartProvider with ChangeNotifier {
  CartProvider(this._userId) {
    if (_userId.isNotEmpty) {
      unawaited(loadCart());
    }
  }

  final List<Map<String, dynamic>> _cartItems = [];

  final String _userId;
  String? _cachedCartId; // تخزين معرف السلة لتجنب الاستعلام المتكرر
  bool _isLoading = false;
  String? _error;
  double _subtotal = 0.0;
  double _deliveryFee = 0.0;
  double _discount = 0.0;
  List<StoreMinimumStatus> _unmetMinimumStores = [];

  String? get cachedCartId => _cachedCartId;

  bool _disposed = false;

  List<Map<String, dynamic>> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get subtotal => _subtotal;
  double get deliveryFee => _deliveryFee;
  double get discount => _discount;
  bool get isEmpty => _cartItems.isEmpty;
  List<StoreMinimumStatus> get unmetMinimumStores => _unmetMinimumStores;

  void _notifyListeners() {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadCart() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    _notifyListeners();

    try {
      if (_userId.isEmpty) {
        _resetCart();
        return;
      }

      final cart = await CartService.getUserCart(_userId);
      if (cart == null) {
        _resetCart();
        return;
      }

      _cachedCartId = cart.id; // تخزين معرف السلة

      final items = await CartService.getCartItemsWithDetails(cart.id);
      _cartItems
        ..clear()
        ..addAll(
          items.map((item) {
            final product = item['products'] as Map<String, dynamic>?;
            return {...item, 'product': product};
          }),
        );

      _recalculateTotals();
    } catch (e) {
      _error = 'فشل تحميل السلة: $e';
      AppLogger.error('خطأ في تحميل السلة', e);
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> addToCart({
    required String productId,
    int quantity = 1,
    Map<String, dynamic>? selectedOptions,
  }) async {
    if (_userId.isEmpty) {
      _error = 'يرجى تسجيل الدخول أولاً';
      _notifyListeners();
      return false;
    }

    try {
      final result = await CartService.addToCart(
        userId: _userId,
        productId: productId,
        quantity: quantity,
        selectedOptions: selectedOptions,
        cachedCartId: _cachedCartId,
      );

      // ⚡ تحديث محلي سريع بدل إعادة تحميل السلة بالكامل
      if (result != null && _cachedCartId != null) {
        // البحث عن العنصر محلياً
        final existingIdx = _cartItems.indexWhere((item) {
          if (item['product_id'] != productId) return false;
          final itemOptions = item['selected_options'] as Map<String, dynamic>?;
          return _compareOptionsLocal(itemOptions, selectedOptions);
        });

        if (existingIdx != -1) {
          // تحديث الكمية محلياً
          _cartItems[existingIdx]['quantity'] = result.quantity;
        } else {
          // عنصر جديد - نحتاج بيانات المنتج الكاملة → نحمل السلة
          await loadCart();
          return true;
        }
        _recalculateTotals();
        _notifyListeners();
      } else {
        // أول مرة أو لا يوجد cache → نحمل السلة
        await loadCart();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('خطأ في إضافة المنتج للسلة', e);
      _notifyListeners();
      return false;
    }
  }

  /// مقارنة options محلياً
  static bool _compareOptionsLocal(
    Map<String, dynamic>? opt1,
    Map<String, dynamic>? opt2,
  ) {
    final o1 = opt1 == null || opt1.isEmpty ? null : opt1;
    final o2 = opt2 == null || opt2.isEmpty ? null : opt2;
    if (o1 == null && o2 == null) return true;
    if (o1 == null || o2 == null) return false;
    if (o1.length != o2.length) return false;
    for (final key in o1.keys) {
      if (o1[key]?.toString() != o2[key]?.toString()) return false;
    }
    return true;
  }

  Future<bool> updateQuantity({
    required String cartItemId,
    required int newQuantity,
  }) async {
    if (_userId.isEmpty) {
      _error = 'يرجى تسجيل الدخول أولاً';
      _notifyListeners();
      return false;
    }

    // ====== Optimistic Update: تحديث الواجهة فوراً ======
    int? oldQuantity;
    for (final item in _cartItems) {
      if (item['id'] == cartItemId) {
        oldQuantity = item['quantity'] as int?;
        item['quantity'] = newQuantity;
        break;
      }
    }
    _recalculateTotals();
    _notifyListeners();

    // ====== ثم حفظ التغيير في قاعدة البيانات ======
    try {
      await CartService.updateItemQuantity(
        userId: _userId,
        cartItemId: cartItemId,
        newQuantity: newQuantity,
      );
      return true;
    } catch (e) {
      // ====== Rollback: إرجاع الكمية القديمة لو فشل ======
      if (oldQuantity != null) {
        for (final item in _cartItems) {
          if (item['id'] == cartItemId) {
            item['quantity'] = oldQuantity;
            break;
          }
        }
        _recalculateTotals();
      }
      _error = e.toString();
      AppLogger.error('خطأ في تحديث كمية السلة', e);
      _notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(String cartItemId) async {
    if (_userId.isEmpty) {
      _error = 'يرجى تسجيل الدخول أولاً';
      _notifyListeners();
      return false;
    }

    // ====== Optimistic Update: حذف العنصر من الواجهة فوراً ======
    final removedIndex = _cartItems.indexWhere(
      (item) => item['id'] == cartItemId,
    );
    Map<String, dynamic>? removedItem;
    if (removedIndex != -1) {
      removedItem = Map<String, dynamic>.from(_cartItems[removedIndex]);
      _cartItems.removeAt(removedIndex);
      _recalculateTotals();
      _notifyListeners();
    }

    // ====== ثم حذف من قاعدة البيانات ======
    try {
      final success = await CartService.removeFromCart(
        userId: _userId,
        cartItemId: cartItemId,
      );
      if (!success && removedItem != null) {
        // Rollback لو السيرفر رفض الحذف
        _cartItems.insert(removedIndex, removedItem);
        _recalculateTotals();
        _notifyListeners();
      }
      return success;
    } catch (e) {
      // ====== Rollback: إرجاع العنصر لو فشل ======
      if (removedItem != null) {
        _cartItems.insert(removedIndex, removedItem);
        _recalculateTotals();
      }
      _error = e.toString();
      AppLogger.error('خطأ في حذف العنصر من السلة', e);
      _notifyListeners();
      return false;
    }
  }

  Future<bool> clearCart() async {
    if (_userId.isEmpty) {
      _resetCart();
      return true;
    }

    // ====== Optimistic Update: تفريغ الواجهة فوراً ======
    final backupItems = List<Map<String, dynamic>>.from(
      _cartItems.map((item) => Map<String, dynamic>.from(item)),
    );
    final backupSubtotal = _subtotal;
    final backupDeliveryFee = _deliveryFee;
    final backupDiscount = _discount;
    final backupUnmetMinimums = List<StoreMinimumStatus>.from(
      _unmetMinimumStores,
    );
    _resetCart();
    _notifyListeners();

    // ====== ثم حذف من قاعدة البيانات ======
    try {
      final success = await CartService.clearCart(_userId);
      if (!success) {
        // Rollback لو السيرفر رفض
        _cartItems.addAll(backupItems);
        _subtotal = backupSubtotal;
        _deliveryFee = backupDeliveryFee;
        _discount = backupDiscount;
        _unmetMinimumStores = backupUnmetMinimums;
        _notifyListeners();
      }
      return success;
    } catch (e) {
      // ====== Rollback: إرجاع كل العناصر لو فشل ======
      _cartItems.addAll(backupItems);
      _subtotal = backupSubtotal;
      _deliveryFee = backupDeliveryFee;
      _discount = backupDiscount;
      _unmetMinimumStores = backupUnmetMinimums;
      _error = e.toString();
      AppLogger.error('خطأ في تفريغ السلة', e);
      _notifyListeners();
      return false;
    }
  }

  /// فحص تعارض التوصيل باستخدام store_id المحلي (بدون استعلام إضافي)
  /// يُستدعى من cart_helper مع storeId من بيانات المنتج المتاحة محلياً
  DeliveryModeConflict? checkDeliveryModeConflictLocal({
    required String deliveryMode,
  }) {
    if (_cartItems.isEmpty) return null;

    final existingModes = <String>{};
    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      final store = product?['stores'] as Map<String, dynamic>?;
      final mode = (store?['delivery_mode'] as String?) ?? 'store';
      existingModes.add(mode);
    }

    if (existingModes.isEmpty) return null;
    if (existingModes.length == 1 && existingModes.first == deliveryMode) {
      return null;
    }

    final existingLabel = _deliveryModeLabel(existingModes.first);
    final newLabel = _deliveryModeLabel(deliveryMode);

    return DeliveryModeConflict(
      existingMode: existingModes.first,
      newMode: deliveryMode,
      message:
          'السلة تحتوي على منتجات بنظام توصيل $existingLabel ولا يمكن إضافة منتج بنظام توصيل $newLabel في نفس الطلب. هل تريد بدء سلة جديدة؟',
    );
  }

  /// فحص تعارض التوصيل بـ storeId — يتحقق من نظام التوصيل + نطاق التوصيل
  Future<DeliveryModeConflict?> checkDeliveryModeConflictByStoreId({
    required String productStoreId,
    double? userLat,
    double? userLng,
  }) async {
    if (_cartItems.isEmpty) return null;

    // استخراج delivery_mode للمتاجر الموجودة في السلة
    final existingModes = <String>{};

    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      final store = product?['stores'] as Map<String, dynamic>?;
      final storeId = store?['id'] as String?;
      final mode = (store?['delivery_mode'] as String?) ?? 'store';
      existingModes.add(mode);

      // لو المنتج الجديد من نفس متجر موجود بالسلة → مفيش تعارض
      if (storeId == productStoreId) return null;
    }

    if (existingModes.isEmpty) return null;

    // المنتج من متجر مختلف → نجلب delivery_mode للمتجر الجديد
    try {
      final newMode = await CartService.getStoreDeliveryMode(productStoreId);
      if (newMode == null) return null; // فشل الاستعلام → نسمح بالإضافة

      // ━━━━━ 1. فحص تعارض نظام التوصيل ━━━━━
      if (!(existingModes.length == 1 && existingModes.first == newMode)) {
        final existingLabel = _deliveryModeLabel(existingModes.first);
        final newLabel = _deliveryModeLabel(newMode);

        return DeliveryModeConflict(
          existingMode: existingModes.first,
          newMode: newMode,
          message:
              'السلة تحتوي على منتجات بنظام توصيل $existingLabel ولا يمكن إضافة منتج بنظام توصيل $newLabel في نفس الطلب. هل تريد بدء سلة جديدة؟',
        );
      }

      // ━━━━━ 2. فحص نطاق التوصيل (نفس النظام لكن متجر مختلف) ━━━━━
      if (userLat != null && userLng != null) {
        final deliveryCheck = await LocationService.canDeliverToLocation(
          storeId: productStoreId,
          latitude: userLat,
          longitude: userLng,
        );

        if (deliveryCheck != null) {
          final canDeliver = deliveryCheck['can_deliver'] as bool? ?? true;
          if (!canDeliver) {
            final distance = deliveryCheck['distance_km'] as double? ?? 0;
            return DeliveryModeConflict(
              existingMode: existingModes.first,
              newMode: newMode,
              message:
                  'هذا المتجر خارج نطاق التوصيل لموقعك الحالي '
                  '(${distance.toStringAsFixed(1)} كم). '
                  'السلة تحتوي على منتجات من متجر في نطاقك. '
                  'هل تريد مسح السلة وبدء طلب جديد؟',
            );
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من تعارض التوصيل', e);
      return null; // فشل → نسمح بالإضافة (الـ checkout هيتحقق)
    }
  }

  /// فحص تعارض التوصيل (async - يستعلم من السيرفر)
  Future<DeliveryModeConflict?> checkDeliveryModeConflict(
    String productId,
  ) async {
    if (_userId.isEmpty || _cartItems.isEmpty) return null;

    try {
      final newProduct = await CartService.getProductWithStore(productId);
      if (newProduct == null) return null;

      final newMode = (newProduct['delivery_mode'] as String?) ?? 'store';
      return checkDeliveryModeConflictLocal(deliveryMode: newMode);
    } catch (e) {
      AppLogger.error('خطأ في التحقق من تعارض التوصيل', e);
      return null;
    }
  }

  void _resetCart() {
    _cartItems.clear();
    _cachedCartId = null;
    _subtotal = 0.0;
    _deliveryFee = 0.0;
    _discount = 0.0;
    _unmetMinimumStores = [];
    _error = null;
    _isLoading = false;
    _notifyListeners();
  }

  void _recalculateTotals() {
    double subtotal = 0.0;
    final storeTotals = <String, double>{};
    final storeNames = <String, String>{};
    final storeMinimums = <String, double>{};
    final storeDeliveryFees = <String, double>{};
    final storeDeliveryModes = <String, String>{};

    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product == null) continue;

      final quantity = (item['quantity'] as int?) ?? 0;
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final lineTotal = price * quantity;
      subtotal += lineTotal;

      final store = product['stores'] as Map<String, dynamic>?;
      final storeId = (store?['id'] ?? item['store_id'] ?? product['store_id'])
          ?.toString();
      if (storeId == null) continue;

      storeTotals[storeId] = (storeTotals[storeId] ?? 0.0) + lineTotal;
      storeNames[storeId] = (store?['name'] as String?) ?? 'متجر';
      storeMinimums[storeId] = (store?['min_order'] as num?)?.toDouble() ?? 0.0;
      storeDeliveryFees[storeId] =
          (store?['delivery_fee'] as num?)?.toDouble() ?? 0.0;
      storeDeliveryModes[storeId] =
          (store?['delivery_mode'] as String?) ?? 'store';
    }

    _subtotal = subtotal;

    _deliveryFee = storeTotals.keys.fold(0.0, (sum, storeId) {
      final mode = storeDeliveryModes[storeId] ?? 'store';
      if (mode == 'store') {
        return sum + (storeDeliveryFees[storeId] ?? 0.0);
      }
      return sum;
    });

    _discount = 0.0;

    _unmetMinimumStores = storeTotals.entries
        .where((entry) {
          final minimum = storeMinimums[entry.key] ?? 0.0;
          return minimum > 0 && entry.value < minimum;
        })
        .map(
          (entry) => StoreMinimumStatus(
            storeId: entry.key,
            storeName: storeNames[entry.key] ?? 'متجر',
            minimum: storeMinimums[entry.key] ?? 0.0,
            currentTotal: entry.value,
          ),
        )
        .toList();
  }

  String _deliveryModeLabel(String mode) {
    switch (mode) {
      case 'app':
        return 'التطبيق';
      case 'store':
      default:
        return 'المتجر';
    }
  }
}
