import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

/// خدمة التعامل مع Deep Links للمصادقة
/// تتعامل مع روابط التأكيد والتوجيه المناسب للمستخدم
/// هذه هي الخدمة الأساسية لمعالجة Deep Links في التطبيق
class AuthDeepLinkHandler {
  static const MethodChannel _channel = MethodChannel('auth_deep_link');
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool _isInitialized = false;

  /// تهيئة معالج Deep Links - الخدمة الأساسية
  static void initialize() {
    if (_isInitialized) {
      debugPrint('🔄 AuthDeepLinkHandler: الخدمة مُفعلة مسبقاً');
      return;
    }

    try {
      // مراقبة تغيرات حالة المصادقة
      _listenToAuthChanges();

      // مراقبة Deep Links من النظام
      _channel.setMethodCallHandler(_handleMethodCall);

      _isInitialized = true;
      debugPrint('✅ AuthDeepLinkHandler: تم تفعيل الخدمة الأساسية بنجاح');
    } catch (e) {
      debugPrint('❌ AuthDeepLinkHandler: خطأ في التفعيل - $e');
    }
  }

  /// معالجة Deep Links الواردة من النظام
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      debugPrint(
        '📱 AuthDeepLinkHandler: استقبال استدعاء من النظام - ${call.method}',
      );

