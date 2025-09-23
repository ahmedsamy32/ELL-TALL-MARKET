import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/category_model.dart';

class CategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  // ===== جلب كل الفئات مع دعم Pagination =====
  Future<List<CategoryModel>> getCategories({int page = 1}) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('order', ascending: true)
          .order('name', ascending: true)
          .range((page - 1) * _pageSize, page * _pageSize - 1);

      return (response as List).map((data) => CategoryModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('فشل جلب الفئات: ${e.toString()}');
    }
  }

  // ===== جلب الفئات المميزة =====
  Future<List<CategoryModel>> getFeaturedCategories({int page = 1}) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_featured', true)
          .order('order', ascending: true)
          .range((page - 1) * _pageSize, page * _pageSize - 1);

      return (response as List).map((data) => CategoryModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('فشل جلب الفئات المميزة: ${e.toString()}');
    }
  }

  // ===== إضافة فئة جديدة =====
  Future<CategoryModel> addCategory(CategoryModel category) async {
    try {
      final existing = await _getCategoryByName(category.name);
      if (existing != null) {
        throw Exception('هناك فئة بنفس الاسم موجودة مسبقاً');
      }

      final response = await _supabase
          .from('categories')
          .insert(category.toMap())
          .select()
          .single();

      return CategoryModel.fromMap(response);
    } catch (e) {
      throw Exception('فشل إضافة الفئة: ${e.toString()}');
    }
  }

  // ===== تحديث فئة =====
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final response = await _supabase
          .from('categories')
          .update(category.toMap())
          .eq('id', category.id)
          .select()
          .single();

      return CategoryModel.fromMap(response);
    } catch (e) {
      throw Exception('فشل تحديث الفئة: ${e.toString()}');
    }
  }

  // ===== حذف فئة =====
  Future<void> deleteCategory(String categoryId) async {
    try {
      final productsCount = await _getProductsCountByCategory(categoryId);
      if (productsCount > 0) {
        throw Exception('لا يمكن حذف الفئة لأنها تحتوي على منتجات');
      }

      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId);
    } catch (e) {
      throw Exception('فشل حذف الفئة: ${e.toString()}');
    }
  }

  // ===== تحديث ترتيب الفئات =====
  Future<void> updateCategoryOrder(String categoryId, int newOrder) async {
    try {
      await _supabase
          .from('categories')
          .update({'order': newOrder})
          .eq('id', categoryId);
    } catch (e) {
      throw Exception('فشل تحديث ترتيب الفئة: ${e.toString()}');
    }
  }

  // ===== تحديث حالة التميز =====
  Future<void> toggleFeatured(String categoryId, bool isFeatured) async {
    try {
      await _supabase
          .from('categories')
          .update({'is_featured': isFeatured})
          .eq('id', categoryId);
    } catch (e) {
      throw Exception('فشل تحديث حالة التميز: ${e.toString()}');
    }
  }

  // ===== رفع صورة فئة =====
  Future<String> uploadCategoryImage({
    required File imageFile,
    required String categoryId,
  }) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final filePath = 'categories/$categoryId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('category-images').upload(filePath, imageFile);
      final imageUrl = _supabase.storage.from('category-images').getPublicUrl(filePath);

      await _supabase
          .from('categories')
          .update({'image_url': imageUrl})
          .eq('id', categoryId);

      return imageUrl;
    } catch (e) {
      throw Exception('فشل رفع صورة الفئة: ${e.toString()}');
    }
  }

  // ===== دوال مساعدة خاصة =====
  Future<CategoryModel?> _getCategoryByName(String name) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .ilike('name', name)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return CategoryModel.fromMap(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> _getProductsCountByCategory(String categoryId) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('category_id', categoryId);

      return (response as List).length;
    } catch (e) {
      throw Exception('فشل جلب عدد المنتجات: ${e.toString()}');
    }
  }

  // ===== جلب الفئات النشطة فقط =====
  Future<List<CategoryModel>> getActiveCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('order', ascending: true);

      return (response as List).map((data) => CategoryModel.fromMap(data)).toList();
    } catch (e) {
      throw Exception('فشل جلب الفئات النشطة: ${e.toString()}');
    }
  }
}