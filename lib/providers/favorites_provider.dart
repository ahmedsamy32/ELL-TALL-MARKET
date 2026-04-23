import 'dart:async';

import 'package:flutter/material.dart';
import '../core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';

class FavoritesProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _disposed = false;

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

  /// Helper method to defer notifyListeners until after build phase
  void _notifyListeners() {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Load user favorites from Supabase using official methods
  Future<void> loadUserFavorites(String userId) async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    _notifyListeners();

    try {
      if (_disposed) return;
      Future<List<dynamic>> fetch() async {
        // Get user favorites with product and store details
        return await _supabase
            .from('favorites')
            .select('''
              *,
              products(*),
              stores(*)
            ''')
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 12));
      }

      final favoritesResponse = await _retryOnNetwork<List<dynamic>>(
        fetch,
        attempts: 3,
      );

      if (_disposed) return;

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
            AppLogger.error('خطأ في تحليل منتج مفضل', e);
          }
        }

        // Handle store favorites
        if (favorite['store_id'] != null && favorite['stores'] != null) {
          try {
            final store = StoreModel.fromSupabaseMap(favorite['stores']);
            _favoriteStores.add(store);
            _favoriteStoreIds.add(store.id);
          } catch (e) {
            AppLogger.error('خطأ في تحليل متجر مفضل', e);
          }
        }
      }

      if (_disposed) return;
      _error = null;
    } on PostgrestException catch (e) {
      // Server-side or query errors
      if (!_disposed) {
        _error = 'خطأ في تحميل المفضلة: ${e.message}';
      }
      AppLogger.error('خطأ في loadUserFavorites (Postgrest)', e);
    } on TimeoutException catch (e) {
      if (!_disposed) {
        _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
      }
      AppLogger.error('خطأ في loadUserFavorites (Timeout)', e);
    } catch (e) {
      if (!_disposed) {
        if (e.toString().contains('SocketException')) {
          _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
          AppLogger.error('خطأ في loadUserFavorites (Socket)', e);
        } else {
          // Includes ClientException with SocketException
          final msg = e.toString();
          if (msg.contains('Connection reset by peer') ||
              msg.contains('SocketException')) {
            _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
          } else {
            _error = 'خطأ في تحميل المفضلة: $e';
          }
          AppLogger.error('خطأ في loadUserFavorites', e);
        }
      }
    }

    if (!_disposed) {
      _isLoading = false;
      _notifyListeners();
    }
  }

  Future<T> _retryOnNetwork<T>(
    Future<T> Function() operation, {
    int attempts = 3,
  }) async {
    var delay = const Duration(milliseconds: 350);
    Object? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException') ||
            e.toString().contains('Connection reset by peer') ||
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('ClientException')) {
          lastError = e;
        } else {
          rethrow;
        }
      }

      if (attempt < attempts) {
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }

    throw lastError ?? Exception('Unknown network error');
  }

  /// Toggle product favorite status using official Supabase methods
  Future<bool> toggleFavoriteProduct(ProductModel product) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        if (!_disposed) {
          _error = 'يرجى تسجيل الدخول أولاً';
          _notifyListeners();
        }
        return false;
      }

      if (_favoriteProductIds.contains(product.id)) {
        // Remove from favorites
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', product.id);

        if (_disposed) return false;
        _favoriteProducts.removeWhere((p) => p.id == product.id);
        _favoriteProductIds.remove(product.id);
      } else {
        // Add to favorites
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': product.id,
        });

        if (_disposed) return false;
        _favoriteProducts.add(product);
        _favoriteProductIds.add(product.id);
      }

      if (!_disposed) {
        _error = null;
        _notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _error = 'خطأ في تحديث المفضلة: $e';
        _notifyListeners();
      }
      AppLogger.error('خطأ في toggleFavoriteProduct', e);
      return false;
    }
  }

  /// Toggle store favorite status using official Supabase methods
  Future<bool> toggleFavoriteStore(StoreModel store) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        if (!_disposed) {
          _error = 'يرجى تسجيل الدخول أولاً';
          _notifyListeners();
        }
        return false;
      }

      if (_favoriteStoreIds.contains(store.id)) {
        // Remove from favorites
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('store_id', store.id);

        if (_disposed) return false;
        _favoriteStores.removeWhere((s) => s.id == store.id);
        _favoriteStoreIds.remove(store.id);
      } else {
        // Add to favorites
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'store_id': store.id,
        });

        if (_disposed) return false;
        _favoriteStores.add(store);
        _favoriteStoreIds.add(store.id);
      }

      if (!_disposed) {
        _error = null;
        _notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _error = 'خطأ في تحديث المفضلة: $e';
        _notifyListeners();
      }
      AppLogger.error('خطأ في toggleFavoriteStore', e);
      return false;
    }
  }

  /// Remove product from favorites using official Supabase methods
  Future<bool> removeFromFavorites(String productId) async {
    if (_disposed) return false;

    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        if (!_disposed) {
          _error = 'يرجى تسجيل الدخول أولاً';
          _notifyListeners();
        }
        return false;
      }

      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);

      if (_disposed) return false;
      _favoriteProducts.removeWhere((p) => p.id == productId);
      _favoriteProductIds.remove(productId);

      if (!_disposed) {
        _error = null;
        _notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _error = 'خطأ في إزالة المنتج من المفضلة: $e';
        _notifyListeners();
      }
      AppLogger.error('خطأ في removeFromFavorites', e);
      return false;
    }
  }

  /// Clear all favorites
  void clear() {
    if (_disposed) return;

    _favoriteProducts.clear();
    _favoriteStores.clear();
    _favoriteProductIds.clear();
    _favoriteStoreIds.clear();
    _error = null;
    _notifyListeners();
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
