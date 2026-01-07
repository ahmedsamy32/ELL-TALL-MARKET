# 🚚 نظام التوصيل المزدوج - دليل الإعداد والتكامل

## 📋 نظرة عامة

تم تطوير نظام توصيل مزدوج يدعم طريقتين للتوصيل:

### 1️⃣ **توصيل التاجر** (Store Delivery)
- التاجر مسؤول عن التوصيل بنفسه
- يحدد التاجر رسوم التوصيل الثابتة
- يحدد الحد الأدنى للطلب ووقت التوصيل
- مناسب للمتاجر التي لديها مناديب خاصة

### 2️⃣ **توصيل التطبيق** (App Delivery)
- التطبيق مسؤول عن التوصيل بالكامل
- يتم حساب رسوم التوصيل تلقائياً بناءً على المسافة
- صيغة الحساب: `رسوم أساسية + (المسافة × رسوم الكيلومتر)`
- مناسب للتجار الذين يفضلون عدم التعامل مع التوصيل

---

## 🗂️ الملفات المعدلة

### 1. **models/settings_model.dart**
تم إضافة حقول جديدة لإعدادات التوصيل:

```dart
class AppSettings {
  // ... الحقول الموجودة
  
  // إعدادات التوصيل للتطبيق
  final double appDeliveryBaseFee;      // رسوم التوصيل الأساسية
  final double appDeliveryFeePerKm;     // رسوم لكل كيلومتر
  final double appDeliveryMaxDistance;  // أقصى مسافة للتوصيل (كم)
  final int appDeliveryEstimatedTime;   // الوقت التقديري للتوصيل (دقائق)
}
```

**القيم الافتراضية:**
- رسوم أساسية: `15.0 ج.م`
- رسوم الكيلومتر: `3.0 ج.م`
- أقصى مسافة: `25.0 كم`
- وقت التوصيل: `30 دقيقة`

---

### 2. **screens/admin/app_settings_screen.dart**
تم إضافة قسم جديد لإعدادات التوصيل في شاشة إعدادات التطبيق:

**المكونات المضافة:**
- `_buildDeliveryInfoBanner()` - بانر توضيحي
- `_buildTextFieldSetting()` - حقل نصي للأرقام العشرية
- `_buildIntFieldSetting()` - حقل نصي للأرقام الصحيحة

**الواجهة:**
```
🚚 إعدادات التوصيل
├── 💰 رسوم التوصيل الأساسية (ج.م)
├── 📏 رسوم لكل كيلومتر (ج.م)
├── 🗺️ أقصى مسافة للتوصيل (كم)
└── ⏱️ الوقت التقديري للتوصيل (دقيقة)
```

---

### 3. **screens/merchant/merchant_settings_screen.dart**
يحتوي بالفعل على نظام كامل لاختيار طريقة التوصيل:

**المكونات الموجودة:**
- `_buildDeliveryModeSelector()` - اختيار نوع التوصيل
- `_buildDeliveryModeInfoBanner()` - بانر توضيحي
- `_buildDeliveryInputGrid()` - إدخال بيانات التوصيل
- `_buildDeliveryAreasSection()` - إدارة مناطق التوصيل

**المتغيرات:**
```dart
String _deliveryMode = 'store'; // أو 'app'
bool get _isStoreDelivery => _deliveryMode == 'store';
bool get _isAppDelivery => _deliveryMode == 'app';
```

---

### 4. **screens/user/cart_screen.dart**
تم تنفيذ عرض رسوم التوصيل المختلطة:

**الدالة الرئيسية:**
```dart
Widget _buildDeliveryFeesSection(
  CartProvider cartProvider,
  ColorScheme colorScheme,
  ThemeData theme,
) {
  // تحليل كل متجر في السلة
  for (var item in cartProvider.cartItems) {
    final store = item['product']['stores'];
    final deliveryType = store['delivery_type'] ?? 'merchant';
    
    if (deliveryType == 'merchant') {
      // إضافة رسوم التاجر
      totalDeliveryFee += store['merchant_delivery_fee'] ?? 0.0;
    } else {
      // إضافة رسوم التطبيق (حالياً 15.0 افتراضي)
      totalDeliveryFee += 15.0; // TODO: حساب بناءً على المسافة
    }
  }
}
```

