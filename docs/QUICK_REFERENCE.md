# 🎯 دليل المرجع السريع - Ell Tall Market

## 📚 الملفات الأساسية التي يجب قراءتها

### 1. قاعدة البيانات
```
📁 supabase/migrations/Supabase_schema.sql
```
**يجب قراءته قبل:**
- إنشاء أي استعلام جديد
- التعامل مع الجداول
- استخدام RPC Functions
- التحقق من RLS Policies

### 2. المصادر الرسمية
| المصدر | الرابط | الاستخدام |
|--------|--------|-----------|
| Supabase Dart | https://supabase.com/docs/reference/dart/introduction | جميع عمليات قاعدة البيانات |
| Flutter Docs | https://flutter.dev/ | Flutter Best Practices |
| Ant Design | https://ant.design | UI/UX Guidelines |

---

## 🔧 الأخطاء الشائعة وحلولها

### ❌ خطأ: withOpacity is deprecated

**الخطأ:**
```dart
Colors.black.withOpacity(0.5)
colorScheme.primary.withOpacity(0.3)
```

**الحل:**
```dart
// للألوان الثابتة - استخدم withAlpha
Colors.black.withAlpha(128)  // 0.5 * 255 = 128

// لـ ColorScheme - استخدم withValues
colorScheme.primary.withValues(alpha: 0.5)
```

**جدول تحويل سريع:**
```dart
0.1 → 26
0.2 → 51
0.3 → 77
0.4 → 102
0.5 → 128
0.6 → 153
0.7 → 179
0.8 → 204
0.9 → 230
1.0 → 255
```

### ❌ خطأ: Bottom Overflowed

**الأسباب:**
- عدم استخدام ScrollView
- محتوى أكبر من الشاشة
- لوحة المفاتيح تظهر

**الحلول:**

**1. SingleChildScrollView:**
```dart
body: SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        // المحتوى
      ],
    ),
  ),
),
```

**2. ListView:**
```dart
body: SafeArea(
  child: ListView(
    padding: const EdgeInsets.all(16.0),
    children: [
      // المحتوى
    ],
  ),
),
```

**3. مع لوحة المفاتيح:**
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
        // المحتوى
      ],
    ),
  ),
),
```

### ❌ نسيان SafeArea

**الخطأ:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // المحتوى
      ],
    ),
  );
}
```

**الحل:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(  // ✅ إضافة SafeArea
      child: Column(
        children: [
          // المحتوى
        ],
      ),
    ),
  );
}
```

---

## 🗄️ أمثلة Supabase الصحيحة

### ✅ قراءة البيانات (SELECT)

**قراءة جميع البيانات:**
```dart
final data = await supabase
    .from('products')
    .select('*');
```

**قراءة مع شرط:**
```dart
final data = await supabase
    .from('products')
    .select('*')
    .eq('store_id', storeId);
```

**قراءة سجل واحد:**
```dart
final data = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
```

**قراءة مع join:**
```dart
final data = await supabase
    .from('products')
    .select('*, categories(*), stores(*)')
    .eq('is_available', true);
```

**قراءة مع ترتيب:**
```dart
final data = await supabase
    .from('products')
    .select('*')
    .order('created_at', ascending: false)
    .limit(10);
```

### ✅ إضافة البيانات (INSERT)

**إضافة سجل واحد:**
```dart
final result = await supabase
    .from('cart_items')
    .insert({
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
    })
    .select()
    .single();
```

**إضافة عدة سجلات:**
```dart
final result = await supabase
    .from('order_items')
    .insert([
      {'order_id': orderId, 'product_id': 'p1', 'quantity': 2},
      {'order_id': orderId, 'product_id': 'p2', 'quantity': 1},
    ])
    .select();
```

### ✅ تحديث البيانات (UPDATE)

**تحديث سجل:**
```dart
await supabase
    .from('profiles')
    .update({'full_name': newName})
    .eq('id', userId);
```

**تحديث مع عدة شروط:**
```dart
await supabase
    .from('products')
    .update({'stock': newStock})
    .eq('id', productId)
    .eq('store_id', storeId);
```

### ✅ حذف البيانات (DELETE)

**حذف سجل:**
```dart
await supabase
    .from('cart_items')
    .delete()
    .eq('id', itemId);
```

**حذف مع شرط:**
```dart
await supabase
    .from('cart_items')
    .delete()
    .eq('user_id', userId);
```

### ✅ استخدام RPC Functions

**استدعاء دالة:**
```dart
final result = await supabase.rpc(
  'get_cart_with_items',
  params: {'user_id': userId},
);
```

**مع معالجة الخطأ:**
```dart
try {
  final result = await supabase.rpc(
    'create_order',
    params: {
      'p_user_id': userId,
      'p_store_id': storeId,
      'p_total': total,
    },
  );
  return result;
} catch (e) {
  Logger.error('خطأ في إنشاء الطلب: $e');
  rethrow;
}
```

---

## 📱 استخدام Providers

### الحصول على Provider

**للقراءة فقط (لا يعيد بناء الـ Widget):**
```dart
final cartProvider = context.read<CartProvider>();
```

**مع مراقبة التغييرات (يعيد بناء الـ Widget):**
```dart
final cartProvider = context.watch<CartProvider>();
```

**في initState:**
```dart
@override
void initState() {
  super.initState();
  Future.microtask(() {
    context.read<CartProvider>().loadCart();
  });
}
```

### Providers المتاحة

```dart
// المصادقة و Supabase
SupabaseProvider
UserProvider

