/// Dynamic UI models that match the Supabase ui_components and ui_templates tables
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:flutter/material.dart';
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

/// UI component type enum
enum UIComponentType {
  banner, // بانر
  grid, // شبكة
  list, // قائمة
  slider, // شريط متحرك
  tabs, // تبويبات
  form, // نموذج
  text, // نص
  image, // صورة
  button, // زر
  card, // بطاقة
  divider, // فاصل
  spacer, // مساحة فارغة
  carousel, // دوار
  search, // بحث
  filter, // تصفية
  map, // خريطة
  video, // فيديو
}

/// Extension for UIComponentType enum
extension UIComponentTypeExtension on UIComponentType {
  String get displayName {
    switch (this) {
      case UIComponentType.banner:
        return 'بانر';
      case UIComponentType.grid:
        return 'شبكة';
      case UIComponentType.list:
        return 'قائمة';
      case UIComponentType.slider:
        return 'شريط متحرك';
      case UIComponentType.tabs:
        return 'تبويبات';
      case UIComponentType.form:
        return 'نموذج';
      case UIComponentType.text:
        return 'نص';
      case UIComponentType.image:
        return 'صورة';
      case UIComponentType.button:
        return 'زر';
      case UIComponentType.card:
        return 'بطاقة';
      case UIComponentType.divider:
        return 'فاصل';
      case UIComponentType.spacer:
        return 'مساحة فارغة';
      case UIComponentType.carousel:
        return 'دوار';
      case UIComponentType.search:
        return 'بحث';
      case UIComponentType.filter:
        return 'تصفية';
      case UIComponentType.map:
        return 'خريطة';
      case UIComponentType.video:
        return 'فيديو';
    }
  }

  String get code {
    switch (this) {
      case UIComponentType.banner:
        return 'banner';
      case UIComponentType.grid:
        return 'grid';
      case UIComponentType.list:
        return 'list';
      case UIComponentType.slider:
        return 'slider';
      case UIComponentType.tabs:
        return 'tabs';
      case UIComponentType.form:
        return 'form';
      case UIComponentType.text:
        return 'text';
      case UIComponentType.image:
        return 'image';
      case UIComponentType.button:
        return 'button';
      case UIComponentType.card:
        return 'card';
      case UIComponentType.divider:
        return 'divider';
      case UIComponentType.spacer:
        return 'spacer';
      case UIComponentType.carousel:
        return 'carousel';
      case UIComponentType.search:
        return 'search';
      case UIComponentType.filter:
        return 'filter';
      case UIComponentType.map:
        return 'map';
      case UIComponentType.video:
        return 'video';
    }
  }

  static UIComponentType fromCode(String code) {
    switch (code) {
      case 'banner':
        return UIComponentType.banner;
      case 'grid':
        return UIComponentType.grid;
      case 'list':
        return UIComponentType.list;
      case 'slider':
        return UIComponentType.slider;
      case 'tabs':
        return UIComponentType.tabs;
      case 'form':
        return UIComponentType.form;
      case 'text':
        return UIComponentType.text;
      case 'image':
        return UIComponentType.image;
      case 'button':
        return UIComponentType.button;
      case 'card':
        return UIComponentType.card;
      case 'divider':
        return UIComponentType.divider;
      case 'spacer':
        return UIComponentType.spacer;
      case 'carousel':
        return UIComponentType.carousel;
      case 'search':
        return UIComponentType.search;
      case 'filter':
        return UIComponentType.filter;
      case 'map':
        return UIComponentType.map;
      case 'video':
        return UIComponentType.video;
      default:
        return UIComponentType.text;
    }
  }
}

/// UI event type enum
enum UIEventType {
  navigation, // التنقل
  apiCall, // استدعاء API
  showDialog, // عرض حوار
  showSnackbar, // عرض إشعار
  updateState, // تحديث الحالة
  openUrl, // فتح رابط
  shareContent, // مشاركة المحتوى
  callPhone, // اتصال هاتفي
  sendEmail, // إرسال بريد
  custom, // مخصص
}

/// Extension for UIEventType enum
extension UIEventTypeExtension on UIEventType {
  String get displayName {
    switch (this) {
      case UIEventType.navigation:
        return 'التنقل';
      case UIEventType.apiCall:
        return 'استدعاء API';
      case UIEventType.showDialog:
        return 'عرض حوار';
      case UIEventType.showSnackbar:
        return 'عرض إشعار';
      case UIEventType.updateState:
        return 'تحديث الحالة';
      case UIEventType.openUrl:
        return 'فتح رابط';
      case UIEventType.shareContent:
        return 'مشاركة المحتوى';
      case UIEventType.callPhone:
        return 'اتصال هاتفي';
      case UIEventType.sendEmail:
        return 'إرسال بريد';
      case UIEventType.custom:
        return 'مخصص';
    }
  }

