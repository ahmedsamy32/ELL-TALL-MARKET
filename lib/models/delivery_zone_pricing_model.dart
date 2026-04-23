class DeliveryZonePricingModel {
  final String id;
  final String governorate;
  final String? city;
  final String? area;
  final double fee;
  final int? estimatedMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DeliveryZonePricingModel({
    required this.id,
    required this.governorate,
    this.city,
    this.area,
    required this.fee,
    this.estimatedMinutes,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryZonePricingModel.fromMap(Map<String, dynamic> map) {
    return DeliveryZonePricingModel(
      id: map['id'] as String,
      governorate: (map['governorate'] as String? ?? '').trim(),
      city: (map['city'] as String?)?.trim(),
      area: (map['area'] as String?)?.trim(),
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt(),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'].toString()),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'governorate': governorate.trim(),
      'city': city?.trim().isEmpty ?? true ? null : city?.trim(),
      'area': area?.trim().isEmpty ?? true ? null : area?.trim(),
      'fee': fee,
      'estimated_minutes': estimatedMinutes,
      'is_active': isActive,
    };
  }

  DeliveryZonePricingModel copyWith({
    String? id,
    String? governorate,
    String? city,
    String? area,
    double? fee,
    int? estimatedMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryZonePricingModel(
      id: id ?? this.id,
      governorate: governorate ?? this.governorate,
      city: city ?? this.city,
      area: area ?? this.area,
      fee: fee ?? this.fee,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get scopeLabel {
    if ((area ?? '').trim().isNotEmpty) {
      return '$governorate - ${city ?? ''} - ${area ?? ''}'.trim();
    }
    if ((city ?? '').trim().isNotEmpty) {
      return '$governorate - ${city ?? ''}'.trim();
    }
    return governorate;
  }
}
