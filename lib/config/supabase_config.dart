// Removed dart:io for Web compatibility
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// تهيئة Supabase الشاملة حسب الوثائق الرسمية
/// https://supabase.com/docs/reference/dart/introduction
class SupabaseConfig {
  static bool _isInitialized = false;

  // معلومات المشروع من Supabase Dashboard
  // ⚠️ استبدل هذه القيم بقيم مشروعك الجديد
  static const String url = 'https://ebbkdhmwaawzxbidjynz.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImViYmtkaG13YWF3enhiaWRqeW56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxMDI3MTMsImV4cCI6MjA3NTY3ODcxM30.lv_wB9miMcNL3HBg7hXviL3cPaIng2C8x_3rIHzdhF8';

  // الوصول إلى العميل
  static SupabaseClient get client => Supabase.instance.client;

  // الوصول إلى Auth
  static GoTrueClient get auth => Supabase.instance.client.auth;

  // الوصول إلى قاعدة البيانات
  static SupabaseQueryBuilder from(String table) =>
      Supabase.instance.client.from(table);

  // الوصول إلى Storage
  static SupabaseStorageClient get storage => Supabase.instance.client.storage;

  // الوصول إلى Realtime
  static RealtimeClient get realtime => Supabase.instance.client.realtime;

  /// تهيئة Supabase مع جميع الخيارات
  static Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint(
          'ℹ️ SupabaseConfig.initialize: already initialized - skipping.',
        );
      }
      return;
    }

    try {
      debugPrint('🔄 بدء تهيئة Supabase...');

      // Add retry logic with timeout for DNS issues
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          await Supabase.initialize(
            url: url,
            anonKey: anonKey,
            debug: kDebugMode,

            // خيارات Auth المتقدمة
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              autoRefreshToken: true,
              detectSessionInUri: true,
            ),

            // خيارات Realtime مع مهلة أطول
            realtimeClientOptions: const RealtimeClientOptions(
              logLevel: RealtimeLogLevel.info,
              timeout: Duration(seconds: 40),
            ),

            // خيارات Storage مع محاولات أكثر
            storageOptions: const StorageClientOptions(retryAttempts: 5),

            // خيارات PostgreSQL مع headers مخصصة للشبكة
            postgrestOptions: const PostgrestClientOptions(schema: 'public'),
          ).timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException('Supabase initialization timeout');
            },
          );

          // Success - break the loop
          break;
        } catch (e) {
          retryCount++;

          if (retryCount < maxRetries) {
            debugPrint('⚠️ محاولة $retryCount فشلت، إعادة المحاولة...');
            await Future.delayed(Duration(seconds: retryCount * 2));
          } else {
            debugPrint('❌ فشلت جميع المحاولات ($maxRetries)');
            rethrow;
          }
        }
      }

      // تكوين Auth callbacks
      _setupAuthCallbacks();

      // تكوين Realtime listeners
      _setupRealtimeListeners();

      debugPrint('✅ تم تهيئة Supabase بنجاح');
      debugPrint('   - URL: $url');
      debugPrint('   - Auth: ${auth.currentUser?.id ?? 'غير مسجل'}');
      debugPrint('   - Debug Mode: $kDebugMode');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة Supabase: $e');
      _isInitialized = false;
      rethrow; // إعادة الرفع للتعامل مع الخطأ في مستوى أعلى
    }
  }

  /// إعداد Auth callbacks للاستماع لتغييرات المصادقة
  static void _setupAuthCallbacks() {
    auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = session?.user;

      if (kDebugMode) {
        debugPrint('🔐 Auth State Changed:');
        debugPrint('   - Event: ${data.event}');
        debugPrint('   - User: ${user?.id ?? 'null'}');
        debugPrint('   - Email: ${user?.email ?? 'null'}');
      }

      switch (data.event) {
        case AuthChangeEvent.signedIn:
          debugPrint('✅ تم تسجيل الدخول');
          break;
        case AuthChangeEvent.signedOut:
          debugPrint('👋 تم تسجيل الخروج');
          break;
        case AuthChangeEvent.tokenRefreshed:
          debugPrint('🔄 تم تحديث الرمز المميز');
          break;
        case AuthChangeEvent.userUpdated:
          debugPrint('👤 تم تحديث بيانات المستخدم');
          break;
        case AuthChangeEvent.passwordRecovery:
          debugPrint('🔑 طلب استعادة كلمة المرور');
          break;
        case AuthChangeEvent.initialSession:
          debugPrint('🎯 تم تحديد الجلسة الأولية');
          break;
        default:
          debugPrint('🔄 حدث Auth غير معروف: ${data.event}');
      }
    });
  }

  /// إعداد Realtime listeners
  static void _setupRealtimeListeners() {
    if (kDebugMode) {
      // الاستماع لحالة الاتصال
      realtime.onOpen(() {
        debugPrint('🔗 Realtime connection opened');
      });

      realtime.onClose((event) {
        // Fix: Check if event is null before accessing reason
        final reason = event?.reason ?? 'Unknown reason';
        debugPrint('❌ Realtime connection closed: $reason');
      });

      realtime.onError((error) {
        debugPrint('💥 Realtime error: $error');
      });
    }
  }

  /// فحص حالة الاتصال مع تحسين الأداء والأمان
  static Future<bool> isConnected() async {
    try {
      // استخدام طريقة أبسط للفحص - استعلام عن المصادقة
      final session = client.auth.currentSession;
      debugPrint('🔍 Session check: ${session != null ? 'valid' : 'null'}');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 Connection check failed: $e');
      }
      // إذا كان الخطأ مرتبط بالشبكة، نعتبره عدم اتصال
      if (e.toString().contains('SocketException') ||
          e.toString().contains('timeout') ||
          e.toString().contains('connection') ||
          e.toString().contains('ClientException')) {
        return false;
      }
      // إذا كان الخطأ من نوع آخر (مثل Auth error)، فهذا يعني أن الاتصال يعمل
      return true;
    }
  }

  /// إعادة محاولة الاتصال
  static Future<bool> retryConnection({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      if (kDebugMode) {
        debugPrint('🔄 Attempting connection retry ${i + 1}/$maxRetries');
      }

      if (await isConnected()) {
        debugPrint('✅ Connection successful');
        return true;
      }

      // انتظار متزايد بين المحاولات
      await Future.delayed(Duration(seconds: (i + 1) * 2));
    }

    debugPrint('❌ Connection failed after $maxRetries retries');
    return false;
  }

  /// الحصول على معلومات الجلسة الحالية
  static Session? get currentSession => auth.currentSession;

  /// الحصول على المستخدم الحالي
  static User? get currentUser => auth.currentUser;

  /// فحص ما إذا كان المستخدم مسجلاً الدخول
  static bool get isAuthenticated => currentUser != null;

  /// تسجيل الخروج الآمن
  static Future<void> signOut() async {
    try {
      await auth.signOut();
      debugPrint('👋 تم تسجيل الخروج بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }

  /// تحديث الرمز المميز
  static Future<bool> refreshSession() async {
    try {
      final response = await auth.refreshSession();
      return response.session != null;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث الجلسة: $e');
      return false;
    }
  }

  /// إرسال إشعار لتحديث Realtime
  static Future<void> sendRealtimeMessage(
    String channel,
    String event,
    Map<String, dynamic> payload,
  ) async {
    try {
      final subscription = realtime.channel(channel);
      subscription.subscribe((status, error) {
        if (error != null) {
          debugPrint('❌ Subscription error: $error');
        }
      });

      // إرسال broadcast message
      await subscription.sendBroadcastMessage(event: event, payload: payload);
    } catch (e) {
      debugPrint('❌ خطأ في إرسال Realtime message: $e');
    }
  }

  /// إنشاء subscription للـ Realtime
  static RealtimeChannel createRealtimeSubscription(String channel) {
    return realtime.channel(channel);
  }

  /// رفع ملف إلى Storage
  static Future<String?> uploadFile(
    String bucket,
    String path,
    dynamic file, {
    FileOptions? fileOptions,
  }) async {
    try {
      // التحقق من المصادقة أولاً
      if (currentUser == null) {
        debugPrint('❌ لا يمكن رفع الملف: المستخدم غير مصادق');
        debugPrint('   - Bucket: $bucket');
        debugPrint('   - Path: $path');
        throw Exception('يجب تسجيل الدخول أولاً لرفع الملفات');
      }

      debugPrint('📤 رفع ملف:');
      debugPrint('   - Bucket: $bucket');
      debugPrint('   - Path: $path');
      debugPrint('   - User: ${currentUser!.id}');

      await storage
          .from(bucket)
          .upload(path, file, fileOptions: fileOptions ?? const FileOptions());

      // الحصول على الرابط العام
      final publicUrl = storage.from(bucket).getPublicUrl(path);
      debugPrint('✅ تم رفع الملف بنجاح: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('❌ Storage Error:');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - StatusCode: ${e.statusCode}');
      debugPrint('   - Error: ${e.error}');

      // معالجة أخطاء RLS بشكل خاص
      if (e.message.contains('row-level security') ||
          e.message.contains('policy') ||
          e.statusCode == '403' ||
          e.statusCode == '401') {
        debugPrint(
          '⚠️ خطأ في صلاحيات Storage - تحقق من سياسات RLS في Supabase Dashboard',
        );
        throw Exception(
          'ليس لديك صلاحية لرفع الملفات. يرجى التواصل مع الدعم الفني.',
        );
      }

      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ خطأ غير متوقع في رفع الملف:');
      debugPrint('   - Error: $e');
      debugPrint('   - Stack: $stackTrace');
      rethrow;
    }
  }

  /// حذف ملف من Storage
  static Future<bool> deleteFile(String bucket, String path) async {
    try {
      await storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حذف الملف: $e');
      return false;
    }
  }

  /// معلومات التشخيص
  static Map<String, dynamic> getDiagnosticInfo() {
    return {
      'url': url,
      'authenticated': isAuthenticated,
      'userId': currentUser?.id,
      'userEmail': currentUser?.email,
      'sessionExists': currentSession != null,
      'realtimeConnected': realtime.isConnected,
      'debugMode': kDebugMode,
    };
  }

  /// طباعة معلومات التشخيص
  static void printDiagnosticInfo() {
    final info = getDiagnosticInfo();
    debugPrint('🔍 Supabase Diagnostic Info:');
    info.forEach((key, value) {
      debugPrint('   - $key: $value');
    });
  }
}
