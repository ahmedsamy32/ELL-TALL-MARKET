# 🎯 ملخص سريع للمطورين - Ell Tall Market

## 📚 قبل أي شيء - اقرأ هذه الملفات:

### 1. **[docs/DEVELOPMENT_GUIDELINES.md](./docs/DEVELOPMENT_GUIDELINES.md)**
الدليل الشامل لتطوير التطبيق - يحتوي على جميع القواعد والأمثلة

### 2. **[docs/QUICK_REFERENCE.md](./docs/QUICK_REFERENCE.md)**
مرجع سريع للحلول والأكواد الجاهزة

### 3. **[supabase/migrations/Supabase_schema.sql](./supabase/migrations/Supabase_schema.sql)**
هيكل قاعدة البيانات الكامل - **راجعه قبل أي استعلام**

---

## ⚡ نظرة سريعة

### ❌ الأخطاء الشائعة التي يجب تجنبها

#### 1. استخدام withOpacity (Deprecated)
```dart
// ❌ خطأ
Colors.black.withOpacity(0.5)
colorScheme.primary.withOpacity(0.3)

// ✅ صحيح
Colors.black.withAlpha(128)  // للألوان الثابتة
colorScheme.primary.withValues(alpha: 0.3)  // لـ ColorScheme
```

#### 2. نسيان SafeArea
```dart
// ❌ خطأ
return Scaffold(
  body: Column(children: [...]),
);

// ✅ صحيح
return Scaffold(
  body: SafeArea(
    child: Column(children: [...]),
  ),
);
```

#### 3. Bottom Overflow
```dart
// ✅ الحل
return Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [...]),
    ),
  ),
);
```

---

## 🗄️ استخدام Supabase الصحيح

### قراءة البيانات
```dart
// ✅ صحيح
final data = await supabase
    .from('products')
    .select('*')
    .eq('store_id', storeId);
```

### إضافة البيانات
```dart
// ✅ صحيح
final result = await supabase
    .from('cart_items')
    .insert({'user_id': userId, 'product_id': productId})
    .select()
    .single();
```

### تحديث البيانات
```dart
// ✅ صحيح
await supabase
    .from('profiles')
    .update({'full_name': newName})
    .eq('id', userId);
```

---

## 📱 استخدام Providers

```dart
// للقراءة فقط
final provider = context.read<CartProvider>();

// مع مراقبة التغييرات
final provider = context.watch<CartProvider>();
```

**Providers المتاحة:**
- SupabaseProvider
- UserProvider
- StoreProvider
- ProductProvider
- CartProvider
- OrderProvider
- FavoritesProvider
- CategoryProvider
- NotificationProvider

---

## ✅ Checklist قبل كل Commit

- [ ] استبدلت `withOpacity` بـ `withValues` أو `withAlpha`
- [ ] أضفت `SafeArea` في الشاشات الجديدة
- [ ] عالجت overflow errors
- [ ] راجعت `Supabase_schema.sql`
- [ ] استخدمت Providers الموجودة
- [ ] اتبعت Material Design 3

---

## 🚀 روابط سريعة

- **Supabase Dart:** https://supabase.com/docs/reference/dart/introduction
- **Flutter:** https://flutter.dev/
- **Material Design 3:** https://m3.material.io/

---

## 📖 للمزيد من التفاصيل

انتقل إلى مجلد [docs/](./docs/) لقراءة الوثائق الكاملة.

**ابدأ بـ:** [docs/README.md](./docs/README.md)
