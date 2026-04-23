library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/captain_model.dart';
import '../core/logger.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _defaultTimeout = Duration(seconds: 10);

  static String _sanitizeSelfSignupRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    if (normalized == 'merchant') return 'merchant';
    return 'client';
  }

  static Exception _networkException(String action, Object error) {
    if (error is TimeoutException) {
      return Exception(
        'انتهت مهلة الاتصال أثناء $action. تأكد من اتصال الإنترنت ثم أعد المحاولة.',
      );
    }

    if (error.toString().contains('SocketException')) {
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
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Sign in network error', e);
        throw _networkException('تسجيل الدخول', e);
      }
      rethrow;
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
      final safeUserType = _sanitizeSelfSignupRole(userType);

      final response = await _client.auth
          .signUp(
            email: email,
            password: password,
            emailRedirectTo: 'elltallmarket://auth/callback',
            data: {
              'full_name': name,
              'phone': phone,
              'role': safeUserType,
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
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Sign up network error', e);
        throw _networkException('إنشاء الحساب', e);
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(_defaultTimeout);
      AppLogger.info('Signed out');
    } on TimeoutException catch (e) {
      AppLogger.error('Sign out timeout', e);
      throw _networkException('تسجيل الخروج', e);
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Sign out network error', e);
        throw _networkException('تسجيل الخروج', e);
      }
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
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Reset password network error', e);
        throw _networkException('إرسال رابط استعادة كلمة المرور', e);
      }
      AppLogger.error('Password reset error', e);
      rethrow;
    }
  }

  static Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    // Retry logic: محاولة 3 مرات مع backoff
    const maxAttempts = 3;
    var delay = const Duration(milliseconds: 500);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 12));

        if (response == null) return null;
        return ProfileModel.fromMap(response);
      } on PostgrestException catch (e) {
        // خطأ من الخادم (RLS, schema mismatch, إلخ) - لا نعيد المحاولة
        AppLogger.error(
          'Get profile Postgrest error: ${e.message} (${e.code})',
          e,
        );
        return null;
      } on TimeoutException catch (e) {
        AppLogger.warning(
          'Get profile timeout (attempt $attempt/$maxAttempts)',
          e,
        );
        if (attempt >= maxAttempts) {
          return null; // بدل رمي الخطأ
        }
      } catch (e) {
        if (e.toString().contains('SocketException')) {
          AppLogger.warning(
            'Get profile network error (attempt $attempt/$maxAttempts)',
            e,
          );
          if (attempt >= maxAttempts) {
            return null;
          }
        } else {
          AppLogger.error('Get profile error', e);
          return null;
        }
      }

      // انتظر قبل المحاولة التالية (exponential backoff)
      await Future<void>.delayed(delay);
      delay = Duration(milliseconds: (delay.inMilliseconds * 2).toInt());
    }

    return null;
  }

  /// Ensures a `profiles` row exists for the currently authenticated user.
  ///
  /// This is useful when the DB trigger isn't present or when OAuth sign-in
  /// doesn't create a profile automatically.
  static Future<bool> ensureCurrentProfileExists() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // ملاحظة: في بعض حالات تأكيد البريد/Code Exchange قد يحدث تأخير بسيط
      // قبل أن يظهر سجل المستخدم في auth.users مما يسبب FK 23503.
      // لذلك نعيد المحاولة عدة مرات بشكل آمن.
      const maxAttempts = 4;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        final current = _client.auth.currentUser;
        if (current == null) return false;

        final existing = await _client
            .from('profiles')
            .select('id')
            .eq('id', current.id)
            .maybeSingle()
            .timeout(_defaultTimeout);

        if (existing != null) return true;

        final metadata = current.userMetadata ?? const <String, dynamic>{};
        final payload = <String, dynamic>{
          'id': current.id,
          'email': current.email,
          'full_name': metadata['full_name'] ?? metadata['name'],
          'phone': metadata['phone'],
          'role': _sanitizeSelfSignupRole(metadata['role']?.toString()),
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          await _client
              .from('profiles')
              .upsert(payload, onConflict: 'id')
              .timeout(_defaultTimeout);
          AppLogger.info(
            '✅ Created missing profile row for user: ${current.id} (attempt $attempt/$maxAttempts)',
          );
          return true;
        } on PostgrestException catch (e) {
          // FK violation: profiles.id references auth.users(id)
          if (e.code == '23503' && attempt < maxAttempts) {
            AppLogger.warning(
              '⏳ Profile upsert FK (23503). Retrying... ($attempt/$maxAttempts)',
              e,
            );
            await Future.delayed(Duration(milliseconds: 600 * attempt));
            continue;
          }
          rethrow;
        }
      }

      return false;
    } on PostgrestException catch (e) {
      AppLogger.error(
        'Ensure profile Postgrest error: ${e.message} (${e.code})',
        e,
      );
      return false;
    } on TimeoutException catch (e) {
      AppLogger.error('Ensure profile timeout', e);
      return false;
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Ensure profile network error', e);
        return false;
      }
      AppLogger.error('Ensure profile error', e);
      return false;
    }
  }

  /// Upload avatar image to Supabase Storage
  static Future<String?> uploadAvatar(dynamic imageFile, String userId) async {
    try {
      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'avatars/user_$userId/avatar_$timestamp.$fileExt';

      await _client.storage
          .from('profiles')
          .upload(filePath, imageFile)
          .timeout(_defaultTimeout);

      final publicUrl = _client.storage.from('profiles').getPublicUrl(filePath);
      AppLogger.info('Avatar uploaded: $publicUrl');
      return publicUrl;
    } on TimeoutException catch (e) {
      AppLogger.error('Upload avatar timeout', e);
      throw _networkException('رفع الصورة', e);
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Upload avatar network error', e);
        throw _networkException('رفع الصورة', e);
      }
      AppLogger.error('Upload avatar error', e);
      return null;
    }
  }

  /// Upload avatar from bytes (Web compatible)
  static Future<String?> uploadAvatarBytes({
    required Uint8List imageBytes,
    required String fileName,
    required String userId,
  }) async {
    try {
      final fileExt = fileName.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'avatars/user_$userId/avatar_$timestamp.$fileExt';

      await _client.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          )
          .timeout(_defaultTimeout);

      final publicUrl = _client.storage.from('profiles').getPublicUrl(filePath);
      AppLogger.info('Avatar bytes uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      AppLogger.error('Upload avatar bytes error', e);
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
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        AppLogger.error('Update profile network error', e);
        throw _networkException('تحديث الملف الشخصي', e);
      }
      AppLogger.error('Update profile error', e);
      return false;
    }
  }

  static User? getCurrentUser() => _client.auth.currentUser;
  static Session? getCurrentSession() => _client.auth.currentSession;
  static bool get isLoggedIn => _client.auth.currentUser != null;

  /// جلب بيانات الكابتن من جدول captains
  static Future<CaptainModel?> getCaptain(String userId) async {
    try {
      final response = await _client
          .from('captains')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(_defaultTimeout);

      if (response == null) return null;
      return CaptainModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Get captain error', e);
      return null;
    }
  }

  /// تحديث حالة الكابتن (متصل/غير متصل) ووقت التوفر في جدول captains
  static Future<bool> updateCaptainStatus(String userId, String status) async {
    try {
      final isOnline = status == 'online' || status == 'active';
      await _client
          .from('captains')
          .update({
            'status': status,
            'is_online': isOnline,
            'is_available': isOnline,
            'last_available_at': isOnline
                ? DateTime.now().toIso8601String()
                : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .timeout(_defaultTimeout);

      AppLogger.info('Captain status updated: $status (is_online: $isOnline)');
      return true;
    } catch (e) {
      AppLogger.error('Update captain status error', e);
      return false;
    }
  }

  /// جلب الكابتن الأنسب للطلب (متاح + أقدم وقت انتظار) من جدول captains
  static Future<CaptainModel?> getPriorityCaptain() async {
    try {
      final response = await _client
          .from('captains')
          .select()
          .or('status.eq.online,status.eq.active')
          .order(
            'last_available_at',
            ascending: true,
          ) // الأقدم أولاً (الأكثر انتظاراً)
          .limit(1)
          .maybeSingle()
          .timeout(_defaultTimeout);

      if (response == null) return null;
      return CaptainModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Get priority captain error', e);
      return null;
    }
  }
}
