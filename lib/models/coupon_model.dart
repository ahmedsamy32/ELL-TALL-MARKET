/// Coupon models that match the Supabase coupons and coupon_usage tables
/// Updated to match the new comprehensive coupon system schema
library;

import 'dart:convert';
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
  freeDelivery,
  productSpecific,
  tieredQuantity,
  flashSale;

  static CouponType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'percentage':
        return CouponType.percentage;
      case 'fixed_amount':
        return CouponType.fixedAmount;
      case 'free_delivery':
        return CouponType.freeDelivery;
      case 'product_specific':
        return CouponType.productSpecific;
      case 'tiered_quantity':
        return CouponType.tieredQuantity;
      case 'flash_sale':
        return CouponType.flashSale;
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
      case CouponType.productSpecific:
        return 'product_specific';
      case CouponType.tieredQuantity:
        return 'tiered_quantity';
      case CouponType.flashSale:
        return 'flash_sale';
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
      case CouponType.productSpecific:
        return 'منتجات محددة';
      case CouponType.tieredQuantity:
        return 'اشترِ أكثر وفّر أكثر';
      case CouponType.flashSale:
        return 'ساعات سعيدة';
    }
  }

  String get typeDescription {
    switch (this) {
      case CouponType.percentage:
        return 'خصم بنسبة مئوية على إجمالي الطلب';
      case CouponType.fixedAmount:
        return 'خصم مبلغ ثابت من إجمالي الطلب';
      case CouponType.freeDelivery:
        return 'توصيل مجاني للطلب';
      case CouponType.productSpecific:
        return 'خصم على أصناف محددة فقط';
      case CouponType.tieredQuantity:
        return 'خصم متصاعد حسب عدد القطع المشتراة';
      case CouponType.flashSale:
        return 'كوبون يعمل فقط في ساعات محددة';
    }
  }
}

/// نموذج شريحة الكمية (اشترِ أكثر وفّر أكثر)
class QuantityTier {
  final int minQuantity;
  final double discountPercent;

  const QuantityTier({
    required this.minQuantity,
    required this.discountPercent,
  });

