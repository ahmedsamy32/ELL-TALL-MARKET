# تطبيق Migration لتحديث كلمة المرور

## المشكلة
خطأ 403 عند محاولة استخدام Admin API لتحديث كلمة مرور المستخدم.

## الحل
تم إنشاء **Database Function** آمنة تسمح للـ Admin بتحديث كلمات المرور.

## خطوات التطبيق

### 1. تطبيق Migration على Supabase

افتح **Supabase Dashboard** → اذهب إلى **SQL Editor** وقم بتنفيذ الملف:
```
supabase/migrations/20260217_admin_update_user_password.sql
```

أو استخدم Supabase CLI:
```bash
supabase db push
```

### 2. التحقق من تطبيق الـ Function

في SQL Editor، قم بتنفيذ:
```sql
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'admin_update_user_password';
```

يجب أن يظهر:
```
routine_name               | routine_type
admin_update_user_password | FUNCTION
```

### 3. اختبار الـ Function

```sql
-- اختبار تغيير كلمة المرور لمستخدم معين
SELECT public.admin_update_user_password(
  'USER_ID_HERE'::uuid,
  'newPassword123'
);
```

## ما تم تغييره في الكود

### `lib/providers/supabase_provider.dart`
تم استبدال:
```dart
await Supabase.instance.client.auth.admin.updateUserById(...)
```

بـ:
```dart
await Supabase.instance.client.rpc('admin_update_user_password', ...)
```

## الأمان
- ✅ يتحقق من أن المستخدم الذي يقوم بالتعديل هو **Admin**
- ✅ يتحقق من طول كلمة المرور (6 أحرف على الأقل)
- ✅ يستخدم `SECURITY DEFINER` للوصول الآمن لجدول `auth.users`
- ✅ يُرجع رسائل خطأ واضحة في حالة الفشل

## ملاحظات
- الـ Function تعمل **فقط** للمستخدمين الذين `role = 'admin'` في جدول `profiles`
- يتم تشفير كلمة المرور تلقائياً باستخدام `bcrypt`
- لا يحتاج لـ Service Role Key على الكلاينت
