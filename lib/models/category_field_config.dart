/// نماذج تعريف الحقول الديناميكية حسب الفئة التجارية
class CategoryFieldConfig {
  final String categoryId;
  final String categoryName;
  final List<DynamicField> fields;

  CategoryFieldConfig({
    required this.categoryId,
    required this.categoryName,
    required this.fields,
  });

  /// الحصول على تكوين الحقول لفئة معينة باستخدام الاسم
  static CategoryFieldConfig? getConfigForCategory(String categoryName) {
    final configs = _allConfigs();
    return configs.firstWhere(
      (config) =>
          config.categoryName.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => CategoryFieldConfig(
        categoryId: 'default',
        categoryName: 'Default',
        fields: [],
      ),
    );
  }

  /// الحصول على تكوين الحقول لفئة معينة باستخدام ID
  /// يدعم UUID من قاعدة البيانات أو الـ categoryId المخصص
  static CategoryFieldConfig? getConfigForCategoryId(String categoryId) {
    final configs = _allConfigs();

    // أولاً: حاول البحث بالـ categoryId المخصص
    try {
      return configs.firstWhere(
        (config) => config.categoryId.toLowerCase() == categoryId.toLowerCase(),
      );
    } catch (e) {
      // ثانياً: إذا لم تجد، حاول البحث بالـ UUID (mapping)
      // هنا نضع mapping بين UUID من قاعدة البيانات والـ categoryId
      final categoryKeyMapping = _getCategoryKeyFromUUID(categoryId);
      if (categoryKeyMapping != null) {
        try {
          return configs.firstWhere(
            (config) =>
                config.categoryId.toLowerCase() ==
                categoryKeyMapping.toLowerCase(),
          );
        } catch (e) {
          return null;
        }
      }
      return null;
    }
  }

  /// Mapping بين UUID من قاعدة البيانات والـ categoryId
  static String? _getCategoryKeyFromUUID(String uuid) {
    final mapping = <String, String>{
      // UUID الفعلي من قاعدة البيانات -> categoryId
      '822c0cf0-3f31-4b8b-97a6-64e50bd72cd6': 'clothing', // ملابس وأزياء
      // أضف المزيد من الـ UUIDs هنا عند الحاجة
      // مثال:
      // 'uuid-مطاعم': 'restaurant',
      // 'uuid-إلكترونيات': 'electronics',
    };
    return mapping[uuid];
  }

  /// جميع تكوينات الفئات
  static List<CategoryFieldConfig> _allConfigs() {
    return [
      _restaurantConfig(),
      _clothingConfig(),
      _electronicsConfig(),
      _groceryConfig(),
      _pharmacyConfig(),
      _beautyConfig(),
      _homeGardenConfig(),
      _sportsConfig(),
      _booksConfig(),
      _toysConfig(),
      _petsConfig(),
      _servicesConfig(),
      // يمكن إضافة المزيد من الفئات هنا
    ];
  }

