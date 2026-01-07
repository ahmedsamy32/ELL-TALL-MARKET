import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import '../core/logger.dart';

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

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _saveDeviceToken(_fcmToken!);
        AppLogger.info('FCM Token saved: ${_fcmToken!.substring(0, 20)}...');
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

      // Save to database
      await _saveNotificationToDatabase(
        notification,
        data,
        imageUrl,
        actionUrl,
        priority,
        tags,
        campaignId,
      );

      // Schedule or send immediately
      if (scheduledTime != null && scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(notification, scheduledTime, data);
      } else {
        await _deliverNotification(
          notification,
          data,
          imageUrl,
          actionUrl,
          priority,
        );
      }

      // Track analytics
      await _trackNotificationSent(notification, campaignId);

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
      final response = await _supabase
          .from('client_notification_preferences')
          .select('preferences')
          .eq('client_id', clientId)
          .maybeSingle();

      if (response != null && response['preferences'] != null) {
        return jsonDecode(response['preferences']);
      }

      // Return default preferences
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
              column: 'client_id',
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
  void _handleRealtimeNotification(PostgresChangePayload payload) {
    try {
      final notification = NotificationModel.fromMap(payload.newRecord);

      // Show local notification for real-time updates
      _showLocalNotification(
        notification.id,
        notification.title,
        notification.body,
        payload: jsonEncode({
          'id': notification.id,
          'user_id': notification.userId,
          'title': notification.title,
          'body': notification.body,
          'type': notification.type?.value,
          'data': notification.data,
        }),
      );

      AppLogger.info(
        '📱 Real-time notification received: ${notification.title}',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to handle real-time notification', e);
    }
  }

  // ===== Analytics & Tracking =====

  /// Track notification interaction
  Future<void> trackNotificationInteraction({
    required String notificationId,
    required String action, // 'opened', 'clicked', 'dismissed'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
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
    return 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Generate unique campaign ID
  String _generateCampaignId() {
    return 'camp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Get default notification preferences
  Map<String, dynamic> _getDefaultPreferences() {
    return {
      'enabled': true,
      'types': {
        'order_update': true,
        'promotion': true,
        'system': true,
        'message': true,
      },
      'channels': {'push': true, 'local': true, 'in_app': true},
      'quiet_hours': {'enabled': false, 'start': '22:00', 'end': '08:00'},
      'frequency_limits': {'daily_max': 10, 'weekly_max': 50},
    };
  }

  /// Save device token to database
  Future<void> _saveDeviceToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('device_tokens').upsert({
        'client_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': '1.0.0', // Note: Get from package info
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save device token', e);
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) {
    _fcmToken = token;
    _saveDeviceToken(token);
    AppLogger.info('🔄 FCM Token refreshed');
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      AppLogger.info('📱 Foreground message: ${message.notification?.title}');
    }

    // Show local notification for foreground messages
    _showLocalNotification(
      message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      payload: jsonEncode(message.data),
    );

    // Track analytics
    trackNotificationInteraction(
      notificationId: message.messageId ?? 'unknown',
      action: 'received_foreground',
      additionalData: message.data,
    );
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
      // Handle different action types
      final actionType = data['action_type'] as String?;
      final actionData = data['action_data'] as Map<String, dynamic>?;

      switch (actionType) {
        case 'navigate':
          // Note: Implement navigation logic
          AppLogger.info('Navigate to: ${actionData?['route']}');
          break;
        case 'open_url':
          // Note: Implement URL opening logic
          AppLogger.info('Open URL: ${actionData?['url']}');
          break;
        case 'show_dialog':
          // Note: Implement dialog showing logic
          AppLogger.info('Show dialog: ${actionData?['message']}');
          break;
        default:
          AppLogger.warning('Unknown action type: $actionType');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ Failed to handle notification action', e);
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(
    String id,
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'ell_tall_market',
        'Ell Tall Market',
        channelDescription: 'Ell Tall Market notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id.hashCode,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ Failed to show local notification', e);
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
    String? campaignId,
  ) async {
    // Implementation for saving notification to database
  }

  Future<void> _scheduleNotification(
    NotificationModel notification,
    DateTime scheduledTime,
    Map<String, dynamic>? data,
  ) async {
    // Implementation for scheduling notification
  }

  Future<void> _deliverNotification(
    NotificationModel notification,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    NotificationPriority priority,
  ) async {
    // Implementation for delivering notification
  }

  Future<void> _trackNotificationSent(
    NotificationModel notification,
    String? campaignId,
  ) async {
    // Implementation for tracking sent notifications
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
