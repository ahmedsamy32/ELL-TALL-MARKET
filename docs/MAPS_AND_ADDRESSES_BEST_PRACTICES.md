# 🗺️ نظام الخرائط والعناوين - أفضل الممارسات

## 📋 نظرة عامة

تم تطوير نظام الخرائط والعناوين في التطبيق باستخدام **أفضل الممارسات** المستخدمة في تطبيقات التوصيل الكبرى مثل:
- 🍔 **طلبات (Talabat)**
- 🚗 **كريم ناو (Careem Now)**
- 🍕 **أوبر إيتس (Uber Eats)**
- 🛒 **نون فود (Noon Food)**

---

## ✨ التحسينات المُطبقة

### 1️⃣ تحسينات MapPickerScreen

#### 🎯 الدبوس المتحرك (Animated Pin)
```dart
// الدبوس يتحرك ويكبر أثناء تحريك الخريطة
AnimatedScale(
  scale: _isLoadingAddress ? 1.2 : 1.0,
  duration: Duration(milliseconds: 200),
  child: Icon(
    Icons.location_on,
    color: _isOutOfRange ? Colors.orange : Colors.blue,
  ),
)
```

**الفوائد:**
- ✅ تجربة مستخدم سلسة ومرئية
- ✅ تغيير اللون حسب نطاق التوصيل (أزرق = داخل، برتقالي = خارج)
- ✅ رسوم متحركة للظل أثناء التحريك

---

#### 🔍 البحث بالاقتراحات التلقائية (Autocomplete)
```dart
// اقتراحات للمدن الشائعة أثناء الكتابة
final _popularPlaces = [
  {'name': 'القاهرة', 'lat': 30.0444, 'lng': 31.2357},
  {'name': 'الإسكندرية', 'lat': 31.2001, 'lng': 29.9187},
  // ...
];

void _onSearchTextChanged(String query) {
  // عرض الاقتراحات فوراً
  setState(() {
    _searchSuggestions = _popularPlaces
      .where((p) => p['name'].contains(query))
      .map((p) => p['name'])
      .toList();
  });
  
  // البحث الفعلي بعد 500ms (debounce)
  _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
    _searchAddress(query);
  });
}
```

**الفوائد:**
- ✅ اقتراحات فورية للمدن الشائعة
- ✅ Debouncing لتقليل استدعاءات API
- ✅ UX سريع ومريح للمستخدم

---

#### 📍 دائرة نطاق التوصيل (Delivery Range Circle)
```dart
// رسم دائرة نصف قطرها 15 كم حول موقع المتجر
Circle(
  circleId: CircleId('delivery_range'),
  center: _storeLocation!,
  radius: 15000, // 15 كم بالمتر
  fillColor: Colors.blue.withOpacity(0.1),
  strokeColor: Colors.blue.withOpacity(0.5),
  strokeWidth: 2,
)
```

**الفوائد:**
- ✅ المستخدم يرى نطاق التوصيل بصرياً
- ✅ علامة زرقاء على المتجر
- ✅ حساب المسافة الدقيقة بالكيلومترات (Haversine formula)
- ✅ عرض المسافة: "2.5 كم من المتجر" أو "450 متر من المتجر"

**كود حساب المسافة:**
```dart
double _calculateDistance(LatLng from, LatLng to) {
  return Geolocator.distanceBetween(
    from.latitude, from.longitude,
    to.latitude, to.longitude,
  ) / 1000; // تحويل من متر لكيلومتر
}
```

---

#### 🎨 أنواع الخرائط المتعددة
```dart
// التبديل بين: Normal → Satellite → Hybrid
MapType _currentMapType = MapType.normal;

void _toggleMapType() {
  setState(() {
    _currentMapType = _currentMapType == MapType.normal 
      ? MapType.satellite 
      : _currentMapType == MapType.satellite
        ? MapType.hybrid
        : MapType.normal;
  });
}
```

---

