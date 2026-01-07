# خطة تطبيق الـ Migrations - نظام التسجيل الموحد

## 📋 نظرة عامة
هذا الملف يشرح الترتيب الصحيح لتطبيق migrations لتفعيل نظام التسجيل الموحد للتجار مع دعم الفئات والأيقونات.

## 🎯 الهدف
- تحويل التسجيل من مرحلتين إلى مرحلة واحدة
- إنشاء trigger تلقائي يقوم بإنشاء سجلات (profile + merchant + store) مباشرة
- دعم اختيار الفئة مع أيقونات توضيحية
- التأكد من تخزين كل البيانات التي يدخلها المستخدم فقط (بدون قيم افتراضية)

## ✅ التحديثات المكتملة

### 1. Flutter Code
- ✅ تحديث `Register_Merchant_Screen.dart`
  - إضافة حقول معلومات المتجر (الاسم، العنوان، الوصف)
  - إضافة اختيار الفئة مع أيقونات Material Icons
  - تحميل الفئات من قاعدة البيانات
  - إرسال كل البيانات مع Auth metadata

- ✅ تحديث `SupabaseProvider.dart`
  - إضافة معامل category
  - إرسال كل البيانات عبر additionalData

### 2. Database Schema
- ✅ تحديث `Supabase_schema.sql`
  - إضافة عمود icon إلى جدول categories

### 3. Migration Files
تم إنشاء 3 ملفات migrations جاهزة للتطبيق:

#### 1️⃣ `add_icon_to_categories.sql`
**الغرض:** إضافة عمود icon إلى جدول categories
**محتوى آمن:** يستخدم IF NOT EXISTS لتجنب الأخطاء
```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'categories' AND column_name = 'icon') THEN
    ALTER TABLE public.categories ADD COLUMN icon TEXT;
    RAISE NOTICE 'Column icon added to categories table';
  ELSE
    RAISE NOTICE 'Column icon already exists in categories table';
  END IF;
END $$;
```

#### 2️⃣ `update_handle_new_user_trigger.sql`
**الغرض:** إنشاء/تحديث trigger لإنشاء profile + merchant + store تلقائياً
**الميزات:**
- يقرأ كل البيانات من raw_user_meta_data
- ينشئ profile لكل المستخدمين
- للتجار: ينشئ merchant + store
- يستخدم SECURITY DEFINER لتجاوز RLS
- معالجة أخطاء شاملة
```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
-- ... الكود الكامل في الملف
```

#### 3️⃣ `seed_categories.sql`
**الغرض:** إضافة 12 فئة افتراضية مع أيقونات
**محتوى آمن:** يستخدم ON CONFLICT (name) DO NOTHING
**الفئات:**
- عام (store) 🏪
- مطاعم وأطعمة (restaurant) 🍽️
- بقالة (local_grocery_store) 🛒
- إلكترونيات (devices) 📱
- ملابس وأزياء (checkroom) 👔
- تجميل وصحة (spa) 💆
- منزل وحديقة (home) 🏡
- رياضة ولياقة (sports) ⚽
- كتب وقرطاسية (menu_book) 📚
- ألعاب وأطفال (toys) 🧸
- حيوانات أليفة (pets) 🐾
- خدمات (room_service) 🛎️

## 📝 الترتيب الصحيح للتطبيق

### الطريقة 1: عبر Supabase Dashboard (موصى بها)

1. **افتح Supabase Dashboard**
   - انتقل إلى مشروعك
   - اذهب إلى SQL Editor

2. **تطبيق Migration 1: إضافة عمود icon**
   ```
   📂 نسخ محتوى: supabase/migrations/add_icon_to_categories.sql
   ▶️ تشغيل في SQL Editor
   ✅ تحقق من الرسالة: "Column icon added" أو "already exists"
   ```

3. **تطبيق Migration 2: تحديث Trigger**
   ```
   📂 نسخ محتوى: supabase/migrations/update_handle_new_user_trigger.sql
   ▶️ تشغيل في SQL Editor
   ✅ تحقق من الرسالة: "Function created" و "Trigger created/updated"
   ```

4. **تطبيق Migration 3: إضافة الفئات**
   ```
   📂 نسخ محتوى: supabase/migrations/seed_categories.sql
   ▶️ تشغيل في SQL Editor
   ✅ تحقق من الرسالة: "INSERT 0 12" (أو أقل إذا كانت موجودة)
   ```

5. **التحقق من النتائج**
   ```sql
   -- تحقق من وجود عمود icon
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'categories' AND column_name = 'icon';
   
   -- تحقق من الفئات
   SELECT id, name, icon, is_active FROM categories ORDER BY name;
   
   -- تحقق من الـ trigger
   SELECT trigger_name, event_manipulation, event_object_table 
   FROM information_schema.triggers 
   WHERE trigger_name = 'on_auth_user_created';
   
   -- تحقق من الـ function
   SELECT routine_name, routine_type 
   FROM information_schema.routines 
   WHERE routine_name = 'handle_new_user';
   ```

### الطريقة 2: عبر Supabase CLI (للمتقدمين)

