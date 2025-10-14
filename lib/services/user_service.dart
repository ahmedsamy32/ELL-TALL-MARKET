/// User Service - خدمات إدارة المستخدمين للأدمن
/// يعمل مع user_model.dart و user_provider.dart
/// Following Supabase Dart SDK: https://supabase.com/docs/reference/dart/introduction
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/Profile_model.dart'; // Import UserRole
import '../core/logger.dart';

/// UserService - خدمات CRUD للمستخدمين
class UserService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Get all users with filters
  /// https://supabase.com/docs/reference/dart/select
  static Future<List<UserModel>> getAllUsers({
    UserRole? role,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _client.from(UserModel.tableName).select();

      if (role != null) {
        query = query.eq('role', role.value);
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await query;
      final list = response as List;

      return list.map((item) => UserModel.fromMap(item)).toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المستخدمين', e);
      rethrow;
    }
  }

  /// Get user by ID
  /// https://supabase.com/docs/reference/dart/select
  static Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from(UserModel.tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromMap(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب المستخدم', e);
      return null;
    }
  }

  /// Update user
  /// https://supabase.com/docs/reference/dart/update
  static Future<bool> updateUser(UserModel user) async {
    try {
      await _client
          .from(UserModel.tableName)
          .update(user.toUpdateMap())
          .eq('id', user.id);

      AppLogger.info('تم تحديث المستخدم: ${user.id}');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث المستخدم', e);
      return false;
    }
  }

  /// Delete user
  /// https://supabase.com/docs/reference/dart/delete
  static Future<bool> deleteUser(String userId) async {
    try {
      await _client.from(UserModel.tableName).delete().eq('id', userId);

      AppLogger.info('تم حذف المستخدم: $userId');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف المستخدم', e);
      return false;
    }
  }

  /// Search users
  /// https://supabase.com/docs/reference/dart/select
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _client
          .from(UserModel.tableName)
          .select()
          .or('full_name.ilike.%$query%,email.ilike.%$query%');

      final list = response as List;
      return list.map((item) => UserModel.fromMap(item)).toList();
    } catch (e) {
      AppLogger.error('خطأ في البحث عن المستخدمين', e);
      return [];
    }
  }

  /// Get users count by role
  /// https://supabase.com/docs/reference/dart/select
  static Future<Map<String, int>> getUsersCountByRole() async {
    try {
      final counts = <String, int>{};

      for (final role in UserRole.values) {
        final response = await _client
            .from(UserModel.tableName)
            .select('id')
            .eq('role', role.value);

        final list = response as List;
        counts[role.value] = list.length;
      }

      return counts;
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات المستخدمين', e);
      return {};
    }
  }
}
