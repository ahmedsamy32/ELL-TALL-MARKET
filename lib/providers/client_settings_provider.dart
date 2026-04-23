import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/settings_model.dart';

class ClientSettingsProvider with ChangeNotifier {
  static const String _tableName = 'client_settings';

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

      final rows = await _supabase
          .from(_tableName)
          .select()
          .eq('client_id', userId)
          .limit(1);

      if (rows.isNotEmpty) {
        _clientSettings = AppSettingsModel.fromMap(
          Map<String, dynamic>.from(rows.first as Map),
        );
      } else {
        _clientSettings = AppSettingsModel.defaults(userId);
        try {
          await updateSettings(_clientSettings);
        } catch (e) {
          AppLogger.warning('⚠️ Could not save default client settings', e);
        }
      }

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

      final updateData = settings.toDatabaseMap()
        ..remove('app_delivery_base_fee')
        ..remove('app_delivery_fee_per_km')
        ..remove('app_delivery_max_distance')
        ..remove('app_delivery_estimated_time');

      try {
        // استخدام upsert لضمان التحديث أو الإضافة بدون أخطاء "duplicate key"
        await _supabase.from(_tableName).upsert({
          ...updateData,
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
