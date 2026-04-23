/// Notification model that matches the Supabase notifications table
/// Updated to match the new comprehensive notifications system schema
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';

/// Base mixin for common model functionality
mixin BaseModelMixin {
  String get id;
  DateTime get createdAt;
  DateTime? get updatedAt;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get updatedAtFormatted => updatedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(updatedAt!)
      : 'لم يتم التحديث';

  static DateTime parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }
}

/// Notification Type Enum
enum NotificationType {
  order,
  promotion,
  system;

  static NotificationType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return NotificationType.order;
      case 'promotion':
        return NotificationType.promotion;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  String get value {
    switch (this) {
      case NotificationType.order:
        return 'order';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.system:
        return 'system';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.order:
        return 'طلب';
      case NotificationType.promotion:
        return 'عرض';
      case NotificationType.system:
        return 'نظام';
    }
  }
}

/// Notification model that matches the Supabase notifications table
class NotificationModel with BaseModelMixin {
  static const String tableName = 'notifications';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String? userId; // UUID REFERENCES auth.users(id) ON DELETE CASCADE
  final String? storeId; // UUID REFERENCES stores(id)
  final String title; // TEXT NOT NULL
  final String body; // TEXT NOT NULL
  final NotificationType?
  type; // TEXT CHECK (type IN ('order', 'promotion', 'system'))
  final Map<String, dynamic>? data; // JSONB DEFAULT '{}'
  final bool isRead; // BOOLEAN DEFAULT FALSE
  final String targetRole; // TEXT DEFAULT 'client'
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const NotificationModel({
    required this.id,
    this.userId,
    this.storeId,
    required this.title,
    required this.body,
    this.type,
    this.data,
    required this.isRead,
    this.targetRole = 'client',
    required this.createdAt,
    this.updatedAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    // targetRole: أولوية للعمود، ثم الـ JSONB data
    final dataMap = map['data'] as Map<String, dynamic>?;
    final role =
        (map['target_role'] as String?) ??
        (dataMap?['target_role'] as String?) ??
        'client';

    return NotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      storeId: map['store_id'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] != null
          ? NotificationType.fromString(map['type'] as String)
          : null,
      data: dataMap,
      isRead: (map['is_read'] as bool?) ?? false,
      targetRole: role,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: null, // notifications table doesn't have updated_at
    );
  }

  // Helper methods
  String get typeDisplayName => type?.displayName ?? 'غير محدد';
  bool get hasData => data != null && data!.isNotEmpty;

  String get createdAtRelative {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(createdAt);
    }
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? storeId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    String? targetRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      targetRole: targetRole ?? this.targetRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: ${type?.value})';
  }
}

/// Service class for notification operations
class NotificationService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// الحصول على إشعارات المستخدم
  static Future<List<NotificationModel>> getUserNotifications({
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response = await _client
          .from(NotificationModel.tableName)
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return response
          .map<NotificationModel>(
            (notification) => NotificationModel.fromMap(notification),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error getting user notifications', e);
      return [];
    }
  }

  /// تحديد إشعار كمقروء
  static Future<bool> markAsRead(String notificationId) async {
    try {
      await _client
          .from(NotificationModel.tableName)
          .update({'is_read': true})
          .eq('id', notificationId);

      return true;
    } catch (e) {
      AppLogger.error('Error marking notification as read', e);
      return false;
    }
  }
}
