import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ell_tall_market/models/settings_model.dart';
import 'package:ell_tall_market/models/merchant_settings.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';
  static const String _merchantSettingsKey = 'merchant_settings';

  Future<AppSettings> getAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson);
        return AppSettings.fromJson(settingsMap);
      } else {
        return AppSettings.defaults();
      }
    } catch (e) {
      throw Exception('فشل تحميل الإعدادات: ${e.toString()}');
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      throw Exception('فشل حفظ الإعدادات: ${e.toString()}');
    }
  }

  Future<MerchantSettings> getMerchantSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_merchantSettingsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson);
        return MerchantSettings.fromJson(settingsMap);
      } else {
        return MerchantSettings(
          isActive: true,
          minOrderAmount: 0.0,
          deliveryFee: 15.0,
          maxDeliveryDistance: 10.0,
          workingHours: {
            'sunday': ['09:00', '21:00'],
            'monday': ['09:00', '21:00'],
            'tuesday': ['09:00', '21:00'],
            'wednesday': ['09:00', '21:00'],
            'thursday': ['09:00', '21:00'],
            'friday': ['16:00', '21:00'],
            'saturday': ['09:00', '21:00'],
          },
          acceptsReturns: true,
          returnsWindowDays: 14,
        ); // الإعدادات الافتراضية
      }
    } catch (e) {
      throw Exception('فشل تحميل إعدادات التاجر: ${e.toString()}');
    }
  }

  Future<void> saveMerchantSettings(MerchantSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_merchantSettingsKey, settingsJson);
    } catch (e) {
      throw Exception('فشل حفظ إعدادات التاجر: ${e.toString()}');
    }
  }

  Future<void> resetAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      throw Exception('فشل إعادة تعيين الإعدادات: ${e.toString()}');
    }
  }

  Future<void> resetMerchantSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_merchantSettingsKey);
    } catch (e) {
      throw Exception('فشل إعادة تعيين إعدادات التاجر: ${e.toString()}');
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    try {
      final settings = await getAppSettings();
      final updatedSettings = _updateSettingsValue(settings, key, value);
      await saveAppSettings(updatedSettings);
    } catch (e) {
      throw Exception('فشل تحديث الإعداد: ${e.toString()}');
    }
  }

  AppSettings _updateSettingsValue(AppSettings settings, String key, dynamic value) {
    switch (key) {
      case 'notificationsEnabled':
        return settings.copyWith(notificationsEnabled: value as bool);
      case 'emailNotifications':
        return settings.copyWith(emailNotifications: value as bool);
      case 'smsNotifications':
        return settings.copyWith(smsNotifications: value as bool);
      case 'darkMode':
        return settings.copyWith(darkMode: value as bool);
      case 'language':
        return settings.copyWith(language: value as String);
      case 'currency':
        return settings.copyWith(currency: value as String);
      case 'biometricAuth':
        return settings.copyWith(biometricAuth: value as bool);
      case 'savePaymentMethods':
        return settings.copyWith(savePaymentMethods: value as bool);
      case 'autoUpdate':
        return settings.copyWith(autoUpdate: value as bool);
      case 'dataSaver':
        return settings.copyWith(dataSaver: value as bool);
      case 'cacheDuration':
        return settings.copyWith(cacheDuration: value as int);
      case 'analyticsEnabled':
        return settings.copyWith(analyticsEnabled: value as bool);
      case 'crashReports':
        return settings.copyWith(crashReports: value as bool);
      default:
        return settings;
    }
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final appSettings = await getAppSettings();
      final merchantSettings = await getMerchantSettings();

      return {
        'app': appSettings.toJson(),
        'merchant': merchantSettings.toJson(),
      };
    } catch (e) {
      throw Exception('فشل تحميل جميع الإعدادات: ${e.toString()}');
    }
  }
}
