import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/merchant_model.dart';
import 'package:ell_tall_market/services/merchant_service.dart';
import 'package:ell_tall_market/core/logger.dart';

/// MerchantProvider - إدارة حالة التجار
/// يستخدم MerchantService للتعامل مع قاعدة البيانات
class MerchantProvider with ChangeNotifier {
  // ================= State Variables =================
  List<MerchantModel> _merchants = [];
  List<MerchantModel> _filteredMerchants = [];
  List<MerchantModel> _activeMerchants = [];
  List<MerchantModel> _verifiedMerchants = [];
  List<MerchantModel> _pendingVerificationMerchants = [];

  bool _isLoading = false;
  String? _error;
  MerchantModel? _selectedMerchant;

  // Filter & Search state
  String _searchQuery = '';
  String? _filterBusinessType;
  bool? _filterIsActive;
  String? _filterVerificationStatus;
  String _sortBy = 'business_name';
  bool _sortAscending = true;

  // Statistics
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _selectedMerchantStats;

  // Pagination
  int _currentPage = 1;
  bool _hasMoreData = true;

  // Real-time subscriptions
  StreamSubscription? _merchantsSubscription;
  StreamSubscription? _selectedMerchantSubscription;

  // ================= Getters =================
  List<MerchantModel> get merchants =>
      _filteredMerchants.isNotEmpty ? _filteredMerchants : _merchants;
  List<MerchantModel> get allMerchants => _merchants;
  List<MerchantModel> get activeMerchants => _activeMerchants;
  List<MerchantModel> get verifiedMerchants => _verifiedMerchants;
  List<MerchantModel> get pendingVerificationMerchants =>
      _pendingVerificationMerchants;

  bool get isLoading => _isLoading;
  String? get error => _error;
  MerchantModel? get selectedMerchant => _selectedMerchant;

  String get searchQuery => _searchQuery;
  String? get filterBusinessType => _filterBusinessType;
  bool? get filterIsActive => _filterIsActive;
  String? get filterVerificationStatus => _filterVerificationStatus;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  Map<String, dynamic>? get statistics => _statistics;
  Map<String, dynamic>? get selectedMerchantStats => _selectedMerchantStats;

  int get currentPage => _currentPage;
  bool get hasMoreData => _hasMoreData;

  // ================= Private Helper Methods =================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ================= Merchant Management =================

  /// جلب جميع التجار
  Future<void> fetchAllMerchants({bool refresh = false}) async {
    if (!refresh && _merchants.isNotEmpty) return;

    _setLoading(true);
    try {
      _merchants = await MerchantService.getMerchants(
        page: 1,
        orderBy: _sortBy,
        ascending: _sortAscending,
      );

      _applyFilters();
      _setError(null);

      AppLogger.info('تم جلب ${_merchants.length} تاجر');
    } catch (e) {
      _setError('فشل جلب التجار: ${e.toString()}');
      _merchants = [];
    } finally {
      _setLoading(false);
    }
  }

  /// جلب التجار النشطين
  Future<void> fetchActiveMerchants() async {
    _setLoading(true);
    try {
      _activeMerchants = await MerchantService.getActiveMerchants(
        orderBy: _sortBy,
        ascending: _sortAscending,
      );

      _setError(null);
      AppLogger.info('تم جلب ${_activeMerchants.length} تاجر نشط');
    } catch (e) {
      _setError('فشل جلب التجار النشطين: ${e.toString()}');
      _activeMerchants = [];
    } finally {
      _setLoading(false);
    }
  }

  /// جلب التجار المعتمدين
  Future<void> fetchVerifiedMerchants() async {
    _setLoading(true);
    try {
      _verifiedMerchants = await MerchantService.getVerifiedMerchants(
        orderBy: _sortBy,
        ascending: _sortAscending,
      );

      _setError(null);
      AppLogger.info('تم جلب ${_verifiedMerchants.length} تاجر معتمد');
    } catch (e) {
      _setError('فشل جلب التجار المعتمدين: ${e.toString()}');
      _verifiedMerchants = [];
    } finally {
      _setLoading(false);
    }
  }

