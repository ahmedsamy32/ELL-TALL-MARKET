import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/banner_model.dart';
import 'package:ell_tall_market/services/banner_service.dart';
import 'package:ell_tall_market/core/logger.dart';

/// مزود حالة البانرات
/// يدير البانرات الإعلانية والترويجية في التطبيق
/// يستخدم BannerService لجميع عمليات قاعدة البيانات
///
/// ⚠️ ملاحظة: التحكم في البانرات للـ Admin فقط
/// - عمليات الإضافة والتعديل والحذف تتطلب صلاحيات Admin
/// - المستخدمون العاديون يمكنهم فقط مشاهدة البانرات النشطة
class BannerProvider with ChangeNotifier {
  // حالة البانرات
  List<BannerModel> _banners = [];

  // حالة التحميل والأخطاء
  bool _isLoading = false;
  String? _error;

  // ================================
  // Getters
  // ================================

  List<BannerModel> get banners => List.unmodifiable(_banners);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // معلومات البانرات
  bool get isEmpty => _banners.isEmpty;
  bool get hasItems => _banners.isNotEmpty;
  int get bannersCount => _banners.length;

  // فلترة البانرات
  List<BannerModel> get activeBanners =>
      _banners.where((b) => b.isActive).toList();

  List<BannerModel> get inactiveBanners =>
      _banners.where((b) => !b.isActive).toList();

  int get activeBannersCount => activeBanners.length;
  int get inactiveBannersCount => inactiveBanners.length;

  // حالة رسائل الحالة
  String get statusMessage {
    if (_isLoading) return 'جاري تحميل البانرات...';
    if (_error != null) return 'خطأ: $_error';
    if (_banners.isEmpty) return 'لا توجد بانرات';
    return '${_banners.length} بانر';
  }

  // ================================
  // تهيئة البانرات
  // ================================

  /// تهيئة وتحميل البانرات
  Future<void> initialize() async {
    await fetchBanners();
  }

  // ================================
  // جلب البانرات
  // ================================

  /// جلب جميع البانرات من قاعدة البيانات
  Future<void> fetchBanners() async {
    _setLoading(true);
    _clearError();

    try {
      _banners = await BannerService.getAllBanners();
      AppLogger.info('تم تحميل ${_banners.length} بانر بنجاح');
    } catch (e) {
      _setError('فشل تحميل البانرات: ${e.toString()}');
      AppLogger.error('خطأ في جلب البانرات', e);
    } finally {
      _setLoading(false);
    }
  }

  /// جلب البانرات النشطة فقط
  Future<void> fetchActiveBanners() async {
    _setLoading(true);
    _clearError();

    try {
      _banners = await BannerService.getActiveBanners();
      AppLogger.info('تم تحميل ${_banners.length} بانر نشط');
    } catch (e) {
      _setError('فشل تحميل البانرات: ${e.toString()}');
      AppLogger.error('خطأ في جلب البانرات النشطة', e);
    } finally {
      _setLoading(false);
    }
  }

  /// جلب بانر واحد حسب المعرف
  Future<BannerModel?> getBannerById(String bannerId) async {
    try {
      return await BannerService.getBannerById(bannerId);
    } catch (e) {
      AppLogger.error('خطأ في جلب البانر', e);
      return null;
    }
  }

  // ================================
  // إدارة البانرات
  // ⚠️ للـ Admin فقط - تتطلب صلاحيات إدارية
  // ================================

  /// إضافة بانر جديد (Admin فقط)
  /// ⚠️ يتطلب: المستخدم الحالي يجب أن يكون Admin
  Future<bool> addBanner(BannerModel banner) async {
    _clearError();

    try {
      final newBanner = await BannerService.createBanner(banner);

      if (newBanner != null) {
        _banners.insert(0, newBanner); // إضافة في البداية
        notifyListeners();

        AppLogger.info('تم إضافة بانر جديد: ${newBanner.id}');
        return true;
      }

      _setError('فشل إضافة البانر');
      return false;
    } catch (e) {
      _setError('فشل إضافة البانر: ${e.toString()}');
      AppLogger.error('خطأ في إضافة البانر', e);
      return false;
    }
  }

  /// تحديث بانر موجود (Admin فقط)
  /// ⚠️ يتطلب: المستخدم الحالي يجب أن يكون Admin
  Future<bool> updateBanner(BannerModel banner) async {
    _clearError();

    try {
      final updatedBanner = await BannerService.updateBanner(
        banner.id,
        banner.toMap(),
      );

      if (updatedBanner != null) {
        final index = _banners.indexWhere((b) => b.id == banner.id);
        if (index != -1) {
          _banners[index] = updatedBanner;
          notifyListeners();

          AppLogger.info('تم تحديث البانر: ${banner.id}');
          return true;
        }
      }

      _setError('البانر غير موجود');
      return false;
    } catch (e) {
      _setError('فشل تحديث البانر: ${e.toString()}');
      AppLogger.error('خطأ في تحديث البانر', e);
      return false;
    }
  }

