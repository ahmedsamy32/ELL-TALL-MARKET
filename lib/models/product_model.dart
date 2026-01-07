/// Product model that matches the Supabase products table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/utils/helpers.dart';

/// Product Variants Models

/// Product variant option (e.g., Color: Red, Size: Large)
class ProductVariantOption {
  final String id;
  final String name;
  final String value;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductVariantOption({
    required this.id,
    required this.name,
    required this.value,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductVariantOption.fromJson(Map<String, dynamic> json) {
    return ProductVariantOption(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as String,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? BaseModelMixin.parseDateTime(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProductVariantOption copyWith({
    String? id,
    String? name,
    String? value,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariantOption(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Product variant group (e.g., Color, Size, Material)
class ProductVariantGroup {
  final String id;
  final String name;
  final String type; // 'color', 'size', 'material', 'custom'
  final List<ProductVariantOption> options;
  final bool isRequired;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductVariantGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.options,
    this.isRequired = false,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductVariantGroup.fromJson(Map<String, dynamic> json) {
    return ProductVariantGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (option) => ProductVariantOption.fromJson(
                  option as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? BaseModelMixin.parseDateTime(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'options': options.map((option) => option.toJson()).toList(),
      'is_required': isRequired,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProductVariantGroup copyWith({
    String? id,
    String? name,
    String? type,
    List<ProductVariantOption>? options,
    bool? isRequired,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariantGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Product variant (combination of options with price and stock)
class ProductVariant {
  final String id;
  final String productId;
  final List<ProductVariantOption> selectedOptions;
  final String sku;
  final double? price;
  final int? stockQuantity;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.selectedOptions,
    required this.sku,
    this.price,
    this.stockQuantity,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      selectedOptions:
          (json['selected_options'] as List<dynamic>?)
              ?.map(
                (option) => ProductVariantOption.fromJson(
                  option as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      sku: json['sku'] as String,
      price: json['price'] as double?,
      stockQuantity: json['stock_quantity'] as int?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? BaseModelMixin.parseDateTime(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'selected_options': selectedOptions
          .map((option) => option.toJson())
          .toList(),
      'sku': sku,
      'price': price,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProductVariant copyWith({
    String? id,
    String? productId,
    List<ProductVariantOption>? selectedOptions,
    String? sku,
    double? price,
    int? stockQuantity,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get variantName {
    return selectedOptions
        .map((option) => '${option.name}: ${option.value}')
        .join(', ');
  }

  String get variantShortName {
    return selectedOptions.map((option) => option.value).join(' - ');
  }
}

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

/// Advanced Pricing Models

/// Quantity-based pricing (bulk discounts)
class QuantityBasedPrice {
  final String id;
  final int minQuantity;
  final int? maxQuantity;
  final double price;
  final double? discountPercentage;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const QuantityBasedPrice({
    required this.id,
    required this.minQuantity,
    this.maxQuantity,
    required this.price,
    this.discountPercentage,
    this.description,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory QuantityBasedPrice.fromMap(Map<String, dynamic> map) {
    return QuantityBasedPrice(
      id: map['id'] as String,
      minQuantity: map['min_quantity'] as int,
      maxQuantity: map['max_quantity'] as int?,
      price: double.parse(map['price'].toString()),
      discountPercentage: map['discount_percentage'] != null
          ? double.parse(map['discount_percentage'].toString())
          : null,
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
      'price': price,
      'discount_percentage': discountPercentage,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  QuantityBasedPrice copyWith({
    String? id,
    int? minQuantity,
    int? maxQuantity,
    double? price,
    double? discountPercentage,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuantityBasedPrice(
      id: id ?? this.id,
      minQuantity: minQuantity ?? this.minQuantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QuantityBasedPrice(minQuantity: $minQuantity, maxQuantity: $maxQuantity, price: $price)';
  }
}

/// Seasonal offers
class SeasonalOffer {
  final String id;
  final String title;
  final String? description;
  final double? discountPercentage;
  final double? fixedDiscount;
  final double? offerPrice;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SeasonalOffer({
    required this.id,
    required this.title,
    this.description,
    this.discountPercentage,
    this.fixedDiscount,
    this.offerPrice,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory SeasonalOffer.fromMap(Map<String, dynamic> map) {
    return SeasonalOffer(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      discountPercentage: map['discount_percentage'] != null
          ? double.parse(map['discount_percentage'].toString())
          : null,
      fixedDiscount: map['fixed_discount'] != null
          ? double.parse(map['fixed_discount'].toString())
          : null,
      offerPrice: map['offer_price'] != null
          ? double.parse(map['offer_price'].toString())
          : null,
      startDate: BaseModelMixin.parseDateTime(map['start_date']),
      endDate: BaseModelMixin.parseDateTime(map['end_date']),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discount_percentage': discountPercentage,
      'fixed_discount': fixedDiscount,
      'offer_price': offerPrice,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  SeasonalOffer copyWith({
    String? id,
    String? title,
    String? description,
    double? discountPercentage,
    double? fixedDiscount,
    double? offerPrice,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SeasonalOffer(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      fixedDiscount: fixedDiscount ?? this.fixedDiscount,
      offerPrice: offerPrice ?? this.offerPrice,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  @override
  String toString() {
    return 'SeasonalOffer(title: $title, discountPercentage: $discountPercentage, startDate: $startDate, endDate: $endDate)';
  }
}

/// VIP customer pricing
class VIPPrice {
  final String id;
  final String customerGroupId;
  final String customerGroupName;
  final double price;
  final double? discountPercentage;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const VIPPrice({
    required this.id,
    required this.customerGroupId,
    required this.customerGroupName,
    required this.price,
    this.discountPercentage,
    this.description,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory VIPPrice.fromMap(Map<String, dynamic> map) {
    return VIPPrice(
      id: map['id'] as String,
      customerGroupId: map['customer_group_id'] as String,
      customerGroupName: map['customer_group_name'] as String,
      price: double.parse(map['price'].toString()),
      discountPercentage: map['discount_percentage'] != null
          ? double.parse(map['discount_percentage'].toString())
          : null,
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_group_id': customerGroupId,
      'customer_group_name': customerGroupName,
      'price': price,
      'discount_percentage': discountPercentage,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  VIPPrice copyWith({
    String? id,
    String? customerGroupId,
    String? customerGroupName,
    double? price,
    double? discountPercentage,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VIPPrice(
      id: id ?? this.id,
      customerGroupId: customerGroupId ?? this.customerGroupId,
      customerGroupName: customerGroupName ?? this.customerGroupName,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'VIPPrice(customerGroupName: $customerGroupName, price: $price)';
  }
}

/// Promotional discounts
class PromotionalDiscount {
  final String id;
  final String title;
  final String? description;
  final double? discountPercentage;
  final double? fixedDiscount;
  final double? maxDiscountAmount;
  final int? usageLimit;
  final int? usedCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PromotionalDiscount({
    required this.id,
    required this.title,
    this.description,
    this.discountPercentage,
    this.fixedDiscount,
    this.maxDiscountAmount,
    this.usageLimit,
    this.usedCount = 0,
    this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory PromotionalDiscount.fromMap(Map<String, dynamic> map) {
    return PromotionalDiscount(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      discountPercentage: map['discount_percentage'] != null
          ? double.parse(map['discount_percentage'].toString())
          : null,
      fixedDiscount: map['fixed_discount'] != null
          ? double.parse(map['fixed_discount'].toString())
          : null,
      maxDiscountAmount: map['max_discount_amount'] != null
          ? double.parse(map['max_discount_amount'].toString())
          : null,
      usageLimit: map['usage_limit'] as int?,
      usedCount: map['used_count'] as int? ?? 0,
      startDate: map['start_date'] != null
          ? BaseModelMixin.parseDateTime(map['start_date'])
          : null,
      endDate: map['end_date'] != null
          ? BaseModelMixin.parseDateTime(map['end_date'])
          : null,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discount_percentage': discountPercentage,
      'fixed_discount': fixedDiscount,
      'max_discount_amount': maxDiscountAmount,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  PromotionalDiscount copyWith({
    String? id,
    String? title,
    String? description,
    double? discountPercentage,
    double? fixedDiscount,
    double? maxDiscountAmount,
    int? usageLimit,
    int? usedCount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromotionalDiscount(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      fixedDiscount: fixedDiscount ?? this.fixedDiscount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    if (!isActive) return false;
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    if (usageLimit != null && usedCount != null && usedCount! >= usageLimit!) {
      return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'PromotionalDiscount(title: $title, discountPercentage: $discountPercentage)';
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
  final String? sectionId; // UUID REFERENCES store_sections(id)
  final String name; // TEXT NOT NULL
  final String? description; // TEXT
  final double price; // DECIMAL(10,2) NOT NULL
  final double? comparePrice; // DECIMAL(10,2)
  final double? costPrice; // DECIMAL(10,2)
  final String? imageUrl; // TEXT
  final List<String>? imageUrls; // TEXT[] - Multiple product images
  final bool inStock; // BOOLEAN DEFAULT TRUE
  final int stockQuantity; // INT DEFAULT 0
  final bool isActive; // BOOLEAN DEFAULT TRUE
  final List<String>? tags; // TEXT[]
  final List<QuantityBasedPrice>? quantityBasedPrices; // Advanced pricing
  final List<SeasonalOffer>? seasonalOffers; // Seasonal offers
  final List<VIPPrice>? vipPrices; // VIP customer pricing
  final List<PromotionalDiscount>?
  promotionalDiscounts; // Promotional discounts
  final List<ProductVariantGroup>? variantGroups; // Product variant groups
  final List<ProductVariant>? variants; // Product variants
  final Map<String, dynamic>?
  customFields; // JSONB - Category-specific dynamic fields
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    this.sectionId,
    required this.name,
    this.description,
    required this.price,
    this.comparePrice,
    this.costPrice,
    this.imageUrl,
    this.imageUrls,
    this.inStock = true,
    this.stockQuantity = 0,
    this.isActive = true,
    this.tags,
    this.quantityBasedPrices,
    this.seasonalOffers,
    this.vipPrices,
    this.promotionalDiscounts,
    this.variantGroups,
    this.variants,
    this.customFields,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      categoryId: map['category_id'] as String?,
      sectionId: map['section_id'] as String?,
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
      imageUrls: (() {
        final iu = map['image_urls'];
        if (iu == null) return null;
        try {
          if (iu is List) {
            return iu.map((e) => e.toString()).toList();
          } else if (iu is Map) {
            // بعض المشاريع تخزن image_urls كـ JSON Object بالمفاتيح 0,1,2,3
            final entries =
                iu.entries
                    .map(
                      (e) => MapEntry(
                        int.tryParse(e.key.toString()) ?? 0,
                        e.value.toString(),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
            return entries.map((e) => e.value).toList();
          }
        } catch (_) {}
        return null;
      })(),
      inStock: map['in_stock'] as bool? ?? true,
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      customFields: map['custom_fields'] != null
          ? Map<String, dynamic>.from(map['custom_fields'] as Map)
          : null,
      quantityBasedPrices: null, // Will be loaded separately
      seasonalOffers: null, // Will be loaded separately
      vipPrices: null, // Will be loaded separately
      promotionalDiscounts: null, // Will be loaded separately
      variantGroups: null, // Will be loaded separately
      variants: null, // Will be loaded separately
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
      'section_id': sectionId,
      'name': name,
      'description': description,
      'price': price,
      'compare_price': comparePrice,
      'cost_price': costPrice,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'tags': tags,
      'image_url': imageUrl,
      'custom_fields': customFields,
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
      'section_id': sectionId,
      'name': name,
      'description': description,
      'price': price,
      'compare_price': comparePrice,
      'cost_price': costPrice,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'tags': tags,
      'image_url': imageUrl,
      'image_urls': imageUrls, // ✅ تفعيل حفظ الصور المتعددة
      'custom_fields': customFields,
      'is_active': isActive,
    };
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? categoryId,
    String? sectionId,
    String? name,
    String? description,
    double? price,
    double? comparePrice,
    double? costPrice,
    String? imageUrl,
    List<String>? imageUrls,
    bool? inStock,
    int? stockQuantity,
    bool? isActive,
    List<String>? tags,
    Map<String, dynamic>? customFields,
    List<QuantityBasedPrice>? quantityBasedPrices,
    List<SeasonalOffer>? seasonalOffers,
    List<VIPPrice>? vipPrices,
    List<PromotionalDiscount>? promotionalDiscounts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      sectionId: sectionId ?? this.sectionId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      comparePrice: comparePrice ?? this.comparePrice,
      costPrice: costPrice ?? this.costPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      customFields: customFields ?? this.customFields,
      quantityBasedPrices: quantityBasedPrices ?? this.quantityBasedPrices,
      seasonalOffers: seasonalOffers ?? this.seasonalOffers,
      vipPrices: vipPrices ?? this.vipPrices,
      promotionalDiscounts: promotionalDiscounts ?? this.promotionalDiscounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Backward compatibility - alias for stockQuantity
  int get stock => stockQuantity;

  bool get isAvailable => inStock && stockQuantity > 0;
  bool get isOutOfStock => !inStock || stockQuantity <= 0;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasMultipleImages => imageUrls != null && imageUrls!.isNotEmpty;
  bool get hasAnyImage => hasImage || hasMultipleImages;
  bool get hasDescription => description != null && description!.isNotEmpty;
  bool get hasCategory => categoryId != null;

  String get stockStatus {
    if (!isActive) return 'غير متاح';
    if (!inStock) return 'نفدت الكمية';
    if (stockQuantity > 10) return 'متوفر';
    if (stockQuantity > 0) return 'كمية محدودة';
    return 'نفدت الكمية';
  }

  String get priceFormatted =>
      Helpers.formatCurrency(price, currencyCode: 'EGP');

  // Advanced pricing getters
  bool get hasAdvancedPricing =>
      (quantityBasedPrices?.isNotEmpty ?? false) ||
      (seasonalOffers?.isNotEmpty ?? false) ||
      (vipPrices?.isNotEmpty ?? false) ||
      (promotionalDiscounts?.isNotEmpty ?? false);

  bool get hasActiveSeasonalOffers =>
      seasonalOffers?.any((offer) => offer.isCurrentlyActive) ?? false;

  bool get hasActivePromotionalDiscounts =>
      promotionalDiscounts?.any((discount) => discount.isCurrentlyActive) ??
      false;

  double? get currentSeasonalPrice {
    if (!hasActiveSeasonalOffers) return null;
    final activeOffers = seasonalOffers!.where(
      (offer) => offer.isCurrentlyActive,
    );
    if (activeOffers.isEmpty) return null;

    // Return the best (lowest) price from active offers
    return activeOffers
        .map(
          (offer) =>
              offer.offerPrice ??
              (price -
                  (offer.fixedDiscount ??
                      (price * (offer.discountPercentage ?? 0) / 100))),
        )
        .reduce((a, b) => a < b ? a : b);
  }

  double? get currentPromotionalPrice {
    if (!hasActivePromotionalDiscounts) return null;
    final activeDiscounts = promotionalDiscounts!.where(
      (discount) => discount.isCurrentlyActive,
    );
    if (activeDiscounts.isEmpty) return null;

    // Return the best (lowest) price from active discounts
    return activeDiscounts
        .map((discount) {
          final discountAmount =
              discount.fixedDiscount ??
              (price * (discount.discountPercentage ?? 0) / 100);
          final maxDiscount = discount.maxDiscountAmount;
          final actualDiscount =
              maxDiscount != null && discountAmount > maxDiscount
              ? maxDiscount
              : discountAmount;
          return price - actualDiscount;
        })
        .reduce((a, b) => a < b ? a : b);
  }

  double get bestAvailablePrice {
    final prices = [price];
    if (currentSeasonalPrice != null) prices.add(currentSeasonalPrice!);
    if (currentPromotionalPrice != null) prices.add(currentPromotionalPrice!);
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double? getQuantityBasedPrice(int quantity) {
    if (quantityBasedPrices == null || quantityBasedPrices!.isEmpty) {
      return null;
    }

    // Find the best price for the given quantity
    final applicablePrices = quantityBasedPrices!
        .where(
          (pricing) =>
              pricing.isActive &&
              quantity >= pricing.minQuantity &&
              (pricing.maxQuantity == null || quantity <= pricing.maxQuantity!),
        )
        .toList();

    if (applicablePrices.isEmpty) return null;

    // Return the lowest price
    return applicablePrices
        .map((pricing) => pricing.price)
        .reduce((a, b) => a < b ? a : b);
  }

  double? getVIPPrice(String customerGroupId) {
    if (vipPrices == null || vipPrices!.isEmpty) return null;

    final vipPrice = vipPrices!.firstWhere(
      (price) => price.isActive && price.customerGroupId == customerGroupId,
      orElse: () => VIPPrice(
        id: '',
        customerGroupId: '',
        customerGroupName: '',
        price: 0,
        createdAt: DateTime.now(),
      ),
    );

    return vipPrice.id.isNotEmpty ? vipPrice.price : null;
  }

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
