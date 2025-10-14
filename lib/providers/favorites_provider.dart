import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';

class FavoritesProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  final List<ProductModel> _favoriteProducts = [];
  final List<StoreModel> _favoriteStores = [];
  final Set<String> _favoriteProductIds = {};
  final Set<String> _favoriteStoreIds = {};
  bool _isLoading = false;
  String? _error;

  // Reference to auth provider for getting current user
  SupabaseProvider? _authProvider;

  // Getters
  List<ProductModel> get favoriteProducts => _favoriteProducts;
  List<StoreModel> get favoriteStores => _favoriteStores;
  List<ProductModel> get favorites => _favoriteProducts; // Legacy compatibility
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize with auth provider
  void setAuthProvider(SupabaseProvider authProvider) {
    _authProvider = authProvider;
  }

  /// Check if product is favorite
  bool isFavoriteProduct(String productId) {
    return _favoriteProductIds.contains(productId);
  }

  /// Check if store is favorite
  bool isFavoriteStore(String storeId) {
    return _favoriteStoreIds.contains(storeId);
  }

  /// Load user favorites from Supabase using official methods
  Future<void> loadUserFavorites(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get user favorites with product and store details
      final favoritesResponse = await _supabase
          .from('favorites')
          .select('''
            *,
            products(*),
            stores(*)
          ''')
          .eq('user_id', userId);

      _favoriteProducts.clear();
      _favoriteStores.clear();
      _favoriteProductIds.clear();
      _favoriteStoreIds.clear();

      for (var favorite in favoritesResponse) {
        // Handle product favorites
        if (favorite['product_id'] != null && favorite['products'] != null) {
          try {
            final product = ProductModel.fromMap(favorite['products']);
            _favoriteProducts.add(product);
            _favoriteProductIds.add(product.id);
          } catch (e) {
            debugPrint('خطأ في تحليل منتج مفضل: $e');
          }
        }

        // Handle store favorites
        if (favorite['store_id'] != null && favorite['stores'] != null) {
          try {
            final store = StoreModel.fromSupabaseMap(favorite['stores']);
            _favoriteStores.add(store);
            _favoriteStoreIds.add(store.id);
          } catch (e) {
            debugPrint('خطأ في تحليل متجر مفضل: $e');
          }
        }
      }

      _error = null;
    } catch (e) {
      _error = 'خطأ في تحميل المفضلة: $e';
      debugPrint('خطأ في loadUserFavorites: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Toggle product favorite status using official Supabase methods
  Future<bool> toggleFavoriteProduct(ProductModel product) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        _error = 'يرجى تسجيل الدخول أولاً';
        notifyListeners();
        return false;
      }

      if (_favoriteProductIds.contains(product.id)) {
        // Remove from favorites
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', product.id);

        _favoriteProducts.removeWhere((p) => p.id == product.id);
        _favoriteProductIds.remove(product.id);
      } else {
        // Add to favorites
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': product.id,
        });

        _favoriteProducts.add(product);
        _favoriteProductIds.add(product.id);
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطأ في تحديث المفضلة: $e';
      debugPrint('خطأ في toggleFavoriteProduct: $e');
      notifyListeners();
      return false;
    }
  }

  /// Toggle store favorite status using official Supabase methods
  Future<bool> toggleFavoriteStore(StoreModel store) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        _error = 'يرجى تسجيل الدخول أولاً';
        notifyListeners();
        return false;
      }

      if (_favoriteStoreIds.contains(store.id)) {
        // Remove from favorites
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('store_id', store.id);

        _favoriteStores.removeWhere((s) => s.id == store.id);
        _favoriteStoreIds.remove(store.id);
      } else {
        // Add to favorites
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'store_id': store.id,
        });

        _favoriteStores.add(store);
        _favoriteStoreIds.add(store.id);
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطأ في تحديث المفضلة: $e';
      debugPrint('خطأ في toggleFavoriteStore: $e');
      notifyListeners();
      return false;
    }
  }

  /// Remove product from favorites using official Supabase methods
  Future<bool> removeFromFavorites(String productId) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        _error = 'يرجى تسجيل الدخول أولاً';
        notifyListeners();
        return false;
      }

      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);

      _favoriteProducts.removeWhere((p) => p.id == productId);
      _favoriteProductIds.remove(productId);

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطأ في إزالة المنتج من المفضلة: $e';
      debugPrint('خطأ في removeFromFavorites: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clear all favorites
  void clear() {
    _favoriteProducts.clear();
    _favoriteStores.clear();
    _favoriteProductIds.clear();
    _favoriteStoreIds.clear();
    _error = null;
    notifyListeners();
  }

  /// Get current user ID (you'll need to implement this based on your auth system)
  String? _getCurrentUserId() {
    return _authProvider?.currentUser?.id;
  }

  // طرق إضافية للتوافق مع الكود القديم
  bool isFavorite(String productId) {
    return _favoriteProductIds.contains(productId);
  }

  Future<void> addToFavorites(ProductModel product) async {
    await toggleFavoriteProduct(product);
  }
}
