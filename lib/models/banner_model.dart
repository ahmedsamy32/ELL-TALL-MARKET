/// Banner model that matches the Supabase banners table
/// Updated to match the new comprehensive banner system schema
library;

import 'package:intl/intl.dart';

/// Base mixin for common model functionality
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

/// Banner Type Enum
enum BannerType {
  store,
  product,
  category,
  promotion;

  static BannerType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'store':
        return BannerType.store;
      case 'product':
        return BannerType.product;
      case 'category':
        return BannerType.category;
      case 'promotion':
        return BannerType.promotion;
      default:
        return BannerType.promotion;
    }
  }

  String get value {
    switch (this) {
      case BannerType.store:
        return 'store';
      case BannerType.product:
        return 'product';
      case BannerType.category:
        return 'category';
      case BannerType.promotion:
        return 'promotion';
    }
  }

  String get displayName {
    switch (this) {
      case BannerType.store:
        return 'متجر';
      case BannerType.product:
        return 'منتج';
      case BannerType.category:
        return 'فئة';
      case BannerType.promotion:
        return 'عرض ترويجي';
    }
  }
}

/// Banner Position Enum for backward compatibility
enum BannerPosition {
  top,
  middle,
  bottom,
  sidebar;

  static BannerPosition fromString(String position) {
    switch (position.toLowerCase()) {
      case 'top':
        return BannerPosition.top;
      case 'middle':
        return BannerPosition.middle;
      case 'bottom':
        return BannerPosition.bottom;
      case 'sidebar':
        return BannerPosition.sidebar;
      default:
        return BannerPosition.top;
    }
  }

  String get value {
    switch (this) {
      case BannerPosition.top:
        return 'top';
      case BannerPosition.middle:
        return 'middle';
      case BannerPosition.bottom:
        return 'bottom';
      case BannerPosition.sidebar:
        return 'sidebar';
    }
  }
}

/// Banner model that matches the Supabase banners table
class BannerModel with BaseModelMixin {
  static const String tableName = 'banners';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String title; // TEXT NOT NULL
  final String? description; // TEXT
  final String imageUrl; // TEXT NOT NULL
  final BannerType? targetType; // banner_type_enum
  final String? targetId; // UUID
  final String? actionUrl; // TEXT
  final int displayOrder; // INT DEFAULT 0
  final bool isActive; // BOOLEAN DEFAULT TRUE
  final DateTime startDate; // TIMESTAMPTZ DEFAULT NOW()
  final DateTime? endDate; // TIMESTAMPTZ
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const BannerModel({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.targetType,
    this.targetId,
    this.actionUrl,
    required this.displayOrder,
    required this.isActive,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String,
      targetType: map['target_type'] != null
          ? BannerType.fromString(map['target_type'] as String)
          : null,
      targetId: map['target_id'] as String?,
      actionUrl: map['action_url'] as String?,
      displayOrder: (map['display_order'] as int?) ?? 0,
      isActive: (map['is_active'] as bool?) ?? true,
      startDate: BaseModelMixin.parseDateTime(map['start_date']),
      endDate: map['end_date'] != null
          ? BaseModelMixin.parseDateTime(map['end_date'])
          : null,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: null, // banners table doesn't have updated_at
    );
  }

  // Helper methods
  String get targetTypeDisplayName => targetType?.displayName ?? 'غير محدد';
  bool get hasDescription => description != null && description!.isNotEmpty;

  bool get isCurrentlyActive {
    if (!isActive) return false;

    final now = DateTime.now();
    final isAfterStart =
        now.isAfter(startDate) || now.isAtSameMomentAs(startDate);
    final isBeforeEnd = endDate == null || now.isBefore(endDate!);

    return isAfterStart && isBeforeEnd;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'target_type': targetType?.value,
      'target_id': targetId,
      'action_url': actionUrl,
      'display_order': displayOrder,
      'is_active': isActive,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  BannerModel copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    BannerType? targetType,
    String? targetId,
    String? actionUrl,
    int? displayOrder,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      actionUrl: actionUrl ?? this.actionUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BannerModel(id: $id, title: $title, targetType: ${targetType?.value})';
  }
}
