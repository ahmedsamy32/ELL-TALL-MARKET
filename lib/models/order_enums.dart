/// Order enums that match the Supabase order_status_enum definition
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

/// Order status enum that matches Supabase order_status_enum
/// Values: 'pending', 'confirmed', 'in_preparation', 'ready', 'on_the_way', 'delivered', 'cancelled'
enum OrderStatus {
  pending,
  confirmed,
  inPreparation,
  ready,
  onTheWay,
  delivered,
  cancelled,
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
      case OrderStatus.inPreparation:
        return 'in_preparation';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.inPreparation:
        return 'قيد التحضير';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.onTheWay:
        return 'في الطريق';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  /// Create OrderStatus from database value
  static OrderStatus fromDbValue(String dbValue) {
    switch (dbValue) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_preparation':
      case 'processing':
      case 'preparing':
        return OrderStatus.inPreparation;
      case 'ready':
      case 'ready_for_delivery':
      case 'ready_for_pickup':
        return OrderStatus.ready;
      case 'on_the_way':
      case 'assigned_to_captain':
      case 'picked_up':
      case 'shipped':
        return OrderStatus.onTheWay;
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

  /// Check if the order is in a final state
  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// Check if the order can be cancelled
  bool get canBeCancelled =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;

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
        return [OrderStatus.inPreparation, OrderStatus.cancelled];
      case OrderStatus.inPreparation:
        return [OrderStatus.ready, OrderStatus.cancelled];
      case OrderStatus.ready:
        return [OrderStatus.onTheWay, OrderStatus.cancelled];
      case OrderStatus.onTheWay:
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
      case OrderStatus.inPreparation:
        return '#FF9800'; // Amber
      case OrderStatus.ready:
        return '#4CAF50'; // Green
      case OrderStatus.onTheWay:
        return '#9C27B0'; // Purple
      case OrderStatus.delivered:
        return '#8BC34A'; // Light Green
      case OrderStatus.cancelled:
        return '#F44336'; // Red
    }
  }
}

/// Payment Method Enum
enum PaymentMethod { cash, card, wallet }

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
  switch (value) {
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
enum PaymentStatus { pending, completed, failed, refunded }

/// Extension for PaymentStatus enum
extension PaymentStatusExtension on PaymentStatus {
  /// Get the database value
  String get dbValue {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.completed:
        return 'completed';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'في الانتظار';
      case PaymentStatus.completed:
        return 'مكتمل';
      case PaymentStatus.failed:
        return 'فشل';
      case PaymentStatus.refunded:
        return 'مُسترد';
    }
  }
}

/// Parse string to PaymentStatus
PaymentStatus parsePaymentStatus(String? value) {
  switch (value) {
    case 'pending':
      return PaymentStatus.pending;
    case 'completed':
      return PaymentStatus.completed;
    case 'failed':
      return PaymentStatus.failed;
    case 'refunded':
      return PaymentStatus.refunded;
    default:
      return PaymentStatus.pending;
  }
}