  /// تكوين فئة المطاعم
  static CategoryFieldConfig _restaurantConfig() {
    return CategoryFieldConfig(
      categoryId: 'restaurant',
      categoryName: 'Restaurant',
      fields: [
        // حجم الوجبة (مطلوب)
        DynamicField(
          id: 'meal_size',
          label: 'حجم الوجبة',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'small', label: 'صغير', price: 0),
            FieldOption(id: 'medium', label: 'وسط', price: 5),
            FieldOption(id: 'large', label: 'كبير', price: 10),
          ],
        ),
        // إضافات (اختياري - متعدد)
        DynamicField(
          id: 'additions',
          label: 'إضافات',
          type: FieldType.multipleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'extra_cheese', label: 'جبنة إضافية', price: 5),
            FieldOption(id: 'extra_sauce', label: 'صوص إضافي', price: 3),
            FieldOption(id: 'pickles', label: 'مخلل', price: 2),
            FieldOption(id: 'onions', label: 'بصل', price: 2),
          ],
        ),
        // نوع الخبز (للساندويتشات)
        DynamicField(
          id: 'bread_type',
          label: 'نوع الخبز',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'white', label: 'أبيض', price: 0),
            FieldOption(id: 'brown', label: 'أسمر', price: 2),
            FieldOption(id: 'sesame', label: 'سمسم', price: 3),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'sandwich',
          ),
        ),
        // مستوى الطبخ (للبرجر واللحوم)
        DynamicField(
          id: 'cooking_level',
          label: 'مستوى الطبخ',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'rare', label: 'نيء', price: 0),
            FieldOption(id: 'medium', label: 'متوسط', price: 0),
            FieldOption(id: 'well_done', label: 'مستوي', price: 0),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'burger,meat',
          ),
        ),
        // كمية الصوص
        DynamicField(
          id: 'sauce_quantity',
          label: 'كمية الصوص',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'light', label: 'خفيف', price: 0),
            FieldOption(id: 'normal', label: 'عادي', price: 0),
            FieldOption(id: 'extra', label: 'زيادة', price: 2),
          ],
        ),
        // كمية الثلج (للمشروبات)
        DynamicField(
          id: 'ice_quantity',
          label: 'كمية الثلج',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'no_ice', label: 'بدون ثلج', price: 0),
            FieldOption(id: 'little', label: 'قليل', price: 0),
            FieldOption(id: 'normal', label: 'عادي', price: 0),
            FieldOption(id: 'extra', label: 'كثير', price: 0),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'drink',
          ),
        ),
        // نوع الجبنة (للبرجر)
        DynamicField(
          id: 'cheese_type',
          label: 'نوع الجبنة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'cheddar', label: '🧀 شيدر', price: 5),
            FieldOption(id: 'mozzarella', label: '🧀 موتزاريلا', price: 6),
            FieldOption(id: 'swiss', label: '🧀 سويسري', price: 7),
            FieldOption(id: 'no_cheese', label: 'بدون جبنة', price: 0),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'burger',
          ),
        ),
        // نوع البطاطس (للبرجر)
        DynamicField(
          id: 'fries_type',
          label: 'نوع البطاطس',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'regular', label: '🍟 عادية', price: 0),
            FieldOption(id: 'sweet', label: '🍠 حلوة', price: 3),
            FieldOption(id: 'wedges', label: '🥔 ودجز', price: 4),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'burger',
          ),
        ),
        // حجم البيتزا
        DynamicField(
          id: 'pizza_size',
          label: 'حجم البيتزا',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'small', label: '🍕 صغيرة (25 سم)', price: 0),
            FieldOption(id: 'medium', label: '🍕 وسط (30 سم)', price: 10),
            FieldOption(id: 'large', label: '🍕 كبيرة (35 سم)', price: 20),
            FieldOption(id: 'family', label: '🍕 عائلي (40 سم)', price: 30),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'pizza',
          ),
        ),
        // نوع العجينة (للبيتزا)
        DynamicField(
          id: 'crust_type',
          label: 'نوع العجينة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'plain', label: '🧅 عادية', price: 0),
            FieldOption(id: 'cheese', label: '🧀 بالجبنة', price: 5),
            FieldOption(id: 'sausage', label: '🌭 بالسجق', price: 7),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'pizza',
          ),
        ),
        // إضافات البيتزا (متعددة)
        DynamicField(
          id: 'pizza_toppings',
          label: 'إضافات البيتزا',
          type: FieldType.multipleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'mushroom', label: '🍄 مشروم', price: 5),
            FieldOption(id: 'olive', label: '🫒 زيتون', price: 4),
            FieldOption(id: 'pepper', label: '🫑 فلفل', price: 4),
            FieldOption(id: 'tomato', label: '🍅 طماطم', price: 3),
            FieldOption(id: 'onion', label: '🧅 بصل', price: 3),
            FieldOption(id: 'corn', label: '🌽 ذرة', price: 4),
            FieldOption(id: 'pepperoni', label: '🍕 بيبروني', price: 8),
            FieldOption(id: 'beef', label: '🥩 لحم بقري', price: 10),
            FieldOption(id: 'chicken', label: '🍗 دجاج', price: 8),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'pizza',
          ),
        ),
      ],
    );
  }

  /// تكوين فئة الملابس
  static CategoryFieldConfig _clothingConfig() {
    return CategoryFieldConfig(
      categoryId: 'clothing',
      categoryName: 'Clothing',
      fields: [
        // المقاسات (اختيار متعدد)
        DynamicField(
          id: 'sizes',
          label: 'المقاسات المتوفرة',
          type: FieldType.multipleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'xs', label: 'XS', price: 0),
            FieldOption(id: 's', label: 'S', price: 0),
            FieldOption(id: 'm', label: 'M', price: 0),
            FieldOption(id: 'l', label: 'L', price: 0),
            FieldOption(id: 'xl', label: 'XL', price: 0),
            FieldOption(id: 'xxl', label: 'XXL', price: 0),
            FieldOption(id: '3xl', label: '3XL', price: 0),
            FieldOption(id: '4xl', label: '4XL', price: 0),
            FieldOption(id: '5xl', label: '5XL', price: 0),
            FieldOption(id: '6xl', label: '6XL', price: 0),
          ],
        ),
        // الألوان المتوفرة (اختيار متعدد)
        DynamicField(
          id: 'colors',
          label: 'الألوان المتوفرة',
          type: FieldType.multipleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'white', label: 'ابيض', price: 0),
            FieldOption(id: 'black', label: 'اسود', price: 0),
          ],
        ),
        // لون إضافي (نص حر)
        DynamicField(
          id: 'custom_color',
          label: 'لون إضافي (اختياري)',
          type: FieldType.text,
          isRequired: false,
        ),
        // الخامة (نص حر)
        DynamicField(
          id: 'material',
          label: 'الخامة (مثال: قطن، بوليستر، حرير، صوف)',
          type: FieldType.text,
          isRequired: false,
        ),
      ],
    );
  }

  /// تكوين فئة الإلكترونيات
  static CategoryFieldConfig _electronicsConfig() {
    return CategoryFieldConfig(
      categoryId: 'electronics',
      categoryName: 'Electronics',
      fields: [
        // اللون
        DynamicField(
          id: 'color',
          label: 'اللون',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'black', label: 'أسود', price: 0),
            FieldOption(id: 'white', label: 'أبيض', price: 0),
            FieldOption(id: 'silver', label: 'فضي', price: 0),
            FieldOption(id: 'gold', label: 'ذهبي', price: 50),
          ],
        ),
        // الضمان
        DynamicField(
          id: 'warranty',
          label: 'الضمان',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'no_warranty', label: 'بدون ضمان', price: 0),
            FieldOption(id: '1_year', label: 'سنة واحدة', price: 50),
            FieldOption(id: '2_years', label: 'سنتان', price: 100),
            FieldOption(id: '3_years', label: '3 سنوات', price: 150),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة البقالة / السوبر ماركت
  static CategoryFieldConfig _groceryConfig() {
    return CategoryFieldConfig(
      categoryId: 'grocery',
      categoryName: 'Grocery',
      fields: [
        // الحجم / الوزن
        DynamicField(
          id: 'package_size',
          label: 'حجم العبوة',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'small', label: 'صغير', price: 0),
            FieldOption(id: 'medium', label: 'وسط', price: 5),
            FieldOption(id: 'large', label: 'كبير', price: 10),
            FieldOption(id: 'family', label: 'عائلي', price: 20),
          ],
        ),
        // الكمية
        DynamicField(
          id: 'quantity_unit',
          label: 'وحدة القياس',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'piece', label: 'قطعة', price: 0),
            FieldOption(id: 'kg', label: 'كيلوجرام', price: 0),
            FieldOption(id: 'gram', label: 'جرام', price: 0),
            FieldOption(id: 'liter', label: 'لتر', price: 0),
            FieldOption(id: 'pack', label: 'عبوة', price: 0),
          ],
        ),
        // طريقة التخزين
        DynamicField(
          id: 'storage_type',
          label: 'طريقة التخزين',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'room_temp', label: 'درجة حرارة الغرفة', price: 0),
            FieldOption(id: 'refrigerated', label: 'مبرد', price: 0),
            FieldOption(id: 'frozen', label: 'مجمد', price: 0),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الصيدلية
  static CategoryFieldConfig _pharmacyConfig() {
    return CategoryFieldConfig(
      categoryId: 'pharmacy',
      categoryName: 'Pharmacy',
      fields: [
        // نوع المنتج
        DynamicField(
          id: 'product_category',
          label: 'فئة المنتج',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'medicine', label: 'دواء', price: 0),
            FieldOption(id: 'supplement', label: 'مكمل غذائي', price: 0),
            FieldOption(id: 'cosmetic', label: 'مستحضرات تجميل', price: 0),
            FieldOption(id: 'medical_device', label: 'جهاز طبي', price: 0),
          ],
        ),
        // شكل الدواء
        DynamicField(
          id: 'medicine_form',
          label: 'الشكل الدوائي',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'tablet', label: 'أقراص', price: 0),
            FieldOption(id: 'capsule', label: 'كبسولات', price: 0),
            FieldOption(id: 'syrup', label: 'شراب', price: 0),
            FieldOption(id: 'cream', label: 'كريم', price: 0),
            FieldOption(id: 'injection', label: 'حقن', price: 5),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_category',
            value: 'medicine',
          ),
        ),
        // الحجم
        DynamicField(
          id: 'package_size',
          label: 'حجم العبوة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'small', label: 'صغير', price: 0),
            FieldOption(id: 'medium', label: 'وسط', price: 5),
            FieldOption(id: 'large', label: 'كبير', price: 10),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة التجميل والصحة
  static CategoryFieldConfig _beautyConfig() {
    return CategoryFieldConfig(
      categoryId: 'beauty',
      categoryName: 'Beauty',
      fields: [
        // نوع المنتج
        DynamicField(
          id: 'product_type',
          label: 'نوع المنتج',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'skincare', label: 'العناية بالبشرة', price: 0),
            FieldOption(id: 'haircare', label: 'العناية بالشعر', price: 0),
            FieldOption(id: 'makeup', label: 'مكياج', price: 0),
            FieldOption(id: 'fragrance', label: 'عطور', price: 0),
          ],
        ),
        // نوع البشرة
        DynamicField(
          id: 'skin_type',
          label: 'نوع البشرة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'all', label: 'جميع أنواع البشرة', price: 0),
            FieldOption(id: 'dry', label: 'جافة', price: 0),
            FieldOption(id: 'oily', label: 'دهنية', price: 0),
            FieldOption(id: 'combination', label: 'مختلطة', price: 0),
            FieldOption(id: 'sensitive', label: 'حساسة', price: 5),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'skincare',
          ),
        ),
        // الحجم
        DynamicField(
          id: 'size',
          label: 'الحجم',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: '50ml', label: '50 مل', price: 0),
            FieldOption(id: '100ml', label: '100 مل', price: 5),
            FieldOption(id: '200ml', label: '200 مل', price: 10),
            FieldOption(id: '500ml', label: '500 مل', price: 20),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة المنزل والحديقة
  static CategoryFieldConfig _homeGardenConfig() {
    return CategoryFieldConfig(
      categoryId: 'home_garden',
      categoryName: 'Home & Garden',
      fields: [
        // نوع المنتج
        DynamicField(
          id: 'category',
          label: 'الفئة',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'furniture', label: 'أثاث', price: 0),
            FieldOption(id: 'decor', label: 'ديكور', price: 0),
            FieldOption(id: 'kitchen', label: 'أدوات مطبخ', price: 0),
            FieldOption(id: 'garden', label: 'أدوات حديقة', price: 0),
          ],
        ),
        // المادة
        DynamicField(
          id: 'material',
          label: 'المادة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'wood', label: 'خشب', price: 0),
            FieldOption(id: 'metal', label: 'معدن', price: 5),
            FieldOption(id: 'plastic', label: 'بلاستيك', price: 0),
            FieldOption(id: 'glass', label: 'زجاج', price: 10),
            FieldOption(id: 'fabric', label: 'قماش', price: 0),
          ],
        ),
        // اللون
        DynamicField(
          id: 'color',
          label: 'اللون',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'white', label: 'أبيض', price: 0),
            FieldOption(id: 'black', label: 'أسود', price: 0),
            FieldOption(id: 'brown', label: 'بني', price: 0),
            FieldOption(id: 'gray', label: 'رمادي', price: 0),
            FieldOption(id: 'beige', label: 'بيج', price: 0),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الرياضة واللياقة
  static CategoryFieldConfig _sportsConfig() {
    return CategoryFieldConfig(
      categoryId: 'sports',
      categoryName: 'Sports',
      fields: [
        // نوع الرياضة
        DynamicField(
          id: 'sport_type',
          label: 'نوع الرياضة',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'gym', label: 'كمال أجسام', price: 0),
            FieldOption(id: 'running', label: 'جري', price: 0),
            FieldOption(id: 'football', label: 'كرة قدم', price: 0),
            FieldOption(id: 'basketball', label: 'كرة سلة', price: 0),
            FieldOption(id: 'swimming', label: 'سباحة', price: 0),
            FieldOption(id: 'yoga', label: 'يوجا', price: 0),
          ],
        ),
        // المقاس
        DynamicField(
          id: 'size',
          label: 'المقاس',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 's', label: 'S', price: 0),
            FieldOption(id: 'm', label: 'M', price: 0),
            FieldOption(id: 'l', label: 'L', price: 0),
            FieldOption(id: 'xl', label: 'XL', price: 5),
            FieldOption(id: 'xxl', label: 'XXL', price: 10),
          ],
        ),
        // اللون
        DynamicField(
          id: 'color',
          label: 'اللون',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'black', label: 'أسود', price: 0),
            FieldOption(id: 'blue', label: 'أزرق', price: 0),
            FieldOption(id: 'red', label: 'أحمر', price: 0),
            FieldOption(id: 'white', label: 'أبيض', price: 0),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الكتب والقرطاسية
  static CategoryFieldConfig _booksConfig() {
    return CategoryFieldConfig(
      categoryId: 'books',
      categoryName: 'Books & Stationery',
      fields: [
        // نوع المنتج
        DynamicField(
          id: 'product_type',
          label: 'نوع المنتج',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'book', label: 'كتاب', price: 0),
            FieldOption(id: 'notebook', label: 'دفتر', price: 0),
            FieldOption(id: 'pen', label: 'قلم', price: 0),
            FieldOption(
              id: 'office_supplies',
              label: 'مستلزمات مكتبية',
              price: 0,
            ),
          ],
        ),
        // نوع الكتاب
        DynamicField(
          id: 'book_type',
          label: 'نوع الكتاب',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'paperback', label: 'غلاف عادي', price: 0),
            FieldOption(id: 'hardcover', label: 'غلاف صلب', price: 10),
            FieldOption(id: 'ebook', label: 'كتاب إلكتروني', price: -5),
          ],
          conditionalDisplay: ConditionalDisplay(
            field: 'product_type',
            value: 'book',
          ),
        ),
        // اللغة
        DynamicField(
          id: 'language',
          label: 'اللغة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'arabic', label: 'عربي', price: 0),
            FieldOption(id: 'english', label: 'إنجليزي', price: 0),
            FieldOption(id: 'french', label: 'فرنسي', price: 5),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الألعاب والأطفال
  static CategoryFieldConfig _toysConfig() {
    return CategoryFieldConfig(
      categoryId: 'toys',
      categoryName: 'Toys & Kids',
      fields: [
        // الفئة العمرية
        DynamicField(
          id: 'age_range',
          label: 'الفئة العمرية',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: '0-2', label: '0-2 سنة', price: 0),
            FieldOption(id: '3-5', label: '3-5 سنوات', price: 0),
            FieldOption(id: '6-8', label: '6-8 سنوات', price: 0),
            FieldOption(id: '9-12', label: '9-12 سنة', price: 0),
            FieldOption(id: '13+', label: '13+ سنة', price: 0),
          ],
        ),
        // نوع اللعبة
        DynamicField(
          id: 'toy_type',
          label: 'نوع اللعبة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'educational', label: 'تعليمية', price: 0),
            FieldOption(id: 'action', label: 'أكشن', price: 0),
            FieldOption(id: 'puzzle', label: 'ألغاز', price: 0),
            FieldOption(id: 'doll', label: 'دمى', price: 0),
            FieldOption(id: 'electronic', label: 'إلكترونية', price: 10),
          ],
        ),
        // اللون
        DynamicField(
          id: 'color',
          label: 'اللون',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'multicolor', label: 'متعدد الألوان', price: 0),
            FieldOption(id: 'blue', label: 'أزرق', price: 0),
            FieldOption(id: 'pink', label: 'وردي', price: 0),
            FieldOption(id: 'red', label: 'أحمر', price: 0),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الحيوانات الأليفة
  static CategoryFieldConfig _petsConfig() {
    return CategoryFieldConfig(
      categoryId: 'pets',
      categoryName: 'Pets',
      fields: [
        // نوع الحيوان
        DynamicField(
          id: 'pet_type',
          label: 'نوع الحيوان',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'dog', label: 'كلاب', price: 0),
            FieldOption(id: 'cat', label: 'قطط', price: 0),
            FieldOption(id: 'bird', label: 'طيور', price: 0),
            FieldOption(id: 'fish', label: 'أسماك', price: 0),
            FieldOption(id: 'other', label: 'أخرى', price: 0),
          ],
        ),
        // فئة المنتج
        DynamicField(
          id: 'product_category',
          label: 'فئة المنتج',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'food', label: 'طعام', price: 0),
            FieldOption(id: 'toy', label: 'لعبة', price: 0),
            FieldOption(id: 'accessory', label: 'إكسسوار', price: 0),
            FieldOption(id: 'health', label: 'صحة وعناية', price: 5),
          ],
        ),
        // الحجم
        DynamicField(
          id: 'size',
          label: 'الحجم',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'small', label: 'صغير', price: 0),
            FieldOption(id: 'medium', label: 'وسط', price: 5),
            FieldOption(id: 'large', label: 'كبير', price: 10),
          ],
        ),
      ],
    );
  }

  /// تكوين فئة الخدمات
  static CategoryFieldConfig _servicesConfig() {
    return CategoryFieldConfig(
      categoryId: 'services',
      categoryName: 'Services',
      fields: [
        // نوع الخدمة
        DynamicField(
          id: 'service_type',
          label: 'نوع الخدمة',
          type: FieldType.singleChoice,
          isRequired: true,
          options: [
            FieldOption(id: 'cleaning', label: 'تنظيف', price: 0),
            FieldOption(id: 'repair', label: 'صيانة', price: 0),
            FieldOption(id: 'delivery', label: 'توصيل', price: 0),
            FieldOption(id: 'installation', label: 'تركيب', price: 0),
            FieldOption(id: 'consultation', label: 'استشارات', price: 0),
          ],
        ),
        // المدة
        DynamicField(
          id: 'duration',
          label: 'المدة',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: '30min', label: '30 دقيقة', price: 0),
            FieldOption(id: '1hour', label: 'ساعة', price: 50),
            FieldOption(id: '2hours', label: 'ساعتان', price: 100),
            FieldOption(id: '3hours', label: '3 ساعات', price: 150),
            FieldOption(id: 'full_day', label: 'يوم كامل', price: 300),
          ],
        ),
        // الموقع
        DynamicField(
          id: 'location',
          label: 'الموقع',
          type: FieldType.singleChoice,
          isRequired: false,
          options: [
            FieldOption(id: 'home', label: 'في المنزل', price: 0),
            FieldOption(id: 'shop', label: 'في المحل', price: 0),
            FieldOption(id: 'online', label: 'عن بُعد', price: -20),
          ],
        ),
      ],
    );
  }
}

/// نوع الحقل
enum FieldType {
  singleChoice, // اختيار واحد (Radio buttons)
  multipleChoice, // اختيارات متعددة (Checkboxes)
  text, // نص
  number, // رقم
}

/// حقل ديناميكي
class DynamicField {
  final String id;
  final String label;
  final FieldType type;
  final bool isRequired;
  final List<FieldOption> options;
  final ConditionalDisplay? conditionalDisplay;

  DynamicField({
    required this.id,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.options = const [],
    this.conditionalDisplay,
  });
}

/// خيار للحقل
class FieldOption {
  final String id;
  final String label;
  final double price; // السعر الإضافي

  FieldOption({required this.id, required this.label, this.price = 0});
}

/// شرط عرض الحقل
class ConditionalDisplay {
  final String field; // الحقل المرتبط
  final String value; // القيمة المطلوبة (يمكن أن تكون قائمة مفصولة بفاصلة)

  ConditionalDisplay({required this.field, required this.value});

  /// التحقق من تطابق الشرط
  bool matches(String? currentValue) {
    if (currentValue == null) return false;
    final values = value.split(',');
    return values.contains(currentValue);
  }
}
