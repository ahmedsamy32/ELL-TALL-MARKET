import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/logger.dart';
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
      AppLogger.info('🔄 AuthDeepLinkHandler: الخدمة مُفعلة مسبقاً');
      return;
    }

    try {
      // مراقبة تغيرات حالة المصادقة
      _listenToAuthChanges();

      // مراقبة Deep Links من النظام
      _channel.setMethodCallHandler(_handleMethodCall);

      _isInitialized = true;
      AppLogger.info('✅ AuthDeepLinkHandler: تم تفعيل الخدمة الأساسية بنجاح');
    } catch (e) {
      AppLogger.error('❌ AuthDeepLinkHandler: خطأ في التفعيل', e);
    }
  }

  /// معالجة Deep Links الواردة من النظام
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      AppLogger.info(
        '📱 AuthDeepLinkHandler: استقبال استدعاء من النظام - ${call.method}',
      );

      switch (call.method) {
        case 'handleDeepLink':
          final String url = call.arguments;
          await _handleAuthDeepLink(url);
          break;
        default:
          AppLogger.warning(
            '⚠️ AuthDeepLinkHandler: طريقة غير مدعومة - ${call.method}',
          );
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    } catch (e) {
      AppLogger.error('❌ AuthDeepLinkHandler: خطأ في معالجة الاستدعاء', e);
      rethrow;
    }
  }

  /// مراقبة تغيرات حالة المصادقة - مع منع التسجيل التلقائي
  static void _listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((authState) {
      AppLogger.info('🔄 تغيرت حالة المصادقة: ${authState.event}');

      if (authState.event == AuthChangeEvent.signedIn) {
        final user = authState.session?.user;
        if (user != null) {
          AppLogger.info('✅ تم تسجيل الدخول عبر Deep Link: ${user.id}');
          AppLogger.info(
            '📧 حالة تأكيد البريد: ${user.emailConfirmedAt != null ? 'مؤكد' : 'غير مؤكد'}',
          );

          // المستخدم يبقى مسجل دخول بعد تأكيد البريد
          if (user.emailConfirmedAt != null) {
            AppLogger.info('✅ البريد مؤكد - المستخدم سيبقى مسجل دخول');
          }

          // إشعار بنجاح التأكيد
          _notifyEmailConfirmationSuccess(user);
        }
      } else if (authState.event == AuthChangeEvent.tokenRefreshed) {
        AppLogger.info('🔄 تم تحديث الرمز المميز');
      }
    });
  }

  /// إشعار بنجاح تأكيد البريد بدون تسجيل دخول تلقائي
  static void _notifyEmailConfirmationSuccess(User user) {
    if (user.emailConfirmedAt != null) {
      AppLogger.info(
        '✅ تم تأكيد البريد الإلكتروني! المستخدم بحاجة لتسجيل الدخول يدوياً',
      );
    }
  }

  /// معالجة رابط المصادقة الوارد
  static Future<void> _handleAuthDeepLink(String url) async {
    try {
      AppLogger.info('🔗 استقبال Deep Link: $url');

      // فحص ما إذا كان الرابط يحتوي على معاملات المصادقة
      final uri = Uri.parse(url);

      if (uri.scheme == 'elltallmarket' &&
          uri.host == 'auth' &&
          uri.path == '/callback') {
        // استخراج معاملات المصادقة
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];

        if (accessToken != null && refreshToken != null) {
          AppLogger.info('✅ تم العثور على رموز المصادقة في Deep Link');

          // إنشاء جلسة Supabase من الرموز
          await _supabase.auth.setSession(refreshToken);

          // فحص حالة تأكيد البريد
          await _checkAndHandleEmailVerification();
        } else {
          AppLogger.warning('❌ رموز المصادقة مفقودة في Deep Link');
        }
      } else {
        AppLogger.warning('⚠️ Deep Link غير متعرف عليه: $url');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة Deep Link', e);
    }
  }

  /// فحص ومعالجة حالة تأكيد البريد الإلكتروني
  static Future<void> _checkAndHandleEmailVerification() async {
    try {
      final currentUser = _supabase.auth.currentUser;

      if (currentUser == null) {
        AppLogger.error('❌ المستخدم غير مسجل دخول');
        return;
      }

      if (currentUser.emailConfirmedAt != null) {
        AppLogger.info('✅ البريد الإلكتروني مؤكد - تسجيل دخول ناجح');
        // سيتم التعامل مع هذا في _notifyAuthSuccess
      } else {
        AppLogger.info('⏳ البريد الإلكتروني غير مؤكد بعد');
        // إظهار رسالة للمستخدم
        _showEmailVerificationPendingMessage();
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص حالة تأكيد البريد', e);
    }
  }

  /// إظهار رسالة انتظار تأكيد البريد
  static void _showEmailVerificationPendingMessage() {
    // يمكن تحسين هذا باستخدام Overlay أو SnackBar عبر NavigatorKey
    AppLogger.info('📧 يجب إظهار رسالة انتظار تأكيد البريد للمستخدم');
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
      AppLogger.info('🔗 بدء معالجة Deep Link: $url');

      if (!isAuthDeepLink(url)) {
        AppLogger.warning('⚠️ الرابط ليس رابط مصادقة صالح: $url');
        return;
      }

      AppLogger.info('✅ الرابط صالح - استخراج المعاملات...');

      // استخراج الرموز من الرابط
      final uri = Uri.parse(url);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];

      AppLogger.info('📋 معاملات الرابط:');
      AppLogger.info(
        '   - access_token: ${accessToken != null ? "موجود" : "مفقود"}',
      );
      AppLogger.info(
        '   - refresh_token: ${refreshToken != null ? "موجود" : "مفقود"}',
      );
      AppLogger.info('   - error: ${error ?? "لا يوجد"}');
      AppLogger.info(
        '   - error_description: ${errorDescription ?? "لا يوجد"}',
      );

      // فحص إذا كان هناك خطأ في الرابط (رابط منتهي أو غير صالح)
      if (error != null || errorDescription != null) {
        AppLogger.error('❌ رابط غير صالح: $error - $errorDescription');

        if (context.mounted) {
          // التوجيه لشاشة تأكيد البريد مع رسالة خطأ
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.emailConfirmation,
            arguments: {
              'email': '', // سيتم الحصول عليه من المستخدم أو من التخزين المحلي
              'expired_link': true,
              'error_message': errorDescription ?? 'رابط التأكيد غير صالح',
            },
          );
        }
        return;
      }

      if (accessToken != null && refreshToken != null) {
        AppLogger.info('🔐 محاولة إنشاء جلسة Supabase...');

        // إنشاء جلسة Supabase
        try {
          await _supabase.auth.setSession(refreshToken);
          AppLogger.info('✅ تم إنشاء الجلسة بنجاح');
        } catch (sessionError) {
          AppLogger.error('❌ فشل إنشاء الجلسة', sessionError);

          // رابط منتهي الصلاحية أو غير صالح
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.emailConfirmation,
              arguments: {
                'email': '',
                'expired_link': true,
                'error_message': 'انتهت صلاحية رابط التأكيد',
              },
            );
          }
          return;
        }

        // تحديث Provider (سيتم تحديث حالة Provider تلقائياً عبر AuthStateChange listener)
        if (context.mounted) {
          AppLogger.info('🔍 فحص حالة المستخدم الحالي...');

          // فحص حالة تأكيد البريد
          final currentUser = _supabase.auth.currentUser;

          if (currentUser != null && currentUser.emailConfirmedAt != null) {
            try {
              AppLogger.info(
                '✅ تم تأكيد البريد الإلكتروني - المستخدم مسجل دخول',
              );
              AppLogger.info('📋 User ID: ${currentUser.id}');
              AppLogger.info('📧 Email: ${currentUser.email}');

              AppLogger.info('🔍 جلب بيانات Profile من قاعدة البيانات...');

              // فحص نوع المستخدم من profiles
              final profileRes = await _supabase
                  .from('profiles')
                  .select('role')
                  .eq('id', currentUser.id)
                  .maybeSingle();

              AppLogger.info('📋 Profile response: $profileRes');

              if (profileRes == null) {
                AppLogger.warning(
                  '⚠️ لم يتم العثور على Profile - قد يكون trigger لم ينفذ بعد',
                );
                // الانتظار قليلاً وإعادة المحاولة
                await Future.delayed(const Duration(seconds: 2));

                final retryProfileRes = await _supabase
                    .from('profiles')
                    .select('role')
                    .eq('id', currentUser.id)
                    .maybeSingle();

                AppLogger.info('📋 Profile retry response: $retryProfileRes');

                if (retryProfileRes == null) {
                  throw Exception(
                    'لم يتم إنشاء Profile - يرجى المحاولة لاحقاً',
                  );
                }
              }

              final userRole = profileRes?['role'] as String?;
              final isMerchant = userRole == 'merchant';

              AppLogger.info('👤 User role: $userRole');
              AppLogger.info('🏪 Is merchant: $isMerchant');

              // توجيه جميع المستخدمين (تجار وعملاء) للصفحة الرئيسية
              // لأن بيانات المتجر يتم إنشاؤها تلقائياً عبر trigger عند التسجيل
              AppLogger.info('✅ توجيه للصفحة الرئيسية - البيانات مكتملة');
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              }
              AppLogger.info('✅ تم استدعاء التوجيه للصفحة الرئيسية');
            } catch (e) {
              AppLogger.error('❌ خطأ في المعالجة', e);
              // fallback: توجيه للصفحة الرئيسية
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              }
            }
          } else {
            // إظهار رسالة انتظار تأكيد
            if (context.mounted) {
              AppLogger.info('⏳ لم يتم تأكيد البريد الإلكتروني بعد');
            }
          }
        }
      } else {
        AppLogger.error('❌ رموز المصادقة مفقودة في Deep Link');

        // رابط غير صالح - لا يحتوي على الرموز المطلوبة
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.emailConfirmation,
            arguments: {
              'email': '',
              'expired_link': true,
              'error_message': 'رابط التأكيد غير صالح أو منتهي الصلاحية',
            },
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في معالجة Deep Link', e);
      AppLogger.error('📍 Stack trace', stackTrace);

      // تحليل نوع الخطأ لتوفير رسالة أكثر وضوحاً
      String errorMessage = 'حدث خطأ في معالجة رابط التأكيد';

      if (e.toString().contains('Connection') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        errorMessage =
            'فشل الاتصال بالخادم. يرجى التحقق من الإنترنت والمحاولة مرة أخرى';
      } else if (e.toString().contains('Session') ||
          e.toString().contains('Invalid token')) {
        errorMessage = 'انتهت صلاحية رابط التأكيد. يرجى طلب رابط جديد';
      } else if (e.toString().contains('User not found')) {
        errorMessage = 'لم يتم العثور على الحساب. يرجى التسجيل مرة أخرى';
      }

      // في حالة حدوث أي خطأ غير متوقع
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.emailConfirmation,
          arguments: {
            'email': '',
            'expired_link': true,
            'error_message': errorMessage,
            'technical_error': e.toString(), // للمطورين
          },
        );
      }
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
    AppLogger.info('🔍 AuthDeepLinkHandler - معلومات الخدمة الأساسية:');
    info.forEach((key, value) {
      AppLogger.info('   - $key: $value');
    });
  }
}
