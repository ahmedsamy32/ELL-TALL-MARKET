import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Helpers {
  // تنسيق الأرقام مع فواصل
  static String formatNumber(double number) {
    return NumberFormat('#,##0.00').format(number);
  }

  // تنسيق التاريخ
  static String formatDate(DateTime date, {String format = 'yyyy/MM/dd'}) {
    return DateFormat(format).format(date);
  }

  // تنسيق الوقت
  static String formatTime(DateTime time, {String format = 'hh:mm a'}) {
    return DateFormat(format).format(time);
  }

  // حساب الوقت المنقضي
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'منذ $weeks أسبوع';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'منذ $months شهر';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'منذ $years سنة';
    }
  }

  // فتح رابط URL
  static Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  // فتح تطبيق الهاتف
  static Future<void> makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // فتح تطبيق الرسائل
  static Future<void> sendSMS(String phoneNumber) async {
    final uri = Uri.parse('sms:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // فتح تطبيق البريد
  static Future<void> sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // فتح موقع على الخريطة
  static Future<void> openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // نسخ النص إلى الحافظة
  static Future<void> copyToClipboard(String text, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم النسخ إلى الحافظة')));
  }

  // تحويل اللون من hex إلى Color
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // تحويل Color إلى hex
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  // توليد لون عشوائي
  static Color generateRandomColor() {
    return Color(
      (Random().nextDouble() * 0xFFFFFF).toInt(),
    ).withValues(alpha: 1.0);
  }

  // اختصار النص الطويل
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // تحويل الحرف الأول إلى كبير
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // تحويل النص إلى عنوان (كل كلمة تبدأ بحرف كبير)
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }

  // التحقق من صحة الصورة
  static bool isValidImageUrl(String url) {
    final imageRegex = RegExp(
      r'\.(jpeg|jpg|gif|png|webp|bmp)$',
      caseSensitive: false,
    );
    return imageRegex.hasMatch(url);
  }

  // التحقق من صحة الفيديو
  static bool isValidVideoUrl(String url) {
    final videoRegex = RegExp(
      r'\.(mp4|mov|avi|wmv|flv|webm)$',
      caseSensitive: false,
    );
    return videoRegex.hasMatch(url);
  }

  // الحصول على امتداد الملف
  static String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  // حساب حجم الملف بشكل مقروء
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  // تحويل الوقت إلى دقائق
  static int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  // تحويل الدقائق إلى وقت
  static String minutesToTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // حساب العمر من التاريخ
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // التحقق من أن التاريخ في المستقبل
  static bool isFutureDate(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  // التحقق من أن التاريخ في الماضي
  static bool isPastDate(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  // الحصول على أول يوم في الشهر
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // الحصول على آخر يوم في الشهر
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  // التحقق من أن النص يحتوي على أرقام فقط
  static bool isNumeric(String text) {
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }

  // التحقق من أن النص يحتوي على أحرف فقط
  static bool isAlphabetic(String text) {
    return RegExp(r'^[a-zA-Zء-ي]+$').hasMatch(text);
  }

  // التحقق من أن النص يحتوي على أحرف وأرقام فقط
  static bool isAlphanumeric(String text) {
    return RegExp(r'^[a-zA-Z0-9ء-ي]+$').hasMatch(text);
  }

  // إنشاء معرف فريد
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(9999).toString().padLeft(4, '0');
  }

  // تحويل القائمة إلى نص مفصول بفواصل
  static String listToCommaSeparated(List<String> list) {
    return list.join(', ');
  }

  // تحويل النص المفصول بفواصل إلى قائمة
  static List<String> commaSeparatedToList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // إزالة الحروف المكررة
  static String removeDuplicates(String text) {
    return text.split('').toSet().join();
  }

  // عكس النص
  static String reverseText(String text) {
    return text.split('').reversed.join();
  }

  // حساب عدد الكلمات
  static int countWords(String text) {
    if (text.isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // التحقق من أن النص هو بريد إلكتروني
  static bool isEmail(String text) {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(text);
  }

  // التحقق من أن النص هو رقم هاتف
  static bool isPhoneNumber(String text) {
    return RegExp(r'^[0-9]{10,15}$').hasMatch(text);
  }

  // التحقق من أن النص هو رابط URL
  static bool isUrl(String text) {
    return RegExp(
      r'^(http|https):\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}',
    ).hasMatch(text);
  }
}
