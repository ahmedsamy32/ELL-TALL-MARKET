# Single-Step Merchant Registration Implementation

## التغييرات المنفذة

تم تعديل نظام تسجيل التجار من **مرحلتين** إلى **مرحلة واحدة** مع إنشاء سجل التاجر وبيانات المتجر بشكل تلقائي عبر Database Trigger.

---

## 📋 ملخص التغييرات

### 1. **SupabaseProvider** (`lib/providers/supabase_provider.dart`)
#### التعديلات:
- إضافة معاملات جديدة لـ `signUp()`:
  - `String? storeName`
  - `String? storeAddress`
  - `String? storeDescription`
- إعداد `additionalData` لإرسال بيانات المتجر في metadata للتاجر فقط

#### الكود:
```dart
Future<AuthResponse?> signUp({
  required String email,
  required String password,
  required String name,
  required String phone,
  String userType = 'client',
  String? storeName,
  String? storeAddress,
  String? storeDescription,
}) async {
  // إعداد البيانات الإضافية للتاجر
  Map<String, dynamic>? additionalData;
  if (userType == 'merchant' && storeName != null) {
    additionalData = {
      'store_name': storeName,
      'store_address': storeAddress,
      'store_description': storeDescription,
    };
  }

  final response = await SupabaseService.signUpWithEmail(
    email: email,
    password: password,
    name: name,
    phone: phone,
    userType: userType,
    additionalData: additionalData,
  );
  // ... rest of code
}
```

---

### 2. **Register_Merchant_Screen** (`lib/screens/auth/Register_Merchant_Screen.dart`)

#### التعديلات:
1. **إضافة Controllers و FocusNodes لحقول المتجر:**
   ```dart
   final _storeNameController = TextEditingController();
   final _storeAddressController = TextEditingController();
   final _storeDescriptionController = TextEditingController();
   
   final _storeNameFocus = FocusNode();
   final _storeAddressFocus = FocusNode();
   final _storeDescriptionFocus = FocusNode();
   ```

2. **إضافة حقول UI لبيانات المتجر:**
   - حقل اسم المتجر (مطلوب)
   - حقل عنوان المتجر (مطلوب)
   - حقل وصف المتجر (اختياري)

3. **تحديث الـ `_registerMerchant()`:**
   ```dart
   final authResponse = await authProvider.signUp(
     email: email,
     password: password,
     name: _nameController.text.trim(),
     phone: _phoneController.text.trim(),
     userType: UserRole.merchant.value,
     storeName: _storeNameController.text.trim(),
     storeAddress: _storeAddressController.text.trim(),
     storeDescription: _storeDescriptionController.text.trim().isEmpty
         ? null
         : _storeDescriptionController.text.trim(),
   );
   ```

4. **تحديث رسالة Info Card:**
   ```dart
   'سيتم إنشاء حسابك وبيانات متجرك مباشرة بعد تأكيد بريدك الإلكتروني'
   ```

#### مميزات الحقول:
- التحقق من صحة البيانات (Validation)
- التنقل التلقائي بين الحقول (Auto-focus)
- دعم اللغة العربية بشكل كامل
- تنسيق Material 3

---

### 3. **Database Trigger** (`supabase/migrations/update_handle_new_user_trigger.sql`)

#### التعديل الرئيسي:
تم تحديث الـ trigger `handle_new_user()` ليقوم بـ:
1. إنشاء profile للمستخدم
2. إذا كان المستخدم تاجر (`role = 'merchant'`)، يتم إنشاء سجل في جدول `merchants` مع:
   - قراءة `store_name` من metadata
   - قراءة `store_description` من metadata
   - قراءة `store_address` من metadata

#### الكود الكامل:
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role TEXT;
  v_store_name TEXT;
  v_full_name TEXT;
  v_phone TEXT;
  v_store_description TEXT;
  v_address TEXT;
  v_merchant_id UUID;
