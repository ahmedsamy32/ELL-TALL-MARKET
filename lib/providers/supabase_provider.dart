/// Supabase Provider - Authentication State Management
/// Works with Profile_model.dart and supabase_service.dart
/// Manages authentication state and user sessions
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Profile_model.dart';
import '../services/supabase_service.dart';
import '../core/logger.dart';

/// SupabaseProvider - manages authentication state
class SupabaseProvider with ChangeNotifier {
  ProfileModel? _currentProfile;
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  ProfileModel? get currentProfile => _currentProfile;
  ProfileModel? get currentUserProfile =>
      _currentProfile; // Alias for compatibility
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorMessage => _error; // Alias for compatibility
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _authSubscription != null;
  bool get isAdmin => _currentProfile?.role == UserRole.admin;
  bool get isMerchant => _currentProfile?.role == UserRole.merchant;
  bool get isCaptain => _currentProfile?.role == UserRole.captain;
  bool get isClient => _currentProfile?.role == UserRole.client;

  /// Stream of auth state changes - exposes the current user
  Stream<User?> get authStateChanges => Supabase
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user);

  // For admin screens that manage all users
  List<ProfileModel> _allUsers = [];
  List<ProfileModel> get allUsers => _allUsers;
  List<ProfileModel> get profiles => _allUsers; // Alias for compatibility

  /// Initialize provider and auth listener
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current user
      _currentUser = SupabaseService.getCurrentUser();

      // Listen to auth changes FIRST (أسرع)
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            _handleAuthStateChange(data);
          });

      AppLogger.info('SupabaseProvider initialized successfully');

      // تحميل البيانات في الخلفية بعد فتح التطبيق
      if (_currentUser != null) {
        // Load profile in background without blocking
        _loadProfile()
            .timeout(
              Duration(seconds: 3),
              onTimeout: () {
                AppLogger.warning('Profile load timeout');
              },
            )
            .catchError((e) {
              AppLogger.warning('Profile load error: $e');
            });
      }
    } catch (e) {
      _error = 'Initialization error: $e';
      AppLogger.error('Init error', e);
      // Continue anyway - create minimal subscription
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            _handleAuthStateChange(data);
          });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user profile with retry
  Future<void> _loadProfile() async {
    try {
      AppLogger.debug('🔄 Attempting to load profile...');
      _currentProfile = await SupabaseService.getCurrentProfile().timeout(
        Duration(seconds: 5),
      );
      AppLogger.info('✅ Profile loaded: ${_currentProfile?.fullName}');
      notifyListeners(); // Update UI after profile loads
    } catch (e) {
      AppLogger.error('❌ Load profile error', e);

      // إذا فشل التحميل، نحاول مرة أخرى بعد ثانيتين
      AppLogger.info('🔄 Retrying profile load in 2 seconds...');
      await Future.delayed(Duration(seconds: 2));

      try {
        _currentProfile = await SupabaseService.getCurrentProfile().timeout(
          Duration(seconds: 5),
        );
        AppLogger.info(
          '✅ Profile loaded on retry: ${_currentProfile?.fullName}',
        );
        notifyListeners();
      } catch (retryError) {
        AppLogger.warning('⚠️ Profile load failed after retry: $retryError');
        _currentProfile = null;
        notifyListeners();
      }
    }
  }

  /// Handle auth state changes
  void _handleAuthStateChange(AuthState authState) async {
    AppLogger.debug('Auth state changed: ${authState.event}');

    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        _currentUser = authState.session?.user;
        _isLoading = false; // Clear loading state
        _error = null; // Clear any previous errors
        AppLogger.info('✅ User signed in: ${_currentUser?.email}');
        notifyListeners(); // Update UI immediately
        // Load profile in background
        _loadProfile();
        break;
      case AuthChangeEvent.signedOut:
        _currentUser = null;
        _currentProfile = null;
        _isLoading = false;
        _error = null;
        AppLogger.info('User signed out');
        notifyListeners();
        break;
      case AuthChangeEvent.userUpdated:
        _currentUser = authState.session?.user;
        notifyListeners();
        _loadProfile();
        break;
      case AuthChangeEvent.tokenRefreshed:
        _currentUser = authState.session?.user;
        notifyListeners();
        break;
      default:
        notifyListeners();
        break;
    }
  }

  /// Sign in
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response?.user != null) {
        _currentUser = response!.user;
        await _loadProfile();
        return true;
      }

      _error = 'Sign in failed';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String userType = 'client',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        userType: userType,
      );

      if (response?.user != null) {
        _currentUser = response!.user;
        return true;
      }

      _error = 'Sign up failed';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.signOut();
      _currentUser = null;
      _currentProfile = null;
    } catch (e) {
      _error = 'Sign out error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await SupabaseService.resetPassword(email);
      return true;
    } catch (e) {
      _error = 'Reset password error: $e';
      return false;
    }
  }

  /// Update profile
  Future<bool> updateProfile(ProfileModel profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await SupabaseService.updateProfile(profile);
      if (success) {
        _currentProfile = profile;
      }
      return success;
    } catch (e) {
      _error = 'Update profile error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh profile
  Future<void> refreshProfile() async {
    if (_currentUser != null) {
      await _loadProfile();
      notifyListeners();
    }
  }

  /// Fetch all users (for admin)
  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final list = response as List;
      _allUsers = list.map((item) => ProfileModel.fromMap(item)).toList();
      AppLogger.info('Fetched ${_allUsers.length} users');
    } catch (e) {
      _error = 'Error fetching users: $e';
      AppLogger.error('Fetch users error', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google using Supabase Auth
  /// Note: This launches the OAuth flow in external browser.
  /// The actual sign-in happens when the deep link callback is processed.
  /// Listen to auth state changes to detect when sign-in completes.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Starting Google Sign In...');

      // استخدام Supabase Native Google Sign In
      // signInWithOAuth يفتح المتصفح ويرجع true/false فوراً (ليس await للمصادقة)
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'elltallmarket://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _error = 'فشل فتح متصفح Google للمصادقة';
        AppLogger.warning('Google Sign In browser launch failed');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      AppLogger.info('✅ Google OAuth browser launched successfully');
      AppLogger.info(
        '⏳ Waiting for user to complete authentication in browser...',
      );

      // المصادقة ستكتمل عبر deep link callback
      // وسيتم التعامل معها من خلال _handleAuthStateChange
      // لذلك نرجع true لنشير أن المتصفح فتح بنجاح

      // Note: Loading state will be cleared by auth state listener
      // when sign-in completes or after timeout

      return true; // Browser opened successfully
    } catch (e, st) {
      _error = 'حدث خطأ في تسجيل الدخول بواسطة Google: $e';
      AppLogger.error('Google Sign In error', e, st);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Facebook (placeholder)
  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement Facebook Sign In with Supabase
      // await SupabaseService.signInWithFacebook();
      _error = 'Facebook Sign In قيد التطوير';
      return false;
    } catch (e) {
      _error = 'Facebook Sign In error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send password reset email (simple version)
  Future<bool> sendPasswordResetEmailSimple(String email) async {
    return await resetPassword(email);
  }

  /// Update password with Supabase
  Future<bool> updatePasswordWithSupabase(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      _error = 'Update password error: $e';
      AppLogger.error('Update password error', e);
      return false;
    }
  }

  /// Verify password reset token (placeholder)
  Future<bool> verifyPasswordResetToken(String token) async {
    // Supabase handles token verification internally
    return true;
  }

  /// Resend email confirmation (placeholder)
  Future<void> resendEmailConfirmationSimple(String email) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.email,
        email: email,
      );
    } catch (e) {
      _error = 'Resend confirmation error: $e';
      AppLogger.error('Resend confirmation error', e);
      throw e;
    }
  }

  /// Check email verification status (simplified)
  Future<String> checkEmailVerificationStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'not_signed_in';

    // Check if email is confirmed
    final emailConfirmed = user.emailConfirmedAt != null;
    return emailConfirmed ? 'verified' : 'pending';
  }

  /// Silent sign in (auto sign in if session exists)
  Future<bool> silentSignIn() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _currentUser = session.user;
      await _loadProfile();
      return true;
    }
    return false;
  }

  /// Register with email verification (enhanced sign up)
  Future<String> registerWithEmailVerification({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        name: fullName,
        phone: phone,
        userType: userType,
      );

      if (response?.user != null) {
        _currentUser = response!.user;

        // Check if email confirmation is required
        final emailConfirmed = response.user?.emailConfirmedAt != null;

        if (emailConfirmed) {
          await _loadProfile();
          return 'success';
        } else {
          return 'successPendingVerification';
        }
      }

      return 'error';
    } catch (e) {
      _error = 'Registration error: $e';

      if (e.toString().contains('already registered')) {
        return 'emailAlreadyExists';
      } else if (e.toString().contains('weak password')) {
        return 'weakPassword';
      } else if (e.toString().contains('invalid email')) {
        return 'invalidEmail';
      } else if (e.toString().contains('network')) {
        return 'networkError';
      }

      return 'error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
