# 🛠️ معايير التطوير - تطبيق Ell Tall Market

## 📋 **المعلومات الأساسية**

### 1. **المراجع الرسمية الإلزامية**
- **قاعدة البيانات**: `supabase/migrations/Supabase_schema.sql`
- **Supabase Dart API**: https://supabase.com/docs/reference/dart/introduction
- **Flutter Documentation**: https://flutter.dev/
- **Ant Design Principles**: https://ant.design (للواجهات الإدارية)

### 2. **هيكل المشروع**
```
lib/
├── config/          # ملفات الإعدادات (Supabase, Firebase, Theme)
├── core/            # Logger وأدوات أساسية
├── models/          # Data Models (Profile, Order, Product, etc.)
├── providers/       # State Management (Provider pattern)
├── services/        # Business Logic (Supabase queries, APIs)
├── screens/         # UI Screens (auth, user, merchant, admin, captain)
├── widgets/         # Reusable UI Components
└── utils/           # Helper functions, Validators, Routes
```

---

## ✅ **قواعد الاستخدام**

### **1. Supabase Best Practices**

#### ✅ **استعلامات صحيحة**
```dart
// ✅ استعلام بسيط
final data = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

// ✅ استعلام مع علاقات (Relations)
final data = await supabase
    .from('orders')
    .select('*, profiles(full_name), stores(name)')
    .eq('user_id', userId);

// ✅ Insert مع RLS Policy
final response = await supabase
    .from('profiles')
    .insert({
      'full_name': name,
      'email': email,
      'role': 'client',
    })
    .select()
    .single();
```

#### ❌ **ممنوع**
```dart
// ❌ استعلامات SQL مباشرة غير آمنة
final data = await supabase.query('SELECT * FROM profiles WHERE id = $userId');

// ❌ تعديل Schema بدون توثيق
CREATE TABLE new_table (...);  // استخدم migration files فقط
```

---

### **2. Flutter UI Best Practices**

#### ✅ **الاستخدام الصحيح**

**أ. SafeArea في كل الشاشات**
```dart
return Scaffold(
  body: SafeArea(  // ✅ تجنب التداخل مع status bar/notch
    child: YourContent(),
  ),
);
```

**ب. معالجة Bottom Overflow**
```dart
return Scaffold(
  resizeToAvoidBottomInset: true,  // ✅ ضبط تلقائي عند ظهور الكيبورد
  body: SafeArea(
    child: SingleChildScrollView(  // ✅ منع overflow عند الكيبورد
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,  // ✅ مسافة للكيبورد
      ),
      child: YourForm(),
    ),
  ),
);
```

**ج. TextInput Navigation**
```dart
CustomTextField(
  textInputAction: TextInputAction.next,  // ✅ زر "Next"
  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),  // ✅ انتقال تلقائي
  validator: Validators.validateEmail,
),
```

**د. Form Validation UX**
```dart
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  Future<void> _handleSubmit() async {
    // ✅ تفعيل validation بعد أول محاولة فاشلة
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      SnackBarHelper.showWarning(context, '⚠️ يرجى تصحيح الأخطاء');
      return;
    }
    // ... باقي المنطق
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,  // ✅ ديناميكي حسب الحالة
      child: Column(...),
    );
  }
}
```

**هـ. Pull-to-Refresh**
```dart
RefreshIndicator(
  onRefresh: () async {
    await Provider.of<ProductProvider>(context, listen: false).loadProducts();
  },
  child: ListView.builder(...),
),
```

**و. الألوان الحديثة (لا withOpacity)**
```dart
// ✅ استخدام .withValues() للدقة
Colors.black.withValues(alpha: 0.5)

// ✅ أو .withAlpha() للألوان الثابتة
Colors.black.withAlpha(128)  // 128 = 0.5 * 255

// ❌ deprecated
Colors.black.withOpacity(0.5)
```

---

### **3. Provider Pattern (State Management)**

