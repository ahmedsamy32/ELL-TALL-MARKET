/// Favorites model that matches the Supabase favorites table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base mixin for common model functionality
mixin BaseModelMixin {
  String get id;
  DateTime get createdAt;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);

  static DateTime parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }
}

/// Favorites model that matches the Supabase favorites table
class FavoritesModel with BaseModelMixin {
  static const String tableName = 'favorites';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String userId; // UUID REFERENCES auth.users(id) ON DELETE CASCADE
  final String? productId; // UUID REFERENCES products(id) ON DELETE CASCADE
  final String? storeId; // UUID REFERENCES stores(id) ON DELETE CASCADE
  @override
  final DateTime createdAt; // TIMESTAMPTZ DEFAULT NOW()

  const FavoritesModel({
    required this.id,
    required this.userId,
    this.productId,
    this.storeId,
    required this.createdAt,
  }) : assert(
         (productId != null && storeId == null) ||
             (productId == null && storeId != null),
         'يجب تحديد إما productId أو storeId وليس كلاهما',
       );

  factory FavoritesModel.fromMap(Map<String, dynamic> map) {
    return FavoritesModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      productId: map['product_id'] as String?,
      storeId: map['store_id'] as String?,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
    );
  }

  factory FavoritesModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return FavoritesModel.fromMap(data);
  }

  factory FavoritesModel.empty() {
    return FavoritesModel(id: '', userId: '', createdAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'store_id': storeId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {'user_id': userId, 'product_id': productId, 'store_id': storeId};
  }

  FavoritesModel copyWith({
    String? id,
    String? userId,
    String? productId,
    String? storeId,
    DateTime? createdAt,
  }) {
    return FavoritesModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Computed getters
  bool get isProductFavorite => productId != null;
  bool get isStoreFavorite => storeId != null;
  bool get isValid =>
      userId.isNotEmpty && (productId != null || storeId != null);

  String get itemType => isProductFavorite ? 'product' : 'store';
  String get itemId => productId ?? storeId ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoritesModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          productId == other.productId &&
          storeId == other.storeId;

  @override
  int get hashCode => userId.hashCode ^ productId.hashCode ^ storeId.hashCode;

  @override
  String toString() {
    return 'FavoritesModel(id: $id, userId: $userId, productId: $productId, storeId: $storeId)';
  }
}