```bash
# 1. التأكد من تسجيل الدخول
supabase login

# 2. ربط المشروع
supabase link --project-ref YOUR_PROJECT_REF

# 3. تطبيق كل الـ migrations
supabase db push

# 4. التحقق من الحالة
supabase db diff
```

## 🧪 اختبار التطبيق

### 1. اختبار عرض الفئات
- افتح التطبيق → شاشة تسجيل التاجر
- تأكد من ظهور قائمة الفئات مع الأيقونات
- جرب اختيار فئات مختلفة

### 2. اختبار التسجيل الكامل
```
1. افتح شاشة تسجيل التاجر
2. أدخل البيانات:
   - البريد الإلكتروني
   - كلمة المرور
   - الاسم الكامل
   - رقم الهاتف
   - اسم المتجر
   - عنوان المتجر
   - وصف المتجر
   - فئة المتجر
3. اضغط "تسجيل"
4. تحقق من:
   ✅ إرسال بريد التأكيد
   ✅ ظهور رسالة النجاح
```

### 3. اختبار إنشاء السجلات في قاعدة البيانات
```sql
-- بعد التسجيل، استخدم البريد الإلكتروني للتحقق

-- 1. تحقق من auth.users
SELECT id, email, email_confirmed_at, raw_user_meta_data 
FROM auth.users 
WHERE email = 'test@example.com';

-- 2. تحقق من profiles
SELECT id, full_name, email, phone, role 
FROM public.profiles 
WHERE email = 'test@example.com';

-- 3. تحقق من merchants
SELECT id, store_name, store_description, address, is_verified 
FROM public.merchants 
WHERE id IN (SELECT id FROM profiles WHERE email = 'test@example.com');

-- 4. تحقق من stores
SELECT merchant_id, name, description, phone, address, category 
FROM public.stores 
WHERE merchant_id IN (SELECT id FROM profiles WHERE email = 'test@example.com');

-- 5. تحقق من اكتمال البيانات
SELECT * FROM get_merchant_complete_status(
  (SELECT id FROM profiles WHERE email = 'test@example.com')
);
```

## 🐛 استكشاف الأخطاء

### المشكلة: "column icon does not exist"
**الحل:** تأكد من تطبيق `add_icon_to_categories.sql` أولاً

### المشكلة: لا تظهر الفئات في التطبيق
**الحل:** 
1. تحقق من تطبيق `seed_categories.sql`
2. تحقق من أن `is_active = true` للفئات
3. تحقق من سجلات AppLogger في التطبيق

### المشكلة: Trigger لا ينشئ السجلات
**الحل:**
1. تحقق من تطبيق `update_handle_new_user_trigger.sql`
2. افحص exception logs في Supabase Dashboard
3. تحقق من RLS policies لا تمنع الإنشاء

### المشكلة: الأيقونات لا تظهر
**الحل:**
1. تأكد من أن عمود icon يحتوي على قيم
2. تحقق من أن اسم الأيقونة يطابق Material Icons
3. راجع switch statement في `register_merchant_screen.dart`

## 📊 الحالة النهائية المتوقعة

### جدول categories
```
id | name           | description              | icon                  | is_active
---+----------------+--------------------------+----------------------+-----------
1  | عام            | متاجر عامة               | store                 | true
2  | مطاعم وأطعمة   | مطاعم ومحلات الأطعمة    | restaurant            | true
...
```

### Trigger & Function
- ✅ Function: `handle_new_user()` (SECURITY DEFINER)
- ✅ Trigger: `on_auth_user_created` على auth.users
- ✅ Event: AFTER INSERT

### Flutter App
- ✅ شاشة تسجيل موحدة بكل الحقول
- ✅ قائمة فئات مع أيقونات
- ✅ إرسال كل البيانات في طلب واحد
- ✅ معالجة أخطاء شاملة

## 📌 ملاحظات مهمة

1. **الأمان:**
   - الـ trigger يستخدم SECURITY DEFINER لتجاوز RLS مؤقتاً
   - يتم التحقق من user_id من auth.uid()
   - لا يمكن استغلاله من الخارج

2. **البيانات:**
   - كل البيانات تأتي من المستخدم (لا قيم افتراضية)
   - metadata محدود بـ 16KB (كافي للبيانات الحالية)
   - التحقق من الصحة يتم في Flutter و SQL

3. **التوافقية:**
   - كل الـ migrations آمنة للتطبيق المتكرر
   - تستخدم CREATE OR REPLACE, IF NOT EXISTS, ON CONFLICT
   - لا تؤثر على البيانات الموجودة

## 🎉 الخطوات التالية

بعد تطبيق الـ migrations بنجاح:
1. ✅ اختبار التسجيل الكامل
2. ⏭️ تحسين تجربة المستخدم (UX)
3. ⏭️ إضافة رفع صور المتجر
4. ⏭️ لوحة تحكم التاجر
5. ⏭️ نظام التحقق من المتاجر

---

**تاريخ الإنشاء:** 2024  
**الحالة:** ✅ جاهز للتطبيق  
**الأولوية:** 🔴 عالية