  String get code {
    switch (this) {
      case UIEventType.navigation:
        return 'navigation';
      case UIEventType.apiCall:
        return 'api_call';
      case UIEventType.showDialog:
        return 'show_dialog';
      case UIEventType.showSnackbar:
        return 'show_snackbar';
      case UIEventType.updateState:
        return 'update_state';
      case UIEventType.openUrl:
        return 'open_url';
      case UIEventType.shareContent:
        return 'share_content';
      case UIEventType.callPhone:
        return 'call_phone';
      case UIEventType.sendEmail:
        return 'send_email';
      case UIEventType.custom:
        return 'custom';
    }
  }

  static UIEventType fromCode(String code) {
    switch (code) {
      case 'navigation':
        return UIEventType.navigation;
      case 'api_call':
        return UIEventType.apiCall;
      case 'show_dialog':
        return UIEventType.showDialog;
      case 'show_snackbar':
        return UIEventType.showSnackbar;
      case 'update_state':
        return UIEventType.updateState;
      case 'open_url':
        return UIEventType.openUrl;
      case 'share_content':
        return UIEventType.shareContent;
      case 'call_phone':
        return UIEventType.callPhone;
      case 'send_email':
        return UIEventType.sendEmail;
      case 'custom':
        return UIEventType.custom;
      default:
        return UIEventType.custom;
    }
  }
}

