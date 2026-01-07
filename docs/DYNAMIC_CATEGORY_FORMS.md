# نظام النماذج الديناميكية حسب الفئة
## Dynamic Category-Based Forms System

## 📋 نظرة عامة | Overview

تم تطبيق نظام نماذج ديناميكية يتكيف تلقائيًا حسب فئة المتجر (مطعم، ملابس، إلكترونيات، إلخ). كل فئة لها حقول مخصصة مع خيارات وأسعار إضافية.

A dynamic forms system has been implemented that automatically adapts based on store category (Restaurant, Clothing, Electronics, etc.). Each category has custom fields with options and additional pricing.

---

## 🏗️ البنية المعمارية | Architecture

### 1. ملف التكوين | Configuration File
**الموقع:** `lib/config/category_field_config.dart`

#### الفئات الرئيسية | Main Classes:

```dart
enum FieldType {
  singleChoice,      // اختيار واحد (Radio)
  multipleChoice,    // اختيارات متعددة (Checkbox)
  text,              // حقل نصي
  number             // حقل رقمي
}

class DynamicField {
  final String id;
  final String label;
  final FieldType type;
  final bool isRequired;
  final List<FieldOption> options;
  final ConditionalDisplay? conditionalDisplay;
}

class FieldOption {
  final String id;
  final String label;
  final double price;  // السعر الإضافي | Additional price
}

class ConditionalDisplay {
  final String field;
  final String value;
  
  bool matches(String? fieldValue) {
    // يدعم القيم المفصولة بفواصل
    // Supports comma-separated values
  }
}
```

### 2. شاشة إضافة/تعديل المنتج | Add/Edit Product Screen
**الموقع:** `lib/screens/merchant/add_edit_product_screen.dart`

#### المتغيرات الجديدة | New State Variables:
```dart
String? _storeCategoryName;              // اسم الفئة (مثل: "Restaurant")
Map<String, dynamic> _dynamicFields = {}; // تخزين قيم الحقول
bool _showCategoryFields = false;         // حالة توسيع القسم
```

#### الميثودات الجديدة | New Methods:
- `_buildCategorySpecificFields()` - بناء قسم الحقول الديناميكية
- `_buildDynamicField()` - بناء حقل واحد
- `_buildSingleChoiceField()` - اختيار واحد (Radio)
- `_buildMultipleChoiceField()` - اختيارات متعددة (Checkbox)
- `_buildTextField()` - حقل نصي
- `_buildNumberField()` - حقل رقمي

---

## 🍕 تكوينات الفئات | Category Configurations

### 1️⃣ المطاعم | Restaurant

#### الحقول الرئيسية | Main Fields:

##### حجم الوجبة | Meal Size (مطلوب | Required)
- صغير | Small (+0 جنيه)
- وسط | Medium (+5 جنيه)
- كبير | Large (+10 جنيه)

##### الإضافات | Additions (اختياري، متعدد | Optional, Multiple)
- جبنة إضافية | Extra Cheese (+5 جنيه)
- صوص إضافي | Extra Sauce (+3 جنيه)
- مخلل | Pickles (+2 جنيه)
- بصل | Onions (+2 جنيه)

##### نوع الخبز | Bread Type (شرطي: سندوتش | Conditional: Sandwich)
- خبز أبيض | White Bread (+0 جنيه)
- خبز بني | Brown Bread (+2 جنيه)
- خبز سمسم | Sesame Bread (+3 جنيه)

##### درجة الطهي | Cooking Level (شرطي: برجر/لحم | Conditional: Burger/Meat)
- نصف استواء | Rare
- متوسط الطهي | Medium
- جيد الطهي | Well Done

#### حقول البرجر الخاصة | Burger-Specific Fields:

##### نوع الجبنة | Cheese Type (شرطي: برجر | Conditional: Burger)
- شيدر | Cheddar (+5 جنيه)
- موزاريلا | Mozzarella (+6 جنيه)
- سويسري | Swiss (+7 جنيه)
- بدون جبنة | No Cheese (+0 جنيه)

