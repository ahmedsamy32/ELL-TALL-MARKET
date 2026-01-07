# 🔄 تحديث نظام التسجيل - دليل الاستخدام

## ✅ التحديثات المنفذة

تم تحديث نظام تسجيل التجار ليشمل إنشاء سجلات كاملة في جدول `stores` تلقائياً.

---

## 📋 ما الجديد؟

### 1. **Database Trigger محسّن**
- ✅ إنشاء `profile` تلقائياً
- ✅ إنشاء `merchant` تلقائياً مع بيانات المتجر
- ✅ **جديد:** إنشاء `store` تلقائياً مع:
  - اسم المتجر
  - وصف المتجر
  - رقم الهاتف
  - العنوان
  - الفئة (افتراضية أو محددة)
  - ساعات العمل الافتراضية (08:00-23:00)
  - حالة النشاط والفتح
  - معلومات التوصيل الافتراضية

### 2. **Flutter Code محسّن**
- ✅ إضافة معامل `category` اختياري في `signUp()`
- ✅ تعليقات توضيحية شاملة
- ✅ رسائل واضحة للمستخدم

---

## 💻 كيفية الاستخدام

### في شاشة التسجيل:

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
  // اختياري: يمكن إضافة الفئة إذا أضفنا حقل اختيار
  // category: selectedCategoryId,
);
```

### ما يحدث تلقائياً:

1. **Supabase Auth** ينشئ المستخدم
2. **Trigger** `handle_new_user()` يُفعّل تلقائياً
3. **Profile** يُنشأ في جدول `profiles`
4. **Merchant** يُنشأ في جدول `merchants` مع:
   ```sql
   - id = user_id
   - store_name = "من metadata"
   - store_description = "من metadata"
   - address = "من metadata"
   - is_verified = FALSE
   ```
5. **Store** يُنشأ في جدول `stores` مع:
   ```sql
   - merchant_id = user_id
   - name = store_name
   - description = store_description
   - phone = user_phone
   - address = store_address
   - category = "عام" (افتراضي) أو محدد
   - is_active = TRUE
   - is_open = TRUE
   - delivery_fee = 0
   - min_order = 0
   - delivery_time = 30
   - opening_hours = {...} (08:00-23:00 يومياً)
   ```

---

## 🎯 البيانات المرسلة في Metadata

```json
{
  "full_name": "اسم التاجر",
  "phone": "01234567890",
  "role": "merchant",
  "store_name": "اسم المتجر",
  "store_address": "عنوان المتجر",
  "store_description": "وصف المتجر",
  "category": "category-uuid" // اختياري
}
```

---

## 📊 هيكل قاعدة البيانات

### قبل التحديث:
```
auth.users → profiles + merchants
```

### بعد التحديث:
```
auth.users → profiles + merchants + stores
```

**كل شيء في transaction واحدة آمنة!** ✅

---

## 🔧 إضافة حقل اختيار الفئة (اختياري)

إذا أردت إضافة اختيار الفئة في الواجهة:

### 1. أضف State للفئة:
```dart
class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    // جلب الفئات من Supabase
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name')
        .eq('is_active', true);
    
    setState(() {
      _categories = List<Map<String, dynamic>>.from(response);
    });
  }
}
```

### 2. أضف Widget اختيار الفئة:
```dart
DropdownButtonFormField<String>(
  value: _selectedCategory,
  decoration: const InputDecoration(
    labelText: 'فئة المتجر',
    hintText: 'اختر فئة المتجر',
    prefixIcon: Icon(Icons.category_outlined),
  ),
  items: _categories.map((cat) {
    return DropdownMenuItem<String>(
      value: cat['id'],
      child: Text(cat['name']),
    );
  }).toList(),
  onChanged: (value) {
    setState(() => _selectedCategory = value);
  },
)
```

### 3. أرسل الفئة عند التسجيل:
```dart
final authResponse = await authProvider.signUp(
  // ... البيانات الأخرى
  category: _selectedCategory, // ✅ إرسال الفئة المحددة
);
```

---

## 🧪 التحقق من نجاح التسجيل

### في SQL Editor:
```sql
-- التحقق الشامل
SELECT public.get_merchant_complete_status(
  (SELECT id FROM profiles WHERE email = 'merchant@example.com')::uuid
);

-- يجب أن تكون النتيجة:
{
  "profile_exists": true,
  "merchant_exists": true,
  "store_exists": true,  // ✅ الآن TRUE
  "is_complete": true
}
```

### فحص بيانات المتجر:
```sql
SELECT 
  s.name,
  s.description,
  s.phone,
  s.address,
  s.category,
  s.is_active,
  s.is_open,
  s.opening_hours
FROM stores s
JOIN merchants m ON s.merchant_id = m.id
JOIN profiles p ON m.id = p.id
WHERE p.email = 'merchant@example.com';
```

---

## ⚡ مميزات النظام المحدث

1. **كل شيء تلقائي** - لا حاجة لخطوات إضافية
2. **آمن تماماً** - SECURITY DEFINER يتجاوز RLS
3. **Atomic Transaction** - كل شيء في عملية واحدة
4. **قيم افتراضية معقولة** - المتجر جاهز للعمل فوراً
5. **ساعات عمل افتراضية** - 08:00-23:00 يومياً
6. **معالجة أخطاء قوية** - لا يمنع إنشاء المستخدم حتى لو فشل إنشاء المتجر

---

## 📝 ملاحظات مهمة

1. ✅ **لا حاجة لتغيير كود Flutter** - النظام الحالي يعمل بشكل ممتاز
2. ✅ **اختيار الفئة اختياري** - النظام يختار فئة افتراضية تلقائياً
3. ✅ **يمكن تعديل بيانات المتجر لاحقاً** - عبر واجهة إعدادات المتجر
4. ⚠️ **تطبيق Migration ضروري** - نفذ `update_handle_new_user_trigger.sql` أولاً

---

## 🚀 الخطوات التالية

1. ✅ تطبيق Migration في Supabase
2. ✅ اختبار التسجيل
3. ✅ التحقق من إنشاء Store
4. (اختياري) إضافة حقل اختيار الفئة
5. (اختياري) إضافة واجهة لتعديل بيانات المتجر

---

## 💡 نصائح

- **للتطوير:** استخدم `get_merchant_complete_status()` للتحقق من البيانات
- **للإنتاج:** تأكد من وجود فئات نشطة في جدول `categories`
- **للصيانة:** راقب Logs في Supabase لرؤية رسائل `RAISE NOTICE`

---

تم التحديث بنجاح! 🎉
