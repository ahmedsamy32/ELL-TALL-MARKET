/// Coupon models that match the Supabase coupons and coupon_usage tables
/// Updated to match the new comprehensive coupon system schema
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

/// Coupon Type Enum
enum CouponType {
  percentage,
  fixedAmount,
  freeDelivery;

  static CouponType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'percentage':
        return CouponType.percentage;
      case 'fixed_amount':
        return CouponType.fixedAmount;
      case 'free_delivery':
        return CouponType.freeDelivery;
      default:
        return CouponType.percentage;
    }
  }

  String get value {
    switch (this) {
      case CouponType.percentage:
        return 'percentage';
      case CouponType.fixedAmount:
        return 'fixed_amount';
      case CouponType.freeDelivery:
        return 'free_delivery';
    }
  }

  String get displayName {
    switch (this) {
      case CouponType.percentage:
        return 'نسبة مئوية';
      case CouponType.fixedAmount:
        return 'مبلغ ثابت';
      case CouponType.freeDelivery:
        return 'توصيل مجاني';
    }
  }
}

/// Coupon lifecycle status derived from validity window & activation
enum CouponStatus { active, scheduled, expired }

/// Coupon model that matches the Supabase coupons table
class CouponModel with BaseModelMixin {
  static const String tableName = 'coupons';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String name;
  final String code; // TEXT UNIQUE NOT NULL
  final String? description; // TEXT
  final CouponType couponType; // coupon_type_enum NOT NULL
  final String? storeId;
  final String? merchantId;
  final String? createdBy;

  // قيمة الخصم
  final double discountValue; // DECIMAL(10,2) NOT NULL
  final double minimumOrderAmount; // DECIMAL(10,2) DEFAULT 0
  final double? maximumDiscountAmount; // DECIMAL(10,2)

  // حدود الاستخدام
  final int? usageLimit; // INT
  final int usedCount; // INT DEFAULT 0
  final int usageLimitPerUser; // INT DEFAULT 1

  // الفعالية
  final DateTime validFrom; // TIMESTAMPTZ DEFAULT NOW()
  final DateTime? validUntil; // TIMESTAMPTZ
  final bool isActive; // BOOLEAN DEFAULT TRUE

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const CouponModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.couponType,
    this.storeId,
    this.merchantId,
    this.createdBy,
    required this.discountValue,
    required this.minimumOrderAmount,
    this.maximumDiscountAmount,
    this.usageLimit,
    required this.usedCount,
    required this.usageLimitPerUser,
    required this.validFrom,
    this.validUntil,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    return CouponModel(
      id: map['id'] as String,
      name:
          (map['name'] as String?) ??
          (map['description'] as String?) ??
          (map['code'] as String),
      code: map['code'] as String,
      description: map['description'] as String?,
      couponType: CouponType.fromString(map['coupon_type'] as String),
      storeId: map['store_id'] as String?,
      merchantId: map['merchant_id'] as String?,
      createdBy: map['created_by'] as String?,
      discountValue: (map['discount_value'] as num).toDouble(),
      minimumOrderAmount:
          (map['minimum_order_amount'] as num?)?.toDouble() ?? 0.0,
      maximumDiscountAmount: (map['maximum_discount_amount'] as num?)
          ?.toDouble(),
      usageLimit: map['usage_limit'] as int?,
      usedCount: (map['used_count'] as int?) ?? 0,
      usageLimitPerUser: (map['usage_limit_per_user'] as int?) ?? 1,
      validFrom: BaseModelMixin.parseDateTime(map['valid_from']),
      validUntil: map['valid_until'] != null
          ? BaseModelMixin.parseDateTime(map['valid_until'])
          : null,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  // Helper methods
  String get discountValueFormatted {
    switch (couponType) {
      case CouponType.percentage:
        return '${discountValue.toStringAsFixed(0)}%';
      case CouponType.fixedAmount:
        return '${discountValue.toStringAsFixed(2)} ج.م';
      case CouponType.freeDelivery:
        return 'توصيل مجاني';
    }
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive &&
        now.isAfter(validFrom) &&
        (validUntil == null || now.isBefore(validUntil!));
  }

  bool get canBeUsed =>
      isValid && (usageLimit == null || usedCount < usageLimit!);

  CouponStatus get status {
    if (!isActive ||
        (validUntil != null && DateTime.now().isAfter(validUntil!))) {
      return CouponStatus.expired;
    }
    if (DateTime.now().isBefore(validFrom)) {
      return CouponStatus.scheduled;
    }
    return CouponStatus.active;
  }

  String get statusLabel {
    switch (status) {
      case CouponStatus.active:
        return 'فعّال';
      case CouponStatus.scheduled:
        return 'مجدوَل';
      case CouponStatus.expired:
        return 'منتهي';
    }
  }

  String get validUntilFormatted {
    if (validUntil == null) return 'دائم';
    return DateFormat('dd/MM/yyyy').format(validUntil!);
  }

  // Backward compatibility getters
  CouponType get type => couponType;
  double get value => discountValue;
  double? get maxDiscountAmount => maximumDiscountAmount;

  CouponModel copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    CouponType? couponType,
    String? storeId,
    String? merchantId,
    String? createdBy,
    double? discountValue,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    int? usageLimit,
    int? usedCount,
    int? usageLimitPerUser,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CouponModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      couponType: couponType ?? this.couponType,
      storeId: storeId ?? this.storeId,
      merchantId: merchantId ?? this.merchantId,
      createdBy: createdBy ?? this.createdBy,
      discountValue: discountValue ?? this.discountValue,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      usageLimitPerUser: usageLimitPerUser ?? this.usageLimitPerUser,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// حساب قيمة الخصم لطلب معين
  double calculateDiscount(double orderAmount) {
    if (!canBeUsed || orderAmount < minimumOrderAmount) {
      return 0.0;
    }

    double discount = 0.0;

    switch (couponType) {
      case CouponType.percentage:
        discount = orderAmount * (discountValue / 100);
        break;
      case CouponType.fixedAmount:
        discount = discountValue;
        break;
      case CouponType.freeDelivery:
        discount = 0.0; // يتم التعامل معه منفصلاً
        break;
    }

    // تطبيق الحد الأقصى للخصم
    if (maximumDiscountAmount != null && discount > maximumDiscountAmount!) {
      discount = maximumDiscountAmount!;
    }

    return discount > orderAmount ? orderAmount : discount;
  }

  @override
  String toString() {
    return 'CouponModel(id: $id, code: $code, type: ${couponType.value})';
  }
}
