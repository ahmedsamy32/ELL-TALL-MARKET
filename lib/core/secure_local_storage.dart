import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تطبيق آمن لـ [LocalStorage] الخاص بـ Supabase باستخدام [FlutterSecureStorage]
/// متوافق مع معيار OWASP MASVS-STORAGE لحماية توكنز الجلسات.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> initialize() async {
    // لا يتطلب تهيئة خاصة لـ FlutterSecureStorage
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: supabasePersistSessionKey);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: supabasePersistSessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(
        key: supabasePersistSessionKey,
        value: persistSessionString,
      );
    } catch (e) {
      debugPrint('SecureLocalStorage Persist Error: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: supabasePersistSessionKey);
    } catch (e) {
      debugPrint('SecureLocalStorage Remove Error: $e');
    }
  }
}
