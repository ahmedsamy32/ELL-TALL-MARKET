import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  static const String languageCode = 'languageCode';

  Locale get locale => _locale ?? const Locale('ar', 'SA');

  LocaleProvider() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(languageCode);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  void setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(languageCode, code);
    _locale = Locale(code);
    notifyListeners();
  }

  void toggleLocale() {
    if (_locale?.languageCode == 'ar') {
      setLocale('en');
    } else {
      setLocale('ar');
    }
  }
}
