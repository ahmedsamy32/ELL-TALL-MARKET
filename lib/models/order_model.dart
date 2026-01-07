import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/order_enums.dart';

export 'package:ell_tall_market/models/order_enums.dart';

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

/// Order model that matches the Supabase orders table
class OrderModel with BaseModelMixin {
  static const String tableName = 'orders';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String clientId; // UUID REFERENCES clients(id) ON DELETE CASCADE
  final String storeId; // UUID REFERENCES stores(id) ON DELETE CASCADE
  final String? captainId; // UUID REFERENCES captains(id)
  final String? storeName; // اسم المتجر (من join)
  final List<String> productNames; // أسماء المنتجات (من order_items)

  // معلومات الطلب
  final String? orderNumber; // TEXT UNIQUE
  final double totalAmount; // DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0)
  final double deliveryFee; // DECIMAL(10,2) DEFAULT 0
  final double taxAmount; // DECIMAL(10,2) DEFAULT 0

  // معلومات التوصيل
  final String deliveryAddress; // TEXT NOT NULL
  final double? deliveryLatitude; // DECIMAL(10, 8)
  final double? deliveryLongitude; // DECIMAL(11, 8)
  final String? deliveryNotes; // TEXT

  // حالة الطلب
  final OrderStatus status; // order_status_enum DEFAULT 'pending'
  final String? cancellationReason; // TEXT - سبب الإلغاء

  // الدفع
  final PaymentMethod paymentMethod; // TEXT DEFAULT 'cash'
  final PaymentStatus paymentStatus; // TEXT DEFAULT 'pending'

  // التواريخ
  final DateTime? acceptedAt; // TIMESTAMPTZ
  final DateTime? preparedAt; // TIMESTAMPTZ
  final DateTime? pickedUpAt; // TIMESTAMPTZ
  final DateTime? deliveredAt; // TIMESTAMPTZ

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    required this.clientId,
    required this.storeId,
    this.captainId,
    this.storeName,
    this.productNames = const [],
    this.orderNumber,
    required this.totalAmount,
    required this.deliveryFee,
    required this.taxAmount,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryNotes,
    required this.status,
    this.cancellationReason,
    required this.paymentMethod,
    required this.paymentStatus,
    this.acceptedAt,
    this.preparedAt,
    this.pickedUpAt,
    this.deliveredAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final productNamesFromItems =
        (map['order_items'] as List?)
            ?.map((item) => (item as Map<String, dynamic>?)?['product_name'])
            .whereType<String>()
            .toList() ??
        const [];

