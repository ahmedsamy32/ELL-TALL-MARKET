# دليل تطبيق Migration الجديد

## 🚀 الخطوات المطلوبة لتفعيل التسجيل بمرحلة واحدة

### 1️⃣ تطبيق Database Migration

#### الطريقة الأولى: Supabase Dashboard (موصى بها)
1. افتح [Supabase Dashboard](https://app.supabase.com)
2. اختر مشروعك
3. اذهب إلى **SQL Editor** من القائمة الجانبية
4. انسخ محتوى الملف:
   ```
   supabase/migrations/update_handle_new_user_trigger.sql
   ```
5. الصق الكود في المحرر
6. اضغط **Run** أو **F5**
7. تأكد من ظهور رسالة نجاح: `Success. No rows returned`

#### الطريقة الثانية: Supabase CLI
إذا كنت تستخدم Supabase CLI:
```bash
# في مجلد المشروع
supabase db reset

# أو تطبيق migration محدد
supabase migration up
```

---

### 2️⃣ التحقق من نجاح التطبيق

#### فحص الـ Trigger:
```sql
-- في SQL Editor
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
```

**النتيجة المتوقعة:**
```
trigger_name          | event_manipulation | event_object_table
----------------------|--------------------|-----------------
on_auth_user_created | INSERT             | users
```

#### فحص الـ Function:
```sql
-- في SQL Editor
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';
```

**النتيجة المتوقعة:**
```
routine_name     | routine_type | security_type
-----------------|--------------|-------------
handle_new_user | FUNCTION     | DEFINER
```

---

### 3️⃣ اختبار التسجيل

#### خطوات الاختبار:
1. **افتح التطبيق** (Flutter App)
2. **اذهب لشاشة تسجيل التاجر**
3. **املأ جميع الحقول:**
   - الاسم الكامل: `تاجر تجريبي`
   - البريد الإلكتروني: `test-merchant@example.com`
   - رقم الهاتف: `01234567890`
   - كلمة المرور: `Test@123`
   - **اسم المتجر: `متجر تجريبي`**
   - **عنوان المتجر: `القاهرة، مصر`**
   - **وصف المتجر (اختياري): `متجر لبيع المنتجات`**
4. **اضغط "إنشاء حساب التاجر"**
5. **تحقق من البريد الإلكتروني** واضغط على رابط التأكيد
6. **يجب أن يتم توجيهك للصفحة الرئيسية مباشرة**

---

### 4️⃣ التحقق من قاعدة البيانات

#### بعد التسجيل، تحقق من:

**1. جدول Profiles:**
```sql
SELECT id, full_name, email, role
FROM profiles
WHERE email = 'test-merchant@example.com';
```

**النتيجة المتوقعة:**
```
id                  | full_name      | email                      | role
--------------------|----------------|---------------------------|--------
uuid-here          | تاجر تجريبي    | test-merchant@example.com | merchant
```

**2. جدول Merchants:**
```sql
SELECT id, store_name, address, store_description
FROM merchants
WHERE id = (
  SELECT id FROM profiles WHERE email = 'test-merchant@example.com'
);
```

**النتيجة المتوقعة:**
```
id         | store_name      | address         | store_description
-----------|-----------------|-----------------|---------------------------
uuid-here  | متجر تجريبي    | القاهرة، مصر    | متجر لبيع المنتجات
```

**3. Auth Metadata:**
```sql
SELECT 
  email,
  raw_user_meta_data->>'store_name' as store_name,
  raw_user_meta_data->>'store_address' as store_address
FROM auth.users
WHERE email = 'test-merchant@example.com';
```

**النتيجة المتوقعة:**
```
email                      | store_name      | store_address
---------------------------|-----------------|---------------
test-merchant@example.com  | متجر تجريبي    | القاهرة، مصر
```

**4. استخدام دالة التحقق الشامل:**
```sql
-- التحقق من الحالة الكاملة للتاجر
SELECT public.get_merchant_complete_status(
  (SELECT id FROM profiles WHERE email = 'test-merchant@example.com')::uuid
);
```

**النتيجة المتوقعة:**
```json
{
  "profile_exists": true,
  "merchant_exists": true,
  "store_exists": true,
  "user_id": "uuid-here",
  "is_complete": true,
  "profile_data": {...},
  "merchant_data": {...},
  "store_data": {...}
}
```

---

## ⚠️ استكشاف الأخطاء الشائعة

### المشكلة: Trigger لا يعمل
**الحل:**
```sql
-- احذف الـ trigger القديم
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- احذف الـ function القديم
DROP FUNCTION IF EXISTS public.handle_new_user();

-- ثم أعد تشغيل migration الجديد
```

### المشكلة: لا يتم إنشاء سجل التاجر
**الأسباب المحتملة:**
1. **Trigger غير موجود** → تحقق من الخطوة 2️⃣
2. **Metadata فارغة** → تحقق من كود Flutter (SupabaseProvider)
3. **RLS Policy تمنع** → تحقق من أن Function بـ `SECURITY DEFINER`

**الحل السريع - استخدام دالة التحقق:**
```sql
-- فحص شامل لحالة التاجر
SELECT public.get_merchant_complete_status('USER-UUID-HERE'::uuid);

-- النتيجة ستوضح:
-- profile_exists: هل البروفايل موجود؟
-- merchant_exists: هل سجل التاجر موجود؟
-- store_exists: هل المتجر موجود؟
-- is_complete: هل كل شيء مكتمل؟
```

**الحل التفصيلي:**
```sql
-- تحقق من RLS policies على جدول merchants
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies
WHERE tablename = 'merchants';

-- إذا كانت policies تمنع، تحقق من أن Function بـ SECURITY DEFINER
SELECT 
  routine_name,
  security_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';

-- يجب أن تكون: security_type = 'DEFINER'
```

### المشكلة: Deep Link لا يوجه للصفحة الرئيسية
**الحل:**
1. تأكد من تطبيق التعديلات على `auth_deep_link_handler.dart`
2. تحقق من Logs في التطبيق:
   ```
   [AuthDeepLinkHandler] ✅ توجيه للصفحة الرئيسية - البيانات مكتملة
   ```
3. أعد تشغيل التطبيق (Hot Restart)

---

## 📊 قائمة التحقق النهائية

- [ ] تم تطبيق Migration الجديد
- [ ] Trigger موجود في قاعدة البيانات
- [ ] Function بـ `SECURITY DEFINER`
- [ ] حقول المتجر ظاهرة في شاشة التسجيل
- [ ] التسجيل يعمل بدون أخطاء
- [ ] بريد التأكيد يصل
- [ ] رابط التأكيد يعمل
- [ ] التوجيه للصفحة الرئيسية يعمل
- [ ] سجل التاجر موجود في قاعدة البيانات
- [ ] بيانات المتجر مكتملة (store_name, address)

---

## 🎉 تهانينا!

إذا نجحت جميع الخطوات، فقد تم تطبيق النظام الجديد بنجاح! 🚀

**التسجيل الآن بمرحلة واحدة فقط:**
التاجر يملأ كل البيانات → يؤكد البريد → يدخل مباشرة للتطبيق ✅
