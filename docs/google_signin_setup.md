# Google Sign-In مع Supabase - دليل التكوين

## ✅ المتطلبات المُكتملة:

### 1. **Android Configuration** - ✅ مُحدثة:
- ✅ `google-services.json` موجود في `android/app/`
- ✅ Deep Links مُعدة في `AndroidManifest.xml`
- ✅ Google Sign-In dependency: `google_sign_in: ^7.2.0`

### 2. **Flutter Dependencies** - ✅ مُحدثة:
```yaml
dependencies:
  supabase_flutter: ^2.8.0
  google_sign_in: ^7.2.0
```

### 3. **Supabase Project Configuration** - ✅ مُحدثة:
- URL: `https://ebbkdhmwaawzxbidjynz.supabase.co`
- Anon Key: محدث في firebase_options.dart

## 🔧 خطوات التكوين الإضافية:

### 1. **Supabase Dashboard - Google OAuth:**
1. اذهب إلى Supabase Dashboard → Authentication → Settings
2. في قسم "Auth Providers"، فعّل Google
3. أضف Google OAuth credentials:
   ```
   Android Client ID: 941471556278-g0d409tmu6qv6oskauhkgbu04ko9faci.apps.googleusercontent.com
   Client Secret: [احصل عليه من Google Cloud Console]
   ```

### 2. **Google Cloud Console:**
1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
2. اختر مشروع `ell-tall-market`
3. في "APIs & Services" → "Credentials"
4. تأكد من إضافة Redirect URIs:
   ```
   https://ebbkdhmwaawzxbidjynz.supabase.co/auth/v1/callback
   ```

### 3. **iOS Configuration** - ⚠️ مطلوب:
**مفقود:** ملف `GoogleService-Info.plist`

**الخطوات:**
1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروع `ell-tall-market`
3. في "Project Settings" → "General"
4. في قسم iOS apps، حمّل `GoogleService-Info.plist`
5. ضع الملف في `ios/Runner/GoogleService-Info.plist`

## 📋 كيفية الاستخدام:

### 1. **تسجيل الدخول:**
```dart
import '../services/google_signin_supabase_service.dart';

// تسجيل دخول
final response = await GoogleSignInService.instance.signInWithGoogle();

if (response?.user != null) {
  print('نجح تسجيل الدخول: ${response!.user!.email}');
}
```

### 2. **استخدام الزر الجاهز:**
```dart
import '../widgets/google_signin_button.dart';

GoogleSignInButton(
  onSuccess: () {
    Navigator.pushReplacementNamed(context, '/home');
  },
  onError: (error) {
    print('خطأ: $error');
  },
)
```

### 3. **تسجيل الخروج:**
```dart
await GoogleSignInService.instance.signOut();
```

### 4. **التحقق من حالة المصادقة:**
```dart
// التحقق البسيط
bool isSignedIn = GoogleSignInService.instance.isSignedIn;

// معلومات المستخدم
Map<String, dynamic>? userInfo = GoogleSignInService.instance.userDisplayInfo;
```

## 🔍 استكشاف الأخطاء:

### المشاكل الشائعة:
1. **"Client ID not found"**
   - تأكد من وجود `google-services.json`
   - تأكد من صحة package name في Firebase

2. **"Invalid redirect URI"**
   - تأكد من إضافة Supabase callback URL في Google Console

3. **"Authentication failed"**
   - تحقق من logs في Supabase Dashboard
   - تأكد من تفعيل Google provider في Supabase

## 📱 اختبار التكامل:

### Android:
```bash
flutter run -d android
```

### iOS (بعد إضافة GoogleService-Info.plist):
```bash
flutter run -d ios
```

## 🚀 الميزات المتاحة:

- ✅ تسجيل دخول/خروج سلس
- ✅ إنشاء/تحديث profiles تلقائياً
- ✅ Deep Links للمصادقة
- ✅ معالجة أخطاء شاملة
- ✅ UI components جاهزة للاستخدام
- ✅ حالة Loading والتحكم بالحالة

---

**جميع التعريفات والخدمات جاهزة للاستخدام! 🎉**

**المطلوب فقط:** إضافة `GoogleService-Info.plist` للـ iOS وتكوين Google OAuth في Supabase Dashboard.