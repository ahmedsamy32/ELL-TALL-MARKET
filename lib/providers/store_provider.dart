import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final Map<String, List<Map<String, dynamic>>> _storeSectionsCache = {};
  final Map<String, StoreDetailBundle> _storeDetailCache = {};
  final Map<String, String?> _storeCoverCache = {};
  StreamSubscription<List<Map<String, dynamic>>>? _storeStreamSub;
  Timer? _realtimeRetryTimer;
  bool _realtimeTemporarilyDisabled = false;
  static const Duration _realtimeRetryDelay = Duration(seconds: 45);

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

  @override
  void dispose() {
    _storeStreamSub?.cancel();
    _storeStreamSub = null;
    _realtimeRetryTimer?.cancel();
    _realtimeRetryTimer = null;
    super.dispose();
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
      final category = _resolveStoreCategoryId(store);
      if (!_storesByCategory.containsKey(category)) {
        _storesByCategory[category] = [];
      }
      _storesByCategory[category]!.add(store);
    }
  }

  /// بناء قائمة الفئات المتاحة لاستخدامها في واجهة المستخدم
  Map<String, String> getStoreCategories() {
    final categories = <String, String>{'all': 'الكل'};

    for (final store in _stores) {
      final categoryId = _resolveStoreCategoryId(store);
      if (categoryId.isEmpty) continue;
      categories[categoryId] = _formatCategoryLabel(categoryId);
    }

    return categories;
  }

  void ensureRealtimeSubscription() {
    if (_storeStreamSub != null) return;
    if (_realtimeTemporarilyDisabled) {
      AppLogger.warning(
        '⏸️ تم تعطيل بث المتاجر مؤقتاً بعد فشل الاتصال، سيتم إعادة المحاولة لاحقاً',
      );
      return;
    }

    AppLogger.info('🔄 تفعيل التحديث الفوري لقائمة المتاجر');
    _storeStreamSub = _supabase
        .from('stores')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .listen(
          (payload) {
            try {
              final updatedStores = payload
                  .map((row) => StoreModel.fromSupabaseMap(row))
                  .toList();
              _applyRealtimeStores(updatedStores);
            } catch (e) {
              AppLogger.error('خطأ في معالجة بث المتاجر', e);
            }
          },
          onError: (error) {
            AppLogger.error('بث المتاجر الفوري توقف بسبب خطأ', error);
            _storeStreamSub?.cancel();
            _storeStreamSub = null;
            // تحديث القائمة مرة واحدة بحيث يبقى المستخدم يرى أحدث البيانات
            unawaited(fetchStores(refresh: true));
            _handleRealtimeError(error);
          },
        );
  }

  void _handleRealtimeError(dynamic error) {
    final isHandshakeFailure =
        error is WebSocketChannelException || error is HandshakeException;

    if (!isHandshakeFailure) {
      return;
    }

    if (_realtimeTemporarilyDisabled) {
      AppLogger.warning(
        '⚠️ محاولة أخرى للاتصال بالبث الفوري فشلت، ما زلنا في فترة التهدئة',
      );
      return;
    }

    _realtimeTemporarilyDisabled = true;
    _realtimeRetryTimer?.cancel();

    AppLogger.warning(
      '⏸️ تم تعطيل البث الفوري مؤقتاً بسبب فشل المصافحة (Handshake). سنعيد المحاولة خلال ${_realtimeRetryDelay.inSeconds} ثانية.',
      error,
    );

    _realtimeRetryTimer = Timer(_realtimeRetryDelay, () {
      _realtimeTemporarilyDisabled = false;
      AppLogger.info('🔁 إعادة محاولة تفعيل البث الفوري للمتاجر');
      ensureRealtimeSubscription();
    });
  }

  void _applyRealtimeStores(List<StoreModel> stores) {
    _stores = stores;
    _filteredStores = List.from(_stores);
    _featuredStores = _stores.where((s) => s.isActive).toList();
    _updateStoresByCategory();
    notifyListeners();
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

  String _resolveStoreCategoryId(StoreModel store) {
    final category = store.category?.trim();
    if (category != null && category.isNotEmpty) {
      return category;
    }
    return _getCategoryFromName(store.name);
  }

  String _formatCategoryLabel(String raw) {
    if (raw.isEmpty) return 'عام';
    return raw;
  }

  /// واجهة خارجية لاستخدامها من الشاشات التي تعتمد على أسماء الفئات
  String getCategoryName(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      return 'غير محدد';
    }
    final categories = getStoreCategories();
    if (categories.containsKey(categoryId)) {
      return categories[categoryId]!;
    }
    // fallback if UI passes label directly
    final match = categories.entries
        .firstWhere(
          (entry) => entry.value == categoryId,
          orElse: () => const MapEntry('', 'غير محدد'),
        )
        .value;
    return match;
  }

  /// تصفية المتاجر محلياً (للأداء الأفضل)
  void filterStores(String searchQuery, String category) {
    List<StoreModel> filtered = List.from(_stores);

    // تصفية حسب الفئة
    final shouldFilterCategory =
        category.isNotEmpty && category != 'all' && category != 'الكل';

    if (shouldFilterCategory) {
      filtered = filtered
          .where((store) => _resolveStoreCategoryId(store) == category)
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
    _storeSectionsCache.clear();
    _storeDetailCache.clear();
    _storeCoverCache.clear();
    _error = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchStoreSections(
    String storeId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _storeSectionsCache.containsKey(storeId)) {
      return _storeSectionsCache[storeId]!;
    }

    try {
      final response = await _supabase
          .from('store_sections')
          .select('id, name, description, display_order, is_active')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('display_order')
          .timeout(const Duration(seconds: 8));

      final sections = List<Map<String, dynamic>>.from(response);
      _storeSectionsCache[storeId] = sections;
      return sections;
    } catch (e) {
      AppLogger.error('خطأ في جلب تصنيفات المتجر $storeId', e);
      return _storeSectionsCache[storeId] ?? [];
    }
  }

  Future<StoreDetailBundle> fetchStoreDetailBundle(
    String storeId, {
    required String merchantId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _storeDetailCache.containsKey(storeId)) {
      return _storeDetailCache[storeId]!;
    }

    try {
      final orderWindowsFuture = _supabase
          .from('store_order_windows')
          .select('day_of_week, open_time, close_time, is_active')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('day_of_week')
          .timeout(const Duration(seconds: 8));

      final branchesFuture = _supabase
          .from('store_branches')
          .select('id, name, address, phone, is_active')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('name')
          .timeout(const Duration(seconds: 8));

      final paymentFuture = _supabase
          .from('store_payment_methods')
          .select('method')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .timeout(const Duration(seconds: 8));

      final merchantFuture = _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', merchantId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      final results = await Future.wait([
        orderWindowsFuture,
        branchesFuture,
        paymentFuture,
        merchantFuture,
      ]);

      final bundle = StoreDetailBundle(
        orderWindows: List<Map<String, dynamic>>.from(results[0] as List),
        branches: List<Map<String, dynamic>>.from(results[1] as List),
        paymentMethods: _mapPaymentMethods(results[2] as List),
        merchantName:
            (results[3] as Map<String, dynamic>?)?['full_name'] as String? ??
            'غير متوفر',
      );

      _storeDetailCache[storeId] = bundle;
      return bundle;
    } catch (e) {
      AppLogger.error('خطأ في جلب تفاصيل المتجر $storeId', e);
      return _storeDetailCache[storeId] ?? const StoreDetailBundle.empty();
    }
  }

  Future<String?> fetchStoreCoverUrl(
    StoreModel store, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _storeCoverCache.containsKey(store.id)) {
      return _storeCoverCache[store.id];
    }

    final storage = _supabase.storage.from('stores');
    final basePath = '${store.merchantId}/stores/${store.id}';
    const candidates = ['cover.jpg', 'cover.png', 'cover.jpeg'];

    for (final candidate in candidates) {
      final path = '$basePath/$candidate';
      try {
        final signed = await storage.createSignedUrl(path, 60);
        if (signed.isNotEmpty) {
          final publicUrl = storage.getPublicUrl(path);
          _storeCoverCache[store.id] = publicUrl;
          return publicUrl;
        }
      } catch (_) {
        // تجاهل الأخطاء لكل مسار واستمر في التحقق من الامتدادات الأخرى
      }
    }

    _storeCoverCache[store.id] = null;
    return null;
  }

  List<String> _mapPaymentMethods(List<dynamic> response) {
    if (response.isEmpty) return const ['نقدي'];

    return response.map((item) {
      final method = item['method'] as String? ?? 'cash';
      switch (method) {
        case 'cash':
          return 'نقدي';
        case 'card':
          return 'بطاقة ائتمان';
        case 'wallet':
          return 'محفظة إلكترونية';
        default:
          return method;
      }
    }).toList();
  }
}

class StoreDetailBundle {
  final List<Map<String, dynamic>> orderWindows;
  final List<Map<String, dynamic>> branches;
  final List<String> paymentMethods;
  final String merchantName;

  const StoreDetailBundle({
    required this.orderWindows,
    required this.branches,
    required this.paymentMethods,
    required this.merchantName,
  });

  const StoreDetailBundle.empty()
    : orderWindows = const [],
      branches = const [],
      paymentMethods = const ['نقدي'],
      merchantName = 'غير متوفر';
}
