enum UserType { customer, merchant, captain, admin }

class UserModel {
  final String id;
  final String? firebaseId; // ✅ إضافة Firebase ID
  final String name;
  final String email;
  final String phone;
  final UserType type;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final DateTime? lastLogin;
  final int loginCount;
  final String? storeId;
  final String? preferredPaymentMethod;
  final String? address; // User's delivery address
  // Store related fields
  final String? storeName;
  final String? storeDescription;
  final String? storeLogoUrl;
  final String? storeCoverUrl;
  final String? storeAddress;
  final Map<String, double>? storeLocation;
  final String? storeCategory;
  final double storeRating;
  final int storeRatingCount;

  UserModel({
    required this.id,
    this.firebaseId, // ✅ إضافة Firebase ID
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    this.avatarUrl,
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
    this.lastLogin,
    this.loginCount = 0,
    this.storeId,
    this.preferredPaymentMethod,
    this.address,
    this.storeName,
    this.storeDescription,
    this.storeLogoUrl,
    this.storeCoverUrl,
    this.storeAddress,
    this.storeLocation,
    this.storeCategory,
    this.storeRating = 0,
    this.storeRatingCount = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final storeData = map['store'] as Map<String, dynamic>?;

    String? locationString = storeData?['location'] as String?;
    Map<String, double>? locationMap;

    if (locationString != null) {
      final parts = locationString.split(',');
      if (parts.length == 2) {
        locationMap = {
          'lat': double.tryParse(parts[0]) ?? 0.0,
          'lng': double.tryParse(parts[1]) ?? 0.0,
        };
      }
    }

    return UserModel(
      id: id,
      firebaseId: map['firebase_id'], // ✅ إضافة Firebase ID
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      type: _parseUserType(map['type']),
      avatarUrl: map['avatar_url'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      isActive: map['is_active'] ?? true,
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'])
          : null,
      loginCount: map['login_count'] ?? 0,
      storeId: map['store_id'],
      preferredPaymentMethod: map['preferred_payment_method'],
      storeName: storeData?['name'],
      storeDescription: storeData?['description'],
      address: map['address'], // Added to fromMap
      storeCoverUrl: storeData?['cover_url'],
      storeAddress: storeData?['address'],
      storeLocation: locationMap,
      storeCategory: storeData?['category'],
      storeRating: (storeData?['rating'] ?? 0.0).toDouble(),
      storeRatingCount: storeData?['rating_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'type': type.toString().split('.').last,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'login_count': loginCount,
      'store_id': storeId,
      'preferred_payment_method': preferredPaymentMethod,
      'address': address,
    };
  }

  Map<String, dynamic> toStoreMap() {
    if (type != UserType.merchant) return {};

    return {
      'id': storeId ?? id,
      'name': storeName ?? name,
      'description': storeDescription,
      'logo_url': storeLogoUrl,
      'cover_url': storeCoverUrl,
      'address': storeAddress,
      'location': storeLocation != null
          ? '${storeLocation!['lat']},${storeLocation!['lng']}'
          : null,
      'owner_id': id,
      'category': storeCategory,
      'is_active': isActive,
      'rating': storeRating,
      'rating_count': storeRatingCount,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserType? type,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    DateTime? lastLogin,
    int? loginCount,
    String? storeId,
    String? preferredPaymentMethod,
    String? address,
    String? storeName,
    String? storeDescription,
    String? storeLogoUrl,
    String? storeCoverUrl,
    String? storeAddress,
    Map<String, double>? storeLocation,
    String? storeCategory,
    double? storeRating,
    int? storeRatingCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      loginCount: loginCount ?? this.loginCount,
      storeId: storeId ?? this.storeId,
      preferredPaymentMethod:
          preferredPaymentMethod ?? this.preferredPaymentMethod,
      address: address ?? this.address,
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
      storeCoverUrl: storeCoverUrl ?? this.storeCoverUrl,
      storeAddress: storeAddress ?? this.storeAddress,
      storeLocation: storeLocation ?? this.storeLocation,
      storeCategory: storeCategory ?? this.storeCategory,
      storeRating: storeRating ?? this.storeRating,
      storeRatingCount: storeRatingCount ?? this.storeRatingCount,
    );
  }

  static UserType _parseUserType(String? type) {
    switch (type?.toLowerCase()) {
      case 'admin':
        return UserType.admin;
      case 'merchant':
        return UserType.merchant;
      case 'captain':
        return UserType.captain;
      default:
        return UserType.customer;
    }
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, type: $type)';
}
