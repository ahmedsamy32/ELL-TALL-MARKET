import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ell_tall_market/core/logger.dart';

/// Location Provider لمشاركة موقع المستخدم عبر التطبيق
/// يُستخدم لفلترة المتاجر بناءً على نطاق التوصيل
class LocationProvider with ChangeNotifier {
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoading = false;
  String? _error;
  bool _permissionDenied = false;

  // Getters
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionDenied => _permissionDenied;
  bool get hasLocation => _latitude != null && _longitude != null;

  /// الحصول على الموقع الحالي
  Future<bool> getCurrentLocation() async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // التحقق من تفعيل خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'خدمة الموقع غير مفعّلة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _permissionDenied = true;
          _error = 'تم رفض صلاحية الموقع';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _error = 'صلاحية الموقع مرفوضة نهائياً. يرجى تفعيلها من الإعدادات';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // الحصول على الموقع
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _permissionDenied = false;
      _error = null;

      AppLogger.info('📍 تم تحديد الموقع: ($_latitude, $_longitude)');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديد الموقع', e);
      _error = 'فشل في تحديد الموقع';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// تعيين الموقع يدوياً (من عنوان محفوظ مثلاً)
  void setLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _address = address;
    _error = null;
    notifyListeners();
  }

  /// مسح الموقع
  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _address = null;
    _error = null;
    notifyListeners();
  }
}
