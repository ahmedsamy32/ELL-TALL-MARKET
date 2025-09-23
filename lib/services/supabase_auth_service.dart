import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final response = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (response != null) {
          return UserModel.fromMap(response, id: user.id);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseAuthService] Error getting current user: $e');
      return null;
    }
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('فشل تسجيل الدخول');
      }

      dynamic userData;
      if (email.toLowerCase() == 'admin@elltall.com') {
        final adminCheck = await _client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (adminCheck == null) {
          final adminData = {
            'id': response.user!.id,
            'email': email,
            'name': 'Admin',
            'type': 'admin',
            'is_active': true,
            'phone': '',
            'created_at': DateTime.now().toIso8601String(),
          };

          await _client.from('profiles').upsert([adminData]);
          userData = adminData;
        } else {
          userData = adminCheck;
        }
      } else {
        userData = await _client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .single();
      }

      final userModel = UserModel.fromMap(userData, id: response.user!.id);

      if (!userModel.isActive) {
        throw Exception('الحساب معطل. يرجى التواصل مع الدعم الفني');
      }

      await _client.from('profiles').update({
        'last_login': DateTime.now().toIso8601String(),
        'login_count': (userData['login_count'] ?? 0) + 1,
      }).eq('id', response.user!.id);

      return userModel;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseAuthService] خطأ في تسجيل الدخول: $e');
      throw Exception(e.toString());
    }
  }

  Future<UserModel> register(UserModel user, String password, {File? storeImage}) async {
    try {
      final response = await _client.auth.signUp(
        email: user.email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('فشل في إنشاء الحساب');
      }

      String? storeImageUrl;
      if (storeImage != null) {
        final imagePath = 'store_images/${response.user!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from('store_images').upload(imagePath, storeImage);
        storeImageUrl = _client.storage.from('store_images').getPublicUrl(imagePath);
      }

      final userData = {
        'id': response.user!.id,
        'email': user.email,
        'name': user.name,
        'phone': user.phone,
        'type': user.type.toString().split('.').last,
        'is_active': true,
        'store_image_url': storeImageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'store_id': user.storeId ?? response.user!.id,
      };

      await _client.from('profiles').insert([userData]);

      return UserModel.fromMap(userData, id: response.user!.id);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseAuthService] ف��ل إنشاء الحساب: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseAuthService] خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('فشل إرسال رابط إعادة تعيين كلمة المرور');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('فشل تحديث كلمة المرور');
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
