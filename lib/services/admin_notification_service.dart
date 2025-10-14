import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// Admin Notification Service
/// Handles notifications specifically for admin-related activities
class AdminNotificationService {
  final _supabase = SupabaseConfig.client;

  /// Notify admin of new financial transaction
  Future<void> notifyAdminOfTransaction({
    required String storeId,
    required String transactionId,
    required String transactionType,
    required double amount,
  }) async {
    try {
      // Get store information
      final storeResponse = await _supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .single();

      final storeName = storeResponse['name'] ?? 'متجر غير معروف';

      // Create admin notification
      await _supabase.from('admin_notifications').insert({
        'type': 'financial_transaction',
        'title': 'معاملة مالية جديدة',
        'message':
            'تم تسجيل $transactionType بقيمة $amount ريال للمتجر $storeName',
        'data': {
          'store_id': storeId,
          'transaction_id': transactionId,
          'transaction_type': transactionType,
          'amount': amount,
          'store_name': storeName,
        },
        'is_read': false,
        'priority': 'medium',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('تم إرسال إشعار للمدير بشأن المعاملة المالية');
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار المعاملة المالية للمدير: $e');
    }
  }

  /// Notify admin of new order
  Future<void> notifyAdminOfNewOrder({
    required String orderId,
    required String storeId,
    required double totalAmount,
  }) async {
    try {
      // Get store information
      final storeResponse = await _supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .single();

      final storeName = storeResponse['name'] ?? 'متجر غير معروف';

      // Create admin notification
      await _supabase.from('admin_notifications').insert({
        'type': 'new_order',
        'title': 'طلب جديد',
        'message':
            'تم استلام طلب جديد بقيمة $totalAmount ريال من المتجر $storeName',
        'data': {
          'order_id': orderId,
          'store_id': storeId,
          'total_amount': totalAmount,
          'store_name': storeName,
        },
        'is_read': false,
        'priority': 'high',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('تم إرسال إشعار للمدير بشأن الطلب الجديد');
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار الطلب الجديد للمدير: $e');
    }
  }

  /// Notify admin of store registration
  Future<void> notifyAdminOfStoreRegistration({
    required String storeId,
    required String storeName,
    required String ownerName,
  }) async {
    try {
      // Create admin notification
      await _supabase.from('admin_notifications').insert({
        'type': 'store_registration',
        'title': 'تسجيل متجر جديد',
        'message': 'تم تسجيل متجر جديد: $storeName بواسطة $ownerName',
        'data': {
          'store_id': storeId,
          'store_name': storeName,
          'owner_name': ownerName,
        },
        'is_read': false,
        'priority': 'high',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('تم إرسال إشعار للمدير بشأن تسجيل المتجر الجديد');
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار تسجيل المتجر للمدير: $e');
    }
  }

  /// Notify admin of system issue
  Future<void> notifyAdminOfSystemIssue({
    required String issueType,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create admin notification
      await _supabase.from('admin_notifications').insert({
        'type': 'system_issue',
        'title': 'مشكلة في النظام',
        'message': '$issueType: $description',
        'data': {
          'issue_type': issueType,
          'description': description,
          'additional_data': additionalData,
        },
        'is_read': false,
        'priority': 'critical',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('تم إرسال إشعار للمدير بشأن مشكلة النظام');
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار مشكلة النظام للمدير: $e');
    }
  }

  /// Get all admin notifications
  Future<List<Map<String, dynamic>>> getAdminNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      dynamic query = _supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('خطأ في جلب إشعارات المدير: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('admin_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      return true;
    } catch (e) {
      debugPrint('خطأ في تحديث حالة الإشعار: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      await _supabase
          .from('admin_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('is_read', false);

      return true;
    } catch (e) {
      debugPrint('خطأ في تحديث جميع الإشعارات: $e');
      return false;
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    try {
      final response = await _supabase
          .from('admin_notifications')
          .select()
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('خطأ في جلب عدد الإشعارات غير المقروءة: $e');
      return 0;
    }
  }

  /// Delete old notifications (older than 30 days)
  Future<bool> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      await _supabase
          .from('admin_notifications')
          .delete()
          .lt('created_at', thirtyDaysAgo);

      debugPrint('تم حذف الإشعارات القديمة بنجاح');
      return true;
    } catch (e) {
      debugPrint('خطأ في حذف الإشعارات القديمة: $e');
      return false;
    }
  }
}