    return OrderModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      storeId: map['store_id'] as String,
      captainId: map['captain_id'] as String?,
      storeName: map['store'] != null
          ? (map['store'] as Map<String, dynamic>)['name'] as String?
          : null,
      productNames: productNamesFromItems,
      orderNumber: map['order_number'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryAddress: map['delivery_address'] as String,
      deliveryLatitude: (map['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (map['delivery_longitude'] as num?)?.toDouble(),
      deliveryNotes: map['delivery_notes'] as String?,
      status: OrderStatus.fromString(map['status'] as String? ?? 'pending'),
      cancellationReason: map['cancellation_reason'] as String?,
      paymentMethod: PaymentMethod.fromString(
        map['payment_method'] as String? ?? 'cash',
      ),
      paymentStatus: PaymentStatus.fromString(
        map['payment_status'] as String? ?? 'pending',
      ),
      acceptedAt: map['accepted_at'] != null
          ? BaseModelMixin.parseDateTime(map['accepted_at'])
          : null,
      preparedAt: map['prepared_at'] != null
          ? BaseModelMixin.parseDateTime(map['prepared_at'])
          : null,
      pickedUpAt: map['picked_up_at'] != null
          ? BaseModelMixin.parseDateTime(map['picked_up_at'])
          : null,
      deliveredAt: map['delivered_at'] != null
          ? BaseModelMixin.parseDateTime(map['delivered_at'])
          : null,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'store_id': storeId,
      'captain_id': captainId,
      'order_number': orderNumber,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'tax_amount': taxAmount,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_notes': deliveryNotes,
      'status': status.value,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
      'accepted_at': acceptedAt?.toIso8601String(),
      'prepared_at': preparedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'client_id': clientId,
      'store_id': storeId,
      'captain_id': captainId,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'tax_amount': taxAmount,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_notes': deliveryNotes,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
    };
  }

  OrderModel copyWith({
    String? id,
    String? clientId,
    String? storeId,
    String? captainId,
    String? orderNumber,
    List<String>? productNames,
    double? totalAmount,
    double? deliveryFee,
    double? taxAmount,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryNotes,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DateTime? acceptedAt,
    DateTime? preparedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      storeId: storeId ?? this.storeId,
      captainId: captainId ?? this.captainId,
      orderNumber: orderNumber ?? this.orderNumber,
      productNames: productNames ?? this.productNames,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      taxAmount: taxAmount ?? this.taxAmount,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      preparedAt: preparedAt ?? this.preparedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  double get finalAmount => totalAmount + deliveryFee + taxAmount;
  String get totalAmountFormatted => totalAmount.toStringAsFixed(2);
  String get deliveryFeeFormatted => deliveryFee.toStringAsFixed(2);
  String get taxAmountFormatted => taxAmount.toStringAsFixed(2);
  String get finalAmountFormatted => finalAmount.toStringAsFixed(2);

  bool get isCompleted => status == OrderStatus.delivered;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isActive => !isCompleted && !isCancelled;
  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  bool get hasDeliveryNotes =>
      deliveryNotes != null && deliveryNotes!.isNotEmpty;
  bool get hasCaptain => captainId != null;

  String get statusDisplayName => status.displayName;
  String get paymentMethodDisplayName => paymentMethod.displayName;
  String get paymentStatusDisplayName => paymentStatus.displayName;

  // Backward compatibility getters
  String get merchantId => storeId;
  String? get notes => deliveryNotes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OrderModel(id: $id, orderNumber: $orderNumber, status: ${status.value}, totalAmount: $totalAmount)';
  }
}

/// Order Item model that matches the Supabase order_items table
class OrderItemModel with BaseModelMixin {
  static const String tableName = 'order_items';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String orderId; // UUID REFERENCES orders(id) ON DELETE CASCADE
  final String? productId; // UUID REFERENCES products(id)
  final String productName; // TEXT NOT NULL
  final double productPrice; // DECIMAL(10,2) NOT NULL
  final int quantity; // INT NOT NULL CHECK (quantity > 0)
  final double totalPrice; // DECIMAL(10,2) NOT NULL
  final String? specialInstructions; // TEXT
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.totalPrice,
    this.specialInstructions,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      productPrice: (map['product_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      totalPrice: (map['total_price'] as num).toDouble(),
      specialInstructions: map['special_instructions'] as String?,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
      'total_price': totalPrice,
      'special_instructions': specialInstructions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
      'total_price': totalPrice,
      'special_instructions': specialInstructions,
    };
  }

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    double? productPrice,
    int? quantity,
    double? totalPrice,
    String? specialInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  String get productPriceFormatted => productPrice.toStringAsFixed(2);
  String get totalPriceFormatted => totalPrice.toStringAsFixed(2);
  bool get hasSpecialInstructions =>
      specialInstructions != null && specialInstructions!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OrderItemModel(id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }
}

/// Order Status Log model that matches the Supabase order_status_logs table
class OrderStatusLogModel with BaseModelMixin {
  static const String tableName = 'order_status_logs';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String orderId; // UUID REFERENCES orders(id) ON DELETE CASCADE
  final String? oldStatus; // TEXT
  final String? newStatus; // TEXT
  final DateTime changedAt; // TIMESTAMPTZ DEFAULT NOW()

  @override
  DateTime get createdAt => changedAt;
  @override
  DateTime? get updatedAt => null;

  const OrderStatusLogModel({
    required this.id,
    required this.orderId,
    this.oldStatus,
    this.newStatus,
    required this.changedAt,
  });

  factory OrderStatusLogModel.fromMap(Map<String, dynamic> map) {
    return OrderStatusLogModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      oldStatus: map['old_status'] as String?,
      newStatus: map['new_status'] as String?,
      changedAt: BaseModelMixin.parseDateTime(map['changed_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'order_id': orderId,
      'old_status': oldStatus,
      'new_status': newStatus,
    };
  }

  OrderStatusLogModel copyWith({
    String? id,
    String? orderId,
    String? oldStatus,
    String? newStatus,
    DateTime? changedAt,
  }) {
    return OrderStatusLogModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      oldStatus: oldStatus ?? this.oldStatus,
      newStatus: newStatus ?? this.newStatus,
      changedAt: changedAt ?? this.changedAt,
    );
  }

  // Helper methods
  String get oldStatusDisplayName => oldStatus != null
      ? OrderStatus.fromString(oldStatus!).displayName
      : 'غير محدد';
  String get newStatusDisplayName => newStatus != null
      ? OrderStatus.fromString(newStatus!).displayName
      : 'غير محدد';
  String get changedAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(changedAt);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderStatusLogModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OrderStatusLogModel(id: $id, oldStatus: $oldStatus, newStatus: $newStatus, changedAt: $changedAt)';
  }
}

/// Service class for order operations
class OrderService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// الحصول على طلبات العميل
  static Future<List<OrderModel>> getClientOrders({String? clientId}) async {
    try {
      final currentClientId = clientId ?? _client.auth.currentUser?.id;
      if (currentClientId == null) return [];

      final response = await _client
          .from(OrderModel.tableName)
          .select()
          .eq('client_id', currentClientId)
          .order('created_at', ascending: false);

      return response
          .map<OrderModel>((order) => OrderModel.fromMap(order))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting client orders', e);
      return [];
    }
  }

