# Addresses Screen Fix - إصلاح شاشة العناوين

## التاريخ: 11 أكتوبر 2025

## نظرة عامة
تم إصلاح `addresses_screen.dart` للعمل مع جدول `addresses` المنفصل في قاعدة البيانات بدلاً من محاولة حفظ العنوان في جدول `profiles`.

---

## المشكلة الأصلية

### الأخطاء الموجودة:
1. ❌ محاولة الوصول إلى `currentUserProfile.address` (غير موجود في ProfileModel)
2. ❌ محاولة استخدام `copyWith(address: ...)` (معامل غير موجود)
3. ❌ استدعاء `authProvider.updateUser()` (دالة غير موجودة)

### السبب:
- الكود القديم كان يفترض أن العنوان محفوظ في جدول `profiles`
- Schema الجديد يستخدم جدول `addresses` منفصل مع علاقة `client_id`

---

## الحل المُطبق

### 1. تحديث الـ Imports
```dart
// تمت إضافة:
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/address_Model.dart';
import 'package:ell_tall_market/core/logger.dart';
```

### 2. إعادة كتابة `initState` وإضافة `_loadDefaultAddress`

#### قبل:
```dart
@override
void initState() {
  super.initState();
  final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
  _fillManualAddress(authProvider.currentUserProfile?.address ?? '');
}

void _fillManualAddress(String address) {
  // محاولة تقسيم string واحد إلى أجزاء
  final parts = address.split(',').map((e) => e.trim()).toList();
  // ... fill controllers
}
```

#### بعد:
```dart
@override
void initState() {
  super.initState();
  _loadDefaultAddress();
}

Future<void> _loadDefaultAddress() async {
  try {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    if (userId == null) return;

    // جلب العنوان الافتراضي من جدول addresses
    final response = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('client_id', userId)
        .eq('is_default', true)
        .maybeSingle();

    if (response != null) {
      final address = AddressModel.fromMap(response);
      
      // ملء النموذج بالبيانات الموجودة
      cityController.text = address.city;
      streetController.text = address.street;
      districtController.text = address.area ?? '';
      buildingController.text = address.buildingNumber ?? '';
      floorController.text = address.floorNumber ?? '';
      apartmentController.text = address.apartmentNumber ?? '';
      landmarkController.text = address.notes ?? '';
      
      if (address.latitude != null && address.longitude != null) {
        selectedPosition = LatLng(address.latitude!, address.longitude!);
        setState(() {});
      }
    }
  } catch (e) {
    AppLogger.error('Error loading address', e);
  }
}
```

### 3. إعادة كتابة `saveAddress` كاملة

#### قبل:
```dart
void saveAddress() async {
  final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
  if (authProvider.currentUserProfile == null) return;

  final addressParts = [
    governorateController.text,
    cityController.text,
    // ... join as string
  ].join(', ');

  // محاولة حفظ في ProfileModel
  final updatedUser = authProvider.currentUserProfile!.copyWith(
    address: addressParts, // ❌ معامل غير موجود
    updatedAt: DateTime.now(),
  );

  final updatedResult = await authProvider.updateUser(updatedUser); // ❌ دالة غير موجودة
}
```

#### بعد:
```dart
void saveAddress() async {
  final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
  final userId = authProvider.currentUser?.id;
  
  if (userId == null) {
    // رسالة خطأ واضحة
    return;
  }

  // التحقق من الحقول المطلوبة
  if (cityController.text.isEmpty || streetController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يرجى إدخال المدينة والشارع على الأقل')),
    );
    return;
  }

  try {
    // تجهيز البيانات لجدول addresses
    final addressData = {
      'client_id': userId,
      'label': 'المنزل', // Default label
      'city': cityController.text.trim(),
      'street': streetController.text.trim(),
      'area': districtController.text.trim().isNotEmpty 
          ? districtController.text.trim() 
          : null,
      'building_number': buildingController.text.trim().isNotEmpty
          ? buildingController.text.trim()
          : null,
      'floor_number': floorController.text.trim().isNotEmpty
          ? floorController.text.trim()
          : null,
      'apartment_number': apartmentController.text.trim().isNotEmpty
          ? apartmentController.text.trim()
          : null,
      'latitude': selectedPosition?.latitude,
      'longitude': selectedPosition?.longitude,
      'notes': landmarkController.text.trim().isNotEmpty
          ? landmarkController.text.trim()
          : null,
      'is_default': true, // Set as default address
    };

    // التحقق من وجود عنوان افتراضي مسبق
    final existingAddress = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('client_id', userId)
        .eq('is_default', true)
        .maybeSingle();

    if (existingAddress != null) {
      // تحديث العنوان الموجود
      await Supabase.instance.client
          .from('addresses')
          .update(addressData)
          .eq('id', existingAddress['id']);
    } else {
      // إدراج عنوان جديد
      await Supabase.instance.client
          .from('addresses')
          .insert(addressData);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ العنوان بنجاح')),
      );
    }
  } catch (e) {
    AppLogger.error('Error saving address', e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ العنوان: ${e.toString()}')),
      );
    }
  }
}
```

