# نظام التحقق من نطاق التوصيل باستخدام PostGIS

## 📋 نظرة عامة

تم استبدال نظام التحقق القديم القائم على مقارنة أسماء المدن والمحافظات بنظام دقيق يعتمد على **PostGIS** لحساب المسافة الفعلية بين موقع المتجر وموقع العميل.

## ❌ المشكلة السابقة

### النظام القديم كان يعتمد على:
```dart
// مقارنة نصية بين المدن والمحافظات
String _normalizeText(String? text) {
  // تطبيع النص
  // قاموس تحويل الأسماء
  // المقارنة النصية
}
```

### عيوب النظام القديم:
1. ❌ **عدم دقة**: مقارنة الأسماء لا تعكس المسافة الحقيقية
2. ❌ **مشاكل اللغة**: اختلافات بين العربية والإنجليزية
3. ❌ **مشاكل التطبيع**: `الزقازيق` vs `al-Zagazig` vs `Zagazig`
4. ❌ **نتائج خاطئة**: رفض عناوين صحيحة في نفس المدينة
5. ❌ **صعوبة الصيانة**: قاموس تحويل ضخم يحتاج تحديث مستمر

### مثال على المشكلة:
```
متجر في: "الزقازيق، الشرقية"
عنوان العميل: "Zagazig, Eastern"
النتيجة: ❌ عنوانك خارج نطاق التوصيل (خطأ!)
```

## ✅ الحل الجديد: PostGIS

### النظام الجديد يعتمد على:
```dart
Future<List<String>> _getStoresOutOfRange(
  CartProvider cartProvider,
  AddressModel? address,
) async {
  // استخدام إحداثيات GPS (latitude, longitude)
  final deliveryCheck = await LocationService.canDeliverToLocation(
    storeId: storeId,
    latitude: address.latitude!,
    longitude: address.longitude!,
  );
  
  // PostGIS يحسب المسافة الفعلية بالكيلومترات
  final canDeliver = deliveryCheck['can_deliver'] as bool;
  final distance = deliveryCheck['distance_km'] as double;
}
```

### مزايا النظام الجديد:
1. ✅ **دقة عالية**: حساب المسافة الفعلية بالكيلومترات
2. ✅ **لا يعتمد على اللغة**: يستخدم إحداثيات GPS
3. ✅ **لا يحتاج تطبيع**: لا حاجة لقواميس التحويل
4. ✅ **نتائج دقيقة**: يقبل/يرفض بناءً على المسافة الحقيقية
5. ✅ **سهولة الصيانة**: لا حاجة لتحديث قواميس الأسماء

### مثال على الحل:
```
متجر في: lat=30.5833, lng=31.5000
عنوان العميل: lat=30.5900, lng=31.5100
PostGIS يحسب: المسافة = 0.95 كم
نطاق التوصيل: 5 كم
النتيجة: ✅ يمكن التوصيل
```

## 🔧 التغييرات التقنية

### 1. إزالة الكود القديم
```dart
// ❌ تم إزالة
String _normalizeText(String? text) { ... }

// ❌ تم إزالة القاموس الضخم
final Map<String, String> cityNormalizations = {
  'zagazig': 'زقازيق',
  'sharqia': 'شرقية',
  // ... 50+ سطر من التحويلات
};
```

### 2. الكود الجديد
```dart
// ✅ استخدام LocationService
Future<List<String>> _getStoresOutOfRange(
  CartProvider cartProvider,
  AddressModel? address,
) async {
  if (address == null || 
      address.latitude == null || 
      address.longitude == null) {
    return [];
  }

  for (var item in cartProvider.cartItems) {
    final deliveryCheck = await LocationService.canDeliverToLocation(
      storeId: storeId,
      latitude: address.latitude!,
      longitude: address.longitude!,
    );

    final canDeliver = deliveryCheck['can_deliver'] as bool? ?? false;
    final distance = deliveryCheck['distance_km'] as double? ?? 0.0;

    if (!canDeliver) {
      storesOutOfRange.add(storeName);
    }
  }

  return storesOutOfRange;
}
```

## 🗄️ قاعدة البيانات (PostGIS)

### الدوال المستخدمة

#### 1. `can_deliver_to_location`
```sql
CREATE OR REPLACE FUNCTION can_deliver_to_location(
  p_store_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS TABLE (
  can_deliver BOOLEAN,
  distance_km DOUBLE PRECISION
)
```

**الوظيفة:**
- تحسب المسافة بين المتجر والعنوان باستخدام PostGIS
- تقارن المسافة مع `delivery_radius_km` المحدد للمتجر
- تعيد `can_deliver: true` إذا كانت المسافة أقل من نطاق التوصيل

#### 2. `get_nearby_stores`
```sql
CREATE OR REPLACE FUNCTION get_nearby_stores(
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 10
)
RETURNS TABLE (
  store_id UUID,
  store_name TEXT,
  distance_km DOUBLE PRECISION,
  can_deliver BOOLEAN
)
```

**الوظيفة:**
- تبحث عن جميع المتاجر القريبة من موقع معين
- ترتب النتائج حسب المسافة
- تحدد إمكانية التوصيل لكل متجر

## 📱 تجربة المستخدم

