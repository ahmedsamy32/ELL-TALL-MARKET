library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../core/logger.dart';
import 'merchant_provider.dart';
import 'product_provider.dart';
import 'order_provider.dart';

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
        // زودنا الـ timeout لـ 10 ثواني لأن الاتصال قد يكون بطيء
        _loadProfile()
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                AppLogger.warning('Profile load timeout after 10 seconds');
                return Future.value(); // نرجع Future فاضية بدل من null
              },
            )
            .catchError((e) {
              AppLogger.warning('Profile load error: $e');
              return Future.value(); // نرجع Future فاضية عشان ميعملش crash
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

      // تحقق من وجود user قبل المحاولة
      if (_currentUser == null) {
        AppLogger.warning('⚠️ No user to load profile for');
        return;
      }

      _currentProfile = await SupabaseService.getCurrentProfile().timeout(
        Duration(seconds: 8), // زودنا الـ timeout
        onTimeout: () {
          AppLogger.warning('⚠️ Profile load timed out after 8 seconds');
          return null;
        },
      );
      if (_currentProfile != null) {
        AppLogger.info('✅ Profile loaded: ${_currentProfile?.fullName}');
      } else {
        AppLogger.warning('⚠️ Profile data unavailable after load attempt');
      }
      notifyListeners(); // Update UI after profile loads
    } catch (e) {
      AppLogger.error('❌ Load profile error', e);

      // إذا فشل التحميل، نحاول مرة أخرى بعد ثانيتين (فقط لو المستخدم موجود)
      if (_currentUser != null) {
        AppLogger.info('🔄 Retrying profile load in 2 seconds...');
        await Future.delayed(Duration(seconds: 2));

        try {
          _currentProfile = await SupabaseService.getCurrentProfile().timeout(
            Duration(seconds: 8),
            onTimeout: () {
              AppLogger.warning(
                '⚠️ Profile load retry timed out after 8 seconds',
              );
              return null;
            },
          );
          if (_currentProfile != null) {
            AppLogger.info(
              '✅ Profile loaded on retry: ${_currentProfile?.fullName}',
            );
          } else {
            AppLogger.warning('⚠️ Profile data still unavailable after retry');
          }
          notifyListeners();
        } catch (retryError) {
          AppLogger.warning('⚠️ Profile load failed after retry: $retryError');
          _currentProfile = null;
          notifyListeners();
        }
      } else {
        AppLogger.warning('⚠️ User logged out during profile load');
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
    } on AuthException catch (e) {
      // Store the specific error message so login_screen can check it
      _error = e.message;
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
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String userType = 'client',
    String? storeName,
    String? storeAddress,
    String? storeDescription,
    String? category,
    String? storeLogoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // إعداد البيانات الإضافية للتاجر
      Map<String, dynamic>? additionalData;
      if (userType == 'merchant' && storeName != null) {
        additionalData = {
          'store_name': storeName,
          'store_address': storeAddress,
          'store_description': storeDescription,
        };

        // إضافة الفئة إذا تم تحديدها
        if (category != null && category.isNotEmpty) {
          additionalData['category'] = category;
        }

        // إضافة رابط شعار المتجر إن وُجد
        if (storeLogoUrl != null && storeLogoUrl.isNotEmpty) {
          additionalData['store_logo_url'] = storeLogoUrl;
        }
      }

      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        userType: userType,
        additionalData: additionalData,
      );

      if (response?.user != null) {
        _currentUser = response!.user;
        return response;
      }

      _error = 'Sign up failed';
      return null;
    } on AuthException catch (e) {
      // معالجة أخطاء Supabase Auth
      _error = e.message;
      rethrow; // إعادة رمي الخطأ للمعالجة في الشاشة
    } catch (e) {
      _error = 'Error: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out - clears all provider data to prevent data leakage
  Future<void> signOut({
    MerchantProvider? merchantProvider,
    ProductProvider? productProvider,
    OrderProvider? orderProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Sign out from Supabase
      await SupabaseService.signOut();

      // Clear authentication data
      _currentUser = null;
      _currentProfile = null;

      // Clear all business data providers to prevent data leakage
      merchantProvider?.clearData();
      productProvider?.clearProducts();
      orderProvider?.clearOrders();

      AppLogger.info('✅ Signed out and cleared all provider data');
    } catch (e) {
      _error = 'Sign out error: $e';
      AppLogger.error('❌ Sign out error', e);
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

  /// Upload avatar image
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      if (_currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }
      return await SupabaseService.uploadAvatar(imageFile, _currentUser!.id);
    } catch (e) {
      _error = 'Upload avatar error: $e';
      return null;
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
    // Prevent multiple simultaneous calls
    if (_isLoading) return;

    _isLoading = true;
    _error = null; // Clear previous errors
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
  Future<bool> signInWithGoogle({String userType = 'client'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Starting Google Sign In for userType: $userType');

      // استخدام Supabase Native Google Sign In
      // signInWithOAuth يفتح المتصفح ويرجع true/false فوراً (ليس await للمصادقة)
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'elltallmarket://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
        // ⚠️ ملاحظة: لا يمكن إرسال metadata مع OAuth!
        // الحل: سنستخدم pending merchants table أو update بعد تسجيل الدخول
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
      // Note: Implement Facebook Sign In with Supabase
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
      rethrow;
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

  /// Delete user account
  Future<({bool success, String? message})> deleteUser(String userId) async {
    try {
      AppLogger.info('🔄 Attempting to delete user: $userId');

      // Delete from profiles table (RLS policy will check if current user is admin)
      await Supabase.instance.client.from('profiles').delete().eq('id', userId);

      AppLogger.info('✅ User deleted successfully');
      return (success: true, message: null);
    } catch (e) {
      AppLogger.error('❌ Delete user error', e);

      // Check if error is due to RLS policy
      if (e.toString().contains('row-level security') ||
          e.toString().contains('policy')) {
        return (
          success: false,
          message:
              'فشل الحذف - لا تمتلك صلاحيات الحذف. تأكد من أنك مسجل كمدير في النظام.',
        );
      }

      return (success: false, message: 'خطأ في الحذف: ${e.toString()}');
    }
  }

  /// Update preferred payment method
  Future<void> updatePreferredPayment(String paymentMethod) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'preferred_payment': paymentMethod})
          .eq('id', _currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = 'Update payment error: $e';
      AppLogger.error('Update payment error', e);
    }
  }

  /// Add new user (for admin)
  /// Note: This uses a workaround since Admin API requires Service Role Key
  Future<String?> addUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Starting user creation: $email');

      // Check if admin is authenticated
      final adminUser = Supabase.instance.client.auth.currentUser;
      if (adminUser == null) {
        _error = 'Admin user not authenticated';
        AppLogger.error('Add user error', Exception(_error));
        return null;
      }

      AppLogger.info('✅ Admin authenticated: ${adminUser.email}');

      // WORKAROUND: Use regular signup with metadata
      // The is_admin() function will allow the profile insertion
      AppLogger.info('🔄 Creating user account...');

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': role.name},
      );

      if (authResponse.user == null) {
        _error = 'Failed to create user account - no user returned';
        AppLogger.error('Add user error', Exception(_error));
        return null;
      }

      final newUserId = authResponse.user!.id;
      AppLogger.info('✅ Auth user created: $newUserId');

      // Wait a bit for the trigger to create the profile
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify/update the profile with admin-specified role
      final profileData = {
        'id': newUserId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      AppLogger.info('🔄 Upserting profile data with role: ${role.name}');

      // Use upsert to update if trigger already created it
      await Supabase.instance.client
          .from('profiles')
          .upsert(profileData, onConflict: 'id');

      AppLogger.info('✅ Profile created/updated successfully');
      AppLogger.info('✅ New user added: $email with ID: $newUserId');

      // Refresh users list
      await fetchAllUsers();

      return newUserId;
    } on AuthException catch (e) {
      _error = 'Authentication error: ${e.message}';
      AppLogger.error('Auth error adding user', e);
      return null;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message} (${e.code})';
      AppLogger.error('Database error adding user', e);
      return null;
    } catch (e) {
      _error = 'Error adding user: $e';
      AppLogger.error('Add user error', e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user by admin
  Future<bool> updateUserByAdmin({
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
    String? password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Update profile data
      final profileData = {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('profiles')
          .update(profileData)
          .eq('id', userId);

      // 2. If password provided, update it using admin API
      if (password != null && password.isNotEmpty) {
        await Supabase.instance.client.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(password: password),
        );
      }

      AppLogger.info('User updated: $email');

      // 3. Refresh users list
      await fetchAllUsers();

      return true;
    } catch (e) {
      _error = 'Error updating user: $e';
      AppLogger.error('Update user error', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle user active status
  Future<bool> toggleUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('User status toggled: $userId -> $isActive');

      // Refresh users list
      await fetchAllUsers();

      return true;
    } catch (e) {
      _error = 'Error toggling user status: $e';
      AppLogger.error('Toggle user status error', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  // Defers notifications during build phases to avoid triggering build errors.
  void notifyListeners() {
    if (!hasListeners) {
      return;
    }

    final scheduler = SchedulerBinding.instance;
    final phase = scheduler.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      super.notifyListeners();
    } else {
      scheduler.addPostFrameCallback((_) {
        if (hasListeners) {
          super.notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
