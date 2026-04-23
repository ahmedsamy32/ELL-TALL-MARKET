import 'package:ell_tall_market/providers/location_provider.dart';

class LocationUiText {
  static const String title = 'الموقع مطلوب';

  static String message(LocationProvider locationProvider) {
    final error = (locationProvider.error ?? '').trim();

    final isDeniedForever =
        locationProvider.permissionDenied && error.contains('نهائياً');
    final isDenied = locationProvider.permissionDenied && !isDeniedForever;
    final isServiceOff = error.contains('خدمة الموقع غير مفعّلة');

    if (isDeniedForever) {
      return 'صلاحية الموقع مرفوضة نهائياً. يرجى تفعيلها من إعدادات التطبيق.';
    }

    if (isDenied) {
      return 'تم رفض صلاحية الموقع. يرجى السماح بالوصول إلى موقعك لعرض المحتوى في منطقتك.';
    }

    if (isServiceOff) {
      return 'خدمة الموقع غير مفعّلة. يرجى تفعيلها لعرض المحتوى في منطقتك.';
    }

    return 'فعّل الموقع لعرض المتاجر والمنتجات والتصنيفات المتاحة في منطقتك.';
  }

  static bool isDeniedForever(LocationProvider locationProvider) {
    final error = (locationProvider.error ?? '').trim();
    return locationProvider.permissionDenied && error.contains('نهائياً');
  }

  static bool isServiceOff(LocationProvider locationProvider) {
    final error = (locationProvider.error ?? '').trim();
    return error.contains('خدمة الموقع غير مفعّلة');
  }

  static String primaryButtonLabel(LocationProvider locationProvider) {
    return isDeniedForever(locationProvider)
        ? 'فتح إعدادات التطبيق'
        : 'تفعيل الموقع';
  }

  static String primaryButtonIconKey(LocationProvider locationProvider) {
    // Used by callers to choose an Icon; keep logic centralized.
    return isDeniedForever(locationProvider) ? 'settings' : 'my_location';
  }

  static const String secondaryButtonLabel = 'إعدادات الموقع';
}
