# 🚀 دليل تطوير تطبيق Ell Tall Market

## 📋 المعلومات الأساسية المطلوبة

### 1. 🗄️ قاعدة البيانات
**الملف:** `supabase/migrations/Supabase_schema.sql`
- **الغرض:** هيكل قاعدة البيانات الكامل
- **المحتوى:** جميع الجداول، العلاقات، الـ RLS Policies، الدوال، والـ Triggers
- **⚠️ يجب مراجعة هذا الملف قبل أي تعديل في قاعدة البيانات**

### 2. 📚 المصادر الرسمية
- **Supabase Dart:** https://supabase.com/docs/reference/dart/introduction
- **Flutter:** https://flutter.dev/
- **Ant Design:** https://ant.design
- **Supabase Dashboard:** https://supabase.com/dashboard/project

### 3. 🎯 هيكل المشروع

```
lib/
├── config/          # إعدادات التطبيق
├── core/            # المكونات الأساسية
├── models/          # نماذج البيانات
├── providers/       # إدارة الحالة (Provider Pattern)
├── services/        # خدمات API و Business Logic
├── screens/         # شاشات التطبيق
│   ├── admin/       # شاشات الإدارة
│   ├── auth/        # شاشات المصادقة
│   ├── captain/     # شاشات الكابتن
│   ├── common/      # شاشات مشتركة
│   ├── merchant/    # شاشات التاجر
│   └── user/        # شاشات المستخدم
├── utils/           # أدوات مساعدة
└── widgets/         # مكونات UI قابلة لإعادة الاستخدام
```

---

## ✅ قواعد الاستخدام

### 🎯 **المطلوب من AI:**

#### 1. **الالتزام بالهيكل الحالي**
- ✅ استخدام الـ Providers و Services الموجودة
- ✅ اتباع نفس نمط تنظيم الملفات
- ✅ استخدام الـ Models المعرفة مسبقاً

#### 2. **استخدام Supabase Dart**
- ✅ اتباع الوثائق الرسمية: https://supabase.com/docs/reference/dart/introduction
- ✅ استخدام الـ RPC Functions المعرفة في `Supabase_schema.sql`
- ✅ التحقق من الـ RLS Policies قبل أي عملية

#### 3. **Flutter Best Practices**
- ✅ استخدام Material Design 3 (MD3)
- ✅ تطبيق SafeArea في جميع الشاشات
- ✅ معالجة bottom overflow errors
- ✅ استخدام `.withValues()` بدلاً من `.withOpacity()`

#### 4. **التحقق من التوافق**
- ✅ مراجعة `Supabase_schema.sql` قبل أي استعلام
- ✅ التأكد من صحة أسماء الجداول والأعمدة
- ✅ التحقق من أنواع البيانات

---

## ❌ الممنوع

### 🚫 **لا تقم بـ:**

1. ❌ إنشاء جداول أو دوال جديدة بدون الرجوع لـ `Supabase_schema.sql`
2. ❌ استخدام طرق قديمة أو غير موثقة من Supabase
3. ❌ تجاهل الـ RLS Policies المحددة
4. ❌ تعديل الهيكل الحالي للمشروع بدون سبب
5. ❌ استخدام `withOpacity()` - استخدم `withValues()` بدلاً منها
6. ❌ نسيان إضافة SafeArea في الشاشات الجديدة
7. ❌ كتابة SQL مباشر - استخدم Supabase Client

---

## 🔍 عند ظهور أخطاء

### خطوات التشخيص:

1. **التحقق من الـ Schema**
   ```dart
   // راجع supabase/migrations/Supabase_schema.sql
   // تأكد من وجود الجدول والأعمدة المطلوبة
   ```

2. **مراجعة وثائق Supabase**
   ```dart
   // تحقق من الصيغة الصحيحة في الوثائق الرسمية
   // https://supabase.com/docs/reference/dart/introduction
   ```

3. **التحقق من RLS Policies**
   ```dart
   // تأكد من أن المستخدم الحالي لديه صلاحيات الوصول
   // راجع الـ Policies في Supabase_schema.sql
   ```

4. **مراجعة أنواع البيانات**
   ```dart
   // تأكد من تطابق الأنواع في Dart مع PostgreSQL
   ```

---

## 🛠️ أمثلة للاستخدام الصحيح

### ✅ قراءة البيانات (SELECT)

```dart
// صحيح - حسب وثائق Supabase
final data = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
```

