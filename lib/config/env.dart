import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // إعدادات قاعدة البيانات
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://ebbkdhmwaawzxbidjynz.supabase.co';
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImViYmtkaG13YWF3enhiaWRqeW56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxMDI3MTMsImV4cCI6MjA3NTY3ODcxM30.lv_wB9miMcNL3HBg7hXviL3cPaIng2C8x_3rIHzdhF8';

  // إعدادات المصادقة الاجتماعية
  static String get googleClientId =>
      dotenv.env['GOOGLE_CLIENT_ID'] ??
      '941471556278-7hngn6n5kqno7of3bu3hgplmibh16dce.apps.googleusercontent.com';
  static String get facebookClientId =>
      dotenv.env['FACEBOOK_CLIENT_ID'] ?? 'your_facebook_client_id_here';

  // إعدادات Google Maps و Places
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ??
      'AIzaSyA5q1yifwlqadIZPs4KttQgSH8-ow2G1js';

  // إعدادات Stripe للمدفوعات
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ??
      'your_stripe_publishable_key_here';
  static String get stripeSecretKey =>
      dotenv.env['STRIPE_SECRET_KEY'] ?? 'your_stripe_secret_key_here';

  // إعدادات Firebase Cloud Messaging
  static String get fcmServerKey =>
      dotenv.env['FCM_SERVER_KEY'] ?? 'your_fcm_server_key_here';

  // إعدادات التطبيق
  static String get appName => dotenv.env['APP_NAME'] ?? 'سوق التل';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static String get apiUrl => dotenv.env['API_URL'] ?? 'your_api_url_here';
  static int get apiTimeout =>
      int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30;

  // حالات البيئة
  static bool get isDevelopment => appEnv == 'development';
  static bool get isProduction => appEnv == 'production';
  static bool get isStaging => appEnv == 'staging';
}

class AppConfig {
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
  static const bool enableLogging = isDebug;
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;

  // Feature Flags
  static const bool enableSocialLogin = true;
  static const bool enablePushNotifications = true;
  static const bool enableLocationServices = true;
  static const bool enableMultipleLanguages = true;
  static const bool enableDarkMode = true;
}
