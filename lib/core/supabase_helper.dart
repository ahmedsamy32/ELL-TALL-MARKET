import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseHelper {
  static final SupabaseHelper _instance = SupabaseHelper._internal();
  static final _supabase = Supabase.instance.client;

  factory SupabaseHelper() {
    return _instance;
  }

  SupabaseHelper._internal();

  static SupabaseHelper get instance => _instance;

  SupabaseClient get client => _supabase;

  // ===== التحقق من وجود المستخدم =====
  static Future<bool> isUserExists(String email) async {
    try {
      final result = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking user existence: $e');
      return false;
    }
  }

  // ===== التحقق من حالة المتجر =====
  static Future<bool> isStoreActive(String storeId) async {
    try {
      final result = await _supabase
          .from('stores')
          .select('is_active')
          .eq('id', storeId)
          .single();
      return result['is_active'] ?? false;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking store status: $e');
      return false;
    }
  }

  // ===== تحديث آخر تسجيل دخول =====
  static Future<void> updateLastLogin(String userId) async {
    try {
      await _supabase.from('profiles').update({
        'last_login': DateTime.now().toIso8601String(),
        'login_count': await _getNewLoginCount(userId),
      }).eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error updating last login: $e');
    }
  }

  static Future<int> _getNewLoginCount(String userId) async {
    try {
      final result = await _supabase
          .from('profiles')
          .select('login_count')
          .eq('id', userId)
          .single();
      return (result['login_count'] ?? 0) + 1;
    } catch (e) {
      return 1;
    }
  }

  // ===== تحديث إعدادات المستخدم =====
  static Future<void> updateUserPreferences(String userId, Map<String, dynamic> preferences) async {
    try {
      await _supabase
          .from('profiles')
          .update({'preferences': preferences})
          .eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error updating user preferences: $e');
    }
  }

  // ===== جلب إحصائيات المتجر =====
  static Future<Map<String, dynamic>> getStoreStats(String storeId) async {
    try {
      final orders = await _supabase
          .from('orders')
          .select('total_amount, status')
          .eq('store_id', storeId);

      final totalOrders = orders.length;
      final completedOrders = orders.where((o) => o['status'] == 'completed').length;
      final totalRevenue = orders.fold<double>(
        0,
        (sum, order) => sum + (order['status'] == 'completed' ? (order['total_amount'] as num).toDouble() : 0),
      );

      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'totalRevenue': totalRevenue,
        'completionRate': totalOrders > 0 ? (completedOrders / totalOrders * 100) : 0,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching store stats: $e');
      return {
        'totalOrders': 0,
        'completedOrders': 0,
        'totalRevenue': 0.0,
        'completionRate': 0.0,
      };
    }
  }

  // ===== تحديث موقع الكابتن =====
  static Future<void> updateCaptainLocation(String captainId, double lat, double lng) async {
    try {
      await _supabase.from('captain_locations').upsert({
        'captain_id': captainId,
        'lat': lat,
        'lng': lng,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error updating captain location: $e');
    }
  }

  // ===== جلب موقع الكابتن =====
  static Future<Map<String, dynamic>?> getCaptainLocation(String captainId) async {
    try {
      final result = await _supabase
          .from('captain_locations')
          .select()
          .eq('captain_id', captainId)
          .single();
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching captain location: $e');
      return null;
    }
  }

  // ===== إرسال إشعار =====
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'action': action,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error sending notification: $e');
    }
  }

  // ===== جلب الإشعارات =====
  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      final result = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  // ===== تحديث حالة قراءة الإشعار =====
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      if (kDebugMode) print('❌ Error marking notification as read: $e');
    }
  }
}