#### ✅ **الاستخدام الصحيح**
```dart
// في main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ProductProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
  ],
  child: MyApp(),
)

// في الشاشات
final provider = Provider.of<ProductProvider>(context, listen: false);
await provider.loadProducts();

// أو باستخدام Consumer
Consumer<ProductProvider>(
  builder: (context, provider, child) {
    return ListView.builder(...);
  },
)
```

---

### **4. Error Handling**

#### ✅ **معالجة الأخطاء بشكل سليم**
```dart
try {
  final data = await supabase.from('profiles').select('*').single();
  // معالجة البيانات
} on PostgrestException catch (e) {
  AppLogger.error('Database error', e);
  SnackBarHelper.showError(context, 'حدث خطأ في قاعدة البيانات');
} on AuthException catch (e) {
  AppLogger.error('Auth error', e);
  if (e.message.contains('email_not_confirmed')) {
    // معالجة خاصة
  }
} catch (e) {
  AppLogger.error('Unexpected error', e);
  SnackBarHelper.showError(context, 'حدث خطأ غير متوقع');
}
```

---

## ❌ **الممنوعات**

1. ❌ **تعديل Schema SQL بدون migration files**
2. ❌ **تجاهل RLS Policies** - كل جدول يحتاج Policies مناسبة
3. ❌ **استخدام `.withOpacity()`** - استخدم `.withValues(alpha:)` أو `.withAlpha()`
4. ❌ **Form بدون SafeArea و SingleChildScrollView**
5. ❌ **List screens بدون RefreshIndicator**
6. ❌ **TextFields بدون `textInputAction` و `onFieldSubmitted`**
7. ❌ **Validation بدون `AutovalidateMode.onUserInteraction`** بعد أول submit

---

## 🔍 **عند ظهور أخطاء**

### 1. **فحص قاعدة البيانات أولاً**
- راجع `Supabase_schema.sql`
- تأكد من RLS Policies
- تحقق من أنواع البيانات والعلاقات

### 2. **فحص وثائق Supabase**
- https://supabase.com/docs/reference/dart/introduction
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/database

### 3. **التحقق من Logs**
```dart
AppLogger.debug('Debug info');
AppLogger.info('Info message');
AppLogger.warning('Warning');
AppLogger.error('Error', exception);
```

---

## 📊 **Quality Gates**

### قبل الـ Commit:
```bash
# تحليل الكود
flutter analyze

# تشغيل الاختبارات (إن وجدت)
flutter test

# فحص التنسيق
dart format lib/ --set-exit-if-changed
```

---

## 🎯 **Checklist للشاشات الجديدة**

- [ ] استخدام `SafeArea`
- [ ] معالجة `bottom overflow` في Forms
- [ ] `textInputAction: TextInputAction.next` في TextFields
- [ ] `onFieldSubmitted` للانتقال التلقائي
- [ ] `AutovalidateMode.onUserInteraction` بعد أول submit
- [ ] `RefreshIndicator` في القوائم
- [ ] استخدام `Provider` للـ State Management
- [ ] معالجة الأخطاء بـ `try-catch`
- [ ] استخدام `AppLogger` للـ debugging
- [ ] SnackBar للتنبيهات والأخطاء
- [ ] الألوان بـ `.withValues(alpha:)` بدلاً من `.withOpacity()`

---

## 📚 **موارد إضافية**

- **Supabase Dashboard**: https://supabase.com/dashboard/project
- **Flutter DevTools**: https://docs.flutter.dev/tools/devtools
- **Material Design 3**: https://m3.material.io/

---

## ✍️ **ملاحظات التطوير**

عند إضافة ميزات جديدة:
1. راجع `Supabase_schema.sql` للتأكد من توفر الجداول
2. أنشئ Service في `lib/services/` للـ business logic
3. أنشئ Provider في `lib/providers/` للـ state
4. استخدم Widgets من `lib/widgets/` قدر الإمكان
5. اتبع نمط التسمية: `snake_case` للملفات، `PascalCase` للـ Classes
6. استخدم Validators من `lib/utils/validators.dart`
7. استخدم AppRoutes من `lib/utils/app_routes.dart`

---

**آخر تحديث**: نوفمبر 2025