  /// جلب التجار المنتظرين للتحقق
  Future<void> fetchPendingVerificationMerchants() async {
    _setLoading(true);
    try {
      _pendingVerificationMerchants =
          await MerchantService.getPendingVerificationMerchants();

      _setError(null);
      AppLogger.info(
        'تم جلب ${_pendingVerificationMerchants.length} تاجر في انتظار التحقق',
      );
    } catch (e) {
      _setError('فشل جلب التجار المنتظرين: ${e.toString()}');
      _pendingVerificationMerchants = [];
    } finally {
      _setLoading(false);
    }
  }

  /// جلب تاجر محدد
  Future<void> fetchMerchantById(String merchantId) async {
    _setLoading(true);
    try {
      _selectedMerchant = await MerchantService.getMerchantById(merchantId);

      if (_selectedMerchant != null) {
        // جلب إحصائيات التاجر
        await fetchMerchantStatistics(merchantId);
        _setError(null);
      } else {
        _setError('لم يتم العثور على التاجر');
      }
    } catch (e) {
      _setError('فشل جلب التاجر: ${e.toString()}');
      _selectedMerchant = null;
    } finally {
      _setLoading(false);
    }
  }

  /// جلب تاجر بواسطة معرف البروفايل
  Future<void> fetchMerchantByProfileId(String profileId) async {
    _setLoading(true);
    try {
      _selectedMerchant = await MerchantService.getMerchantByProfileId(
        profileId,
      );

      if (_selectedMerchant != null) {
        await fetchMerchantStatistics(_selectedMerchant!.id);
        _setError(null);
      } else {
        _setError('لم يتم العثور على تاجر لهذا البروفايل');
      }
    } catch (e) {
      _setError('فشل جلب التاجر: ${e.toString()}');
      _selectedMerchant = null;
    } finally {
      _setLoading(false);
    }
  }

  // ================= CRUD Operations =================

