import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/core/api_client.dart';

class CategoryProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final _supabase = Supabase.instance.client;

  List<CategoryModel> _categories = [];
  List<CategoryModel> _mainCategories = [];
  final List<CategoryModel> _featuredCategories = [];
  final Map<String, List<CategoryModel>> _subCategoriesMap = {};

  bool _isLoading = false;
  String? _error;
  CategoryModel? _selectedCategory;

  // ===== Getters =====
  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get mainCategories => _mainCategories;
  List<CategoryModel> get featuredCategories => _featuredCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CategoryModel? get selectedCategory => _selectedCategory;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ===== جلب كل الفئات =====
  Future<void> fetchCategories({bool refresh = false}) async {
    if (!refresh && _categories.isNotEmpty) return;

    _setLoading(true);

    try {
      // محاولة جلب البيانات من API
      final response = await _apiClient.getCategories();
      _categories = response.map((c) => CategoryModel.fromJson(c)).toList();

      // إذا لم توجد فئات في قاعدة البيانات، إنشاء فئات تجريبية
      if (_categories.isEmpty) {
        _categories = _createSampleCategories();
      }

      // تصنيف الفئات
      _mainCategories = _categories.where((c) => c.parentId == null).toList();
      _updateSubCategories();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching categories: $e');
      // في حالة فشل الـ API، إنشاء فئات تجريبية
      _categories = _createSampleCategories();
      _mainCategories = _categories.where((c) => c.parentId == null).toList();
      _updateSubCategories();
      notifyListeners();
      _setError('تم تحميل البيانات التجريبية - ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء فئات تجريبية =====
  List<CategoryModel> _createSampleCategories() {
    return [
      CategoryModel(
        id: '1',
        name: 'سوبر ماركت',
        icon: 'shopping_cart',
        imageUrl:
            'https://via.placeholder.com/150/4CAF50/white?text=سوبر+ماركت',
        isActive: true,
        isFeatured: true,
        order: 1,
        productCount: 250,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '2',
        name: 'صيدلية',
        icon: 'local_pharmacy',
        imageUrl: 'https://via.placeholder.com/150/2196F3/white?text=صيدلية',
        isActive: true,
        isFeatured: true,
        order: 2,
        productCount: 180,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '3',
        name: 'مطاعم',
        icon: 'restaurant',
        imageUrl: 'https://via.placeholder.com/150/FF9800/white?text=مطاعم',
        isActive: true,
        isFeatured: true,
        order: 3,
        productCount: 120,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '4',
        name: 'مخبز',
        icon: 'bakery_dining',
        imageUrl: 'https://via.placeholder.com/150/795548/white?text=مخبز',
        isActive: true,
        isFeatured: false,
        order: 4,
        productCount: 80,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '5',
        name: 'جزارة',
        icon: 'rice_bowl',
        imageUrl: 'https://via.placeholder.com/150/F44336/white?text=جزارة',
        isActive: true,
        isFeatured: false,
        order: 5,
        productCount: 60,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '6',
        name: 'خضروات وفواكه',
        icon: 'local_florist',
        imageUrl: 'https://via.placeholder.com/150/8BC34A/white?text=خضروات',
        isActive: true,
        isFeatured: true,
        order: 6,
        productCount: 95,
        createdAt: DateTime.now(),
      ),
    ];
  }

  // ===== تحديث تصنيف الفئات الفرعية =====
  void _updateSubCategories() {
    _subCategoriesMap.clear();
    for (var category in _mainCategories) {
      _subCategoriesMap[category.id] = _categories
          .where((c) => c.parentId == category.id)
          .toList();
    }
  }

  // ===== إضافة فئة جديدة =====
  Future<bool> addCategory(
    CategoryModel category, {
    File? iconFile,
    File? imageFile,
  }) async {
    try {
      String? iconUrl;
      String? imageUrl;

      // رفع الأيقونة إذا وجدت
      if (iconFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_icon.${iconFile.path.split('.').last}';
        await _supabase.storage.from('categories').upload(fileName, iconFile);
        iconUrl = _supabase.storage.from('categories').getPublicUrl(fileName);
      }

      // رفع الصورة إذا وجدت
      if (imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_image.${imageFile.path.split('.').last}';
        await _supabase.storage.from('categories').upload(fileName, imageFile);
        imageUrl = _supabase.storage.from('categories').getPublicUrl(fileName);
      }

      // إضافة الفئة إلى قاعدة البيانات
      final response = await _supabase
          .from('categories')
          .insert({
            ...category.toJson(),
            if (iconUrl != null) 'icon': iconUrl,
            if (imageUrl != null) 'image': imageUrl,
          })
          .select()
          .single();

      final newCategory = CategoryModel.fromJson(response);
      _categories.add(newCategory);

      if (newCategory.parentId == null) {
        _mainCategories.add(newCategory);
      } else {
        _updateSubCategories();
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error adding category: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== تحديث فئة =====
  Future<bool> updateCategory(
    CategoryModel category, {
    File? iconFile,
    File? imageFile,
  }) async {
    try {
      String? iconUrl;
      String? imageUrl;

      // رفع الأيقونة الجديدة إذا وجدت
      if (iconFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_icon.${iconFile.path.split('.').last}';
        await _supabase.storage.from('categories').upload(fileName, iconFile);
        iconUrl = _supabase.storage.from('categories').getPublicUrl(fileName);
      }

      // رفع الصورة الجديدة إذا وجدت
      if (imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_image.${imageFile.path.split('.').last}';
        await _supabase.storage.from('categories').upload(fileName, imageFile);
        imageUrl = _supabase.storage.from('categories').getPublicUrl(fileName);
      }

      // تحديث الفئة في قاعدة البيانات
      await _supabase
          .from('categories')
          .update({
            ...category.toJson(),
            if (iconUrl != null) 'icon': iconUrl,
            if (imageUrl != null) 'image': imageUrl,
          })
          .eq('id', category.id);

      // تحديث القائمة المحلية
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        if (category.parentId == null) {
          final mainIndex = _mainCategories.indexWhere(
            (c) => c.id == category.id,
          );
          if (mainIndex != -1) {
            _mainCategories[mainIndex] = category;
          }
        }
        _updateSubCategories();
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error updating category: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== حذف فئة =====
  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _supabase.from('categories').delete().eq('id', categoryId);

      _categories.removeWhere((c) => c.id == categoryId);
      _mainCategories.removeWhere((c) => c.id == categoryId);
      _updateSubCategories();

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting category: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== اختيار فئة =====
  void selectCategory(CategoryModel category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // ===== الحصول على الفئات الفرعية =====
  List<CategoryModel> getSubCategories(String parentId) {
    return _subCategoriesMap[parentId] ?? [];
  }
}
