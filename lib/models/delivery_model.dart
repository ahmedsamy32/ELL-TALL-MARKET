/// Delivery models that match the Supabase deliveries, delivery_tracking, and delivery_pricing tables
/// Updated to match the new comprehensive delivery system schema
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

/// Delivery Status Enum
enum DeliveryStatus {
  pending,
  assigned,
  pickedUp,
  inTransit,
  arrived,
  delivered,
  cancelled,
  failed;

  static DeliveryStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'assigned':
        return DeliveryStatus.assigned;
      case 'picked_up':
        return DeliveryStatus.pickedUp;
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'arrived':
        return DeliveryStatus.arrived;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      case 'failed':
        return DeliveryStatus.failed;
      default:
        return DeliveryStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case DeliveryStatus.pending:
        return 'pending';
      case DeliveryStatus.assigned:
        return 'assigned';
      case DeliveryStatus.pickedUp:
        return 'picked_up';
      case DeliveryStatus.inTransit:
        return 'in_transit';
      case DeliveryStatus.arrived:
        return 'arrived';
      case DeliveryStatus.delivered:
        return 'delivered';
      case DeliveryStatus.cancelled:
        return 'cancelled';
      case DeliveryStatus.failed:
        return 'failed';
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return 'في الانتظار';
      case DeliveryStatus.assigned:
        return 'تم التعيين';
      case DeliveryStatus.pickedUp:
        return 'تم الاستلام';
      case DeliveryStatus.inTransit:
        return 'في الطريق';
      case DeliveryStatus.arrived:
        return 'وصل';
      case DeliveryStatus.delivered:
        return 'تم التوصيل';
      case DeliveryStatus.cancelled:
        return 'ملغي';
      case DeliveryStatus.failed:
        return 'فشل';
    }
  }
}

/// Vehicle Type Enum
enum VehicleType {
  motorcycle,
  car,
  bicycle,
  truck;

  static VehicleType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'motorcycle':
        return VehicleType.motorcycle;
      case 'car':
        return VehicleType.car;
      case 'bicycle':
        return VehicleType.bicycle;
      case 'truck':
        return VehicleType.truck;
      default:
        return VehicleType.motorcycle;
    }
  }

  String get value {
    switch (this) {
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.car:
        return 'car';
      case VehicleType.bicycle:
        return 'bicycle';
      case VehicleType.truck:
        return 'truck';
    }
  }

  String get displayName {
    switch (this) {
      case VehicleType.motorcycle:
        return 'دراجة نارية';
      case VehicleType.car:
        return 'سيارة';
      case VehicleType.bicycle:
        return 'دراجة هوائية';
      case VehicleType.truck:
        return 'شاحنة';
    }
  }
}

/// Delivery model that matches the Supabase deliveries table
class DeliveryModel with BaseModelMixin {
  static const String tableName = 'deliveries';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String orderId; // UUID REFERENCES orders(id) ON DELETE CASCADE
  final String? captainId; // UUID REFERENCES captains(id)

  // معلومات التوصيل
  final String? trackingNumber; // TEXT UNIQUE
  final DeliveryStatus status; // delivery_status_enum DEFAULT 'pending'

  // المواقع
  final String pickupAddress; // TEXT NOT NULL
  final double? pickupLatitude; // DECIMAL(10, 8)
  final double? pickupLongitude; // DECIMAL(11, 8)

  final String deliveryAddress; // TEXT NOT NULL
  final double? deliveryLatitude; // DECIMAL(10, 8)
  final double? deliveryLongitude; // DECIMAL(11, 8)

  // معلومات التكلفة والوقت
  final double deliveryFee; // DECIMAL(10,2) NOT NULL DEFAULT 0
  final double? distanceKm; // DECIMAL(8,2)
  final int? estimatedDurationMinutes; // INT

  // التواريخ
  final DateTime? assignedAt; // TIMESTAMPTZ
  final DateTime? pickedUpAt; // TIMESTAMPTZ
  final DateTime? inTransitAt; // TIMESTAMPTZ
  final DateTime? arrivedAt; // TIMESTAMPTZ
  final DateTime? deliveredAt; // TIMESTAMPTZ
  final DateTime? cancelledAt; // TIMESTAMPTZ

  // معلومات إضافية
  final String? captainNotes; // TEXT
  final String? customerNotes; // TEXT
  final String? cancellationReason; // TEXT

