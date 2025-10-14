import 'package:flutter/foundation.dart';

/// 🚀 إعدادات Production Mode
class ProductionConfig {
  /// تحقق من أن التطبيق يعمل في وضع production
  static bool get isProduction => kReleaseMode;

  /// تحقق من أن التطبيق يعمل في وضع debug
  static bool get isDebug => kDebugMode;

  /// تحقق من أن التطبيق يعمل في وضع profile
  static bool get isProfile => kProfileMode;

  /// هل يجب تشغيل schema checks
  static bool get shouldRunSchemaChecks => isDebug;

  /// هل يجب عرض debug logs
  static bool get shouldShowDebugLogs => isDebug;

  /// هل يجب استخدام SSL verification صارم
  static bool get shouldUseStrictSSL => isProduction;

  /// مدة timeout للـ connection في production
  static Duration get connectionTimeout =>
      isProduction ? const Duration(seconds: 30) : const Duration(seconds: 10);

  /// عدد محاولات إعادة الاتصال في production
  static int get maxRetryAttempts => isProduction ? 3 : 1;

  /// هل يجب عرض error details للمستخدم
  static bool get shouldShowErrorDetails => !isProduction;

  /// رسالة خطأ للمستخدم في production
  static String get userFriendlyErrorMessage =>
      'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';

  /// هل يجب تسجيل crash reports
  static bool get shouldLogCrashReports => isProduction;
}
