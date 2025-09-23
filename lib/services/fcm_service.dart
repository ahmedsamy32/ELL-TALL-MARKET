import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/utils/navigation_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permission for notifications
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('🔔 User granted permission: ${settings.authorizationStatus}');
    }

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('🔑 FCM Token: $token');
    }

    // Configure notification channels for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _configureAndroidChannels();
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Listen to FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _isInitialized = true;
  }

  Future<void> _configureAndroidChannels() async {
    // إعداد قنوات الإشعارات للأندرويد
    const defaultChannel = AndroidNotificationChannel(
      'default_channel',
      'الإشعارات العامة',
      description: 'قناة الإشعارات الافتراضية للتطبيق',
      importance: Importance.high,
    );

    const ordersChannel = AndroidNotificationChannel(
      'orders_channel',
      'إشعارات الطلبات',
      description: 'إشعارات خاصة بحالة الطلبات وتحديثاتها',
      importance: Importance.max,
    );

    const chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'إشعارات المحادثات',
      description: 'إشعارات الرسائل والمحادثات',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(defaultChannel);
      await androidPlugin.createNotificationChannel(ordersChannel);
      await androidPlugin.createNotificationChannel(chatChannel);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        final payload = details.payload;
        if (payload != null) {
          final data = json.decode(payload);
          _handleNotificationTap(data);
        }
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('📩 Got a message in foreground!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Payload: ${message.data}');
    }

    // عرض الإشعار المحلي
    if (message.notification != null) {
      final androidDetails = AndroidNotificationDetails(
        message.data['channel'] ?? 'default_channel',
        message.data['channel_name'] ?? 'الإشعارات العامة',
        channelDescription: 'إشعارات التطبيق',
        importance: Importance.max,
        priority: Priority.high,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        notificationDetails,
        payload: json.encode(message.data),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 Notification opened app from background state!');
      print('Data: ${message.data}');
    }
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // التعامل مع الضغط على الإشعار حسب نوعه
    final type = data['type'];
    final id = data['id'];

    if (id == null) return;

    switch (type) {
      case 'order':
        // التنقل لصفحة تفاصيل الطلب
        NavigationService.navigateTo('/orders/$id');
        break;
      case 'chat':
        // التنقل لصفحة المحادثة
        NavigationService.navigateTo('/chat/$id');
        break;
      case 'promo':
        // التنقل لصفحة العرض
        NavigationService.navigateTo('/promotions/$id');
        break;
    }
  }

  // تسجيل توكن الجهاز في Supabase
  Future<void> saveTokenToDatabase(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final deviceInfo = {
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'last_used': DateTime.now().toIso8601String(),
      };

      // حفظ التوكن في جدول device_tokens
      await _supabase
          .from('device_tokens')
          .upsert(deviceInfo, onConflict: 'token');

      if (kDebugMode) {
        print('✅ FCM token saved to database for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving FCM token to database: $e');
      }
    }
  }

  // إلغاء تسجيل التوكن من Supabase
  Future<void> deleteToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // حذف التوكن من جدول device_tokens
      await _supabase.from('device_tokens').delete().eq('token', token);

      // حذف التوكن من Firebase
      await _firebaseMessaging.deleteToken();

      if (kDebugMode) {
        print('✅ FCM token deleted from database');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting FCM token: $e');
      }
    }
  }

  // تحديث آخر استخدام للتوكن
  Future<void> updateTokenLastUsed(String token) async {
    try {
      await _supabase
          .from('device_tokens')
          .update({'last_used': DateTime.now().toIso8601String()})
          .eq('token', token);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating token last used: $e');
      }
    }
  }
}

// معالج رسائل FCM في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('📩 Handling a background message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Payload: ${message.data}');
  }
}
