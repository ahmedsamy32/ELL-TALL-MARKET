import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  AppSettingsModel _appSettings = AppSettingsModel.empty();
  bool _isLoading = false;
  String? _error;

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

  // ===== جلب الإعدادات =====
  Future<void> loadSettings() async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        // لا يوجد مستخدم مسجل دخول
        _appSettings = AppSettingsModel.empty();
        _setLoading(false);
        return;
      }

      // محاولة قراءة الإعدادات الموجودة من جدول app_settings
      final response = await _supabase
          .from('app_settings')
          .select()
          .eq('client_id', userId)
          .maybeSingle();

      if (response != null) {
        _appSettings = AppSettingsModel.fromMap(response);
      } else {
        // إذا لم توجد إعدادات، أنشئ إعدادات افتراضية جديدة
        _appSettings = AppSettingsModel.defaults(userId);
        // حاول حفظ الإعدادات الافتراضية
        try {
          await updateAppSettings(_appSettings);
        } catch (e) {
          // تجاهل خطأ الحفظ، فقط استخدم الافتراضي
          AppLogger.warning('⚠️ Could not save default settings', e);
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error loading settings', e);
      _setError(e.toString());
      // استخدم الإعدادات الافتراضية في حالة الخطأ
      _appSettings = AppSettingsModel.empty();
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحديث الإعدادات =====
  Future<void> updateAppSettings(AppSettingsModel settings) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('لا يمكن حفظ الإعدادات بدون تسجيل دخول');
      }

      // تحديث الحالة المحلية فوراً للاستجابة السريعة
      final previousSettings = _appSettings;
      _appSettings = settings;
      notifyListeners();

      // تحضير البيانات للحفظ باستخدام toDatabaseMap
      final updateData = settings.toDatabaseMap();

      try {
        // محاولة التحديث أولاً (أسرع)
        final result = await _supabase
            .from('app_settings')
            .update(updateData)
            .eq('client_id', userId)
            .select()
            .maybeSingle();

        // إذا لم يتم التحديث (لا يوجد سجل)، أنشئ سجلاً جديداً
        if (result == null) {
          await _supabase.from('app_settings').insert({
            ...updateData,
            'client_id': userId,
          });
        }
      } catch (e) {
        // في حالة الخطأ، استرجع الإعدادات السابقة
        _appSettings = previousSettings;
        notifyListeners();
        rethrow;
      }
    } catch (e) {
      AppLogger.error('❌ Error updating settings', e);
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
      AppLogger.error('❌ Error resetting settings', e);
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
