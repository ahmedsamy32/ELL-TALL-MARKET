import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DynamicUIProvider with ChangeNotifier {
  final Map<String, dynamic> _uiConfig = {};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get uiConfig => _uiConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUIConfig() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('ui_config');

      if (configJson != null) {
        _uiConfig.clear();
        _uiConfig.addAll(Map<String, dynamic>.from(json.decode(configJson)));
      } else {
        // استخدام الإعدادات الافتراضية
        _setDefaultConfig();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setDefaultConfig() {
    _uiConfig.clear();
    _uiConfig.addAll({
      'theme': 'light',
      'primaryColor': '#2A6DE5',
      'secondaryColor': '#FF6E40',
      'fontFamily': 'Cairo',
      'fontSize': 'medium',
      'language': 'ar',
      'layout': 'grid',
      'showBanners': true,
      'showCategories': true,
      'showFeaturedProducts': true,
      'showReviews': true,
      'animationEnabled': true,
      'transitionSpeed': 'normal',
    });
  }

  Future<void> updateUIConfig(Map<String, dynamic> newConfig) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = json.encode(newConfig);
      await prefs.setString('ui_config', configJson);

      _uiConfig.clear();
      _uiConfig.addAll(newConfig);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateConfigValue(String key, dynamic value) async {
    try {
      final newConfig = Map<String, dynamic>.from(_uiConfig);
      newConfig[key] = value;
      await updateUIConfig(newConfig);
    } catch (e) {
      throw Exception('فشل تحديث إعداد الواجهة: ${e.toString()}');
    }
  }

  dynamic getConfigValue(String key, {dynamic defaultValue}) {
    return _uiConfig[key] ?? defaultValue;
  }

  Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ui_config');
      _setDefaultConfig();
      notifyListeners();
    } catch (e) {
      throw Exception('فشل إعادة تعيين إعدادات الواجهة: ${e.toString()}');
    }
  }

  String getPrimaryColor() {
    return _uiConfig['primaryColor'] ?? '#2A6DE5';
  }

  String getTheme() {
    return _uiConfig['theme'] ?? 'light';
  }

  String getLayout() {
    return _uiConfig['layout'] ?? 'grid';
  }

  bool shouldShowBanners() {
    return _uiConfig['showBanners'] ?? true;
  }

  bool shouldShowCategories() {
    return _uiConfig['showCategories'] ?? true;
  }

  bool isAnimationEnabled() {
    return _uiConfig['animationEnabled'] ?? true;
  }
}