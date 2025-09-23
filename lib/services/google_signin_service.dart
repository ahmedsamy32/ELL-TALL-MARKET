import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService _instance = GoogleSignInService._();
  static GoogleSignInService get instance => _instance;

  bool _isInitialized = false;

  // ✅ استخدام GoogleSignIn.instance بدلاً من إنشاء instance جديد
  Future<void> initialize() async {
    if (!_isInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId:
            '337870521468-kjf5h0aqjgs9aiv5jn67csdtptj8afja.apps.googleusercontent.com',
      );
      _isInitialized = true;
    }
  }

  // ✅ استخدام authenticate بدلاً من signIn في الإصدار الجديد
  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // في google_sign_in 7.2.0، استخدم authenticate
      final account = await GoogleSignIn.instance.authenticate();
      return account;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  // ✅ في google_sign_in 7.2.0، لا يوجد currentUser مباشرة
  // يمكن استخدام attemptLightweightAuthentication للتحقق من المستخدم الحالي
  Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // ✅ محاولة تسجيل الدخول بصمت (بدون تفاعل من المستخدم)
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (e) {
      print('Error attempting silent sign in: $e');
      return null;
    }
  }
}