/// UI component model that matches the Supabase ui_components table
class UIComponentModel with BaseModelMixin {
  static const String tableName = 'ui_components';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String?
  templateId; // UUID REFERENCES ui_templates(id) ON DELETE CASCADE
  final String name; // TEXT NOT NULL
  final UIComponentType type; // TEXT NOT NULL
  final Map<String, dynamic> data; // JSONB DEFAULT '{}'
  final Map<String, dynamic> styles; // JSONB DEFAULT '{}'
  final Map<String, dynamic> actions; // JSONB DEFAULT '{}'
  final int position; // INT DEFAULT 0
  final bool isVisible; // BOOLEAN DEFAULT TRUE
  final bool isEnabled; // BOOLEAN DEFAULT TRUE
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const UIComponentModel({
    required this.id,
    this.templateId,
    required this.name,
    required this.type,
    this.data = const {},
    this.styles = const {},
    this.actions = const {},
    this.position = 0,
    this.isVisible = true,
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory UIComponentModel.fromMap(Map<String, dynamic> map) {
    return UIComponentModel(
      id: map['id'] as String,
      templateId: map['template_id'] as String?,
      name: map['name'] as String,
      type: UIComponentTypeExtension.fromCode(map['type'] as String? ?? 'text'),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      styles: Map<String, dynamic>.from(map['styles'] ?? {}),
      actions: Map<String, dynamic>.from(map['actions'] ?? {}),
      position: map['position'] as int? ?? 0,
      isVisible: map['is_visible'] as bool? ?? true,
      isEnabled: map['is_enabled'] as bool? ?? true,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory UIComponentModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return UIComponentModel.fromMap(data);
  }

  factory UIComponentModel.empty() {
    return UIComponentModel(
      id: '',
      name: '',
      type: UIComponentType.text,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'name': name,
      'type': type.code,
      'data': data,
      'styles': styles,
      'actions': actions,
      'position': position,
      'is_visible': isVisible,
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'template_id': templateId,
      'name': name,
      'type': type.code,
      'data': data,
      'styles': styles,
      'actions': actions,
      'position': position,
      'is_visible': isVisible,
      'is_enabled': isEnabled,
    };
  }

  UIComponentModel copyWith({
    String? id,
    String? templateId,
    String? name,
    UIComponentType? type,
    Map<String, dynamic>? data,
    Map<String, dynamic>? styles,
    Map<String, dynamic>? actions,
    int? position,
    bool? isVisible,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UIComponentModel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      type: type ?? this.type,
      data: data ?? this.data,
      styles: styles ?? this.styles,
      actions: actions ?? this.actions,
      position: position ?? this.position,
      isVisible: isVisible ?? this.isVisible,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get data value by key
  T? getDataValue<T>(String key) {
    return data[key] as T?;
  }

  /// Get style value by key
  T? getStyleValue<T>(String key) {
    return styles[key] as T?;
  }

  /// Get action value by key
  T? getActionValue<T>(String key) {
    return actions[key] as T?;
  }

  /// Update component data
  UIComponentModel updateData(Map<String, dynamic> newData) {
    return copyWith(data: {...data, ...newData}, updatedAt: DateTime.now());
  }

  /// Update component styles
  UIComponentModel updateStyles(Map<String, dynamic> newStyles) {
    return copyWith(
      styles: {...styles, ...newStyles},
      updatedAt: DateTime.now(),
    );
  }

  /// Update component actions
  UIComponentModel updateActions(Map<String, dynamic> newActions) {
    return copyWith(
      actions: {...actions, ...newActions},
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UIComponentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UIComponentModel(id: $id, name: $name, type: ${type.code})';
  }
}

/// UI template model that matches the Supabase ui_templates table
class UITemplateModel with BaseModelMixin {
  static const String tableName = 'ui_templates';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String name; // TEXT NOT NULL
  final String description; // TEXT
  final String? categoryId; // UUID REFERENCES ui_categories(id)
  final List<UIComponentModel> components; // Relationship
  final Map<String, dynamic> styles; // JSONB DEFAULT '{}'
  final Map<String, dynamic> settings; // JSONB DEFAULT '{}'
  final bool isActive; // BOOLEAN DEFAULT TRUE
  final bool isPublic; // BOOLEAN DEFAULT FALSE
  final String? createdBy; // UUID REFERENCES profiles(id)
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const UITemplateModel({
    required this.id,
    required this.name,
    this.description = '',
    this.categoryId,
    this.components = const [],
    this.styles = const {},
    this.settings = const {},
    this.isActive = true,
    this.isPublic = false,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory UITemplateModel.fromMap(Map<String, dynamic> map) {
    return UITemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      categoryId: map['category_id'] as String?,
      components: map['components'] != null
          ? List<UIComponentModel>.from(
              (map['components'] as List).map(
                (x) => UIComponentModel.fromMap(x),
              ),
            )
          : [],
      styles: Map<String, dynamic>.from(map['styles'] ?? {}),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      isActive: map['is_active'] as bool? ?? true,
      isPublic: map['is_public'] as bool? ?? false,
      createdBy: map['created_by'] as String?,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory UITemplateModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return UITemplateModel.fromMap(data);
  }

  factory UITemplateModel.empty() {
    return UITemplateModel(id: '', name: '', createdAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'components': components.map((x) => x.toJson()).toList(),
      'styles': styles,
      'settings': settings,
      'is_active': isActive,
      'is_public': isPublic,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'name': name,
      'description': description,
      'category_id': categoryId,
      'styles': styles,
      'settings': settings,
      'is_active': isActive,
      'is_public': isPublic,
      'created_by': createdBy,
    };
  }

  UITemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    List<UIComponentModel>? components,
    Map<String, dynamic>? styles,
    Map<String, dynamic>? settings,
    bool? isActive,
    bool? isPublic,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UITemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      components: components ?? this.components,
      styles: styles ?? this.styles,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      isPublic: isPublic ?? this.isPublic,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add component to template
  UITemplateModel addComponent(UIComponentModel component) {
    final newComponents = [...components, component];
    return copyWith(components: newComponents, updatedAt: DateTime.now());
  }

  /// Remove component from template
  UITemplateModel removeComponent(String componentId) {
    final newComponents = components.where((c) => c.id != componentId).toList();
    return copyWith(components: newComponents, updatedAt: DateTime.now());
  }

  /// Update component in template
  UITemplateModel updateComponent(UIComponentModel component) {
    final newComponents = components
        .map((c) => c.id == component.id ? component : c)
        .toList();
    return copyWith(components: newComponents, updatedAt: DateTime.now());
  }

  /// Get components by type
  List<UIComponentModel> getComponentsByType(UIComponentType type) {
    return components.where((c) => c.type == type).toList();
  }

  /// Get sorted components by position
  List<UIComponentModel> get sortedComponents {
    final sortedList = [...components];
    sortedList.sort((a, b) => a.position.compareTo(b.position));
    return sortedList;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UITemplateModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UITemplateModel(id: $id, name: $name, components: ${components.length})';
  }
}

/// UI customization model for theme and styling
class UICustomizationModel with BaseModelMixin {
  static const String tableName = 'ui_customizations';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String? userId; // UUID REFERENCES profiles(id)
  final String? storeId; // UUID REFERENCES stores(id)
  final String theme; // TEXT DEFAULT 'light'
  final Map<String, dynamic> colors; // JSONB DEFAULT '{}'
  final Map<String, dynamic> typography; // JSONB DEFAULT '{}'
  final Map<String, dynamic> spacing; // JSONB DEFAULT '{}'
  final Map<String, dynamic> borderRadius; // JSONB DEFAULT '{}'
  final Map<String, dynamic> animations; // JSONB DEFAULT '{}'
  final Map<String, dynamic> customStyles; // JSONB DEFAULT '{}'
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const UICustomizationModel({
    required this.id,
    this.userId,
    this.storeId,
    this.theme = 'light',
    this.colors = const {},
    this.typography = const {},
    this.spacing = const {},
    this.borderRadius = const {},
    this.animations = const {},
    this.customStyles = const {},
    required this.createdAt,
    this.updatedAt,
  });

  factory UICustomizationModel.fromMap(Map<String, dynamic> map) {
    return UICustomizationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      storeId: map['store_id'] as String?,
      theme: map['theme'] as String? ?? 'light',
      colors: Map<String, dynamic>.from(map['colors'] ?? {}),
      typography: Map<String, dynamic>.from(map['typography'] ?? {}),
      spacing: Map<String, dynamic>.from(map['spacing'] ?? {}),
      borderRadius: Map<String, dynamic>.from(map['border_radius'] ?? {}),
      animations: Map<String, dynamic>.from(map['animations'] ?? {}),
      customStyles: Map<String, dynamic>.from(map['custom_styles'] ?? {}),
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory UICustomizationModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return UICustomizationModel.fromMap(data);
  }

  factory UICustomizationModel.empty() {
    return UICustomizationModel(id: '', createdAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'store_id': storeId,
      'theme': theme,
      'colors': colors,
      'typography': typography,
      'spacing': spacing,
      'border_radius': borderRadius,
      'animations': animations,
      'custom_styles': customStyles,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'user_id': userId,
      'store_id': storeId,
      'theme': theme,
      'colors': colors,
      'typography': typography,
      'spacing': spacing,
      'border_radius': borderRadius,
      'animations': animations,
      'custom_styles': customStyles,
    };
  }

  UICustomizationModel copyWith({
    String? id,
    String? userId,
    String? storeId,
    String? theme,
    Map<String, dynamic>? colors,
    Map<String, dynamic>? typography,
    Map<String, dynamic>? spacing,
    Map<String, dynamic>? borderRadius,
    Map<String, dynamic>? animations,
    Map<String, dynamic>? customStyles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UICustomizationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      theme: theme ?? this.theme,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      borderRadius: borderRadius ?? this.borderRadius,
      animations: animations ?? this.animations,
      customStyles: customStyles ?? this.customStyles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get color by key
  Color getColor(String key, [Color defaultValue = Colors.black]) {
    final colorValue = colors[key];
    if (colorValue is String) {
      return _parseColor(colorValue, defaultValue);
    } else if (colorValue is int) {
      return Color(colorValue);
    }
    return defaultValue;
  }

  /// Get spacing value by key
  double getSpacing(String key, [double defaultValue = 8.0]) {
    final spacingValue = spacing[key];
    if (spacingValue is num) {
      return spacingValue.toDouble();
    }
    return defaultValue;
  }

  /// Get border radius value by key
  double getBorderRadius(String key, [double defaultValue = 8.0]) {
    final borderRadiusValue = borderRadius[key];
    if (borderRadiusValue is num) {
      return borderRadiusValue.toDouble();
    }
    return defaultValue;
  }

  /// Get typography value by key
  T? getTypography<T>(String key) {
    return typography[key] as T?;
  }

  /// Get animation value by key
  T? getAnimation<T>(String key) {
    return animations[key] as T?;
  }

  /// Check if dark theme is enabled
  bool get isDarkTheme => theme == 'dark';

  /// Parse color from string
  Color _parseColor(String colorString, Color defaultColor) {
    try {
      String hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return defaultColor;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UICustomizationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UICustomizationModel(id: $id, theme: $theme)';
  }
}

/// Legacy classes for backward compatibility
@Deprecated('Use UIComponentModel instead')
class UIComponent {
  final String type;
  final Map<String, dynamic> data;
  final Map<String, dynamic> styles;
  final Map<String, dynamic> actions;

  UIComponent({
    required this.type,
    required this.data,
    this.styles = const {},
    this.actions = const {},
  });

  factory UIComponent.fromMap(Map<String, dynamic> map) {
    return UIComponent(
      type: map['type'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      styles: Map<String, dynamic>.from(map['styles'] ?? {}),
      actions: Map<String, dynamic>.from(map['actions'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'data': data, 'styles': styles, 'actions': actions};
  }
}

@Deprecated('Use UITemplateModel instead')
class UILayout {
  final String id;
  final String name;
  final List<UIComponent> components;
  final Map<String, dynamic> styles;
  final DateTime createdAt;
  final DateTime updatedAt;

  UILayout({
    required this.id,
    required this.name,
    required this.components,
    this.styles = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UILayout.fromMap(Map<String, dynamic> map) {
    return UILayout(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      components: List<UIComponent>.from(
        (map['components'] ?? []).map((x) => UIComponent.fromMap(x)),
      ),
      styles: Map<String, dynamic>.from(map['styles'] ?? {}),
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'components': components.map((x) => x.toMap()).toList(),
      'styles': styles,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

@Deprecated('Use UITemplateModel instead')
class UITemplate {
  final String id;
  final String name;
  final String description;
  final List<UILayout> layouts;
  final Map<String, dynamic> styles;
  final bool isActive;
  final DateTime createdAt;

  UITemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.layouts,
    this.styles = const {},
    this.isActive = true,
    required this.createdAt,
  });

  factory UITemplate.fromMap(Map<String, dynamic> map) {
    return UITemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      layouts: List<UILayout>.from(
        (map['layouts'] ?? []).map((x) => UILayout.fromMap(x)),
      ),
      styles: Map<String, dynamic>.from(map['styles'] ?? {}),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'layouts': layouts.map((x) => x.toMap()).toList(),
      'styles': styles,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

@Deprecated('Use UICustomizationModel instead')
class UICustomization {
  final String theme;
  final Map<String, dynamic> colors;
  final Map<String, dynamic> typography;
  final Map<String, dynamic> spacing;
  final Map<String, dynamic> borderRadius;
  final Map<String, dynamic> animations;

  UICustomization({
    this.theme = 'light',
    this.colors = const {},
    this.typography = const {},
    this.spacing = const {},
    this.borderRadius = const {},
    this.animations = const {},
  });

  factory UICustomization.fromMap(Map<String, dynamic> map) {
    return UICustomization(
      theme: map['theme'] ?? 'light',
      colors: Map<String, dynamic>.from(map['colors'] ?? {}),
      typography: Map<String, dynamic>.from(map['typography'] ?? {}),
      spacing: Map<String, dynamic>.from(map['spacing'] ?? {}),
      borderRadius: Map<String, dynamic>.from(map['borderRadius'] ?? {}),
      animations: Map<String, dynamic>.from(map['animations'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'colors': colors,
      'typography': typography,
      'spacing': spacing,
      'borderRadius': borderRadius,
      'animations': animations,
    };
  }

  Color getColor(String key, [Color defaultValue = Colors.black]) {
    final colorHex = colors[key];
    if (colorHex is String) {
      return _parseColor(colorHex, defaultValue);
    }
    return defaultValue;
  }

  double getSpacing(String key, [double defaultValue = 8.0]) {
    final spacingValue = spacing[key];
    if (spacingValue is num) {
      return spacingValue.toDouble();
    }
    return defaultValue;
  }

  double getBorderRadius(String key, [double defaultValue = 8.0]) {
    final borderRadiusValue = borderRadius[key];
    if (borderRadiusValue is num) {
      return borderRadiusValue.toDouble();
    }
    return defaultValue;
  }

  Color _parseColor(String hexColor, Color defaultColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return defaultColor;
    }
  }
}

/// Legacy constants for backward compatibility
@Deprecated('Use UIComponentType enum instead')
class UIComponentTypes {
  static const String banner = 'banner';
  static const String grid = 'grid';
  static const String list = 'list';
  static const String slider = 'slider';
  static const String tabs = 'tabs';
  static const String form = 'form';
  static const String text = 'text';
  static const String image = 'image';
  static const String button = 'button';
  static const String card = 'card';
  static const String divider = 'divider';
  static const String spacer = 'spacer';
}

@Deprecated('Use UIEventType enum instead')
class UIEventTypes {
  static const String navigation = 'navigation';
  static const String apiCall = 'api_call';
  static const String showDialog = 'show_dialog';
  static const String showSnackbar = 'show_snackbar';
  static const String updateState = 'update_state';
  static const String custom = 'custom';
}
