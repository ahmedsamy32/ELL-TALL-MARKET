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

  // معلومات المركبة
  final String
  vehicleType; // TEXT CHECK ('motorcycle', 'car', 'bicycle', 'truck')
  final String? vehicleNumber;
  final String? licenseNumber; // UNIQUE
  final String? nationalId;

  // الحالة
  final String status; // CHECK ('online', 'offline', 'busy') DEFAULT 'offline'
  final bool isVerified;
  final bool isActive;
  final bool isAvailable;
  final bool isOnline;
  final String verificationStatus; // CHECK ('pending', 'approved', 'rejected')

  // الموقع
  final double? latitude;
  final double? longitude;

  // التقييم والإحصائيات
  final double rating;
  final int ratingCount;
  final int totalDeliveries;
  final double totalEarnings;
  final double earningsToday;

  // الصور والمستندات
  final String? profileImageUrl;
  final String? licenseImageUrl;
  final String? vehicleImageUrl;

  // أوقات العمل والمناطق
  final Map<String, dynamic> workingHours;
  final List<dynamic> workingAreas;
  final String? contactPhone;

  // بيانات إضافية
  final Map<String, dynamic> additionalData;
  final DateTime? lastAvailableAt;

  // بيانات البروفايل المرتبطة (عند select مع profiles)
  final String? fullName;
  final String? email;
  final String? profilePhone;

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const CaptainModel({
    required this.id,
    required this.vehicleType,
    this.vehicleNumber,
    this.licenseNumber,
    this.nationalId,
    this.status = 'offline',
    this.isVerified = false,
    this.isActive = true,
    this.isAvailable = true,
    this.isOnline = false,
    this.verificationStatus = 'pending',
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalDeliveries = 0,
    this.totalEarnings = 0.0,
    this.earningsToday = 0.0,
    this.profileImageUrl,
    this.licenseImageUrl,
    this.vehicleImageUrl,
    this.workingHours = const {},
    this.workingAreas = const [],
    this.contactPhone,
    this.additionalData = const {},
    this.lastAvailableAt,
    this.fullName,
    this.email,
    this.profilePhone,
    required this.createdAt,
    this.updatedAt,
  });

  factory CaptainModel.fromMap(Map<String, dynamic> map) {
    final profileMap = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;

    return CaptainModel(
      id: map['id'] as String,
      vehicleType: map['vehicle_type'] as String? ?? 'motorcycle',
      vehicleNumber: map['vehicle_number'] as String?,
      licenseNumber: map['license_number'] as String?,
      nationalId: map['national_id'] as String?,
      status: map['status'] as String? ?? 'offline',
      isVerified: map['is_verified'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      isAvailable: map['is_available'] as bool? ?? true,
      isOnline: map['is_online'] as bool? ?? false,
      verificationStatus: map['verification_status'] as String? ?? 'pending',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: map['rating_count'] as int? ?? 0,
      totalDeliveries: map['total_deliveries'] as int? ?? 0,
      totalEarnings: (map['total_earnings'] as num?)?.toDouble() ?? 0.0,
      earningsToday: (map['earnings_today'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: map['profile_image_url'] as String?,
      licenseImageUrl: map['license_image_url'] as String?,
      vehicleImageUrl: map['vehicle_image_url'] as String?,
      workingHours: map['working_hours'] is Map
          ? Map<String, dynamic>.from(map['working_hours'] as Map)
          : {},
      workingAreas: map['working_areas'] is List
          ? List<dynamic>.from(map['working_areas'] as List)
          : [],
      contactPhone: map['contact_phone'] as String?,
      additionalData: map['additional_data'] is Map
          ? Map<String, dynamic>.from(map['additional_data'] as Map)
          : {},
      lastAvailableAt: map['last_available_at'] != null
          ? BaseModelMixin.parseDateTime(map['last_available_at'])
          : null,
      fullName: profileMap?['full_name'] as String?,
      email: profileMap?['email'] as String?,
      profilePhone: profileMap?['phone'] as String?,
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
      'national_id': nationalId,
      'status': status,
      'is_verified': isVerified,
      'is_active': isActive,
      'is_available': isAvailable,
      'is_online': isOnline,
      'verification_status': verificationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'rating_count': ratingCount,
      'total_deliveries': totalDeliveries,
      'total_earnings': totalEarnings,
      'earnings_today': earningsToday,
      'profile_image_url': profileImageUrl,
      'license_image_url': licenseImageUrl,
      'vehicle_image_url': vehicleImageUrl,
      'working_hours': workingHours,
      'working_areas': workingAreas,
      'contact_phone': contactPhone,
      'additional_data': additionalData,
      'last_available_at': lastAvailableAt?.toIso8601String(),
      'full_name': fullName,
      'email': email,
      'profile_phone': profilePhone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// For insert/update operations, exclude auto-generated fields
  Map<String, dynamic> toDatabaseMap() {
    return {
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'license_number': licenseNumber,
      'national_id': nationalId,
      'status': status,
      'is_verified': isVerified,
      'is_active': isActive,
      'is_available': isAvailable,
      'is_online': isOnline,
      'verification_status': verificationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'rating_count': ratingCount,
      'total_deliveries': totalDeliveries,
      'total_earnings': totalEarnings,
      'earnings_today': earningsToday,
      'profile_image_url': profileImageUrl,
      'license_image_url': licenseImageUrl,
      'vehicle_image_url': vehicleImageUrl,
      'working_hours': workingHours,
      'working_areas': workingAreas,
      'contact_phone': contactPhone,
      'additional_data': additionalData,
      'last_available_at': lastAvailableAt?.toIso8601String(),
    };
  }

  CaptainModel copyWith({
    String? id,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    String? nationalId,
    String? status,
    bool? isVerified,
    bool? isActive,
    bool? isAvailable,
    bool? isOnline,
    String? verificationStatus,
    double? latitude,
    double? longitude,
    double? rating,
    int? ratingCount,
    int? totalDeliveries,
    double? totalEarnings,
    double? earningsToday,
    String? profileImageUrl,
    String? licenseImageUrl,
    String? vehicleImageUrl,
    Map<String, dynamic>? workingHours,
    List<dynamic>? workingAreas,
    String? contactPhone,
    Map<String, dynamic>? additionalData,
    DateTime? lastAvailableAt,
    String? fullName,
    String? email,
    String? profilePhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CaptainModel(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      nationalId: nationalId ?? this.nationalId,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnline: isOnline ?? this.isOnline,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      earningsToday: earningsToday ?? this.earningsToday,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
      workingHours: workingHours ?? this.workingHours,
      workingAreas: workingAreas ?? this.workingAreas,
      contactPhone: contactPhone ?? this.contactPhone,
      additionalData: additionalData ?? this.additionalData,
      lastAvailableAt: lastAvailableAt ?? this.lastAvailableAt,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profilePhone: profilePhone ?? this.profilePhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Helper Getters ──────────────────────────────

  bool get hasVehicleNumber =>
      vehicleNumber != null && vehicleNumber!.isNotEmpty;
  bool get hasDriverLicense =>
      licenseNumber != null && licenseNumber!.isNotEmpty;
  bool get isApproved => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';
  bool get canReceiveOrders =>
      isActive && isAvailable && isOnline && isApproved;

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
      case 'online':
        return 'متصل';
      case 'offline':
        return 'غير متصل';
      case 'busy':
        return 'مشغول';
      default:
        return 'غير محدد';
    }
  }

  String get verificationStatusText {
    switch (verificationStatus) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مُعتمد';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير محدد';
    }
  }

  // Backward compatibility
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
