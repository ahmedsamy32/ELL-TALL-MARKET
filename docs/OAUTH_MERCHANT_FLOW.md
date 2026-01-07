# 🔐 آلية تسجيل التجار عبر Google/Facebook OAuth

## 📊 **المشكلة الأساسية**

عند استخدام OAuth (Google/Facebook)، **لا يمكن إرسال metadata مخصص** مثل:
- `role = 'merchant'`
- `store_name`
- `store_address`
- `category`

لأن OAuth يُنشئ الحساب مباشرة في `auth.users` بدون التحكم في metadata.

---

## ✅ **الحل المُطبق**

### **1. تسجيل دخول OAuth عادي**
```dart
// في register_merchant_screen.dart
final ok = await authProvider.signInWithGoogle(userType: 'merchant');
```

**ما يحدث:**
- ✅ يفتح متصفح Google OAuth
- ✅ المستخدم يسجل دخول بحساب Google
- ✅ Supabase يُنشئ حساب جديد بـ `role = 'client'` (افتراضي)
- ✅ يتم إنشاء سجل في `profiles` فقط

---

### **2. جمع بيانات المتجر**
```dart
// بعد تسجيل الدخول الناجح
setState(() => _currentStep = 1); // الانتقال لصفحة بيانات المتجر
```

**ما يحدث:**
- المستخدم يدخل:
  - اسم المتجر
  - عنوان المتجر
  - وصف المتجر (اختياري)
  - فئة المتجر
  - صورة شعار المتجر (إجباري)
- يوافق على الشروط والأحكام

---

### **3. ترقية الحساب إلى تاجر**
```dart
// عند الضغط على "إنشاء حساب التاجر"
final success = await authProvider.upgradeToMerchant(
  storeName: _storeNameController.text.trim(),
  storeAddress: _storeAddressController.text.trim(),
  storeDescription: _storeDescriptionController.text.trim(),
  category: _selectedCategory,
  storeLogoUrl: logoUrl,
);
```

**ما يحدث في `upgradeToMerchant()`:**

#### **أ. تحديث role في `profiles`**
```dart
await Supabase.instance.client.from('profiles').update({
  'role': 'merchant',
}).eq('id', currentUser.id);
```

#### **ب. إنشاء سجل في `merchants`**
```dart
await Supabase.instance.client.from('merchants').insert({
  'id': currentUser.id,
  'store_name': storeName,
  'store_description': storeDescription,
  'address': storeAddress,
  'is_verified': false, // سيتم التحقق من قبل الإدارة
});
```

#### **ج. إنشاء سجل في `stores`**
```dart
await Supabase.instance.client.from('stores').insert({
  'merchant_id': currentUser.id,
  'name': storeName,
  'description': storeDescription,
  'address': storeAddress,
  'category': category,
  'logo_url': storeLogoUrl,
  'is_active': true,
});
```

#### **د. إعادة تحميل الـ Profile**
```dart
await refreshProfile(); // لتحديث role في الواجهة
```

---

## 🔄 **مقارنة: التسجيل العادي vs OAuth**

### **تسجيل عادي (Email + Password):**
```
1. المستخدم يدخل جميع البيانات (خطوة 1 + خطوة 2)
2. الضغط على "إنشاء حساب"
3. signUp() ترسل metadata كامل:
   - role = 'merchant'
   - store_name
   - store_address
   - category
   - store_logo_url
4. Trigger handle_new_user() يُنشئ:
   ✅ profiles (role = 'merchant')
   ✅ merchants
   ✅ stores
5. توجيه لصفحة تأكيد البريد
```

