class AdminDetectionConfig {
  // قائمة إيميلات الأدمن المسموحة
  static const List<String> adminEmails = [
    'admin@elltall.com',
    'admin@admin.com',
    'super@elltall.com',
    'root@elltall.com',
  ];

  // كلمات مرور خاصة للأدمن (اختيارية)
  static const List<String> adminPasswords = [
    'ADMIN_MASTER_2024',
    'SUPER_ADMIN_KEY',
  ];

  // دومينات مخصصة للأدمن
  static const List<String> adminDomains = [
    '@elltall.com',
    '@admin.elltall.com',
  ];

  // كود سري للأدمن (يُدخل أثناء التسجيل)
  static const String adminSecretCode = 'ADMIN_SECRET_2024';

  /// التحقق من كون المستخدم أدمن بالإيميل
  static bool isAdminByEmail(String email) {
    final emailLower = email.toLowerCase();

    // فحص قائمة الإيميلات المحددة
    if (adminEmails.contains(emailLower)) {
      return true;
    }

    // فحص الدومينات
    for (String domain in adminDomains) {
      if (emailLower.endsWith(domain.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// التحقق من كون كلمة المرور للأدمن
  static bool isAdminPassword(String password) {
    return adminPasswords.contains(password);
  }

  /// التحقق من الكود السري
  static bool isValidAdminCode(String code) {
    return code == adminSecretCode;
  }

  /// التحقق الشامل للأدمن
  static bool isAdmin({
    required String email,
    String? password,
    String? secretCode,
  }) {
    // الطريقة الأساسية: الإيميل
    if (isAdminByEmail(email)) {
      return true;
    }

    // طريقة إضافية: كلمة مرور خاصة
    if (password != null && isAdminPassword(password)) {
      return true;
    }

    // طريقة إضافية: كود سري
    if (secretCode != null && isValidAdminCode(secretCode)) {
      return true;
    }

    return false;
  }
}
