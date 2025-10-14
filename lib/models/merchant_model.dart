/// Merchant model that matches the new Supabase merchants table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';

/// Merchant model that matches the new Supabase merchants table
class MerchantModel {
  static const String tableName = 'merchants';
  static const String schema = 'public';

  final String id; // UUID that references profiles(id)
  final String storeName;
  final String? storeDescription;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MerchantModel({
    required this.id,
    required this.storeName,
    this.storeDescription,
    this.address,
    this.latitude,
    this.longitude,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory MerchantModel.fromMap(Map<String, dynamic> map) {
    return MerchantModel(
      id: map['id'] as String,
      storeName: map['store_name'] as String,
      storeDescription: map['store_description'] as String?,
      address: map['address'] as String?,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      isVerified: map['is_verified'] as bool? ?? false,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? _parseDateTime(map['updated_at'])
          : null,
    );
  }

  static DateTime _parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }

  // Formatted date getters
  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get updatedAtFormatted => updatedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(updatedAt!)
      : 'لم يتم التحديث';

  factory MerchantModel.empty() {
    return MerchantModel(id: '', storeName: '', createdAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'store_description': storeDescription,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'store_name': storeName,
      'store_description': storeDescription,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
    };
  }

  MerchantModel copyWith({
    String? id,
    String? storeName,
    String? storeDescription,
    String? address,
    double? latitude,
    double? longitude,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Backward compatibility parameters
    bool? isActive,
    String? logoUrl,
  }) {
    return MerchantModel(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isVerified:
          isActive ?? isVerified ?? this.isVerified, // Use isActive if provided
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MerchantModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MerchantModel(id: $id, storeName: $storeName, isVerified: $isVerified)';
  }

  // Helper methods
  String get displayName => storeName;
  String get statusText => isVerified ? 'موثق' : 'غير موثق';
  bool get hasLocation => latitude != null && longitude != null;
  String get locationString =>
      hasLocation ? '$latitude, $longitude' : 'غير محدد';

  // Backward compatibility getters
  String get businessName => storeName;
  String? get businessAddress => address;
  String? get businessType => 'retail'; // Default business type
  String? get contactPhone => null; // Not available in current schema
  bool get isActive => isVerified; // Use verification status as active status
  String? get logoUrl => null; // Not available in current schema
}