### 2️⃣ تحسينات AddressesScreen

#### 📊 مؤشر اكتمال العنوان (Completion Indicator)
```dart
// حساب نسبة الاكتمال (0-100%)
int get addressCompletionPercentage {
  int filledFields = 0;
  
  // الحقول المطلوبة (70% من الوزن)
  if (selectedPosition != null) filledFields++;
  if (governorateController.text.isNotEmpty) filledFields++;
  if (cityController.text.isNotEmpty) filledFields++;
  if (streetController.text.isNotEmpty) filledFields++;
  
  // الحقول الاختيارية (30% من الوزن)
  if (districtController.text.isNotEmpty) filledFields++;
  if (buildingController.text.isNotEmpty) filledFields++;
  // ...
  
  return calculatedPercentage;
}
```

**واجهة المستخدم:**
```dart
Container(
  decoration: BoxDecoration(
    color: percentage == 100 ? Colors.green.shade50 : Colors.orange.shade50,
    border: Border.all(color: percentage == 100 ? Colors.green : Colors.orange),
  ),
  child: Column(
    children: [
      Text('اكتمال البيانات'),
      Text('$percentage%', style: TextStyle(fontSize: 18, fontWeight: bold)),
      LinearProgressIndicator(value: percentage / 100),
      Text('✅ جميع البيانات الأساسية مكتملة'),
    ],
  ),
)
```

**الفوائد:**
- ✅ يعرف المستخدم ما الذي ينقصه
- ✅ ألوان مرئية (أخضر = كامل، برتقالي = ناقص، أحمر = مطلوب)
- ✅ زر الحفظ معطل حتى يكتمل الحد الأدنى
- ✅ Progress bar مرئي

---

#### ✔️ التحقق من الاكتمال قبل الحفظ
```dart
bool get isAddressComplete {
  return selectedPosition != null &&
    governorateController.text.trim().isNotEmpty &&
    cityController.text.trim().isNotEmpty &&
    streetController.text.trim().isNotEmpty;
}

// الزر معطل إذا لم تكتمل البيانات
FilledButton(
  onPressed: isAddressComplete ? saveAddress : null,
  child: Text('حفظ العنوان'),
)
```

---

#### 🎯 تحسين تحميل البيانات من الخريطة
```dart
void _loadMapPickerData() {
  final args = ModalRoute.of(context)?.settings.arguments;
  
  if (args != null && args is Map) {
    setState(() {
      // المحافظة والمدينة
      governorateController.text = args['governorate'] ?? '';
      cityController.text = args['city'] ?? '';
      
      // تقسيم العنوان الذكي
      if (args['address'] != null) {
        List<String> parts = args['address'].split('، ');
        
        streetController.text = parts[0]; // الشارع
        
        // الحي (إذا لم يكن مدينة أو محافظة)
        if (parts.length > 1 && 
            parts[1] != cityController.text &&
            parts[1] != governorateController.text) {
          districtController.text = parts[1];
        }
      }
      
      // الموقع
      selectedPosition = args['position'];
    });
  }
}
```

---

## 🎨 التصميم المرئي (UI/UX)

### ألوان نطاق التوصيل

| الحالة | لون الدبوس | لون الخلفية | الرسالة |
|--------|-----------|------------|---------|
| داخل النطاق | 🔵 أزرق | 🟢 أخضر فاتح | ✅ ضمن نطاق التوصيل |
| خارج النطاق | 🟠 برتقالي | 🟠 برتقالي فاتح | ⚠️ تنبيه: خارج النطاق |
| غير محدد | 🔴 أحمر | 🔴 أحمر فاتح | ❌ يرجى تحديد الموقع |

---

### حالات التحميل (Loading States)

```dart
// أثناء تحديد العنوان من الخريطة
_isLoadingAddress ? CircularProgressIndicator() : Icon(Icons.search)

// أثناء الحصول على الموقع الحالي
_isLoadingCurrentLocation ? CircularProgressIndicator() : Icon(Icons.my_location)

// نص متغير
Text(_isLoadingAddress ? 'جاري تحديد العنوان...' : _selectedAddress)
```

