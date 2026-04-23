# نظام إدارة الأذونات للصور والملفات

## نظرة عامة
تم إضافة نظام متكامل للتحقق من أذونات الوصول للصور والملفات قبل استخدام `ImagePicker` و `FilePicker`.

## التغييرات المنفذة

### 1. إنشاء خدمة مركزية للأذونات
**الملف:** `lib/services/permission_service.dart`

خدمة شاملة تتعامل مع:
- ✅ أذونات الكاميرا
- ✅ أذونات المعرض (الصور)
- ✅ أذونات التخزين (الملفات)
- ✅ دعم Android 13+ (API 33+) مع `READ_MEDIA_IMAGES`
- ✅ دعم Android 12 وأقل مع `READ_EXTERNAL_STORAGE`
- ✅ دعم iOS مع `photos`
- ✅ دعم Web بدون أذونات

### 2. تحديث المكتبات
**الملف:** `pubspec.yaml`

```yaml
dependencies:
  device_info_plus: ^12.3.0  # للتحقق من إصدار Android
  permission_handler: ^11.3.1  # موجودة مسبقاً
```

### 3. الملفات المحدثة

#### شاشات المستخدم
- ✅ `lib/screens/user/edit_profile_screen.dart`
  - إضافة التحقق من الأذونات قبل اختيار صورة الملف الشخصي
  - إضافة dialog للأذونات المرفوضة نهائياً

#### شاشات التاجر
- ✅ `lib/screens/merchant/add_edit_product_screen.dart`
  - التحقق من الأذونات عند إضافة صور المنتجات
  - دعم الكاميرا والمعرض
  
- ✅ `lib/screens/merchant/merchant_settings_screen.dart`
  - التحقق من أذونات المعرض لصور المتجر

- ✅ `lib/screens/merchant/import_products_screen.dart`
  - التحقق من أذونات التخزين لملفات Excel

#### شاشات الإدارة
- ✅ `lib/screens/admin/manage_banners_screen.dart`
  - التحقق من الأذونات لصور البنرات الإعلانية

- ✅ `lib/screens/admin/manage_captains_screen.dart`
  - التحقق من الأذونات لصور الكباتن

## كيفية الاستخدام

### مثال 1: طلب إذن الكاميرا
```dart
final permissionService = PermissionService();
final result = await permissionService.requestCameraPermission();

if (result.granted) {
  // استخدام الكاميرا
} else if (result.permanentlyDenied) {
  // عرض dialog لفتح الإعدادات
  showPermissionDialog(result.message);
}
```

### مثال 2: طلب إذن المعرض
```dart
final permissionService = PermissionService();
final result = await permissionService.requestGalleryPermission();

if (result.granted) {
  // اختيار صورة من المعرض
}
```

### مثال 3: طلب الأذونات معاً
```dart
final permissionService = PermissionService();
final result = await permissionService.requestImagePermissions(
  useCamera: true,
  useGallery: true,
);

if (result.granted) {
  // يمكن استخدام الكاميرا والمعرض
}
```

## الأذونات في AndroidManifest.xml

الأذونات التالية موجودة مسبقاً في `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- الكاميرا -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- التخزين - Android 12 وأقل -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="32" />

<!-- الصور - Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

## الأذونات في Info.plist (iOS)

الأذونات التالية موجودة في `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>نحتاج للوصول للكاميرا لالتقاط صور المنتجات والملف الشخصي.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>نحتاج للوصول لمكتبة الصور لاختيار صور المنتجات والملف الشخصي.</string>
```

## الميزات الرئيسية

### 1. التوافق مع إصدارات Android المختلفة
- **Android 13+ (API 33+):** استخدام `READ_MEDIA_IMAGES`
- **Android 12 وأقل:** استخدام `READ_EXTERNAL_STORAGE`

### 2. معالجة الأذونات المرفوضة
- **رفض مؤقت:** عرض رسالة وإعادة الطلب
- **رفض دائم:** عرض dialog مع زر لفتح إعدادات التطبيق

### 3. دعم المنصات المختلفة
- ✅ Android (مع دعم إصدارات مختلفة)
- ✅ iOS
- ✅ Web (بدون أذونات)

## التحسينات المستقبلية

1. إضافة إذن الميكروفون للفيديوهات
2. إضافة إذن التخزين للوسائط الأخرى (فيديو، مستندات)
3. إضافة تتبع لحالة الأذونات في Analytics
4. إضافة اختبارات وحدة للـ PermissionService

## الاختبار

للتأكد من عمل النظام بشكل صحيح:

1. **Android:**
   - اختبر على Android 13+ وAndroid 12
   - ارفض الإذن أولاً ثم اقبله
   - ارفض الإذن بشكل دائم وتحقق من dialog

2. **iOS:**
   - اختبر على iOS 14+
   - تحقق من ظهور رسائل الأذونات الصحيحة

3. **Web:**
   - تأكد من عمل اختيار الصور بدون طلب أذونات

## ملاحظات مهمة

⚠️ **مهم:** يجب دائماً التحقق من الأذونات قبل استخدام `ImagePicker` أو `FilePicker`

✅ **تم التنفيذ:** جميع الملفات التي تستخدم `ImagePicker` و `FilePicker` تم تحديثها

📱 **الأذونات المطلوبة:** الكاميرا، المعرض، التخزين (Android فقط)
