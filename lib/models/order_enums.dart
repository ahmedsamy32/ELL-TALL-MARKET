/// Order enums that match the Supabase order_status_enum definition
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  inTransit,
  delivered,
  cancelled;

  static OrderStatus fromString(String value) =>
      OrderStatusExtension.fromDbValue(value);
}

/// Extension for OrderStatus enum with Supabase integration
extension OrderStatusExtension on OrderStatus {
  /// Get the database value (snake_case) for Supabase
  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.inTransit:
        return 'in_transit';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Alias for dbValue to match other models
  String get value => dbValue;

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.preparing:
        return 'قيد التحضير';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.inTransit:
        return 'في الطريق';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  /// Create OrderStatus from database value
  static OrderStatus fromDbValue(String dbValue) {
    switch (dbValue.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
      case 'in_preparation':
      case 'processing':
        return OrderStatus.preparing;
      case 'ready':
      case 'ready_for_delivery':
      case 'ready_for_pickup':
        return OrderStatus.ready;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'in_transit':
      case 'on_the_way':
      case 'assigned_to_captain':
      case 'shipped':
        return OrderStatus.inTransit;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
      case 'refunded':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  /// Alias for fromDbValue to match other models
  static OrderStatus fromString(String status) => fromDbValue(status);

  /// Check if the order is in a final state
  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// Check if the order can be cancelled
  bool get canBeCancelled =>
      this == OrderStatus.pending ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.preparing;

  /// Check if the order can be confirmed
  bool get canBeConfirmed => this == OrderStatus.pending;

  /// Check if the order is active (not cancelled or delivered)
  bool get isActive => !isFinal;

  /// Get the next possible statuses
  List<OrderStatus> get nextStatuses {
    switch (this) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready, OrderStatus.cancelled];
      case OrderStatus.ready:
        return [OrderStatus.pickedUp, OrderStatus.cancelled];
      case OrderStatus.pickedUp:
        return [OrderStatus.inTransit];
      case OrderStatus.inTransit:
        return [OrderStatus.delivered];
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return [];
    }
  }

  /// Get status color for UI
  String get colorHex {
    switch (this) {
      case OrderStatus.pending:
        return '#FFA500'; // Orange
      case OrderStatus.confirmed:
        return '#2196F3'; // Blue
      case OrderStatus.preparing:
        return '#FF9800'; // Amber
      case OrderStatus.ready:
        return '#4CAF50'; // Green
      case OrderStatus.pickedUp:
        return '#00BCD4'; // Cyan
      case OrderStatus.inTransit:
        return '#9C27B0'; // Purple
      case OrderStatus.delivered:
        return '#8BC34A'; // Light Green
      case OrderStatus.cancelled:
        return '#F44336'; // Red
    }
  }
}

/// Payment Method Enum
enum PaymentMethod {
  cash,
  card,
  wallet;

  static PaymentMethod fromString(String value) => parsePaymentMethod(value);
}

/// Extension for PaymentMethod enum
extension PaymentMethodExtension on PaymentMethod {
  /// Get the database value
  String get dbValue {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.wallet:
        return 'wallet';
    }
  }

  /// Alias for dbValue
  String get value => dbValue;

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'الدفع نقداً';
      case PaymentMethod.card:
        return 'بطاقة ائتمان';
      case PaymentMethod.wallet:
        return 'محفظة إلكترونية';
    }
  }

  /// Get icon for each payment method
  String get icon {
    switch (this) {
      case PaymentMethod.cash:
        return '💵';
      case PaymentMethod.card:
        return '💳';
      case PaymentMethod.wallet:
        return '👛';
    }
  }
}

/// Parse string to PaymentMethod
PaymentMethod parsePaymentMethod(String? value) {
  switch (value?.toLowerCase()) {
    case 'cash':
      return PaymentMethod.cash;
    case 'card':
      return PaymentMethod.card;
    case 'wallet':
      return PaymentMethod.wallet;
    default:
      return PaymentMethod.cash;
  }
}

/// Payment Status Enum
enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded;

  static PaymentStatus fromString(String value) => parsePaymentStatus(value);
}

/// Extension for PaymentStatus enum
extension PaymentStatusExtension on PaymentStatus {
  /// Get the database value
  String get dbValue {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  /// Alias for dbValue
  String get value => dbValue;

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'في الانتظار';
      case PaymentStatus.paid:
        return 'مدفوع';
      case PaymentStatus.failed:
        return 'فشل الدفع';
      case PaymentStatus.refunded:
        return 'مُسترد';
    }
  }
}

/// Parse string to PaymentStatus
PaymentStatus parsePaymentStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'pending':
      return PaymentStatus.pending;
    case 'paid':
    case 'completed':
    case 'success':
      return PaymentStatus.paid;
    case 'failed':
    case 'error':
      return PaymentStatus.failed;
    case 'refunded':
      return PaymentStatus.refunded;
    default:
      return PaymentStatus.pending;
  }
}