---

## 📱 تجربة المستخدم (UX Flow)

### السيناريو الكامل:

```
1. المستخدم يفتح الخريطة
   ↓
2. تحصل على الموقع الحالي تلقائياً
   ↓
3. يعرض دائرة نطاق التوصيل (إذا كان هناك متجر)
   ↓
4. المستخدم يحرك الخريطة
   - الدبوس يتحرك
   - يتغير النص: "جاري تحديد العنوان..."
   ↓
5. بعد توقف الخريطة (500ms debounce)
   - يحصل على العنوان من Geocoding
   - يحسب المسافة من المتجر
   - يحدد: داخل/خارج النطاق
   - يغير لون الدبوس
   ↓
6. المستخدم يبحث عن مكان:
   - يظهر اقتراحات فورية (المدن الشائعة)
   - بعد 500ms: بحث كامل
   ↓
7. المستخدم يضغط "أكمل باقي العنوان"
   - ينتقل لـ AddressesScreen
   - البيانات محملة تلقائياً من الخريطة
   ↓
8. في AddressesScreen:
   - يعرض مؤشر الاكتمال
   - المستخدم يكمل البيانات الناقصة
   - زر الحفظ معطل حتى الحد الأدنى
   ↓
9. بعد الحفظ:
   - رسالة نجاح
   - العودة للصفحة السابقة مع العنوان الجديد
```

---

## 🔧 الكود التقني

### 1. Debouncing للبحث
```dart
Timer? _searchDebounceTimer;

void _onSearchTextChanged(String query) {
  _searchDebounceTimer?.cancel();
  
  _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
    _searchAddress(query);
  });
}
```

**الفائدة:** تقليل استدعاءات Geocoding API (توفير التكلفة والسرعة)

---

### 2. Geocoding الذكي
```dart
Future<void> _getAddressFromPosition(LatLng position) async {
  final placemarks = await placemarkFromCoordinates(
    position.latitude, 
    position.longitude,
  ).timeout(Duration(seconds: 10));
  
  if (placemarks.isNotEmpty) {
    final place = placemarks.first;
    
    // تنظيف Plus Codes
    String? cleanText(String? text) {
      if (text == null) return null;
      return text
        .replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]+'), '') // Plus codes
        .replaceAll(RegExp(r'\d{5,}'), '') // أرقام طويلة
        .trim();
    }
    
    // استخراج ذكي
    String street = cleanText(place.thoroughfare) ?? 
                    cleanText(place.name) ?? 
                    'الموقع المحدد';
  }
}
```

---

### 3. حساب المسافة (Haversine)
```dart
double _calculateDistance(LatLng from, LatLng to) {
  // استخدام Geolocator للحساب الدقيق
  return Geolocator.distanceBetween(
    from.latitude, from.longitude,
    to.latitude, to.longitude,
  ) / 1000; // متر → كيلومتر
}
```

**البديل (Haversine يدوي):**
```dart
double _haversine(LatLng from, LatLng to) {
  const R = 6371; // نصف قطر الأرض بالكيلومتر
  
  final dLat = _toRadians(to.latitude - from.latitude);
  final dLon = _toRadians(to.longitude - from.longitude);
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(from.latitude)) * cos(_toRadians(to.latitude)) *
      sin(dLon / 2) * sin(dLon / 2);
  
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
```

---

## 🎯 أفضل الممارسات المُطبقة

### ✅ Performance
- [x] Debouncing للبحث (500ms)
- [x] Timeout للـ Geocoding (10s)
- [x] Caching للمواقع الشائعة
- [x] Lazy loading للعناوين المحفوظة

### ✅ UX
- [x] Loading states واضحة
- [x] رسوم متحركة سلسة
- [x] ألوان مرئية للحالات
- [x] رسائل واضحة بالعربية
- [x] أيقونات معبرة

