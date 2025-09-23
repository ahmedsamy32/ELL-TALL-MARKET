import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';

class ProductService {
  final _supabase = Supabase.instance.client;
  final int _pageSize = 10; // عدد المنتجات في كل صفحة

  // ===== جلب كل المنتجات مع دعم Pagination =====
  Future<List<ProductModel>> getProducts({int page = 1}) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      final response = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب المنتجات: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات حسب الفئة مع دعم Pagination =====
  Future<List<ProductModel>> getProductsByCategory(
    String categoryId, {
    int page = 1,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      final response = await _supabase
          .from('products')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب المنتجات حسب الفئة: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات حسب التاجر مع دعم Pagination =====
  Future<List<ProductModel>> getProductsByMerchant(
    String merchantId, {
    int page = 1,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      final response = await _supabase
          .from('products')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب المنتجات حسب التاجر: ${e.toString()}');
    }
  }

  // ===== جلب منتج حسب المعرف =====
  Future<ProductModel> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      return ProductModel.fromMap(response);
    } catch (e) {
      throw Exception('فشل جلب المنتج: ${e.toString()}');
    }
  }

  // ===== إضافة منتج جديد =====
  Future<void> addProduct(ProductModel product) async {
    try {
      await _supabase
          .from('products')
          .insert(product.toMap());
    } catch (e) {
      throw Exception('فشل إضافة المنتج: ${e.toString()}');
    }
  }

  // ===== تحديث منتج =====
  Future<void> updateProduct(ProductModel product) async {
    try {
      await _supabase
          .from('products')
          .update(product.toMap())
          .eq('id', product.id);
    } catch (e) {
      throw Exception('فشل تحديث المنتج: ${e.toString()}');
    }
  }

  // ===== حذف منتج =====
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId);
    } catch (e) {
      throw Exception('فشل حذف المنتج: ${e.toString()}');
    }
  }

  // ===== البحث عن منتجات =====
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .ilike('name', '%$query%')
          .order('created_at', ascending: false)
          .limit(_pageSize);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('فشل البحث عن المنتجات: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات المميزة =====
  Future<List<ProductModel>> getFeaturedProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_featured', true)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب المنتجات المميزة: ${e.toString()}');
    }
  }
}