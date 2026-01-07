/// Store model that matches the Supabase stores table
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

/// Store model matching the actual Supabase stores table schema
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
class StoreModel with BaseModelMixin {
  static const String tableName = 'stores';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String merchantId; // UUID REFERENCES merchants(id) ON DELETE CASCADE
  final String name; // TEXT NOT NULL
  final String? description; // TEXT
  final String? phone; // TEXT
  final String address; // TEXT NOT NULL
  final String? city; // TEXT - المدينة
  final String? governorate; // TEXT - المحافظة
  final double? latitude; // DECIMAL(10, 8)
  final double? longitude; // DECIMAL(11, 8)
  final int deliveryTime; // INT DEFAULT 30
  final bool isOpen; // BOOLEAN DEFAULT TRUE
  final double deliveryFee; // DECIMAL(10,2) DEFAULT 0
  final double minOrder; // DECIMAL(10,2) DEFAULT 0
  final String deliveryMode; // TEXT CHECK store/app
  final double rating; // DECIMAL(2,1) DEFAULT 0.0
  final int reviewCount; // INT DEFAULT 0
  final String? category; // TEXT
  final Map<String, dynamic>? openingHours; // JSONB DEFAULT '{}'
  final String? imageUrl; // TEXT
  final String? coverUrl; // TEXT - رابط صورة الغلاف
  final bool isActive; // BOOLEAN DEFAULT TRUE
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const StoreModel({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    this.phone,
    required this.address,
    this.city,
    this.governorate,
    this.latitude,
    this.longitude,
    this.deliveryTime = 30,
    this.isOpen = true,
    this.deliveryFee = 0.0,
    this.minOrder = 0.0,
    this.deliveryMode = 'store',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.category,
    this.openingHours,
    this.imageUrl,
    this.coverUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String,
      city: map['city'] as String?,
      governorate: map['governorate'] as String?,
      latitude: map['latitude'] != null
          ? double.parse(map['latitude'].toString())
          : null,
      longitude: map['longitude'] != null
          ? double.parse(map['longitude'].toString())
          : null,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
      deliveryTime: map['delivery_time'] as int? ?? 30,
      isOpen: map['is_open'] as bool? ?? true,
      deliveryFee: map['delivery_fee'] != null
          ? double.parse(map['delivery_fee'].toString())
          : 0.0,
      minOrder: map['min_order'] != null
          ? double.parse(map['min_order'].toString())
          : 0.0,
      deliveryMode: map['delivery_mode'] as String? ?? 'store',
      rating: map['rating'] != null
          ? double.parse(map['rating'].toString())
          : 0.0,
      reviewCount: map['review_count'] as int? ?? 0,
      category: map['category'] as String?,
      openingHours: map['opening_hours'] as Map<String, dynamic>?,
      imageUrl: map['image_url'] as String?,
      coverUrl: map['cover_url'] as String?,
    );
  }

  factory StoreModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return StoreModel.fromMap(data);
  }

  factory StoreModel.fromSupabaseMap(Map<String, dynamic> map) {
    return StoreModel.fromMap(map);
  }

  factory StoreModel.empty() {
    return StoreModel(
      id: '',
      merchantId: '',
      name: '',
      address: '',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'name': name,
      'description': description,
      'phone': phone,
      'address': address,
      'city': city,
      'governorate': governorate,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'delivery_time': deliveryTime,
      'is_open': isOpen,
      'delivery_fee': deliveryFee,
      'min_order': minOrder,
      'delivery_mode': deliveryMode,
      'rating': rating,
      'review_count': reviewCount,
      'category': category,
      'opening_hours': openingHours,
      'image_url': imageUrl,
      'cover_url': coverUrl,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'merchant_id': merchantId,
      'name': name,
      'description': description,
      'phone': phone,
      'address': address,
      'city': city,
      'governorate': governorate,
      'latitude': latitude,
      'longitude': longitude,
      'delivery_time': deliveryTime,
      'is_open': isOpen,
      'delivery_fee': deliveryFee,
      'min_order': minOrder,
      'delivery_mode': deliveryMode,
      'rating': rating,
      'review_count': reviewCount,
      'category': category,
      'opening_hours': openingHours,
      'image_url': imageUrl,
      'cover_url': coverUrl,
      'is_active': isActive,
    };
  }

  StoreModel copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? description,
    String? phone,
    String? address,
    String? city,
    String? governorate,
    double? latitude,
    double? longitude,
    int? deliveryTime,
    bool? isOpen,
    double? deliveryFee,
    double? minOrder,
    double? rating,
    String? deliveryMode,
    int? reviewCount,
    String? category,
    Map<String, dynamic>? openingHours,
    String? imageUrl,
    String? coverUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      governorate: governorate ?? this.governorate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      isOpen: isOpen ?? this.isOpen,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minOrder: minOrder ?? this.minOrder,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      category: category ?? this.category,
      openingHours: openingHours ?? this.openingHours,
      imageUrl: imageUrl ?? this.imageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Computed getters
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasDescription => description != null && description!.isNotEmpty;
  bool get hasAddress => address.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasCategory => category != null && category!.isNotEmpty;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasOpeningHours => openingHours != null && openingHours!.isNotEmpty;
  bool get hasCover => coverUrl != null && coverUrl!.isNotEmpty;
  bool get deliversOwnOrders => deliveryMode == 'store';
  bool get usesPlatformDelivery => deliveryMode == 'app';

  // Helper getters for UI
  String get displayAddress => hasAddress ? address : 'عنوان غير محدد';
  String get displayImageUrl => hasImage ? imageUrl! : '';
  String get displayCoverUrl => hasCover ? coverUrl! : '';
  String get ratingDisplay =>
      rating > 0 ? '${rating.toStringAsFixed(1)} ⭐' : 'غير مقيم';

  String get deliveryTimeFormatted => '$deliveryTime دقيقة';
  String get deliveryFeeFormatted =>
      deliveryFee == 0 ? 'مجاناً' : '${deliveryFee.toStringAsFixed(2)} ر.س';
  String get minOrderFormatted => '${minOrder.toStringAsFixed(2)} ر.س';
  String get ratingFormatted => rating.toStringAsFixed(1);

  bool get hasFreeDelivery => deliveryFee == 0;
  bool get hasMinOrder => minOrder > 0;

  // Backward compatibility getters
  String? get location => address;
  String? get logoUrl => imageUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'StoreModel(id: $id, merchantId: $merchantId, name: $name, deliveryMode: $deliveryMode, isActive: $isActive)';
  }
}