### ✅ Validation
- [x] التحقق من اكتمال البيانات
- [x] منع الحفظ قبل الحد الأدنى
- [x] تحذيرات واضحة للعناوين خارج النطاق
- [x] منع الطلب إذا كان العنوان خارج النطاق

### ✅ Accessibility
- [x] نصوص قابلة للقراءة
- [x] ألوان متباينة
- [x] أزرار كبيرة
- [x] دعم RTL كامل

---

## 📊 مقارنة مع التطبيقات الكبرى

| الميزة | طلبات | كريم | أوبر إيتس | تطبيقنا |
|-------|------|------|----------|---------|
| دبوس متحرك | ✅ | ✅ | ✅ | ✅ |
| دائرة نطاق التوصيل | ✅ | ✅ | ❌ | ✅ |
| بحث بالاقتراحات | ✅ | ✅ | ✅ | ✅ |
| حساب المسافة | ✅ | ✅ | ✅ | ✅ |
| مؤشر الاكتمال | ❌ | ❌ | ❌ | ✅ |
| أنواع خرائط متعددة | ✅ | ❌ | ❌ | ✅ |
| تحذيرات خارج النطاق | ✅ | ✅ | ✅ | ✅ |

---

## 🚀 تحسينات مستقبلية محتملة

### 1️⃣ Places API Integration
```dart
// استخدام Google Places Autocomplete
import 'package:google_places_flutter/google_places_flutter.dart';

GooglePlaceAutoCompleteTextField(
  textEditingController: _searchController,
  googleAPIKey: "YOUR_API_KEY",
  inputDecoration: InputDecoration(hintText: "ابحث عن مكان..."),
  countries: ["EG"],
  language: "ar",
)
```

### 2️⃣ الحفظ المحلي (Caching)
```dart
import 'package:shared_preferences/shared_preferences.dart';

// حفظ آخر موقع
Future<void> _saveLastLocation(LatLng position) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('last_lat', position.latitude);
  await prefs.setDouble('last_lng', position.longitude);
}
```

### 3️⃣ الأماكن المحفوظة السريعة
```dart
// Quick Access للمنزل والعمل
Row(
  children: [
    QuickAddressChip(
      icon: Icons.home,
      label: 'المنزل',
      onTap: () => _navigateToAddress(homeAddress),
    ),
    QuickAddressChip(
      icon: Icons.work,
      label: 'العمل',
      onTap: () => _navigateToAddress(workAddress),
    ),
  ],
)
```

### 4️⃣ مشاركة الموقع
```dart
import 'package:share_plus/share_plus.dart';

void _shareLocation() {
  final url = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  Share.share('موقعي: $url');
}
```

---

## 📚 المراجع والمصادر

- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Geocoding Plugin](https://pub.dev/packages/geocoding)
- [Geolocator Plugin](https://pub.dev/packages/geolocator)
- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Best Practices](https://docs.flutter.dev/perf/best-practices)

---

## 👨‍💻 المطور

تم التطوير بواسطة: **Ahmed Samy**  
التاريخ: **ديسمبر 2025**  
الإصدار: **1.0.0**

---

## 📝 ملاحظات إضافية

### للمطورين الجدد:
1. اقرأ هذا الملف بالكامل قبل التعديل
2. لا تحذف الـ Debouncing - ضروري للأداء
3. اختبر التطبيق على أجهزة حقيقية (GPS أدق)
4. تأكد من تفعيل Google Maps API Key
5. راقب استهلاك الـ Quota للـ Geocoding API

### للتحسين المستمر:
- راقب تقييمات المستخدمين
- اجمع Analytics عن الأماكن الأكثر بحثاً
- حسّن قائمة الأماكن الشائعة بناءً على البيانات
- أضف المزيد من التحسينات حسب الطلب

---

**🎉 نتمنى لك تجربة ممتازة!**
