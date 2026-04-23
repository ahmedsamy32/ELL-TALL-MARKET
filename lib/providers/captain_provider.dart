import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/core/logger.dart';

/// Captain Provider لإدارة حالة الكابتنز
/// يستخدم CaptainService للتواصل مع قاعدة البيانات
class CaptainProvider with ChangeNotifier {
  // ================= State Variables =================
  List<CaptainModel> _captains = [];
  List<CaptainModel> _filteredCaptains = [];
  List<CaptainModel> _availableCaptains = [];
  List<CaptainModel> _nearbyActiveCaptains = [];

  bool _isLoading = false;
  String? _error;
  CaptainModel? _selectedCaptain;

  // Filter & Search
  String _searchQuery = '';
  String? _filterVehicleType;
  bool? _filterActive;
  String? _filterAvailabilityStatus;
  bool? _filterOnlineStatus;

  // Statistics
  Map<String, dynamic>? _statistics;

  // ================= Getters =================
  List<CaptainModel> get captains =>
      _filteredCaptains.isNotEmpty ? _filteredCaptains : _captains;
  List<CaptainModel> get allCaptains => _captains;
  List<CaptainModel> get availableCaptains => _availableCaptains;
  List<CaptainModel> get nearbyActiveCaptains => _nearbyActiveCaptains;

  bool get isLoading => _isLoading;
  String? get error => _error;
  CaptainModel? get selectedCaptain => _selectedCaptain;

  String get searchQuery => _searchQuery;
  String? get filterVehicleType => _filterVehicleType;
  bool? get filterActive => _filterActive;
  String? get filterAvailabilityStatus => _filterAvailabilityStatus;
  bool? get filterOnlineStatus => _filterOnlineStatus;

  Map<String, dynamic>? get statistics => _statistics;

  // ================= Private Helper Methods =================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ================= Captain Management =================

  /// جلب جميع الكابتنز
  Future<void> fetchAllCaptains({
    bool refresh = false,
    int page = 1,
    String? vehicleType,
    bool? isActive,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    if (!refresh && _captains.isNotEmpty) return;

    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info('جلب الكابتنز من CaptainService...');

      final captains = await CaptainService.getCaptains(
        page: page,
        vehicleType: vehicleType,
        isActive: isActive,
        orderBy: orderBy,
        ascending: ascending,
      );

      _captains = captains;
      _applyFilters();
      _updateAvailableCaptains();

      AppLogger.info('تم جلب ${_captains.length} كابتن بنجاح');
    } catch (e) {
      AppLogger.error('خطأ في جلب الكابتنز', e);
      _setError('فشل تحميل الكابتنز: ${e.toString()}');
      _captains = [];
    } finally {
      _setLoading(false);
    }
  }

  /// جلب كابتن بالمعرف
  Future<CaptainModel?> getCaptainById(String captainId) async {
    try {
      return await CaptainService.getCaptainById(captainId);
    } catch (e) {
      _setError('فشل جلب الكابتن: ${e.toString()}');
      return null;
    }
  }

  /// جلب كابتن بمعرف البروفايل
  Future<CaptainModel?> getCaptainByProfileId(String profileId) async {
    try {
      return await CaptainService.getCaptainByProfileId(profileId);
    } catch (e) {
      _setError('فشل جلب الكابتن: ${e.toString()}');
      return null;
    }
  }