```dart
// خطأ - طريقة غير موثقة
final data = await supabase.query('SELECT * FROM profiles WHERE id = $userId');
```

### ✅ إضافة البيانات (INSERT)

```dart
// صحيح
final result = await supabase
    .from('stores')
    .insert({
      'name': storeName,
      'description': description,
      'merchant_id': merchantId,
    })
    .select()
    .single();
```

```dart
// خطأ
await supabase.rpc('insert_store', params: {...});
```

### ✅ تحديث البيانات (UPDATE)

```dart
// صحيح
await supabase
    .from('profiles')
    .update({'full_name': newName})
    .eq('id', userId);
```

### ✅ حذف البيانات (DELETE)

```dart
// صحيح
await supabase
    .from('cart_items')
    .delete()
    .eq('id', itemId);
```

### ✅ استخدام RPC Functions

```dart
// صحيح - استدعاء دالة معرفة في Supabase_schema.sql
final result = await supabase.rpc(
  'get_cart_with_items',
  params: {'user_id': userId},
);
```

---

## 🎨 إصلاح withOpacity (Deprecated)

### ❌ الطريقة القديمة (Deprecated)
```dart
Colors.black.withOpacity(0.5)
colorScheme.primary.withOpacity(0.3)
```

### ✅ الطريقة الجديدة

#### لـ Solid Colors:
```dart
// بدلاً من withOpacity(0.5)
Colors.black.withAlpha(128)  // 0.5 * 255 = 128

// بدلاً من withOpacity(0.3)
Colors.white.withAlpha(77)   // 0.3 * 255 = 77

// بدلاً من withOpacity(0.2)
Colors.black.withAlpha(51)   // 0.2 * 255 = 51
```

#### لـ ColorScheme:
```dart
// بدلاً من colorScheme.primary.withOpacity(0.5)
colorScheme.primary.withValues(alpha: 0.5)

// بدلاً من colorScheme.surface.withOpacity(0.3)
colorScheme.surface.withValues(alpha: 0.3)
```

### جدول التحويل السريع:
| Opacity | Alpha Value |
|---------|-------------|
| 0.1     | 26          |
| 0.2     | 51          |
| 0.3     | 77          |
| 0.4     | 102         |
| 0.5     | 128         |
| 0.6     | 153         |
| 0.7     | 179         |
| 0.8     | 204         |
| 0.9     | 230         |
| 1.0     | 255         |

---

## 🛡️ استخدام SafeArea

