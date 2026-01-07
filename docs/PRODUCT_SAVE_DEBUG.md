# 🐛 تصحيح مشكلة حفظ المنتجات للتاجر

## المشكلة
عند إضافة منتج جديد، البيانات لا تُحفظ بشكل صحيح للتاجر المحدد.

## الحلول المطبقة

### 1️⃣ إضافة Logging شامل

#### في `add_edit_product_screen.dart`:

**عند تحميل بيانات المتجر (`_loadContext()`):**
```dart
✅ إضافة: debugPrint('📋 [AddProduct] Merchant ID: ${merchant?.id}');
✅ إضافة: debugPrint('📋 [AddProduct] Fetching store for merchant: ${merchant.id}');
✅ إضافة: debugPrint('📋 [AddProduct] Found ${stores.length} stores');
✅ إضافة: debugPrint('✅ [AddProduct] Store ID set to: $_storeId');
```

**عند حفظ المنتج (`_saveProduct()`):**
```dart
✅ إضافة: debugPrint('💾 [AddProduct] Saving product with storeId: $storeId');
✅ إضافة: debugPrint('❌ [AddProduct] StoreId is null! Cannot save product');
✅ إضافة: debugPrint('💾 [AddProduct] Product data to save:');
          - Name, StoreId, Price, Stock
✅ إضافة: debugPrint('📝 [AddProduct] Creating new product...');
✅ إضافة: debugPrint('✅ [AddProduct] Product created with ID: ${savedProduct?.id}');
```

#### في `store_service.dart`:

**في `getMerchantStores()`:**
```dart
✅ إضافة: debugPrint('🏪 [StoreService] Fetching stores for merchant: $merchantId');
✅ إضافة: debugPrint('✅ [StoreService] Found ${stores.length} stores');
✅ إضافة: debugPrint('   First store ID: ${stores.first.id}');
✅ إضافة: debugPrint('❌ [StoreService] PostgreSQL Error: ${e.message}');
✅ إضافة: debugPrint('❌ [StoreService] Error fetching stores: $e');
```

### 2️⃣ تحسين معالجة الأخطاء

- ✅ إضافة رسالة خطأ واضحة عندما يكون `storeId` فارغ
- ✅ تسجيل الأخطاء في كل خطوة للتتبع السهل

## كيفية التشخيص

### الخطوات:
1. **افتح Flutter Debug Console**
2. **سجل دخول كتاجر**
3. **اذهب لإضافة منتج جديد**
4. **راقب السجلات:**

```
📋 [AddProduct] Merchant ID: <merchant-uuid>
📋 [AddProduct] Fetching store for merchant: <merchant-uuid>
🏪 [StoreService] Fetching stores for merchant: <merchant-uuid>
✅ [StoreService] Found 1 stores
   First store ID: <store-uuid>
✅ [AddProduct] Store ID set to: <store-uuid>
```

5. **املأ بيانات المنتج واضغط حفظ**
6. **راقب السجلات:**

```
💾 [AddProduct] Saving product with storeId: <store-uuid>
💾 [AddProduct] Product data to save:
   - Name: اسم المنتج
   - StoreId: <store-uuid>
   - Price: 100.0
   - Stock: 50
📝 [AddProduct] Creating new product...
✅ [AddProduct] Product created with ID: <product-uuid>
```

## السيناريوهات المحتملة

### ✅ السيناريو الطبيعي (كل شيء يعمل):
```
📋 Found merchant → 
🏪 Found store → 
✅ Store ID set → 
💾 Product saved with correct storeId
```

### ❌ السيناريو 1: لا يوجد متجر للتاجر
```
📋 Found merchant → 
🏪 Found 0 stores ❌
⚠️ Error: "لم يتم العثور على متجر مرتبط بالتاجر"
```

**الحل:**
- تأكد من أن الـ trigger `handle_new_user()` يعمل بشكل صحيح
- تحقق من قاعدة البيانات: `SELECT * FROM stores WHERE merchant_id = '<merchant-id>'`

### ❌ السيناريو 2: StoreId فارغ عند الحفظ
```
📋 Found merchant → 
🏪 Found store → 
✅ Store ID set → 
💾 Saving with storeId: null ❌
```

**الحل:**
- المشكلة في حالة الـ State
- تحقق من أن `_storeId` يتم تعيينه في `setState()`

### ❌ السيناريو 3: Merchant غير موجود
```
📋 Merchant ID: null ❌
⚠️ Error: "لم يتم العثور على بيانات التاجر"
```

**الحل:**
- تأكد من تسجيل الدخول كتاجر
- تحقق من جدول `profiles`: `SELECT * FROM profiles WHERE id = auth.uid()`
- تحقق من جدول `merchants`: `SELECT * FROM merchants WHERE id = '<profile-id>'`

## التحقق من قاعدة البيانات

### 1. التحقق من وجود المتجر
```sql
-- استبدل <merchant-id> بالـ ID الفعلي
SELECT 
  s.id as store_id,
  s.name as store_name,
  s.merchant_id,
  m.store_name as merchant_store_name
FROM stores s
JOIN merchants m ON s.merchant_id = m.id
WHERE s.merchant_id = '<merchant-id>';
```

### 2. التحقق من المنتجات المحفوظة
```sql
-- بعد حفظ المنتج
SELECT 
  p.id,
  p.name,
  p.store_id,
  s.merchant_id,
  m.store_name
FROM products p
JOIN stores s ON p.store_id = s.id
JOIN merchants m ON s.merchant_id = m.id
WHERE s.merchant_id = '<merchant-id>'
ORDER BY p.created_at DESC
LIMIT 10;
```

### 3. التحقق من اكتمال بيانات التاجر
```sql
SELECT * FROM get_merchant_complete_status('<user-id>');
```

## الخطوات التالية

إذا استمرت المشكلة بعد هذه التحديثات:

1. **شارك السجلات (Logs)** من Debug Console
2. **تحقق من نتائج الاستعلامات SQL** أعلاه
3. **تأكد من تطبيق الـ migrations** الجديدة في قاعدة البيانات
4. **افحص RLS Policies** للتأكد من السماح بإنشاء المنتجات

---

**تاريخ التحديث:** 2024  
**الحالة:** ✅ تم إضافة Logging شامل  
**الأولوية:** 🔴 عالية
