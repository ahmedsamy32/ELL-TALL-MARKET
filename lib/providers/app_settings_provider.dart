import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/settings_model.dart';

/// Admin/app-wide settings provider.
/// Loads user preferences from `client_settings` and global configurations from `app_settings`.
class AppSettingsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  AppSettingsModel _appSettings = AppSettingsModel.empty();
  bool _isLoading = false;
  String? _error;

  AppSettingsProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.userUpdated) {
        AppLogger.info('🔑 Auth event ($event) triggered settings load');
        loadSettings();
      } else if (event == AuthChangeEvent.signedOut) {
        AppLogger.info('🔑 Auth event ($event) reset settings to empty');
        _appSettings = AppSettingsModel.empty();
        notifyListeners();
      }
    });
  }

  AppSettingsModel get appSettings => _appSettings;
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

  // ===== جلب الإعدادات (دمج الإعدادات الخاصة بالمستخدم مع الإعدادات العامة للتطبيق) =====
  Future<void> loadSettings() async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _appSettings = AppSettingsModel.empty();
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

      _appSettings = AppSettingsModel.fromMap(mergedMap);
      _setError(null);
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error loading app settings', e);
      _setError(e.toString());
      _appSettings = AppSettingsModel.empty();
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحديث الإعدادات (حفظ الجزء الخاص بالمستخدم وحفظ الجزء العام إذا كان المستخدم أدمن) =====
  Future<void> updateAppSettings(AppSettingsModel settings) async {
    final previousSettings = _appSettings;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('لا يمكن حفظ الإعدادات بدون تسجيل دخول');
      }

      _appSettings = settings;
      notifyListeners();

      // 1. فصل إعدادات المستخدم الخاصة لحفظها في client_settings
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

      // 2. فصل الإعدادات العامة لحفظها في app_settings
      final globalSettingsMap = {
        'support_email': settings.supportEmail,
        'support_phone': settings.supportPhone,
        'support_website': settings.supportWebsite,
        'app_delivery_base_fee': settings.appDeliveryBaseFee,
        'app_delivery_fee_per_km': settings.appDeliveryFeePerKm,
        'app_delivery_max_distance': settings.appDeliveryMaxDistance,
        'app_delivery_estimated_time': settings.appDeliveryEstimatedTime,
        'multi_store_delivery_fee_per_km': settings.multiStoreDeliveryFeePerKm,
        'multi_store_delivery_min_distance': settings.multiStoreDeliveryMinDistance,
        'multi_store_delivery_fee_enabled': settings.multiStoreDeliveryFeeEnabled,
      };

      // حفظ إعدادات المستخدم الشخصية
      await _supabase.from('client_settings').upsert({
        ...userSettingsMap,
        'client_id': userId,
      }, onConflict: 'client_id');

      // حفظ الإعدادات العامة للتطبيق (فقط إذا كان المستخدم أدمن)
      final profileRow = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .limit(1)
          .maybeSingle();

      if (profileRow != null && profileRow['role'] == 'admin') {
        final globalRows = await _supabase.from('app_settings').select('id').limit(1);
        if (globalRows.isNotEmpty) {
          final globalId = globalRows.first['id'];
          await _supabase.from('app_settings').update(globalSettingsMap).eq('id', globalId);
        } else {
          await _supabase.from('app_settings').insert(globalSettingsMap);
        }
      }

      _setError(null);
    } catch (e) {
      _appSettings = previousSettings;
      notifyListeners();
      AppLogger.error('❌ Error updating app settings', e);
      _setError(e.toString());
      rethrow;
    }
  }

  // ===== إعادة تعيين الإعدادات =====
  Future<void> resetSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final defaultSettings = AppSettingsModel.defaults(userId);
      await updateAppSettings(defaultSettings);
    } catch (e) {
      AppLogger.error('❌ Error resetting app settings', e);
      _setError(e.toString());
      rethrow;
    }
  }

  // ===== جلب حالة الصيانة =====
  Future<bool> isInMaintenance() async {
    try {
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('maintenance_windows')
          .select()
          .eq('is_active', true)
          .lte('start_time', now.toIso8601String())
          .gte('end_time', now.toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger.error('❌ Error checking maintenance status', e);
      return false;
    }
  }

  // ===== تنسيق العملة =====
  String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ${_appSettings.currency.symbol}';
  }
}
