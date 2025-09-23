import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  static const String LANGUAGE_CODE = 'languageCode';

  Locale get locale => _locale ?? const Locale('ar', 'SA');

  LocaleProvider() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(LANGUAGE_CODE);
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  void setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_CODE, languageCode);
    _locale = Locale(languageCode);
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
