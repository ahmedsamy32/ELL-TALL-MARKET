class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? imageUrl;
  final String? parentId;
  final bool isActive;
  final bool isFeatured;
  final int order;
  final int productCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.imageUrl,
    this.parentId,
    this.isActive = true,
    this.isFeatured = false,
    this.order = 0,
    this.productCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'image_url': imageUrl,
      'parent_id': parentId,
      'is_active': isActive,
      'is_featured': isFeatured,
      'order': order,
      'product_count': productCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel.fromMap(json);

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'],
      imageUrl: map['image_url'],
      parentId: map['parent_id'],
      isActive: map['is_active'] ?? true,
      isFeatured: map['is_featured'] ?? false,
      order: map['order'] ?? 0,
      productCount: map['product_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  CategoryModel copyWith({
    String? name,
    String? icon,
    String? imageUrl,
    String? parentId,
    bool? isActive,
    bool? isFeatured,
    int? order,
    int? productCount,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      order: order ?? this.order,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}
