import 'package:flutter/material.dart';

class DynamicUIProvider extends ChangeNotifier {
  // القائمة الافتراضية للواجهات الديناميكية
  final List<Map<String, dynamic>> _uiComponents = [];

  List<Map<String, dynamic>> get uiComponents => _uiComponents;

  // إضافة مكون واجهة جديد
  void addUIComponent(Map<String, dynamic> component) {
    _uiComponents.add(component);
    notifyListeners();
  }

  // حذف مكون واجهة
  void removeUIComponent(int index) {
    if (index >= 0 && index < _uiComponents.length) {
      _uiComponents.removeAt(index);
      notifyListeners();
    }
  }

  // تحديث مكون واجهة
  void updateUIComponent(int index, Map<String, dynamic> component) {
    if (index >= 0 && index < _uiComponents.length) {
      _uiComponents[index] = component;
      notifyListeners();
    }
  }

  // إعادة ترتيب المكونات
  void reorderComponents(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final component = _uiComponents.removeAt(oldIndex);
    _uiComponents.insert(newIndex, component);
    notifyListeners();
  }

  // مسح جميع المكونات
  void clearComponents() {
    _uiComponents.clear();
    notifyListeners();
  }

  // طرق إضافية مطلوبة للتوافق
  bool _isLoading = false;
  Map<String, dynamic> _uiConfig = {};

  bool get isLoading => _isLoading;
  Map<String, dynamic> get uiConfig => _uiConfig;

  Future<void> loadUIConfig() async {
    _isLoading = true;
    notifyListeners();

    // محاكاة تحميل البيانات
    await Future.delayed(const Duration(seconds: 1));

    _isLoading = false;
    notifyListeners();
  }

  dynamic getConfigValue(String key) {
    return _uiConfig[key];
  }

  void updateConfigValue(String key, dynamic value) {
    _uiConfig[key] = value;
    notifyListeners();
  }

  void updateUIConfig(Map<String, dynamic> config) {
    _uiConfig = config;
    notifyListeners();
  }

  void resetToDefault() {
    _uiConfig.clear();
    _uiComponents.clear();
    notifyListeners();
  }
}
