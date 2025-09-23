class ProductModel {
  // Properties
  final String id;
  final String name;
  final String description;
  final double price;
  final double? salePrice;
  final String categoryId;
  final String storeId;
  final bool isAvailable;
  final List<String> images;
  final int stockQuantity;
  final String? unit;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Store info (joined data)
  final String? storeName;
  final String? storeLogoUrl;
  final double? storeRating;

  // Category info (joined data)
  final String? categoryName;
  final String? categoryImage;

  // Getters
  bool get inStock => isAvailable && stockQuantity > 0;
  String get imageUrl => images.isNotEmpty ? images.first : '';
  bool get hasDiscount => salePrice != null && salePrice! < price;
  double get finalPrice => salePrice ?? price;
  double get discountPercentage => hasDiscount
      ? ((price - salePrice!) / price * 100).roundToDouble()
      : 0.0;

  // Constructor
  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.salePrice,
    required this.categoryId,
    required this.storeId,
    this.isAvailable = true,
    required this.images,
    required this.stockQuantity,
    this.unit,
    this.rating = 0,
    this.ratingCount = 0,
    required this.createdAt,
    this.updatedAt,
    // Store info
    this.storeName,
    this.storeLogoUrl,
    this.storeRating,
    // Category info
    this.categoryName,
    this.categoryImage,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final storeData = map['store'] as Map<String, dynamic>?;
    final categoryData = map['category'] as Map<String, dynamic>?;

    return ProductModel(
      id: id ?? map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      salePrice: map['sale_price']?.toDouble(),
      categoryId: map['category_id'] ?? '',
      storeId: map['store_id'] ?? '',
      isAvailable: map['is_available'] ?? true,
      images: List<String>.from(map['images'] ?? []),
      stockQuantity: map['stock_quantity'] ?? 0,
      unit: map['unit'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      ratingCount: map['rating_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      // Store info
      storeName: storeData?['name'],
      storeLogoUrl: storeData?['logo_url'],
      storeRating: storeData?['rating']?.toDouble(),
      // Category info
      categoryName: categoryData?['name'],
      categoryImage: categoryData?['image_url'],
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final storeData = json['store'] as Map<String, dynamic>?;
    final categoryData = json['category'] as Map<String, dynamic>?;

    return ProductModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      categoryId: json['category_id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      images: List<String>.from(json['images'] ?? []),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      unit: json['unit'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      // Store info
      storeName: storeData?['name'] as String?,
      storeLogoUrl: storeData?['logo_url'] as String?,
      storeRating: (storeData?['rating'] as num?)?.toDouble(),
      // Category info
      categoryName: categoryData?['name'] as String?,
      categoryImage: categoryData?['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'sale_price': salePrice,
      'category_id': categoryId,
      'store_id': storeId,
      'is_available': isAvailable,
      'images': images,
      'stock_quantity': stockQuantity,
      'unit': unit,
      'rating': rating,
      'rating_count': ratingCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  ProductModel copyWith({
    String? name,
    String? description,
    double? price,
    double? salePrice,
    String? categoryId,
    bool? isAvailable,
    List<String>? images,
    int? stockQuantity,
    String? unit,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      categoryId: categoryId ?? this.categoryId,
      storeId: storeId,
      isAvailable: isAvailable ?? this.isAvailable,
      images: images ?? this.images,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      unit: unit ?? this.unit,
      rating: rating,
      ratingCount: ratingCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      storeRating: storeRating,
      categoryName: categoryName,
      categoryImage: categoryImage,
    );
  }

  @override
  String toString() => 'ProductModel(id: $id, name: $name, price: $price)';
}
