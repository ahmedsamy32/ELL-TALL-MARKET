import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get facebookClientId => dotenv.env['FACEBOOK_CLIENT_ID'] ?? '';
  static String get appName => dotenv.env['APP_NAME'] ?? 'التل ماركت';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static String get apiUrl => dotenv.env['API_URL'] ?? '';

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
