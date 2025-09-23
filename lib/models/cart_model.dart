// lib/models/cart_model.dart

import 'package:ell_tall_market/models/product_model.dart';

class CartItem {
  final ProductModel product;
  final int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  String get productId => product.id;
  double get totalPrice => product.price * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: ProductModel.fromJson(map['product']),
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartModel {
  final String id;
  final String userId;
  final List<CartItem> items;
  final DateTime lastUpdated;
  final String? couponCode;
  final double? couponDiscount;

  const CartModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.lastUpdated,
    this.couponCode,
    this.couponDiscount,
  });

  factory CartModel.fromMap(Map<String, dynamic> data) {
    return CartModel(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      items: List<CartItem>.from(
        (data['items'] ?? []).map((item) => CartItem.fromMap(item)),
      ),
      lastUpdated: DateTime.tryParse(data['lastUpdated'] ?? '') ?? DateTime.now(),
      couponCode: data['couponCode'],
      couponDiscount: (data['couponDiscount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'couponCode': couponCode,
      'couponDiscount': couponDiscount,
    };
  }

  // --- Getters ---
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get total {
    final discount = couponDiscount ?? 0;
    return subtotal - discount;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  // --- Immutable operations (copyWith) ---
  CartModel copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    DateTime? lastUpdated,
    String? couponCode,
    double? couponDiscount,
  }) {
    return CartModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      couponCode: couponCode ?? this.couponCode,
      couponDiscount: couponDiscount ?? this.couponDiscount,
    );
  }

  CartModel addItem(CartItem item) {
    final existingIndex = items.indexWhere((i) => i.productId == item.productId);
    final newItems = List<CartItem>.from(items);

    if (existingIndex >= 0) {
      newItems[existingIndex] = CartItem(
        product: newItems[existingIndex].product,
        quantity: newItems[existingIndex].quantity + item.quantity,
      );
    } else {
      newItems.add(item);
    }

    return copyWith(items: newItems, lastUpdated: DateTime.now());
  }

  CartModel removeItem(String productId) {
    final newItems = items.where((item) => item.productId != productId).toList();
    return copyWith(items: newItems, lastUpdated: DateTime.now());
  }

  CartModel updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(productId);
    }

    final newItems = items.map((item) {
      if (item.productId == productId) {
        return CartItem(
          product: item.product,
          quantity: newQuantity,
        );
      }
      return item;
    }).toList();

    return copyWith(items: newItems, lastUpdated: DateTime.now());
  }

  CartModel clear() {
    return copyWith(
      items: [],
      couponCode: null,
      couponDiscount: null,
      lastUpdated: DateTime.now(),
    );
  }

  bool containsProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }
}