  /// تبديل حالة تفعيل البانر (Admin فقط)
  /// ⚠️ يتطلب: المستخدم الحالي يجب أن يكون Admin
  Future<bool> toggleBannerStatus(String bannerId) async {
    _clearError();

    try {
      final index = _banners.indexWhere((b) => b.id == bannerId);
      if (index == -1) {
        _setError('البانر غير موجود');
        return false;
      }

      final banner = _banners[index];
      final newStatus = !banner.isActive;

      final success = await BannerService.toggleBannerStatus(
        bannerId,
        newStatus,
      );

      if (success) {
        _banners[index] = banner.copyWith(isActive: newStatus);
        notifyListeners();

        AppLogger.info(
          'تم ${newStatus ? "تفعيل" : "إلغاء تفعيل"} البانر: $bannerId',
        );
        return true;
      }

      _setError('فشل تغيير حالة البانر');
      return false;
    } catch (e) {
      _setError('فشل تغيير حالة البانر: ${e.toString()}');
      AppLogger.error('خطأ في تغيير حالة البانر', e);
      return false;
    }
  }

  /// حذف بانر (Admin فقط)
  /// ⚠️ يتطلب: المستخدم الحالي يجب أن يكون Admin
  Future<bool> deleteBanner(String bannerId) async {
    _clearError();

    try {
      final success = await BannerService.deleteBanner(bannerId);

      if (success) {
        _banners.removeWhere((b) => b.id == bannerId);
        notifyListeners();

        AppLogger.info('تم حذف البانر: $bannerId');
        return true;
      }

      _setError('فشل حذف البانر');
      return false;
    } catch (e) {
      _setError('فشل حذف البانر: ${e.toString()}');
      AppLogger.error('خطأ في حذف البانر', e);
      return false;
    }
  }

  /// حذف عدة بانرات (Admin فقط)
  /// ⚠️ يتطلب: المستخدم الحالي يجب أن يكون Admin
  Future<bool> deleteBanners(List<String> bannerIds) async {
    _clearError();

    try {
      final deletedCount = await BannerService.deleteBanners(bannerIds);

      if (deletedCount > 0) {
        _banners.removeWhere((b) => bannerIds.contains(b.id));
        notifyListeners();

        AppLogger.info('تم حذف $deletedCount من ${bannerIds.length} بانر');
        return true;
      }

      _setError('فشل حذف البانرات');
      return false;
    } catch (e) {
      _setError('فشل حذف البانرات: ${e.toString()}');
      AppLogger.error('خطأ في حذف البانرات', e);
      return false;
    }
  }

  // ================================
  // عمليات فلترة وبحث
  // ================================

  /// الحصول على بانرات حسب النوع
  List<BannerModel> getBannersByType(BannerType type) {
    return _banners.where((b) => b.targetType == type).toList();
  }

  /// الحصول على بانرات حسب الموضع (استخدام النوع كموضع للتوافق)
  List<BannerModel> getBannersByPosition(BannerPosition position) {
    // تحويل الموضع إلى نوع مناسب
    BannerType? correspondingType;
    switch (position) {
      case BannerPosition.top:
        correspondingType = BannerType.promotion;
        break;
      case BannerPosition.middle:
        correspondingType = BannerType.product;
        break;
      case BannerPosition.bottom:
        correspondingType = BannerType.store;
        break;
      case BannerPosition.sidebar:
        correspondingType = BannerType.category;
        break;
    }
    return _banners.where((b) => b.targetType == correspondingType).toList();
  }

  /// البحث في البانرات
  List<BannerModel> searchBanners(String query) {
    if (query.isEmpty) return _banners;

    final lowerQuery = query.toLowerCase();
    return _banners.where((banner) {
      return banner.title.toLowerCase().contains(lowerQuery) ||
          (banner.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ================================
  // عمليات مساعدة
  // ================================

  /// إعادة المحاولة بعد حدوث خطأ
  Future<void> retry() async {
    await fetchBanners();
  }

  /// تحديث البانرات (إعادة التحميل)
  Future<void> refresh() async {
    await fetchBanners();
  }

  /// الحصول على بانر من القائمة المحلية
  BannerModel? getLocalBanner(String bannerId) {
    try {
      return _banners.firstWhere((b) => b.id == bannerId);
    } catch (e) {
      return null;
    }
  }

  /// التحقق من وجود بانر
  bool hasBanner(String bannerId) {
    return _banners.any((b) => b.id == bannerId);
  }

  // ================================
  // إدارة الحالة
  // ================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    if (value != null) {
      AppLogger.error('خطأ في BannerProvider: $value');
    }
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// إعادة تعيين الحالة
  void resetState() {
    _banners = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
    AppLogger.info('تم إعادة تعيين حالة البانرات');
  }

  @override
  void dispose() {
    _banners.clear();
    super.dispose();
  }
}
