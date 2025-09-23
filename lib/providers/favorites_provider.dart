import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';

class FavoritesProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<ProductModel> _favorites = [];
  bool _isLoading = false;
  String? _error;

  List<ProductModel> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ===== جلب المفضلة =====
  Future<void> fetchFavorites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _setLoading(true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('favorite_products')
          .eq('id', userId)
          .single();

      final favoriteIds = List<String>.from(response['favorite_products'] ?? []);
      if (favoriteIds.isEmpty) {
        _favorites = [];
        return;
      }

      final products = await _supabase
          .from('products')
          .select()
          .inFilter('id', favoriteIds);

      _favorites = (products as List)
          .map((data) => ProductModel.fromJson(data))
          .toList();

    } catch (e) {
      if (kDebugMode) print('❌ Error fetching favorites: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== إضافة إلى المفضلة =====
  Future<void> addToFavorites(ProductModel product) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // جلب القائمة الحالية
      final response = await _supabase
          .from('profiles')
          .select('favorite_products')
          .eq('id', userId)
          .single();

      List<String> favoriteIds = List<String>.from(response['favorite_products'] ?? []);

      // إضافة المنتج إذا لم يكن موجوداً
      if (!favoriteIds.contains(product.id)) {
        favoriteIds.add(product.id);

        await _supabase
            .from('profiles')
            .update({'favorite_products': favoriteIds})
            .eq('id', userId);

        _favorites.add(product);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error adding to favorites: $e');
      _setError(e.toString());
    }
  }

  // ===== حذف من المفضلة =====
  Future<void> removeFromFavorites(String productId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // جلب القائمة الحالية
      final response = await _supabase
          .from('profiles')
          .select('favorite_products')
          .eq('id', userId)
          .single();

      List<String> favoriteIds = List<String>.from(response['favorite_products'] ?? []);

      // حذف المنتج إذا كان موجوداً
      if (favoriteIds.contains(productId)) {
        favoriteIds.remove(productId);

        await _supabase
            .from('profiles')
            .update({'favorite_products': favoriteIds})
            .eq('id', userId);

        _favorites.removeWhere((product) => product.id == productId);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error removing from favorites: $e');
      _setError(e.toString());
    }
  }

  // ===== التحقق من وجود منتج في المفضلة =====
  bool isFavorite(String productId) {
    return _favorites.any((product) => product.id == productId);
  }

  // ===== تبديل حالة المفضلة =====
  Future<void> toggleFavorite(ProductModel product) async {
    if (isFavorite(product.id)) {
      await removeFromFavorites(product.id);
    } else {
      await addToFavorites(product);
    }
  }
}