  factory QuantityTier.fromMap(Map<String, dynamic> map) {
    return QuantityTier(
      minQuantity: (map['min_quantity'] as num).toInt(),
      discountPercent: (map['discount_percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'min_quantity': minQuantity,
    'discount_percent': discountPercent,
  };

  String get label => '$minQuantity+ قطع → $discountPercent%';
}

/// Coupon lifecycle status derived from validity window & activation
enum CouponStatus { active, scheduled, expired }

/// Coupon model that matches the Supabase coupons table
class CouponModel with BaseModelMixin {
  static const String tableName = 'coupons';
  static const String schema = 'public';

  @override
  final String id;
  final String name;
  final String code;
  final String? description;
  final CouponType couponType;
  final String? storeId;
  final String? merchantId;
  final String? createdBy;

  // قيمة الخصم
  final double discountValue;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;

  // حدود الاستخدام
  final int? usageLimit;
  final int usedCount;
  final int usageLimitPerUser;

  // الفعالية
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool isActive;

  // ── الحقول الجديدة ──
  /// قائمة معرفات المنتجات المستهدفة (كوبون المنتجات المحددة)
  final List<String> productIds;

  /// شرائح الكمية (اشترِ أكثر وفّر أكثر)
  final List<QuantityTier> quantityTiers;

  /// ساعة بداية التفعيل (Flash Sale) — 0..23
  final int? activeHoursStart;

  /// ساعة نهاية التفعيل (Flash Sale) — 0..23
  final int? activeHoursEnd;

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
    this.productIds = const [],
    this.quantityTiers = const [],
    this.activeHoursStart,
    this.activeHoursEnd,
    required this.createdAt,
    this.updatedAt,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    // parse product_ids
    List<String> parsedProductIds = [];
    if (map['product_ids'] != null) {
      if (map['product_ids'] is List) {
        parsedProductIds = (map['product_ids'] as List)
            .map((e) => e.toString())
            .toList();
      } else if (map['product_ids'] is String) {
        try {
          final decoded = jsonDecode(map['product_ids'] as String);
          if (decoded is List) {
            parsedProductIds = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    // parse quantity_tiers
    List<QuantityTier> parsedTiers = [];
    if (map['quantity_tiers'] != null) {
      List<dynamic> tierList;
      if (map['quantity_tiers'] is String) {
        tierList = jsonDecode(map['quantity_tiers'] as String) as List;
      } else {
        tierList = map['quantity_tiers'] as List;
      }
      parsedTiers =
          tierList
              .map((t) => QuantityTier.fromMap(t as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));
    }

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
      productIds: parsedProductIds,
      quantityTiers: parsedTiers,
      activeHoursStart: map['active_hours_start'] as int?,
      activeHoursEnd: map['active_hours_end'] as int?,
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
      case CouponType.productSpecific:
        return '${discountValue.toStringAsFixed(0)}% على أصناف محددة';
      case CouponType.tieredQuantity:
        if (quantityTiers.isNotEmpty) {
          final best = quantityTiers.last;
          return 'حتى ${best.discountPercent.toStringAsFixed(0)}%';
        }
        return '${discountValue.toStringAsFixed(0)}%';
      case CouponType.flashSale:
        return '${discountValue.toStringAsFixed(0)}% ⚡';
    }
  }

  bool get isValid {
    final now = DateTime.now();
    final baseValid =
        isActive &&
        now.isAfter(validFrom) &&
        (validUntil == null || now.isBefore(validUntil!));
    if (!baseValid) return false;
    // Flash sale يجب أن يكون ضمن ساعات التفعيل
    if (couponType == CouponType.flashSale) {
      return isWithinActiveHours;
    }
    return true;
  }

  /// هل الوقت الحالي ضمن ساعات التفعيل؟
  bool get isWithinActiveHours {
    if (activeHoursStart == null || activeHoursEnd == null) return true;
    final nowHour = DateTime.now().hour;
    if (activeHoursStart! <= activeHoursEnd!) {
      // نفس اليوم: مثال 14 → 18
      return nowHour >= activeHoursStart! && nowHour < activeHoursEnd!;
    } else {
      // يمتد لليوم التالي: مثال 22 → 2
      return nowHour >= activeHoursStart! || nowHour < activeHoursEnd!;
    }
  }

  /// عرض ساعات التفعيل بصيغة مقروءة
  String get activeHoursFormatted {
    if (activeHoursStart == null || activeHoursEnd == null) return '';
    String formatHour(int h) {
      if (h == 0) return '12 ص';
      if (h < 12) return '$h ص';
      if (h == 12) return '12 م';
      return '${h - 12} م';
    }

    return '${formatHour(activeHoursStart!)} - ${formatHour(activeHoursEnd!)}';
  }

  /// الحصول على الشريحة المناسبة لعدد معين
  QuantityTier? getTierForQuantity(int quantity) {
    if (quantityTiers.isEmpty) return null;
    QuantityTier? matched;
    for (final tier in quantityTiers) {
      if (quantity >= tier.minQuantity) matched = tier;
    }
    return matched;
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
    List<String>? productIds,
    List<QuantityTier>? quantityTiers,
    int? activeHoursStart,
    int? activeHoursEnd,
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
      productIds: productIds ?? this.productIds,
      quantityTiers: quantityTiers ?? this.quantityTiers,
      activeHoursStart: activeHoursStart ?? this.activeHoursStart,
      activeHoursEnd: activeHoursEnd ?? this.activeHoursEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// حساب قيمة الخصم لطلب معين
  /// [orderAmount] إجمالي مبلغ الطلب
  /// [totalQuantity] عدد العناصر في السلة (يُستخدم لشرائح الكمية)
  /// [eligibleAmount] مبلغ المنتجات المؤهلة فقط (كوبون المنتجات المحددة)
  double calculateDiscount(
    double orderAmount, {
    int totalQuantity = 1,
    double? eligibleAmount,
  }) {
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
      case CouponType.productSpecific:
        final base = eligibleAmount ?? orderAmount;
        discount = base * (discountValue / 100);
        break;
      case CouponType.tieredQuantity:
        final tier = getTierForQuantity(totalQuantity);
        if (tier != null) {
          discount = orderAmount * (tier.discountPercent / 100);
        }
        break;
      case CouponType.flashSale:
        if (isWithinActiveHours) {
          discount = orderAmount * (discountValue / 100);
        }
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