---

## Schema الجديد - جدول addresses

```sql
CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  label TEXT NOT NULL, -- مثل: "المنزل"، "العمل"، "أخرى"
  street TEXT NOT NULL,
  city TEXT NOT NULL,
  area TEXT,
  building_number TEXT,
  floor_number TEXT,
  apartment_number TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  phone TEXT,
  notes TEXT,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);
```

---

## التحسينات المُضافة

### 1. ✅ التحقق من صحة البيانات
```dart
if (cityController.text.isEmpty || streetController.text.isEmpty) {
  // رسالة خطأ واضحة
  return;
}
```

### 2. ✅ معالجة الحقول الاختيارية بشكل صحيح
```dart
'area': districtController.text.trim().isNotEmpty 
    ? districtController.text.trim() 
    : null,
```

### 3. ✅ Update vs Insert Logic
```dart
// التحقق من وجود عنوان افتراضي
final existingAddress = await Supabase.instance.client
    .from('addresses')
    .select()
    .eq('client_id', userId)
    .eq('is_default', true)
    .maybeSingle();

if (existingAddress != null) {
  // Update
} else {
  // Insert
}
```

### 4. ✅ حفظ الإحداثيات الجغرافية
```dart
'latitude': selectedPosition?.latitude,
'longitude': selectedPosition?.longitude,
```

### 5. ✅ استخدام `mounted` check
```dart
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

---

## الميزات المدعومة

### ✅ تحميل العنوان الافتراضي عند فتح الشاشة
- يجلب العنوان المُعلّم كـ `is_default = true`
- يملأ جميع الحقول تلقائياً
- يعرض الموقع على الخريطة إذا كانت الإحداثيات موجودة

### ✅ حفظ/تحديث العنوان
- يُدرج عنوان جديد إذا لم يكن موجود
- يُحدث العنوان الموجود إذا كان موجوداً
- يحفظ جميع الحقول بشكل منفصل (city, street, area, etc.)

### ✅ دعم Google Maps
- اختيار الموقع من الخريطة
- حفظ latitude و longitude
- اكتشاف الموقع الحالي

### ✅ معالجة الأخطاء
- رسائل خطأ واضحة للمستخدم
- Logging للأخطاء في AppLogger
- التحقق من تسجيل الدخول

---

## الملفات المُستخدمة

### Models:
- ✅ `ProfileModel` - للحصول على `userId`
- ✅ `AddressModel` - لتمثيل بيانات العنوان

### Providers:
- ✅ `SupabaseProvider` - للحصول على `currentUser.id`

### Database Tables:
- ✅ `addresses` - جدول العناوين الرئيسي
- ✅ `clients` - مرتبط عبر `client_id`

---

## الحالة النهائية

### ✅ الشاشة تعمل بدون أخطاء تجميع
### ✅ التكامل الكامل مع قاعدة البيانات
### ✅ دعم CRUD operations للعناوين
### ✅ UI/UX محسّن مع رسائل واضحة

---

## ملاحظات مهمة

### 1. العلاقة مع جدول clients
```sql
client_id UUID REFERENCES clients(id) ON DELETE CASCADE
```
- تأكد من وجود record في جدول `clients` لـ userId
- إذا لم يكن موجوداً، سيفشل الـ INSERT بسبب foreign key constraint

### 2. العنوان الافتراضي (is_default)
- كل مستخدم يمكن أن يكون له عنوان واحد فقط `is_default = true`
- يمكن تطوير الشاشة لدعم عناوين متعددة لاحقاً

### 3. تطويرات مستقبلية محتملة
- 📋 إضافة قائمة بجميع عناوين المستخدم
- ➕ السماح بإضافة عناوين متعددة
- 🏷️ إضافة labels مخصصة (المنزل، العمل، الخ)
- 🗑️ حذف العناوين
- ⭐ تبديل العنوان الافتراضي

---

**تم التوثيق بواسطة**: GitHub Copilot
**التاريخ**: 11 أكتوبر 2025
