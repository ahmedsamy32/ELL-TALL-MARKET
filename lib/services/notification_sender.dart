import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class NotificationSender {
  static final NotificationSender _instance = NotificationSender._internal();
  factory NotificationSender() => _instance;
  NotificationSender._internal();

  final _supabase = Supabase.instance.client;
  final String _fcmServerKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key

  // إرسال إشعار لمستخدم محدد
  Future<bool> sendToUser(String userId, {
    required String title,
    required String body,
    String? type,
    String? targetId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // جلب توكنات المستخدم
      final tokens = await _getUserTokens(userId);
      if (tokens.isEmpty) return false;

      // بناء محتوى الإشعار
      final notification = {
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': type ?? 'general',
          'id': targetId ?? '',
          ...?additionalData,
        },
        'registration_ids': tokens,
      };

      // إرسال الإشعار
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: json.encode(notification),
      );

      if (kDebugMode) {
        print('📤 FCM Response: ${response.body}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }
      return false;
    }
  }

  // إرسال إشعار لمجموعة من المستخدمين
  Future<bool> sendToUsers(List<String> userIds, {
    required String title,
    required String body,
    String? type,
    String? targetId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // جلب توكنات المستخدمين
      final List<String> tokens = [];
      for (final userId in userIds) {
        tokens.addAll(await _getUserTokens(userId));
      }

      if (tokens.isEmpty) return false;

      // إرسال الإشعار لكل 500 توكن (حد FCM)
      final chunks = _chunkList(tokens, 500);
      for (final chunk in chunks) {
        final notification = {
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': type ?? 'general',
            'id': targetId ?? '',
            ...?additionalData,
          },
          'registration_ids': chunk,
        };

        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$_fcmServerKey',
          },
          body: json.encode(notification),
        );

        if (kDebugMode) {
          print('📤 FCM Batch Response: ${response.body}');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending batch notification: $e');
      }
      return false;
    }
  }

  // إرسال إشعار حسب نوع المستخدم
  Future<bool> sendToUserType(UserType type, {
    required String title,
    required String body,
    String? notificationType,
    String? targetId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // جلب معرفات المستخدمين من النوع المحدد
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('type', type.toString().split('.').last);

      final userIds = (response as List).map((u) => u['id'] as String).toList();

      return await sendToUsers(
        userIds,
        title: title,
        body: body,
        type: notificationType,
        targetId: targetId,
        additionalData: additionalData,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification to user type: $e');
      }
      return false;
    }
  }

  // جلب توكنات مستخدم معين
  Future<List<String>> _getUserTokens(String userId) async {
    try {
      final response = await _supabase
          .from('device_tokens')
          .select('token')
          .eq('user_id', userId);

      return (response as List).map((t) => t['token'] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user tokens: $e');
      }
      return [];
    }
  }

  // تقسيم القائمة إلى أجزاء
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }
}