  /// إضافة كابتن جديد
  Future<bool> addCaptain({
    required String profileId,
    required String vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    bool isActive = true,
    Map<String, dynamic>? additionalData,
  }) async {
    _setLoading(true);
    try {
      final captain = await CaptainService.createCaptain(
        profileId: profileId,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        licenseNumber: licenseNumber,
        isActive: isActive,
        additionalData: additionalData,
      );

      if (captain != null) {
        _captains.add(captain);
        _applyFilters();
        _updateAvailableCaptains();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل إضافة الكابتن: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث كابتن
  Future<bool> updateCaptain({
    required String captainId,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    bool? isActive,
    Map<String, dynamic>? additionalData,
  }) async {
    _setLoading(true);
    try {
      final updatedCaptain = await CaptainService.updateCaptain(
        captainId: captainId,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        licenseNumber: licenseNumber,
        isActive: isActive,
        additionalData: additionalData,
      );

      if (updatedCaptain != null) {
        final index = _captains.indexWhere((c) => c.id == captainId);
        if (index != -1) {
          _captains[index] = updatedCaptain;
          _applyFilters();
          _updateAvailableCaptains();
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث الكابتن: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف كابتن
  Future<bool> deleteCaptain(String captainId) async {
    _setLoading(true);
    try {
      final success = await CaptainService.deleteCaptain(captainId);
      if (success) {
        _captains.removeWhere((c) => c.id == captainId);
        _applyFilters();
        _updateAvailableCaptains();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل حذف الكابتن: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تغيير حالة نشاط الكابتن
  Future<bool> toggleCaptainStatus(String captainId) async {
    try {
      final success = await CaptainService.toggleAvailability(captainId);
      if (success) {
        final index = _captains.indexWhere((c) => c.id == captainId);
        if (index != -1) {
          _captains[index] = _captains[index].copyWith(
            status: _captains[index].isActive ? 'offline' : 'active',
            updatedAt: DateTime.now(),
          );
          _applyFilters();
          _updateAvailableCaptains();
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تغيير حالة الكابتن: ${e.toString()}');
      return false;
    }
  }

  // ================= Search & Filtering =================

  /// البحث في الكابتنز
  void searchCaptains(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  /// فلترة الكابتنز حسب نوع المركبة
  void filterByVehicleType(String? vehicleType) {
    _filterVehicleType = vehicleType;
    _applyFilters();
  }

  /// فلترة الكابتنز حسب الحالة النشطة
  void filterByActiveStatus(bool? isActive) {
    _filterActive = isActive;
    _applyFilters();
  }

  /// فلترة الكابتنز حسب حالة التوفر
  void filterByAvailabilityStatus(String? status) {
    _filterAvailabilityStatus = status;
    _applyFilters();
  }

  /// فلترة الكابتنز حسب الحالة الأونلاين
  void filterByOnlineStatus(bool? isOnline) {
    _filterOnlineStatus = isOnline;
    _applyFilters();
  }

  /// تطبيق جميع الفلاتر
  void _applyFilters() {
    List<CaptainModel> filtered = List.from(_captains);

    // تطبيق فلتر البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((captain) {
        final query = _searchQuery.toLowerCase();
        return captain.vehicleType.toLowerCase().contains(query) ||
            (captain.vehicleNumber?.toLowerCase().contains(query) ?? false) ||
            (captain.driverLicense?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق فلتر نوع المركبة
    if (_filterVehicleType != null && _filterVehicleType != 'الكل') {
      filtered = filtered
          .where((captain) => captain.vehicleType == _filterVehicleType)
          .toList();
    }

    // تطبيق فلتر الحالة النشطة
    if (_filterActive != null) {
      filtered = filtered
          .where((captain) => captain.isActive == _filterActive)
          .toList();
    }

    _filteredCaptains = filtered;
    notifyListeners();
  }

  /// إعادة تعيين الفلاتر
  void resetFilters() {
    _searchQuery = '';
    _filterVehicleType = null;
    _filterActive = null;
    _filterAvailabilityStatus = null;
    _filterOnlineStatus = null;
    _filteredCaptains = List.from(_captains);
    notifyListeners();
  }

  /// تحديث قائمة الكابتنز المتاحين
  void _updateAvailableCaptains() {
    _availableCaptains = _captains
        .where((captain) => captain.isActive)
        .toList();
  }

  // ================= Statistics =================

  /// جلب الإحصائيات العامة للكابتنز
  Future<void> fetchStatistics() async {
    try {
      _setLoading(true);
      _statistics = await CaptainService.getGeneralStats();
      notifyListeners();
    } catch (e) {
      _setError('فشل جلب الإحصائيات: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// جلب إحصائيات كابتن محدد
  Future<Map<String, dynamic>?> getCaptainStatistics(String captainId) async {
    try {
      return await CaptainService.getCaptainStatistics(captainId);
    } catch (e) {
      _setError('فشل جلب إحصائيات الكابتن: ${e.toString()}');
      return null;
    }
  }

  /// الحصول على إحصائيات سريعة
  Map<String, int> getQuickStatistics() {
    return {
      'total': _captains.length,
      'active': _captains.where((c) => c.isActive).length,
      'inactive': _captains.where((c) => !c.isActive).length,
      'motorcycle': _captains
          .where((c) => c.vehicleType == 'motorcycle')
          .length,
      'car': _captains.where((c) => c.vehicleType == 'car').length,
      'bicycle': _captains.where((c) => c.vehicleType == 'bicycle').length,
      'truck': _captains.where((c) => c.vehicleType == 'truck').length,
    };
  }

  // ================= Vehicle Type Management =================

  List<CaptainModel> getCaptainsByVehicleType(String vehicleType) {
    return _captains
        .where((captain) => captain.vehicleType == vehicleType)
        .toList();
  }

  List<String> get availableVehicleTypes {
    return _captains.map((captain) => captain.vehicleType).toSet().toList();
  }

  // ================= Sorting =================

  void sortCaptains(String sortBy) {
    switch (sortBy) {
      case 'name':
        _filteredCaptains.sort(
          (a, b) => a.vehicleType.compareTo(b.vehicleType),
        );
        break;
      case 'vehicle_type':
        _filteredCaptains.sort(
          (a, b) => a.vehicleType.compareTo(b.vehicleType),
        );
        break;
      case 'status':
        _filteredCaptains.sort(
          (a, b) => b.isActive.toString().compareTo(a.isActive.toString()),
        );
        break;
      case 'created_date':
      default:
        _filteredCaptains.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    notifyListeners();
  }

  // ================= Selection Management =================

  void selectCaptain(CaptainModel? captain) {
    _selectedCaptain = captain;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCaptain = null;
    notifyListeners();
  }

  // ================= Utility Methods =================

  /// البحث المتقدم
  Future<List<CaptainModel>> advancedSearch({
    String? query,
    String? vehicleType,
    bool? isActive,
    bool? isOnline,
    bool? isAvailable,
    double? minRating,
    int limit = 20,
  }) async {
    try {
      return await CaptainService.searchCaptains(
        query: query ?? '',
        vehicleType: vehicleType,
        isActive: isActive,
        limit: limit,
      );
    } catch (e) {
      _setError('فشل البحث المتقدم: ${e.toString()}');
      return [];
    }
  }

  /// تنظيف البيانات
  void clear() {
    _captains = [];
    _filteredCaptains = [];
    _availableCaptains = [];
    _nearbyActiveCaptains = [];
    _selectedCaptain = null;
    _error = null;
    _statistics = null;
    notifyListeners();
  }

  /// الحصول على كابتن بالمعرف (محلياً)
  CaptainModel? getCaptainByIdSync(String captainId) {
    try {
      return _captains.firstWhere((captain) => captain.id == captainId);
    } catch (e) {
      return null;
    }
  }

  /// التحقق من وجود كابتن
  bool hasCaptain(String captainId) {
    return _captains.any((captain) => captain.id == captainId);
  }
}
