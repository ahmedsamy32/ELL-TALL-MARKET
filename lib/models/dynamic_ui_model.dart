import 'package:flutter/material.dart';

// نموذج لتكوين عنصر واجهة المستخدم الديناميكي
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
    return {
      'type': type,
      'data': data,
      'styles': styles,
      'actions': actions,
    };
  }
}

// نموذج لتخطيط الصفحة
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
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
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

// نموذج لقالب واجهة المستخدم
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
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
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

// نموذج لإعدادات التخصيص
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

// ثوابت لأنواع عناصر واجهة المستخدم
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

// ثوابت لأنواع الأحداث
class UIEventTypes {
  static const String navigation = 'navigation';
  static const String apiCall = 'api_call';
  static const String showDialog = 'show_dialog';
  static const String showSnackbar = 'show_snackbar';
  static const String updateState = 'update_state';
  static const String custom = 'custom';
}
