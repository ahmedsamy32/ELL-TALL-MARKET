class Validators {
  // التحقق من البريد الإلكتروني مع معايير أكثر دقة
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }

    // إزالة المسافات من البداية والنهاية
    value = value.trim();

    // التحقق من طول البريد الإلكتروني
    if (value.length > 254) {
      return 'البريد الإلكتروني طويل جداً';
    }

    // تحسين regex للبريد الإلكتروني
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صالح';
    }

    // التحقق من النقاط المتتالية
    if (value.contains('..')) {
      return 'البريد الإلكتروني غير صالح (نقاط متتالية)';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    if (value.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }

    if (value.length > 50) {
      return 'كلمة المرور يجب ألا تزيد عن 50 حرف';
    }

    // التحقق من وجود حرف كبير
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
    }

    // التحقق من وجود حرف صغير
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل';
    }

    // التحقق من وجود رقم
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
    }

    // التحقق من وجود رمز خاص
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على رمز خاص واحد على الأقل (!@#\$%^&*)';
    }

    // التحقق من عدم وجود مسافات
    if (value.contains(' ')) {
      return 'كلمة المرور يجب ألا تحتوي على مسافات';
    }

    return null;
  }

  // دالة لحساب قوة كلمة المرور (0-100)
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // نقاط للطول
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;

    // نقاط للأحرف الكبيرة
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;

    // نقاط للأحرف الصغيرة
    if (RegExp(r'[a-z]').hasMatch(password)) score += 15;

    // نقاط للأرقام
    if (RegExp(r'[0-9]').hasMatch(password)) score += 15;

    // نقاط للرموز الخاصة
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 15;

    return score > 100 ? 100 : score;
  }

  // دالة للحصول على نص قوة كلمة المرور
  static String getPasswordStrengthText(String password) {
    int strength = getPasswordStrength(password);

    if (strength < 40) return 'ضعيفة جداً';
    if (strength < 60) return 'ضعيفة';
    if (strength < 80) return 'متوسطة';
    if (strength < 90) return 'قوية';
    return 'قوية جداً';
  }

  // دالة للحصول على لون قوة كلمة المرور
  static String getPasswordStrengthColor(String password) {
    int strength = getPasswordStrength(password);

    if (strength < 40) return '#F44336'; // أحمر
    if (strength < 60) return '#FF9800'; // برتقالي
    if (strength < 80) return '#FFC107'; // أصفر
    if (strength < 90) return '#4CAF50'; // أخضر
    return '#2E7D32'; // أخضر داكن
  }

  // دالة للحصول على نصائح تحسين كلمة المرور
  static List<String> getPasswordImprovementTips(String password) {
    List<String> tips = [];

    if (password.length < 8) {
      tips.add('استخدم 8 أحرف على الأقل');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      tips.add('أضف حرف كبير واحد على الأقل (A-Z)');
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      tips.add('أضف حرف صغير واحد على الأقل (a-z)');
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      tips.add('أضف رقم واحد على الأقل (0-9)');
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      tips.add('أضف رمز خاص واحد على الأقل (!@#\$%^&*)');
    }

    if (password.contains(' ')) {
      tips.add('تجنب استخدام المسافات');
    }

    if (password.length < 12) {
      tips.add('استخدم 12 حرف أو أكثر لأمان أفضل');
    }

    return tips;
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

  // التحقق من الاسم مع معايير محسنة
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'الاسم مطلوب';
    }

    // إزالة المسافات الزائدة
    value = value.trim();

    if (value.length < 2) {
      return 'الاسم يجب أن يكون حرفين على الأقل';
    }

    if (value.length > 50) {
      return 'الاسم يجب ألا يزيد عن 50 حرف';
    }

    // التحقق من وجود أحرف صالحة فقط (عربي وإنجليزي ومسافات)
    final nameRegex = RegExp(r'^[a-zA-Zأ-ي\u0600-\u06FF\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'الاسم يجب أن يحتوي على أحرف فقط';
    }

    // التحقق من عدم وجود مسافات متتالية
    if (value.contains('  ')) {
      return 'الاسم لا يجب أن يحتوي على مسافات متتالية';
    }

    // التحقق من عدم البداية أو الانتهاء بمسافة
    if (value.startsWith(' ') || value.endsWith(' ')) {
      return 'الاسم لا يجب أن يبدأ أو ينتهي بمسافة';
    }

    return null;
  }

  // التحقق من رقم الهاتف السعودي المحسن
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }

    // إزالة المسافات والرموز
    value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // التحقق من الأرقام السعودية المحلية والدولية
    final saudiPhoneRegex = RegExp(
      r'^(009665|9665|\+9665|05|5)(5|0|3|6|4|9|1|8|7)([0-9]{7})$',
    );

    if (saudiPhoneRegex.hasMatch(value)) {
      return null; // رقم سعودي صالح
    }

    // التحقق من الأرقام المصرية (إضافة للمرونة)
    final egyptianPhoneRegex = RegExp(r'^(0020|20|\+20|01|1)([0-9]{9})$');
    if (egyptianPhoneRegex.hasMatch(value)) {
      return null; // رقم مصري صالح
    }

    // للأرقام المحلية البسيطة
    if (value.length == 11 && value.startsWith('01')) {
      final localPhoneRegex = RegExp(r'^01[0-9]{9}$');
      if (localPhoneRegex.hasMatch(value)) {
        return null;
      }
    }

    return 'رقم الهاتف غير صالح (يرجى إدخال رقم سعودي أو مصري صالح)';
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

    final saudiPhoneRegex = RegExp(
      r'^(009665|9665|\+9665|05|5)(5|0|3|6|4|9|1|8|7)([0-9]{7})$',
    );

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

    final dateRegex = RegExp(
      r'^([0-9]{4})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$',
    );

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

    final coordRegex = RegExp(
      r'^-?([0-9]{1,2}|1[0-7][0-9]|180)(\.[0-9]{1,6})?$',
    );

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

  // ================= دوال التحقق الخاصة بالتطبيق =================

  // التحقق من اسم المنتج
  static String? validateProductName(String? value) {
    if (value == null || value.isEmpty) {
      return 'اسم المنتج مطلوب';
    }

    value = value.trim();

    if (value.length < 3) {
      return 'اسم المنتج يجب أن يكون 3 أحرف على الأقل';
    }

    if (value.length > 100) {
      return 'اسم المنتج يجب ألا يزيد عن 100 حرف';
    }

    // التحقق من الأحرف المسموحة
    final productNameRegex = RegExp(
      r'^[a-zA-Zأ-ي\u0600-\u06FF0-9\s\.\-\(\)]+$',
    );
    if (!productNameRegex.hasMatch(value)) {
      return 'اسم المنتج يحتوي على أحرف غير مسموحة';
    }

    return null;
  }

  // التحقق من وصف المنتج
  static String? validateProductDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'وصف المنتج مطلوب';
    }

    value = value.trim();

    if (value.length < 10) {
      return 'وصف المنتج يجب أن يكون 10 أحرف على الأقل';
    }

    if (value.length > 1000) {
      return 'وصف المنتج يجب ألا يزيد عن 1000 حرف';
    }

    return null;
  }

  // التحقق من سعر المنتج
  static String? validateProductPrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'سعر المنتج مطلوب';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'السعر يجب أن يكون رقمًا صحيحاً';
    }

    if (price <= 0) {
      return 'السعر يجب أن يكون أكبر من الصفر';
    }

    if (price > 1000000) {
      return 'السعر يجب ألا يزيد عن مليون ريال';
    }

    // التحقق من عدد الأرقام العشرية
    final decimalParts = value.split('.');
    if (decimalParts.length > 2) {
      return 'صيغة السعر غير صحيحة';
    }

    if (decimalParts.length == 2 && decimalParts[1].length > 2) {
      return 'السعر يجب ألا يحتوي على أكثر من رقمين عشريين';
    }

    return null;
  }

  // التحقق من كمية المنتج
  static String? validateProductQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'كمية المنتج مطلوبة';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'الكمية يجب أن تكون رقمًا صحيحاً';
    }

    if (quantity < 0) {
      return 'الكمية لا يمكن أن تكون سالبة';
    }

    if (quantity > 10000) {
      return 'الكمية يجب ألا تزيد عن 10,000 قطعة';
    }

    return null;
  }

  // التحقق من اسم المتجر
  static String? validateStoreName(String? value) {
    if (value == null || value.isEmpty) {
      return 'اسم المتجر مطلوب';
    }

    value = value.trim();

    if (value.length < 3) {
      return 'اسم المتجر يجب أن يكون 3 أحرف على الأقل';
    }

    if (value.length > 50) {
      return 'اسم المتجر يجب ألا يزيد عن 50 حرف';
    }

    // التحقق من الأحرف المسموحة
    final storeNameRegex = RegExp(r'^[a-zA-Zأ-ي\u0600-\u06FF0-9\s\.\-]+$');
    if (!storeNameRegex.hasMatch(value)) {
      return 'اسم المتجر يحتوي على أحرف غير مسموحة';
    }

    return null;
  }

  // التحقق من عنوان التوصيل
  static String? validateDeliveryAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'عنوان التوصيل مطلوب';
    }

    value = value.trim();

    if (value.length < 15) {
      return 'عنوان التوصيل يجب أن يكون 15 حرف على الأقل';
    }

    if (value.length > 200) {
      return 'عنوان التوصيل يجب ألا يزيد عن 200 حرف';
    }

    // التحقق من وجود معلومات أساسية في العنوان
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'يرجى إضافة رقم المنزل أو الشارع';
    }

    return null;
  }

  // التحقق من كود الخصم
  static String? validateDiscountCode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // كود الخصم اختياري
    }

    value = value.trim().toUpperCase();

    if (value.length < 3) {
      return 'كود الخصم يجب أن يكون 3 أحرف على الأقل';
    }

    if (value.length > 20) {
      return 'كود الخصم يجب ألا يزيد عن 20 حرف';
    }

    // التحقق من الأحرف والأرقام فقط
    final discountCodeRegex = RegExp(r'^[A-Z0-9]+$');
    if (!discountCodeRegex.hasMatch(value)) {
      return 'كود الخصم يجب أن يحتوي على أحرف وأرقام إنجليزية فقط';
    }

    return null;
  }

  // التحقق من تقييم المنتج/الخدمة
  static String? validateRatingComment(String? value) {
    if (value == null || value.isEmpty) {
      return null; // التعليق اختياري
    }

    value = value.trim();

    if (value.length < 5) {
      return 'التعليق يجب أن يكون 5 أحرف على الأقل';
    }

    if (value.length > 500) {
      return 'التعليق يجب ألا يزيد عن 500 حرف';
    }

    return null;
  }

  // التحقق من رقم بطاقة الهوية السعودية
  static String? validateSaudiID(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهوية مطلوب';
    }

    // إزالة المسافات
    value = value.replaceAll(' ', '');

    if (value.length != 10) {
      return 'رقم الهوية السعودية يجب أن يكون 10 أرقام';
    }

    if (!RegExp(r'^[12][0-9]{9}$').hasMatch(value)) {
      return 'رقم الهوية السعودية غير صالح';
    }

    // خوارزمية التحقق من صحة رقم الهوية السعودية
    List<int> digits = value.split('').map(int.parse).toList();

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      if (i % 2 == 0) {
        int doubled = digits[i] * 2;
        sum += doubled > 9 ? doubled - 9 : doubled;
      } else {
        sum += digits[i];
      }
    }

    int checkDigit = (10 - (sum % 10)) % 10;

    if (checkDigit != digits[9]) {
      return 'رقم الهوية السعودية غير صحيح';
    }

    return null;
  }

  // التحقق من IBAN السعودي
  static String? validateSaudiIBAN(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الآيبان مطلوب';
    }

    // إزالة المسافات والتحويل للأحرف الكبيرة
    value = value.replaceAll(' ', '').toUpperCase();

    if (!value.startsWith('SA')) {
      return 'رقم الآيبان يجب أن يبدأ بـ SA';
    }

    if (value.length != 24) {
      return 'رقم الآيبان السعودي يجب أن يكون 24 حرف';
    }

    final ibanRegex = RegExp(r'^SA[0-9]{22}$');
    if (!ibanRegex.hasMatch(value)) {
      return 'رقم الآيبان غير صالح';
    }

    return null;
  }

  // التحقق من رقم الرخصة التجارية
  static String? validateCommercialLicense(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم السجل التجاري مطلوب';
    }

    // إزالة المسافات
    value = value.replaceAll(' ', '');

    if (value.length != 10) {
      return 'رقم السجل التجاري يجب أن يكون 10 أرقام';
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
      return 'رقم السجل التجاري يجب أن يحتوي على أرقام فقط';
    }

    return null;
  }

  // ================= دوال مساعدة =================

  // تنظيف النص من المسافات الزائدة
  static String cleanText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // التحقق من قوة كلمة المرور مع إرجاع التفاصيل
  static Map<String, dynamic> getPasswordStrengthDetails(String password) {
    int score = getPasswordStrength(password);
    String text = getPasswordStrengthText(password);
    String color = getPasswordStrengthColor(password);
    List<String> tips = getPasswordImprovementTips(password);

    return {
      'score': score,
      'text': text,
      'color': color,
      'tips': tips,
      'isStrong': score >= 80,
    };
  }

  // التحقق من صحة رقم الهاتف مع إرجاع التفاصيل
  static Map<String, dynamic> getPhoneDetails(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    bool isSaudi = RegExp(
      r'^(009665|9665|\+9665|05|5)(5|0|3|6|4|9|1|8|7)([0-9]{7})$',
    ).hasMatch(phone);
    bool isEgyptian = RegExp(
      r'^(0020|20|\+20|01|1)([0-9]{9})$',
    ).hasMatch(phone);
    bool isLocal = phone.length == 11 && phone.startsWith('01');

    String country = '';
    if (isSaudi) {
      country = 'السعودية';
    } else if (isEgyptian)
      country = 'مصر';
    else if (isLocal)
      country = 'محلي';

    return {
      'isValid': isSaudi || isEgyptian || isLocal,
      'country': country,
      'formatted': _formatPhone(phone),
      'type': _getPhoneType(phone),
    };
  }

  // تنسيق رقم الهاتف
  static String _formatPhone(String phone) {
    if (phone.length == 11 && phone.startsWith('01')) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6, 8)} ${phone.substring(8)}';
    }
    if (phone.startsWith('05') && phone.length == 10) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}';
    }
    return phone;
  }

  // تحديد نوع الهاتف
  static String _getPhoneType(String phone) {
    if (phone.startsWith('010') ||
        phone.startsWith('011') ||
        phone.startsWith('012')) {
      return 'فودافون';
    }
    if (phone.startsWith('015')) {
      return 'اتصالات';
    }
    if (phone.startsWith('05')) {
      return 'جوال سعودي';
    }
    return 'غير محدد';
  }
}
