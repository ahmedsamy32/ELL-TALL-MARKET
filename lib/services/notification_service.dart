import 'dart:convert';
// Removed dart:io for Web compatibility
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:uuid/uuid.dart';
import '../core/logger.dart';
import '../utils/navigation_service.dart';
import '../utils/app_routes.dart';

/// Enhanced NotificationService with comprehensive smart features
class NotificationServiceEnhanced {
  static const String _logTag = '🔔 NotificationService';

  // ===== Singleton Pattern =====
  static NotificationServiceEnhanced? _instance;
  static NotificationServiceEnhanced get instance =>
      _instance ??= NotificationServiceEnhanced._internal();

  NotificationServiceEnhanced._internal();

  // ===== Core Dependencies =====
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  // ===== State Management =====
  bool _isInitialized = false;
  String? _fcmToken;
  Map<String, dynamic> _userPreferences = {};
  final List<String> _subscribedTopics = [];

  /// Track roles that have been registered for this device
  final Set<String> _activeRoles = {};

  /// Expose FCM token availability
  String? get fcmToken => _fcmToken;

  /// حماية من تكرار الإشعارات - تتبع الإشعارات المعروضة مؤخراً
  final Set<String> _recentlyShownNotifications = {};
  static const int _maxRecentNotifications = 50;

  // ===== Initialization =====

  /// Initialize the notification service with comprehensive setup
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      AppLogger.info('Initializing enhanced notification service...');

      // Initialize Firebase Messaging
      await _initializeFirebaseMessaging();

      // Initialize Local Notifications
      await _initializeLocalNotifications();

      // Setup notification handlers
      await _setupNotificationHandlers();

      // Load user preferences
      await _loadUserPreferences();

      // Setup real-time listeners
      await _setupRealtimeListeners();

      // Initialize notification analytics
      await _initializeAnalytics();

