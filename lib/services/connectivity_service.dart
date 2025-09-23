import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static bool _isOnline = true;
  static bool get isOnline => _isOnline;

  /// فحص الاتصال بالإنترنت
  static Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (kDebugMode) {
        debugPrint(
          '🌐 Internet connection: ${_isOnline ? "Connected" : "Disconnected"}',
        );
      }
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      if (kDebugMode) {
        debugPrint('🌐 Internet connection check failed: $e');
      }
      return false;
    }
  }

  /// فحص الاتصال مع Supabase
  static Future<bool> checkSupabaseConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'oonfjaiodghxfgapdcfw.supabase.co',
      ).timeout(const Duration(seconds: 5));
      final isSupabaseReachable =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (kDebugMode) {
        debugPrint(
          '🔗 Supabase reachable: ${isSupabaseReachable ? "Yes" : "No"}',
        );
      }
      return isSupabaseReachable;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔗 Supabase connection check failed: $e');
      }
      return false;
    }
  }

  /// رسالة خطأ منظمة للمستخدم
  static String getConnectionErrorMessage() {
    return _isOnline
        ? 'مشكلة في الاتصال بالخادم. يرجى المحاولة لاحقاً.'
        : 'لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
  }

  /// رسالة حالة الاتصال
  static String getConnectionStatus() {
    return _isOnline ? 'متصل' : 'غير متصل';
  }
}
