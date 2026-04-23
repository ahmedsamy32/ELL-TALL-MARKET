import 'package:geocoding/geocoding.dart';
import 'package:ell_tall_market/core/logger.dart';

/// 🏠 أدوات مشتركة لمعالجة العناوين
///
/// تم استخراجها من الملفات المكررة:
/// - advanced_map_screen.dart
/// - main_navigation.dart
/// - google_maps_api_service.dart
/// - address_service.dart

class AddressUtils {
  AddressUtils._();

  /// إزالة Plus Code من بداية النص
  /// مثال: "HQ5J+JV8، القاهرة" → "القاهرة"
  static String stripLeadingPlusCode(String input) {
    final s = input.trim();
    return s.replaceFirst(
      RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}\s*(?:,|،)?\s*'),
      '',
    );
  }

  /// تنظيف والتحقق من صحة نص العنوان
  ///
  /// يزيل Plus Codes والرموز غير المفيدة وأرقام البريد
  /// يعيد null إذا كان النص غير صالح
  static String? cleanAndValidate(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    var cleaned = stripLeadingPlusCode(text).trim();

    // ❌ رفض Plus Codes (مثل: 7PPR+J3J)
    if (RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}$').hasMatch(cleaned)) {
      return null;
    }

    // 🧹 إزالة أرقام البريد/الضوضاء
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?<![0-9\u0660-\u0669])[0-9\u0660-\u0669]{5,7}(?![0-9\u0660-\u0669])',
      ),
      '',
    );

    // 🧹 توحيد الفواصل والمسافات
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*(،|,)\s*'), '، ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'(،\s*){2,}'), '، ')
        .trim();

    // ❌ رفض النصوص التي تحتوي على رموز غريبة فقط
    if (RegExp(r'^[^\u0600-\u06FFa-zA-Z\s]+$').hasMatch(cleaned)) {
      return null;
    }

    // ❌ رفض النصوص القصيرة جداً
    if (cleaned.length < 2) return null;

    // ❌ رفض الأرقام فقط
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return null;

    // ❌ رفض "Unnamed Road" وما شابه
    final lower = cleaned.toLowerCase();
    if (lower == 'unnamed road' ||
        lower == 'unnamed' ||
        cleaned == 'طريق بدون اسم') {
      return null;
    }

    return cleaned;
  }

  /// توحيد نص لإزالة التكرارات
  ///
  /// يزيل البادئات الإدارية ويوحد الفواصل والمسافات
  static String canonicalForDedup(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    // إزالة التطويل العربي
    s = s.replaceAll('\u0640', '');

    // إزالة البادئات الإدارية
    s = s
        .replaceFirst(RegExp(r'^\s*محافظة\s+'), '')
        .replaceFirst(RegExp(r'^\s*مركز\s+'), '')
        .replaceFirst(RegExp(r'^\s*مدينة\s+'), '')
        .replaceFirst(RegExp(r'^\s*قرية\s+'), '')
        .replaceFirst(RegExp(r'^\s*حي\s+'), '');

    // توحيد الفواصل والمسافات
    s = s
        .replaceAll(RegExp(r'[\-–—‑]+'), ' ')
        .replaceAll(RegExp(r'\s*(،|,)\s*'), ' ')
        .replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    return s;
  }

  /// بناء عنوان عرض مع إزالة التكرارات
  ///
  /// يأخذ أجزاء العنوان ويدمجها بدون تكرار
  static String composeDisplayAddress({
    required String? governorate,
    required String? city,
    required String? district,
    required String? street,
    required String fallback,
    int maxParts = 4,
  }) {
    final parts = <String>[];

    void add(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      final cv = canonicalForDedup(v);
      if (cv.isEmpty) return;
      for (final p in parts) {
        final cp = canonicalForDedup(p);
        if (cp == cv || cp.contains(cv)) return;
      }
      parts.add(v);
    }

    // الأكثر تحديداً أولاً
    add(street);
    add(district);
    add(city);
    add(governorate);

    final displayParts = parts.take(maxParts).toList(growable: false);
    return displayParts.isNotEmpty ? displayParts.join('، ') : fallback;
  }

  /// Fallback: تحويل إحداثيات لعنوان باستخدام geocoding package
  ///
  /// يُستخدم كبديل لما Google Maps API يفشل
  static Future<String?> fallbackAddressFromPlacemark(
    double lat,
    double lng, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng).timeout(
        timeout,
        onTimeout: () {
          AppLogger.warning('⏱️ Placemark timeout after ${timeout.inSeconds}s');
          return <Placemark>[];
        },
      );
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final parts = <String>[];

      void add(String? v) {
        final cleaned = cleanAndValidate(v);
        if (cleaned == null) return;
        final cv = canonicalForDedup(cleaned);
        if (cv.isEmpty) return;
        for (final p in parts) {
          final cp = canonicalForDedup(p);
          if (cp == cv || cp.contains(cv) || cv.contains(cp)) return;
        }
        parts.add(cleaned);
      }

      add(placemark.thoroughfare);
      add(placemark.street);
      add(placemark.subLocality);
      add(placemark.locality);
      add(placemark.administrativeArea);

      const maxDisplayParts = 4;
      final displayParts = parts.take(maxDisplayParts).toList(growable: false);
      return displayParts.isEmpty ? 'موقع محدد' : displayParts.join('، ');
    } catch (e) {
      AppLogger.warning('❌ Fallback placemark error: $e');
      return null;
    }
  }

  /// إضافة قيمة لقائمة أجزاء العنوان مع تجنب التكرار
  static void addDeduplicated(List<String> parts, String? value) {
    final cleaned = cleanAndValidate(value);
    if (cleaned == null) return;
    final cv = canonicalForDedup(cleaned);
    if (cv.isEmpty) return;
    for (final p in parts) {
      final cp = canonicalForDedup(p);
      if (cp == cv || cp.contains(cv) || cv.contains(cp)) return;
    }
    parts.add(cleaned);
  }
}