  /// الحصول على طلبات المتجر
  static Future<List<OrderModel>> getStoreOrders(String storeId) async {
    try {
      final response = await _client
          .from(OrderModel.tableName)
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      return response
          .map<OrderModel>((order) => OrderModel.fromMap(order))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting store orders', e);
      return [];
    }
  }

  /// الحصول على طلبات الكابتن
  static Future<List<OrderModel>> getCaptainOrders({String? captainId}) async {
    try {
      final currentCaptainId = captainId ?? _client.auth.currentUser?.id;
      if (currentCaptainId == null) return [];

      final response = await _client
          .from(OrderModel.tableName)
          .select()
          .eq('captain_id', currentCaptainId)
          .order('created_at', ascending: false);

      return response
          .map<OrderModel>((order) => OrderModel.fromMap(order))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting captain orders', e);
      return [];
    }
  }

  /// الحصول على عناصر الطلب
  static Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    try {
      final response = await _client
          .from(OrderItemModel.tableName)
          .select()
          .eq('order_id', orderId);

      return response
          .map<OrderItemModel>((item) => OrderItemModel.fromMap(item))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting order items', e);
      return [];
    }
  }

  /// الحصول على سجل تغييرات حالة الطلب
  static Future<List<OrderStatusLogModel>> getOrderStatusLogs(
    String orderId,
  ) async {
    try {
      final response = await _client
          .from(OrderStatusLogModel.tableName)
          .select()
          .eq('order_id', orderId)
          .order('changed_at', ascending: true);

      return response
          .map<OrderStatusLogModel>((log) => OrderStatusLogModel.fromMap(log))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting order status logs', e);
      return [];
    }
  }

  /// تحديث حالة الطلب
  static Future<bool> updateOrderStatus(
    String orderId,
    OrderStatus newStatus,
  ) async {
    try {
      await _client
          .from(OrderModel.tableName)
          .update({'status': newStatus.value})
          .eq('id', orderId);

      return true;
    } catch (e) {
      AppLogger.error('Error updating order status', e);
      return false;
    }
  }

  /// تحديث حالة الدفع
  static Future<bool> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus,
  ) async {
    try {
      await _client
          .from(OrderModel.tableName)
          .update({'payment_status': newStatus.value})
          .eq('id', orderId);

      return true;
    } catch (e) {
      AppLogger.error('Error updating payment status', e);
      return false;
    }
  }

  /// تعيين كابتن للطلب
  static Future<bool> assignCaptain(String orderId, String captainId) async {
    try {
      await _client
          .from(OrderModel.tableName)
          .update({'captain_id': captainId})
          .eq('id', orderId);

      return true;
    } catch (e) {
      AppLogger.error('Error assigning captain', e);
      return false;
    }
  }
}
