import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ell_tall_market/core/logger.dart';

class CaptainContactUtils {
  CaptainContactUtils._();

  static Future<void> callPhone(
    BuildContext context,
    String? phone, {
    String unavailableMessage = 'رقم الهاتف غير متوفر',
  }) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إجراء المكالمة على هذا الجهاز')),
        );
      }
    } catch (e) {
      AppLogger.error('فشل إجراء مكالمة', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء محاولة الاتصال')),
      );
    }
  }

  static Future<void> sendSms(
    BuildContext context,
    String? phone, {
    String unavailableMessage = 'رقم الهاتف غير متوفر للمراسلة',
  }) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
      return;
    }

    final uri = Uri(scheme: 'sms', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الرسائل')));
      }
    } catch (e) {
      AppLogger.error('فشل فتح الرسائل', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الرسائل')));
    }
  }

  static Future<void> openMapByCoordinates(
    BuildContext context,
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await _openMapUri(context, url);
  }

  static Future<void> openMapByAddress(
    BuildContext context,
    String address,
  ) async {
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    await _openMapUri(context, url);
  }

  static Future<void> _openMapUri(BuildContext context, Uri url) async {
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
      }
    } catch (e) {
      AppLogger.error('فشل فتح الخرائط', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
    }
  }
}
