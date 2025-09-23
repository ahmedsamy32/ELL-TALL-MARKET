// dynamic_ui_service_full.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================= ApiClient جاهز =================
class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'https://api.example.com'});

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.get(url);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.delete(url);
  }
}

// =================== موديلات UI ===================
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
    if (colorHex is String) return _parseColor(colorHex, defaultValue);
    return defaultValue;
  }

  double getSpacing(String key, [double defaultValue = 8.0]) {
    final spacingValue = spacing[key];
    if (spacingValue is num) return spacingValue.toDouble();
    return defaultValue;
  }

  double getBorderRadius(String key, [double defaultValue = 8.0]) {
    final value = borderRadius[key];
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  Color _parseColor(String hexColor, Color defaultColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) hexColor = 'FF$hexColor';
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

// ================= DynamicUIService كامل =================
class DynamicUIService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getLocalUIConfig() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/config/ui_config.json');
      final Map<String, dynamic> config = json.decode(jsonString);
      return config;
    } catch (e) {
      print('Error loading local UI config: $e');
      return _getDefaultUIConfig();
    }
  }

  Future<Map<String, dynamic>> getRemoteUIConfig() async {
    try {
      final response = await _apiClient.get('/ui/config');
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load UI config: ${response.statusCode}');
    } catch (e) {
      print('Error loading remote UI config: $e');
      return await getLocalUIConfig();
    }
  }

  Future<void> saveUIConfig(Map<String, dynamic> config) async {
    try {
      final response = await _apiClient.post('/ui/config', config);
      if (response.statusCode != 200) throw Exception('Failed to save UI config: ${response.statusCode}');
    } catch (e) {
      print('Error saving UI config: $e');
      throw Exception('فشل حفظ إعدادات الواجهة');
    }
  }


  Map<String, dynamic> _getDefaultUIConfig() {
    return {
      'theme': 'light',
      'primaryColor': '#2A6DE5',
      'secondaryColor': '#FF6E40',
      'fontFamily': 'Cairo',
      'fontSize': 'medium',
      'language': 'ar',
      'layout': 'grid',
    };
  }
}