  /// تسجيل تاجر جديد
  Future<bool> registerMerchant({
    required String profileId,
    required String businessName,
    String? businessType,
    String? businessAddress,
    String? contactPhone,
    String? logoUrl,
    bool isActive = true,
    Map<String, dynamic>? businessHours,
    List<String>? businessCategories,
    String? taxId,
    String? licenseNumber,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? socialMedia,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    try {
      final newMerchant = await MerchantService.registerMerchant(
        profileId: profileId,
        storeName: businessName,
        storeDescription: businessType,
        address: businessAddress,
        latitude: null,
        longitude: null,
        isVerified: false,
      );

      if (newMerchant != null) {
        _merchants.add(newMerchant);
        _applyFilters();
        _setError(null);

        AppLogger.info('تم تسجيل التاجر: $businessName');
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تسجيل التاجر: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث معلومات التاجر
  Future<bool> updateMerchant({
    required String merchantId,
    String? businessName,
    String? businessType,
    String? businessAddress,
    String? contactPhone,
    String? logoUrl,
    bool? isActive,
    Map<String, dynamic>? businessHours,
    List<String>? businessCategories,
    String? taxId,
    String? licenseNumber,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? socialMedia,
    String? verificationStatus,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    try {
      final updatedMerchant = await MerchantService.updateMerchant(
        merchantId: merchantId,
        businessName: businessName,
        businessType: businessType,
        businessAddress: businessAddress,
        contactPhone: contactPhone,
        logoUrl: logoUrl,
        isActive: isActive,
        businessHours: businessHours,
        businessCategories: businessCategories,
        taxId: taxId,
        licenseNumber: licenseNumber,
        bankDetails: bankDetails,
        socialMedia: socialMedia,
        verificationStatus: verificationStatus,
        metadata: metadata,
      );

      if (updatedMerchant != null) {
        // تحديث التاجر في القائمة المحلية
        final index = _merchants.indexWhere((m) => m.id == merchantId);
        if (index != -1) {
          _merchants[index] = updatedMerchant;
        }

        // تحديث التاجر المحدد إذا كان هو نفسه
        if (_selectedMerchant?.id == merchantId) {
          _selectedMerchant = updatedMerchant;
        }

        _applyFilters();
        _setError(null);

        AppLogger.info('تم تحديث التاجر: ${updatedMerchant.businessName}');
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث التاجر: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف تاجر
  Future<bool> deleteMerchant(String merchantId) async {
    _setLoading(true);
    try {
      final success = await MerchantService.deleteMerchant(merchantId);

      if (success) {
        _merchants.removeWhere((m) => m.id == merchantId);
        _applyFilters();

        if (_selectedMerchant?.id == merchantId) {
          _selectedMerchant = null;
          _selectedMerchantStats = null;
        }

        _setError(null);
        AppLogger.info('تم حذف التاجر');
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل حذف التاجر: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ================= Status Management =================

  /// تغيير حالة النشاط
  Future<bool> toggleMerchantStatus(String merchantId) async {
    _setLoading(true);
    try {
      final success = await MerchantService.toggleMerchantStatus(merchantId);

      if (success) {
        // تحديث الحالة محلياً
        final index = _merchants.indexWhere((m) => m.id == merchantId);
        if (index != -1) {
          final merchant = _merchants[index];
          _merchants[index] = merchant.copyWith(isActive: !merchant.isActive);
        }

        if (_selectedMerchant?.id == merchantId) {
          _selectedMerchant = _selectedMerchant!.copyWith(
            isActive: !_selectedMerchant!.isActive,
          );
        }

        _applyFilters();
        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تغيير حالة التاجر: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث حالة التحقق
  Future<bool> updateVerificationStatus({
    required String merchantId,
    required String status,
    String? notes,
    String? verifiedBy,
  }) async {
    _setLoading(true);
    try {
      final success = await MerchantService.updateVerificationStatus(
        merchantId: merchantId,
        status: status,
        notes: notes,
        verifiedBy: verifiedBy,
      );

      if (success) {
        // تحديث الحالة محلياً - reload merchants after verification update
        await fetchAllMerchants(refresh: true);

        _applyFilters();
        await fetchPendingVerificationMerchants(); // تحديث قائمة المنتظرين
        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث حالة التحقق: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// طلب إعادة التحقق
  Future<bool> requestReVerification(String merchantId) async {
    _setLoading(true);
    try {
      final success = await MerchantService.requestReVerification(merchantId);

      if (success) {
        await fetchPendingVerificationMerchants();
        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل طلب إعادة التحقق: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ================= Statistics =================

  /// جلب إحصائيات التاجر
  Future<void> fetchMerchantStatistics(String merchantId) async {
    try {
      _selectedMerchantStats = await MerchantService.getMerchantStatistics(
        merchantId,
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('فشل جلب إحصائيات التاجر: ${e.toString()}', e);
    }
  }

  /// جلب الإحصائيات العامة
  Future<void> fetchMerchantsStatistics() async {
    _setLoading(true);
    try {
      _statistics = await MerchantService.getMerchantsStatistics();
      _setError(null);
    } catch (e) {
      _setError('فشل جلب الإحصائيات: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// جلب أفضل التجار
  Future<List<Map<String, dynamic>>> fetchTopMerchants({
    int limit = 10,
    String criteria = 'rating',
  }) async {
    try {
      return await MerchantService.getTopMerchants(
        limit: limit,
        criteria: criteria,
      );
    } catch (e) {
      _setError('فشل جلب أفضل التجار: ${e.toString()}');
      return [];
    }
  }

  /// تحديث التقييم
  Future<bool> updateMerchantRating({
    required String merchantId,
    required double newRating,
  }) async {
    try {
      final success = await MerchantService.updateMerchantRating(
        merchantId: merchantId,
        newRating: newRating,
      );

      if (success && _selectedMerchant?.id == merchantId) {
        await fetchMerchantStatistics(merchantId);
      }

      return success;
    } catch (e) {
      _setError('فشل تحديث التقييم: ${e.toString()}');
      return false;
    }
  }

  /// تحديث إحصائيات المبيعات
  Future<bool> updateSalesStats({
    required String merchantId,
    required double saleAmount,
  }) async {
    try {
      final success = await MerchantService.updateSalesStats(
        merchantId: merchantId,
        saleAmount: saleAmount,
      );

      if (success && _selectedMerchant?.id == merchantId) {
        await fetchMerchantStatistics(merchantId);
      }

      return success;
    } catch (e) {
      _setError('فشل تحديث إحصائيات المبيعات: ${e.toString()}');
      return false;
    }
  }

  // ================= Image Management =================

  /// رفع شعار التاجر
  Future<String?> uploadMerchantLogo({
    required String merchantId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    _setLoading(true);
    try {
      final imageUrl = await MerchantService.uploadMerchantLogo(
        merchantId: merchantId,
        imageBytes: imageBytes,
        fileName: fileName,
      );

      if (imageUrl != null) {
        // تحديث الشعار محلياً
        final index = _merchants.indexWhere((m) => m.id == merchantId);
        if (index != -1) {
          _merchants[index] = _merchants[index].copyWith(logoUrl: imageUrl);
        }

        if (_selectedMerchant?.id == merchantId) {
          _selectedMerchant = _selectedMerchant!.copyWith(logoUrl: imageUrl);
        }

        _applyFilters();
        _setError(null);
      }

      return imageUrl;
    } catch (e) {
      _setError('فشل رفع شعار التاجر: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف شعار التاجر
  Future<bool> deleteMerchantLogo(String merchantId) async {
    _setLoading(true);
    try {
      final success = await MerchantService.deleteMerchantLogo(merchantId);

      if (success) {
        // إزالة الشعار محلياً
        final index = _merchants.indexWhere((m) => m.id == merchantId);
        if (index != -1) {
          _merchants[index] = _merchants[index].copyWith(logoUrl: null);
        }

        if (_selectedMerchant?.id == merchantId) {
          _selectedMerchant = _selectedMerchant!.copyWith(logoUrl: null);
        }

        _applyFilters();
        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل حذف شعار التاجر: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ================= Search & Filter =================

  /// البحث في التجار
  Future<void> searchMerchants(String searchTerm) async {
    _searchQuery = searchTerm;

    if (searchTerm.isEmpty) {
      _applyFilters();
      return;
    }

    _setLoading(true);
    try {
      final results = await MerchantService.searchMerchants(
        searchTerm: searchTerm,
        activeOnly: _filterIsActive ?? false,
        verifiedOnly: _filterVerificationStatus == 'verified',
      );

      _filteredMerchants = results;
      _setError(null);
    } catch (e) {
      _setError('فشل البحث: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// البحث المتقدم
  Future<void> advancedSearch({
    String? businessName,
    String? businessType,
    String? businessAddress,
    bool? isActive,
    String? verificationStatus,
    double? minRating,
    int? minOrders,
    double? minSales,
    String orderBy = 'business_name',
    bool ascending = true,
    int limit = 50,
  }) async {
    _setLoading(true);
    try {
      final results = await MerchantService.advancedSearchMerchants(
        businessName: businessName,
        businessType: businessType,
        businessAddress: businessAddress,
        isActive: isActive,
        verificationStatus: verificationStatus,
        minRating: minRating,
        minOrders: minOrders,
        minSales: minSales,
        orderBy: orderBy,
        ascending: ascending,
        limit: limit,
      );

      _filteredMerchants = results;
      _setError(null);
    } catch (e) {
      _setError('فشل البحث المتقدم: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// تطبيق الفلاتر محلياً
  void _applyFilters() {
    List<MerchantModel> filtered = List.from(_merchants);

    // تطبيق فلتر نوع العمل
    if (_filterBusinessType != null && _filterBusinessType!.isNotEmpty) {
      filtered = filtered
          .where((m) => m.businessType == _filterBusinessType)
          .toList();
    }

    // تطبيق فلتر حالة النشاط
    if (_filterIsActive != null) {
      filtered = filtered.where((m) => m.isActive == _filterIsActive).toList();
    }

    // تطبيق فلتر حالة التحقق - skip since not available in model
    // TODO: Implement when verificationStatus is added to MerchantModel

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        return m.businessName.toLowerCase().contains(query) ||
            (m.businessAddress?.toLowerCase().contains(query) ?? false) ||
            (m.contactPhone?.contains(query) ?? false);
      }).toList();
    }

    _filteredMerchants = filtered;
    notifyListeners();
  }

  /// تعيين فلتر نوع العمل
  void setBusinessTypeFilter(String? businessType) {
    _filterBusinessType = businessType;
    _applyFilters();
  }

  /// تعيين فلتر حالة النشاط
  void setActiveFilter(bool? isActive) {
    _filterIsActive = isActive;
    _applyFilters();
  }

  /// تعيين فلتر حالة التحقق
  void setVerificationStatusFilter(String? verificationStatus) {
    _filterVerificationStatus = verificationStatus;
    _applyFilters();
  }

  /// تعيين ترتيب القائمة
  void setSorting(String sortBy, bool ascending) {
    _sortBy = sortBy;
    _sortAscending = ascending;

    _filteredMerchants.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortBy) {
        case 'business_name':
          aValue = a.businessName;
          bValue = b.businessName;
          break;
        case 'created_at':
          aValue = a.createdAt;
          bValue = b.createdAt;
          break;
        case 'rating':
          // rating not available in MerchantModel, fallback to name
          aValue = a.businessName;
          bValue = b.businessName;
          break;
        case 'total_sales':
          // totalSales not available in MerchantModel, fallback to name
          aValue = a.businessName;
          bValue = b.businessName;
          break;
        case 'total_orders':
          // totalOrders not available in MerchantModel, fallback to name
          aValue = a.businessName;
          bValue = b.businessName;
          break;
        default:
          aValue = a.businessName;
          bValue = b.businessName;
      }

      final comparison = aValue.compareTo(bValue);
      return ascending ? comparison : -comparison;
    });

    notifyListeners();
  }

  /// إعادة تعيين الفلاتر
  void resetFilters() {
    _searchQuery = '';
    _filterBusinessType = null;
    _filterIsActive = null;
    _filterVerificationStatus = null;
    _applyFilters();
  }

  // ================= Real-time Updates =================

  /// بدء مراقبة التحديثات الفورية
  void startWatchingMerchants() {
    _merchantsSubscription?.cancel();

    _merchantsSubscription = MerchantService.watchMerchants().listen(
      (data) {
        try {
          _merchants = data.map((json) => MerchantModel.fromMap(json)).toList();
          _applyFilters();
        } catch (e) {
          AppLogger.error('خطأ في معالجة تحديثات التجار الفورية', e);
        }
      },
      onError: (error) {
        AppLogger.error('خطأ في مراقبة تحديثات التجار', error);
      },
    );
  }

  /// بدء مراقبة تاجر محدد
  void startWatchingMerchant(String merchantId) {
    _selectedMerchantSubscription?.cancel();

    _selectedMerchantSubscription = MerchantService.watchMerchant(merchantId)
        .listen(
          (data) {
            if (data != null) {
              try {
                _selectedMerchant = MerchantModel.fromMap(data);
                notifyListeners();
              } catch (e) {
                AppLogger.error('خطأ في معالجة تحديثات التاجر المحدد', e);
              }
            }
          },
          onError: (error) {
            AppLogger.error('خطأ في مراقبة تحديثات التاجر المحدد', error);
          },
        );
  }

  /// إيقاف مراقبة التحديثات
  void stopWatching() {
    _merchantsSubscription?.cancel();
    _selectedMerchantSubscription?.cancel();
    _merchantsSubscription = null;
    _selectedMerchantSubscription = null;
  }

  // ================= Bulk Operations =================

  /// عمليات مجمعة على التجار
  Future<bool> bulkUpdateMerchants({
    required List<String> merchantIds,
    bool? isActive,
    String? verificationStatus,
  }) async {
    _setLoading(true);
    try {
      final success = await MerchantService.bulkUpdateMerchants(
        merchantIds: merchantIds,
        isActive: isActive,
        verificationStatus: verificationStatus,
      );

      if (success) {
        // تحديث التجار محلياً
        for (final merchantId in merchantIds) {
          final index = _merchants.indexWhere((m) => m.id == merchantId);
          if (index != -1) {
            _merchants[index] = _merchants[index].copyWith(
              isActive: isActive ?? _merchants[index].isActive,
              // verificationStatus not available in MerchantModel
            );
          }
        }

        _applyFilters();
        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل التحديث المجمع: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث جميع إحصائيات التجار
  Future<bool> updateAllMerchantStats() async {
    _setLoading(true);
    try {
      final success = await MerchantService.updateAllMerchantStats();

      if (success) {
        // إعادة جلب الإحصائيات
        if (_selectedMerchant != null) {
          await fetchMerchantStatistics(_selectedMerchant!.id);
        }
        await fetchMerchantsStatistics();

        _setError(null);
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث الإحصائيات: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ================= Pagination =================

  /// جلب المزيد من التجار (للـ pagination)
  Future<void> loadMoreMerchants() async {
    if (_isLoading || !_hasMoreData) return;

    _setLoading(true);
    try {
      final nextPage = _currentPage + 1;
      final moreMerchants = await MerchantService.getMerchants(
        page: nextPage,
        searchTerm: _searchQuery.isNotEmpty ? _searchQuery : null,
        isVerified: _filterVerificationStatus == 'verified' ? true : null,
        orderBy: _sortBy,
        ascending: _sortAscending,
      );

      if (moreMerchants.isNotEmpty) {
        _merchants.addAll(moreMerchants);
        _currentPage = nextPage;
        _applyFilters();
      } else {
        _hasMoreData = false;
      }

      _setError(null);
    } catch (e) {
      _setError('فشل جلب المزيد من التجار: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// إعادة تعيين pagination
  void resetPagination() {
    _currentPage = 1;
    _hasMoreData = true;
  }

  // ================= Utility Methods =================

  /// البحث عن تاجر محلياً
  MerchantModel? findMerchantById(String merchantId) {
    try {
      return _merchants.firstWhere((m) => m.id == merchantId);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على التجار حسب نوع العمل
  List<MerchantModel> getMerchantsByBusinessType(String businessType) {
    return _merchants.where((m) => m.businessType == businessType).toList();
  }

  /// الحصول على التجار حسب حالة التحقق
  List<MerchantModel> getMerchantsByVerificationStatus(String status) {
    // verificationStatus not available in MerchantModel, return all active merchants as placeholder
    return _merchants.where((m) => m.isActive).toList();
  }

  /// تنظيف البيانات
  void clearData() {
    _merchants.clear();
    _filteredMerchants.clear();
    _activeMerchants.clear();
    _verifiedMerchants.clear();
    _pendingVerificationMerchants.clear();

    _selectedMerchant = null;
    _statistics = null;
    _selectedMerchantStats = null;

    _error = null;
    resetFilters();
    resetPagination();

    notifyListeners();
  }

  // ================= Validation =================

  /// التحقق من صحة بيانات التاجر
  static bool validateMerchantData({
    required String businessName,
    String? businessAddress,
    String? contactPhone,
    String? taxId,
    String? licenseNumber,
  }) {
    return MerchantService.validateMerchantData(
      businessName: businessName,
      businessAddress: businessAddress,
      contactPhone: contactPhone,
      taxId: taxId,
      licenseNumber: licenseNumber,
    );
  }

  /// التحقق من ساعات العمل
  static bool validateBusinessHours(Map<String, dynamic> businessHours) {
    return MerchantService.validateBusinessHours(businessHours);
  }

  /// التحقق من معلومات البنك
  static bool validateBankDetails(Map<String, dynamic> bankDetails) {
    return MerchantService.validateBankDetails(bankDetails);
  }

  /// تنظيف اسم العمل
  static String sanitizeBusinessName(String name) {
    return MerchantService.sanitizeBusinessName(name);
  }

  /// إنشاء slug للعمل
  static String generateBusinessSlug(String name) {
    return MerchantService.generateBusinessSlug(name);
  }

  // ================= Dispose =================

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }
}
