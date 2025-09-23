import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/notification_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    // طلب إذن الإشعارات
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('تم منح إذن الإشعارات');
    }

    // الحصول على token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      await _saveDeviceToken(token);
    }

    // التعامل مع الإشعارات في الخلفية
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  Future<void> _saveDeviceToken(String token) async {
    try {
      await _supabase
          .from('device_tokens')
          .upsert({
            'token': token,
            'user_id': _supabase.auth.currentUser?.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('فشل حفظ token الجهاز: ${e.toString()}');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('تم استقبال إشعار في الواجهة: ${message.notification?.title}');
    // معالجة الإشعار في الواجهة
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('تم فتح التطبيق من خلال إشعار: ${message.notification?.title}');
    // معالجة الإشعار عند فتح التطبيق
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
  }) async {
    try {
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        message: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
        actionUrl: actionUrl,
        imageUrl: imageUrl,
      );

      await _supabase
          .from('notifications')
          .insert(notification.toJson());

      await _sendPushNotification(
        userId: userId,
        title: title,
        body: message,
        data: data,
      );
    } catch (e) {
      print('فشل إرسال الإشعار: ${e.toString()}');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      final list = response as List;
      return list.length;
    } catch (e) {
      throw Exception('فشل الحصول على عدد الإشعارات غير المقروءة: ${e.toString()}');
    }
  }

  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _supabase
          .from('device_tokens')
          .select('token')
          .eq('user_id', userId);

      final tokens = response as List;
      if (tokens.isNotEmpty) {
        // TODO: تنفيذ إرسال إشعارات FCM باستخدام Edge Functions
        // سيتم التنفيذ عندما تكون Edge Function جاهزة
      }
    } catch (e) {
      print('فشل إرسال إشعار push: ${e.toString()}');
    }
  }

  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((doc) => NotificationModel.fromJson(doc))
          .toList();
    } catch (e) {
      throw Exception('فشل تحميل الإشعارات: ${e.toString()}');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('فشل تحديث حالة الإشعار: ${e.toString()}');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('فشل تحديث جميع الإشعارات: ${e.toString()}');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('فشل حذف الإشعار: ${e.toString()}');
    }
  }
}