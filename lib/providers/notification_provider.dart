import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/notification_model.dart';

class NotificationProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationsChannel;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  String? _activeRole; // الدور المحمّل حالياً (client, merchant, admin)

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  /// الحصول على الإشعارات المفلترة حسب الدور
  List<NotificationModel> getNotificationsForRole(String? role) {
    if (role == null) return _notifications;
    return _notifications.where((n) => n.targetRole == role).toList();
  }

  /// الحصول على عدد الإشعارات غير المقروءة حسب الدور
  int getUnreadCountForRole(String? role) {
    if (role == null) return _unreadCount;
    return _notifications
        .where((n) => !n.isRead && n.targetRole == role)
        .length;
  }

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

    _notificationsChannel =
        _supabase
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

  // ===== جلب إشعارات المستخدم (العميل فقط) =====
  Future<void> loadUserNotifications(
    String userId, {
    String targetRole = 'client',
  }) async {
    _activeRole = targetRole;
    _setLoading(true);
    _setError(null); // مسح الأخطاء السابقة
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('target_role', targetRole)
          .order('created_at', ascending: false);

      _notifications = (response as List)
          .map((data) => NotificationModel.fromMap(data))
          .toList();

      _updateUnreadCount();
    } catch (e) {
      AppLogger.error('❌ Error fetching notifications', e);

      // معالجة أفضل لرسائل الخطأ
      String errorMessage = 'حدث خطأ في تحميل الإشعارات';

      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        errorMessage =
            'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى';
      } else if (e.toString().contains('JWTExpiredException') ||
          e.toString().contains('Invalid')) {
        errorMessage = 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى';
      }

      _setError(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // ===== جلب إشعارات المتجر (للتجار) =====
  Future<void> loadStoreNotifications(String storeId) async {
    _activeRole = 'merchant';
    _setLoading(true);
    _setError(null);
    try {
      AppLogger.info('🏪 جلب إشعارات المتجر: $storeId');
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      _notifications = (response as List)
          .map((data) => NotificationModel.fromMap(data))
          .toList();

      AppLogger.info('✅ تم جلب ${_notifications.length} إشعار للمتجر');
      _updateUnreadCount();
    } catch (e) {
      AppLogger.error('❌ Error fetching store notifications', e);
      String errorMessage = 'حدث خطأ في تحميل الإشعارات';

      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        errorMessage =
            'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى';
      }

      _setError(errorMessage);
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
      AppLogger.error('❌ Error marking notification as read', e);
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

      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _updateUnreadCount();
    } catch (e) {
      AppLogger.error('❌ Error marking all notifications as read', e);
      _setError(e.toString());
    }
  }

  // ===== تحديث حالة قراءة كل إشعارات المتجر =====
  Future<void> markAllAsReadForStore(String storeId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('store_id', storeId)
          .eq('is_read', false);

      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error marking all store notifications as read', e);
      _setError(e.toString());
    }
  }

  // ===== حذف إشعار =====
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
    } catch (e) {
      AppLogger.error('❌ Error deleting notification', e);
      _setError(e.toString());
    }
  }

  // ===== حذف كل الإشعارات =====
  Future<void> deleteAllNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('notifications').delete().eq('user_id', userId);

      _notifications.clear();
      _updateUnreadCount();
    } catch (e) {
      AppLogger.error('❌ Error deleting all notifications', e);
      _setError(e.toString());
    }
  }

  // ===== حذف إشعارات المستخدم فقط =====
  Future<void> deleteUserNotifications(String userId) async {
    try {
      await _supabase.from('notifications').delete().eq('user_id', userId);

      _notifications.clear();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error deleting user notifications', e);
      _setError(e.toString());
    }
  }

  // ===== حذف إشعارات المتجر فقط =====
  Future<void> deleteStoreNotifications(String storeId) async {
    try {
      await _supabase.from('notifications').delete().eq('store_id', storeId);

      _notifications.clear();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error deleting store notifications', e);
      _setError(e.toString());
    }
  }

  // ===== معالجة الإشعارات في الوقت الحقيقي =====
  void _handleNewNotification(Map<String, dynamic> data) {
    final notification = NotificationModel.fromMap(data);

    // تجاهل الإشعار إذا لم يكن من نفس الدور المحمّل حالياً
    if (_activeRole != null && notification.targetRole != _activeRole) {
      AppLogger.info(
        '🔕 تجاهل إشعار realtime (role=${notification.targetRole}, active=$_activeRole)',
      );
      return;
    }

    // تجنب التكرار
    if (_notifications.any((n) => n.id == notification.id)) return;

    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  void _handleNotificationUpdate(Map<String, dynamic> data) {
    final updatedNotification = NotificationModel.fromMap(data);
    final index = _notifications.indexWhere(
      (n) => n.id == updatedNotification.id,
    );
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
