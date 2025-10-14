import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/core/logger.dart';

/// Store Provider مع دعم Supabase حسب الوثائق الرسمية
/// https://supabase.com/docs/reference/dart/installing
/// https://supabase.com/docs/reference/dart/select
/// https://supabase.com/docs/reference/dart/insert
class StoreProvider with ChangeNotifier {
  // استخدام Supabase Client مباشرة حسب الوثائق الرسمية
  final _supabase = Supabase.instance.client;

  List<StoreModel> _stores = [];
  List<StoreModel> _filteredStores = [];
  List<StoreModel> _featuredStores = [];
  List<StoreModel> _nearbyStores = [];
  final Map<String, List<StoreModel>> _storesByCategory = {};

  bool _isLoading = false;
  String? _error;
  StoreModel? _selectedStore;

  // ===== Getters =====
  List<StoreModel> get stores => _stores;
  List<StoreModel> get filteredStores => _filteredStores;
  List<StoreModel> get featuredStores => _featuredStores;
  List<StoreModel> get nearbyStores => _nearbyStores;
  bool get isLoading => _isLoading;
  String? get error => _error;
  StoreModel? get selectedStore => _selectedStore;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// جلب المتاجر من Supabase باستخدام الوثائق الرسمية
  /// https://supabase.com/docs/reference/dart/select
  Future<void> fetchStores({bool refresh = false}) async {
    if (!refresh && _stores.isNotEmpty) return;

    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info("جلب المتاجر من Supabase...");

      final response = await _supabase
          .from('stores')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _stores = (response as List)
          .map((data) => StoreModel.fromSupabaseMap(data))
          .toList();

      if (_stores.isEmpty) {
        AppLogger.info("لا توجد متاجر في قاعدة البيانات");
      }

      // تصنيف المتاجر
      _filteredStores = List.from(_stores);
      _featuredStores.clear();
      // Since isFeatured doesn't exist, we'll use active stores as featured for now
      _featuredStores.addAll(_stores.where((s) => s.isActive).toList());
      _updateStoresByCategory();

      AppLogger.info("تم جلب ${_stores.length} متجر بنجاح");
      _setError(null);
    } catch (e) {
      AppLogger.error("خطأ في جلب المتاجر", e);
      _stores = [];
      _filteredStores = [];
      _setError('فشل في تحميل المتاجر من قاعدة البيانات');
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث تصنيف المتاجر حسب الفئة
  void _updateStoresByCategory() {
    _storesByCategory.clear();
    // Since category doesn't exist, we'll categorize by name for now
    for (final store in _stores) {
      final category = _getCategoryFromName(store.name);
      if (!_storesByCategory.containsKey(category)) {
        _storesByCategory[category] = [];
      }
      _storesByCategory[category]!.add(store);
    }
  }

  /// Helper method to extract category from store name
  String _getCategoryFromName(String name) {
    if (name.contains('سوبرماركت')) return 'سوبرماركت';
    if (name.contains('مطعم') || name.contains('البيك')) return 'مطاعم';
    if (name.contains('صيدلية')) return 'صيدلية';
    if (name.contains('مقهى') || name.contains('ستارباكس')) return 'مقاهي';
    if (name.contains('إلكترونيات') || name.contains('إكسترا')) {
      return 'إلكترونيات';
    }
    if (name.contains('مخبز')) return 'مخابز';
    return 'عام';
  }

  /// تصفية المتاجر محلياً (للأداء الأفضل)
  void filterStores(String searchQuery, String category) {
    List<StoreModel> filtered = List.from(_stores);

    // تصفية حسب الفئة
    if (category != 'الكل') {
      filtered = filtered
          .where((store) => _getCategoryFromName(store.name) == category)
          .toList();
    }

    // تصفية حسب النص
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (store) =>
                store.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (store.description?.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (store.address.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                )),
          )
          .toList();
    }

    _filteredStores = filtered;
    notifyListeners();
  }

  /// ترتيب المتاجر
  void sortStores(String sortBy) {
    switch (sortBy) {
      case 'الأعلى تقييماً':
        // Since rating doesn't exist, sort by name as fallback
        _filteredStores.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'الأكثر طلباً':
        // Since ratingCount doesn't exist, sort by name as fallback
        _filteredStores.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'الأقل رسوم توصيل':
        // Since deliveryFee doesn't exist, sort by name as fallback
        _filteredStores.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'الأسرع توصيل':
        // Since deliveryTime doesn't exist, sort by name as fallback
        _filteredStores.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        // الافتراضي - حسب التاريخ
        _filteredStores.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    notifyListeners();
  }

  /// إعادة تعيين التصفية
  void resetFilters() {
    _filteredStores = List.from(_stores);
    notifyListeners();
  }

  /// Get store by ID
  StoreModel? getStoreById(String id) {
    try {
      return _stores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clear data
  void clear() {
    _stores = [];
    _filteredStores = [];
    _featuredStores = [];
    _nearbyStores = [];
    _storesByCategory.clear();
    _error = null;
    notifyListeners();
  }
}
