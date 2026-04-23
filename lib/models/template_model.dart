import 'package:flutter/foundation.dart';

/// Product Template Model
/// Allows merchants to save and reuse product specifications and attributes
class TemplateModel {
  final String id;
  final String storeId;
  final String templateName;
  final String? categoryId;
  final String? description;
  final Map<String, dynamic> customFields;
  final List<dynamic> variantGroups;
  final DateTime createdAt;
  final DateTime updatedAt;

  TemplateModel({
    required this.id,
    required this.storeId,
    required this.templateName,
    this.categoryId,
    this.description,
    Map<String, dynamic>? customFields,
    List<dynamic>? variantGroups,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : customFields = customFields ?? {},
       variantGroups = variantGroups ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create from database map
  factory TemplateModel.fromMap(Map<String, dynamic> map) {
    return TemplateModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      templateName: map['template_name'] as String,
      categoryId: map['category_id'] as String?,
      description: map['description'] as String?,
      customFields: (map['custom_fields'] as Map<String, dynamic>?) ?? {},
      variantGroups: (map['variant_groups'] as List<dynamic>?) ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'template_name': templateName,
      'category_id': categoryId,
      'description': description,
      'custom_fields': customFields,
      'variant_groups': variantGroups,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  TemplateModel copyWith({
    String? id,
    String? storeId,
    String? templateName,
    String? categoryId,
    String? description,
    Map<String, dynamic>? customFields,
    List<dynamic>? variantGroups,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      templateName: templateName ?? this.templateName,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      customFields: customFields ?? this.customFields,
      variantGroups: variantGroups ?? this.variantGroups,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TemplateModel &&
        other.id == id &&
        other.storeId == storeId &&
        other.templateName == templateName &&
        other.categoryId == categoryId &&
        other.description == description &&
        mapEquals(other.customFields, customFields) &&
        listEquals(other.variantGroups, variantGroups);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      storeId,
      templateName,
      categoryId,
      description,
      Object.hashAll(customFields.entries),
      Object.hashAll(variantGroups),
    );
  }

  @override
  String toString() {
    return 'TemplateModel(id: $id, templateName: $templateName, storeId: $storeId)';
  }
}
