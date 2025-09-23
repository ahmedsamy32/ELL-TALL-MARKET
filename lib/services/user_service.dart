import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'dart:io';

class UserService {
  final _supabase = Supabase.instance.client;

  // الحصول على مستخدم بواسطة ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromMap(response, id: response['id']);
    } catch (e) {
      throw Exception('فشل تحميل المستخدم: ${e.toString()}');
    }
  }

  // الحصول على جميع المستخدمين
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => UserModel.fromMap(data, id: data['id']))
          .toList();
    } catch (e) {
      throw Exception('فشل تحميل المستخدمين: ${e.toString()}');
    }
  }

  // إنشاء مستخدم جديد
  Future<UserModel?> createUser(UserModel user, String password) async {
    try {
      // إنشاء المستخدم في Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: user.email,
        password: password,
        data: {
          'full_name': user.name,
          'phone': user.phone,
        },
      );

      if (authResponse.user != null) {
        // حفظ بيانات المس��خدم في جدول المستخدمين
        final userData = user.toMap()
          ..addAll({
            'id': authResponse.user!.id,
            'created_at': DateTime.now().toIso8601String(),
          });

        await _supabase
            .from('users')
            .insert(userData);

        return user.copyWith(id: authResponse.user!.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل إنشاء المستخدم: ${e.toString()}');
    }
  }

  // تحديث مستخدم
  Future<bool> updateUser(UserModel user) async {
    try {
      await _supabase
          .from('users')
          .update(user.toMap())
          .eq('id', user.id);
      return true;
    } catch (e) {
      throw Exception('فشل تحديث المستخدم: ${e.toString()}');
    }
  }

  // حذف مستخدم
  Future<bool> deleteUser(String userId) async {
    try {
      await _supabase
          .from('users')
          .delete()
          .eq('id', userId);

      // حذف المستخدم من Supabase Auth
      await _supabase.auth.admin.deleteUser(userId);
      return true;
    } catch (e) {
      throw Exception('فشل حذف المستخدم: ${e.toString()}');
    }
  }

  // إعادة تعيين كلمة المرور
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      throw Exception('فشل إرسال رابط إعادة تعيين كلمة المرور: ${e.toString()}');
    }
  }

  // تحديث كلمة المرور
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
      return true;
    } catch (e) {
      throw Exception('فشل تحديث كلمة المرور: ${e.toString()}');
    }
  }

  // الاستماع للتحدي��ات في الوقت الحقيقي
  RealtimeChannel getUsersStream() {
    return _supabase
        .channel('public:users')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            // يمكن معالجة التحديثات هنا
          },
        )
        .subscribe();
  }

  // البحث عن المستخد��ين
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => UserModel.fromMap(data, id: data['id']))
          .toList();
    } catch (e) {
      throw Exception('فشل البحث عن المستخدمين: ${e.toString()}');
    }
  }

  // رفع صورة المستخدم
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = 'profile_$userId.$fileExt';
      final storageResponse = await _supabase
          .storage
          .from('avatars')
          .upload(fileName, imageFile);

      if (storageResponse.isNotEmpty) {
        final imageUrl = _supabase
            .storage
            .from('avatars')
            .getPublicUrl(fileName);

        // تحديث رابط الصورة في جدول المستخدمين
        await _supabase
            .from('users')
            .update({'avatar_url': imageUrl})
            .eq('id', userId);

        return imageUrl;
      }
      return null;
    } catch (e) {
      throw Exception('فشل رفع صورة المستخدم: ${e.toString()}');
    }
  }

  // التحقق من وجود مستخدم مسؤول
  Future<bool> checkAdminExists() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('type', 'admin')
          .eq('email', 'admin@elltall.com')
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw Exception('فشل التحقق من وجود مستخدم مسؤول: ${e.toString()}');
    }
  }

  // إنشاء مستخدم مسؤول
  Future<bool> createAdminUser() async {
    try {
      final exists = await checkAdminExists();
      if (exists) {
        return true;
      }

      // إنشاء المستخدم في Supabase Auth
      final authResponse = await _supabase.auth.admin.createUser(
        AdminUserAttributes(
          email: 'admin@elltall.com',
          password: 'Admin@123',
          emailConfirm: true,
          userMetadata: {
            'full_name': 'Admin',
            'type': 'admin',
          },
        ),
      );

      if (authResponse.user != null) {
        // حفظ بيانات المستخدم في جدول profiles
        await _supabase.from('profiles').insert({
          'id': authResponse.user!.id,
          'name': 'Admin',
          'email': 'admin@elltall.com',
          'type': 'admin',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        return true;
      }
      return false;
    } catch (e) {
      throw Exception('فشل إنشاء مستخدم مسؤول: ${e.toString()}');
    }
  }
}