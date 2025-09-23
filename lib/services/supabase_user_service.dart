import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

class SupabaseUserService {
  static final SupabaseUserService _instance = SupabaseUserService._internal();
  factory SupabaseUserService() => _instance;
  SupabaseUserService._internal();

  final SupabaseClient _client = SupabaseConfig.client;

  /// إنشاء مستخدم جديد في Supabase
  Future<UserModel?> createUser(UserModel user) async {
    try {
      if (kDebugMode) {
        debugPrint('👤 [SupabaseUserService] إنشاء مستخدم: ${user.email}');
      }

      final response = await _client
          .from('profiles')
          .insert({
            'firebase_id': user.firebaseId,
            'name': user.name,
            'email': user.email,
            'phone': user.phone,
            'type': user.type.toString().split('.').last,
            'is_active': user.isActive,
            'created_at': user.createdAt.toIso8601String(),
          })
          .select()
          .single();

      final createdUser = UserModel.fromMap(response, id: response['id']);

      if (kDebugMode) {
        debugPrint(
          '✅ [SupabaseUserService] تم إنشاء المستخدم بنجاح: ${createdUser.id}',
        );
      }

      return createdUser;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في إنشاء المستخدم: $e');
      }
      rethrow;
    }
  }

  /// الحصول على مستخدم بواسطة Firebase ID
  Future<UserModel?> getUserByFirebaseId(String firebaseId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('*, stores(*)')
          .eq('firebase_id', firebaseId)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromMap(response, id: response['id']);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في جلب المستخدم: $e');
      }
      return null;
    }
  }

  /// الحصول على مستخدم بواسطة البريد الإلكتروني
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select('*, stores(*)')
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromMap(response, id: response['id']);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في جلب المستخدم بالبريد: $e');
      }
      return null;
    }
  }

  /// تحديث آخر تسجيل دخول
  Future<void> updateLastLogin(String userId) async {
    try {
      await _client
          .from('profiles')
          .update({
            'last_login': DateTime.now().toIso8601String(),
            'login_count': 'login_count + 1',
          })
          .eq('id', userId);

      if (kDebugMode) {
        debugPrint('✅ [SupabaseUserService] تم تحديث آخر تسجيل دخول');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SupabaseUserService] خطأ في تحديث آخر تسجيل دخول: $e');
      }
      // لا نرمي خطأ هنا لأنه ليس حرجاً
    }
  }

  /// تحديث معلومات المستخدم
  Future<UserModel?> updateUser(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select('*, stores(*)')
          .single();

      if (kDebugMode) {
        debugPrint('✅ [SupabaseUserService] تم تحديث المستخدم');
      }

      return UserModel.fromMap(response, id: response['id']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في تحديث المستخدم: $e');
      }
      rethrow;
    }
  }

  /// حذف مستخدم بواسطة Firebase ID
  Future<void> deleteUserByFirebaseId(String firebaseId) async {
    try {
      await _client.from('profiles').delete().eq('firebase_id', firebaseId);

      if (kDebugMode) {
        debugPrint('✅ [SupabaseUserService] تم حذف المستخدم');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في حذف المستخدم: $e');
      }
      rethrow;
    }
  }

  /// الحصول على جميع المستخدمين (للأدمن فقط)
  Future<List<UserModel>> getAllUsers({int? limit, int? offset}) async {
    try {
      PostgrestTransformBuilder query = _client
          .from('profiles')
          .select('*, stores(*)');

      if (limit != null && offset != null) {
        query = query.range(offset, offset + limit - 1);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return response
          .map((data) => UserModel.fromMap(data, id: data['id']))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في جلب جميع المستخدمين: $e');
      }
      return [];
    }
  }

  /// البحث عن المستخدمين
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select('*, stores(*)')
          .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%');

      return response
          .map((data) => UserModel.fromMap(data, id: data['id']))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في البحث عن المستخدمين: $e');
      }
      return [];
    }
  }

  /// تحديث نوع المستخدم (للأدمن فقط)
  Future<void> updateUserType(String userId, UserType userType) async {
    try {
      await _client
          .from('profiles')
          .update({'type': userType.toString().split('.').last})
          .eq('id', userId);

      if (kDebugMode) {
        debugPrint('✅ [SupabaseUserService] تم تحديث نوع المستخدم');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في تحديث نوع المستخدم: $e');
      }
      rethrow;
    }
  }

  /// تفعيل/إلغاء تفعيل المستخدم
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _client
          .from('profiles')
          .update({'is_active': isActive})
          .eq('id', userId);

      if (kDebugMode) {
        debugPrint('✅ [SupabaseUserService] تم تحديث حالة المستخدم');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseUserService] خطأ في تحديث حالة المستخدم: $e');
      }
      rethrow;
    }
  }

  /// إحصائيات المستخدمين
  Future<Map<String, int>> getUserStats() async {
    try {
      // جلب جميع المستخدمين وحساب الإحصائيات محلياً
      final allUsers = await getAllUsers();

      final total = allUsers.length;
      final active = allUsers.where((user) => user.isActive).length;
      final admins = allUsers
          .where((user) => user.type == UserType.admin)
          .length;
      final merchants = allUsers
          .where((user) => user.type == UserType.merchant)
          .length;
      final customers = allUsers
          .where((user) => user.type == UserType.customer)
          .length;

      return {
        'total': total,
        'active': active,
        'admins': admins,
        'merchants': merchants,
        'customers': customers,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [SupabaseUserService] خطأ في جلب إحصائيات المستخدمين: $e',
        );
      }
      return {
        'total': 0,
        'active': 0,
        'admins': 0,
        'merchants': 0,
        'customers': 0,
      };
    }
  }
}
