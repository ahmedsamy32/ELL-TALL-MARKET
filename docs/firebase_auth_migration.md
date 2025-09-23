# تحديث قاعدة البيانات لدعم Firebase Auth

## 1. إضافة عمود Firebase ID

```sql
-- إضافة عمود firebase_id لربط المستخدمين مع Firebase Auth
ALTER TABLE profiles ADD COLUMN firebase_id TEXT UNIQUE;

-- إنشاء فهرس لتحسين الأداء
CREATE INDEX idx_profiles_firebase_id ON profiles(firebase_id);

-- إضافة تعليق للتوضيح
COMMENT ON COLUMN profiles.firebase_id IS 'Firebase Auth UID للربط مع نظام المصادقة';
```

## 2. تحديث RLS Policies

```sql
-- إزالة RLS policies القديمة المرتبطة بـ Supabase Auth
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;

-- إنشاء RLS policies جديدة (سيتم التحكم في الوصول من التطبيق)
CREATE POLICY "Allow all operations for service role" ON profiles
    FOR ALL USING (auth.role() = 'service_role');

-- للسماح للتطبيق بالوصول لجميع البيانات (سيتم التحكم في الأمان من Firebase)
CREATE POLICY "Allow app access" ON profiles
    FOR ALL USING (true);
```

## 3. إنشاء دالة للبحث بـ Firebase ID

```sql
-- دالة للبحث عن مستخدم بواسطة Firebase ID
CREATE OR REPLACE FUNCTION get_user_by_firebase_id(firebase_uid TEXT)
RETURNS TABLE (
    id UUID,
    firebase_id TEXT,
    name TEXT,
    email TEXT,
    phone TEXT,
    type TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_active BOOLEAN,
    last_login TIMESTAMPTZ,
    login_count INTEGER,
    address TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.firebase_id,
        p.name,
        p.email,
        p.phone,
        p.type,
        p.avatar_url,
        p.created_at,
        p.updated_at,
        p.is_active,
        p.last_login,
        p.login_count,
        p.address
    FROM profiles p
    WHERE p.firebase_id = firebase_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 4. دالة لإنشاء مستخدم جديد

```sql
-- دالة لإنشاء مستخدم جديد مع Firebase ID
CREATE OR REPLACE FUNCTION create_user_with_firebase_id(
    firebase_uid TEXT,
    user_name TEXT,
    user_email TEXT,
    user_phone TEXT DEFAULT '',
    user_type TEXT DEFAULT 'customer'
)
RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    INSERT INTO profiles (
        firebase_id,
        name,
        email,
        phone,
        type,
        is_active,
        created_at,
        login_count
    ) VALUES (
        firebase_uid,
        user_name,
        user_email,
        user_phone,
        user_type,
        true,
        NOW(),
        0
    )
    RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 5. دالة لتحديث آخر تسجيل دخول

```sql
-- دالة لتحديث آخر تسجيل دخول
CREATE OR REPLACE FUNCTION update_last_login(user_firebase_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE profiles 
    SET 
        last_login = NOW(),
        login_count = login_count + 1
    WHERE firebase_id = user_firebase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 6. ترحيل البيانات الموجودة (اختياري)

```sql
-- إذا كان لديك مستخدمين موجودين، يمكنك إنشاء Firebase IDs وهمية مؤقتة
-- هذا فقط للاختبار - في الواقع المستخدمون سيحتاجون إعادة تسجيل

UPDATE profiles 
SET firebase_id = 'temp_' || id::text 
WHERE firebase_id IS NULL;
```

## 7. تحديث أذونات الجداول الأخرى

```sql
-- تحديث جدول stores للعمل مع النظام الجديد
-- إضافة مرجع لـ profiles عبر user_id بدلاً من auth.uid()

-- تحديث RLS policies للجداول الأخرى
DROP POLICY IF EXISTS "Users can manage own stores" ON stores;

CREATE POLICY "Allow store management" ON stores
    FOR ALL 
    USING (
        user_id IN (
            SELECT id FROM profiles 
            WHERE firebase_id = current_setting('app.current_user_firebase_id', true)
        )
    );
```

## 8. دوال المساعدة

```sql
-- دالة للحصول على إحصائيات المستخدمين
CREATE OR REPLACE FUNCTION get_user_statistics()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total', (SELECT COUNT(*) FROM profiles),
        'active', (SELECT COUNT(*) FROM profiles WHERE is_active = true),
        'admins', (SELECT COUNT(*) FROM profiles WHERE type = 'admin'),
        'merchants', (SELECT COUNT(*) FROM profiles WHERE type = 'merchant'),
        'customers', (SELECT COUNT(*) FROM profiles WHERE type = 'customer'),
        'captains', (SELECT COUNT(*) FROM profiles WHERE type = 'captain')
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 9. الفهارس لتحسين الأداء

```sql
-- فهارس إضافية لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_type ON profiles(type);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);
```

## 10. تنظيف البيانات القديمة

```sql
-- إزالة البيانات المرتبطة بـ Supabase Auth (بعد التأكد من النقل)
-- هذا الأمر يتم تنفيذه بحذر بعد التأكد من أن كل شيء يعمل

-- حذف auth users من Supabase (بعد التأكد)
-- DELETE FROM auth.users WHERE email NOT LIKE '%admin%';
```

---

## ملاحظات مهمة:

1. **النسخ الاحتياطي**: تأكد من عمل نسخة احتياطية قبل تنفيذ أي تغييرات
2. **الاختبار**: اختبر على بيئة تطوير أولاً
3. **التدرج**: نفذ التغييرات تدريجياً وتحقق من كل خطوة
4. **المراقبة**: راقب النظام بعد التحديث للتأكد من عدم وجود مشاكل

## الاستخدام بعد التحديث:

```dart
// مثال على الاستخدام الجديد
final firebaseUser = FirebaseAuth.instance.currentUser;
if (firebaseUser != null) {
  final supabaseUser = await supabase
    .rpc('get_user_by_firebase_id', params: {
      'firebase_uid': firebaseUser.uid
    })
    .single();
}
```
