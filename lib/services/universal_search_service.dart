import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/core/logger.dart';

class SearchResult {
  final List<ProductModel> products;
  final List<StoreModel> stores;
  final List<CategoryModel> categories;

  SearchResult({
    required this.products,
    required this.stores,
    required this.categories,
  });

  bool get isEmpty => products.isEmpty && stores.isEmpty && categories.isEmpty;
  int get totalCount => products.length + stores.length + categories.length;
}

class UniversalSearchService {
  final _supabase = Supabase.instance.client;

  Future<SearchResult> search(String query) async {
    if (query.trim().isEmpty) {
      return SearchResult(products: [], stores: [], categories: []);
    }

    try {
      // البحث المتوازي في جميع الجداول
      final results = await Future.wait([
        _searchProducts(query),
        _searchStores(query),
        _searchCategories(query),
      ]);

      return SearchResult(
        products: results[0] as List<ProductModel>,
        stores: results[1] as List<StoreModel>,
        categories: results[2] as List<CategoryModel>,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث الشامل', e);
      rethrow;
    }
  }

  Future<List<ProductModel>> _searchProducts(String query) async {
    try {
      final searchPattern = '%$query%';
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .or('name.ilike.$searchPattern,description.ilike.$searchPattern')
          .order('name')
          .limit(20);

      AppLogger.debug('🔍 نتائج بحث المنتجات: ${(response as List).length}');
      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتجات', e);
      return [];
    }
  }

  Future<List<StoreModel>> _searchStores(String query) async {
    try {
      final searchPattern = '%$query%';
      final response = await _supabase
          .from('stores')
          .select()
          .eq('is_active', true)
          .or('name.ilike.$searchPattern,description.ilike.$searchPattern')
          .order('name')
          .limit(10);

      AppLogger.debug('🔍 نتائج بحث المتاجر: ${(response as List).length}');
      return (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المتاجر', e);
      return [];
    }
  }

  Future<List<CategoryModel>> _searchCategories(String query) async {
    try {
      final searchPattern = '%$query%';
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .or('name.ilike.$searchPattern,name_ar.ilike.$searchPattern')
          .order('name')
          .limit(10);

      AppLogger.debug('🔍 نتائج بحث الفئات: ${(response as List).length}');
      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن الفئات', e);
      return [];
    }
  }
}