      _isInitialized = true;
      AppLogger.info('Notification service initialized successfully');

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to initialize', e);
      return false;
    }
  }

  /// Initialize Firebase Messaging with advanced permissions
  Future<void> _initializeFirebaseMessaging() async {
    // Request comprehensive permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      AppLogger.info('✅ Firebase messaging permissions granted');

      // Get FCM token (save to memory only; DB save happens after auth)
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        AppLogger.info('FCM Token acquired: ${_fcmToken!.substring(0, 20)}...');
        // Try saving if user is already authenticated (e.g. app restart)
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _saveDeviceToken(_fcmToken!);
          AppLogger.info(
            'FCM Token saved to DB for already-authenticated user',
          );
        } else {
          AppLogger.info(
            'User not yet authenticated — token will be saved after login',
          );
        }
      }

      // Setup token refresh listener
      _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
    } else {
      AppLogger.warning('⚠️ Firebase messaging permissions denied');
    }
  }

  /// Initialize local notifications with platform-specific settings
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create Android notification channel (required for Android 8.0+)
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'ell_tall_market',
        'Ell Tall Market',
        description: 'إشعارات سوق التل',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      AppLogger.info('✅ Android notification channel created');
    }

    // iOS foreground notification presentation options
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Setup notification message handlers
  Future<void> _setupNotificationHandlers() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // App launched from terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleAppLaunchedFromNotification(initialMessage);
    }
  }

  // ===== Smart Notification Management =====

  /// Send smart notification with AI-powered personalization
  Future<bool> sendSmartNotification({
    required String clientId,
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    NotificationPriority priority = NotificationPriority.normal,
    DateTime? scheduledTime,
    List<String>? tags,
    String? campaignId,
    String? targetRole,
  }) async {
    try {
      AppLogger.info('Sending smart notification to client: $clientId');

      // Personalize notification content
      final personalizedContent = await _personalizeNotification(
        clientId: clientId,
        title: title,
        message: message,
        type: type,
      );

      // Check delivery preferences
      final canDeliver = await _checkDeliveryPreferences(clientId, type);
      if (!canDeliver) {
        AppLogger.warning('⚠️ Notification blocked by user preferences');
        return false;
      }

      // Create notification record
      final notification = NotificationModel(
        id: _generateNotificationId(),
        userId: clientId,
        title: personalizedContent['title'] ?? title,
        body: personalizedContent['message'] ?? message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Merge targetRole into data if provided
      final finalData = Map<String, dynamic>.from(data ?? {});
      if (targetRole != null) {
        finalData['target_role'] = targetRole;
      }

      // Save to database → DB trigger sends FCM push automatically
      // NO local notification here! The target device receives via FCM.
      await _saveNotificationToDatabase(
        notification,
        finalData,
        imageUrl,
        actionUrl,
        priority,
        tags,
        campaignId,
        targetRole: targetRole,
      );

      // Schedule if needed (future implementation)
      if (scheduledTime != null && scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(notification, scheduledTime, finalData);
      }

      // Track analytics (fail silently if RLS blocks it)
      try {
        await _trackNotificationSent(notification, campaignId);
      } catch (e) {
        AppLogger.warning('⚠️ Analytics tracking failed (RLS policy): $e');
        // Don't fail the entire notification flow
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to send smart notification', e);
      return false;
    }
  }

  /// Send bulk notifications with intelligent batching
  Future<Map<String, dynamic>> sendBulkNotifications({
    required List<String> clientIds,
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    String? campaignId,
    String? targetRole,
    int batchSize = 100,
  }) async {
    final results = <String, dynamic>{
      'total': clientIds.length,
      'sent': 0,
      'failed': 0,
      'errors': <String>[],
    };

    try {
      AppLogger.info(
        'Sending bulk notifications to ${clientIds.length} clients',
      );

      // Process in batches
      for (int i = 0; i < clientIds.length; i += batchSize) {
        final batch = clientIds.skip(i).take(batchSize).toList();

        final batchResults = await Future.wait(
          batch.map(
            (clientId) => sendSmartNotification(
              clientId: clientId,
              title: title,
              message: message,
              type: type,
              data: data,
              imageUrl: imageUrl,
              actionUrl: actionUrl,
              campaignId: campaignId,
              targetRole: targetRole,
            ),
          ),
        );

        // Update results
        for (int j = 0; j < batchResults.length; j++) {
          if (batchResults[j]) {
            results['sent']++;
          } else {
            results['failed']++;
            results['errors'].add('Failed to send to client: ${batch[j]}');
          }
        }

        // Prevent rate limiting
        if (i + batchSize < clientIds.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      AppLogger.info(
        '✅ Bulk notifications completed: ${results['sent']} sent, ${results['failed']} failed',
      );
    } catch (e) {
      AppLogger.error('❌ Bulk notification error', e);
      results['errors'].add('Bulk operation failed: $e');
    }

    return results;
  }

  /// Send notification campaign with A/B testing
  Future<String> createNotificationCampaign({
    required String name,
    required List<String> targetClientIds,
    required String title,
    required String message,
    NotificationType type = NotificationType.promotion,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    DateTime? scheduledTime,
    Map<String, dynamic>? abTestVariants,
    List<String>? segmentationRules,
  }) async {
    try {
      final campaignId = _generateCampaignId();

      AppLogger.info('Creating notification campaign: $name ($campaignId)');

      // Create campaign record
      await _supabase.from('notification_campaigns').insert({
        'id': campaignId,
        'name': name,
        'type': type.value,
        'title': title,
        'message': message,
        'target_count': targetClientIds.length,
        'scheduled_time': scheduledTime?.toIso8601String(),
        'status': 'created',
        'created_at': DateTime.now().toIso8601String(),
        'data': data != null ? jsonEncode(data) : null,
        'image_url': imageUrl,
        'action_url': actionUrl,
        'ab_test_variants': abTestVariants != null
            ? jsonEncode(abTestVariants)
            : null,
        'segmentation_rules': segmentationRules != null
            ? jsonEncode(segmentationRules)
            : null,
      });

      // Process A/B testing if enabled
      final clientGroups = abTestVariants != null
          ? _splitClientsForABTesting(targetClientIds, abTestVariants)
          : {'default': targetClientIds};

      // Schedule campaign execution
      if (scheduledTime != null && scheduledTime.isAfter(DateTime.now())) {
        await _scheduleCampaign(campaignId, clientGroups, scheduledTime);
      } else {
        await _executeCampaign(campaignId, clientGroups);
      }

      return campaignId;
    } catch (e) {
      AppLogger.error('❌ Failed to create campaign', e);
      rethrow;
    }
  }

  // ===== Smart Features & AI =====

  /// Personalize notification content using AI analysis
  Future<Map<String, String>> _personalizeNotification({
    required String clientId,
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    try {
      // Get user behavior data
      final userData = await _getUserBehaviorData(clientId);
      if (userData.isEmpty) return {'title': title, 'message': message};

      // Apply personalization rules
      String personalizedTitle = title;
      String personalizedMessage = message;

      // Personalize based on user preferences and behavior
      if (userData['preferred_language'] == 'en') {
        // Could add English translations here
      }

      // Add user-specific content
      if (userData['name'] != null && userData['name'].isNotEmpty) {
        if (type == NotificationType.promotion) {
          personalizedTitle = 'مرحباً ${userData['name']}، $title';
        }
      }

      // Time-based personalization
      final hour = DateTime.now().hour;
      if (type == NotificationType.promotion) {
        if (hour < 12) {
          personalizedMessage = 'صباح الخير! $message';
        } else if (hour < 18) {
          personalizedMessage = 'مساء الخير! $message';
        } else {
          personalizedMessage = 'مساء النور! $message';
        }
      }

      // Behavior-based personalization
      final lastOrderDays = userData['days_since_last_order'] as int? ?? 30;
      if (type == NotificationType.promotion && lastOrderDays > 7) {
        personalizedMessage += ' عرض خاص للعملاء المميزين!';
      }

      return {'title': personalizedTitle, 'message': personalizedMessage};
    } catch (e) {
      AppLogger.warning('⚠️ Personalization failed', e);
      return {'title': title, 'message': message};
    }
  }

  /// Get smart notification recommendations
  Future<List<Map<String, dynamic>>> getSmartRecommendations(
    String clientId,
  ) async {
    try {
      AppLogger.info('Getting smart recommendations for client: $clientId');

      final recommendations = <Map<String, dynamic>>[];

      // Get user behavior analysis
      final behaviorData = await _analyzeUserBehavior(clientId);

      // Recommend based on order history
      if (behaviorData['days_since_last_order'] > 14) {
        recommendations.add({
          'type': 'comeback',
          'title': 'نشتاق لك! 💙',
          'message': 'عروض خاصة في انتظارك، اكتشفها الآن',
          'priority': 'high',
          'suggested_time': _getBestDeliveryTime(clientId),
        });
      }

      // Recommend based on browsing behavior
      if (behaviorData['favorite_category'] != null) {
        recommendations.add({
          'type': 'category_update',
          'title': 'منتجات جديدة في ${behaviorData['favorite_category']}',
          'message': 'اكتشف أحدث المنتجات في قسمك المفضل',
          'priority': 'medium',
          'category': behaviorData['favorite_category'],
        });
      }

      // Recommend based on cart abandonment
      final abandonedCart = await _checkAbandonedCart(clientId);
      if (abandonedCart['has_items'] == true) {
        recommendations.add({
          'type': 'cart_reminder',
          'title': 'لا تنسى مشترياتك! 🛒',
          'message': '${abandonedCart['items_count']} منتج في انتظارك',
          'priority': 'high',
          'action_url': '/cart',
        });
      }

      // Weather-based recommendations
      final weatherRecommendation = await _getWeatherBasedRecommendation(
        clientId,
      );
      if (weatherRecommendation != null) {
        recommendations.add(weatherRecommendation);
      }

      // Special occasions recommendations
      final occasionRecommendation = await _getOccasionBasedRecommendation(
        clientId,
      );
      if (occasionRecommendation != null) {
        recommendations.add(occasionRecommendation);
      }

      return recommendations;
    } catch (e) {
      AppLogger.error('❌ Failed to get recommendations', e);
      return [];
    }
  }

  /// Analyze notification performance and user engagement
  Future<Map<String, dynamic>> analyzeNotificationPerformance({
    String? campaignId,
    DateTime? startDate,
    DateTime? endDate,
    NotificationType? type,
  }) async {
    try {
      AppLogger.info('Analyzing notification performance...');

      final query = _supabase.from('notification_analytics').select('*');

      if (campaignId != null) {
        query.eq('campaign_id', campaignId);
      }

      if (startDate != null) {
        query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query.lte('created_at', endDate.toIso8601String());
      }

      if (type != null) {
        query.eq('notification_type', type.value);
      }

      final analyticsData = await query;
      final analytics = analyticsData as List;

      // Calculate metrics
      final totalSent = analytics.length;
      final totalOpened = analytics.where((a) => a['opened'] == true).length;
      final totalClicked = analytics.where((a) => a['clicked'] == true).length;

      final openRate = totalSent > 0 ? (totalOpened / totalSent * 100) : 0.0;
      final clickRate = totalSent > 0 ? (totalClicked / totalSent * 100) : 0.0;
      final ctr = totalOpened > 0 ? (totalClicked / totalOpened * 100) : 0.0;

      // Engagement analysis by time
      final hourlyEngagement = <int, int>{};
      for (final item in analytics) {
        if (item['opened'] == true && item['opened_at'] != null) {
          final hour = DateTime.parse(item['opened_at']).hour;
          hourlyEngagement[hour] = (hourlyEngagement[hour] ?? 0) + 1;
        }
      }

      // Device analysis
      final deviceStats = <String, int>{};
      for (final item in analytics) {
        final device = item['device_type'] ?? 'unknown';
        deviceStats[device] = (deviceStats[device] ?? 0) + 1;
      }

      return {
        'summary': {
          'total_sent': totalSent,
          'total_opened': totalOpened,
          'total_clicked': totalClicked,
          'open_rate': double.parse(openRate.toStringAsFixed(2)),
          'click_rate': double.parse(clickRate.toStringAsFixed(2)),
          'click_through_rate': double.parse(ctr.toStringAsFixed(2)),
        },
        'engagement': {
          'hourly_distribution': hourlyEngagement,
          'best_hour': hourlyEngagement.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
        },
        'devices': deviceStats,
        'trends': await _calculateEngagementTrends(analytics),
      };
    } catch (e) {
      AppLogger.error('❌ Failed to analyze performance', e);
      return {};
    }
  }

  // ===== Advanced Notification Features =====

  /// Send location-based notification
  Future<bool> sendLocationBasedNotification({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String title,
    required String message,
    NotificationType type = NotificationType.promotion,
    Map<String, dynamic>? data,
  }) async {
    try {
      AppLogger.info('Sending location-based notification...');

      // Get clients in the specified location
      final nearbyClients = await _getClientsInRadius(
        latitude,
        longitude,
        radiusKm,
      );

      if (nearbyClients.isEmpty) {
        AppLogger.info('No clients found in specified location');
        return false;
      }

      // Send to all nearby clients
      final results = await sendBulkNotifications(
        clientIds: nearbyClients,
        title: title,
        message: message,
        type: type,
        data: data,
        campaignId: _generateCampaignId(),
      );

      AppLogger.info(
        'Location-based notification sent to ${results['sent']} clients',
      );

      return results['sent'] > 0;
    } catch (e) {
      AppLogger.error('❌ Failed to send location-based notification', e);
      return false;
    }
  }

  /// Send interactive notification with action buttons
  Future<bool> sendInteractiveNotification({
    required String clientId,
    required String title,
    required String message,
    required List<NotificationAction> actions,
    NotificationType type = NotificationType.system,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      AppLogger.info('Sending interactive notification...');

      // Create notification with actions
      final notification = NotificationModel(
        id: _generateNotificationId(),
        userId: clientId,
        title: title,
        body: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Save to database with actions
      await _supabase.from('notifications').insert({
        'id': notification.id,
        'user_id': notification.userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type?.value,
        'is_read': notification.isRead,
        'created_at': notification.createdAt.toIso8601String(),
        'data': data,
      });

      // Send push notification with actions
      await _sendInteractivePushNotification(
        clientId: clientId,
        title: title,
        message: message,
        actions: actions,
        data: data,
        imageUrl: imageUrl,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to send interactive notification', e);
      return false;
    }
  }

  /// Send rich media notification
  Future<bool> sendRichMediaNotification({
    required String clientId,
    required String title,
    required String message,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    NotificationType type = NotificationType.promotion,
    Map<String, dynamic>? data,
    String? actionUrl,
  }) async {
    try {
      AppLogger.info('Sending rich media notification...');

      // Create rich notification
      final notification = NotificationModel(
        id: _generateNotificationId(),
        userId: clientId,
        title: title,
        body: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Save with media attachments
      // Note: image_url, video_url, audio_url, action_url not in current schema
      await _supabase.from('notifications').insert({
        'id': notification.id,
        'user_id': notification.userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type?.value,
        'is_read': notification.isRead,
        'created_at': notification.createdAt.toIso8601String(),
        'data': data,
      });

      // Send with media attachments
      await _sendRichMediaPushNotification(
        clientId: clientId,
        title: title,
        message: message,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        data: data,
        actionUrl: actionUrl,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to send rich media notification', e);
      return false;
    }
  }

  // ===== User Preferences & Settings =====

  /// Update user notification preferences
  Future<bool> updateUserPreferences(
    String clientId,
    Map<String, dynamic> preferences,
  ) async {
    try {
      AppLogger.info('Updating notification preferences for client: $clientId');

      await _supabase.from('client_notification_preferences').upsert({
        'client_id': clientId,
        'preferences': jsonEncode(preferences),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update local cache
      final currentUserId = _supabase.auth.currentUser?.id;
      if (clientId == currentUserId) {
        _userPreferences = preferences;
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update preferences', e);
      return false;
    }
  }

  /// Get user notification preferences
  Future<Map<String, dynamic>> getUserPreferences(String clientId) async {
    try {
      // ❌ العمود 'preferences' لا يوجد في الجدول
      // بدلاً من محاولة جلبه - استخدم التفضيلات الافتراضية
      // final response = await _supabase
      //     .from('client_notification_preferences')
      //     .select('preferences')
      //     .eq('client_id', clientId)
      //     .maybeSingle();

      // Return default preferences (since column doesn't exist)
      return _getDefaultPreferences();
    } catch (e) {
      AppLogger.warning('⚠️ Failed to get preferences', e);
      return _getDefaultPreferences();
    }
  }

  /// Subscribe to notification topic
  Future<bool> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _subscribedTopics.add(topic);
      AppLogger.info('✅ Subscribed to topic: $topic');
      return true;
    } catch (e) {
      AppLogger.error('$_logTag ❌ Failed to subscribe to topic $topic', e);
      return false;
    }
  }

  /// Unsubscribe from notification topic
  Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _subscribedTopics.remove(topic);
      AppLogger.info('$_logTag ✅ Unsubscribed from topic: $topic');
      return true;
    } catch (e) {
      AppLogger.error('$_logTag ❌ Failed to unsubscribe from topic $topic', e);
      return false;
    }
  }

  // ===== Real-time Features =====

  /// Setup real-time notification listeners
  Future<void> _setupRealtimeListeners() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Listen to new notifications
      _supabase
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id', // العمود الصحيح في جدول notifications
              value: userId,
            ),
            callback: _handleRealtimeNotification,
          )
          .subscribe();

      AppLogger.info('✅ Real-time listeners setup completed');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to setup real-time listeners', e);
    }
  }

  /// Handle real-time notification updates
  /// ⚠️ لا نعرض إشعار محلي هنا - FCM push بيتكفل بالعرض
  /// Realtime يُستخدم فقط لتحديث واجهة المستخدم (badge, list refresh)
  void _handleRealtimeNotification(PostgresChangePayload payload) {
    try {
      final notification = NotificationModel.fromMap(payload.newRecord);

      // إبلاغ المستمعين بوجود إشعار جديد (لتحديث UI فقط)
      // لا نعرض local notification لأن FCM push هيوصل الإشعار
      _onNewNotificationCallback?.call(notification);

      AppLogger.info(
        '📱 Real-time notification received (UI update only): ${notification.title}',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to handle real-time notification', e);
    }
  }

  /// Callback for new notifications (UI updates)
  Function(NotificationModel)? _onNewNotificationCallback;

  /// Set callback for new notification events (for UI updates like badge count)
  void onNewNotification(Function(NotificationModel) callback) {
    _onNewNotificationCallback = callback;
  }

  // ===== Analytics & Tracking =====

  /// Track notification interaction
  Future<void> trackNotificationInteraction({
    required String notificationId,
    required String action, // 'opened', 'clicked', 'dismissed'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Validate UUID format (notification_analytics.notification_id expects UUID)
      // FCM message IDs like "0:1770409046999692%d1912ae5d1912ae5" are not valid UUIDs
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      if (!uuidRegex.hasMatch(notificationId)) {
        // Skip analytics for non-UUID notification IDs (FCM message IDs)
        AppLogger.info(
          '⏭️ Skipped analytics for non-UUID notification: $notificationId',
        );
        return;
      }

      await _supabase.from('notification_analytics').insert({
        'notification_id': notificationId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'additional_data': additionalData != null
            ? jsonEncode(additionalData)
            : null,
      });

      AppLogger.info('📊 Tracked interaction: $action for $notificationId');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to track interaction', e);
    }
  }

  /// Get notification statistics for admin dashboard
  Future<Map<String, dynamic>> getNotificationStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      AppLogger.info('Getting notification statistics...');

      // Get basic stats
      final totalSentData = await _supabase
          .from('notifications')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final totalReadData = await _supabase
          .from('notifications')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('is_read', true);

      final totalSent = (totalSentData as List).length;
      final totalRead = (totalReadData as List).length;

      // Get type distribution
      final typeStatsData = await _supabase
          .from('notifications')
          .select('type')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final typeStats = typeStatsData as List;
      final typeDistribution = <String, int>{};
      for (final item in typeStats) {
        final type = item['type'] as String;
        typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
      }

      // Calculate engagement metrics
      final readRate = totalSent > 0 ? (totalRead / totalSent * 100) : 0.0;

      return {
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'totals': {
          'sent': totalSent,
          'read': totalRead,
          'unread': totalSent - totalRead,
        },
        'rates': {'read_rate': double.parse(readRate.toStringAsFixed(2))},
        'type_distribution': typeDistribution,
        'daily_breakdown': await _getDailyNotificationBreakdown(start, end),
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get statistics', e);
      return {};
    }
  }

  // ===== Helper Methods =====

  /// Generate unique notification ID
  String _generateNotificationId() {
    return const Uuid().v4();
  }

  /// Generate unique campaign ID
  String _generateCampaignId() {
    return 'camp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Get default notification preferences
  Map<String, dynamic> _getDefaultPreferences() {
    return {
      'enabled': true,
      'types': {'order': true, 'promotion': true, 'system': true},
      'channels': {'push': true, 'local': true, 'in_app': true},
      'quiet_hours': {'enabled': false, 'start': '22:00', 'end': '08:00'},
      'frequency_limits': {'daily_max': 10, 'weekly_max': 50},
    };
  }

  /// Save device token to database with role separation
  /// Each user can register their token for different roles:
  /// - client: for customer notifications (default)
  /// - merchant: for store order notifications (uses store_id)
  /// - admin: for system/admin notifications
  /// - captain: for delivery notifications
  Future<void> _saveDeviceToken(
    String token, {
    String role = 'client',
    String? storeId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final deviceType = kIsWeb ? 'web' : 'mobile';

      // حذف أي سجلات قديمة لنفس التوكن من مستخدمين آخرين
      // لمنع وصول إشعارات مستخدم سابق على نفس الجهاز
      await _supabase
          .from('device_tokens')
          .delete()
          .neq('client_id', userId)
          .eq('token', token);

      final tokenData = <String, dynamic>{
        'client_id': userId,
        'token': token,
        'platform': deviceType,
        'role': role,
        'app_version': '1.0.0',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (storeId != null) {
        tokenData['store_id'] = storeId;
      }

      await _supabase
          .from('device_tokens')
          .upsert(
            tokenData,
            onConflict: storeId != null
                ? 'store_id,token'
                : 'client_id,token,role',
          );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save device token (role: $role)', e);
    }
  }

  /// حفظ device token للمستخدم الحالي مع الدور المناسب
  /// يتم استدعاؤها بعد تسجيل الدخول أو عند تغير حالة المصادقة
  Future<void> saveTokenForCurrentUser({String role = 'client'}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        AppLogger.warning('⚠️ Cannot save token: no authenticated user');
        return;
      }

      // If FCM token not yet available, try to get it
      _fcmToken ??= await _firebaseMessaging.getToken();

      if (_fcmToken == null) {
        AppLogger.warning('⚠️ Cannot save token: FCM token unavailable');
        return;
      }

      await _saveDeviceToken(_fcmToken!, role: role);
      _activeRoles.add(role);
      AppLogger.info('✅ Device token saved for user $userId with role: $role');
    } catch (e) {
      AppLogger.error(
        '❌ Failed to save token for current user (role: $role)',
        e,
      );
    }
  }

  /// تسجيل device token للمتجر (إشعارات الطلبات)
  Future<void> saveDeviceTokenForStore(String storeId) async {
    try {
      final token = _fcmToken;
      if (token == null) {
        AppLogger.warning('⚠️ No FCM token available');
        return;
      }

      await _saveDeviceToken(token, role: 'merchant', storeId: storeId);
      _activeRoles.add('merchant');
      AppLogger.info('✅ Device token saved for store: $storeId');
    } catch (e) {
      AppLogger.error('❌ Failed to save device token for store', e);
    }
  }

  /// تسجيل device token لدور معين (admin / captain)
  Future<void> saveDeviceTokenForRole(String role) async {
    try {
      final token = _fcmToken;
      if (token == null) {
        AppLogger.warning('⚠️ No FCM token available');
        return;
      }

      await _saveDeviceToken(token, role: role);
      _activeRoles.add(role);
      AppLogger.info('✅ Device token saved for role: $role');
    } catch (e) {
      AppLogger.error('❌ Failed to save device token for role: $role', e);
    }
  }

  /// حذف device token للمستخدم الحالي من قاعدة البيانات عند تسجيل الخروج
  /// يمنع وصول إشعارات المستخدم القديم للمستخدم الجديد على نفس الجهاز
  Future<void> removeDeviceTokenForCurrentUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final token = _fcmToken;

      if (userId == null || token == null) {
        AppLogger.warning(
          '⚠️ Cannot remove token: missing userId or FCM token',
        );
        return;
      }

      // حذف كل سجلات هذا التوكن لهذا المستخدم (كل الأدوار)
      await _supabase
          .from('device_tokens')
          .delete()
          .eq('client_id', userId)
          .eq('token', token);

      // مسح الأدوار المسجلة محلياً
      _activeRoles.clear();

      AppLogger.info('✅ Device tokens removed for user $userId on logout');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to remove device token on logout', e);
    }
  }

  /// إلغاء الاشتراك من جميع المواضيع عند تسجيل الخروج
  Future<void> unsubscribeFromAllTopics() async {
    try {
      for (final topic in List<String>.from(_subscribedTopics)) {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
      }
      _subscribedTopics.clear();
      AppLogger.info('✅ Unsubscribed from all topics on logout');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to unsubscribe from topics', e);
    }
  }

  /// Handle token refresh — re-save for ALL active roles
  void _onTokenRefresh(String token) {
    _fcmToken = token;
    AppLogger.info(
      '🔄 FCM Token refreshed — updating ${_activeRoles.length} active role(s)',
    );

    if (_activeRoles.isEmpty) {
      // Fallback: save as client if no roles registered yet
      _saveDeviceToken(token);
    } else {
      // Re-save for every role the user has registered
      for (final role in _activeRoles) {
        _saveDeviceToken(token, role: role);
      }
    }
  }

  /// Handle foreground messages
  /// على Android، إشعارات FCM لا تظهر تلقائياً عندما التطبيق مفتوح
  /// لذلك نعرضها كـ Local Notification
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('📱 Foreground message: ${message.notification?.title}');

    // عرض إشعار محلي لأن Android لا يعرض FCM notifications في foreground
    _showLocalNotification(message);

    // Track analytics
    trackNotificationInteraction(
      notificationId: message.messageId ?? 'unknown',
      action: 'received_foreground',
      additionalData: message.data,
    );
  }

  /// عرض إشعار محلي من رسالة FCM
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      // إنشاء مفتاح فريد للإشعار لمنع التكرار
      final notifKey =
          message.data['notification_id'] ??
          message.messageId ??
          '${notification.title}_${notification.body}';

      // تحقق من عدم عرض نفس الإشعار مسبقاً
      if (_recentlyShownNotifications.contains(notifKey)) {
        AppLogger.info('⏭️ تم تخطي إشعار مكرر: $notifKey');
        return;
      }

      // إضافة للقائمة وتنظيف القديم
      _recentlyShownNotifications.add(notifKey);
      if (_recentlyShownNotifications.length > _maxRecentNotifications) {
        _recentlyShownNotifications.remove(_recentlyShownNotifications.first);
      }

      // استخدام ID ثابت من بيانات الإشعار لمنع التكرار من النظام
      final notifId = notifKey.hashCode & 0x7FFFFFFF;

      const androidDetails = AndroidNotificationDetails(
        'ell_tall_market',
        'Ell Tall Market',
        channelDescription: 'إشعارات سوق التل',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notifId,
        notification.title ?? 'سوق التل',
        notification.body ?? '',
        details,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to show local notification', e);
    }
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    AppLogger.info('🔄 Background message tap: ${message.notification?.title}');

    // Track analytics
    trackNotificationInteraction(
      notificationId: message.messageId ?? 'unknown',
      action: 'opened_background',
      additionalData: message.data,
    );

    // Handle navigation if needed
    _handleNotificationAction(message.data);
  }

  /// Handle app launched from notification
  Future<void> _handleAppLaunchedFromNotification(RemoteMessage message) async {
    AppLogger.info(
      '🚀 App launched from notification: ${message.notification?.title}',
    );

    // Track analytics
    trackNotificationInteraction(
      notificationId: message.messageId ?? 'unknown',
      action: 'app_launched',
      additionalData: message.data,
    );

    // Handle navigation if needed
    _handleNotificationAction(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    AppLogger.info('👆 Local notification tapped: ${response.id}');

    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationAction(data);

      // Track analytics
      trackNotificationInteraction(
        notificationId: response.id.toString(),
        action: 'local_tapped',
        additionalData: data,
      );
    }
  }

  /// Handle notification actions (navigation, etc.)
  void _handleNotificationAction(Map<String, dynamic> data) {
    try {
      AppLogger.info('$_logTag Navigating to notifications screen');
      // Always navigate to the notifications screen when a notification is tapped
      NavigationService.navigateTo(AppRoutes.notifications);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ Failed to handle notification action', e);
      }
    }
  }

  /// Load user preferences from database
  Future<void> _loadUserPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        _userPreferences = await getUserPreferences(userId);
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load user preferences', e);
    }
  }

  /// Initialize analytics system
  Future<void> _initializeAnalytics() async {
    try {
      // Setup analytics tables if needed
      // This would be handled by database migrations
      AppLogger.info('✅ Analytics system initialized');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to initialize analytics', e);
    }
  }

  // ===== Additional Helper Methods =====
  // These methods would contain the actual implementation logic
  // for various features like user behavior analysis, location-based
  // targeting, A/B testing, etc.

  Future<Map<String, dynamic>> _getUserBehaviorData(String clientId) async {
    // Implementation for getting user behavior data
    return {};
  }

  Future<Map<String, dynamic>> _analyzeUserBehavior(String clientId) async {
    // Implementation for analyzing user behavior
    return {};
  }

  Future<DateTime> _getBestDeliveryTime(String clientId) async {
    // Implementation for calculating optimal delivery time
    return DateTime.now().add(const Duration(hours: 1));
  }

  Future<Map<String, dynamic>> _checkAbandonedCart(String clientId) async {
    // Implementation for checking abandoned cart
    return {'has_items': false, 'items_count': 0};
  }

  Future<Map<String, dynamic>?> _getWeatherBasedRecommendation(
    String clientId,
  ) async {
    // Implementation for weather-based recommendations
    return null;
  }

  Future<Map<String, dynamic>?> _getOccasionBasedRecommendation(
    String clientId,
  ) async {
    // Implementation for occasion-based recommendations
    return null;
  }

  Future<bool> _checkDeliveryPreferences(
    String clientId,
    NotificationType type,
  ) async {
    try {
      // Get user preferences (use cached if available for current user)
      final preferences =
          (clientId == _supabase.auth.currentUser?.id &&
              _userPreferences.isNotEmpty)
          ? _userPreferences
          : await getUserPreferences(clientId);

      // Check if notifications are enabled
      if (preferences['enabled'] != true) return false;

      // Check type-specific preferences
      final typePrefs = preferences['types'] as Map<String, dynamic>? ?? {};
      if (typePrefs[type.value] != true) return false;

      // Check quiet hours
      final quietHours =
          preferences['quiet_hours'] as Map<String, dynamic>? ?? {};
      if (quietHours['enabled'] == true) {
        final now = DateTime.now();
        final hour = now.hour;
        final startHour =
            int.tryParse(
              (quietHours['start'] as String? ?? '22:00').split(':')[0],
            ) ??
            22;
        final endHour =
            int.tryParse(
              (quietHours['end'] as String? ?? '08:00').split(':')[0],
            ) ??
            8;

        if (startHour > endHour) {
          // Overnight quiet hours (e.g., 22:00 to 08:00)
          if (hour >= startHour || hour < endHour) return false;
        } else {
          // Same day quiet hours
          if (hour >= startHour && hour < endHour) return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ Failed to check delivery preferences', e);
      }
      return true; // Default to allowing delivery
    }
  }

  Future<void> _saveNotificationToDatabase(
    NotificationModel notification,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    NotificationPriority priority,
    List<String>? tags,
    String? campaignId, {
    String? targetRole,
    String? storeId,
  }) async {
    try {
      final finalData = Map<String, dynamic>.from(data ?? {});
      if (imageUrl != null) finalData['image_url'] = imageUrl;
      if (actionUrl != null) finalData['action_url'] = actionUrl;
      finalData['priority'] = priority.name;
      if (tags != null) finalData['tags'] = tags;
      if (campaignId != null) finalData['campaign_id'] = campaignId;

      final insertData = <String, dynamic>{
        'id': notification.id,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type?.value,
        'data': finalData,
        'is_read': notification.isRead,
        'created_at': notification.createdAt.toIso8601String(),
        'target_role': targetRole ?? 'client',
      };

      // إشعارات المتجر تستخدم store_id بدل user_id
      if (storeId != null) {
        insertData['store_id'] = storeId;
      } else {
        insertData['user_id'] = notification.userId;
      }

      await _supabase.from('notifications').insert(insertData);
      AppLogger.info('✅ Notification saved to database: ${notification.id}');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save notification to database', e);
    }
  }

  Future<void> _scheduleNotification(
    NotificationModel notification,
    DateTime scheduledTime,
    Map<String, dynamic>? data,
  ) async {
    // Implementation for scheduling notification
  }

  Future<void> _trackNotificationSent(
    NotificationModel notification,
    String? campaignId,
  ) async {
    try {
      final deviceType = kIsWeb ? 'web' : 'mobile';
      // Use deviceType for analytics insert if needed
      await _supabase.from('notification_analytics').insert({
        'notification_id': notification.id,
        'user_id': notification.userId,
        'campaign_id': campaignId,
        'device_type': deviceType,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        // RLS policy blocks insert - this is expected if user doesn't have permission
        AppLogger.warning(
          '⚠️ RLS policy blocks notification analytics insert: ${e.message}',
        );
      } else {
        AppLogger.warning(
          '⚠️ Failed to track notification analytics: ${e.message}',
          e,
        );
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to track notification analytics', e);
    }
  }

  Map<String, List<String>> _splitClientsForABTesting(
    List<String> clientIds,
    Map<String, dynamic> variants,
  ) {
    // Implementation for A/B testing client splitting
    return {'default': clientIds};
  }

  Future<void> _scheduleCampaign(
    String campaignId,
    Map<String, List<String>> clientGroups,
    DateTime scheduledTime,
  ) async {
    // Implementation for scheduling campaign
  }

  Future<void> _executeCampaign(
    String campaignId,
    Map<String, List<String>> clientGroups,
  ) async {
    // Implementation for executing campaign
  }

  Future<List<String>> _getClientsInRadius(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    // Implementation for getting clients in geographic radius
    return [];
  }

  Future<void> _sendInteractivePushNotification({
    required String clientId,
    required String title,
    required String message,
    required List<NotificationAction> actions,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    // Implementation for sending interactive push notifications
  }

  Future<void> _sendRichMediaPushNotification({
    required String clientId,
    required String title,
    required String message,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    Map<String, dynamic>? data,
    String? actionUrl,
  }) async {
    // Implementation for sending rich media push notifications
  }

  Future<Map<String, dynamic>> _calculateEngagementTrends(
    List<dynamic> analytics,
  ) async {
    // Implementation for calculating engagement trends
    return {};
  }

  Future<Map<String, int>> _getDailyNotificationBreakdown(
    DateTime start,
    DateTime end,
  ) async {
    // Implementation for getting daily notification breakdown
    return {};
  }

  // ===== Merchant Notification Helpers =====

  /// إرسال إشعار للتاجر عند استلام طلب جديد
  Future<bool> notifyMerchantOfNewOrder({
    required String storeId,
    required String orderId,
    required double totalAmount,
    String? clientName,
  }) async {
    try {
      AppLogger.info('Sending new order notification to store: $storeId');

      // جلب معلومات المتجر
      final storeResponse = await _supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();

      if (storeResponse == null) {
        AppLogger.warning('Store not found: $storeId');
        return false;
      }

      final storeName = storeResponse['name'] as String? ?? 'متجرك';
      final bodyText =
          'لديك طلب جديد بقيمة ${totalAmount.toStringAsFixed(0)} ج.م${clientName != null ? ' من $clientName' : ''}';

      // إشعار المتجر: يستخدم store_id بدل user_id
      // الـ trigger بيبعت store_id للـ Edge Function
      // الـ Edge Function بيدور على device_tokens WHERE store_id = X
      await _supabase.from('notifications').insert({
        'title': '🛒 طلب جديد!',
        'body': bodyText,
        'type': NotificationType.order.value,
        'target_role': 'merchant',
        'store_id': storeId,
        'data': {
          'type': 'new_order',
          'target_role': 'merchant',
          'order_id': orderId,
          'store_id': storeId,
          'store_name': storeName,
          'total_amount': totalAmount,
          'action_url': '/merchant/orders/$orderId',
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('✅ Notification sent to store: $storeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to send store notification', e);
      return false;
    }
  }

  // ===== Admin Notification Helpers =====

  /// إرسال إشعار للمديرين عند استلام طلب جديد في النظام
  Future<bool> notifyAdminOfNewOrder({
    required String orderId,
    required String storeName,
    required double totalAmount,
  }) async {
    try {
      AppLogger.info(
        'Sending new order notification to admins for order: $orderId',
      );

      // جلب جميع المستخدمين الأدمن من جدول profiles
      final adminsResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      final admins = adminsResponse as List;
      if (admins.isEmpty) {
        AppLogger.warning('⚠️ No admin users found to notify');
        return false;
      }

      bool anySent = false;
      for (final admin in admins) {
        final adminId = admin['id'] as String?;
        if (adminId == null) continue;

        final sent = await sendSmartNotification(
          clientId: adminId,
          title: '📊 طلب جديد في النظام',
          message:
              'طلب جديد من متجر $storeName بقيمة ${totalAmount.toStringAsFixed(0)} ج.م',
          type: NotificationType.order,
          priority: NotificationPriority.normal,
          targetRole: 'admin',
          data: {
            'type': 'new_order',
            'target_role': 'admin',
            'order_id': orderId,
            'store_name': storeName,
            'total_amount': totalAmount,
          },
          actionUrl: '/admin/orders/$orderId',
        );
        if (sent) anySent = true;
      }

      AppLogger.info('✅ Admin notifications sent to ${admins.length} admins');
      return anySent;
    } catch (e) {
      AppLogger.error('❌ Failed to send admin notification', e);
      return false;
    }
  }

  // ===== Captain Notification Helpers =====

  /// إرسال إشعار للكباتن عن طلب متاح للتوصيل
  Future<bool> notifyCaptainsOfAvailableOrder({
    required String orderId,
    required String storeName,
    String? area,
  }) async {
    try {
      AppLogger.info('Sending available order notification to captains');

      // جلب الكباتن المتصلين حالياً
      final captainsResponse = await _supabase
          .from('captains')
          .select('id')
          .eq('status', 'online')
          .eq('is_active', true)
          .eq('is_available', true);

      final captains = captainsResponse as List;
      if (captains.isEmpty) {
        AppLogger.warning('⚠️ No online captains found to notify');
        return false;
      }

      final areaText = area != null ? ' في منطقة $area' : '';
      bool anySent = false;

      for (final captain in captains) {
        final captainId = captain['id'] as String?;
        if (captainId == null) continue;

        final sent = await sendSmartNotification(
          clientId: captainId,
          title: '🚗 طلب جديد متاح للتوصيل',
          message: 'طلب جديد من متجر $storeName$areaText متاح للاستلام',
          type: NotificationType.order,
          priority: NotificationPriority.high,
          targetRole: 'captain',
          data: {
            'type': 'available_order',
            'target_role': 'captain',
            'order_id': orderId,
            'store_name': storeName,
            if (area != null) 'area': area,
          },
        );
        if (sent) anySent = true;
      }

      AppLogger.info(
        '✅ Available order notification sent to ${captains.length} captains',
      );
      return anySent;
    } catch (e) {
      AppLogger.error('❌ Failed to send captains notification', e);
      return false;
    }
  }

  /// إرسال إشعار لكابتن معين عند تعيين طلب له
  Future<bool> notifyCaptainOfOrderAssignment({
    required String captainId,
    required String orderId,
    required String storeName,
  }) async {
    return await sendSmartNotification(
      clientId: captainId,
      title: '📦 تم تعيين طلب لك',
      message: 'تم تعيين طلب جديد لك من متجر $storeName. يرجى استلام الطلب.',
      type: NotificationType.order,
      priority: NotificationPriority.high,
      targetRole: 'captain',
      data: {
        'type': 'order_assigned',
        'target_role': 'captain',
        'order_id': orderId,
        'store_name': storeName,
      },
    );
  }

  /// إرسال إشعار للتاجر عند تغيير حالة الطلب
  Future<bool> notifyMerchantOfOrderStatusChange({
    required String storeId,
    required String orderId,
    required String newStatus,
    String? clientName,
  }) async {
    try {
      // جلب معلومات المتجر والتاجر
      final storeResponse = await _supabase
          .from('stores')
          .select('merchant_id, name')
          .eq('id', storeId)
          .maybeSingle();

      if (storeResponse == null) return false;

      final merchantId = storeResponse['merchant_id'] as String?;
      if (merchantId == null) return false;

      // تحديد الرسالة حسب الحالة
      String statusMessage;
      switch (newStatus) {
        case 'preparing':
          statusMessage = 'تم قبول الطلب وبدأ التحضير 👨‍🍳';
          break;
        case 'in_transit':
          statusMessage = 'الطلب جاهز وخرج للتوصيل 🚗';
          break;
        case 'delivered':
          statusMessage = 'تم تسليم الطلب بنجاح ✅';
          break;
        case 'cancelled':
          statusMessage = 'تم إلغاء الطلب ❌';
          break;
        case 'on_the_way':
          statusMessage = 'الطلب في الطريق 🚗';
          break;
        default:
          statusMessage = 'تم تحديث حالة الطلب';
      }

      return await sendSmartNotification(
        clientId: merchantId,
        title: 'تحديث الطلب',
        message: statusMessage,
        type: NotificationType.order,
        targetRole: 'merchant',
        data: {
          'type': 'order_status_change',
          'target_role': 'merchant',
          'order_id': orderId,
          'store_id': storeId,
          'new_status': newStatus,
        },
      );
    } catch (e) {
      AppLogger.error('❌ Failed to send order status notification', e);
      return false;
    }
  }

  /// إرسال إشعار للعميل عند تغيير حالة طلبه
  Future<bool> notifyClientOfOrderStatusChange({
    required String clientId,
    required String orderId,
    required String newStatus,
    String? storeName,
  }) async {
    try {
      // تحميل إعدادات الإشعارات للمستخدم
      final prefs = await SharedPreferences.getInstance();
      final notificationLevelIndex =
          prefs.getInt('notification_level') ?? 1; // default: important

      // تحديد مستوى الإشعار من الإعدادات
      // 0 = all, 1 = important, 2 = deliveryOnly
      final shouldSkip = _shouldSkipNotification(
        newStatus,
        notificationLevelIndex,
      );
      if (shouldSkip) {
        AppLogger.info(
          '⏭️ تم تخطي إشعار الحالة $newStatus بناءً على تفضيلات المستخدم',
        );
        return true; // Not an error, just skipped
      }

      // دمج الإشعارات الذكي (للمستويات important و all)
      String statusMessage;
      String title;

      switch (newStatus) {
        case 'confirmed':
          // دمج Confirmed + Preparing في إشعار واحد
          title = 'تم قبول طلبك وجاري تحضيره ✅👨‍🍳';
          statusMessage =
              'تم تأكيد طلبك${storeName != null ? ' من $storeName' : ''} وبدأ التحضير الآن';
          break;
        case 'preparing':
          // التاجر قبل وبدأ التحضير مباشرة (التدفق الجديد المبسط)
          title = 'تم قبول طلبك وجاري تحضيره ✅👨‍🍳';
          statusMessage =
              'تم قبول طلبك${storeName != null ? ' من $storeName' : ''} وبدأ التحضير الآن';
          break;
        case 'ready':
          title = 'طلبك جاهز 📦';
          statusMessage =
              'طلبك جاهز${storeName != null ? ' من $storeName' : ''} وسيتم التوصيل قريباً';
          break;
        case 'on_the_way':
        case 'in_transit':
          title = 'طلبك في الطريق! 🚗';
          statusMessage = 'الطلب في طريقه إليك الآن';
          break;
        case 'delivered':
          title = 'تم التوصيل! 🎉';
          statusMessage = 'تم توصيل طلبك بنجاح. نتمنى لك تجربة ممتعة!';
          break;
        case 'cancelled':
          title = 'تم إلغاء الطلب ❌';
          statusMessage =
              'تم إلغاء طلبك${storeName != null ? ' من $storeName' : ''}';
          break;
        default:
          title = 'تحديث الطلب';
          statusMessage = 'تم تحديث حالة طلبك';
      }

      return await sendSmartNotification(
        clientId: clientId,
        title: title,
        message: statusMessage,
        type: NotificationType.order,
        priority: NotificationPriority.high,
        targetRole: 'client',
        data: {
          'type': 'order_status_change',
          'target_role': 'client',
          'order_id': orderId,
          'new_status': newStatus,
        },
        actionUrl: '/orders/$orderId',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to send client order notification', e);
      return false;
    }
  }

  /// تحديد ما إذا كان يجب تخطي الإشعار بناءً على تفضيلات المستخدم
  bool _shouldSkipNotification(String status, int notificationLevel) {
    // Level 0 (all): لا تخطي أي إشعار
    if (notificationLevel == 0) return false;

    // Level 2 (deliveryOnly): فقط in_transit, delivered و cancelled
    if (notificationLevel == 2) {
      return !(status == 'in_transit' ||
          status == 'on_the_way' ||
          status == 'delivered' ||
          status == 'cancelled');
    }

    // Level 1 (important): preparing, in_transit, delivered, cancelled
    // تخطي: pending, confirmed, ready (حالات وسيطة مدمجة)
    if (notificationLevel == 1) {
      return status == 'pending' || status == 'confirmed' || status == 'ready';
    }

    return false;
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      // Cancel subscriptions and cleanup resources
      await _supabase.removeAllChannels();
      AppLogger.info('♻️ Notification service disposed');
    } catch (e) {
      AppLogger.warning('⚠️ Error during disposal', e);
    }
  }
}

/// Notification priority levels
enum NotificationPriority { low, normal, high, urgent }

/// Notification action for interactive notifications
class NotificationAction {
  final String id;
  final String title;
  final String? icon;
  final Map<String, dynamic>? data;

  const NotificationAction({
    required this.id,
    required this.title,
    this.icon,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'data': data,
  };
}