// المتاجر والمنتجات
StoreProvider
ProductProvider
CategoryProvider

// الطلبات والسلة
CartProvider
OrderProvider

// الأخرى
FavoritesProvider
NotificationProvider
SettingsProvider
```

---

## 🎨 Material Design 3

### استخدام ColorScheme

```dart
final colorScheme = Theme.of(context).colorScheme;

// الألوان الأساسية
colorScheme.primary          // اللون الأساسي
colorScheme.onPrimary        // نص على اللون الأساسي
colorScheme.primaryContainer // خلفية فاتحة للون الأساسي
colorScheme.onPrimaryContainer // نص على الخلفية الفاتحة

// الألوان الثانوية
colorScheme.secondary
colorScheme.onSecondary
colorScheme.secondaryContainer
colorScheme.onSecondaryContainer

// السطح والخلفية
colorScheme.surface          // لون السطح
colorScheme.onSurface        // نص على السطح
colorScheme.surfaceVariant   // متغير لون السطح
colorScheme.background       // لون الخلفية

// الحدود والأخطاء
colorScheme.outline          // لون الحدود
colorScheme.error            // لون الخطأ
colorScheme.onError          // نص على الخطأ
```

### الأزرار الحديثة

```dart
// الزر الأساسي المملوء
FilledButton(
  onPressed: () {},
  child: Text('تأكيد'),
)

// الزر المحدد بإطار
OutlinedButton(
  onPressed: () {},
  child: Text('إلغاء'),
)

// الزر النصي
TextButton(
  onPressed: () {},
  child: Text('تخطي'),
)

// زر مع أيقونة
FilledButton.icon(
  onPressed: () {},
  icon: Icon(Icons.shopping_cart),
  label: Text('أضف للسلة'),
)
```

---

## 🔐 RLS Policies - نظرة عامة

### التحقق من الصلاحيات

```dart
// التحقق من تسجيل الدخول
final user = supabase.auth.currentUser;
if (user == null) {
  // المستخدم غير مسجل
}

// الحصول على UID
final userId = supabase.auth.currentUser!.id;

// التحقق من الدور (Role)
final profile = await supabase
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single();

final role = profile['role'] as String;
```

### الأدوار المتاحة

| الدور | الصلاحيات |
|-------|-----------|
| `client` | المستخدم العادي - تصفح وشراء |
| `merchant` | التاجر - إدارة المتجر والمنتجات |
| `captain` | الكابتن - توصيل الطلبات |
| `admin` | المدير - جميع الصلاحيات |

---

## 🧪 معالجة الأخطاء

### Template معالجة الأخطاء

```dart
import 'package:ell_tall_market/core/logger.dart';

Future<void> someFunction() async {
  try {
    final result = await supabase
        .from('table_name')
        .select('*');
    
    // معالجة النتيجة
    
  } on PostgrestException catch (e) {
    Logger.error('خطأ في قاعدة البيانات: ${e.message}');
    rethrow;
  } catch (e) {
    Logger.error('خطأ غير متوقع: $e');
    rethrow;
  }
}
```

### عرض الأخطاء للمستخدم

```dart
import 'package:ell_tall_market/utils/snackbar_helper.dart';

try {
  // العملية
} catch (e) {
  if (mounted) {
    SnackbarHelper.showError(
      context,
      'حدث خطأ أثناء العملية',
    );
  }
}
```

---

## 📋 Checklist السريع

قبل كل commit:

- [ ] ✅ استبدلت `withOpacity` بـ `withValues` أو `withAlpha`
- [ ] ✅ أضفت `SafeArea` في الشاشات الجديدة
- [ ] ✅ عالجت overflow errors
- [ ] ✅ استخدمت Providers الموجودة
- [ ] ✅ راجعت `Supabase_schema.sql`
- [ ] ✅ استخدمت Material Design 3
- [ ] ✅ أضفت معالجة للأخطاء
- [ ] ✅ اختبرت على أجهزة مختلفة

---

## 🎯 الجداول الرئيسية

### profiles (المستخدمين)
```sql
id, full_name, email, phone, role, avatar_url, is_active
```

### stores (المتاجر)
```sql
id, name, description, merchant_id, is_active, rating
```

### products (المنتجات)
```sql
id, name, description, price, store_id, category_id, stock
```

### orders (الطلبات)
```sql
id, user_id, store_id, captain_id, status, total_amount
```

### cart_items (سلة التسوق)
```sql
id, user_id, product_id, quantity
```

### categories (الفئات)
```sql
id, name, icon_name, is_active
```

---

## 🚀 أوامر Terminal السريعة

```bash
# تحميل Dependencies
flutter pub get

# تشغيل التطبيق
flutter run

# تنظيف المشروع
flutter clean

# فحص الأخطاء
flutter analyze

# إصلاح الأخطاء التلقائية
dart fix --apply

# تنسيق الكود
dart format .
```

---

## 📞 روابط مهمة

- **Supabase Dart Docs:** https://supabase.com/docs/reference/dart/introduction
- **Flutter Docs:** https://flutter.dev/
- **Material Design 3:** https://m3.material.io/
- **Provider Package:** https://pub.dev/packages/provider

---

**آخر تحديث:** أكتوبر 2025
