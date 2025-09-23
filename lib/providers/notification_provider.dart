import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/notification_model.dart';

class NotificationProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationsChannel;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  NotificationProvider() {
    _initRealtimeSubscription();
  }

  void _initRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsChannel = _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleNewNotification(payload.newRecord);
                break;
              case PostgresChangeEvent.update:
                _handleNotificationUpdate(payload.newRecord);
                break;
              case PostgresChangeEvent.delete:
                _handleNotificationDelete(payload.oldRecord['id']);
                break;
              default:
                break;
            }
          },
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  // ===== جلب إشعارات المستخدم =====
  Future<void> loadUserNotifications(String userId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = (response as List)
          .map((data) => NotificationModel.fromJson(data))
          .toList();

      _updateUnreadCount();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching notifications: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ===== تحديث حالة قراءة الإشعار =====
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _updateUnreadCount();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error marking notification as read: $e');
      _setError(e.toString());
    }
  }

  // ===== تحديث حالة قراءة كل الإشعارات =====
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _updateUnreadCount();
    } catch (e) {
      if (kDebugMode) print('❌ Error marking all notifications as read: $e');
      _setError(e.toString());
    }
  }

  // ===== حذف إشعار =====
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting notification: $e');
      _setError(e.toString());
    }
  }

  // ===== حذف كل الإشعارات =====
  Future<void> deleteAllNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);

      _notifications.clear();
      _updateUnreadCount();
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting all notifications: $e');
      _setError(e.toString());
    }
  }

  // ===== معالجة الإشعارات في الوقت الحقيقي =====
  void _handleNewNotification(Map<String, dynamic> data) {
    final notification = NotificationModel.fromJson(data);
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  void _handleNotificationUpdate(Map<String, dynamic> data) {
    final updatedNotification = NotificationModel.fromJson(data);
    final index = _notifications.indexWhere((n) => n.id == updatedNotification.id);
    if (index != -1) {
      _notifications[index] = updatedNotification;
      _updateUnreadCount();
    }
  }

  void _handleNotificationDelete(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }
}
