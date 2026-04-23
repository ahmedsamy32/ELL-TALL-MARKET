// Removed dart:io for Web compatibility
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/core/logger.dart';

/// Category Provider - يعمل فقط مع قاعدة البيانات Supabase
/// لا يحتوي على بيانات تجريبية - يعتمد بالكامل على قاعدة البيانات
/// https://supabase.com/docs/reference/dart/installing
/// https://supabase.com/docs/reference/dart/select
/// https://supabase.com/docs/reference/dart/insert
class CategoryProvider with ChangeNotifier {
  // استخدام Supabase Client مباشرة حسب الوثائق الرسمية
  final _supabase = Supabase.instance.client;

  List<CategoryModel> _categories = [];
  List<CategoryModel> _mainCategories = [];
  final List<CategoryModel> _featuredCategories = [];

  bool _availabilityScopeActive = false;
  Set<String> _availableCategoryIds = <String>{};
  Set<String> _availableCategoryNamesFromStores = <String>{};
  Set<String> _availableCategoryIdsFromProducts = <String>{};

  bool _isLoading = false;
  String? _error;
  CategoryModel? _selectedCategory;

  // ===== Getters =====
  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get mainCategories => _mainCategories;
  List<CategoryModel> get featuredCategories => _featuredCategories;

  bool get availabilityScopeActive => _availabilityScopeActive;
  Set<String> get availableCategoryIds => _availableCategoryIds;
  List<CategoryModel> get availableCategories => !_availabilityScopeActive
      ? _categories
      : _categories.where((c) => _availableCategoryIds.contains(c.id)).toList();
  List<CategoryModel> get availableMainCategories => !_availabilityScopeActive
      ? _mainCategories
      : _mainCategories
            .where((c) => _availableCategoryIds.contains(c.id))
            .toList();
  List<CategoryModel> get availableFeaturedCategories =>
      !_availabilityScopeActive
      ? _featuredCategories
      : _featuredCategories
            .where((c) => _availableCategoryIds.contains(c.id))
            .toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  CategoryModel? get selectedCategory => _selectedCategory;

  // Getters إضافية لحالة البيانات
  bool get hasCategories => _categories.isNotEmpty;
  bool get isEmpty => _categories.isEmpty && !_isLoading;
  bool get hasError => _error != null;
  String get statusMessage {
    if (_isLoading) return 'جاري تحميل الفئات...';
    if (hasError) return _error!;
    if (isEmpty) return 'لا توجد فئات متاحة';
    return 'تم تحميل ${_categories.length} فئة';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// جلب الفئات من Supabase باستخدام الوثائق الرسمية مع إعادة المحاولة
  /// https://supabase.com/docs/reference/dart/select
  Future<void> fetchCategories({bool refresh = false}) async {
    if (!refresh && _categories.isNotEmpty) return;

    if (refresh) {
      _categories = [];
      _mainCategories = [];
      _featuredCategories.clear();
      notifyListeners();
    }

    _setLoading(true);
    _setError(null);

    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.info(
          "جلب الفئات من Supabase... (محاولة $attempt/$maxRetries)",
        );

        // جلب البيانات من قاعدة البيانات باستخدام Supabase Client
        final response = await _supabase
            .from('categories')
            .select('*')
            .eq('is_active', true) // جلب الفئات النشطة فقط
            .order(
              'display_order',
              ascending: true,
            ) // الترتيب حسب display_order
            .order('name', ascending: true) // ثم حسب الاسم
            .timeout(
              const Duration(seconds: 30), // مهلة أطول للشبكات البطيئة
            );

        AppLogger.debug("استجابة Supabase: ${response.length} فئة");

        // تحويل البيانات إلى نماذج
        _categories = (response as List)
            .map((data) => CategoryModel.fromMap(data))
            .toList();

        // التحقق من وجود فئات
        if (_categories.isEmpty) {
          AppLogger.warning("لا توجد فئات في قاعدة البيانات");
          _mainCategories = [];
          _featuredCategories.clear();
          _setError('لا توجد فئات متاحة حالياً - يرجى المحاولة لاحقاً');
        } else {
          // تصنيف الفئات
          _mainCategories = List.from(_categories); // جميع الفئات أساسية
          _featuredCategories.clear();
          _featuredCategories.addAll(
            _categories.take(6).toList(),
          ); // أول 6 كفئات مميزة

          if (_availabilityScopeActive) {
            _recomputeAvailableCategoryIds();
          }

          _setError(null);
          AppLogger.info("تم جلب ${_categories.length} فئة من قاعدة البيانات");
        }

        _setLoading(false); // إيقاف حالة التحميل عند النجاح
        return; // نجحت العملية، اخرج من الحلقة
      } catch (e) {
        final isNetworkError = e.toString().contains('SocketException');
        final isTimeoutError =
            e.toString().contains('TimeoutException') ||
            e.toString().contains('انتهت مهلة الاتصال');

        if (isNetworkError || isTimeoutError) {
          final errorType = isTimeoutError ? 'انتهاء المهلة' : 'خطأ في الشبكة';
          AppLogger.error(
            "$errorType عند جلب الفئات (محاولة $attempt/$maxRetries)",
            e,
          );

          if (attempt == maxRetries) {
            // في حالة فشل جميع المحاولات
            AppLogger.error(
              "فشل جلب الفئات من الخادم نهائياً بعد $maxRetries محاولات",
              e,
            );
            _categories = [];
            _mainCategories = [];
            _featuredCategories.clear();
            _setError(
              'لا يمكن جلب الفئات - تحقق من اتصال الإنترنت وأعد المحاولة',
            );
            return;
          }
        } else {
          AppLogger.error("خطأ في جلب الفئات (محاولة $attempt/$maxRetries)", e);

          if (attempt == maxRetries) {
            // في حالة فشل الـ API نهائياً
            AppLogger.error(
              "فشل جلب الفئات نهائياً بعد $maxRetries محاولات",
              e,
            );
            _categories = [];
            _mainCategories = [];
            _featuredCategories.clear();
            _setError('حدث خطأ في الخادم - أعد المحاولة لاحقاً');
            return;
          }
        }

        // انتظار متزايد بين المحاولات (exponential backoff)
        final delay = Duration(seconds: baseDelay.inSeconds * attempt);
        AppLogger.info('⏳ إعادة المحاولة خلال ${delay.inSeconds} ثانية...');
        await Future.delayed(delay);
      }
    }