### **تسجيل OAuth (Google/Facebook):**
```
1. المستخدم يضغط "Google" في الخطوة 1
2. signInWithGoogle() يفتح المتصفح
3. المستخدم يسجل دخول بـ Google
4. Supabase يُنشئ حساب:
   ✅ profiles (role = 'client') ❌ ليس merchant!
   ❌ لا يُنشأ merchants
   ❌ لا يُنشأ stores
5. الانتقال تلقائياً للخطوة 2 (بيانات المتجر)
6. المستخدم يدخل بيانات المتجر
7. الضغط على "إنشاء حساب التاجر"
8. upgradeToMerchant() تُحدّث:
   ✅ profiles.role = 'merchant'
   ✅ تُنشئ merchants
   ✅ تُنشئ stores
9. توجيه مباشرة لـ merchantDashboard (لا حاجة لتأكيد البريد)
```

---

## 📝 **ملاحظات مهمة**

### **1. لماذا لا نستخدم `handle_new_user()` trigger في OAuth؟**
- ❌ OAuth لا يسمح بإرسال metadata مخصص
- ❌ Trigger يعتمد على `raw_user_meta_data->>'role'`
- ❌ OAuth يُنشئ المستخدم بـ `role = 'client'` تلقائياً

### **2. هل يحتاج OAuth لتأكيد البريد؟**
- ✅ **لا!** Google/Facebook يؤكدون البريد بالفعل
- ✅ `user.email_confirmed_at` يكون موجوداً تلقائياً
- ✅ يمكن التوجيه مباشرة للوحة التاجر

### **3. ماذا لو كان المستخدم مسجل مسبقاً؟**
```dart
// في _buildSocialAuth
final ok = await authProvider.signInWithGoogle();
if (ok) {
  // التحقق من role
  final currentRole = authProvider.currentProfile?.role;
  
  if (currentRole == UserRole.merchant) {
    // المستخدم تاجر بالفعل - توجيه للوحة
    Navigator.pushReplacementNamed(context, AppRoutes.merchantDashboard);
  } else {
    // المستخدم عميل - السماح بالترقية
    setState(() => _currentStep = 1);
  }
}
```

### **4. أمان الترقية إلى merchant:**
```sql
-- في Supabase RLS Policies:

-- السماح للمستخدم بتحديث role الخاص به فقط
CREATE POLICY "Users can upgrade to merchant" ON profiles
  FOR UPDATE 
  USING (auth.uid() = id AND role = 'client')
  WITH CHECK (role = 'merchant');

-- السماح للمستخدم بإنشاء merchant record لنفسه فقط
CREATE POLICY "Users can create own merchant record" ON merchants
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- السماح للمستخدم بإنشاء store لنفسه فقط
CREATE POLICY "Merchants can create own store" ON stores
  FOR INSERT 
  WITH CHECK (auth.uid() = merchant_id);
```

---

## 🎯 **الخلاصة**

| **جانب** | **تسجيل عادي** | **OAuth** |
|----------|---------------|-----------|
| **البيانات المطلوبة** | اسم، بريد، هاتف، كلمة مرور، بيانات متجر | بيانات متجر فقط |
| **تأكيد البريد** | ✅ مطلوب | ❌ غير مطلوب |
| **إنشاء السجلات** | تلقائي عبر trigger | يدوي عبر `upgradeToMerchant()` |
| **الأمان** | SECURITY DEFINER trigger | RLS Policies |
| **التوجيه بعد التسجيل** | emailConfirmation → merchantDashboard | merchantDashboard مباشرة |

---

## 🔧 **الملفات المُعدلة**

1. **`lib/providers/supabase_provider.dart`:**
   - إضافة `upgradeToMerchant()` method
   - تحديث `signInWithGoogle()` لدعم `userType`

2. **`lib/screens/auth/Register_Merchant_Screen.dart`:**
   - تحديث `_buildSocialAuth()` لشرح الآلية
   - تحديث `_registerMerchant()` لدعم OAuth users

3. **`supabase/migrations/Supabase_schema.sql`** (مطلوب):**
   - إضافة RLS Policies لـ upgrade to merchant
   - إضافة Policies لـ merchants و stores INSERT

---

**آخر تحديث:** نوفمبر 2025
