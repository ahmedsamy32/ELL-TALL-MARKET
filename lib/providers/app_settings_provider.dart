import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/settings_model.dart';

/// Admin/app-wide settings provider.
/// Uses `public.app_settings` (NOT per-client preferences).
class AppSettingsProvider with ChangeNotifier {
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
        _appSettings = AppSettingsModel.empty();
        _setLoading(false);
        return;
      }

      final rows = await _supabase
          .from('app_settings')
          .select()
          .eq('client_id', userId)
          .limit(1);

      if (rows.isNotEmpty) {
        _appSettings = AppSettingsModel.fromMap(
          Map<String, dynamic>.from(rows.first as Map),
        );
      } else {
        _appSettings = AppSettingsModel.defaults(userId);
        try {
          await updateAppSettings(_appSettings);
        } catch (e) {
          AppLogger.warning('⚠️ Could not save default app settings', e);
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error loading app settings', e);
      _setError(e.toString());
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

      final previousSettings = _appSettings;
      _appSettings = settings;
      notifyListeners();

      final updateData = settings.toDatabaseMap();

      try {
        final updated = await _supabase
            .from('app_settings')
            .update(updateData)
            .eq('client_id', userId);

        final bool didUpdate = updated.isNotEmpty;
        if (!didUpdate) {
          await _supabase.from('app_settings').insert({
            ...updateData,
            'client_id': userId,
          });
        }
      } catch (e) {
        _appSettings = previousSettings;
        notifyListeners();
        rethrow;
      }
    } catch (e) {
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
