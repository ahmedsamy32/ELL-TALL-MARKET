import 'package:equatable/equatable.dart';

class DeliveryCompanyModel extends Equatable {
  final String id;
  final String? adminId;
  final String companyName;
  final String? ownerEmail;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerImagePath;
  final String? governorate;
  final String city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeliveryCompanyModel({
    required this.id,
    this.adminId,
    required this.companyName,
    this.ownerEmail,
    this.ownerName,
    this.ownerPhone,
    this.ownerImagePath,
    this.governorate,
    required this.city,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  DeliveryCompanyModel copyWith({
    String? id,
    String? adminId,
    String? companyName,
    String? ownerEmail,
    String? ownerName,
    String? ownerPhone,
    String? ownerImagePath,
    String? governorate,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryCompanyModel(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      companyName: companyName ?? this.companyName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerImagePath: ownerImagePath ?? this.ownerImagePath,
      governorate: governorate ?? this.governorate,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DeliveryCompanyModel.fromMap(Map<String, dynamic> map) {
    return DeliveryCompanyModel(
      id: map['id'] as String? ?? '',
      adminId: map['admin_id'] as String?,
      companyName: map['company_name'] as String? ?? '',
      ownerEmail: map['owner_email'] as String?,
      ownerName: map['owner_name'] as String?,
      ownerPhone: map['owner_phone'] as String?,
      ownerImagePath: map['owner_image_path'] as String?,
      governorate: map['governorate'] as String?,
      city: map['city'] as String? ?? '',
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admin_id': adminId,
      'company_name': companyName,
      'owner_email': ownerEmail,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'owner_image_path': ownerImagePath,
      'governorate': governorate,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    adminId,
    companyName,
    ownerEmail,
    ownerName,
    ownerPhone,
    ownerImagePath,
    governorate,
    city,
    address,
    latitude,
    longitude,
    createdAt,
    updatedAt,
  ];
}
