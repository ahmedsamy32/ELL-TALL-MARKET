import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class SupabaseConfig {
  static const String url = 'https://oonfjaiodghxfgapdcfw.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vbmZqYWlvZGdoeGZnYXBkY2Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2ODc3NDgsImV4cCI6MjA3MzI2Mzc0OH0.o_Tr8Saqw74j85T_SbFwNuzlNQJ0cbKkhTfPh-odn90';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      // تحسين إعدادات HTTP للتعامل مع مشاكل الاتصال
      if (!kIsWeb) {
        HttpOverrides.global = _CustomHttpOverrides();
      }

      await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);

      if (kDebugMode) {
        debugPrint('✅ Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Supabase initialization error: $e');
      }
      // Continue app execution even if Supabase fails
      // The app should work in offline mode or show appropriate errors
    }
  }

  /// فحص حالة الاتصال
  static Future<bool> isConnected() async {
    try {
      // محاولة select بسيط مع timeout
      await client
          .from('profiles')
          .select('count')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 Connection check failed: $e');
      }
      return false;
    }
  }

  /// إعادة محاولة الاتصال
  static Future<bool> retryConnection({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      if (kDebugMode) {
        debugPrint('🔄 Attempting connection retry ${i + 1}/$maxRetries');
      }

      if (await isConnected()) {
        if (kDebugMode) {
          debugPrint('✅ Connection restored on attempt ${i + 1}');
        }
        return true;
      }

      // انتظار متزايد بين المحاولات
      await Future.delayed(Duration(seconds: (i + 1) * 2));
    }

    if (kDebugMode) {
      debugPrint('❌ All connection retries failed');
    }
    return false;
  }
}

/// إعدادات HTTP محسنة وآمنة
class _CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // إعدادات timeout محسنة
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 30);

    // في وضع التطوير فقط - للإنتاج يجب إزالة هذا
    if (kDebugMode) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            // التحقق من أن الـ host صحيح
            if (host.contains('supabase.co')) {
              debugPrint('⚠️ Accepting certificate for Supabase: $host');
              return true;
            }
            return false; // رفض الشهادات الأخرى
          };
    }

    return client;
  }
}