**العرض:**
```
🏪 توصيل التاجر: متجر أحمد، متجر محمد
🚚 توصيل التطبيق: متجر سارة
─────────────────────────────
إجمالي رسوم التوصيل: 45.00 ج.م
```

---

## 🗄️ قاعدة البيانات

### جدول `stores`
```sql
CREATE TABLE stores (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  delivery_mode TEXT DEFAULT 'store' CHECK (delivery_mode IN ('store', 'app')),
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  delivery_time INTEGER DEFAULT 30,
  -- ... باقي الأعمدة
);
```

### جدول `app_settings` (جديد)
```sql
CREATE TABLE app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_delivery_base_fee DECIMAL(10,2) DEFAULT 15.00,
  app_delivery_fee_per_km DECIMAL(10,2) DEFAULT 3.00,
  app_delivery_max_distance DECIMAL(10,2) DEFAULT 25.00,
  app_delivery_estimated_time INTEGER DEFAULT 30,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);
```

---

## 🚀 خطوات التنفيذ

### 1. تحديث قاعدة البيانات

قم بتشغيل السكريبت:
```bash
psql -U your_user -d your_database -f supabase/migrations/add_app_delivery_settings.sql
```

أو من Supabase Dashboard → SQL Editor:
```sql
-- انسخ محتوى ملف add_app_delivery_settings.sql
```

### 2. تحديث جدول المتاجر (إذا لزم الأمر)

```sql
-- تأكد من وجود عمود delivery_mode
ALTER TABLE stores 
ADD COLUMN IF NOT EXISTS delivery_mode TEXT DEFAULT 'store' 
CHECK (delivery_mode IN ('store', 'app'));

-- تحديث المتاجر الموجودة
UPDATE stores 
SET delivery_mode = 'store' 
WHERE delivery_mode IS NULL;
```

### 3. اختبار الواجهات

#### أ) شاشة إعدادات التطبيق (Admin)
```
1. افتح التطبيق كـ Admin
2. اذهب إلى إعدادات التطبيق
3. ابحث عن قسم "🚚 إعدادات التوصيل"
4. قم بتعديل القيم واحفظ
5. تحقق من حفظ القيم بقاعدة البيانات
```

#### ب) شاشة إعدادات التاجر (Merchant)
```
1. افتح التطبيق كـ Merchant
2. اذهب إلى الإعدادات
3. اختر تبويب "التوصيل والمواعيد"
4. اختر طريقة التوصيل (متجر/تطبيق)
5. إذا اخترت "المتجر"، أدخل الرسوم والوقت
6. احفظ واختبر في السلة
```

#### ج) شاشة السلة (User)
```
1. أضف منتجات من متاجر مختلفة
2. تأكد من أن بعض المتاجر تستخدم توصيل المتجر وبعضها توصيل التطبيق
3. افتح السلة
4. تحقق من عرض قسم رسوم التوصيل بشكل صحيح
5. تأكد من فصل المتاجر حسب نوع التوصيل
```

---

## 🔄 التكامل المستقبلي

### 1. حساب المسافة الفعلية

استبدل القيمة الافتراضية في `cart_screen.dart`:

```dart
// الكود الحالي (placeholder)
totalDeliveryFee += 15.0;

// الكود المستقبلي
final userAddress = await _getUserDeliveryAddress();
final storeLocation = store['location']; // {lat, lng}
final distance = await _calculateDistance(userAddress, storeLocation);
final settings = await _getAppSettings();
final calculatedFee = settings.appDeliveryBaseFee + 
                      (distance * settings.appDeliveryFeePerKm);
totalDeliveryFee += calculatedFee;
```

### 2. دالة حساب المسافة

```dart
Future<double> _calculateDistance(
  Map<String, double> from,
  Map<String, double> to,
) async {
  // استخدام Google Maps Distance Matrix API
  final url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${from['lat']},${from['lng']}'
      '&destinations=${to['lat']},${to['lng']}'
      '&key=$GOOGLE_MAPS_API_KEY';
  
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);
  
  // المسافة بالأمتار
  final distanceMeters = data['rows'][0]['elements'][0]['distance']['value'];
  
  // تحويل إلى كيلومترات
  return distanceMeters / 1000.0;
}
```

### 3. التحقق من المسافة القصوى

