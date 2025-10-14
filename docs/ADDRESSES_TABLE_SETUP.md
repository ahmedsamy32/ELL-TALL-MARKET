# إنشاء جدول Addresses في Supabase

## الخطوات:

### 1. افتح Supabase Dashboard
- اذهب إلى: https://app.supabase.com
- اختر مشروعك: **ebbkdhmwaawzxbidjynz**

### 2. افتح SQL Editor
- من القائمة الجانبية اختر **SQL Editor**
- اضغط على **+ New query**

### 3. انسخ والصق SQL
- انسخ محتوى الملف: `supabase/migrations/20241012_create_addresses_table.sql`
- الصقه في SQL Editor

### 4. نفذ الـ Query
- اضغط على **Run** أو `Ctrl+Enter`
- انتظر رسالة **Success**

### 5. تحقق من الجدول
- اذهب إلى **Table Editor**
- يجب أن ترى جدول جديد اسمه `addresses`

## محتويات جدول Addresses:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | معرّف فريد للعنوان |
| `client_id` | UUID | معرّف المستخدم (foreign key) |
| `label` | VARCHAR | تصنيف العنوان (مثل: المنزل، العمل) |
| `city` | VARCHAR | المدينة/المنطقة |
| `street` | VARCHAR | الشارع |
| `area` | VARCHAR | الحي |
| `building_number` | VARCHAR | رقم المبنى |
| `floor_number` | VARCHAR | رقم الطابق |
| `apartment_number` | VARCHAR | رقم الشقة |
| `latitude` | DOUBLE | خط العرض (GPS) |
| `longitude` | DOUBLE | خط الطول (GPS) |
| `notes` | TEXT | ملاحظات/علامة مميزة |
| `is_default` | BOOLEAN | هل هذا العنوان الافتراضي |
| `created_at` | TIMESTAMP | تاريخ الإنشاء |
| `updated_at` | TIMESTAMP | تاريخ آخر تعديل |

## الميزات المُضافة:

✅ **Row Level Security (RLS)** - كل مستخدم يرى عناوينه فقط
✅ **Indexes** - لتسريع الاستعلامات
✅ **Policies** - صلاحيات للمستخدمين، المشرفين، والكباتن
✅ **Triggers** - 
   - تحديث `updated_at` تلقائياً
   - عنوان افتراضي واحد فقط لكل مستخدم
✅ **Foreign Keys** - ربط مع جدول المستخدمين

## بعد تطبيق الـ Migration:

التطبيق سيعمل بشكل طبيعي وستتمكن من:
- ✅ حفظ عناوين التوصيل
- ✅ تحديد الموقع على الخريطة
- ✅ تعيين عنوان افتراضي
- ✅ تعديل وحذف العناوين

## إذا واجهت مشكلة:

1. تأكد من أنك مسجل دخول في Supabase Dashboard
2. تأكد من اختيار المشروع الصحيح
3. تحقق من عدم وجود أخطاء في SQL Editor
4. جرب تحديث الصفحة (Refresh) بعد التطبيق

---

**ملاحظة:** لست بحاجة لإعادة تشغيل التطبيق، فقط أعد تحميل الصفحة (Hot Reload).
