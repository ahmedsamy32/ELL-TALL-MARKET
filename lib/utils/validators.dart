class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صالح';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير على الأقل';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'كلمة المرور يجب أن تحتوي على رقم على الأقل';
    }

    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'تأكيد كلمة المرور مطلوب';
    }

    if (value != password) {
      return 'كلمة المرور غير متطابقة';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'الاسم مطلوب';
    }

    if (value.length < 2) {
      return 'الاسم يجب أن يكون حرفين على الأقل';
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }

    final phoneRegex = RegExp(r'^05[0-9]{8}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'رقم الهاتف غير صالح';
    }

    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName مطلوب';
    }

    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'السعر مطلوب';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'السعر يجب أن يكون رقمًا';
    }

    if (price <= 0) {
      return 'السعر يجب أن يكون أكبر من الصفر';
    }

    return null;
  }

  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'الكمية مطلوبة';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'الكمية يجب أن تكون رقمًا';
    }

    if (quantity <= 0) {
      return 'الكمية يجب أن تكون أكبر من الصفر';
    }

    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'العنوان مطلوب';
    }

    if (value.length < 10) {
      return 'العنوان يجب أن يكون 10 أحرف على الأقل';
    }

    return null;
  }

  static String? validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'المدينة مطلوبة';
    }

    return null;
  }

  static String? validateCreditCard(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم البطاقة مطلوب';
    }

    // Remove spaces and dashes
    final cleanedValue = value.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanedValue.length != 16) {
      return 'رقم البطاقة يجب أن يكون 16 رقمًا';
    }

    if (!RegExp(r'^[0-9]{16}$').hasMatch(cleanedValue)) {
      return 'رقم البطاقة غير صالح';
    }

    return null;
  }

  static String? validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'تاريخ الانتهاء مطلوب';
    }

    final expiryRegex = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$');
    if (!expiryRegex.hasMatch(value)) {
      return 'التاريخ غير صالح (MM/YY)';
    }

    final parts = value.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse('20${parts[1]}');

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return 'البطاقة منتهية الصلاحية';
    }

    return null;
  }

  static String? validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV مطلوب';
    }

    if (value.length != 3 && value.length != 4) {
      return 'CVV يجب أن يكون 3 أو 4 أرقام';
    }

    if (!RegExp(r'^[0-9]{3,4}$').hasMatch(value)) {
      return 'CVV غير صالح';
    }

    return null;
  }

  static String? validateCouponCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'كود الكوبون مطلوب';
    }

    if (value.length < 4) {
      return 'كود الكوبون يجب أن يكون 4 أحرف على الأقل';
    }

    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'الوصف مطلوب';
    }

    if (value.length < 10) {
      return 'الوصف يجب أن يكون 10 أحرف على الأقل';
    }

    return null;
  }

  static String? validateRating(double? value) {
    if (value == null) {
      return 'التقييم مطلوب';
    }

    if (value < 1 || value > 5) {
      return 'التقييم يجب أن يكون بين 1 و 5';
    }

    return null;
  }

  // دالة للتحقق من صحة الرقم السعودي
  static String? validateSaudiPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }

    final saudiPhoneRegex = RegExp(r'^(009665|9665|\+9665|05|5)(5|0|3|6|4|9|1|8|7)([0-9]{7})$');

    if (!saudiPhoneRegex.hasMatch(value)) {
      return 'رقم الهاتف السعودي غير صالح';
    }

    return null;
  }

  // دالة للتحقق من صحة الرقم القومي (السعودي)
  static String? validateNationalId(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرقم القومي مطلوب';
    }

    if (value.length != 14) {
      return 'الرقم القومي يجب أن يكون 14 أرقام';
    }

    if (!RegExp(r'^[0-9]{14}$').hasMatch(value)) {
      return 'الرقم القومي غير صالح';
    }

    return null;
  }

  // دالة للتحقق من صحة التاريخ
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'التاريخ مطلوب';
    }

    final dateRegex = RegExp(r'^([0-9]{4})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$');

    if (!dateRegex.hasMatch(value)) {
      return 'التاريخ غير صالح (YYYY-MM-DD)';
    }

    return null;
  }

  // دالة للتحقق من صحة الوقت
  static String? validateTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'الوقت مطلوب';
    }

    final timeRegex = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$');

    if (!timeRegex.hasMatch(value)) {
      return 'الوقت غير صالح (HH:MM)';
    }

    return null;
  }

  // دالة للتحقق من صحة الرمز البريدي
  static String? validatePostalCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرمز البريدي مطلوب';
    }

    if (value.length != 5) {
      return 'الرمز البريدي يجب أن يكون 5 أرقام';
    }

    if (!RegExp(r'^[0-9]{5}$').hasMatch(value)) {
      return 'الرمز البريدي غير صالح';
    }

    return null;
  }

  // دالة للتحقق من صحة الموقع الجغرافي
  static String? validateCoordinates(String? value) {
    if (value == null || value.isEmpty) {
      return 'الإحداثيات مطلوبة';
    }

    final coordRegex = RegExp(r'^-?([0-9]{1,2}|1[0-7][0-9]|180)(\.[0-9]{1,6})?$');

    if (!coordRegex.hasMatch(value)) {
      return 'الإحداثيات غير صالحة';
    }

    final coord = double.tryParse(value);
    if (coord == null) {
      return 'الإحداثيات غير صالحة';
    }

    if (coord < -180 || coord > 180) {
      return 'الإحداثيات يجب أن تكون بين -180 و 180';
    }

    return null;
  }
}
