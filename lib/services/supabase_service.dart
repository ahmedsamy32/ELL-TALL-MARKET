/// Supabase Service - Authentication and Profile Services
/// Works with Profile_model.dart and supabase_provider.dart
/// Following Supabase Dart SDK: https://supabase.com/docs/reference/dart/introduction
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Profile_model.dart';
import '../core/logger.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        AppLogger.info('Signed in: ${response.user!.email}');
      }
      return response;
    } on AuthException catch (e) {
      AppLogger.error('Sign in error', e);
      return null;
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
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'elltallmarket://auth/callback',
        data: {
          'full_name': name,
          'phone': phone,
          'role': userType,
          ...?additionalData,
        },
      );
      if (response.user != null) {
        AppLogger.info('New account: ${response.user!.email}');
      }
      return response;
    } on AuthException catch (e) {
      AppLogger.error('Sign up error', e);
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      AppLogger.info('Signed out');
    } catch (e) {
      AppLogger.error('Sign out error', e);
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'elltallmarket://auth/callback',
      );
      AppLogger.info('Password reset email sent');
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
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Get profile error', e);
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
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile.id);

      AppLogger.info('Profile updated');
      return true;
    } catch (e) {
      AppLogger.error('Update profile error', e);
      return false;
    }
  }

  static User? getCurrentUser() => _client.auth.currentUser;
  static Session? getCurrentSession() => _client.auth.currentSession;
  static bool get isLoggedIn => _client.auth.currentUser != null;
}
