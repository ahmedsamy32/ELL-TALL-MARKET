enum CouponType { percentage, fixed }

class CouponModel {
  final String id;
  final String code;
  final CouponType type;
  final double value;
  final double? minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;
  final int? usageLimit;
  final int usageCount;
  final bool isActive;
  final String? storeId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Store info (joined data)
  final String? storeName;
  final String? storeLogoUrl;

  CouponModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minOrderAmount,
    this.maxDiscountAmount,
    required this.startDate,
    required this.endDate,
    this.usageLimit,
    this.usageCount = 0,
    this.isActive = true,
    this.storeId,
    required this.createdAt,
    this.updatedAt,
    this.storeName,
    this.storeLogoUrl,
  });

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'type': type.toString().split('.').last,
      'value': value,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'is_active': isActive,
      'store_id': storeId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel.fromMap(json);

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    final storeData = map['store'] as Map<String, dynamic>?;

    return CouponModel(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      type: _parseCouponType(map['type']),
      value: (map['value'] ?? 0.0).toDouble(),
      minOrderAmount: map['min_order_amount']?.toDouble(),
      maxDiscountAmount: map['max_discount_amount']?.toDouble(),
      startDate: DateTime.parse(map['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['end_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String()),
      usageLimit: map['usage_limit'],
      usageCount: map['usage_count'] ?? 0,
      isActive: map['is_active'] ?? true,
      storeId: map['store_id'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      // Store info
      storeName: storeData?['name'],
      storeLogoUrl: storeData?['logo_url'],
    );
  }

  static CouponType _parseCouponType(String? type) {
    return type?.toLowerCase() == 'percentage'
        ? CouponType.percentage
        : CouponType.fixed;
  }

  bool get isExpired => DateTime.now().isAfter(endDate);

  bool get isStarted => DateTime.now().isAfter(startDate);

  bool get isValid => isActive && isStarted && !isExpired &&
      (usageLimit == null || usageCount < usageLimit!);

  double calculateDiscount(double orderAmount) {
    if (!isValid || (minOrderAmount != null && orderAmount < minOrderAmount!)) {
      return 0;
    }

    double discount = type == CouponType.percentage
        ? orderAmount * (value / 100)
        : value;

    if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
      discount = maxDiscountAmount!;
    }

    return discount;
  }

  @override
  String toString() => 'CouponModel(code: $code, type: $type, value: $value)';
}
