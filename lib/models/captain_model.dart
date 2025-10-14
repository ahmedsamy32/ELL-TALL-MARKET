/// Captain model that matches the Supabase captains table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base mixin for common model functionality (if not imported from user_model.dart)
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

/// Captain model that matches the Supabase captains table
class CaptainModel with BaseModelMixin {
  static const String tableName = 'captains';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE
  final String vehicleType; // vehicle_type_enum DEFAULT 'motorcycle'
  final String? vehicleNumber;
  final String? licenseNumber; // UNIQUE
  final String
  status; // CHECK (status IN ('online', 'offline', 'busy')) DEFAULT 'offline'
  final double? latitude; // DECIMAL(10, 8)
  final double? longitude; // DECIMAL(11, 8)
  final double rating; // DECIMAL(2,1) DEFAULT 0
  final int totalDeliveries; // INT DEFAULT 0
  final bool isVerified; // BOOLEAN DEFAULT FALSE
  final double earningsToday; // DECIMAL(10,2) DEFAULT 0
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const CaptainModel({
    required this.id,
    required this.vehicleType,
    this.vehicleNumber,
    this.licenseNumber,
    this.status = 'offline',
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.totalDeliveries = 0,
    this.isVerified = false,
    this.earningsToday = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory CaptainModel.fromMap(Map<String, dynamic> map) {
    return CaptainModel(
      id: map['id'] as String,
      vehicleType: map['vehicle_type'] as String? ?? 'motorcycle',
      vehicleNumber: map['vehicle_number'] as String?,
      licenseNumber: map['license_number'] as String?,
      status: map['status'] as String? ?? 'offline',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: map['total_deliveries'] as int? ?? 0,
      isVerified: map['is_verified'] as bool? ?? false,
      earningsToday: (map['earnings_today'] as num?)?.toDouble() ?? 0.0,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory CaptainModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return CaptainModel.fromMap(data);
  }

  factory CaptainModel.empty() {
    return CaptainModel(
      id: '',
      vehicleType: 'motorcycle',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'license_number': licenseNumber,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'is_verified': isVerified,
      'earnings_today': earningsToday,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'license_number': licenseNumber,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'is_verified': isVerified,
      'earnings_today': earningsToday,
    };
  }

  CaptainModel copyWith({
    String? id,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    String? status,
    double? latitude,
    double? longitude,
    double? rating,
    int? totalDeliveries,
    bool? isVerified,
    double? earningsToday,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CaptainModel(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      isVerified: isVerified ?? this.isVerified,
      earningsToday: earningsToday ?? this.earningsToday,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasVehicleNumber =>
      vehicleNumber != null && vehicleNumber!.isNotEmpty;
  bool get hasDriverLicense =>
      licenseNumber != null && licenseNumber!.isNotEmpty;

  String get vehicleTypeDisplayName {
    switch (vehicleType.toLowerCase()) {
      case 'motorcycle':
        return 'دراجة نارية';
      case 'car':
        return 'سيارة';
      case 'bicycle':
        return 'دراجة هوائية';
      case 'truck':
        return 'شاحنة';
      default:
        return vehicleType;
    }
  }

  String get statusText {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'offline':
        return 'غير متصل';
      case 'busy':
        return 'مشغول';
      default:
        return 'غير محدد';
    }
  }

  // Backward compatibility getters
  bool get isActive => status == 'active' || status == 'online';
  String? get driverLicense => licenseNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptainModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CaptainModel(id: $id, vehicleType: $vehicleType, status: $status, rating: $rating)';
  }
}
