import 'dart:async';
// Removed dart:io for Web compatibility
import 'package:flutter/material.dart';
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
  Map<String, String> _categoryMapping = {};
  StreamSubscription<List<Map<String, dynamic>>>? _storeStreamSub;
  Timer? _realtimeRetryTimer;
  bool _realtimeTemporarilyDisabled = false;
  static const Duration _realtimeRetryDelay = Duration(seconds: 45);

  /// عند تفعيل هذا الوضع، تعتمد القوائم على المتاجر القريبة فقط.
  /// هذا يمنع ظهور "كل المتاجر" ثم اختفائها بعد تطبيق الموقع.
  bool _nearbyModeEnabled = false;

  bool _isLoading = false;
  String? _error;
  StoreModel? _selectedStore;

  bool _hasDisplayableAddress(StoreModel store) {
    return store.address.trim().isNotEmpty;
  }

  List<StoreModel> _filterStoresWithAddress(Iterable<StoreModel> stores) {
    return stores.where(_hasDisplayableAddress).toList(growable: false);
  }

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
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء لتجنب الأخطاء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setError(String? value) {
    _error = value;
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء لتجنب الأخطاء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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

    // العودة للوضع العام (غير مرتبط بالموقع)
    _nearbyModeEnabled = false;

    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info("جلب المتاجر من Supabase...");

      final response = await _supabase
          .from('stores')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final fetchedStores = (response as List)
          .map((data) => StoreModel.fromSupabaseMap(data))
          .toList();

      // لا نعرض متاجر بدون عنوان (العنوان مشتق من الحقول التفصيلية أيضاً).
      _stores = _filterStoresWithAddress(fetchedStores);

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

  /// جلب المتاجر القريبة من موقع العميل باستخدام PostGIS
  /// يُستخدم في الصفحة الرئيسية والمتاجر المميزة
  Future<void> fetchNearbyStores({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 15,
    String? categoryFilter,
  }) async {
    // تفعيل وضع المتاجر القريبة حتى لو كانت النتيجة فارغة.
    _nearbyModeEnabled = true;
    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info(
        "جلب المتاجر القريبة من الموقع ($latitude, $longitude)...",
      );

      final response = await _supabase.rpc(
        'get_nearby_stores',
        params: {
          'customer_lat': latitude,
          'customer_lng': longitude,
          'max_distance_km': maxDistanceKm,
          'category_filter': categoryFilter,
        },
      );

      final List<Map<String, dynamic>> nearbyData =
          List<Map<String, dynamic>>.from(response ?? []);

      if (nearbyData.isEmpty) {
        _nearbyStores = [];
        _featuredStores = [];
        _filteredStores = [];
        _stores = [];
        _updateStoresByCategory();
        AppLogger.info('لا توجد متاجر قريبة ضمن النطاق');
        notifyListeners();
        return;
      }

      // جلب بيانات المتاجر الكاملة من جدول stores حتى نحصل على cover_url والعنوان
      // (RPC get_nearby_stores لا يُرجع هذه الحقول).
      final nearbyIds = nearbyData
          .map((row) => (row['id'] ?? row['store_id'])?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final fullRows = await _supabase
          .from('stores')
          .select(
            'id, merchant_id, name, description, phone, governorate, city, area, street, landmark, address, '
            'latitude, longitude, delivery_time, is_open, delivery_fee, min_order, delivery_mode, delivery_radius_km, '
            'rating, review_count, category, opening_hours, image_url, cover_url, is_active, created_at, updated_at',
          )
          .inFilter('id', nearbyIds);

      final fullById = <String, StoreModel>{
        for (final row in (fullRows as List))
          if ((row as Map)['id'] != null)
            (row['id'].toString()): StoreModel.fromSupabaseMap(
              Map<String, dynamic>.from(row),
            ),
      };

      // دمج بيانات RPC (المسافة/الوقت المتوقع/… إلخ) مع بيانات المتجر الكاملة.
      final mergedStores = nearbyData.map((data) {
        final id = (data['id'] ?? data['store_id'])?.toString() ?? '';
        final base = fullById[id];

        if (base == null) {
          // احتياطي: لو لم نستطع جلب صف المتجر من الجدول لأي سبب.
          return StoreModel(
            id: id,
            merchantId: '',
            name: data['name'] as String? ?? '',
            description: data['description'] as String?,
            imageUrl: data['image_url'] as String?,
            coverUrl: data['cover_url'] as String?,
            address: (data['address'] as String?)?.trim() ?? '',
            phone: null,
            isOpen: data['is_open'] as bool? ?? true,
            isActive: true,
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0.0,
            minOrder: (data['min_order_amount'] as num?)?.toDouble() ?? 0.0,
            deliveryTime: data['estimated_delivery_time'] as int? ?? 30,
            latitude: (data['latitude'] as num?)?.toDouble(),
            longitude: (data['longitude'] as num?)?.toDouble(),
            createdAt: DateTime.now(),
            deliveryMode: 'store',
            deliveryRadiusKm:
                (data['delivery_radius_km'] as num?)?.toDouble() ?? 7.0,
          );
        }

        return base.copyWith(
          // RPC fields (prefer these over base when provided)
          isOpen: data['is_open'] as bool?,
          rating: (data['rating'] as num?)?.toDouble(),
          deliveryFee: (data['delivery_fee'] as num?)?.toDouble(),
          minOrder: (data['min_order_amount'] as num?)?.toDouble(),
          deliveryTime: data['estimated_delivery_time'] as int?,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
          // Image URL from RPC might be fresher depending on function
          imageUrl: data['image_url'] as String?,
        );
      }).toList();

      // لا نعرض متاجر بدون عنوان.
      _nearbyStores = _filterStoresWithAddress(mergedStores);

      if (_nearbyStores.isEmpty) {
        _featuredStores = [];
        _filteredStores = [];
        _stores = [];
        _updateStoresByCategory();
        AppLogger.info('⚠️ تم استبعاد كل المتاجر القريبة لعدم وجود عنوان');
        notifyListeners();
        return;
      }

      // لتجنب التعارض بين مصادر البيانات في الشاشات، نجعل _stores تعكس نطاق المتاجر القريبة.
      _stores = List.from(_nearbyStores);
      _updateStoresByCategory();

      // تحديث المتاجر المميزة والمفلترة لتكون المتاجر القريبة فقط
      _featuredStores = List.from(_nearbyStores);
      _filteredStores = List.from(_nearbyStores);

      AppLogger.info("تم جلب ${_nearbyStores.length} متجر قريب");
      notifyListeners();
    } catch (e) {
      AppLogger.error("خطأ في جلب المتاجر القريبة", e);
      // في حالة الخطأ لا نعرض كل المتاجر (لمنع ظهورها ثم اختفائها عند تطبيق الموقع)
      _nearbyStores = [];
      _featuredStores = [];
      _filteredStores = [];
      _setError('تعذر تحميل المتاجر القريبة حالياً');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// جلب المتاجر حسب المدينة (بدون GPS)
  /// يُستخدم عند الاعتماد على العنوان المختار من العميل.
  Future<void> fetchStoresByCity({
    required String city,
    String? governorate,
    String? categoryFilter,
  }) async {
    final cityValue = city.trim();
    final governorateValue = (governorate ?? '').trim();

    if (cityValue.isEmpty) {
      _nearbyModeEnabled = true;
      _nearbyStores = [];
      _featuredStores = [];
      _filteredStores = [];
      _stores = [];
      _updateStoresByCategory();
      notifyListeners();
      return;
    }

    _nearbyModeEnabled = true;
    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info(
        '🏙️ جلب المتاجر حسب المدينة: $cityValue${governorateValue.isNotEmpty ? ' - $governorateValue' : ''}',
      );

      var query = _supabase
          .from('stores')
          .select(
            'id, merchant_id, name, description, phone, governorate, city, area, street, landmark, address, '
            'latitude, longitude, delivery_time, is_open, delivery_fee, min_order, delivery_mode, delivery_radius_km, '
            'rating, review_count, category, opening_hours, image_url, cover_url, is_active, created_at, updated_at',
          )
          .eq('is_active', true)
          .eq('city', cityValue);

      if (governorateValue.isNotEmpty) {
        query = query.eq('governorate', governorateValue);
      }

      if (categoryFilter != null && categoryFilter.trim().isNotEmpty) {
        query = query.eq('category', categoryFilter.trim());
      }

      final rows = await query;

      final scopedStores = (rows as List)
          .map(
            (row) => StoreModel.fromSupabaseMap(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);

      _nearbyStores = _filterStoresWithAddress(scopedStores);
      _stores = List.from(_nearbyStores);
      _featuredStores = List.from(_nearbyStores);
      _filteredStores = List.from(_nearbyStores);
      _updateStoresByCategory();

      AppLogger.info('✅ تم جلب ${_nearbyStores.length} متجر ضمن نفس المدينة');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المتاجر حسب المدينة', e);
      _nearbyStores = [];
      _featuredStores = [];
      _filteredStores = [];
      _stores = [];
      _updateStoresByCategory();
      _setError('تعذر تحميل المتاجر حسب المدينة حالياً');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث المتاجر المميزة بناءً على موقع العميل
  void updateFeaturedStoresFromLocation() {
    if (_nearbyStores.isNotEmpty) {
      _featuredStores = List.from(_nearbyStores);
    } else {
      _featuredStores = _stores.where((s) => s.isActive).toList();
    }
    notifyListeners();
  }

  /// تحديث تصنيف المتاجر حسب الفئة
  void _updateStoresByCategory() {
    _storesByCategory.clear();
    // Since category doesn't exist, we'll categorize by name for now
    final source = _nearbyModeEnabled
        ? _nearbyStores
        : (_stores.isNotEmpty ? _stores : _nearbyStores);
    for (final store in source) {
      final category = _resolveStoreCategoryId(store);
      if (!_storesByCategory.containsKey(category)) {
        _storesByCategory[category] = [];
      }
      _storesByCategory[category]!.add(store);
    }
  }

  void updateCategoryMapping(Map<String, String> mapping) {
    _categoryMapping = mapping;
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// بناء قائمة الفئات المتاحة لاستخدامها في واجهة المستخدم
  Map<String, String> getStoreCategories({
    Map<String, String>? categoryMapping,
  }) {
    final categories = <String, String>{'all': 'الكل'};

    // If the app is currently scoped to nearby stores only, _stores may be empty.
    // Fall back to _nearbyStores to keep category chips working.
    final source = _nearbyModeEnabled
        ? _nearbyStores
        : (_stores.isNotEmpty ? _stores : _nearbyStores);
    for (final store in source) {
      final categoryId = _resolveStoreCategoryId(store);
      if (categoryId.isEmpty) continue;

      // Use mapping if available to get a human-readable name
      final categoryName =
          categoryMapping?[categoryId] ??
          _categoryMapping[categoryId] ??
          _formatCategoryLabel(categoryId);
      categories[categoryId] = categoryName;
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
            // Don't log timeout errors as errors - they're expected with slow connections
            final isTimeoutError =
                error.toString().contains('timedOut') ||
                error.toString().contains('RealtimeSubscribeException');

            if (isTimeoutError) {
              AppLogger.warning(
                '⏱️ انتهت مهلة الاشتراك في البث الفوري - سيتم إعادة المحاولة',
                error,
              );
            } else {
              AppLogger.error('بث المتاجر الفوري توقف بسبب خطأ', error);
            }

            _storeStreamSub?.cancel();
            _storeStreamSub = null;
            // تحديث القائمة مرة واحدة بحيث يبقى المستخدم يرى أحدث البيانات
            unawaited(fetchStores(refresh: true));
            _handleRealtimeError(error);
          },
        );
  }

  void _handleRealtimeError(dynamic error) {
    // معالجة أخطاء timeout في Realtime subscription
    final isTimeoutError =
        error.toString().contains('timedOut') ||
        error.toString().contains('RealtimeSubscribeException');

    final isHandshakeFailure =
        error is WebSocketChannelException ||
        error.toString().contains('HandshakeException');

    // إذا كان timeout أو handshake failure، نعطل البث مؤقتاً
    if (!isHandshakeFailure && !isTimeoutError) {
      return;
    }

    if (_realtimeTemporarilyDisabled) {
      // Don't spam logs with repeated retry attempts
      return;
    }

    _realtimeTemporarilyDisabled = true;
    _realtimeRetryTimer?.cancel();

    final errorType = isTimeoutError ? 'انتهاء المهلة الزمنية' : 'فشل المصافحة';
    AppLogger.warning(
      '⏸️ تم تعطيل البث الفوري مؤقتاً بسبب $errorType. سنعيد المحاولة خلال ${_realtimeRetryDelay.inSeconds} ثانية.',
      error,
    );

    _realtimeRetryTimer = Timer(_realtimeRetryDelay, () {
      _realtimeTemporarilyDisabled = false;
      AppLogger.info('🔁 إعادة محاولة تفعيل البث الفوري للمتاجر');
      ensureRealtimeSubscription();
    });
  }

  void _applyRealtimeStores(List<StoreModel> stores) {
    if (_nearbyModeEnabled) {
      // لا نسمح للبث الفوري باستبدال القوائم عند الاعتماد على الموقع.
      return;
    }
    // لا نعرض متاجر بدون عنوان.
    _stores = _filterStoresWithAddress(stores);
    _filteredStores = List.from(_stores);
    _featuredStores = _stores.where((s) => s.isActive).toList();
    _updateStoresByCategory();
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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

    // Check internal mapping first for performance
    if (_categoryMapping.containsKey(categoryId)) {
      return _categoryMapping[categoryId]!;
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
  /// يستخدم المتاجر القريبة إذا كانت متاحة، وإلا يستخدم جميع المتاجر
  void filterStores(String searchQuery, String category) {
    // استخدام المتاجر القريبة إذا كانت متاحة
    final sourceStores = _nearbyModeEnabled
        ? _nearbyStores
        : (_nearbyStores.isNotEmpty ? _nearbyStores : _stores);
    List<StoreModel> filtered = List.from(sourceStores);

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
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// إعادة تعيين التصفية
  void resetFilters() {
    // استخدام المتاجر القريبة إذا كانت متاحة
    _filteredStores = _nearbyModeEnabled
        ? List.from(_nearbyStores)
        : (_nearbyStores.isNotEmpty
              ? List.from(_nearbyStores)
              : List.from(_stores));
    // تأجيل notifyListeners إلى ما بعد انتهاء مرحلة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
    // منع ظهور "كل المتاجر" عبر البث الفوري بعد مسح البيانات.
    _nearbyModeEnabled = true;
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
