# دليل تطوير المصادقة الاجتماعية

## البدء السريع

### 1. استخدام المصادقة الاجتماعية
```dart
import 'package:ell_tall_market/services/social_auth_service.dart';

final socialAuth = SocialAuthService();

// تسجيل الدخول بجوجل
final googleResult = await socialAuth.signInWithGoogle();

// تسجيل الدخول بفيسبوك  
final facebookResult = await socialAuth.signInWithFacebook();

// تسجيل الخروج
await socialAuth.signOut();
```

### 2. معالجة الأخطاء
```dart
try {
  final result = await socialAuth.signInWithGoogle();
  if (result?.user != null) {
    // نجح تسجيل الدخول
    print('مرحباً ${result!.user!.email}');
  }
} catch (e) {
  // فشل تسجيل الدخول
  print('خطأ: $e');
}
```

### 3. إعداد خدمة مخصصة
```dart
import 'package:ell_tall_market/config/auth_config.dart';

// تخصيص الرسائل
print(AuthConfig.authMessages['signin_success']);

// استخدام الصلاحيات المحددة
final permissions = AuthConfig.facebookPermissions;
```

## هيكل الملفات

```
lib/
├── config/
│   └── auth_config.dart          # إعدادات المصادقة
├── services/
│   ├── social_auth_service.dart  # خدمة المصادقة الاجتماعية
│   ├── google_signin_service.dart # خدمة جوجل
│   └── auth_service.dart         # خدمة المصادقة الرئيسية
└── screens/auth/
    └── login_screen.dart         # شاشة تسجيل الدخول
```

## API المتاح

### SocialAuthService

#### Methods:
- `signInWithGoogle()` - تسجيل الدخول بجوجل
- `signInWithFacebook()` - تسجيل الدخول بفيسبوك  
- `signOut()` - تسجيل الخروج من جميع الخدمات

#### Private Methods:
- `_updateUserProfile()` - تحديث ملف المستخدم

### AuthConfig

#### Constants:
- `googleClientId` - معرف عميل جوجل
- `facebookPermissions` - صلاحيات فيسبوك
- `authMessages` - رسائل المصادقة
- `profileFields` - حقول الملف الشخصي

## نصائح التطوير

### 1. التشخيص والأخطاء
- تفعيل `AuthConfig.enableDebugLogs` في وضع التطوير
- مراقبة console logs للرسائل التشخيصية
- استخدام try-catch لمعالجة الأخطاء

### 2. اختبار المصادقة
```dart
// اختبار الاتصال
final user = Supabase.instance.client.auth.currentUser;
print('المستخدم الحالي: ${user?.email ?? 'غير متصل'}');

// اختبار تسجيل الخروج
await socialAuth.signOut();
assert(Supabase.instance.client.auth.currentUser == null);
```

### 3. التخصيص
```dart
// تخصيص رسائل الخطأ
const customMessages = {
  'signin_failed': 'فشل في التسجيل، حاول مرة أخرى',
  'network_error': 'تحقق من الاتصال',
};
```

## استكشاف الأخطاء

### مشاكل شائعة:

#### 1. فشل Google Sign-In
```
خطأ: PlatformException(sign_in_failed, ...)
```
**الحل**: التحقق من Google Client ID في auth_config.dart

#### 2. فشل Facebook Auth  
```
خطأ: LoginStatus.cancelled
```
**الحل**: المستخدم ألغى العملية، هذا سلوك طبيعي

#### 3. فشل Supabase Connection
```
خطأ: SocketException: Failed host lookup
```
**الحل**: التحقق من اتصال الإنترنت والإعدادات

### سجلات مفيدة:
- `🔄` - بدء العملية
- `✅` - نجاح العملية  
- `❌` - فشل العملية
- `⚠️` - تحذير

## الأمان

### أفضل الممارسات:
1. عدم تخزين access tokens في الذاكرة
2. استخدام HTTPS دائماً
3. التحقق من صحة البيانات المستلمة
4. تسجيل الخروج عند إنهاء الجلسة

### حماية البيانات:
```dart
// تشفير البيانات الحساسة
final encryptedData = await encrypt(userData);

// التحقق من صحة التوقيع
final isValid = await verifySignature(token);
```

---
**آخر تحديث**: ${DateTime.now().toString().split('.')[0]}
