import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/core/logger.dart';

enum CouponFilter { active, scheduled, expired, all }

class MerchantCouponsProvider with ChangeNotifier {
  List<CouponModel> _coupons = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _storeId;
  String? _merchantId;
  CouponFilter _activeFilter = CouponFilter.active;

  List<CouponModel> get coupons => List.unmodifiable(_coupons);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get storeId => _storeId;
  String? get merchantId => _merchantId;
  CouponFilter get activeFilter => _activeFilter;

  bool get hasStore => _storeId != null;

  List<CouponModel> get filteredCoupons {
    switch (_activeFilter) {
      case CouponFilter.active:
        return _coupons
            .where((coupon) => coupon.status == CouponStatus.active)
            .toList();
      case CouponFilter.scheduled:
        return _coupons
            .where((coupon) => coupon.status == CouponStatus.scheduled)
            .toList();
      case CouponFilter.expired:
        return _coupons
            .where((coupon) => coupon.status == CouponStatus.expired)
            .toList();
      case CouponFilter.all:
        return List.unmodifiable(_coupons);
    }
  }

  int get totalUsage =>
      _coupons.fold(0, (sum, coupon) => sum + coupon.usedCount);
  int get activeCount =>
      _coupons.where((coupon) => coupon.status == CouponStatus.active).length;
  int get scheduledCount => _coupons
      .where((coupon) => coupon.status == CouponStatus.scheduled)
      .length;
  int get expiredCount =>
      _coupons.where((coupon) => coupon.status == CouponStatus.expired).length;

  Future<void> initialize({required String merchantId}) async {
    if (_merchantId == merchantId && _storeId != null && _coupons.isNotEmpty) {
      return;
    }

    _merchantId = merchantId;
    _storeId = await CouponService.findStoreIdForMerchant(merchantId);

    if (_storeId == null) {
      _error = 'لم يتم العثور على متجر مرتبط بهذا التاجر';
      notifyListeners();
      return;
    }

    await loadCoupons();
  }

  Future<void> loadCoupons({bool refresh = false}) async {
    if (_storeId == null || _merchantId == null) {
      _error = 'الرجاء تأكيد معلومات المتجر قبل تحميل الكوبونات';
      notifyListeners();
      return;
    }

    if (!refresh && _coupons.isNotEmpty) return;

    _setLoading(true);
    try {
      _coupons = await CouponService.fetchCouponsByStore(_storeId!);
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل الكوبونات: ${e.toString()}';
      AppLogger.error('خطأ في تحميل الكوبونات', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createCoupon({
    required CouponInput input,
    required String createdBy,
  }) async {
    if (_storeId == null || _merchantId == null) {
      _error = 'لا يمكن إنشاء كوبون قبل تحديد المتجر';
      notifyListeners();
      return false;
    }

    _setSaving(true);
    try {
      final coupon = await CouponService.createCoupon(
        input: input,
        storeId: _storeId!,
        merchantId: _merchantId!,
        createdBy: createdBy,
      );
      _coupons.insert(0, coupon);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل إنشاء الكوبون: ${e.toString()}';
      AppLogger.error('فشل إنشاء الكوبون', e);
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> updateCoupon({
    required String couponId,
    required CouponInput input,
  }) async {
    _setSaving(true);
    try {
      final updated = await CouponService.updateCoupon(
        couponId: couponId,
        input: input,
      );

      final index = _coupons.indexWhere((coupon) => coupon.id == couponId);
      if (index != -1) {
        _coupons[index] = updated;
        notifyListeners();
      }
      _error = null;
      return true;
    } catch (e) {
      _error = 'فشل تحديث الكوبون: ${e.toString()}';
      AppLogger.error('فشل تحديث الكوبون', e);
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> toggleCoupon(CouponModel coupon) async {
    final newState = !coupon.isActive;

    final success = await CouponService.toggleCouponStatus(
      couponId: coupon.id,
      isActive: newState,
    );

    if (success) {
      final index = _coupons.indexWhere((c) => c.id == coupon.id);
      if (index != -1) {
        _coupons[index] = coupon.copyWith(
          isActive: newState,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }

    return success;
  }

  Future<bool> deleteCoupon(String couponId) async {
    final success = await CouponService.deleteCoupon(couponId);
    if (success) {
      _coupons.removeWhere((coupon) => coupon.id == couponId);
      notifyListeners();
    }
    return success;
  }

  void setFilter(CouponFilter filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadCoupons(refresh: true);
  }

  void clear() {
    _coupons = [];
    _storeId = null;
    _merchantId = null;
    _error = null;
    _activeFilter = CouponFilter.active;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }
}
