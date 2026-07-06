import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/settings_model.dart';

class ClientSettingsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  AppSettingsModel _clientSettings = AppSettingsModel.empty();
  bool _isLoading = false;
  String? _error;

  AppSettingsModel get clientSettings => _clientSettings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _clientSettings = AppSettingsModel.empty();
        _setLoading(false);
        return;
      }

      // 1. جلب إعدادات المستخدم الخاصة من client_settings
      final userRows = await _supabase
          .from('client_settings')
          .select()
          .eq('client_id', userId)
          .limit(1);

      // 2. جلب الإعدادات العامة للتطبيق من app_settings
      final globalRows = await _supabase
          .from('app_settings')
          .select()
          .limit(1);

      final Map<String, dynamic> mergedMap = {};

      if (userRows.isEmpty) {
        final defaultUserMap = {
          'client_id': userId,
          'notifications_enabled': true,
          'email_notifications': true,
          'sms_notifications': false,
          'dark_mode': false,
          'language': 'ar',
          'currency': 'EGP',
          'biometric_auth': false,
          'save_payment_methods': true,
          'auto_update': true,
          'data_saver': false,
          'cache_duration': 7,
          'analytics_enabled': true,
          'crash_reports': true,
        };
        try {
          await _supabase.from('client_settings').insert(defaultUserMap);
          mergedMap.addAll(defaultUserMap);
        } catch (e) {
          AppLogger.warning('⚠️ Could not save default client settings', e);
        }
      } else {
        mergedMap.addAll(Map<String, dynamic>.from(userRows.first));
      }

      if (globalRows.isNotEmpty) {
        mergedMap.addAll(Map<String, dynamic>.from(globalRows.first));
      }

      _clientSettings = AppSettingsModel.fromMap(mergedMap);
      _setError(null);
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error loading client settings', e);
      _setError(e.toString());
      _clientSettings = AppSettingsModel.empty();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSettings(AppSettingsModel settings) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('لا يمكن حفظ الإعدادات بدون تسجيل دخول');
      }

      final previousSettings = _clientSettings;
      _clientSettings = settings;
      notifyListeners();

      final userSettingsMap = {
        'notifications_enabled': settings.notificationsEnabled,
        'email_notifications': settings.emailNotifications,
        'sms_notifications': settings.smsNotifications,
        'dark_mode': settings.darkMode,
        'language': settings.language.code,
        'currency': settings.currency.code,
        'biometric_auth': settings.biometricAuth,
        'save_payment_methods': settings.savePaymentMethods,
        'auto_update': settings.autoUpdate,
        'data_saver': settings.dataSaver,
        'cache_duration': settings.cacheDuration,
        'analytics_enabled': settings.analyticsEnabled,
        'crash_reports': settings.crashReports,
      };

      try {
        await _supabase.from('client_settings').upsert({
          ...userSettingsMap,
          'client_id': userId,
        }, onConflict: 'client_id');

        _setError(null);
      } catch (e) {
        _clientSettings = previousSettings;
        notifyListeners();
        rethrow;
      }
    } catch (e) {
      AppLogger.error('❌ Error updating client settings', e);
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> resetSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final defaultSettings = AppSettingsModel.defaults(userId);
      await updateSettings(defaultSettings);
    } catch (e) {
      AppLogger.error('❌ Error resetting client settings', e);
      _setError(e.toString());
      rethrow;
    }
  }
}
