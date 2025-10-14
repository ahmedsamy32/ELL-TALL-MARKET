import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';

/// ProductProvider - إدارة المنتجات مع Supabase
/// يتبع التوثيق الرسمي لـ Supabase
class ProductProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // الحالة الداخلية
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  List<ProductModel> _featuredProducts = [];
  bool _isLoading = false;
  String? _error;
  final bool _hasMore = true;

  // Getters
  List<ProductModel> get products =>
      _filteredProducts.isNotEmpty ? _filteredProducts : _products;
  List<ProductModel> get featuredProducts => _featuredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// جلب جميع المنتجات
  Future<void> fetchProducts() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('in_stock', true)
          .order('created_at', ascending: false);

      _products = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (kDebugMode) {
        print('✅ تم جلب ${_products.length} منتج بنجاح');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في جلب المنتجات: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// جلب منتجات متجر محدد
  Future<void> fetchProductsByStore(String storeId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _products = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
      _filteredProducts = [];

      if (kDebugMode) {
        print('🏪 منتجات المتجر "$storeId": ${_products.length} منتج');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في جلب منتجات المتجر: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// جلب منتجات تاجر محدد (deprecated - استخدم fetchProductsByStore)
  @Deprecated('Use fetchProductsByStore instead')
  Future<void> fetchProductsByMerchant(String merchantId) async {
    // يجب جلب المتاجر للتاجر أولاً ثم جلب المنتجات
    _setLoading(true);
    _setError(null);

    try {
      // جلب متاجر التاجر
      final storesResponse = await _supabase
          .from('stores')
          .select('id')
          .eq('merchant_id', merchantId);

      final storeIds = (storesResponse as List)
          .map((store) => store['id'] as String)
          .toList();

      if (storeIds.isEmpty) {
        _products = [];
        _filteredProducts = [];
        if (kDebugMode) {
          print('⚠️ لا توجد متاجر للتاجر "$merchantId"');
        }
        return;
      }

      // جلب منتجات جميع متاجر التاجر
      final response = await _supabase
          .from('products')
          .select()
          .inFilter('store_id', storeIds)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _products = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
      _filteredProducts = [];

      if (kDebugMode) {
        print('🏪 منتجات التاجر "$merchantId": ${_products.length} منتج');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في جلب منتجات التاجر: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// جلب المنتجات المميزة
  Future<void> fetchFeaturedProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('in_stock', true)
          .order('created_at', ascending: false)
          .limit(10);

      _featuredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      notifyListeners();

      if (kDebugMode) {
        print('✅ تم جلب ${_featuredProducts.length} منتج مميز');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في جلب المنتجات المميزة: $e');
      }
    }
  }

  /// البحث في المنتجات
  Future<void> searchProducts(String query) async {
    if (query.isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .ilike('name', '%$query%')
          .order('name');

      _filteredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (kDebugMode) {
        print('🔍 نتائج البحث لـ "$query": ${_filteredProducts.length} منتج');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في البحث: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// فلترة المنتجات حسب الفئة
  Future<void> filterByCategory(String categoryId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);

      _filteredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (kDebugMode) {
        print(
          '📂 منتجات الفئة "$categoryId": ${_filteredProducts.length} منتج',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في فلترة الفئة: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// فلترة المنتجات حسب المتجر
  Future<void> filterByStore(String storeId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      _filteredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (kDebugMode) {
        print('🏪 منتجات المتجر "$storeId": ${_filteredProducts.length} منتج');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في فلترة المتجر: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// فلترة المنتجات حسب النطاق السعري
  Future<void> filterByPriceRange(double minPrice, double maxPrice) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .gte('price', minPrice)
          .lte('price', maxPrice)
          .order('price');

      _filteredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (kDebugMode) {
        print(
          '💰 منتجات النطاق السعري $minPrice-$maxPrice: ${_filteredProducts.length} منتج',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في فلترة السعر: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// ترتيب المنتجات
  void sortProducts(String sortBy) {
    final productsToSort = _filteredProducts.isNotEmpty
        ? _filteredProducts
        : _products;

    switch (sortBy) {
      case 'name_asc':
        productsToSort.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        productsToSort.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'price_asc':
        productsToSort.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        productsToSort.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        // Since rating doesn't exist, sort by name as fallback
        productsToSort.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'newest':
        productsToSort.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    notifyListeners();

    if (kDebugMode) {
      print('🔄 تم ترتيب المنتجات حسب: $sortBy');
    }
  }

  /// إضافة منتج جديد
  Future<bool> addProduct(ProductModel product) async {
    try {
      await _supabase.from('products').insert(product.toJson());
      await fetchProducts(); // إعادة تحميل المنتجات

      if (kDebugMode) {
        print('✅ تم إضافة المنتج: ${product.name}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في إضافة المنتج: $e');
      }
      _setError(e.toString());
      return false;
    }
  }

  /// تحديث منتج
  Future<bool> updateProduct(ProductModel product) async {
    try {
      await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);

      // تحديث المنتج في القائمة المحلية
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      if (kDebugMode) {
        print('✅ تم تحديث المنتج: ${product.name}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في تحديث المنتج: $e');
      }
      _setError(e.toString());
      return false;
    }
  }

  /// حذف منتج
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);

      _products.removeWhere((p) => p.id == productId);
      _filteredProducts.removeWhere((p) => p.id == productId);
      _featuredProducts.removeWhere((p) => p.id == productId);

      notifyListeners();

      if (kDebugMode) {
        print('✅ تم حذف المنتج: $productId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في حذف المنتج: $e');
      }
      _setError(e.toString());
      return false;
    }
  }

  /// جلب منتج بالمعرف
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      return ProductModel.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ خطأ في جلب المنتج: $e');
      }
      return null;
    }
  }

  /// إزالة الفلاتر
  void clearFilters() {
    _filteredProducts = [];
    _setError(null);
    notifyListeners();

    if (kDebugMode) {
      print('🧹 تم مسح الفلاتر');
    }
  }

  /// إعادة تحميل البيانات
  Future<void> refresh() async {
    await fetchProducts();
    await fetchFeaturedProducts();
  }
}