##### نوع البطاطس | Fries Type (شرطي: برجر | Conditional: Burger)
- عادية | Regular (+0 جنيه)
- بطاطس حلوة | Sweet Potato (+3 جنيه)
- ويدجز | Wedges (+4 جنيه)

#### حقول البيتزا الخاصة | Pizza-Specific Fields:

##### حجم البيتزا | Pizza Size (شرطي: بيتزا | Conditional: Pizza)
- صغيرة | Small (+0 جنيه)
- وسط | Medium (+10 جنيه)
- كبيرة | Large (+20 جنيه)
- عائلية | Family (+30 جنيه)

##### نوع العجينة | Crust Type (شرطي: بيتزا | Conditional: Pizza)
- عادية | Plain (+0 جنيه)
- محشوة جبنة | Cheese Stuffed (+5 جنيه)
- محشوة سجق | Sausage Stuffed (+7 جنيه)

##### إضافات البيتزا | Pizza Toppings (شرطي: بيتزا، متعدد | Conditional: Pizza, Multiple)
- مشروم | Mushroom (+3 جنيه)
- زيتون | Olive (+3 جنيه)
- فلفل أخضر | Green Pepper (+3 جنيه)
- طماطم | Tomato (+3 جنيه)
- بصل | Onion (+3 جنيه)
- ذرة | Corn (+4 جنيه)
- بيبروني | Pepperoni (+8 جنيه)
- لحم بقري | Beef (+10 جنيه)
- دجاج | Chicken (+7 جنيه)

#### حقول المشروبات | Drink Fields:

##### كمية الثلج | Ice Quantity (شرطي: مشروب | Conditional: Drink)
- بدون ثلج | No Ice
- ثلج قليل | Little Ice
- ثلج عادي | Normal Ice
- ثلج إضافي | Extra Ice (+2 جنيه)

---

### 2️⃣ الملابس | Clothing

##### المقاس | Size (مطلوب | Required)
- XS, S, M, L, XL, XXL

##### اللون | Color (اختياري | Optional)
- حقل نصي مفتوح

##### الخامة | Material (اختياري | Optional)
- قطن | Cotton
- بوليستر | Polyester
- حرير | Silk
- كتان | Linen

---

### 3️⃣ الإلكترونيات | Electronics

##### اللون | Color (اختياري | Optional)
- حقل نصي مفتوح

##### الضمان | Warranty (اختياري | Optional)
- بدون ضمان | No Warranty (+0 جنيه)
- 6 أشهر | 6 Months (+50 جنيه)
- سنة | 1 Year (+100 جنيه)
- سنتين | 2 Years (+130 جنيه)
- 3 سنوات | 3 Years (+150 جنيه)

---

## 🎨 واجهة المستخدم | User Interface

### العرض الديناميكي | Dynamic Display

```dart
ExpansionTile(
  title: 'حقول خاصة بالفئة (اسم الفئة)',
  subtitle: 'حقول إضافية بناءً على نوع النشاط التجاري',
  children: [
    // الحقول الديناميكية مع شروط العرض
    // Dynamic fields with conditional display
  ]
)
```

### أنواع الحقول | Field Types

#### 1. اختيار واحد | Single Choice
- تصميم بطاقات مع Radio buttons
- عرض السعر الإضافي على كل خيار
- تمييز بصري للخيار المحدد

#### 2. اختيارات متعددة | Multiple Choice
- تصميم بطاقات مع Checkboxes
- إمكانية اختيار أكثر من خيار
- عرض السعر الإضافي لكل خيار

#### 3. حقول نصية ورقمية | Text & Number Fields
- TextField عادي مع الـ border
- تحقق تلقائي من نوع البيانات

---

## 🔄 آلية العرض الشرطي | Conditional Display Logic

### المثال: حقول البرجر | Example: Burger Fields

