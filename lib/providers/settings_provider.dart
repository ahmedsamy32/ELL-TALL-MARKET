import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  late AppSettings _appSettings = AppSettings.defaults();
  bool _isLoading = false;
  String? _error;

  AppSettings get appSettings => _appSettings;
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
      final response = await _supabase
          .from('app_settings')
          .select()
          .single();

      _appSettings = AppSettings.fromJson(response);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error loading settings: $e');
      _setError(e.toString());
      // Use defaults if loading fails
      _appSettings = AppSettings.defaults();
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحديث الإعدادات =====
  Future<void> updateAppSettings(AppSettings settings) async {
    try {
      await _supabase
          .from('app_settings')
          .upsert(settings.toJson());

      _appSettings = settings;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error updating settings: $e');
      _setError(e.toString());
      rethrow;
    }
  }

  // ===== إعادة تعيين الإعدادات =====
  Future<void> resetSettings() async {
    try {
      final defaultSettings = AppSettings.defaults();
      await updateAppSettings(defaultSettings);
    } catch (e) {
      if (kDebugMode) print('❌ Error resetting settings: $e');
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
      if (kDebugMode) print('❌ Error checking maintenance status: $e');
      return false;
    }
  }
}
