# 📋 دليل مزامنة قاعدة البيانات
**تاريخ التحديث:** 4 نوفمبر 2025

## 📌 نظرة عامة

تم دمج جميع الجداول المنفصلة في ملف السكيما الرئيسي `Supabase_schema.sql` لضمان التوافق الكامل بين التطبيق وقاعدة البيانات.

---

## ✅ الجداول المضافة حديثاً

### 1️⃣ **جدول أقسام المتجر** `store_sections`
**الموقع:** `supabase/migrations/Supabase_schema.sql`

```sql
CREATE TABLE IF NOT EXISTS public.store_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  image_url text,
  display_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
```

**الغرض:**
- إدارة أقسام القائمة الخاصة بكل متجر (مستقلة عن الفئات العامة)
- يستخدم في شاشة إعدادات التاجر (`MerchantSettingsScreen`)

**الاستخدام في التطبيق:**
- Model: `lib/models/store_category_model.dart`
- Service: `lib/services/store_category_service.dart`
- Provider: `lib/providers/store_category_provider.dart`

---

### 2️⃣ **الجداول المساعدة للمتاجر**

#### أ) **فروع المتجر** `store_branches`
```sql
CREATE TABLE IF NOT EXISTS public.store_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text,
  address text NOT NULL,
  phone text,
  latitude double precision,
  longitude double precision,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
```

#### ب) **مناطق التوصيل** `store_delivery_areas`
```sql
CREATE TABLE IF NOT EXISTS public.store_delivery_areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  area_name text NOT NULL,
  fee numeric(10,2) NOT NULL DEFAULT 0,
  min_order numeric(10,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
```

#### ج) **طرق الدفع** `store_payment_methods`
```sql
CREATE TABLE IF NOT EXISTS public.store_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  method public.payment_method NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

#### د) **أوقات العمل** `store_order_windows`
```sql
CREATE TABLE IF NOT EXISTS public.store_order_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  open_time time NOT NULL,
  close_time time NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

#### هـ) **ربط الفئات بالمتاجر** `store_categories`
```sql
CREATE TABLE IF NOT EXISTS public.store_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  display_order int NOT NULL DEFAULT 0,
  is_visible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

## 🔧 تحديثات جدول المتاجر `stores`

تمت إضافة الحقول التالية لجدول `stores`:

```sql
ALTER TABLE public.stores
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS cover_url text,
  ADD COLUMN IF NOT EXISTS pickup_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS phones jsonb;
```

**الحقول الجديدة:**
- `email` - البريد الإلكتروني للمتجر
- `cover_url` - رابط صورة الغلاف
- `pickup_enabled` - تفعيل خدمة الاستلام من المتجر
- `phones` - قائمة بأرقام هواتف إضافية (JSON)

---

## 🛡️ سياسات RLS

تم إضافة سياسات RLS محسّنة لجميع الجداول الجديدة:

### نمط السياسات:
```sql
-- القراءة العامة للمتاجر النشطة
CREATE POLICY "table_public_read" ON public.table_name
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = table_name.store_id AND s.is_active = true)
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = table_name.store_id AND s.merchant_id = auth.uid())
  );

-- التحكم الكامل للمالك
CREATE POLICY "table_owner_manage" ON public.table_name
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = table_name.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = table_name.store_id AND s.merchant_id = auth.uid()));
```

---

## 📦 كيفية التطبيق

### الطريقة الأولى: تشغيل السكيما الكامل (موصى به للبداية)

1. افتح **Supabase SQL Editor**
2. احذف جميع البيانات الحالية (إذا كانت تطوير):
   ```sql
   -- تحذير: سيحذف جميع البيانات!
   DROP SCHEMA public CASCADE;
   CREATE SCHEMA public;
   GRANT ALL ON SCHEMA public TO postgres;
   GRANT ALL ON SCHEMA public TO public;
   ```

3. انسخ محتوى `supabase/migrations/Supabase_schema.sql` بالكامل
4. الصق وشغّل في SQL Editor
5. تحقق من إنشاء الجداول:
   ```sql
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   ORDER BY table_name;
   ```

### الطريقة الثانية: تطبيق التحديثات فقط (للقواعد الموجودة)

إذا كانت لديك بيانات موجودة، شغّل الملف:
```bash
supabase/migrations/2025-11-01_store_settings_and_rls.sql
```

هذا الملف:
- يضيف الأعمدة الجديدة بأمان (`IF NOT EXISTS`)
- لا يحذف أي بيانات موجودة
- يمكن تشغيله عدة مرات بأمان

---

## 🔍 التحقق من التطبيق

بعد تطبيق التحديثات، تحقق من:

### 1. وجود الجداول:
```sql
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'store_sections'
);
```

### 2. سياسات RLS:
```sql
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename LIKE 'store_%'
ORDER BY tablename, policyname;
```

### 3. الفهارس:
```sql
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename LIKE 'store_%'
ORDER BY tablename;
```

---

## 🎯 الاستخدام في التطبيق

### مثال: إضافة قسم متجر
```dart
final provider = context.read<StoreCategoryProvider>();
await provider.add(
  'قسم جديد',
  description: 'وصف القسم',
  isActive: true,
);
```

### مثال: جلب أقسام المتجر
```dart
final sections = await StoreCategoryService.getByStore(storeId);
```

### مثال: إعادة ترتيب الأقسام
```dart
await provider.moveUp(sectionId);
await provider.moveDown(sectionId);
```

---

## 📊 الفرق بين الجداول

| الجدول | الغرض | يديره |
|--------|-------|--------|
| `categories` | الفئات العامة للتطبيق | الأدمن |
| `store_categories` | ربط المتاجر بالفئات العامة | التاجر |
| `store_sections` | أقسام القائمة الخاصة بالمتجر | التاجر |

**مهم:** `store_sections` مستقل تماماً عن `categories` ويستخدم لتنظيم المنتجات داخل المتجر.

---

## 🚨 ملاحظات مهمة

1. **النسخ الاحتياطي**: احفظ نسخة احتياطية قبل تطبيق أي تحديثات
2. **البيئة**: طبّق على بيئة التطوير أولاً
3. **الـ Migration السابق**: الملف `2025-11-01_store_settings_and_rls.sql` موجود للمرجعية فقط
4. **السكيما الرئيسي**: استخدم `Supabase_schema.sql` كمصدر واحد للحقيقة

---

## ✅ قائمة التحقق

- [ ] تطبيق السكيما على Supabase
- [ ] التحقق من إنشاء جميع الجداول
- [ ] التحقق من سياسات RLS
- [ ] اختبار إضافة/تعديل/حذف قسم متجر
- [ ] التحقق من ظهور البيانات في التطبيق
- [ ] اختبار إعادة الترتيب
- [ ] اختبار التبديل بين نشط/غير نشط

---

## 📞 الدعم

إذا واجهت أي مشاكل:
1. راجع ملف `DEVELOPER_GUIDE.md`
2. تحقق من سجلات Supabase
3. افحص أخطاء التطبيق في Flutter DevTools
4. تأكد من صلاحيات RLS

---

**آخر تحديث:** 4 نوفمبر 2025  
**الإصدار:** 2.1  
**الحالة:** ✅ جاهز للتطبيق
