import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/core/api_client.dart';

class ProductProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final _supabase = Supabase.instance.client;

  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  String? _currentCategoryId;
  String? _currentMerchantId;
  final int _limit = 20;

  List<ProductModel> get products =>
      _filteredProducts.isNotEmpty ? _filteredProducts : _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoading && _page > 1;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ===== جلب كل المنتجات =====
  Future<void> fetchProducts() async {
    _setLoading(true);
    _error = null;
    _page = 1;
    _hasMore = true;
    _currentCategoryId = null;
    _currentMerchantId = null;

    try {
      final products = await _apiClient.getProducts(limit: _limit, offset: 0);

      _products = products.map((p) => ProductModel.fromJson(p)).toList();

      // إذا لم توجد منتجات، إنشاء منتجات تجريبية
      if (_products.isEmpty) {
        _products = _createSampleProducts();
      }

      _filteredProducts = [];
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching products: $e');
      // في حالة فشل الـ API، إنشاء منتجات تجريبية
      _products = _createSampleProducts();
      _setError('تم تحميل البيانات التجريبية - ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // ===== إنشاء منتجات تجريبية =====
  List<ProductModel> _createSampleProducts() {
    return [
      // منتجات سوبر ماركت
      ProductModel(
        id: '1',
        name: 'أرز بسمتي هندي',
        description: 'أرز بسمتي عالي الجودة من الهند',
        price: 25.50,
        salePrice: 22.99,
        categoryId: '1',
        storeId: 'store1',
        images: ['https://via.placeholder.com/300/4CAF50/white?text=أرز+بسمتي'],
        stockQuantity: 100,
        unit: 'كيس 5 كيلو',
        rating: 4.5,
        ratingCount: 120,
        createdAt: DateTime.now(),
        categoryName: 'سوبر ماركت',
        storeName: 'سوبر ماركت الخير',
      ),
      ProductModel(
        id: '2',
        name: 'زيت زيتون بكر',
        description: 'زيت زيتون بكر ممتاز من فلسطين',
        price: 45.00,
        categoryId: '1',
        storeId: 'store1',
        images: ['https://via.placeholder.com/300/4CAF50/white?text=زيت+زيتون'],
        stockQuantity: 50,
        unit: 'زجاجة 750 مل',
        rating: 4.8,
        ratingCount: 85,
        createdAt: DateTime.now(),
        categoryName: 'سوبر ماركت',
        storeName: 'سوبر ماركت الخير',
      ),

      // منتجات صيدلية
      ProductModel(
        id: '3',
        name: 'فيتامين د3',
        description: 'مكمل غذائي فيتامين د3 1000 وحدة',
        price: 35.00,
        salePrice: 29.99,
        categoryId: '2',
        storeId: 'pharmacy1',
        images: [
          'https://via.placeholder.com/300/2196F3/white?text=فيتامين+د3',
        ],
        stockQuantity: 30,
        unit: 'علبة 30 قرص',
        rating: 4.3,
        ratingCount: 65,
        createdAt: DateTime.now(),
        categoryName: 'صيدلية',
        storeName: 'صيدلية الشفاء',
      ),
      ProductModel(
        id: '4',
        name: 'شامبو طبي',
        description: 'شامبو طبي لعلاج قشرة الشعر',
        price: 28.50,
        categoryId: '2',
        storeId: 'pharmacy1',
        images: ['https://via.placeholder.com/300/2196F3/white?text=شامبو+طبي'],
        stockQuantity: 25,
        unit: 'زجاجة 200 مل',
        rating: 4.1,
        ratingCount: 42,
        createdAt: DateTime.now(),
        categoryName: 'صيدلية',
        storeName: 'صيدلية الشفاء',
      ),

      // منتجات مطاعم
      ProductModel(
        id: '5',
        name: 'شاورما دجاج',
        description: 'شاورما دجاج طازجة مع الخضار والصلصة',
        price: 18.00,
        categoryId: '3',
        storeId: 'restaurant1',
        images: [
          'https://via.placeholder.com/300/FF9800/white?text=شاورما+دجاج',
        ],
        stockQuantity: 20,
        unit: 'سندويش كبير',
        rating: 4.6,
        ratingCount: 200,
        createdAt: DateTime.now(),
        categoryName: 'مطاعم',
        storeName: 'مطعم الأصالة',
      ),
      ProductModel(
        id: '6',
        name: 'برجر لحم',
        description: 'برجر لحم بقري مشوي مع البطاطس',
        price: 22.00,
        salePrice: 19.99,
        categoryId: '3',
        storeId: 'restaurant1',
        images: ['https://via.placeholder.com/300/FF9800/white?text=برجر+لحم'],
        stockQuantity: 15,
        unit: 'وجبة كاملة',
        rating: 4.4,
        ratingCount: 150,
        createdAt: DateTime.now(),
        categoryName: 'مطاعم',
        storeName: 'مطعم الأصالة',
      ),

      // منتجات خضروات وفواكه
      ProductModel(
        id: '7',
        name: 'تفاح أحمر',
        description: 'تفاح أحمر طازج ومقرمش',
        price: 12.00,
        categoryId: '6',
        storeId: 'vegetables1',
        images: ['https://via.placeholder.com/300/8BC34A/white?text=تفاح+أحمر'],
        stockQuantity: 80,
        unit: 'كيلو',
        rating: 4.7,
        ratingCount: 95,
        createdAt: DateTime.now(),
        categoryName: 'خضروات وفواكه',
        storeName: 'خضروات وفواكه الطازجة',
      ),
      ProductModel(
        id: '8',
        name: 'طماطم طازجة',
        description: 'طماطم طازجة حمراء للسلطات والطبخ',
        price: 8.50,
        categoryId: '6',
        storeId: 'vegetables1',
        images: ['https://via.placeholder.com/300/8BC34A/white?text=طماطم'],
        stockQuantity: 120,
        unit: 'كيلو',
        rating: 4.2,
        ratingCount: 78,
        createdAt: DateTime.now(),
        categoryName: 'خضروات وفواكه',
        storeName: 'خضروات وفواكه الطازجة',
      ),
    ];
  }

  // ===== جلب المزيد من المنتجات =====
  Future<void> fetchMoreProducts() async {
    if (!_hasMore || _isLoading) return;

    _setLoading(true);

    try {
      final products = await _apiClient.getProducts(
        category: _currentCategoryId,
        storeId: _currentMerchantId,
        limit: _limit,
        offset: _page * _limit,
      );

      final newProducts = products
          .map((p) => ProductModel.fromJson(p))
          .toList();

      if (newProducts.isEmpty) {
        _hasMore = false;
      } else {
        _products.addAll(newProducts);
        _page++;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching more products: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب منتجات حسب الفئة =====
  Future<void> fetchProductsByCategory(String categoryId) async {
    _setLoading(true);
    _error = null;
    _page = 1;
    _hasMore = true;
    _currentCategoryId = categoryId;
    _currentMerchantId = null;

    try {
      final products = await _apiClient.getProducts(
        category: categoryId,
        limit: _limit,
        offset: 0,
      );

      _products = products.map((p) => ProductModel.fromJson(p)).toList();

      // إذا لم توجد منتجات، إنشاء منتجات تجريبية مفلترة
      if (_products.isEmpty) {
        final allSampleProducts = _createSampleProducts();
        _products = allSampleProducts
            .where((p) => p.categoryId == categoryId)
            .toList();
      }

      _filteredProducts = [];
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching products by category: $e');
      // في حالة فشل الـ API، إنشاء منتجات تجريبية مفلترة
      final allSampleProducts = _createSampleProducts();
      _products = allSampleProducts
          .where((p) => p.categoryId == categoryId)
          .toList();
      _setError('تم تحميل البيانات التجريبية - ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحميل المزيد من منتجات الفئة =====
  Future<void> loadMoreProductsByCategory() async {
    if (!_hasMore || _isLoading || _currentCategoryId == null) return;

    _setLoading(true);

    try {
      final products = await _apiClient.getProducts(
        category: _currentCategoryId,
        limit: _limit,
        offset: _page * _limit,
      );

      final newProducts = products
          .map((p) => ProductModel.fromJson(p))
          .toList();

      if (newProducts.isEmpty) {
        _hasMore = false;
      } else {
        _products.addAll(newProducts);
        _page++;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading more products by category: $e');
      _hasMore = false;
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحميل المزيد من المنتجات =====
  Future<void> loadMoreProducts() async {
    await fetchMoreProducts();
  }

  // ===== تحديث منتجات الفئة =====
  Future<void> refreshProductsByCategory(String categoryId) async {
    await fetchProductsByCategory(categoryId);
  }

  // ===== تحديث كل المنتجات =====
  Future<void> refreshProducts() async {
    await fetchProducts();
  }

  // ===== جلب منتجات حسب التاجر =====
  Future<void> fetchProductsByMerchant(String merchantId) async {
    _setLoading(true);
    _error = null;
    _page = 1;
    _hasMore = true;
    _currentCategoryId = null;
    _currentMerchantId = merchantId;

    try {
      final products = await _apiClient.getProducts(
        storeId: merchantId,
        limit: _limit,
        offset: 0,
      );

      _products = products.map((p) => ProductModel.fromJson(p)).toList();
      _filteredProducts = [];
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching products by merchant: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== البحث في المنتجات =====
  Future<void> searchProducts(String query, {String? categoryId}) async {
    if (query.isEmpty) {
      await fetchProducts();
      return;
    }

    _setLoading(true);
    _error = null;
    _page = 1;
    _hasMore = false;

    try {
      final products = await _apiClient.getProducts(
        search: query,
        category: categoryId,
        limit: 50,
      );

      _products = products.map((p) => ProductModel.fromJson(p)).toList();
      _filteredProducts = [];
    } catch (e) {
      if (kDebugMode) print('❌ Error searching products: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== إضافة منتج =====
  Future<bool> addProduct(ProductModel product) async {
    try {
      await _supabase.from('products').insert(product.toJson());
      await fetchProducts();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error adding product: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== تحديث منتج =====
  Future<bool> updateProduct(ProductModel product) async {
    try {
      await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error updating product: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== حذف منتج =====
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
      _products.removeWhere((p) => p.id == productId);
      _filteredProducts.removeWhere((p) => p.id == productId);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting product: $e');
      _setError(e.toString());
      return false;
    }
  }

  // ===== تصفية المنتجات =====
  void filterProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    _filteredProducts = _products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
          product.description.toLowerCase().contains(lowercaseQuery) ||
          (product.categoryName?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          (product.storeName?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();

    notifyListeners();
  }
}
