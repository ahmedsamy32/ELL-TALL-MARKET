import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';

/// 🛡️ معالج أخطاء الطلبات الموحد
/// يوفر معالجة متسقة للأخطاء مع رسائل مفهومة للمستخدم
class OrderErrorHandler {
  // ===== الحصول على رسالة خطأ مفهومة للمستخدم =====
  static String getUserFriendlyMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'يأخذ التحميل وقتاً أطول من المعتاد. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
    }

    if (error is PostgrestException) {
      return _handlePostgrestError(error);
    }

    if (error is AuthException) {
      return _handleAuthError(error);
    }

    final errorString = error.toString().toLowerCase();

    if (_isNetworkError(errorString)) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
    }

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }

    if (errorString.contains('not found')) {
      return 'لم يتم العثور على الطلب المطلوب.';
    }

    if (errorString.contains('already exists') ||
        errorString.contains('duplicate')) {
      return 'هذا الطلب موجود بالفعل.';
    }

    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
  }

  // ===== معالجة أخطاء Supabase =====
  static String _handlePostgrestError(PostgrestException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    // أخطاء الصلاحيات
    if (code == '42501' || message.contains('permission')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء على الطلب.';
    }

    // أخطاء عدم وجود البيانات
    if (code == 'PGRST116' || message.contains('no rows')) {
      return 'لم يتم العثور على الطلب المطلوب.';
    }

    // أخطاء التكرار
    if (code == '23505' || message.contains('duplicate')) {
      return 'هذا الطلب موجود بالفعل.';
    }

    // أخطاء المفاتيح الخارجية
    if (code == '23503' || message.contains('foreign key')) {
      return 'خطأ في البيانات المرتبطة. تحقق من صحة المعلومات.';
    }

    // أخطاء القيود
    if (code == '23514' || message.contains('check constraint')) {
      return 'البيانات المدخلة غير صالحة.';
    }

    // أخطاء نوع البيانات
    if (code == '22P02' || message.contains('invalid input')) {
      return 'تنسيق البيانات غير صحيح.';
    }

    AppLogger.error('PostgrestException غير معالج', error);
    return 'خطأ في قاعدة البيانات: ${error.message}';
  }

  // ===== معالجة أخطاء المصادقة =====
  static String _handleAuthError(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('session expired') ||
        message.contains('jwt expired')) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً.';
    }

    if (message.contains('not authenticated')) {
      return 'يرجى تسجيل الدخول للمتابعة.';
    }

    return 'خطأ في المصادقة. يرجى تسجيل الدخول مجدداً.';
  }

  // ===== فحص أخطاء الشبكة =====
  static bool _isNetworkError(String errorString) {
    return errorString.contains('socketexception') ||
        errorString.contains('networkexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection refused') ||
        errorString.contains('no internet') ||
        errorString.contains('network is unreachable');
  }

  // ===== هل الخطأ قابل لإعادة المحاولة؟ =====
  static bool isRetryable(dynamic error) {
    if (error is TimeoutException) return true;

    final errorString = error.toString().toLowerCase();
    if (_isNetworkError(errorString)) return true;

    // أخطاء Supabase المؤقتة
    if (error is PostgrestException) {
      final code = error.code;
      // أخطاء الخادم المؤقتة
      if (code?.startsWith('5') == true) return true;
      // أخطاء القفل
      if (code == '40001' || code == '40P01') return true;
    }

    return false;
  }

  // ===== رسالة خطأ لحالة معينة =====
  static String getStatusUpdateError(String targetStatus, dynamic error) {
    final baseMessage = getUserFriendlyMessage(error);

    final statusName = _getStatusArabicName(targetStatus);
    return 'فشل تحديث الطلب إلى "$statusName": $baseMessage';
  }

  static String _getStatusArabicName(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'جاهز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'in_transit':
        return 'في الطريق';
      case 'delivered':
        return 'تم التوصيل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  // ===== تسجيل الخطأ مع السياق =====
  static void logError(
    String operation,
    dynamic error, {
    String? orderId,
    Map<String, dynamic>? context,
  }) {
    final contextInfo = <String, dynamic>{
      'operation': operation,
      if (orderId != null) 'orderId': orderId,
      if (context != null) ...context,
    };

    AppLogger.error('❌ خطأ في عملية الطلب: $contextInfo', error);
  }
}

/// نتيجة عملية الطلب مع معالجة الأخطاء
class OrderResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final bool isRetryable;

  const OrderResult._({
    this.data,
    this.error,
    required this.isSuccess,
    this.isRetryable = false,
  });

  factory OrderResult.success(T data) {
    return OrderResult._(data: data, isSuccess: true);
  }

  factory OrderResult.failure(dynamic error) {
    return OrderResult._(
      error: OrderErrorHandler.getUserFriendlyMessage(error),
      isSuccess: false,
      isRetryable: OrderErrorHandler.isRetryable(error),
    );
  }

  /// تنفيذ عملية بناءً على النتيجة
  R when<R>({
    required R Function(T data) success,
    required R Function(String error, bool isRetryable) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    }
    return failure(error ?? 'خطأ غير معروف', isRetryable);
  }
}
