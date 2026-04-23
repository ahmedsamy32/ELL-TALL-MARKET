/// Google Sign-In Service integrated with Supabase
/// Following the official Supabase Google OAuth documentation
/// https://supabase.com/docs/guides/auth/social-login/auth-google
///
/// دمج خدمتي Google Sign-In العادية والمتكاملة مع Supabase
library;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';

/// Google Sign-In Service with Supabase Integration
/// خدمة شاملة لتسجيل الدخول مع Google ودمجها مع Supabase
class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._();
  static GoogleSignInService get instance => _instance;

  GoogleSignInService._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  // Google Sign-In Configuration
  static GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  // Android Client ID من Google Console
  static const String _androidClientId =
      '941471556278-g0d409tmu6qv6oskauhkgbu04ko9faci.apps.googleusercontent.com';

  // Web Client ID من Google Console
  static const String _webClientId =
      '337870521468-kjf5h0aqjgs9aiv5jn67csdtptj8afja.apps.googleusercontent.com';

  /// تهيئة Google Sign-In مع Client ID
  Future<void> initialize({String? clientId}) async {
    if (!_isInitialized) {
      // ✅ استخدام Web Client ID على الويب، وAndroid Client ID على الموبايل
      final configClientId =
          clientId ?? (kIsWeb ? _webClientId : _androidClientId);
      await _googleSignIn.initialize(clientId: configClientId);
      _isInitialized = true;
      AppLogger.info(
        '✅ تم تهيئة Google Sign-In مع Client ID: ${configClientId.substring(0, 20)}...',
      );
    }
  }

  /// تسجيل دخول Google مع Supabase (طريقة شاملة)
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      AppLogger.info('🚀 بدء تسجيل الدخول مع Google');

      // ✅ التأكد من التهيئة مع Client ID المناسب للمنصة
      if (!_isInitialized) {
        await initialize(clientId: kIsWeb ? _webClientId : _androidClientId);
      }

      // الخطوة 1: تسجيل الدخول مع Google (استخدام authenticate في الإصدار الجديد)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      AppLogger.info('✅ تم الحصول على بيانات Google: ${googleUser.email}');

      // الخطوة 2: الحصول على Google ID Token
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        AppLogger.error('❌ فشل في الحصول على Google ID Token');
        return null;
      }

      AppLogger.info('✅ تم الحصول على Google ID Token');

      // الخطوة 3: تسجيل الدخول مع Supabase باستخدام Google Token
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );

      if (response.user != null) {
        AppLogger.info(
          '✅ تم تسجيل الدخول بنجاح مع Supabase: ${response.user!.email}',
        );

        // إنشاء/تحديث profile إذا لزم الأمر
        await _createOrUpdateProfile(response.user!);

        return response;
      } else {
        AppLogger.error('❌ فشل في تسجيل الدخول مع Supabase');
        return null;
      }
    } on AuthException catch (e) {
      AppLogger.error('❌ خطأ Supabase Auth: ${e.message}', e);
      await _handleAuthError(e);
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في تسجيل الدخول مع Google', e);
      return null;
    }
  }

  /// إنشاء أو تحديث profile المستخدم
  Future<void> _createOrUpdateProfile(User user) async {
    try {
      // التحقق من وجود profile
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // إنشاء profile جديد
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'full_name':
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              '',
          'avatar_url':
              user.userMetadata?['avatar_url'] ??
              user.userMetadata?['picture'] ??
              '',
          'provider': 'google',
          'updated_at': DateTime.now().toIso8601String(),
        });

        AppLogger.info('✅ تم إنشاء profile جديد للمستخدم');
      } else {
        // تحديث profile موجود
        await _supabase
            .from('profiles')
            .update({
              'full_name':
                  user.userMetadata?['full_name'] ??
                  user.userMetadata?['name'] ??
                  existingProfile['full_name'],
              'avatar_url':
                  user.userMetadata?['avatar_url'] ??
                  user.userMetadata?['picture'] ??
                  existingProfile['avatar_url'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);

        AppLogger.info('✅ تم تحديث profile المستخدم');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء/تحديث profile', e);
    }
  }

  /// معالجة أخطاء المصادقة
  Future<void> _handleAuthError(AuthException e) async {
    switch (e.statusCode) {
      case '400':
        AppLogger.error('خطأ في البيانات المرسلة لـ Supabase');
        break;
      case '401':
        AppLogger.error('رمز Google غير صحيح أو منتهي الصلاحية');
        break;
      case '422':
        AppLogger.error('المستخدم غير موجود أو محظور');
        break;
      default:
        AppLogger.error('خطأ غير معروف في المصادقة: ${e.message}');
    }
  }

  /// تسجيل دخول Google فقط (بدون Supabase)
  /// مفيد للتطبيقات التي تريد استخدام Google فقط
  Future<GoogleSignInAccount?> signInWithGoogleOnly() async {
    try {
      AppLogger.info('🚀 تسجيل دخول Google فقط');

      if (!_isInitialized) {
        await initialize();
      }

      final account = await _googleSignIn.authenticate();

      if (account.email.isNotEmpty) {
        AppLogger.info('✅ تم تسجيل الدخول مع Google: ${account.email}');
      }

      return account;
    } catch (e) {
      AppLogger.error('❌ خطأ في تسجيل الدخول مع Google', e);
      return null;
    }
  }

  /// محاولة تسجيل الدخول بصمت (بدون تفاعل من المستخدم)
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final account = await _googleSignIn.attemptLightweightAuthentication();

      if (account?.email != null) {
        AppLogger.info('✅ تم العثور على مستخدم محفوظ: ${account!.email}');
      }

      return account;
    } catch (e) {
      AppLogger.info('ℹ️ لا يوجد مستخدم محفوظ للدخول الصامت');
      return null;
    }
  }

  /// الحصول على المستخدم الحالي من Google
  Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      return await _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المستخدم الحالي', e);
      return null;
    }
  }

  /// تسجيل خروج شامل
  Future<void> signOut() async {
    try {
      AppLogger.info('🚪 بدء تسجيل الخروج');

      // تسجيل الخروج من Google
      await _googleSignIn.signOut();

      // تسجيل الخروج من Supabase
      await _supabase.auth.signOut();

      AppLogger.info('✅ تم تسجيل الخروج بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تسجيل الخروج', e);
    }
  }

  /// قطع الاتصال نهائياً
  Future<void> disconnect() async {
    try {
      AppLogger.info('🔌 قطع الاتصال نهائياً');

      // قطع الاتصال من Google
      await _googleSignIn.disconnect();

      // تسجيل الخروج من Supabase
      await _supabase.auth.signOut();

      AppLogger.info('✅ تم قطع الاتصال نهائياً');
    } catch (e) {
      AppLogger.error('❌ خطأ في قطع الاتصال', e);
    }
  }

  /// التحقق من حالة تسجيل الدخول
  bool get isSignedIn => _supabase.auth.currentUser != null;

  /// الحصول على المستخدم الحالي
  User? get currentUser => _supabase.auth.currentUser;

  /// التحقق من وجود مستخدم Google
  bool get hasGoogleUser {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    return user.appMetadata['provider'] == 'google';
  }

  /// معلومات المستخدم للعرض
  Map<String, dynamic>? get userDisplayInfo {
    final user = currentUser;
    if (user == null) return null;

    return {
      'id': user.id,
      'email': user.email ?? '',
      'name':
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          'مستخدم',
      'avatar':
          user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          '',
      'provider': 'google',
      'isVerified': user.emailConfirmedAt != null,
    };
  }
}
