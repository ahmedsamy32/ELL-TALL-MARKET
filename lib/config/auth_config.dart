class AuthConfig {
  // إعدادات Google Sign-In
  static const String googleClientId =
      '337870521468-kjf5h0aqjgs9aiv5jn67csdtptj8afja.apps.googleusercontent.com';

  // إعدادات Facebook Auth
  static const List<String> facebookPermissions = ['email', 'public_profile'];

  // إعدادات عامة للمصادقة
  static const Duration authTimeout = Duration(seconds: 30);
  static const bool enableDebugLogs = true;

  // رسائل المصادقة
  static const Map<String, String> authMessages = {
    'google_signin_start': 'جاري تسجيل الدخول بواسطة جوجل...',
    'facebook_signin_start': 'جاري تسجيل الدخول بواسطة فيسبوك...',
    'signin_success': 'تم تسجيل الدخول بنجاح!',
    'signin_failed': 'فشل تسجيل الدخول',
    'signout_start': 'جاري تسجيل الخروج...',
    'signout_success': 'تم تسجيل الخروج بنجاح',
    'network_error': 'تحقق من اتصالك بالإنترنت',
    'unexpected_error': 'حدث خطأ غير متوقع',
  };

  // حقول الملف الشخصي المطلوبة
  static const Map<String, String> profileFields = {
    'facebook': 'name,email,picture.type(large)',
    'google': 'email,name,picture',
  };
}
