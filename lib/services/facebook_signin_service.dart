import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';

/// Facebook Sign-In Service integrated with Supabase
class FacebookSignInService {
  static final FacebookSignInService _instance = FacebookSignInService._();
  static FacebookSignInService get instance => _instance;

  FacebookSignInService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  /// تسجيل دخول فيسبوك مع Supabase
  Future<AuthResponse?> signInWithFacebook() async {
    try {
      AppLogger.info('🚀 بدء تسجيل الدخول مع فيسبوك');

      // 1. طلب تسجيل الدخول من فيسبوك
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        AppLogger.info('✅ حصلنا على Facebook Access Token');

        // 2. تسجيل الدخول مع Supabase باستخدام Token
        final AuthResponse response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.facebook,
          idToken: accessToken.tokenString,
        );

        if (response.user != null) {
          AppLogger.info('✅ تم تسجيل الدخول بنجاح مع Supabase: ${response.user!.email}');
          return response;
        } else {
          AppLogger.error('❌ فشل تسجيل الدخول مع Supabase بعد نجاح فيسبوك');
          return null;
        }
      } else if (result.status == LoginStatus.cancelled) {
        AppLogger.info('ℹ️ تم إلغاء تسجيل الدخول من قبل المستخدم');
        return null;
      } else {
        AppLogger.error('❌ خطأ في تسجيل دخول فيسبوك: ${result.message}');
        return null;
      }
    } on AuthException catch (e) {
      AppLogger.error('❌ خطأ Supabase Auth بفيسبوك: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ غير متوقع في تسجيل دخول فيسبوك', e);
      return null;
    }
  }

  /// تسجيل خروج
  Future<void> signOut() async {
    try {
      await FacebookAuth.instance.logOut();
      AppLogger.info('✅ سجل الخروج من فيسبوك');
    } catch (e) {
      AppLogger.error('❌ خطأ في تسجيل خروج فيسبوك', e);
    }
  }
}