      switch (call.method) {
        case 'handleDeepLink':
          final String url = call.arguments;
          await _handleAuthDeepLink(url);
          break;
        default:
          debugPrint(
            '⚠️ AuthDeepLinkHandler: طريقة غير مدعومة - ${call.method}',
          );
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    } catch (e) {
      debugPrint('❌ AuthDeepLinkHandler: خطأ في معالجة الاستدعاء - $e');
      rethrow;
    }
  }

  /// مراقبة تغيرات حالة المصادقة - مع منع التسجيل التلقائي
  static void _listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((authState) {
      debugPrint('🔄 تغيرت حالة المصادقة: ${authState.event}');

      if (authState.event == AuthChangeEvent.signedIn) {
        final user = authState.session?.user;
        if (user != null) {
          debugPrint('✅ تم تسجيل الدخول عبر Deep Link: ${user.id}');
          debugPrint(
            '📧 حالة تأكيد البريد: ${user.emailConfirmedAt != null ? 'مؤكد' : 'غير مؤكد'}',
          );

          // تم إلغاء منع التسجيل التلقائي - المستخدم يبقى مسجل دخول
          if (user.emailConfirmedAt != null) {
            debugPrint('✅ البريد مؤكد - المستخدم سيبقى مسجل دخول');
            // تم إلغاء تسجيل الخروج التلقائي
            // Future.delayed(Duration.zero, () async {
            //   try {
            //     await SupabaseService.signOut();
            //     debugPrint('✅ تم منع التسجيل التلقائي بنجاح');
            //   } catch (e) {
            //     debugPrint('❌ خطأ في منع التسجيل التلقائي: $e');
            //   }
            // });
          }

          // إشعار بنجاح التأكيد فقط (بدون تسجيل دخول)
          _notifyEmailConfirmationSuccess(user);
        }
      } else if (authState.event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('🔄 تم تحديث الرمز المميز');
      }
    });
  }

  /// إشعار بنجاح تأكيد البريد بدون تسجيل دخول تلقائي
  static void _notifyEmailConfirmationSuccess(User user) {
    if (user.emailConfirmedAt != null) {
      debugPrint(
        '✅ تم تأكيد البريد الإلكتروني! المستخدم بحاجة لتسجيل الدخول يدوياً',
      );
    }
  }

  /// معالجة رابط المصادقة الوارد
  static Future<void> _handleAuthDeepLink(String url) async {
    try {
      debugPrint('🔗 استقبال Deep Link: $url');

      // فحص ما إذا كان الرابط يحتوي على معاملات المصادقة
      final uri = Uri.parse(url);

      if (uri.scheme == 'elltallmarket' &&
          uri.host == 'auth' &&
          uri.path == '/callback') {
        // استخراج معاملات المصادقة
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];

        if (accessToken != null && refreshToken != null) {
          debugPrint('✅ تم العثور على رموز المصادقة في Deep Link');

          // إنشاء جلسة Supabase من الرموز
          await _supabase.auth.setSession(refreshToken);

          // فحص حالة تأكيد البريد
          await _checkAndHandleEmailVerification();
        } else {
          debugPrint('❌ رموز المصادقة مفقودة في Deep Link');
        }
      } else {
        debugPrint('⚠️ Deep Link غير متعرف عليه: $url');
      }
    } catch (e) {
      debugPrint('❌ خطأ في معالجة Deep Link: $e');
    }
  }

  /// فحص ومعالجة حالة تأكيد البريد الإلكتروني
  static Future<void> _checkAndHandleEmailVerification() async {
    try {
      final currentUser = _supabase.auth.currentUser;

      if (currentUser == null) {
        debugPrint('❌ المستخدم غير مسجل دخول');
        return;
      }

      if (currentUser.emailConfirmedAt != null) {
        debugPrint('✅ البريد الإلكتروني مؤكد - تسجيل دخول ناجح');
        // سيتم التعامل مع هذا في _notifyAuthSuccess
      } else {
        debugPrint('⏳ البريد الإلكتروني غير مؤكد بعد');
        // إظهار رسالة للمستخدم
        _showEmailVerificationPendingMessage();
      }
    } catch (e) {
      debugPrint('❌ خطأ في فحص حالة تأكيد البريد: $e');
    }
  }

  /// إظهار رسالة انتظار تأكيد البريد
  static void _showEmailVerificationPendingMessage() {
    // يمكن تحسين هذا باستخدام Overlay أو SnackBar عبر NavigatorKey
    debugPrint('📧 يجب إظهار رسالة انتظار تأكيد البريد للمستخدم');
  }

  /// فحص ما إذا كان الرابط صالح للمصادقة
  static bool isAuthDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'elltallmarket' &&
          uri.host == 'auth' &&
          uri.path == '/callback';
    } catch (e) {
      return false;
    }
  }

  /// معالجة Deep Link في سياق معين مع Provider
  static Future<void> handleAuthDeepLinkWithContext(
    String url,
    BuildContext context,
  ) async {
    try {
      if (!isAuthDeepLink(url)) {
        debugPrint('⚠️ الرابط ليس رابط مصادقة صالح: $url');
        return;
      }

      debugPrint('🔗 معالجة Deep Link في السياق: $url');

      // استخراج الرموز من الرابط
      final uri = Uri.parse(url);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];

      if (accessToken != null && refreshToken != null) {
        // إنشاء جلسة Supabase
        await _supabase.auth.setSession(refreshToken);

        // تحديث Provider (سيتم تحديث حالة Provider تلقائياً عبر AuthStateChange listener)
        if (context.mounted) {
          // فحص حالة تأكيد البريد
          final currentUser = _supabase.auth.currentUser;

          if (currentUser != null && currentUser.emailConfirmedAt != null) {
            // تم إلغاء منع التسجيل التلقائي - المستخدم يبقى مسجل دخول
            try {
              debugPrint('✅ تم تأكيد البريد الإلكتروني - المستخدم مسجل دخول');
              // await SupabaseService.signOut();

              if (context.mounted) {
                debugPrint('✅ المستخدم سيبقى مسجل دخول');

                // التوجه للصفحة الرئيسية بدلاً من تسجيل الدخول
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              }
            } catch (e) {
              debugPrint('❌ خطأ في المعالجة: $e');
            }
          } else {
            // إظهار رسالة انتظار تأكيد
            if (context.mounted) {
              debugPrint('⏳ لم يتم تأكيد البريد الإلكتروني بعد');
            }
          }
        }
      } else {
        debugPrint('❌ رموز المصادقة مفقودة في Deep Link');
      }
    } catch (e) {
      debugPrint('❌ خطأ في معالجة Deep Link: $e');
    }
  }

  /// التحقق من حالة تفعيل الخدمة
  static bool get isInitialized => _isInitialized;

  /// إعادة تعيين الخدمة
  static void reset() {
    _isInitialized = false;
    debugPrint('🔄 AuthDeepLinkHandler: تم إعادة تعيين الخدمة');
  }

  /// معلومات تشخيصية للخدمة
  static Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isInitialized': _isInitialized,
      'serviceName': 'AuthDeepLinkHandler',
      'isMainService': true,
      'supportedScheme': 'elltallmarket://auth/callback',
      'supabaseConnected': _supabase.auth.currentUser != null,
    };
  }

  /// طباعة معلومات تشخيصية
  static void printDiagnosticInfo() {
    final info = getDiagnosticInfo();
    debugPrint('🔍 AuthDeepLinkHandler - معلومات الخدمة الأساسية:');
    info.forEach((key, value) {
      debugPrint('   - $key: $value');
    });
  }
}