  // التقييم
  final int? customerRating; // INT CHECK (customer_rating BETWEEN 1 AND 5)
  final String? customerFeedback; // TEXT

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const DeliveryModel({
    required this.id,
    required this.orderId,
    this.captainId,
    this.trackingNumber,
    required this.status,
    required this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.deliveryFee,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.assignedAt,
    this.pickedUpAt,
    this.inTransitAt,
    this.arrivedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.captainNotes,
    this.customerNotes,
    this.cancellationReason,
    this.customerRating,
    this.customerFeedback,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map) {
    return DeliveryModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      captainId: map['captain_id'] as String?,
      trackingNumber: map['tracking_number'] as String?,
      status: DeliveryStatus.fromString(map['status'] as String? ?? 'pending'),
      pickupAddress: map['pickup_address'] as String,
      pickupLatitude: (map['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (map['pickup_longitude'] as num?)?.toDouble(),
      deliveryAddress: map['delivery_address'] as String,
      deliveryLatitude: (map['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (map['delivery_longitude'] as num?)?.toDouble(),
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes: map['estimated_duration_minutes'] as int?,
      assignedAt: map['assigned_at'] != null
          ? BaseModelMixin.parseDateTime(map['assigned_at'])
          : null,
      pickedUpAt: map['picked_up_at'] != null
          ? BaseModelMixin.parseDateTime(map['picked_up_at'])
          : null,
      inTransitAt: map['in_transit_at'] != null
          ? BaseModelMixin.parseDateTime(map['in_transit_at'])
          : null,
      arrivedAt: map['arrived_at'] != null
          ? BaseModelMixin.parseDateTime(map['arrived_at'])
          : null,
      deliveredAt: map['delivered_at'] != null
          ? BaseModelMixin.parseDateTime(map['delivered_at'])
          : null,
      cancelledAt: map['cancelled_at'] != null
          ? BaseModelMixin.parseDateTime(map['cancelled_at'])
          : null,
      captainNotes: map['captain_notes'] as String?,
      customerNotes: map['customer_notes'] as String?,
      cancellationReason: map['cancellation_reason'] as String?,
      customerRating: map['customer_rating'] as int?,
      customerFeedback: map['customer_feedback'] as String?,
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
      'captain_id': captainId,
      'tracking_number': trackingNumber,
      'status': status.value,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_fee': deliveryFee,
      'distance_km': distanceKm,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'assigned_at': assignedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'in_transit_at': inTransitAt?.toIso8601String(),
      'arrived_at': arrivedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'captain_notes': captainNotes,
      'customer_notes': customerNotes,
      'cancellation_reason': cancellationReason,
      'customer_rating': customerRating,
      'customer_feedback': customerFeedback,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'order_id': orderId,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_fee': deliveryFee,
      'distance_km': distanceKm,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'customer_notes': customerNotes,
    };
  }

  // Helper methods
  String get deliveryFeeFormatted => deliveryFee.toStringAsFixed(2);
  String get distanceKmFormatted =>
      distanceKm?.toStringAsFixed(1) ?? 'غير محدد';
  String get estimatedDurationFormatted => estimatedDurationMinutes != null
      ? '$estimatedDurationMinutes دقيقة'
      : 'غير محدد';

  bool get isCompleted => status == DeliveryStatus.delivered;
  bool get isCancelled =>
      status == DeliveryStatus.cancelled || status == DeliveryStatus.failed;
  bool get isActive => !isCompleted && !isCancelled;
  bool get hasTracking => trackingNumber != null && trackingNumber!.isNotEmpty;
  bool get hasCaptain => captainId != null;
  bool get hasRating => customerRating != null;
  bool get hasFeedback =>
      customerFeedback != null && customerFeedback!.isNotEmpty;
  bool get hasCaptainNotes => captainNotes != null && captainNotes!.isNotEmpty;
  bool get hasCustomerNotes =>
      customerNotes != null && customerNotes!.isNotEmpty;

  String get statusDisplayName => status.displayName;
  String get assignedAtFormatted => assignedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(assignedAt!)
      : 'لم يتم التعيين';
  String get deliveredAtFormatted => deliveredAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(deliveredAt!)
      : 'لم يتم التوصيل';

  DeliveryModel copyWith({
    String? id,
    String? orderId,
    String? captainId,
    String? trackingNumber,
    DeliveryStatus? status,
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double? deliveryFee,
    double? distanceKm,
    int? estimatedDurationMinutes,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? inTransitAt,
    DateTime? arrivedAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? captainNotes,
    String? customerNotes,
    String? cancellationReason,
    int? customerRating,
    String? customerFeedback,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      captainId: captainId ?? this.captainId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      inTransitAt: inTransitAt ?? this.inTransitAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      captainNotes: captainNotes ?? this.captainNotes,
      customerNotes: customerNotes ?? this.customerNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      customerRating: customerRating ?? this.customerRating,
      customerFeedback: customerFeedback ?? this.customerFeedback,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DeliveryModel(id: $id, trackingNumber: $trackingNumber, status: ${status.value})';
  }
}
