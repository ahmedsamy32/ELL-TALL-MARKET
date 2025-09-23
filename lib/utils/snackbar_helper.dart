import 'package:flutter/material.dart';

/// مساعد عرض رسائل SnackBar محسنة
class SnackBarHelper {
  /// عرض رسالة نجاح
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  /// عرض رسالة خطأ
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: duration ?? const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  /// عرض رسالة تحذير
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  /// عرض رسالة معلومات
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  /// عرض رسالة تحميل
  static void showLoading(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[700],
        duration: duration ?? const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// التحقق من صحة البريد الإلكتروني مع SnackBar
  static bool validateEmail(BuildContext context, String email) {
    if (email.isEmpty) {
      showError(context, '📧 يرجى إدخال البريد الإلكتروني');
      return false;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      showError(context, '📧 صيغة البريد الإلكتروني غير صحيحة');
      return false;
    }
    return true;
  }

  /// التحقق من كلمة المرور مع SnackBar
  static bool validatePassword(BuildContext context, String password) {
    if (password.isEmpty) {
      showError(context, '🔒 يرجى إدخال كلمة المرور');
      return false;
    }
    if (password.length < 6) {
      showError(context, '🔒 كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return false;
    }
    return true;
  }

  /// التحقق من تطابق كلمات المرور
  static bool validatePasswordConfirmation(
    BuildContext context,
    String password,
    String confirmPassword,
  ) {
    if (confirmPassword.isEmpty) {
      showError(context, '🔒 يرجى تأكيد كلمة المرور');
      return false;
    }
    if (password != confirmPassword) {
      showError(context, '🔒 كلمات المرور غير متطابقة');
      return false;
    }
    return true;
  }

  /// التحقق من الاسم مع SnackBar
  static bool validateName(BuildContext context, String name) {
    if (name.isEmpty) {
      showError(context, '👤 يرجى إدخال الاسم');
      return false;
    }
    if (name.length < 2) {
      showError(context, '👤 الاسم يجب أن يكون حرفين على الأقل');
      return false;
    }
    return true;
  }

  /// التحقق من رقم الهاتف مع SnackBar
  static bool validatePhone(BuildContext context, String phone) {
    if (phone.isEmpty) {
      showError(context, '📱 يرجى إدخال رقم الهاتف');
      return false;
    }
    if (!RegExp(
      r'^[0-9]{10,15}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''))) {
      showError(context, '📱 رقم الهاتف غير صحيح');
      return false;
    }
    return true;
  }

  /// معالجة أخطاء Firebase مع رسائل مخصصة
  static void handleFirebaseError(
    BuildContext context,
    String errorCode,
    String? errorMessage,
  ) {
    String message;
    SnackBarAction? action;

    switch (errorCode) {
      case 'user-not-found':
        message = '👤 البريد الإلكتروني غير مسجل في النظام';
        action = SnackBarAction(
          label: 'إنشاء حساب',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/register'),
        );
        break;

      case 'wrong-password':
      case 'invalid-credential':
        message = '🔒 البريد الإلكتروني أو كلمة المرور غير صحيحة';
        action = SnackBarAction(
          label: 'نسيت كلمة المرور؟',
          textColor: Colors.white,
          onPressed: () {
            // يمكن إضافة منطق نسيان كلمة المرور هنا
          },
        );
        break;

      case 'invalid-email':
        message = '📧 صيغة البريد الإلكتروني غير صحيحة';
        break;

      case 'user-disabled':
        message = '🚫 هذا الحساب معطل. يرجى التواصل مع الدعم الفني';
        break;

      case 'too-many-requests':
        message = '⏰ عدد كبير من المحاولات الفاشلة. يرجى المحاولة بعد قليل';
        break;

      case 'email-already-in-use':
        message = '📧 البريد الإلكتروني مستخدم مسبقاً';
        action = SnackBarAction(
          label: 'تسجيل دخول',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/login'),
        );
        break;

      case 'weak-password':
        message = '🔒 كلمة المرور ضعيفة جداً';
        break;

      case 'operation-not-allowed':
        message = '🚫 هذه العملية غير مسموحة حالياً';
        break;

      case 'network-request-failed':
        message = '🌐 مشكلة في الاتصال بالإنترنت';
        action = SnackBarAction(
          label: 'إعادة المحاولة',
          textColor: Colors.white,
          onPressed: () {
            // يمكن إضافة منطق إعادة المحاولة هنا
          },
        );
        break;

      default:
        message = errorMessage ?? '❌ حدث خطأ غير متوقع';
    }

    showError(context, message, action: action);
  }
}
