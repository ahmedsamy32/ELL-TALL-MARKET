class MerchantSettings {
  final bool isActive;
  final double minOrderAmount;
  final double deliveryFee;
  final double maxDeliveryDistance;
  final Map<String, List<String>> workingHours;
  final bool acceptsReturns;
  final int returnsWindowDays;
  final String? notes;

  const MerchantSettings({
    this.isActive = true,
    this.minOrderAmount = 0.0,
    this.deliveryFee = 0.0,
    this.maxDeliveryDistance = 10.0,
    this.workingHours = const {
      'sunday': ['09:00', '21:00'],
      'monday': ['09:00', '21:00'],
      'tuesday': ['09:00', '21:00'],
      'wednesday': ['09:00', '21:00'],
      'thursday': ['09:00', '21:00'],
      'friday': ['16:00', '21:00'],
      'saturday': ['09:00', '21:00'],
    },
    this.acceptsReturns = true,
    this.returnsWindowDays = 14,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'minOrderAmount': minOrderAmount,
      'deliveryFee': deliveryFee,
      'maxDeliveryDistance': maxDeliveryDistance,
      'workingHours': workingHours,
      'acceptsReturns': acceptsReturns,
      'returnsWindowDays': returnsWindowDays,
      'notes': notes,
    };
  }

  factory MerchantSettings.fromJson(Map<String, dynamic> json) {
    return MerchantSettings(
      isActive: json['isActive'] ?? true,
      minOrderAmount: (json['minOrderAmount'] ?? 0.0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0.0).toDouble(),
      maxDeliveryDistance: (json['maxDeliveryDistance'] ?? 10.0).toDouble(),
      workingHours: Map<String, List<String>>.from(json['workingHours'] ?? {}),
      acceptsReturns: json['acceptsReturns'] ?? true,
      returnsWindowDays: json['returnsWindowDays'] ?? 14,
      notes: json['notes'],
    );
  }

  MerchantSettings copyWith({
    bool? isActive,
    double? minOrderAmount,
    double? deliveryFee,
    double? maxDeliveryDistance,
    Map<String, List<String>>? workingHours,
    bool? acceptsReturns,
    int? returnsWindowDays,
    String? notes,
  }) {
    return MerchantSettings(
      isActive: isActive ?? this.isActive,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      maxDeliveryDistance: maxDeliveryDistance ?? this.maxDeliveryDistance,
      workingHours: workingHours ?? this.workingHours,
      acceptsReturns: acceptsReturns ?? this.acceptsReturns,
      returnsWindowDays: returnsWindowDays ?? this.returnsWindowDays,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MerchantSettings &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          minOrderAmount == other.minOrderAmount &&
          deliveryFee == other.deliveryFee &&
          maxDeliveryDistance == other.maxDeliveryDistance &&
          workingHours == other.workingHours &&
          acceptsReturns == other.acceptsReturns &&
          returnsWindowDays == other.returnsWindowDays &&
          notes == other.notes;

  @override
  int get hashCode =>
      isActive.hashCode ^
      minOrderAmount.hashCode ^
      deliveryFee.hashCode ^
      maxDeliveryDistance.hashCode ^
      workingHours.hashCode ^
      acceptsReturns.hashCode ^
      returnsWindowDays.hashCode ^
      notes.hashCode;

  @override
  String toString() {
    return 'MerchantSettings{isActive: $isActive, '
        'minOrderAmount: $minOrderAmount, '
        'deliveryFee: $deliveryFee, '
        'maxDeliveryDistance: $maxDeliveryDistance, '
        'workingHours: $workingHours, '
        'acceptsReturns: $acceptsReturns, '
        'returnsWindowDays: $returnsWindowDays, '
        'notes: $notes}';
  }
}