```dart
Future<bool> _isWithinDeliveryRange(double distance) async {
  final settings = await _getAppSettings();
  return distance <= settings.appDeliveryMaxDistance;
}

// في شاشة السلة
if (!await _isWithinDeliveryRange(distance)) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('خارج نطاق التوصيل'),
      content: Text('عذراً، عنوانك خارج نطاق التوصيل المسموح به'),
    ),
  );
  return;
}
```

---

## 📊 أمثلة على الحسابات

### مثال 1: متجر واحد - توصيل التاجر
```
🏪 متجر أحمد (توصيل التاجر)
رسوم التوصيل: 20.00 ج.م (حددها التاجر)
─────────────────────────────
إجمالي: 20.00 ج.م
```

### مثال 2: متجر واحد - توصيل التطبيق
```
🚚 متجر سارة (توصيل التطبيق)
المسافة: 5 كم
الحساب: 15 + (5 × 3) = 30.00 ج.م
─────────────────────────────
إجمالي: 30.00 ج.م
```

### مثال 3: متاجر مختلطة
```
🏪 توصيل التاجر:
  - متجر أحمد: 20.00 ج.م
  - متجر محمد: 15.00 ج.م

🚚 توصيل التطبيق:
  - متجر سارة (3 كم): 24.00 ج.م
  - متجر فاطمة (7 كم): 36.00 ج.م
─────────────────────────────
إجمالي رسوم التوصيل: 95.00 ج.م
```

---

## ⚠️ ملاحظات مهمة

### 1. الأداء
- استخدم `FutureBuilder` لحساب المسافة بشكل async
- قم بتخزين النتائج مؤقتاً (cache) لتجنب الطلبات المتكررة
- استخدم Debouncing عند تغيير العنوان

### 2. تجربة المستخدم
- اعرض مؤشر تحميل أثناء حساب المسافة
- اعرض تقدير الوقت بجانب رسوم التوصيل
- اسمح للمستخدم بمعاينة الرسوم قبل إتمام الطلب

### 3. الأمان
- تحقق من صحة القيم في الـ Backend
- لا تسمح بقيم سالبة أو صفرية
- ضع حد أقصى للمسافة والرسوم

### 4. التحسينات المستقبلية
- إضافة عروض توصيل مجاني لطلبات معينة
- دعم أوقات ذروة برسوم إضافية
- إضافة خيار "توصيل سريع" برسوم أعلى
- إشعارات فورية بتحديثات التوصيل

---

## 🧪 اختبارات مقترحة

### Test 1: إعدادات التطبيق
```dart
test('يجب حفظ إعدادات التوصيل بنجاح', () async {
  final settings = AppSettings(
    appDeliveryBaseFee: 20.0,
    appDeliveryFeePerKm: 5.0,
    appDeliveryMaxDistance: 30.0,
    appDeliveryEstimatedTime: 45,
  );
  
  await settingsProvider.updateAppSettings(settings);
  final saved = await settingsProvider.loadSettings();
  
  expect(saved.appDeliveryBaseFee, 20.0);
  expect(saved.appDeliveryFeePerKm, 5.0);
});
```

### Test 2: حساب رسوم التوصيل
```dart
test('يجب حساب رسوم التوصيل بشكل صحيح', () {
  final baseFee = 15.0;
  final feePerKm = 3.0;
  final distance = 5.0;
  
  final totalFee = baseFee + (distance * feePerKm);
  
  expect(totalFee, 30.0);
});
```

---

## 📞 الدعم والمساعدة

في حالة وجود أي مشاكل أو استفسارات:
1. راجع ملف `DEVELOPER_GUIDE.md`
2. تحقق من Logs في Console
3. راجع قاعدة البيانات مباشرة
4. تواصل مع فريق التطوير

---

## ✅ Checklist

- [✅] تحديث `settings_model.dart` بحقول التوصيل
- [✅] إضافة قسم إعدادات التوصيل في `app_settings_screen.dart`
- [✅] التحقق من نظام التوصيل في `merchant_settings_screen.dart`
- [✅] تنفيذ عرض رسوم التوصيل في `cart_screen.dart`
- [✅] إنشاء migration script لقاعدة البيانات
- [✅] كتابة الدليل التوثيقي
- [⏳] تنفيذ حساب المسافة الفعلية (مستقبلي)
- [⏳] اختبار شامل على بيانات حقيقية
- [⏳] إضافة Unit Tests و Integration Tests

---

**تم التحديث:** 7 ديسمبر 2025  
**الإصدار:** 1.0  
**المطور:** ELL TALL Market Development Team
