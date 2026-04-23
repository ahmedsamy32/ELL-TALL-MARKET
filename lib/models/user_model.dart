/// User Management Model
library;

import 'profile_model.dart'; // Import UserRole from profile_model

class UserModel {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'full_name': fullName,
      'role': role.value,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static const String tableName = 'profiles';
}
