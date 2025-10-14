# نظام المفضلة والسلة - Favorites & Cart System

## 📋 نظرة عامة

تم تحديث نظام المفضلة والسلة ليعمل بشكل كامل مع قاعدة البيانات Supabase، مع دعم التحميل التلقائي عند تسجيل الدخول والحفظ الفوري عند كل عملية.

---

## 🎯 المفضلة - Favorites System

### البنية في قاعدة البيانات

**جدول `favorites`:**
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key → profiles)
- product_id (uuid, foreign key → products, nullable)
- store_id (uuid, foreign key → stores, nullable)
- created_at (timestamp)
```

### الوظائف الرئيسية

#### 1. تحميل المفضلة
```dart
// يتم تلقائياً عند:
// - تسجيل الدخول
// - فتح التطبيق (إذا كان مسجل دخول)

await favoritesProvider.loadUserFavorites(userId);
```

#### 2. إضافة/إزالة من المفضلة
```dart
// Toggle (إضافة أو إزالة)
final success = await favoritesProvider.toggleFavoriteProduct(product);

// أو إزالة مباشرة
await favoritesProvider.removeFromFavorites(productId);
```

#### 3. التحقق من المفضلة
```dart
// في الـ UI
bool isFavorite = favoritesProvider.isFavorite(productId);

// للمنتج
bool isFavoriteProduct = favoritesProvider.isFavoriteProduct(productId);

// للمتجر
bool isFavoriteStore = favoritesProvider.isFavoriteStore(storeId);
```

### التكامل مع UI

**في `home_screen.dart`:**
```dart
Consumer<FavoritesProvider>(
  builder: (context, favoritesProvider, child) {
    return ProductCard(
      product: product,
      isFavorite: favoritesProvider.isFavorite(product.id),
      onFavoritePressed: () => _handleFavoriteProduct(product),
    );
  },
)
```

**معالج الضغط:**
```dart
void _handleFavoriteProduct(ProductModel product) {
  _checkLoginForAction(() async {
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final success = await favoritesProvider.toggleFavoriteProduct(product);
    
    if (success) {
      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت الإضافة/الإزالة')),
      );
    }
  });
}
```

---

## 🛒 السلة - Cart System

### البنية في قاعدة البيانات

**جدول `carts`:**
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key → profiles, unique)
- created_at (timestamp)
- updated_at (timestamp)
```

**جدول `cart_items`:**
```sql
- id (uuid, primary key)
- cart_id (uuid, foreign key → carts)
- product_id (uuid, foreign key → products)
- quantity (integer)
- price (numeric)
- created_at (timestamp)
```

### الوظائف الرئيسية

#### 1. تحميل السلة
```dart
// يتم تلقائياً عند:
// - تسجيل الدخول
// - فتح التطبيق (إذا كان مسجل دخول)

await cartProvider.loadCart();
```

#### 2. إضافة منتج للسلة
```dart
final success = await cartProvider.addToCart(
  productId: product.id,
  quantity: 1, // اختياري، القيمة الافتراضية 1
);
```

#### 3. تحديث الكمية
```dart
await cartProvider.updateCartItem(
  itemId: cartItemId,
  quantity: newQuantity,
);
```

#### 4. إزالة من السلة
```dart
await cartProvider.removeCartItem(itemId);
```

#### 5. الحصول على المعلومات
```dart
// عدد المنتجات
int itemCount = cartProvider.itemCount;

// المجموع
double total = cartProvider.total;
double subtotal = cartProvider.subtotal;

// التحقق
bool isEmpty = cartProvider.isEmpty;
bool hasItems = cartProvider.hasItems;
```

### التكامل مع UI

**عرض عدد المنتجات في AppBar:**
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    final itemCount = cartProvider.cartItems.length;
    return Badge(
      label: Text(itemCount > 99 ? '99+' : itemCount.toString()),
      child: Icon(Icons.shopping_cart_rounded),
    );
  },
)
```

**إضافة للسلة:**
```dart
void _handleBuyProduct(ProductModel product) {
  _checkLoginForAction(() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final success = await cartProvider.addToCart(productId: product.id);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة ${product.name} إلى السلة')),
      );
    }
  });
}
```

---

## ⚙️ التهيئة في `main.dart`

### FavoritesProvider

```dart
ChangeNotifierProxyProvider<SupabaseProvider, FavoritesProvider>(
  create: (_) => FavoritesProvider(),
  update: (context, auth, previousFavorites) {
    final favoritesProvider = previousFavorites ?? FavoritesProvider();
    favoritesProvider.setAuthProvider(auth);
    
    // تحميل المفضلة تلقائياً عند تسجيل الدخول
    if (auth.isLoggedIn && auth.currentUser != null) {
      favoritesProvider.loadUserFavorites(auth.currentUser!.id);
    }
    return favoritesProvider;
  },
)
```

### CartProvider

```dart
ChangeNotifierProxyProvider<SupabaseProvider, CartProvider>(
  create: (context) => CartProvider(''),
  update: (context, auth, previousCart) =>
      CartProvider(auth.currentUser?.id ?? ''),
)
```

---

## 🔐 التحقق من تسجيل الدخول

جميع العمليات محمية بدالة `_checkLoginForAction`:

```dart
void _checkLoginForAction(VoidCallback action, {String? loginMessage}) {
  final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
  
  if (authProvider.isLoggedIn) {
    action(); // تنفيذ العملية
  } else {
    // عرض رسالة وزر للانتقال لشاشة تسجيل الدخول
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loginMessage ?? 'يرجى تسجيل الدخول أولاً'),
        action: SnackBarAction(
          label: 'تسجيل الدخول',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
        ),
      ),
    );
  }
}
```

---

## 📊 تدفق البيانات

### عند تسجيل الدخول:
```
1. SupabaseProvider.login()
   ↓
