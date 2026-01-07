# 🎯 دليل المطور السريع - نسخة مبسطة

## 🚀 ابدأ من هنا

### 1️⃣ **للمبتدئين في المشروع**
اقرأ بالترتيب:
1. هذا الملف (ملخص سريع)
2. [DEVELOPER_GUIDE.md](../DEVELOPER_GUIDE.md) (نظرة عامة)
3. [DEVELOPMENT_GUIDELINES.md](./DEVELOPMENT_GUIDELINES.md) (التفاصيل الكاملة)

### 2️⃣ **للمطورين الحاليين**
استخدم: [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) كمرجع يومي

---

## ⚡ الأخطاء الأكثر شيوعاً

### 🔴 خطأ #1: withOpacity deprecated

**المشكلة:**
```dart
Colors.black.withOpacity(0.5)  // ❌ قديم ولا يُستخدم
```

**الحل:**
```dart
// للألوان الثابتة (Colors.black, Colors.white, etc.)
Colors.black.withAlpha(128)  // ✅ صحيح (0.5 × 255 = 128)

// لألوان الثيم (colorScheme.primary, etc.)
colorScheme.primary.withValues(alpha: 0.5)  // ✅ صحيح
```

**تحويل سريع:**
- 0.1 → 26
- 0.2 → 51
- 0.3 → 77
- 0.5 → 128
- 0.8 → 204

---

### 🔴 خطأ #2: نسيان SafeArea

**المشكلة:**
```dart
Scaffold(
  body: Column(children: [...]),  // ❌ بدون SafeArea
)
```

**الحل:**
```dart
Scaffold(
  body: SafeArea(  // ✅ دائماً استخدم SafeArea
    child: Column(children: [...]),
  ),
)
```

---

### 🔴 خطأ #3: Bottom Overflow

**المشكلة:**
المحتوى أكبر من الشاشة ولا يمكن التمرير

**الحل:**
```dart
Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(  // ✅ أضف scroll
      child: Column(children: [...]),
    ),
  ),
)
```

---

## 🗄️ Supabase - أمثلة سريعة

### قراءة بيانات
```dart
final products = await supabase
    .from('products')
    .select('*')
    .eq('store_id', storeId);
```

### إضافة بيانات
```dart
await supabase
    .from('cart_items')
    .insert({'user_id': userId, 'product_id': productId});
```

### تحديث بيانات
```dart
await supabase
    .from('profiles')
    .update({'full_name': name})
    .eq('id', userId);
```

### حذف بيانات
```dart
await supabase
    .from('cart_items')
    .delete()
    .eq('id', itemId);
```

---

## 📱 Providers - استخدام سريع

### قراءة بدون تحديث UI
```dart
final provider = context.read<CartProvider>();
provider.addItem(item);
```

### قراءة مع تحديث UI
```dart
final provider = context.watch<CartProvider>();
// الـ widget سيتحدث تلقائياً عند تغيير البيانات
```

---

## ✅ Checklist قبل كل Commit

قبل عمل commit، تأكد من:
- [ ] لا توجد `withOpacity` في كودك
- [ ] كل الشاشات فيها `SafeArea`
- [ ] لا توجد مشاكل overflow
- [ ] راجعت `Supabase_schema.sql` للجداول
- [ ] استخدمت الـ Providers الموجودة
- [ ] الكود متناسق مع المشروع

---

## 📚 الملفات المهمة

| الملف | متى تقرأه |
|-------|-----------|
| [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) | يومياً - للمراجعة السريعة |
| [DEVELOPMENT_GUIDELINES.md](./DEVELOPMENT_GUIDELINES.md) | عند البدء في ميزة جديدة |
| [Supabase_schema.sql](../supabase/migrations/Supabase_schema.sql) | قبل أي عملية قاعدة بيانات |

---

## 🆘 عندك مشكلة؟

1. **ابحث في** [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) عن حل سريع
2. **راجع** [DEVELOPMENT_GUIDELINES.md](./DEVELOPMENT_GUIDELINES.md) للتفاصيل
3. **تحقق من** `Supabase_schema.sql` للجداول والـ RLS

---

## 🎨 Material Design 3 - سريع

### الألوان الصحيحة
```dart
final colorScheme = Theme.of(context).colorScheme;

colorScheme.primary          // اللون الأساسي
colorScheme.onPrimary        // نص على الأساسي
colorScheme.surface          // خلفية
colorScheme.onSurface        // نص على الخلفية
```

### الأزرار الصحيحة
```dart
FilledButton(...)      // الزر الأساسي
OutlinedButton(...)    // زر بإطار
TextButton(...)        // زر نصي
```

---

**للتفاصيل الكاملة:** راجع [DEVELOPMENT_GUIDELINES.md](./DEVELOPMENT_GUIDELINES.md)
