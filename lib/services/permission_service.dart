import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// خدمة مركزية لإدارة أذونات الوصول للملفات والصور والكاميرا
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// التحقق من إصدار Android
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('❌ فشل الحصول على إصدار Android: $e');
      return 0;
    }
  }

  /// طلب إذن الكاميرا
  Future<PermissionResult> requestCameraPermission() async {
    if (kIsWeb) {
      return PermissionResult(granted: true, permanentlyDenied: false);
    }

    try {
      final status = await Permission.camera.request();

      if (status.isGranted) {
        return PermissionResult(granted: true, permanentlyDenied: false);
      } else if (status.isPermanentlyDenied) {
        return PermissionResult(
          granted: false,
          permanentlyDenied: true,
          message: 'تم رفض إذن الكاميرا بشكل دائم. الرجاء تفعيله من الإعدادات.',
        );
      } else {
        return PermissionResult(
          granted: false,
          permanentlyDenied: false,
          message: 'يجب منح إذن الكاميرا لالتقاط الصور.',
        );
      }
    } catch (e) {
      debugPrint('❌ خطأ في طلب إذن الكاميرا: $e');
      return PermissionResult(
        granted: false,
        permanentlyDenied: false,
        message: 'حدث خطأ أثناء طلب إذن الكاميرا.',
      );
    }
  }

  /// طلب إذن المعرض (الصور)
  Future<PermissionResult> requestGalleryPermission() async {
    if (kIsWeb) {
      return PermissionResult(granted: true, permanentlyDenied: false);
    }

    try {
      Permission permission;

      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();

        // Android 13+ (API 33+) - استخدام الأذونات الجديدة
        if (androidVersion >= 33) {
          permission = Permission.photos;
        } else {
          permission = Permission.storage;
        }
      } else if (Platform.isIOS) {
        permission = Permission.photos;
      } else {
        // For other platforms, assume granted
        return PermissionResult(granted: true, permanentlyDenied: false);
      }

      final status = await permission.request();

      if (status.isGranted || status.isLimited) {
        return PermissionResult(granted: true, permanentlyDenied: false);
      } else if (status.isPermanentlyDenied) {
        return PermissionResult(
          granted: false,
          permanentlyDenied: true,
          message:
              'تم رفض إذن الوصول للصور بشكل دائم. الرجاء تفعيله من الإعدادات.',
        );
      } else {
        return PermissionResult(
          granted: false,
          permanentlyDenied: false,
          message: 'يجب منح إذن الوصول للصور لاختيار الصور من المعرض.',
        );
      }
    } catch (e) {
      debugPrint('❌ خطأ في طلب إذن المعرض: $e');
      return PermissionResult(
        granted: false,
        permanentlyDenied: false,
        message: 'حدث خطأ أثناء طلب إذن الوصول للصور.',
      );
    }
  }

  /// طلب إذن الوصول للملفات
  Future<PermissionResult> requestStoragePermission() async {
    if (kIsWeb) {
      return PermissionResult(granted: true, permanentlyDenied: false);
    }

    try {
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();

        // Android 13+ لا يحتاج إذن storage للوصول للملفات عبر file picker
        if (androidVersion >= 33) {
          return PermissionResult(granted: true, permanentlyDenied: false);
        }

        // Android 12 وأقل
        final status = await Permission.storage.request();

        if (status.isGranted) {
          return PermissionResult(granted: true, permanentlyDenied: false);
        } else if (status.isPermanentlyDenied) {
          return PermissionResult(
            granted: false,
            permanentlyDenied: true,
            message:
                'تم رفض إذن الوصول للتخزين بشكل دائم. الرجاء تفعيله من الإعدادات.',
          );
        } else {
          return PermissionResult(
            granted: false,
            permanentlyDenied: false,
            message: 'يجب منح إذن الوصول للتخزين لاختيار الملفات.',
          );
        }
      } else if (Platform.isIOS) {
        // iOS لا يحتاج إذن storage منفصل
        return PermissionResult(granted: true, permanentlyDenied: false);
      } else {
        return PermissionResult(granted: true, permanentlyDenied: false);
      }
    } catch (e) {
      debugPrint('❌ خطأ في طلب إذن التخزين: $e');
      return PermissionResult(
        granted: false,
        permanentlyDenied: false,
        message: 'حدث خطأ أثناء طلب إذن الوصول للتخزين.',
      );
    }
  }

  /// التحقق من حالة إذن معين بدون طلبه
  Future<PermissionStatus> checkPermission(Permission permission) async {
    if (kIsWeb) return PermissionStatus.granted;

    try {
      return await permission.status;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من حالة الإذن: $e');
      return PermissionStatus.denied;
    }
  }

  /// فتح إعدادات التطبيق
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ خطأ في فتح إعدادات التطبيق: $e');
      return false;
    }
  }

  /// طلب جميع الأذونات المطلوبة للوصول للصور (كاميرا + معرض)
  Future<PermissionResult> requestImagePermissions({
    required bool useCamera,
    required bool useGallery,
  }) async {
    if (kIsWeb) {
      return PermissionResult(granted: true, permanentlyDenied: false);
    }

    final List<PermissionResult> results = [];

    if (useCamera) {
      final cameraResult = await requestCameraPermission();
      results.add(cameraResult);
      if (!cameraResult.granted) return cameraResult;
    }

    if (useGallery) {
      final galleryResult = await requestGalleryPermission();
      results.add(galleryResult);
      if (!galleryResult.granted) return galleryResult;
    }

    return PermissionResult(granted: true, permanentlyDenied: false);
  }
}

/// نتيجة طلب الإذن
class PermissionResult {
  final bool granted;
  final bool permanentlyDenied;
  final String? message;

  PermissionResult({
    required this.granted,
    required this.permanentlyDenied,
    this.message,
  });

  bool get isDenied => !granted && !permanentlyDenied;
}
