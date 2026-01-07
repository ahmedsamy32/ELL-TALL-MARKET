# 🗺️ Advanced Map Screen - دليل الاستخدام الشامل

## 📋 المحتويات
1. [نظرة عامة](#نظرة-عامة)
2. [الميزات](#الميزات)
3. [المتطلبات](#المتطلبات)
4. [التثبيت](#التثبيت)
5. [أمثلة الاستخدام](#أمثلة-الاستخدام)
6. [API Reference](#api-reference)
7. [أفضل الممارسات](#أفضل-الممارسات)

---

## 🎯 نظرة عامة

`AdvancedMapScreen` هو نظام خرائط متقدم مبني على أفضل الممارسات من:
- ✅ Flutter Gems (https://fluttergems.dev)
- ✅ Flutter Awesome (https://flutterawesome.com)
- ✅ Awesome Flutter (https://github.com/Solido/awesome-flutter)
- ✅ Google Maps Flutter (https://pub.dev/packages/google_maps_flutter)

### 🎨 يدعم 3 أنواع مستخدمين:
1. **العميل (Customer)** - اختيار موقع التوصيل
2. **التاجر (Merchant)** - عرض المتجر ونطاق التوصيل
3. **الكابتن (Driver)** - التتبع الحي والتنقل

---

## ✨ الميزات

### 🧑 للعميل:
- ✅ اختيار موقع التوصيل بسهولة
- ✅ تحويل تلقائي للإحداثيات إلى عنوان
- ✅ تحديد الموقع الحالي GPS
- ✅ بحث عن الأماكن (قريباً)
- ✅ دبوس متحرك مع animation

### 🏪 للتاجر:
- ✅ عرض موقع المتجر
- ✅ دائرة نطاق التوصيل (15 كم)
- ✅ عرض مواقع الطلبات الحالية
- ✅ تتبع الكابتن في الوقت الفعلي

### 🚗 للكابتن:
- ✅ التتبع الحي (Live Tracking)
- ✅ رسم المسار الأمثل
- ✅ حساب المسافة والوقت المتوقع
- ✅ معلومات العميل (اسم، رقم، موقع)
- ✅ زر الاتصال السريع
- ✅ إشعار عند الوصول

### 🎨 ميزات عامة:
- ✅ تبديل نوع الخريطة (Normal, Satellite, Hybrid)
- ✅ عرض حركة المرور (Traffic)
- ✅ Animations سلسة
- ✅ تصميم Material Design 3
- ✅ دعم الوضع الليلي

---

## 📦 المتطلبات

### 1. إضافة الـ Dependencies

في `pubspec.yaml`:

```yaml
dependencies:
  google_maps_flutter: ^2.2.6
  geolocator: ^10.1.0
  geocoding: ^2.1.0
  flutter_polyline_points: ^1.0.0
```

ثم نفذ:
```bash
flutter pub get
```

### 2. إعداد Google Maps API

#### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${GOOGLE_MAPS_API_KEY}"/>
    </application>
    
    <!-- أذونات الموقع -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
</manifest>
```

#### iOS (`ios/Runner/AppDelegate.swift`):
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY")
```

#### iOS (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك لتحديد عنوان التوصيل</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك لتتبع رحلة التوصيل</string>
```

### 3. إضافة API Key في `lib/config/env.dart`:
```dart
class Env {
  static const String googleMapsApiKey = 'YOUR_API_KEY_HERE';
}
```

---

## 🚀 أمثلة الاستخدام

### 1️⃣ العميل - اختيار موقع التوصيل

```dart
// فتح الخريطة
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AdvancedMapScreen(
      userType: MapUserType.customer,
      actionType: MapActionType.pickLocation,
      initialPosition: const LatLng(30.0444, 31.2357),
      onLocationSelected: (position, address) {
        print('الموقع: $position');
        print('العنوان: $address');
      },
    ),
  ),
);

// استخدام النتيجة
if (result != null) {
  final LatLng position = result['position'];
  final String address = result['address'];
  
  // حفظ في قاعدة البيانات
  await saveAddress(position, address);
}
```

### 2️⃣ التاجر - عرض نطاق التوصيل

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdvancedMapScreen(
      userType: MapUserType.merchant,
      actionType: MapActionType.viewLocation,
      initialPosition: LatLng(30.5852, 31.5048), // موقع المتجر
    ),
  ),
);
```

### 3️⃣ الكابتن - بدء رحلة التوصيل

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AdvancedMapScreen(
      userType: MapUserType.driver,
      actionType: MapActionType.navigation,
      destinationPosition: customerLocation,
      orderId: '12345',
      customerName: 'أحمد محمد',
      customerPhone: '01012345678',
      
      // عند بدء التنقل
      onNavigationStart: () {
        updateOrderStatus('on_the_way');
      },
      
      // عند إتمام التوصيل
      onDeliveryComplete: () {
        completeOrder();
        sendNotification();
      },
    ),
  ),
);
```

### 4️⃣ Widget سريع لاختيار الموقع

```dart
MapPickerWidget(
  initialPosition: savedLocation,
  onLocationPicked: (position, address) {
    setState(() {
      _selectedLocation = position;
      _selectedAddress = address;
    });
  },
)
```

---

## 📚 API Reference

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userType` | `MapUserType` | ✅ Yes | نوع المستخدم (customer/merchant/driver) |
| `actionType` | `MapActionType` | ✅ Yes | نوع العملية (pickLocation/viewLocation/navigation/tracking) |
| `initialPosition` | `LatLng?` | ❌ No | الموقع الأولي للخريطة |
| `destinationPosition` | `LatLng?` | ❌ No | موقع الوجهة (للكابتن فقط) |
| `orderId` | `String?` | ❌ No | معرف الطلب |
| `customerName` | `String?` | ❌ No | اسم العميل (للكابتن) |
| `customerPhone` | `String?` | ❌ No | رقم العميل (للكابتن) |
| `onLocationSelected` | `Function?` | ❌ No | Callback عند اختيار الموقع |
| `onNavigationStart` | `VoidCallback?` | ❌ No | Callback عند بدء التنقل |
| `onDeliveryComplete` | `VoidCallback?` | ❌ No | Callback عند إتمام التوصيل |

### Enums

#### MapUserType
```dart
enum MapUserType {
  customer,  // العميل
  merchant,  // التاجر
  driver,    // الكابتن
}
```

#### MapActionType
```dart
enum MapActionType {
  pickLocation,  // اختيار موقع
  viewLocation,  // عرض موقع
  navigation,    // التنقل
  tracking,      // التتبع
}
```

---

## 🎯 أفضل الممارسات

### 1. إدارة الأذونات
```dart
// تحقق من الأذونات قبل فتح الخريطة
Future<bool> checkLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  
  return permission != LocationPermission.deniedForever;
}

// الاستخدام
if (await checkLocationPermission()) {
  // فتح الخريطة
} else {
  // عرض رسالة خطأ
}
```

### 2. حفظ الموقع المختار
```dart
Future<void> saveCustomerAddress(LatLng position, String address) async {
  try {
    await Supabase.instance.client.from('addresses').insert({
      'user_id': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': address,
      'created_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    print('خطأ في الحفظ: $e');
  }
}
```

### 3. التتبع الحي (Realtime)
```dart
// إرسال موقع الكابتن للسيرفر
void startRealtimeTracking(String orderId) {
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // كل 10 متر
  );

  Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position position) async {
    // تحديث موقع الكابتن في Supabase
    await Supabase.instance.client
        .from('orders')
        .update({
          'driver_latitude': position.latitude,
          'driver_longitude': position.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  });
}
```

### 4. حساب تكلفة التوصيل حسب المسافة
```dart
double calculateDeliveryFee(double distanceInKm) {
  const basePrice = 10.0; // سعر أساسي
  const pricePerKm = 5.0; // سعر الكيلومتر
  
  if (distanceInKm <= 5) {
    return basePrice;
  } else {
    return basePrice + ((distanceInKm - 5) * pricePerKm);
  }
}
```

### 5. التحقق من نطاق التوصيل
```dart
bool isWithinDeliveryRange(
  LatLng storeLocation,
  LatLng customerLocation,
  double maxRadius, // بالكيلومتر
) {
  double distance = Geolocator.distanceBetween(
    storeLocation.latitude,
    storeLocation.longitude,
    customerLocation.latitude,
    customerLocation.longitude,
  ) / 1000; // تحويل من متر لكم
  
  return distance <= maxRadius;
}
```

---

## 🔧 التخصيص

### تغيير ألوان الخريطة
```dart
// في ملف JSON منفصل (map_style.json)
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  // ... المزيد من الأنماط
]

// تطبيق الأنماط
Future<void> _setMapStyle() async {
  String style = await rootBundle.loadString('assets/map_style.json');
  _mapController?.setMapStyle(style);
}
```

### إضافة أيقونات مخصصة للمؤشرات
```dart
BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
  const ImageConfiguration(size: Size(48, 48)),
  'assets/icons/store_marker.png',
);

_markers.add(
  Marker(
    markerId: const MarkerId('store'),
    position: storeLocation,
    icon: customIcon,
  ),
);
```

---

## 🐛 استكشاف الأخطاء

### مشكلة: الخريطة لا تظهر
**الحل:**
1. تأكد من إضافة API Key
2. تفعيل Maps SDK في Google Cloud Console
3. فحص الأذونات في AndroidManifest.xml

### مشكلة: لا يتم تحديد الموقع
**الحل:**
```dart
// تأكد من تفعيل GPS
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
  // اطلب تفعيل GPS
  await Geolocator.openLocationSettings();
}
```

### مشكلة: رسم المسار لا يعمل
**الحل:**
1. تفعيل Directions API في Google Cloud Console
2. التأكد من صحة API Key
3. فحص الاتصال بالإنترنت

---

## 📱 الاختبار

### Unit Tests
```dart
test('حساب المسافة بين نقطتين', () {
  final cairo = LatLng(30.0444, 31.2357);
  final alex = LatLng(31.2001, 29.9187);
  
  double distance = calculateDistance(cairo, alex);
  
  expect(distance, greaterThan(180)); // ~180 كم
  expect(distance, lessThan(220));
});
```

### Widget Tests
```dart
testWidgets('زر تأكيد الموقع يعمل', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdvancedMapScreen(
        userType: MapUserType.customer,
        actionType: MapActionType.pickLocation,
      ),
    ),
  );

  expect(find.text('تأكيد الموقع'), findsOneWidget);
  
  await tester.tap(find.text('تأكيد الموقع'));
  await tester.pumpAndSettle();
});
```

---

## 🌟 المصادر والمراجع

### 📚 Documentation
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Geolocator](https://pub.dev/packages/geolocator)
- [Geocoding](https://pub.dev/packages/geocoding)
- [Flutter Polyline Points](https://pub.dev/packages/flutter_polyline_points)

### 🎨 Templates & Examples
- [FlutterGems - Maps](https://fluttergems.dev/packages/maps/)
- [Flutter Awesome](https://flutterawesome.com)
- [Awesome Flutter](https://github.com/Solido/awesome-flutter)

### 🎓 Tutorials
- [Google Maps in Flutter - Official](https://codelabs.developers.google.com/codelabs/google-maps-in-flutter)
- [Flutter Maps Tutorial](https://www.youtube.com/watch?v=RpQLFAFqMlw)

---

## 📄 الترخيص

هذا الكود مفتوح المصدر ويمكن استخدامه بحرية في مشروعك.

---

## 🤝 المساهمة

لديك اقتراح؟ واجهتك مشكلة؟
افتح Issue أو Pull Request على GitHub!

---

## 📞 الدعم

للمساعدة والدعم:
- 📧 Email: support@example.com
- 💬 Discord: [Join Server](https://discord.gg/example)
- 📱 WhatsApp: +20 XXX XXX XXXX

---

**صنع بـ ❤️ للمطورين العرب**
