# إعداد Google Maps API Key

## ⚠️ **مطلوب: إضافة Google Maps API Key**

التطبيق يتعطل عند فتح صفحة العناوين بسبب عدم وجود Google Maps API Key.

---

## 📋 **الخطوات:**

### 1. **إنشاء Google Maps API Key**

#### أ. اذهب إلى Google Cloud Console:
```
https://console.cloud.google.com/
```

#### ب. إنشاء مشروع جديد أو اختيار مشروع موجود:
- اضغط على **Select a project** في الأعلى
- اختر مشروعك أو أنشئ مشروع جديد

#### ج. تفعيل APIs المطلوبة:
1. اذهب إلى **APIs & Services** > **Library**
2. ابحث عن وفعّل:
   - ✅ **Maps SDK for Android**
   - ✅ **Geocoding API** (لتحويل الإحداثيات لعناوين)
   - ✅ **Places API** (اختياري - للبحث عن الأماكن)

#### د. إنشاء API Key:
1. اذهب إلى **APIs & Services** > **Credentials**
2. اضغط **+ CREATE CREDENTIALS**
3. اختر **API Key**
4. انسخ الـ API Key

#### هـ. تقييد API Key (مهم للأمان):
1. اضغط على الـ API Key الذي أنشأته
2. في **Application restrictions**:
   - اختر **Android apps**
   - اضغط **+ Add an item**
   - Package name: `com.example.ell_tall_market`
   - SHA-1: (احصل عليه من الخطوة التالية)
3. في **API restrictions**:
   - اختر **Restrict key**
   - حدد:
     - Maps SDK for Android
     - Geocoding API
     - Places API (إذا فعلته)
4. اضغط **Save**

---

### 2. **الحصول على SHA-1 Certificate Fingerprint**

افتح Terminal في مجلد المشروع وشغل:

#### Windows (PowerShell):
```powershell
cd android
./gradlew signingReport
```

#### أو:
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

ستحصل على شيء مثل:
```
SHA1: 5E:8F:16:06:2E:A3:CD:2C:4A:0D:54:78:76:BA:A6:F3:8C:AB:F6:25
```

انسخ الـ SHA-1 وأضفه في Google Cloud Console.

---

### 3. **إضافة API Key للتطبيق**

#### أ. Android:
افتح:
```
android/app/src/main/AndroidManifest.xml
```

**✅ تم إضافة السطر بالفعل**، فقط استبدل:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

بـ:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSy..."/>  <!-- ضع API Key هنا -->
```

#### ب. iOS (إذا أردت):
افتح:
```
ios/Runner/AppDelegate.swift
```

أضف في بداية الملف:
```swift
import GoogleMaps

// في دالة application
GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

---

### 4. **إعادة تشغيل التطبيق**

```powershell
flutter clean
flutter pub get
flutter run
```

---

## 🎯 **بعد التطبيق:**

✅ الخريطة ستظهر في صفحة العناوين
✅ يمكنك تحديد الموقع الحالي
✅ يمكنك النقر على الخريطة لاختيار موقع
✅ تحويل الإحداثيات لعنوان فعلي (Geocoding)

---

## 💡 **ملاحظات مهمة:**

### **1. Billing في Google Cloud**
Google Maps يتطلب تفعيل Billing (حتى لو كانت خطة مجانية).
- اذهب إلى **Billing** في Google Cloud Console
- أضف بطاقة (لن تُحاسب إلا بعد تجاوز الحد المجاني)
- الحد المجاني السخي جداً: **$200 شهرياً**

### **2. Quota & Limits**
- **Maps SDK for Android**: 28,000 مرة تحميل خريطة مجاناً شهرياً
- **Geocoding API**: 40,000 طلب مجاناً شهرياً

### **3. الأمان**
- ⚠️ **لا تشارك API Key علناً** في GitHub
- ✅ استخدم **Application restrictions** و **API restrictions**
- ✅ راقب الاستخدام من **APIs & Services** > **Dashboard**

---

## 🔧 **إذا واجهت مشاكل:**

### **الخريطة لا تظهر (شاشة رمادية):**
- تأكد من API Key صحيح
- تأكد من تفعيل **Maps SDK for Android**
- تأكد من SHA-1 صحيح
- انتظر 5-10 دقائق بعد إضافة API Key (وقت التفعيل)

### **"API key not found" أو "API key is invalid":**
- تأكد من إضافة `<meta-data>` في `AndroidManifest.xml`
- تأكد من عدم وجود مسافات زائدة في API Key
- جرب `flutter clean` ثم `flutter run`

### **"This API project is not authorized":**
- أضف SHA-1 في Google Cloud Console
- تأكد من Package Name صحيح: `com.example.ell_tall_market`

---

## 📚 **روابط مفيدة:**

- Google Cloud Console: https://console.cloud.google.com/
- Maps SDK for Android: https://developers.google.com/maps/documentation/android-sdk
- Geocoding API: https://developers.google.com/maps/documentation/geocoding
- Flutter Google Maps Plugin: https://pub.dev/packages/google_maps_flutter

---

**بعد إضافة API Key، التطبيق سيعمل بشكل طبيعي! 🗺️✨**
