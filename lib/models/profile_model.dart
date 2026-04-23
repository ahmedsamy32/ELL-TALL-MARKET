/// Profile Model - Authentication and User Profiles
/// Used by supabase_provider.dart and supabase_service.dart
/// Matches the 'profiles' table in Supabase database
library;

import 'package:intl/intl.dart';

/// User Role Enum - matches database CHECK constraint
/// role TEXT CHECK (role IN ('client', 'merchant', 'captain', 'admin', 'delivery_company_admin'))
enum UserRole {
  client,
  merchant,
  captain,
  admin,
  deliveryCompanyAdmin;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'client':
        return UserRole.client;
      case 'merchant':
        return UserRole.merchant;
      case 'captain':
        return UserRole.captain;
      case 'admin':
        return UserRole.admin;
      case 'delivery_company_admin':
        return UserRole.deliveryCompanyAdmin;
      default:
        return UserRole.client;
    }
  }

  String get value {
    switch (this) {
      case UserRole.deliveryCompanyAdmin:
        return 'delivery_company_admin';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'عميل';
      case UserRole.merchant:
        return 'تاجر';
      case UserRole.captain:
        return 'كابتن';
      case UserRole.admin:
        return 'مدير';
      case UserRole.deliveryCompanyAdmin:
        return 'مسؤول شركة توصيل';
    }
  }
}

/// ProfileModel - matches 'profiles' table
class ProfileModel {
  static const String tableName = 'profiles';

  final String id; // UUID PRIMARY KEY REFERENCES auth.users(id)
  final String? fullName; // full_name TEXT
  final String? email; // email TEXT UNIQUE
  final String? phone; // phone TEXT
  final String? password; // password TEXT
  final String? avatarUrl; // avatar_url TEXT
  final UserRole role; // role TEXT DEFAULT 'client'
  final String? fcmToken; // fcm_token TEXT
  final bool isActive; // is_active BOOLEAN DEFAULT TRUE
  final bool isOnline; // is_online BOOLEAN DEFAULT FALSE
  final DateTime? birthDate; // birth_date DATE
  final String? gender; // gender TEXT CHECK (gender IN ('male', 'female'))
  final DateTime createdAt; // created_at TIMESTAMPTZ DEFAULT NOW()
  final DateTime? updatedAt; // updated_at TIMESTAMPTZ
  final DateTime? lastAvailableAt; // last_available_at TIMESTAMPTZ

  const ProfileModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.password,
    this.avatarUrl,
    required this.role,
    this.fcmToken,
    this.isActive = true,
    this.isOnline = false,
    this.birthDate,
    this.gender,
    required this.createdAt,
    this.updatedAt,
    this.lastAvailableAt,
  });

  /// Create from Supabase response
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      password: map['password'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      fcmToken: map['fcm_token'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      isOnline: (map['is_online'] as bool?) ?? false,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      gender: map['gender'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      lastAvailableAt: map['last_available_at'] != null
          ? DateTime.parse(map['last_available_at'] as String)
          : null,
    );
  }

  /// Convert to map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'avatar_url': avatarUrl,
      'role': role.value,
      'fcm_token': fcmToken,
      'is_active': isActive,
      'is_online': isOnline,
      'birth_date': birthDate?.toIso8601String().split(
        'T',
      )[0], // yyyy-MM-dd format
      'gender': gender,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_available_at': lastAvailableAt?.toIso8601String(),
    };
  }

  /// Copy with updated fields
  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? password,
    String? avatarUrl,
    UserRole? role,
    String? fcmToken,
    bool? isActive,
    bool? isOnline,
    DateTime? birthDate,
    String? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAvailableAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAvailableAt: lastAvailableAt ?? this.lastAvailableAt,
    );
  }

  // Helper getters
  String get displayName => fullName ?? email ?? 'مستخدم';
  String get roleDisplayName => role.displayName;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  bool get isClient => role == UserRole.client;
  bool get isMerchant => role == UserRole.merchant;
  bool get isCaptain => role == UserRole.captain;
  bool get isAdmin => role == UserRole.admin;
  bool get isDeliveryCompanyAdmin => role == UserRole.deliveryCompanyAdmin;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);

  @override
  String toString() =>
      'ProfileModel(id: $id, fullName: $fullName, role: ${role.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
