# 🚀 دليل التطبيق السريع - نظام التسجيل الموحد

## ✨ ما الجديد؟
✅ **تسجيل موحد** - مرحلة واحدة فقط بدلاً من مرحلتين  
✅ **اختيار الفئة** - 12 فئة مع أيقونات جميلة  
✅ **بيانات كاملة** - كل معلومات المتجر في خطوة واحدة  
✅ **إنشاء تلقائي** - Trigger ينشئ Profile + Merchant + Store مباشرة  

---

## 📋 خطوات التطبيق (3 دقائق فقط!)

### 1️⃣ افتح Supabase Dashboard
```
🌐 https://supabase.com/dashboard
➡️ اختر مشروعك
➡️ SQL Editor
```

### 2️⃣ نفذ الأوامر بالترتيب

#### أولاً: إضافة عمود الأيقونات
```sql
-- 📂 انسخ من: supabase/migrations/add_icon_to_categories.sql
-- ▶️ الصق هنا واضغط Run

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'categories' AND column_name = 'icon') THEN
    ALTER TABLE public.categories ADD COLUMN icon TEXT;
    RAISE NOTICE 'تم إضافة عمود icon ✅';
  ELSE
    RAISE NOTICE 'عمود icon موجود مسبقاً ✅';
  END IF;
END $$;
```

#### ثانياً: تحديث الـ Trigger
```sql
-- 📂 انسخ من: supabase/migrations/update_handle_new_user_trigger.sql
-- ▶️ الصق هنا واضغط Run
-- ⚡ ينشئ function و trigger للإنشاء التلقائي
```

#### ثالثاً: إضافة الفئات
```sql
-- 📂 انسخ من: supabase/migrations/seed_categories.sql
-- ▶️ الصق هنا واضغط Run
-- 🏷️ يضيف 12 فئة بأيقوناتها
```

### 3️⃣ تأكد من النجاح
```sql
-- تحقق من الفئات
SELECT name, icon FROM categories WHERE is_active = true ORDER BY name;

-- يجب أن ترى 12 فئة مع أيقوناتها ✅
```

---

## 🧪 اختبر الآن!

### في التطبيق:
1. 📱 افتح شاشة "تسجيل تاجر جديد"
2. 👀 يجب أن تظهر قائمة الفئات مع الأيقونات
3. ✍️ املأ كل الحقول:
   - البريد الإلكتروني
   - كلمة المرور
   - الاسم الكامل
   - رقم الهاتف
   - اسم المتجر
   - عنوان المتجر
   - وصف المتجر
   - **فئة المتجر** ← اختر من القائمة
4. ✅ اضغط "تسجيل"
5. 📧 افحص البريد الإلكتروني للتأكيد

### في قاعدة البيانات:
```sql
-- ابحث عن آخر تاجر مسجل
SELECT 
  p.email,
  p.full_name,
  m.store_name,
  s.category,
  c.name as category_name,
  c.icon
FROM profiles p
LEFT JOIN merchants m ON p.id = m.id
LEFT JOIN stores s ON m.id = s.merchant_id
LEFT JOIN categories c ON s.category = c.id::text
WHERE p.role = 'merchant'
ORDER BY p.created_at DESC
LIMIT 1;

-- يجب أن ترى كل البيانات محفوظة ✅
```

---

## 🎯 الفئات المتاحة

| الفئة | الأيقونة | الوصف |
|-------|---------|-------|
| 🏪 عام | `store` | متاجر عامة |
| 🍽️ مطاعم وأطعمة | `restaurant` | مطاعم ومحلات الأطعمة |
| 🛒 بقالة | `local_grocery_store` | محلات البقالة والسوبر ماركت |
| 📱 إلكترونيات | `devices` | أجهزة ومعدات إلكترونية |
| 👔 ملابس وأزياء | `checkroom` | محلات الملابس والإكسسوارات |
| 💆 تجميل وصحة | `spa` | منتجات التجميل والعناية |
| 🏡 منزل وحديقة | `home` | أدوات منزلية ومستلزمات الحدائق |
| ⚽ رياضة ولياقة | `sports` | معدات رياضية ولياقة بدنية |
| 📚 كتب وقرطاسية | `menu_book` | كتب ومستلزمات مكتبية |
| 🧸 ألعاب وأطفال | `toys` | ألعاب ومستلزمات الأطفال |
| 🐾 حيوانات أليفة | `pets` | مستلزمات الحيوانات الأليفة |
| 🛎️ خدمات | `room_service` | خدمات متنوعة |

---

## ❌ حل المشاكل الشائعة

### ❓ الفئات لا تظهر في التطبيق
```
✔️ تأكد من تشغيل seed_categories.sql
✔️ افحص السجلات في VS Code Debug Console
✔️ تحقق من الاتصال بالإنترنت
```

### ❓ خطأ "column icon does not exist"
```
✔️ شغل add_icon_to_categories.sql أولاً
✔️ أعد تشغيل seed_categories.sql
```

### ❓ Trigger لا يعمل
```
✔️ شغل update_handle_new_user_trigger.sql
✔️ افحص Logs في Supabase Dashboard
✔️ تأكد من تفعيل Email confirmations
```

### ❓ الأيقونات لا تظهر
```
✔️ تحقق من أن icon column يحتوي على قيم
✔️ تحديث التطبيق (Hot Reload)
✔️ افحص switch statement في الكود
```

---

## 📞 تحتاج مساعدة؟

1. 📖 راجع: `MIGRATION_EXECUTION_PLAN.md` (تفاصيل كاملة)
2. 🔍 افحص السجلات في VS Code
3. 🗄️ تحقق من Supabase Dashboard → Logs
4. 💬 اسأل عن أي خطوة غير واضحة

---

## ✅ قائمة التحقق النهائية

- [ ] ✅ تم تطبيق add_icon_to_categories.sql
- [ ] ✅ تم تطبيق update_handle_new_user_trigger.sql
- [ ] ✅ تم تطبيق seed_categories.sql
- [ ] ✅ تظهر الفئات مع الأيقونات في التطبيق
- [ ] ✅ التسجيل يعمل بنجاح
- [ ] ✅ يتم إنشاء السجلات تلقائياً في قاعدة البيانات

---

**🎉 مبروك! نظام التسجيل الموحد جاهز الآن!**