    // التأكد من إعادة تعيين حالة التحميل
    _setLoading(false);
  }

  /// تفعيل/تحديث نطاق الفئات المتاحة بناءً على المتاجر القريبة
  /// القاعدة: الفئة تظهر فقط إذا كان لها (منتجات) داخل allowedStoreIds
  /// أو (متاجر) داخل allowedStoreIds مرتبطة بالاسم (stores.category)
  Future<void> applyAvailabilityScope({List<String>? allowedStoreIds}) async {
    if (allowedStoreIds == null) {
      clearAvailabilityScope();
      return;
    }

    _availabilityScopeActive = true;

    if (allowedStoreIds.isEmpty) {
      _availableCategoryNamesFromStores = <String>{};
      _availableCategoryIdsFromProducts = <String>{};
      _availableCategoryIds = <String>{};
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait<Set<String>>([
        _fetchAvailableStoreCategoryNames(allowedStoreIds),
        _fetchAvailableProductCategoryIds(allowedStoreIds),
      ]);

      _availableCategoryNamesFromStores = results[0];
      _availableCategoryIdsFromProducts = results[1];
      _recomputeAvailableCategoryIds();
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في تطبيق نطاق الفئات المتاحة', e);
      // في حال فشل حساب النطاق، نعود للوضع الافتراضي (عرض كل الفئات)
      _availabilityScopeActive = false;
      _availableCategoryIds = <String>{};
      _availableCategoryNamesFromStores = <String>{};
      _availableCategoryIdsFromProducts = <String>{};
      notifyListeners();
    }
  }

  void clearAvailabilityScope() {
    if (!_availabilityScopeActive) return;
    _availabilityScopeActive = false;
    _availableCategoryIds = <String>{};
    _availableCategoryNamesFromStores = <String>{};
    _availableCategoryIdsFromProducts = <String>{};
    notifyListeners();
  }

  void _recomputeAvailableCategoryIds() {
    final available = <String>{..._availableCategoryIdsFromProducts};
    if (_availableCategoryNamesFromStores.isNotEmpty) {
      for (final category in _categories) {
        if (_availableCategoryNamesFromStores.contains(category.name)) {
          available.add(category.id);
        }
      }
    }
    _availableCategoryIds = available;
  }

  Future<Set<String>> _fetchAvailableStoreCategoryNames(
    List<String> allowedStoreIds,
  ) async {
    final response = await _supabase
        .from('stores')
        .select('category')
        .eq('is_active', true)
        .inFilter('id', allowedStoreIds);

    final rows = (response as List).cast<dynamic>();
    final names = <String>{};
    for (final row in rows) {
      final map = (row as Map).cast<String, dynamic>();
      final value = map['category']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        names.add(value);
      }
    }
    return names;
  }

  Future<Set<String>> _fetchAvailableProductCategoryIds(
    List<String> allowedStoreIds,
  ) async {
    final response = await _supabase
        .from('products')
        .select('category_id')
        .eq('is_active', true)
        .inFilter('store_id', allowedStoreIds);

    final rows = (response as List).cast<dynamic>();
    final ids = <String>{};
    for (final row in rows) {
      final map = (row as Map).cast<String, dynamic>();
      final value = map['category_id']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        ids.add(value);
      }
    }
    return ids;
  }

  /// جلب الفئات المميزة من Supabase
  /// https://supabase.com/docs/reference/dart/select
  Future<void> fetchFeaturedCategories() async {
    try {
      AppLogger.info("جلب الفئات المميزة من Supabase...");

      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('is_active', true) // جلب الفئات النشطة فقط
          .order('display_order', ascending: true) // الترتيب حسب display_order
          .order('name', ascending: true) // ثم حسب الاسم
          .limit(6); // أخذ أول 6 فئات كمميزة

      _featuredCategories.clear();
      _featuredCategories.addAll(
        (response as List).map((data) => CategoryModel.fromMap(data)),
      );

      AppLogger.info("تم جلب ${_featuredCategories.length} فئة مميزة");
      notifyListeners();
    } catch (e) {
      AppLogger.error("خطأ في جلب الفئات المميزة", e);
      rethrow;
    }
  }

  /// إضافة فئة جديدة
  /// https://supabase.com/docs/reference/dart/insert
  Future<bool> addCategory(CategoryModel category) async {
    try {
      AppLogger.info("إضافة فئة جديدة: ${category.name}");

      final response = await _supabase
          .from('categories')
          .insert(category.toDatabaseMap())
          .select('*')
          .single();

      final newCategory = CategoryModel.fromMap(response);
      _categories.add(newCategory);

      // جميع الفئات هي فئات رئيسية
      _mainCategories.add(newCategory);

      notifyListeners();

      AppLogger.info("تم إضافة الفئة بنجاح");
      return true;
    } catch (e) {
      AppLogger.error("فشل في إضافة الفئة", e);
      return false;
    }
  }

  /// تحديث فئة موجودة
  /// https://supabase.com/docs/reference/dart/update
  Future<bool> updateCategory(CategoryModel category) async {
    try {
      AppLogger.info("تحديث الفئة: ${category.name}");

      await _supabase
          .from('categories')
          .update(category.toDatabaseMap())
          .eq('id', category.id);

      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;

        // تحديث في الفئات الرئيسية
        final mainIndex = _mainCategories.indexWhere(
          (c) => c.id == category.id,
        );
        if (mainIndex != -1) {
          _mainCategories[mainIndex] = category;
        }

        notifyListeners();
      }

      AppLogger.info("تم تحديث الفئة بنجاح");
      return true;
    } catch (e) {
      AppLogger.error("فشل في تحديث الفئة", e);
      return false;
    }
  }

  /// حذف فئة (حذف منطقي)
  /// https://supabase.com/docs/reference/dart/update
  Future<bool> deleteCategory(String categoryId) async {
    try {
      AppLogger.info("حذف الفئة: $categoryId");

      // حذف فعلي من قاعدة البيانات
      await _supabase.from('categories').delete().eq('id', categoryId);

      _categories.removeWhere((c) => c.id == categoryId);
      _mainCategories.removeWhere((c) => c.id == categoryId);
      notifyListeners();

      AppLogger.info("تم حذف الفئة بنجاح");
      return true;
    } catch (e) {
      AppLogger.error("فشل في حذف الفئة", e);
      return false;
    }
  }

  /// جلب فئة واحدة بواسطة المعرف
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('id', categoryId)
          .maybeSingle();

      if (response != null) {
        return CategoryModel.fromMap(response);
      }
      return null;
    } catch (e) {
      AppLogger.error("فشل في جلب الفئة", e);
      return null;
    }
  }

  // ===== إنشاء فئة افتراضية =====
  Future<void> createDefaultCategory() async {
    try {
      AppLogger.info("إنشاء فئة افتراضية...");

      final defaultCategory = CategoryModel(
        id: '', // سيتم توليد ID تلقائياً
        name: 'عام',
        description: 'فئة عامة للمنتجات',
        imageUrl: null,
        createdAt: DateTime.now(),
      );

      final success = await addCategory(defaultCategory);
      if (success) {
        AppLogger.info("تم إنشاء فئة افتراضية بنجاح");
        // إعادة جلب الفئات لتحديث القوائم
        await fetchCategories(refresh: true);
      } else {
        AppLogger.error("فشل في إنشاء الفئة الافتراضية");
      }
    } catch (e) {
      AppLogger.error("خطأ في إنشاء الفئة الافتراضية", e);
    }
  }

  // ===== تحديد الفئة المختارة =====
  void setSelectedCategory(CategoryModel? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // ===== البحث في الفئات =====
  List<CategoryModel> searchCategories(String query) {
    if (query.isEmpty) return _categories;

    return _categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(query.toLowerCase()) ||
              (category.description?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  // ===== إعادة المحاولة =====
  Future<void> retry() async {
    AppLogger.info("إعادة محاولة جلب الفئات...");
    await fetchCategories(refresh: true);
  }

  // ===== إعادة تعيين الحالة =====
  void resetState() {
    _categories.clear();
    _mainCategories.clear();
    _featuredCategories.clear();
    _selectedCategory = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // ===== تنظيف الموارد =====
  @override
  void dispose() {
    _categories.clear();
    _mainCategories.clear();
    _featuredCategories.clear();
    super.dispose();
  }
}
