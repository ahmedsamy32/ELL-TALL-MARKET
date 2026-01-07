# 📑 تبويبات شاشة طلبات المستخدم

## 📌 التحديث
تم تعديل شاشة `order_history_screen.dart` لتحتوي على **تبويبين** بدلاً من قائمة واحدة.

## 🎨 التبويبات الجديدة

### 1️⃣ الطلبات النشطة 🚚
**الأيقونة**: `local_shipping_rounded`  
**المحتوى**:
- ✅ جميع الطلبات **ما عدا الملغاة**
- ✅ قيد التوصيل (pending, confirmed, in_preparation, ready, on_the_way)
- ✅ تم التوصيل (delivered)

**عندما تكون فارغة**:
```
أيقونة: shopping_bag_outlined
الرسالة: "لا توجد طلبات نشطة"
زر: "ابدأ التسوق"
```

### 2️⃣ الطلبات الملغاة ❌
**الأيقونة**: `cancel_outlined`  
**المحتوى**:
- ✅ الطلبات الملغاة فقط (cancelled)
- ✅ الطلبات المسترجعة (إن وُجدت)

**عندما تكون فارغة**:
```
أيقونة: check_circle_outline (خضراء)
الرسالة: "لا توجد طلبات ملغاة"
الوصف: "جميع طلباتك تم تنفيذها بنجاح! 🎉"
```

## 🔧 التغييرات التقنية

### 1. إضافة TabController
```dart
class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
```

### 2. إضافة TabBar في AppBar
```dart
bottom: authProvider.isLoggedIn
    ? TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            icon: Icon(Icons.local_shipping_rounded),
            text: 'الطلبات النشطة',
          ),
          Tab(
            icon: Icon(Icons.cancel_outlined),
            text: 'الطلبات الملغاة',
          ),
        ],
      )
    : null,
```

### 3. استبدال الجسم بـ TabBarView
```dart
body: TabBarView(
  controller: _tabController,
  children: [
    _buildActiveOrdersTab(orderProvider, colorScheme),
    _buildCancelledOrdersTab(orderProvider, colorScheme),
  ],
),
```

### 4. دوال بناء التبويبات

#### `_buildActiveOrdersTab`
```dart
// تصفية الطلبات
final activeOrders = [...provider.currentOrders, ...provider.pastOrders]
    .where((order) {
  final status = OrderStatusExtension.fromDbValue(order.status.value);
  return status != OrderStatus.cancelled;
}).toList();

// عرض في ListView.builder
```

#### `_buildCancelledOrdersTab`
```dart
// تصفية الطلبات الملغاة فقط
final cancelledOrders = [...provider.currentOrders, ...provider.pastOrders]
    .where((order) {
  final status = OrderStatusExtension.fromDbValue(order.status.value);
  return status == OrderStatus.cancelled;
}).toList();

// عرض في ListView.builder
```

## 📊 المقارنة

### ❌ قبل التحديث:
```
┌─────────────────────┐
│   الطلبات الحالية   │
├─────────────────────┤
│ طلب 1 (قيد التوصيل) │
│ طلب 2 (تم التوصيل)  │
├─────────────────────┤
│   الطلبات السابقة   │
├─────────────────────┤
│ طلب 3 (تم التوصيل)  │
│ طلب 4 (ملغي)       │
└─────────────────────┘
```

### ✅ بعد التحديث:
```
┌─────────────────────────────────┐
│ [🚚 الطلبات النشطة] [❌ الملغاة] │
├─────────────────────────────────┤
│ التبويب الأول:                  │
│ - طلب 1 (قيد التوصيل)          │
│ - طلب 2 (تم التوصيل)           │
│ - طلب 3 (تم التوصيل)           │
│                                 │
│ التبويب الثاني:                 │
│ - طلب 4 (ملغي)                 │
└─────────────────────────────────┘
```

## ✨ المميزات

1. ✅ **تنظيم أفضل** - فصل واضح بين النشطة والملغاة
2. ✅ **سهولة التصفح** - سوايب بين التبويبات
3. ✅ **رسائل ذكية** - رسالة إيجابية عند عدم وجود ملغيات
4. ✅ **أيقونات مناسبة** - شاحنة للنشطة، إلغاء للملغاة
5. ✅ **RefreshIndicator** - التحديث بالسحب لأسفل في كلا التبويبين

## 🎯 حالات الطلبات

### طلبات نشطة (تبويب 1):
- `pending` - قيد الانتظار
- `confirmed` - تم التأكيد
- `in_preparation` - جاري التحضير
- `ready` - جاهز للتوصيل
- `on_the_way` - في الطريق
- `delivered` - تم التوصيل ✅

### طلبات ملغاة (تبويب 2):
- `cancelled` - تم الإلغاء ❌

## 📁 الملفات المُعدّلة
- ✅ `lib/screens/user/order_history_screen.dart`
  - إضافة `TabController`
  - إضافة `TabBar` و `TabBarView`
  - دالتين جديدتين: `_buildActiveOrdersTab` & `_buildCancelledOrdersTab`
  - حذف `_buildOrderList` القديمة

---

**تاريخ التطبيق**: 15 ديسمبر 2025  
**حالة الأخطاء**: ✅ لا توجد أخطاء  
**الحالة**: ✅ جاهز للاستخدام