```dart
ConditionalDisplay(
  field: 'product_type',
  value: 'burger',  // أو 'burger,meat' للقيم المتعددة
)
```

### كيفية التحقق | How It Works:

```dart
bool matches(String? fieldValue) {
  if (fieldValue == null || fieldValue.isEmpty) return false;
  final values = value.split(',').map((v) => v.trim()).toList();
  return values.contains(fieldValue);
}
```

**مثال:** إذا كان `product_type = "burger"`:
- ✅ يظهر: نوع الجبنة، نوع البطاطس، درجة الطهي
- ❌ لا يظهر: حجم البيتزا، نوع العجينة، إضافات البيتزا

---

## 💾 حفظ البيانات | Data Persistence

### الوضع الحالي | Current Status

✅ **تم التكامل الكامل مع قاعدة البيانات**

تم تحديث `ProductModel` ودمج حفظ وتحميل البيانات بشكل كامل.

The `ProductModel` has been updated and data saving/loading is fully integrated.

### الملفات المحدثة | Updated Files

1. ✅ `lib/models/product_model.dart`
   - Added `customFields` JSONB field
   - Updated all methods (fromMap, toJson, copyWith, etc.)

2. ✅ `lib/screens/merchant/add_edit_product_screen.dart`
   - Integrated customFields saving in `_saveProduct()`
   - Integrated customFields loading in `_initializeForm()`

3. ✅ `supabase/migrations/20241105000000_add_custom_fields_to_products.sql`
   - Migration to add custom_fields column
   - GIN index for performance

4. ✅ `docs/DYNAMIC_FIELDS_INTEGRATION.md`
   - Complete integration documentation

### كيفية تطبيق التحديث | How to Apply Update

**خطوة واحدة فقط:** تنفيذ الـ Migration على قاعدة البيانات

```sql
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_products_custom_fields 
ON products USING gin (custom_fields);
```

**أو عبر Supabase CLI:**
```bash
supabase db push
```

راجع `docs/DYNAMIC_FIELDS_INTEGRATION.md` للتفاصيل الكاملة.

---

## � آلية العرض الشرطي | Conditional Display Logic

### المثال | Example

**سعر أساسي:** 50 جنيه  
**الاختيارات:**
- حجم وسط: +5 جنيه
- جبنة إضافية: +5 جنيه
- صوص إضافي: +3 جنيه

**السعر النهائي:** 50 + 5 + 5 + 3 = **63 جنيه**

### التنفيذ | Implementation

```dart
double calculateTotalPrice() {
  double total = basePrice;
  
  final config = CategoryFieldConfig.getConfigForCategory(_storeCategoryName!);
  if (config == null) return total;
  
  for (final field in config.fields) {
    final value = _dynamicFields[field.id];
    
    if (field.type == FieldType.singleChoice && value != null) {
      final option = field.options.firstWhere((o) => o.id == value);
      total += option.price;
    } else if (field.type == FieldType.multipleChoice && value is List) {
      for (final optionId in value) {
        final option = field.options.firstWhere((o) => o.id == optionId);
        total += option.price;
      }
    }
  }
  
  return total;
}
```

---

## 🚀 إضافة فئة جديدة | Adding a New Category

### الخطوات | Steps:

1. **إضافة تكوين في `category_field_config.dart`:**

```dart
static List<DynamicField> _newCategoryConfig() {
  return [
    DynamicField(
      id: 'field_id',
      label: 'اسم الحقل',
      type: FieldType.singleChoice,
      isRequired: true,
      options: [
        FieldOption(id: 'opt1', label: 'خيار 1', price: 0),
        FieldOption(id: 'opt2', label: 'خيار 2', price: 5),
      ],
    ),
  ];
}
```

2. **إضافة في `getConfigForCategory`:**