### ✅ في جميع الشاشات:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('عنوان الشاشة'),
    ),
    body: SafeArea(  // ⚠️ مهم جداً
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // محتوى الشاشة
          ],
        ),
      ),
    ),
  );
}
```

---

## 🔧 معالجة Bottom Overflow

### ✅ الحل الأول: SingleChildScrollView

```dart
body: SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        // المحتوى هنا
      ],
    ),
  ),
),
```

### ✅ الحل الثاني: ListView

```dart
body: SafeArea(
  child: ListView(
    padding: const EdgeInsets.all(16.0),
    children: [
      // المحتوى هنا
    ],
  ),
),
```

### ✅ الحل الثالث: مع Keyboard

```dart
body: SafeArea(
  child: SingleChildScrollView(
    padding: EdgeInsets.only(
      left: 16.0,
      right: 16.0,
      top: 16.0,
      bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
    ),
    child: Column(
      children: [
        // المحتوى هنا
      ],
    ),
  ),
),
```

---

## 📦 الجداول الرئيسية في قاعدة البيانات

### 1. profiles (المستخدمين)
```sql
- id: UUID (PK)
- full_name: TEXT
- email: TEXT (UNIQUE)
- phone: TEXT
- role: TEXT (client, merchant, captain, admin)
- avatar_url: TEXT
- fcm_token: TEXT
- is_active: BOOLEAN
```

### 2. stores (المتاجر)
```sql
- id: UUID (PK)
- name: TEXT
- description: TEXT
- merchant_id: UUID (FK -> profiles.id)
- is_active: BOOLEAN
- rating: NUMERIC(3,2)
- total_reviews: INTEGER
```

### 3. products (المنتجات)
```sql
- id: UUID (PK)
- name: TEXT
- description: TEXT
- price: NUMERIC(10,2)
- store_id: UUID (FK -> stores.id)
- category_id: UUID (FK -> categories.id)
- stock: INTEGER
- is_available: BOOLEAN
```

### 4. orders (الطلبات)
```sql
- id: UUID (PK)
- user_id: UUID (FK -> profiles.id)
- store_id: UUID (FK -> stores.id)
- captain_id: UUID (FK -> profiles.id)
- status: order_status_enum
- total_amount: NUMERIC(10,2)
```

### 5. cart_items (سلة التسوق)
```sql
- id: UUID (PK)
- user_id: UUID (FK -> profiles.id)
- product_id: UUID (FK -> products.id)
- quantity: INTEGER
```

---

## 🔐 RLS Policies المهمة

### للـ profiles:
- ✅ Users can view own profile
- ✅ Users can update own profile
- ✅ Public profiles are viewable by everyone
- ✅ Admins can insert/update/delete users

### للـ stores:
- ✅ Anyone can view active stores
- ✅ Merchants can manage their stores
- ✅ Admins can manage all stores

### للـ products:
- ✅ Anyone can view available products
- ✅ Merchants can manage their products
- ✅ Admins can manage all products

### للـ orders:
- ✅ Users can view their orders
- ✅ Merchants can view orders for their stores
- ✅ Captains can view assigned orders
- ✅ Admins can view all orders

---

## 📱 Providers المتاحة

قراءة هذه الملفات قبل الاستخدام:

1. **supabase_provider.dart** - إدارة اتصال Supabase
2. **user_provider.dart** - إدارة بيانات المستخدم
3. **store_provider.dart** - إدارة المتاجر
4. **product_provider.dart** - إدارة المنتجات
5. **cart_provider.dart** - إدارة سلة التسوق
6. **order_provider.dart** - إدارة الطلبات
7. **category_provider.dart** - إدارة الفئات
8. **favorites_provider.dart** - إدارة المفضلة
9. **notification_provider.dart** - إدارة الإشعارات

---

## 🔧 Services المتاحة

قراءة هذه الملفات قبل الاستخدام:

1. **supabase_service.dart** - خدمات Supabase الأساسية
2. **auth_deep_link_handler.dart** - معالجة روابط المصادقة
3. **network_manager.dart** - إدارة الاتصال بالإنترنت
4. **cart_service.dart** - عمليات سلة التسوق
5. **order_service.dart** - عمليات الطلبات
6. **payment_service.dart** - عمليات الدفع
7. **notification_service.dart** - عمليات الإشعارات
8. **google_signin_service.dart** - تسجيل الدخول بـ Google

---

## ✨ Material Design 3 Guidelines

### استخدام ColorScheme بدلاً من Colors الثابتة:

```dart
// ✅ صحيح
final colorScheme = Theme.of(context).colorScheme;

Container(
  color: colorScheme.primaryContainer,
  child: Text(
    'مرحباً',
    style: TextStyle(color: colorScheme.onPrimaryContainer),
  ),
)

// ❌ خطأ
Container(
  color: Colors.blue[100],
  child: Text('مرحباً', style: TextStyle(color: Colors.blue[900])),
)
```

### استخدام FilledButton و OutlinedButton:

```dart
// ✅ صحيح
FilledButton(
  onPressed: () {},
  child: Text('تأكيد'),
)

OutlinedButton(
  onPressed: () {},
  child: Text('إلغاء'),
)

// ❌ خطأ
RaisedButton(onPressed: () {}, child: Text('تأكيد'))
```

---

## 📝 Checklist قبل أي تعديل

- [ ] قرأت `Supabase_schema.sql` للتحقق من الجداول
- [ ] راجعت الـ Providers و Services الموجودة
- [ ] تأكدت من الـ RLS Policies المطلوبة
- [ ] استخدمت `.withValues()` بدلاً من `.withOpacity()`
- [ ] أضفت `SafeArea` في الشاشات الجديدة
- [ ] عالجت مشاكل overflow المحتملة
- [ ] اتبعت Material Design 3 Guidelines
- [ ] تحققت من وثائق Supabase الرسمية

---

## 🎯 Quick Reference

### تشغيل المشروع:
```bash
flutter pub get
flutter run
```

### تنظيف المشروع:
```bash
flutter clean
flutter pub get
```

### فحص الأخطاء:
```bash
flutter analyze
```

---

## 📞 المراجع السريعة

- **Supabase Schema:** `supabase/migrations/Supabase_schema.sql`
- **Providers:** `lib/providers/`
- **Services:** `lib/services/`
- **Models:** `lib/models/`
- **Screens:** `lib/screens/`

---

**آخر تحديث:** أكتوبر 2025
**الإصدار:** 1.0.0
