# 📋 عرض رقم الطلب في عناصر الطلب

## 📌 المشكلة
عندما يكون الطلب يحتوي على أكثر من منتج، كان يجب أن يظهر **رقم الطلب الرئيسي** نفسه لكل المنتجات حتى يعرف التاجر أن كل هذه المنتجات تنتمي لنفس الطلب.

## ✅ الحل المُطبق

### في شاشة طلبات التاجر (`merchant_orders_screen.dart`)

#### 1️⃣ تعديل توقيع الدوال
```dart
// قبل التعديل
Widget _buildOrderItemsSection(String orderId, ThemeData theme)
Widget _buildOrderItemCard(OrderItemModel item, ThemeData theme)

// بعد التعديل
Widget _buildOrderItemsSection(OrderModel order, ThemeData theme)
Widget _buildOrderItemCard(OrderItemModel item, OrderModel order, ThemeData theme)
```

#### 2️⃣ إضافة رقم الطلب في كارت المنتج
تم إضافة badge في أعلى كل كارت منتج يعرض رقم الطلب:

```dart
Widget _buildOrderItemCard(
    OrderItemModel item, OrderModel order, ThemeData theme) {
  return Container(
    child: Column(
      children: [
        // رقم الطلب في الأعلى
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16),
              SizedBox(width: 6),
              Text(
                'رقم الطلب: #${order.orderNumber ?? order.id.substring(0, 8)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        // ... باقي محتوى المنتج
      ],
    ),
  );
}
```

## 🎯 النتيجة

### قبل التعديل:
- كانت المنتجات تُعرض بدون توضيح رقم الطلب
- التاجر قد يتساءل: هل هذه المنتجات من نفس الطلب أم لا؟

### بعد التعديل:
- ✅ كل منتج يعرض رقم الطلب الرئيسي بوضوح
- ✅ إذا كان الطلب يحتوي على 3 منتجات، كلهم يعرضون نفس رقم الطلب
- ✅ التاجر يعرف مباشرة أن كل هذه المنتجات تنتمي لنفس الطلب

## 📊 مثال عملي

### طلب رقم #1234 يحتوي على 3 منتجات:

```
┌─────────────────────────────────────┐
│ 📋 رقم الطلب: #1234               │
├─────────────────────────────────────┤
│ 🍕 بيتزا                           │
│ الكمية: 2 • 50 ج.م                │
│ الإجمالي: 100 ج.م                 │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📋 رقم الطلب: #1234               │
├─────────────────────────────────────┤
│ 🥤 كوكاكولا                        │
│ الكمية: 1 • 10 ج.م                │
│ الإجمالي: 10 ج.م                  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📋 رقم الطلب: #1234               │
├─────────────────────────────────────┤
│ 🍟 بطاطس                           │
│ الكمية: 1 • 15 ج.م                │
│ الإجمالي: 15 ج.م                  │
└─────────────────────────────────────┘
```

## 🔧 الملفات المُعدّلة
- ✅ `lib/screens/merchant/merchant_orders_screen.dart`
  - `_buildOrderItemsSection()` - تمرير `OrderModel` بدلاً من `orderId`
  - `_buildOrderItemCard()` - إضافة رقم الطلب في الأعلى

## 📱 التأثير على الشاشات الأخرى
- ❌ لم يتم التعديل في شاشات المستخدم (لأنها لا تعرض تفاصيل المنتجات بنفس الطريقة)
- ✅ التعديل خاص بشاشة طلبات التاجر فقط

## 🎨 التصميم
- **Icon**: `Icons.receipt_long_rounded`
- **Color**: `primary` مع opacity 0.1 للخلفية
- **Border**: خفيف بـ opacity 0.3
- **Typography**: 12px, bold
- **Layout**: Horizontal مع icon في البداية

## ✨ المميزات الإضافية
1. ✅ رقم الطلب واضح ومرئي
2. ✅ نفس التصميم لكل المنتجات في نفس الطلب
3. ✅ لا يؤثر على باقي الكود
4. ✅ يستخدم `orderNumber` إن وُجد، وإلا يستخدم أول 8 أحرف من `id`

## 📝 ملاحظات تقنية
- البنية المستخدمة: `Column` بدلاً من `Row` مباشرة
- Badge رقم الطلب في الأعلى، ثم `Row` للمحتوى الأساسي
- استخدام `MainAxisSize.min` للبادج حتى يكون بحجم المحتوى فقط

---

**تاريخ التطبيق**: 15 ديسمبر 2025  
**حالة الأخطاء**: ✅ لا توجد أخطاء