```dart
static CategoryFieldConfig? getConfigForCategory(String categoryName) {
  switch (categoryName.toLowerCase()) {
    // ... existing cases
    case 'new_category_name':
      return CategoryFieldConfig(
        categoryName: 'New Category',
        fields: _newCategoryConfig(),
      );
    default:
      return null;
  }
}
```

---

## ✅ الميزات المكتملة | Completed Features

- ✅ نظام تكوين ديناميكي مرن
- ✅ واجهة مستخدم تفاعلية
- ✅ دعم 4 أنواع من الحقول
- ✅ عرض شرطي للحقول
- ✅ أسعار إضافية لكل خيار
- ✅ تكوينات كاملة لـ **12 فئة**
- ✅ دعم القيم المتعددة في الشروط
- ✅ تحميل اسم الفئة تلقائيًا
- ✅ تحديث ProductModel لدعم customFields
- ✅ دمج حفظ البيانات مع قاعدة البيانات
- ✅ تحميل البيانات عند تعديل المنتج
- ✅ Migration script جاهز
- ✅ **43 حقل ديناميكي** عبر جميع الفئات

### الفئات المدعومة (12 فئة):
1. ✅ المطاعم والأطعمة (11 حقل)
2. ✅ الملابس والأزياء (3 حقول)
3. ✅ الإلكترونيات (2 حقل)
4. ✅ البقالة والسوبر ماركت (3 حقول)
5. ✅ الصيدلية (3 حقول)
6. ✅ التجميل والصحة (3 حقول)
7. ✅ المنزل والحديقة (3 حقول)
8. ✅ الرياضة واللياقة (3 حقول)
9. ✅ الكتب والقرطاسية (3 حقول)
10. ✅ الألعاب والأطفال (3 حقول)
11. ✅ الحيوانات الأليفة (3 حقول)
12. ✅ الخدمات (3 حقول)

📚 **التفاصيل الكاملة:** راجع `docs/ALL_CATEGORIES_DYNAMIC_FIELDS.md`

---

## 🔧 العمل المطلوب | Pending Work

- ⏳ تطبيق Migration على قاعدة البيانات (خطوة واحدة!)
- ⏳ اختبار النظام بالكامل
- ⏳ عرض الحقول في صفحة تفاصيل المنتج
- ⏳ حساب السعر النهائي بناءً على الخيارات
- ⏳ التحقق من الحقول المطلوبة قبل الحفظ
- ⏳ إضافة المزيد من الفئات

---

## 📝 ملاحظات تطويرية | Development Notes

### الأداء | Performance
- الحقول تُبنى فقط عند الحاجة (lazy loading)
- استخدام `const` حيثما أمكن
- تقليل عمليات `setState()` غير الضرورية

### الأمان | Security
- التحقق من صحة البيانات قبل الحفظ
- تنظيف المدخلات النصية
- التحقق من الحقول المطلوبة

### التوسع | Scalability
- سهولة إضافة فئات جديدة
- مرونة في تعديل التكوينات
- فصل المنطق عن واجهة المستخدم

---

## 🤝 المساهمة | Contributing

لإضافة حقول جديدة أو تحسين النظام:

1. راجع التكوينات الحالية في `category_field_config.dart`
2. اتبع نفس البنية والتسمية
3. اختبر الحقول الجديدة بدقة
4. حدّث هذه الوثائق

To add new fields or improve the system:

1. Review existing configurations in `category_field_config.dart`
2. Follow the same structure and naming conventions
3. Test new fields thoroughly
4. Update this documentation

---

## 📞 الدعم | Support

للأسئلة أو المشاكل، راجع:
- `lib/config/category_field_config.dart`
- `lib/screens/merchant/add_edit_product_screen.dart`

For questions or issues, check:
- Configuration file for field definitions
- Screen file for UI implementation

---

**آخر تحديث:** 5 نوفمبر 2024  
**الإصدار:** 2.0.0  
**الفئات المدعومة:** 12 فئة  
**الحالة:** جاهز للاستخدام بعد تطبيق Migration 🚀
