/// Product model that matches the Supabase products table
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

/// Product model that matches the Supabase products table
class ProductModel with BaseModelMixin {
  static const String tableName = 'products';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String storeId; // UUID REFERENCES stores(id) ON DELETE CASCADE
  final String? categoryId; // UUID REFERENCES categories(id)
  final String name; // TEXT NOT NULL
  final String? description; // TEXT
  final double price; // DECIMAL(10,2) NOT NULL
  final double? comparePrice; // DECIMAL(10,2)
  final double? costPrice; // DECIMAL(10,2)
  final String? imageUrl; // TEXT
  final bool inStock; // BOOLEAN DEFAULT TRUE
  final int stockQuantity; // INT DEFAULT 0
  final bool isActive; // BOOLEAN DEFAULT TRUE
  final List<String>? tags; // TEXT[]
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.comparePrice,
    this.costPrice,
    this.imageUrl,
    this.inStock = true,
    this.stockQuantity = 0,
    this.isActive = true,
    this.tags,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: double.parse(map['price'].toString()),
      comparePrice: map['compare_price'] != null
          ? double.parse(map['compare_price'].toString())
          : null,
      costPrice: map['cost_price'] != null
          ? double.parse(map['cost_price'].toString())
          : null,
      imageUrl: map['image_url'] as String?,
      inStock: map['in_stock'] as bool? ?? true,
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory ProductModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return ProductModel.fromMap(data);
  }

  factory ProductModel.empty() {
    return ProductModel(
      id: '',
      storeId: '',
      name: '',
      price: 0.0,
      stockQuantity: 0,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'compare_price': comparePrice,
      'cost_price': costPrice,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'tags': tags,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'store_id': storeId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'compare_price': comparePrice,
      'cost_price': costPrice,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'tags': tags,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    double? comparePrice,
    double? costPrice,
    String? imageUrl,
    bool? inStock,
    int? stockQuantity,
    bool? isActive,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      comparePrice: comparePrice ?? this.comparePrice,
      costPrice: costPrice ?? this.costPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Backward compatibility - alias for stockQuantity
  int get stock => stockQuantity;

  bool get isAvailable => inStock && stockQuantity > 0;
  bool get isOutOfStock => !inStock || stockQuantity <= 0;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasDescription => description != null && description!.isNotEmpty;
  bool get hasCategory => categoryId != null;

  String get stockStatus {
    if (!isActive) return 'غير متاح';
    if (!inStock) return 'نفدت الكمية';
    if (stockQuantity > 10) return 'متوفر';
    if (stockQuantity > 0) return 'كمية محدودة';
    return 'نفدت الكمية';
  }

  String get priceFormatted => '${price.toStringAsFixed(2)} ج.م';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $price, stockQuantity: $stockQuantity)';
  }
}
