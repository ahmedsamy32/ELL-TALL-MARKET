/// Cart models that match the Supabase cart and cart_items tables
/// Updated to match the new comprehensive schema
library;

import 'package:intl/intl.dart';

/// Base mixin for common model functionality
mixin BaseModelMixin {
  String get id;
  DateTime get createdAt;
  DateTime? get updatedAt;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get updatedAtFormatted => updatedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(updatedAt!)
      : 'لم يتم التحديث';

  static DateTime parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }
}

/// Cart model that matches the Supabase carts table
/// سلة متعددة المتاجر مع تفاصيل التوصيل والخصومات
class CartModel with BaseModelMixin {
  static const String tableName = 'carts';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String userId; // UUID REFERENCES auth.users(id) ON DELETE CASCADE

  // معلومات السلة
  final double totalAmount; // DECIMAL(10,2) DEFAULT 0
  final int itemsCount; // INT DEFAULT 0

  // معلومات التوصيل
  final String? deliveryAddress; // TEXT
  final double? deliveryLatitude; // DECIMAL(10, 8)
  final double? deliveryLongitude; // DECIMAL(11, 8)

  // الخصومات
  final String? couponCode; // TEXT
  final double discountAmount; // DECIMAL(10,2) DEFAULT 0

  // الحالة
  final bool isActive; // BOOLEAN DEFAULT TRUE

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const CartModel({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.itemsCount,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.couponCode,
    required this.discountAmount,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory CartModel.fromMap(Map<String, dynamic> map) {
    return CartModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      itemsCount: (map['items_count'] as int?) ?? 0,
      deliveryAddress: map['delivery_address'] as String?,
      deliveryLatitude: (map['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (map['delivery_longitude'] as num?)?.toDouble(),
      couponCode: map['coupon_code'] as String?,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory CartModel.empty({required String userId}) {
    return CartModel(
      id: '',
      userId: userId,
      totalAmount: 0.0,
      itemsCount: 0,
      discountAmount: 0.0,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'total_amount': totalAmount,
      'items_count': itemsCount,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'coupon_code': couponCode,
      'discount_amount': discountAmount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'total_amount': totalAmount,
      'items_count': itemsCount,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'coupon_code': couponCode,
      'discount_amount': discountAmount,
      'is_active': isActive,
    };
  }

  CartModel copyWith({
    String? id,
    String? userId,
    double? totalAmount,
    int? itemsCount,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? couponCode,
    double? discountAmount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalAmount: totalAmount ?? this.totalAmount,
      itemsCount: itemsCount ?? this.itemsCount,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isEmpty => itemsCount == 0;
  bool get hasItems => itemsCount > 0;
  bool get hasDeliveryAddress =>
      deliveryAddress != null && deliveryAddress!.isNotEmpty;
  bool get hasCoupon => couponCode != null && couponCode!.isNotEmpty;
  double get finalAmount => totalAmount - discountAmount;
  String get totalAmountFormatted => totalAmount.toStringAsFixed(2);
  String get discountAmountFormatted => discountAmount.toStringAsFixed(2);
  String get finalAmountFormatted => finalAmount.toStringAsFixed(2);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CartModel(id: $id, userId: $userId, totalAmount: $totalAmount, itemsCount: $itemsCount, isActive: $isActive)';
  }
}

/// Cart Item model that matches the Supabase cart_items table
/// عنصر في السلة مع تفاصيل المنتج والمتجر
class CartItemModel with BaseModelMixin {
  static const String tableName = 'cart_items';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String cartId; // UUID REFERENCES carts(id) ON DELETE CASCADE
  final String productId; // UUID REFERENCES products(id) ON DELETE CASCADE
  final String storeId; // UUID REFERENCES stores(id) ON DELETE CASCADE

  // معلومات المنتج في السلة
  final String productName; // TEXT NOT NULL
  final double productPrice; // DECIMAL(10,2) NOT NULL
  final String? productImage; // TEXT

  // الكمية والسعر
  final int quantity; // INT NOT NULL CHECK (quantity > 0)
  final double totalPrice; // DECIMAL(10,2) NOT NULL

  // خيارات إضافية
  final String? specialInstructions; // TEXT
  final Map<String, dynamic>? selectedOptions; // JSONB DEFAULT '{}'

  // معلومات التوصيل الخاصة بكل متجر
  final double storeDeliveryFee; // DECIMAL(10,2) DEFAULT 0

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.storeId,
    required this.productName,
    required this.productPrice,
    this.productImage,
    required this.quantity,
    required this.totalPrice,
    this.specialInstructions,
    this.selectedOptions,
    required this.storeDeliveryFee,
    required this.createdAt,
    this.updatedAt,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: map['id'] as String,
      cartId: map['cart_id'] as String,
      productId: map['product_id'] as String,
      storeId: map['store_id'] as String,
      productName: map['product_name'] as String,
      productPrice: (map['product_price'] as num).toDouble(),
      productImage: map['product_image'] as String?,
      quantity: map['quantity'] as int,
      totalPrice: (map['total_price'] as num).toDouble(),
      specialInstructions: map['special_instructions'] as String?,
      selectedOptions: map['selected_options'] as Map<String, dynamic>?,
      storeDeliveryFee: (map['store_delivery_fee'] as num?)?.toDouble() ?? 0.0,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cart_id': cartId,
      'product_id': productId,
      'store_id': storeId,
      'product_name': productName,
      'product_price': productPrice,
      'product_image': productImage,
      'quantity': quantity,
      'total_price': totalPrice,
      'special_instructions': specialInstructions,
      'selected_options': selectedOptions,
      'store_delivery_fee': storeDeliveryFee,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'cart_id': cartId,
      'product_id': productId,
      'store_id': storeId,
      'product_name': productName,
      'product_price': productPrice,
      'product_image': productImage,
      'quantity': quantity,
      'special_instructions': specialInstructions,
      'selected_options': selectedOptions,
      'store_delivery_fee': storeDeliveryFee,
    };
  }

  CartItemModel copyWith({
    String? id,
    String? cartId,
    String? productId,
    String? storeId,
    String? productName,
    double? productPrice,
    String? productImage,
    int? quantity,
    double? totalPrice,
    String? specialInstructions,
    Map<String, dynamic>? selectedOptions,
    double? storeDeliveryFee,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      cartId: cartId ?? this.cartId,
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
      productName: productName ?? this.productName,
      productPrice: productPrice ?? this.productPrice,
      productImage: productImage ?? this.productImage,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      storeDeliveryFee: storeDeliveryFee ?? this.storeDeliveryFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  String get productPriceFormatted => productPrice.toStringAsFixed(2);
  String get totalPriceFormatted => totalPrice.toStringAsFixed(2);
  String get storeDeliveryFeeFormatted => storeDeliveryFee.toStringAsFixed(2);
  bool get hasSpecialInstructions =>
      specialInstructions != null && specialInstructions!.isNotEmpty;
  bool get hasSelectedOptions =>
      selectedOptions != null && selectedOptions!.isNotEmpty;
  bool get hasProductImage => productImage != null && productImage!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CartItemModel(id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }
}