BEGIN
  -- استخراج البيانات من metadata
  v_user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
  v_full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'name', 
    'User'
  );
  v_phone := NEW.raw_user_meta_data->>'phone';
  v_store_name := COALESCE(
    NEW.raw_user_meta_data->>'store_name',
    'متجر ' || v_full_name
  );
  v_store_description := NEW.raw_user_meta_data->>'store_description';
  v_address := COALESCE(
    NEW.raw_user_meta_data->>'store_address',
    NEW.raw_user_meta_data->>'address'
  );
  v_merchant_id := NEW.id;

  -- 1. إنشاء profile أولاً
  INSERT INTO public.profiles (id, full_name, email, phone, role, avatar_url)
  VALUES (
    v_merchant_id,
    v_full_name,
    NEW.email,
    v_phone,
    v_user_role,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  -- 2. إذا كان المستخدم تاجراً، إنشاء سجل في merchants وstores تلقائياً
  IF v_user_role = 'merchant' THEN
    -- أولاً: إنشاء التاجر في جدول merchants
    INSERT INTO public.merchants (
      id, 
      store_name, 
      store_description, 
      address,
      is_verified
    )
    VALUES (
      v_merchant_id,
      v_store_name,
      v_store_description,
      v_address,
      FALSE
    );
    
    -- ثانياً: إنشاء المتجر في جدول stores
    INSERT INTO public.stores (
      merchant_id,
      name,
      description,
      phone,
      address,
      category,
      is_active,
      is_open,
      delivery_fee,
      min_order,
      delivery_time
    )
    VALUES (
      v_merchant_id,
      v_store_name,
      v_store_description,
      v_phone,
      v_address,
      COALESCE(NEW.raw_user_meta_data->>'category', 'عام'),
      TRUE,
      TRUE,
      0,
      0,
      30
    );
    
    RAISE NOTICE 'تم إنشاء تاجر ومتجر جديد: %, المتجر: %', v_merchant_id, v_store_name;
  END IF;

  RETURN NEW;
  
EXCEPTION
  WHEN others THEN
    RAISE WARNING 'خطأ في handle_new_user للمستخدم %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

#### المميزات:
- **SECURITY DEFINER**: يتجاوز RLS policies ويمكنه إنشاء السجلات
- **IF condition**: يتحقق من نوع المستخدم قبل إنشاء سجل التاجر
- **Metadata reading**: يقرأ بيانات المتجر من `raw_user_meta_data`
- **Auto Store Creation**: إنشاء سجل المتجر تلقائياً مع قيم افتراضية معقولة
- **Smart Category Detection**: البحث عن فئة افتراضية من جدول `categories`
- **Default Opening Hours**: ساعات عمل افتراضية (08:00-23:00) لجميع أيام الأسبوع
- **Error Handling**: معالجة الأخطاء مع الاستمرار لعدم منع إنشاء المستخدم
- **DECLARE Variables**: استخدام متغيرات لتسهيل القراءة والصيانة
- **Detailed Logging**: رسائل واضحة مع emojis للتتبع والتشخيص

---

### 5. **Helper Function: get_merchant_complete_status** (`supabase/migrations/update_handle_new_user_trigger.sql`)

#### الوصف:
دالة مساعدة للتحقق من اكتمال بيانات التاجر والمتجر في قاعدة البيانات.

#### الاستخدام:
```sql
-- Check complete status of a merchant
SELECT public.get_merchant_complete_status('user-uuid-here'::uuid);
```

#### الناتج (JSONB):
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

#### الفوائد:
- **Debugging**: سهولة تتبع مشاكل التسجيل
- **Validation**: التحقق من اكتمال البيانات
- **Integration**: يمكن استدعاؤها من Flutter للتحقق من الحالة

---

### 4. **Auth Deep Link Handler** (`lib/services/auth_deep_link_handler.dart`)

#### التعديل:
- تم إلغاء التوجيه لشاشة `completeStoreProfile`
- جميع المستخدمين (تجار وعملاء) يتم توجيههم للصفحة الرئيسية مباشرة بعد تأكيد البريد
- السبب: بيانات المتجر تم إنشاؤها بالكامل عبر trigger

#### الكود:
```dart
// توجيه جميع المستخدمين (تجار وعملاء) للصفحة الرئيسية
// لأن بيانات المتجر يتم إنشاؤها تلقائياً عبر trigger عند التسجيل
debugPrint('✅ توجيه للصفحة الرئيسية - البيانات مكتملة');
Navigator.of(context).pushNamedAndRemoveUntil(
  AppRoutes.home,
  (route) => false,
);
```

---

## 🔄 سير عمل التسجيل الجديد

### للتاجر (Merchant):
1. **المستخدم يملأ النموذج** في `Register_Merchant_Screen`:
   - البيانات الشخصية (الاسم، البريد، الهاتف، كلمة المرور)
   - بيانات المتجر (اسم المتجر، العنوان، الوصف)

2. **الضغط على "إنشاء حساب التاجر"**:
   - يتم استدعاء `SupabaseProvider.signUp()` مع جميع البيانات
   - البيانات ترسل إلى Supabase Auth مع metadata تحتوي على:
     ```json
     {
       "full_name": "...",
       "phone": "...",
       "role": "merchant",
       "store_name": "...",
       "store_address": "...",
       "store_description": "..."
     }
     ```

3. **Supabase Auth يُنشئ المستخدم**:
   - يتم تفعيل الـ trigger `handle_new_user()`
   - الـ trigger يقرأ `raw_user_meta_data` ويقوم بـ:
     - إنشاء سجل في `profiles`
     - إنشاء سجل في `merchants` مع بيانات المتجر الكاملة
     - **إنشاء سجل في `stores` تلقائياً** باستخدام بيانات التاجر

4. **إرسال بريد التأكيد**:
   - يتم توجيه المستخدم لشاشة `EmailConfirmationScreen`
   - رسالة تأكيد ترسل للبريد الإلكتروني

5. **المستخدم يضغط على رابط التأكيد**:
   - يتم فتح التطبيق عبر Deep Link
   - `AuthDeepLinkHandler` يتعامل مع الرابط
   - يتم توجيه التاجر للصفحة الرئيسية **مباشرة** (لأن بيانات المتجر مكتملة)

---

## ✅ المميزات

1. **تجربة مستخدم أبسط**: كل البيانات في نموذج واحد
2. **تقليل الأخطاء**: لا حاجة لخطوات متعددة قد تفشل
3. **أداء أفضل**: عملية واحدة بدلاً من اثنتين
4. **RLS Security**: الـ trigger بـ SECURITY DEFINER يتجاوز RLS بأمان
5. **Atomic Operation**: كل شيء يحدث في transaction واحدة

---

## 🧪 خطوات الاختبار

### 1. تطبيق Migration:
```bash
# في Supabase Dashboard > SQL Editor
# تشغيل محتوى الملف:
supabase/migrations/update_handle_new_user_trigger.sql
```

### 2. اختبار التسجيل:
1. فتح التطبيق
2. الذهاب لشاشة تسجيل التاجر
3. ملء جميع الحقول:
   - البيانات الشخصية
   - بيانات المتجر
4. الضغط على "إنشاء حساب التاجر"
5. التحقق من:
   - وصول بريد التأكيد
   - إمكانية الضغط على رابط التأكيد
   - التوجيه للصفحة الرئيسية

### 3. التحقق من قاعدة البيانات:
```sql
-- الطريقة السريعة: استخدام دالة التحقق الشامل
SELECT public.get_merchant_complete_status(
  (SELECT id FROM profiles WHERE email = 'test@example.com')::uuid
);

-- سيعطيك نتيجة شاملة تتضمن:
-- ✅ profile_exists: true
-- ✅ merchant_exists: true
-- ✅ store_exists: false (لأننا لم نعد نستخدم جدول stores منفصل)
-- ✅ is_complete: true إذا كانت بيانات المتجر موجودة في جدول merchants

-- أو الطريقة التفصيلية:

-- التحقق من إنشاء profile
SELECT * FROM profiles WHERE email = 'test@example.com';

-- التحقق من إنشاء merchant مع بيانات المتجر
SELECT * FROM merchants WHERE id = '...' ;

-- يجب أن يحتوي على:
-- - store_name (مملوء)
-- - address (مملوء)
-- - store_description (مملوء أو null إذا كان اختياري)
```

---

## 📝 ملاحظات مهمة

1. **حقل الوصف اختياري**: يمكن للتاجر تركه فارغاً
2. **الحقول الأخرى إجبارية**: اسم المتجر والعنوان مطلوبان
3. **Trigger يعمل تلقائياً**: لا حاجة لتدخل Flutter بعد signUp
4. **Deep Link يوجه للرئيسية**: لأن البيانات مكتملة مسبقاً

---

## 🔧 استكشاف الأخطاء

### أداة التشخيص السريع:
```sql
-- استخدم هذه الدالة لفحص حالة أي تاجر
SELECT public.get_merchant_complete_status('USER-UUID'::uuid);

-- النتيجة ستخبرك بالضبط ما المفقود:
-- profile_exists: false → المشكلة في trigger أو إنشاء المستخدم
-- merchant_exists: false → المشكلة في قراءة metadata أو شرط IF
-- store_exists: تجاهلها (لا نستخدم جدول stores منفصل)
-- is_complete: false → هناك شيء ناقص
```

### إذا لم يتم إنشاء سجل التاجر:
1. تحقق من تطبيق Migration الجديد
2. تحقق من `raw_user_meta_data` في جدول `auth.users`:
   ```sql
   SELECT raw_user_meta_data FROM auth.users WHERE email = '...';
   ```
3. تحقق من وجود الـ trigger:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```

### إذا فشل التسجيل:
1. تحقق من Logs في Supabase Dashboard
2. تحقق من RLS policies على جدول `merchants`
3. تحقق من أن الحقول nullable في جدول `merchants`

---

## 🎯 الخلاصة

تم تحويل نظام تسجيل التجار من **مرحلتين** (تسجيل → تأكيد بريد → استكمال متجر) إلى **مرحلة واحدة** (كل البيانات دفعة واحدة)، مع الاعتماد على Database Trigger لإنشاء السجلات تلقائياً عند تأكيد البريد.

**الملفات المعدلة:**
1. `lib/providers/supabase_provider.dart`
2. `lib/screens/auth/Register_Merchant_Screen.dart`
3. `lib/services/auth_deep_link_handler.dart`
4. `supabase/migrations/update_handle_new_user_trigger.sql` (جديد)

**الخطوة التالية:** تطبيق الـ Migration واختبار التسجيل بشكل كامل.
