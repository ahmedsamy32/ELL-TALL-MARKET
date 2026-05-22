import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'notification_service.dart';

/// Admin Notification Service
/// Handles notifications specifically for admin-related activities
class AdminNotificationService {
  final NotificationServiceEnhanced _notifications =
      NotificationServiceEnhanced.instance;

  /// Notify admin of new financial transaction
  Future<void> notifyAdminOfTransaction({
    required String storeId,
    required String transactionId,
    required String transactionType,
    required double amount,
  }) async {
    try {
      final storeName = await _getStoreName(storeId);
      await _notifications.notifyAdminOfTransaction(
        storeId: storeId,
        storeName: storeName,
        transactionId: transactionId,
        transactionType: transactionType,
        amount: amount,
      );
    } catch (e) {
      AppLogger.error('خطأ في إرسال إشعار المعاملة المالية للمدير', e);
    }
  }

  /// Notify admin of new order
  Future<void> notifyAdminOfNewOrder({
    required String orderId,
    required String storeId,
    required double totalAmount,
  }) async {
    try {
      final storeName = await _getStoreName(storeId);
      await _notifications.notifyAdminOfNewOrder(
        orderId: orderId,
        storeName: storeName,
        totalAmount: totalAmount,
      );
    } catch (e) {
      AppLogger.error('خطأ في إرسال إشعار الطلب الجديد للمدير', e);
    }
  }

  /// Notify admin of store registration
  Future<void> notifyAdminOfStoreRegistration({
    required String storeId,
    required String storeName,
    required String ownerName,
  }) async {
    try {
      await _notifications.notifyAdminOfStoreRegistration(
        storeId: storeId,
        storeName: storeName,
        ownerName: ownerName,
      );
    } catch (e) {
      AppLogger.error('خطأ في إرسال إشعار تسجيل المتجر للمدير', e);
    }
  }

  /// Notify admin of system issue
  Future<void> notifyAdminOfSystemIssue({
    required String issueType,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _notifications.notifyAdminOfSystemIssue(
        issueType: issueType,
        description: description,
        additionalData: additionalData,
      );
    } catch (e) {
      AppLogger.error('خطأ في إرسال إشعار مشكلة النظام للمدير', e);
    }
  }

  /// Get all admin notifications
  Future<List<Map<String, dynamic>>> getAdminNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    AppLogger.warning('⚠️ getAdminNotifications uses notifications table now');
    return [];
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    AppLogger.warning('⚠️ markNotificationAsRead deprecated for admins');
    return false;
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    AppLogger.warning('⚠️ markAllNotificationsAsRead deprecated for admins');
    return false;
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    AppLogger.warning('⚠️ getUnreadNotificationsCount deprecated for admins');
    return 0;
  }

  /// Delete old notifications (older than 30 days)
  Future<bool> cleanupOldNotifications() async {
    AppLogger.warning('⚠️ cleanupOldNotifications deprecated for admins');
    return false;
  }

  Future<String> _getStoreName(String storeId) async {
    try {
      final response = await Supabase.instance.client
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();
      return response?['name'] as String? ?? 'متجر غير معروف';
    } catch (e) {
      AppLogger.warning('⚠️ Failed to fetch store name', e);
      return 'متجر غير معروف';
    }
  }
}
