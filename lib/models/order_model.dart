import 'shipping_address.dart';

enum OrderStatus {
  pending,         // في الانتظار
  confirmed,       // مؤكد
  processing,      // قيد التحضير
  readyForDelivery, // جاهز للتوصيل
  assignedToCaptain, // تم تعيين كابتن
  pickedUp,        // تم الاستلام من المتجر
  onTheWay,        // في الطريق للعميل
  delivered,       // تم التوصيل
  completed,       // تم الدفع واكتمل الطلب
  cancelled,       // ملغي
  refunded         // تم الاسترجاع
}

enum PaymentStatus {
  pending,         // في انتظار الدفع
  collected,       // تم تحصيل المبلغ
  transferredToStore, // تم تحويل المبلغ للمتجر
  refunded,        // تم الاسترجاع
  failed           // فشل الدفع
}

enum PaymentMethod {
  cashOnDelivery,  // الدفع عند الاستلام
}

class OrderModel {
  final String id;
  final String userId;
  final String storeId;
  final String? captainId;
  final OrderStatus status;
  final double totalAmount;
  final double deliveryFee;
  final double discountAmount;
  final double finalAmount;
  final ShippingAddress shippingAddress;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? cancellationReason;

  // جديد: معلومات الدفع
  final DateTime? paymentCollectedAt;
  final DateTime? paymentTransferredAt;
  final String? paymentCollectedBy; // معرف الكابتن الذي حصل المبلغ
  final String? paymentNotes;

  // Items in the order
  final List<OrderItemModel> items;

  // Related data
  final String? userName;
  final String? userPhone;
  final String? storeName;
  final String? storePhone;
  final String? captainName;
  final String? captainPhone;

  // Getters
  double get total => finalAmount;

  OrderModel({
    required this.id,
    required this.userId,
    required this.storeId,
    this.captainId,
    required this.status,
    required this.totalAmount,
    required this.deliveryFee,
    required this.discountAmount,
    required this.finalAmount,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.updatedAt,
    required this.items,
    this.notes,
    this.cancellationReason,
    // جديد: معلومات الدفع
    this.paymentCollectedAt,
    this.paymentTransferredAt,
    this.paymentCollectedBy,
    this.paymentNotes,
    // Related data
    this.userName,
    this.userPhone,
    this.storeName,
    this.storePhone,
    this.captainName,
    this.captainPhone,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final userData = map['user'] as Map<String, dynamic>?;
    final storeData = map['store'] as Map<String, dynamic>?;
    final captainData = map['captain'] as Map<String, dynamic>?;

    return OrderModel(
      id: id ?? map['id'],
      userId: map['user_id'] ?? '',
      storeId: map['store_id'] ?? '',
      captainId: map['captain_id'],
      status: _parseOrderStatus(map['status']),
      totalAmount: (map['total_amount'] ?? 0.0).toDouble(),
      deliveryFee: (map['delivery_fee'] ?? 0.0).toDouble(),
      discountAmount: (map['discount_amount'] ?? 0.0).toDouble(),
      finalAmount: (map['final_amount'] ?? 0.0).toDouble(),
      shippingAddress: ShippingAddress(
        formattedAddress: map['delivery_address'] ?? '',
        phone: userData?['phone'] ?? '',
        coordinates: map['delivery_location'] != null ? {
          'lat': double.parse((map['delivery_location'] as String).split(',')[0]),
          'lng': double.parse((map['delivery_location'] as String).split(',')[1]),
        } : null,
      ),
      paymentMethod: PaymentMethod.cashOnDelivery,
      paymentStatus: _parsePaymentStatus(map['payment_status']),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      notes: map['notes'],
      cancellationReason: map['cancellation_reason'],

      // جديد: معلومات الدفع
      paymentCollectedAt: map['payment_collected_at'] != null
          ? DateTime.parse(map['payment_collected_at'])
          : null,
      paymentTransferredAt: map['payment_transferred_at'] != null
          ? DateTime.parse(map['payment_transferred_at'])
          : null,
      paymentCollectedBy: map['payment_collected_by'],
      paymentNotes: map['payment_notes'],

      items: (map['items'] as List?)?.map((item) => OrderItemModel.fromMap(item)).toList() ?? [],

      // Related data
      userName: userData?['name'],
      userPhone: userData?['phone'],
      storeName: storeData?['name'],
      storePhone: storeData?['phone'],
      captainName: captainData?['name'],
      captainPhone: captainData?['phone'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'store_id': storeId,
      'captain_id': captainId,
      'status': status.toString().split('.').last,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'delivery_address': shippingAddress.formattedAddress,
      'delivery_location': shippingAddress.coordinates != null
          ? '${shippingAddress.coordinates!['lat']},${shippingAddress.coordinates!['lng']}'
          : null,
      'payment_method': 'cash_on_delivery',
      'payment_status': paymentStatus.toString().split('.').last,
      'payment_collected_at': paymentCollectedAt?.toIso8601String(),
      'payment_transferred_at': paymentTransferredAt?.toIso8601String(),
      'payment_collected_by': paymentCollectedBy,
      'payment_notes': paymentNotes,
      'notes': notes,
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? captainId,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    String? captainName,
    String? captainPhone,
    String? notes,
    String? cancellationReason,
  }) {
    return OrderModel(
      id: id,
      userId: userId,
      storeId: storeId,
      captainId: captainId ?? this.captainId,
      status: status ?? this.status,
      totalAmount: totalAmount,
      deliveryFee: deliveryFee,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items,
      userName: userName,
      userPhone: userPhone,
      storeName: storeName,
      storePhone: storePhone,
      notes: notes ?? this.notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      captainName: captainName ?? this.captainName,
      captainPhone: captainPhone ?? this.captainPhone,
    );
  }

  static OrderStatus _parseOrderStatus(String? status) {
    if (status == null) return OrderStatus.pending;
    return OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => OrderStatus.pending,
    );
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    if (status == null) return PaymentStatus.pending;
    return PaymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => PaymentStatus.pending,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel.fromMap(json);

  @override
  String toString() => 'OrderModel(id: $id, status: $status, total: $finalAmount)';
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  // Product info
  final String? productName;
  final String? productImage;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
    this.productName,
    this.productImage,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final productData = map['product'] as Map<String, dynamic>?;

    return OrderItemModel(
      id: map['id'] ?? '',
      orderId: map['order_id'] ?? '',
      productId: map['product_id'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unit_price'] ?? 0.0).toDouble(),
      totalPrice: (map['total_price'] ?? 0.0).toDouble(),
      notes: map['notes'],
      productName: productData?['name'],
      productImage: productData?['images']?[0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'notes': notes,
    };
  }
}