### السيناريو 1: اختيار عنوان
```
المستخدم يختار عنوان من قائمة العناوين
  ↓
التطبيق يحسب المسافة لكل متجر في السلة
  ↓
إذا كان متجر خارج النطاق:
  → عرض تنبيه: "المتجر [اسم] لا يوصل لهذا العنوان"
  → إمكانية الاستمرار أو اختيار عنوان آخر
```

### السيناريو 2: إضافة عنوان جديد
```
المستخدم يحدد موقع على الخريطة
  ↓
التطبيق يحسب المسافة فوراً
  ↓
إذا كان خارج النطاق:
  → تنبيه فوري قبل الحفظ
  → إمكانية تعديل الموقع
```

### السيناريو 3: تأكيد الطلب
```
المستخدم يسحب زر التأكيد
  ↓
التحقق النهائي من جميع المتاجر
  ↓
إذا كان متجر خارج النطاق:
  → منع التأكيد
  → رسالة توضح المتاجر المرفوضة
```

## 🎯 الفوائد

### للمطور
- ✅ كود أبسط وأسهل في الصيانة
- ✅ لا حاجة لتحديث قواميس الأسماء
- ✅ دعم تلقائي لجميع المدن والمحافظات
- ✅ أداء أفضل (استعلامات PostGIS محسّنة)

### للتاجر
- ✅ تحكم دقيق في نطاق التوصيل
- ✅ تحديد نطاق بالكيلومترات (مثلاً: 5 كم، 10 كم)
- ✅ لا حاجة لإدخال أسماء مدن

### للعميل
- ✅ نتائج دقيقة ومنطقية
- ✅ لا رفض خاطئ للعناوين الصحيحة
- ✅ رسائل واضحة مع المسافات الفعلية
- ✅ تجربة أفضل عند اختيار العنوان

## 📊 مثال عملي

### قبل (النظام القديم):
```
متجر: "الزقازيق - الشرقية"
عنوان 1: "الزقازيق، الشرقية" → ✅ مقبول
عنوان 2: "Zagazig, Eastern" → ❌ مرفوض (خطأ!)
عنوان 3: "حي السلام، الزقازيق" → ❌ مرفوض (خطأ!)
```

### بعد (النظام الجديد):
```
متجر: lat=30.5833, lng=31.5000 (نطاق 5 كم)
عنوان 1: lat=30.5900, lng=31.5100 → المسافة: 0.95 كم → ✅ مقبول
عنوان 2: lat=30.5850, lng=31.5050 → المسافة: 0.45 كم → ✅ مقبول
عنوان 3: lat=30.6500, lng=31.6000 → المسافة: 10.2 كم → ❌ مرفوض
```

## 🔍 سجلات التتبع

التطبيق يطبع سجلات تفصيلية للمساعدة في التشخيص:

```
📍 التحقق من نطاق التوصيل للعنوان:
  Lat: 30.5900, Lng: 31.5100

🏪 التحقق من متجر: سوبر ماركت الأسرة (ID: abc-123)
  📊 النتيجة:
    - يمكن التوصيل: true
    - المسافة: 0.95 كم
  ✅ المتجر داخل نطاق التوصيل

🏪 التحقق من متجر: متجر البركة (ID: def-456)
  📊 النتيجة:
    - يمكن التوصيل: false
    - المسافة: 12.30 كم
  ❌ المتجر خارج نطاق التوصيل
```

## 📝 ملاحظات مهمة

### متطلبات العمل:
1. ✅ يجب أن يكون للمتجر موقع GPS محدد في جدول `stores`
2. ✅ يجب أن يكون للعنوان إحداثيات (latitude, longitude)
3. ✅ يجب تحديد `delivery_radius_km` لكل متجر
4. ✅ PostGIS extension يجب أن يكون مفعّل في Supabase

### التعامل مع الأخطاء:
- إذا لم يكن للمتجر موقع GPS → يُعتبر خارج النطاق
- إذا لم يكن للعنوان إحداثيات → يُعتبر غير صالح
- إذا حدث خطأ في الحساب → احتياطياً يُعتبر خارج النطاق (للأمان)

## 🚀 الاستخدام

### في كود Flutter:
```dart
// التحقق من متجر واحد
final result = await LocationService.canDeliverToLocation(
  storeId: 'store-uuid',
  latitude: 30.5900,
  longitude: 31.5100,
);

print('يمكن التوصيل: ${result['can_deliver']}');
print('المسافة: ${result['distance_km']} كم');

// البحث عن متاجر قريبة
final nearbyStores = await LocationService.getNearbyStores(
  latitude: 30.5900,
  longitude: 31.5100,
  radiusKm: 10.0,
);

for (var store in nearbyStores) {
  print('${store['name']}: ${store['distance_km']} كم');
}
```

## ✨ الخلاصة

تم الانتقال من نظام **مقارنة نصية غير دقيق** إلى نظام **حساب جغرافي دقيق** باستخدام PostGIS، مما يوفر:

- 🎯 دقة عالية في تحديد نطاق التوصيل
- 🌍 دعم عالمي بدون قيود لغوية
- 🚀 أداء أفضل وكود أبسط
- 😊 تجربة مستخدم محسّنة
- 🔧 صيانة أسهل للمطورين

---

**تاريخ التحديث:** يناير 2026  
**الإصدار:** 1.0  
**الملفات المتأثرة:**
- `lib/screens/user/checkout_screen.dart`
- `lib/services/location_service.dart`
- `supabase/migrations/20260107000002_enable_postgis_nearby_stores.sql`
