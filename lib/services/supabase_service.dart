library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../core/logger.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _defaultTimeout = Duration(seconds: 10);

  static Exception _networkException(String action, Object error) {
    if (error is TimeoutException) {
      return Exception(
        'انتهت مهلة الاتصال أثناء $action. تأكد من اتصال الإنترنت ثم أعد المحاولة.',
      );
    }

    if (error is SocketException) {
      return Exception(
        'تعذر الوصول إلى الخادم أثناء $action. تحقق من الشبكة أو إعدادات DNS ثم أعد المحاولة.',
      );
    }

    return Exception('خطأ في الاتصال أثناء $action: $error');
  }

  static Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_defaultTimeout);
      if (response.user != null) {
        AppLogger.info('Signed in: ${response.user!.email}');
      }
      return response;
    } on AuthException catch (e) {
      AppLogger.error('Sign in error', e);
      // Re-throw to allow caller to handle specific errors (like email_not_confirmed)
      rethrow;
    } on TimeoutException catch (e) {
      AppLogger.error('Sign in timeout', e);
      throw _networkException('تسجيل الدخول', e);
    } on SocketException catch (e) {
      AppLogger.error('Sign in network error', e);
      throw _networkException('تسجيل الدخول', e);
    }
  }

  static Future<AuthResponse?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String userType = 'client',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final response = await _client.auth
          .signUp(
            email: email,
            password: password,
            emailRedirectTo: 'elltallmarket://auth/callback',
            data: {
              'full_name': name,
              'phone': phone,
              'role': userType,
              ...?additionalData,
            },
          )
          .timeout(_defaultTimeout);
      if (response.user != null) {
        AppLogger.info('New account: ${response.user!.email}');
      }
      return response;
    } on AuthException catch (e) {
      AppLogger.error('Sign up error', e);
      rethrow; // إعادة رمي الخطأ للمعالجة في الطبقة الأعلى
    } on TimeoutException catch (e) {
      AppLogger.error('Sign up timeout', e);
      throw _networkException('إنشاء الحساب', e);
    } on SocketException catch (e) {
      AppLogger.error('Sign up network error', e);
      throw _networkException('إنشاء الحساب', e);
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(_defaultTimeout);
      AppLogger.info('Signed out');
    } on TimeoutException catch (e) {
      AppLogger.error('Sign out timeout', e);
      throw _networkException('تسجيل الخروج', e);
    } on SocketException catch (e) {
      AppLogger.error('Sign out network error', e);
      throw _networkException('تسجيل الخروج', e);
    } catch (e) {
      AppLogger.error('Sign out error', e);
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(
            email,
            redirectTo: 'elltallmarket://auth/callback',
          )
          .timeout(_defaultTimeout);
      AppLogger.info('Password reset email sent');
    } on TimeoutException catch (e) {
      AppLogger.error('Reset password timeout', e);
      throw _networkException('إرسال رابط استعادة كلمة المرور', e);
    } on SocketException catch (e) {
      AppLogger.error('Reset password network error', e);
      throw _networkException('إرسال رابط استعادة كلمة المرور', e);
    } catch (e) {
      AppLogger.error('Password reset error', e);
      rethrow;
    }
  }

  static Future<ProfileModel?> getCurrentProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_defaultTimeout);

      if (response == null) return null;
      return ProfileModel.fromMap(response);
    } on TimeoutException catch (e) {
      AppLogger.error('Get profile timeout', e);
      throw _networkException('جلب الملف الشخصي', e);
    } on SocketException catch (e) {
      AppLogger.error('Get profile network error', e);
      throw _networkException('جلب الملف الشخصي', e);
    } catch (e) {
      AppLogger.error('Get profile error', e);
      return null;
    }
  }

  /// Upload avatar image to Supabase Storage
  static Future<String?> uploadAvatar(File imageFile, String userId) async {
    try {
      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // تسمية واضحة: avatars/user_{userId}/avatar_{timestamp}.{ext}
      // مثال: avatars/user_abc123/avatar_1702345678901.jpg
      final filePath = 'avatars/user_$userId/avatar_$timestamp.$fileExt';

      // Upload file to Supabase Storage
      await _client.storage
          .from('profiles')
          .upload(filePath, imageFile)
          .timeout(_defaultTimeout);

      // Get public URL
      final publicUrl = _client.storage.from('profiles').getPublicUrl(filePath);

      AppLogger.info('Avatar uploaded: $publicUrl');
      return publicUrl;
    } on TimeoutException catch (e) {
      AppLogger.error('Upload avatar timeout', e);
      throw _networkException('رفع الصورة', e);
    } on SocketException catch (e) {
      AppLogger.error('Upload avatar network error', e);
      throw _networkException('رفع الصورة', e);
    } catch (e) {
      AppLogger.error('Upload avatar error', e);
      return null;
    }
  }

  static Future<bool> updateProfile(ProfileModel profile) async {
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': profile.fullName,
            'phone': profile.phone,
            'avatar_url': profile.avatarUrl,
            'birth_date': profile.birthDate?.toIso8601String().split('T')[0],
            'gender': profile.gender,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile.id)
          .timeout(_defaultTimeout);

      AppLogger.info('Profile updated');
      return true;
    } on TimeoutException catch (e) {
      AppLogger.error('Update profile timeout', e);
      throw _networkException('تحديث الملف الشخصي', e);
    } on SocketException catch (e) {
      AppLogger.error('Update profile network error', e);
      throw _networkException('تحديث الملف الشخصي', e);
    } catch (e) {
      AppLogger.error('Update profile error', e);
      return false;
    }
  }

  static User? getCurrentUser() => _client.auth.currentUser;
  static Session? getCurrentSession() => _client.auth.currentSession;
  static bool get isLoggedIn => _client.auth.currentUser != null;
}