2. main.dart update callback
   ↓
3. FavoritesProvider.loadUserFavorites(userId)
   ↓
4. CartProvider (new instance with userId)
   ↓
5. home_screen.dart _loadData()
   ↓
6. cartProvider.loadCart()
```

### عند إضافة للمفضلة:
```
1. User taps favorite icon
   ↓
2. _handleFavoriteProduct()
   ↓
3. _checkLoginForAction() ✓
   ↓
4. favoritesProvider.toggleFavoriteProduct()
   ↓
5. Supabase INSERT/DELETE on 'favorites' table
   ↓
6. Update local state
   ↓
7. notifyListeners()
   ↓
8. UI updates (Consumer rebuilds)
```

### عند إضافة للسلة:
```
1. User taps cart icon
   ↓
2. _handleBuyProduct()
   ↓
3. _checkLoginForAction() ✓
   ↓
4. cartProvider.addToCart()
   ↓
5. CartService.addItemToCart()
   ↓
6. Supabase INSERT on 'cart_items' table
   ↓
7. Update local state
   ↓
8. notifyListeners()
   ↓
9. UI updates (AppBar badge, etc.)
```

---

## 🎨 تأثيرات UI

### Haptic Feedback
```dart
// عند الضغط على الأيقونات
HapticFeedback.lightImpact();
```

### Material Design 3
- أيقونات مستديرة: `Icons.favorite_rounded`
- ألوان ديناميكية: `colorScheme.primaryContainer`
- InkWell للتأثيرات: Ripple effect

### Shimmer Loading
- يظهر أثناء تحميل البيانات
- يطابق شكل الكروت الفعلية

---

## 🐛 معالجة الأخطاء

### في FavoritesProvider:
```dart
try {
  await _supabase.from('favorites').insert({...});
} catch (e) {
  _error = 'خطأ في تحديث المفضلة: $e';
  debugPrint('خطأ في toggleFavoriteProduct: $e');
  notifyListeners();
  return false;
}
```

### في UI:
```dart
if (mounted && success) {
  // عرض رسالة نجاح
} else if (mounted && !success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(favoritesProvider.error ?? 'فشلت العملية'),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
```

---

## 📱 الشاشات المتأثرة

### ✅ تم التحديث:
- `home_screen.dart` - المنتجات الجديدة والأكثر مبيعاً
- `main.dart` - تهيئة Providers

### 🔄 تحتاج للتحديث:
- `favorites_screen.dart` - عرض المفضلة
- `cart_screen.dart` - عرض السلة
- `product_detail_screen.dart` - تفاصيل المنتج
- `category_screen.dart` - منتجات التصنيف
- `store_detail_screen.dart` - منتجات المتجر

---

## ✅ قائمة التحقق

- [x] المفضلة تُحفظ في قاعدة البيانات
- [x] السلة تُحفظ في قاعدة البيانات
- [x] تحميل تلقائي عند تسجيل الدخول
- [x] UI يتحدث فوراً عند التغيير
- [x] رسائل نجاح/فشل واضحة
- [x] حماية بالتحقق من تسجيل الدخول
- [x] HapticFeedback للتفاعل
- [x] معالجة الأخطاء

---

## 🚀 الخطوات التالية

1. **تحديث شاشة المفضلة:**
   - عرض المنتجات من `favoritesProvider.favoriteProducts`
   - إضافة زر "إزالة الكل"
   - عرض حالة فارغة مناسبة

2. **تحديث شاشة السلة:**
   - عرض العناصر من `cartProvider.cartItems`
   - تحديث الكمية
   - حساب المجموع الكلي
   - تطبيق الكوبونات

3. **إضافة Offline Support:**
   - حفظ مؤقت للمفضلة
   - queue للعمليات الفاشلة
   - مزامنة عند عودة الاتصال

4. **تحسينات الأداء:**
   - Pagination للمفضلة
   - Lazy loading للسلة
   - Caching الذكي

---

تم التحديث: 13 أكتوبر 2025
الإصدار: 1.0.0
