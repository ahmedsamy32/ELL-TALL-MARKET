import 'package:flutter/foundation.dart';
import '../core/logger.dart';
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
  int _storeProductCount = 0; // عداد خفيف للوحة التحكم
  RealtimeChannel? _productsChannel; // قناة التحديث اللحظي

  // Getters
  List<ProductModel> get products =>
      _filteredProducts.isNotEmpty ? _filteredProducts : _products;
  List<ProductModel> get featuredProducts => _featuredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  int get storeProductCount => _storeProductCount;

  /// ضبط قيمة العداد يدوياً (مثلاً من إحصائيات مخزنة مسبقاً)
  void preloadStoreProductCount(int count, {bool silent = false}) {
    final normalized = count < 0 ? 0 : count;
    if (_storeProductCount == normalized) return;
    _storeProductCount = normalized;
    if (!silent) notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// جلب عدد منتجات المتجر فقط (سريع للوحة التحكم)
  Future<void> fetchStoreProductCount(
    String storeId, {
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select('id')
          .eq('store_id', storeId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.count(CountOption.exact);
      final totalCount = response.count;
      preloadStoreProductCount(totalCount);
      AppLogger.info('📊 عدد منتجات المتجر "$storeId": $_storeProductCount');
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب عدد منتجات المتجر', e);
    }
  }

  /// الاشتراك في تحديثات المنتجات للمتجر (Realtime)
  Future<void> subscribeToStoreProducts(
    String storeId, {
    bool activeOnly = true,
  }) async {
    try {
      // إلغاء أي اشتراك سابق
      await _productsChannel?.unsubscribe();

      final channelName = 'products_store_$storeId';
      _productsChannel = _supabase.channel(channelName);

      // INSERT
      _productsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'products',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) {
          final newRow = payload.newRecord;
          final isActive = (newRow['is_active'] == true);
          if (!activeOnly || isActive) {
            _storeProductCount += 1;
          }
          // تحديث القائمة إن كانت محمّلة
          try {
            final product = ProductModel.fromMap(newRow);
            // أضف فقط إذا كانت نفس المتجر
            if (product.storeId == storeId) {
              _products.insert(0, product);
            }
          } catch (_) {}
          notifyListeners();
        },
      );

      // DELETE
      _productsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'products',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) {
          final oldRow = payload.oldRecord;
          final id = oldRow['id'] as String?;
          if (id != null) {
            // نقلل العداد دومًا لأن السجل اختفى
            if (_storeProductCount > 0) _storeProductCount -= 1;
            _products.removeWhere((p) => p.id == id);
            _filteredProducts.removeWhere((p) => p.id == id);
          }
          notifyListeners();
        },
      );

      // UPDATE
      _productsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'products',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) {
          final newRow = payload.newRecord;
          final oldRow = payload.oldRecord;
          final id = newRow['id'] as String?;
          if (id != null) {
            // عدّل العداد إذا تغيرت حالة is_active
            final wasActive = oldRow['is_active'] == true;
            final nowActive = newRow['is_active'] == true;
            if (activeOnly && wasActive != nowActive) {
              if (nowActive && !wasActive) {
                _storeProductCount += 1;
              } else if (!nowActive && wasActive) {
                if (_storeProductCount > 0) _storeProductCount -= 1;
              }
            }

            // حدّث العنصر في الذاكرة إن وُجد
            try {
              final updated = ProductModel.fromMap(newRow);
              final idx = _products.indexWhere((p) => p.id == id);
              if (idx != -1) {
                _products[idx] = updated;
              }
              final fIdx = _filteredProducts.indexWhere((p) => p.id == id);
              if (fIdx != -1) {
                _filteredProducts[fIdx] = updated;
              }
            } catch (_) {}
          }
          notifyListeners();
        },
      );

      _productsChannel!.subscribe();
      AppLogger.info('🔌 تم الاشتراك في Realtime لمنتجات المتجر: $storeId');
    } catch (e) {
      AppLogger.error('❌ خطأ في الاشتراك بالتحديث اللحظي', e);
    }
  }

  /// إلغاء الاشتراك في التحديثات
  Future<void> unsubscribeFromStoreProducts() async {
    try {
      await _productsChannel?.unsubscribe();
      _productsChannel = null;
    } catch (_) {}
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

      AppLogger.info('✅ تم جلب ${_products.length} منتج بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتجات', e);
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

      AppLogger.info('🏪 منتجات المتجر "$storeId": ${_products.length} منتج');

      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب منتجات المتجر', e);
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
      // جلب المنتجات مع معلومات المتجر باستخدام join
      final response = await _supabase
          .from('products')
          .select('*, store:stores!inner(merchant_id)')
          .eq('store.merchant_id', merchantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _products = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
      _filteredProducts = [];

      AppLogger.info(
        '🏪 منتجات التاجر "$merchantId": ${_products.length} منتج',
      );

      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب منتجات التاجر', e);
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

      AppLogger.info('✅ تم جلب ${_featuredProducts.length} منتج مميز');
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتجات المميزة', e);
    }
  }

  /// البحث في المنتجات
  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      // البحث في اسم المنتج أو الوصف
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('name');

      _filteredProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      AppLogger.info(
        '🔍 نتائج البحث لـ "$query": ${_filteredProducts.length} منتج',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث', e);
      _error = 'فشل البحث: ${e.toString()}';
      _filteredProducts = [];
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

      AppLogger.info(
        '📂 منتجات الفئة "$categoryId": ${_filteredProducts.length} منتج',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فلترة الفئة', e);
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

      AppLogger.info(
        '🏪 منتجات المتجر "$storeId": ${_filteredProducts.length} منتج',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فلترة المتجر', e);
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

      AppLogger.info(
        '💰 منتجات النطاق السعري $minPrice-$maxPrice: ${_filteredProducts.length} منتج',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فلترة السعر', e);
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

    AppLogger.info('🔄 تم ترتيب المنتجات حسب: $sortBy');
  }

  /// إضافة منتج جديد
  Future<bool> addProduct(ProductModel product) async {
    try {
      await _supabase.from('products').insert(product.toJson());
      await fetchProducts(); // إعادة تحميل المنتجات

      AppLogger.info('✅ تم إضافة المنتج: ${product.name}');

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إضافة المنتج', e);
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

      AppLogger.info('✅ تم تحديث المنتج: ${product.name}');

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث المنتج', e);
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

      AppLogger.info('✅ تم حذف المنتج: $productId');

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف المنتج', e);
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
      AppLogger.error('❌ خطأ في جلب المنتج', e);
      return null;
    }
  }

  /// إزالة الفلاتر
  void clearFilters() {
    _filteredProducts = [];
    _setError(null);
    notifyListeners();

    AppLogger.info('🧹 تم مسح الفلاتر');
  }

  /// مسح كل المنتجات (للاستخدام عند تغيير المستخدم)
  void clearProducts({bool resetCount = true}) {
    _products = [];
    _filteredProducts = [];
    _featuredProducts = [];
    _setError(null);
    if (resetCount) {
      preloadStoreProductCount(0, silent: true);
    }
    // أوقف الاشتراك في التحديثات
    unsubscribeFromStoreProducts();
    notifyListeners();

    AppLogger.info('🧹 تم مسح جميع المنتجات');
  }

  /// إعادة تحميل البيانات
  Future<void> refresh() async {
    await fetchProducts();
    await fetchFeaturedProducts();
  }
}
