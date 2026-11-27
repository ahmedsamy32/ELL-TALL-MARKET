library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../core/logger.dart';
import 'merchant_provider.dart';
import 'product_provider.dart';
import 'order_provider.dart';
import 'notification_provider.dart';
import '../services/notification_service.dart';
import '../services/google_signin_service.dart';

/// SupabaseProvider - manages authentication state
class SupabaseProvider with ChangeNotifier {
  ProfileModel? _currentProfile;
  User? _currentUser;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isProfileMissing = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _sessionExpiry;
  int _identityVersion = 0;
  String? _recoveryUserId;
  String? get recoveryUserId => _recoveryUserId;
  Future<void>? _profileRequest;

  ProfileModel? get currentProfile => _currentProfile;
  ProfileModel? get currentUserProfile =>
      _currentProfile; // Alias for compatibility
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading;
  bool get isProfileMissing => _isProfileMissing;
  String? get error => _error;
  String? get errorMessage => _error; // Alias for compatibility
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _authSubscription != null;
  bool get isAdmin => _currentProfile?.role == UserRole.admin;
  bool get isDeliveryCompanyAdmin =>
      _currentProfile?.role == UserRole.deliveryCompanyAdmin;
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

  SupabaseClient get client => Supabase.instance.client;

  // For admin screens that manage all users
  List<ProfileModel> _allUsers = [];
  List<ProfileModel> get allUsers => _allUsers;
  List<ProfileModel> get profiles => _allUsers; // Alias for compatibility

  /// Initialize provider and auth listener
  Future<void> initialize() async {
    if (isInitialized) return;
    final auth = Supabase.instance.client.auth;
    _authSubscription = auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (Object error) {
        AppLogger.warning('Auth session update failed: $error');
        _syncSession(auth.currentSession);
        notifyListeners();
      },
    );
    _syncSession(auth.currentSession);
    if (_currentUser != null) unawaited(_loadProfile());
    notifyListeners();
  }

  void _syncSession(Session? session) {
    _sessionExpiry?.cancel();
    final expiresAt = session?.expiresAt;
    final remaining = expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
          ).difference(DateTime.now());
    User? user;
    if (session != null &&
        !session.user.isAnonymous &&
        remaining != null &&
        remaining > Duration.zero) {
      user = session.user;
    }
    if (user?.id != _currentUser?.id) {
      _identityVersion++;
      _recoveryUserId = null;
      _allUsers = [];
      _currentProfile = null;
      _profileRequest = null;
      _isProfileLoading = false;
      _isProfileMissing = false;
    }
    _currentUser = user;
    if (user != null) {
      _sessionExpiry = Timer(remaining!, () {
        _syncSession(Supabase.instance.client.auth.currentSession);
        notifyListeners();
      });
    }
  }

  // Wait for an in-flight load of the same identity. A previous user's result
  // must never be published after sign-out or a switch to another account.
  Future<void> _loadProfile() {
    final user = _currentUser;
    if (user == null) return Future.value();
    final pending = _profileRequest;
    if (pending != null) return pending;
    final version = _identityVersion;
    final done = Completer<void>();
    _profileRequest = done.future;
    _isProfileLoading = true;
    _isProfileMissing = false;
    notifyListeners();

    Future<void> load() async {
      try {
        var profile = await SupabaseService.getCurrentProfile();
        if (version != _identityVersion) return;
        if (profile == null &&
            await SupabaseService.ensureCurrentProfileExists()) {
          if (version != _identityVersion) return;
          profile = await SupabaseService.getCurrentProfile();
        }
        if (version != _identityVersion) return;
        _currentProfile = profile?.id == user.id ? profile : null;
      } catch (e) {
        if (version == _identityVersion) _currentProfile = null;
        AppLogger.warning('Profile load failed: $e');
      } finally {
        if (version == _identityVersion) {
          _profileRequest = null;
          _isProfileLoading = false;
          _isProfileMissing = _currentProfile == null;
          notifyListeners();
        }
        done.complete();
      }
    }

    unawaited(load());
    return done.future;
  }

  /// Force refresh the current profile from the `profiles` table.
  Future<void> refreshCurrentProfile() async {
    await _loadProfile();
  }

  /// Handle auth state changes
  void _handleAuthStateChange(AuthState state) {
    _syncSession(state.session);
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _recoveryUserId = _currentUser?.id;
    }
    if (state.event == AuthChangeEvent.signedIn && _currentUser != null) {
      _error = null;
      unawaited(_loadProfileThenSaveToken());
    } else if (_currentUser != null &&
        (_currentProfile == null ||
            state.event == AuthChangeEvent.userUpdated ||
            state.event == AuthChangeEvent.tokenRefreshed)) {
      unawaited(_loadProfile());
    }
    notifyListeners();
  }

  /// Load profile then save FCM device token with correct role
  Future<void> _loadProfileThenSaveToken() async {
    try {
      final version = _identityVersion;
      await _loadProfile();

      if (version != _identityVersion || _currentUser == null) return;
      await _saveDeviceTokenAfterAuth();
    } catch (e) {
      AppLogger.warning('⚠️ Profile load or token save failed: $e');
    }
  }

  /// Save FCM device token after authentication with correct role
  Future<void> _saveDeviceTokenAfterAuth() async {
    try {
      // Always save as 'client' first (every user is at minimum a client)
      await NotificationServiceEnhanced.instance.saveTokenForCurrentUser(
        role: 'client',
      );

      // Profile should be loaded by now — save for their specific role
      if (_currentProfile != null) {
        final role = _currentProfile!.role;
        AppLogger.info('🔑 Saving device token for role: $role');
        if (role == UserRole.admin) {
          await NotificationServiceEnhanced.instance.saveTokenForCurrentUser(
            role: 'admin',
          );
        } else if (role == UserRole.deliveryCompanyAdmin) {
          await NotificationServiceEnhanced.instance.saveTokenForCurrentUser(
            role: 'delivery_company_admin',
          );
        } else if (role == UserRole.captain) {
          await NotificationServiceEnhanced.instance.saveTokenForCurrentUser(
            role: 'captain',
          );
        }
        // merchant token is saved separately with store_id in merchant dashboard
      } else {
        AppLogger.warning(
          '⚠️ Profile not loaded yet — only client token saved',
        );
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save device token after auth: $e');
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
        _syncSession(client.auth.currentSession);
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
    String? storeGovernorate,
    String? storeCity,
    String? storeArea,
    String? storeStreet,
    String? storeLandmark,
    double? storeLatitude,
    double? storeLongitude,
    String? storeDescription,
    String? category,
    String? storeLogoUrl,
    String? merchantType,
    String? payoutMethod,
    String? payoutAccountDetails,
    String? supplyAgreementType,
    int? estimatedPrepTimeMinutes,
    String? workingHours,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final normalizedUserType = userType.trim().toLowerCase();
      const selfSignupAllowedRoles = <String>{'client', 'merchant'};

      if (!selfSignupAllowedRoles.contains(normalizedUserType)) {
        throw Exception(
          'هذا النوع من الحسابات لا يمكن إنشاؤه من شاشة التسجيل. يتم إنشاؤه بواسطة الإدارة فقط.',
        );
      }

      // إعداد البيانات الإضافية للتاجر
      Map<String, dynamic>? additionalData;
      if (normalizedUserType == 'merchant' && storeName != null) {
        additionalData = {
          'store_name': storeName,
          'store_address': storeAddress,
          'store_governorate': storeGovernorate,
          'store_city': storeCity,
          'store_area': storeArea,
          'store_street': storeStreet,
          'store_landmark': storeLandmark,
          'store_latitude': storeLatitude,
          'store_longitude': storeLongitude,
          'store_description': storeDescription,
          'merchant_type': ?merchantType,
          'payout_method': ?payoutMethod,
          'payout_details': ?payoutAccountDetails,
          'supply_agreement_type': ?supplyAgreementType,
          'estimated_prep_time_minutes': ?estimatedPrepTimeMinutes,
          'working_hours': ?workingHours,
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
        userType: normalizedUserType,
        additionalData: additionalData,
      );

      if (response?.user != null) {
        _syncSession(client.auth.currentSession);
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
    NotificationProvider? notificationProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // حذف device token قبل تسجيل الخروج لمنع وصول إشعارات لمستخدم آخر
      await NotificationServiceEnhanced.instance
          .removeDeviceTokenForCurrentUser();
      await NotificationServiceEnhanced.instance.unsubscribeFromAllTopics();

      // Sign out from Supabase
      await SupabaseService.signOut();

      // Clear authentication data
      _syncSession(null);

      // Clear all business data providers to prevent data leakage
      merchantProvider?.clearData();
      productProvider?.clearProducts();
      orderProvider?.clearOrders();
      notificationProvider?.clearData();

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
  Future<String?> uploadAvatar(dynamic imageFile) async {
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

  /// Upload avatar from bytes
  Future<String?> uploadAvatarBytes({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }
      return await SupabaseService.uploadAvatarBytes(
        imageBytes: imageBytes,
        fileName: fileName,
        userId: _currentUser!.id,
      );
    } catch (e) {
      _error = 'Upload avatar bytes error: $e';
      return null;
    }
  }

  /// Update profile
  Future<bool> updateProfile(ProfileModel profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await SupabaseService.updateProfile(profile);
      if (success && profile.id == _currentUser?.id) {
        await _loadProfile();
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

  /// Sign in with Google using Supabase Auth (Native flow on Mobile, OAuth on Web/Desktop)
  Future<bool> signInWithGoogle({String userType = 'client'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final useOAuth = kIsWeb || 
          defaultTargetPlatform == TargetPlatform.windows || 
          defaultTargetPlatform == TargetPlatform.linux || 
          defaultTargetPlatform == TargetPlatform.macOS;

      if (useOAuth) {
        AppLogger.info('🔄 Starting OAuth Google Sign In for userType: $userType on $defaultTargetPlatform');
        
        final launched = await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          // Redirect callback URL configured on Supabase Dashboard
          redirectTo: kIsWeb
              ? '${Uri.base.origin}/market/auth/callback'
              : 'elltallmarket://auth/callback',
          authScreenLaunchMode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
          queryParams: {'access_type': 'offline', 'prompt': 'consent'},
        );
        
        // Clear loading since the browser popup/redirect will take over
        _isLoading = false;
        notifyListeners();
        return launched;
      } else {
        AppLogger.info('🔄 Starting Native Google Sign In for userType: $userType');

        // 1. استدعاء خدمة تسجيل الدخول الأصلية من جوجل (الموبايل)
        final authResponse = await GoogleSignInService.instance.signInWithGoogle();

          if (authResponse == null || authResponse.user == null) {
            // تحديد ما إذا كان الإلغاء أم فشل الاتصال
            if (authResponse == null) {
              _error = 'تم إلغاء تسجيل الدخول عبر جوجل';
            } else {
              _error = 'فشل الاتصال بجوجل، يرجى المحاولة لاحقاً';
            }
            AppLogger.warning('Native Google Sign In failed or was cancelled');
            _isLoading = false;
            notifyListeners();
            return false;
          }

        AppLogger.info('✅ Native Google Sign In completed successfully: ${authResponse.user!.email}');
        
        // تحديث الحالة المحلية للمستخدم الحالي
        _syncSession(client.auth.currentSession);

        // تحميل الملف الشخصي محلياً
        await _loadProfile();

        _isLoading = false;
        _error = null;
        notifyListeners();
        return true;
      }
    } catch (e, st) {
      _error = 'حدث خطأ في تسجيل الدخول بواسطة Google: $e';
      AppLogger.error('Google Sign In error', e, st);
      _isLoading = false;
      notifyListeners();
      return false;
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
      _recoveryUserId = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Update password error: $e';
      AppLogger.error('Update password error', e);
      return false;
    }
  }

  /// Bind the recovery form to the user Supabase validated for this link.
  Future<String> verifyRecoverySession({
    String? accessToken,
    String? refreshToken,
  }) async {
    final auth = client.auth;
    if (accessToken == null || refreshToken == null) {
      final user = (await auth.getUser()).user;
      if (user != null &&
          user.id == _recoveryUserId &&
          user.id == auth.currentUser?.id) {
        return user.id;
      }
    } else {
      final expected = (await auth.getUser(accessToken)).user;
      if (expected != null) {
        final session = auth.currentSession?.accessToken == accessToken
            ? auth.currentSession
            : (await auth.setSession(refreshToken)).session;
        if (session?.user.id == expected.id &&
            auth.currentUser?.id == expected.id) {
          return expected.id;
        }
      }
    }
    throw const AuthException('رابط استعادة كلمة المرور غير صالح');
  }

  /// Resend email confirmation (placeholder)
  Future<void> resendEmailConfirmationSimple(String email) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
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
      _syncSession(session);
      if (_currentUser == null) return false;
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
        _syncSession(client.auth.currentSession);

        // Check if email confirmation is required
        final emailConfirmed = response?.user?.emailConfirmedAt != null;

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
  /// Uses RPC function to delete from auth.users + profiles + sessions
  Future<({bool success, String? message})> deleteUser(String userId) async {
    try {
      AppLogger.info('🔄 Attempting to delete user via RPC: $userId');

      final response = await Supabase.instance.client.rpc(
        'admin_delete_user',
        params: {'p_user_id': userId},
      );

      AppLogger.info('📦 Delete user response: $response');

      if (response is Map) {
        if (response['success'] == true) {
          AppLogger.info('✅ User deleted successfully from auth + profiles');
          return (success: true, message: null);
        } else {
          final errorMsg =
              response['error']?.toString() ?? 'فشل في حذف المستخدم';
          AppLogger.error('Delete user failed', Exception(errorMsg));
          return (success: false, message: errorMsg);
        }
      }

      return (success: false, message: 'استجابة غير متوقعة من الخادم');
    } catch (e) {
      AppLogger.error('❌ Delete user error', e);
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
  /// Uses RPC function to create user in auth.users + profiles
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
      AppLogger.info('🔄 Starting user creation via RPC: $email');

      final response = await Supabase.instance.client.rpc(
        'admin_create_user',
        params: {
          'user_email': email,
          'user_password': password,
          'user_full_name': fullName,
          'user_phone': phone,
          'user_role': role.value,
        },
      );

      AppLogger.info('📦 Create user response: $response');

      if (response is Map) {
        if (response['success'] == true) {
          final newUserId = response['user_id'] as String?;
          AppLogger.info('✅ User created successfully: $newUserId');
          await fetchAllUsers();
          return newUserId;
        } else {
          _error = response['error']?.toString() ?? 'فشل في إنشاء المستخدم';
          AppLogger.error('Create user failed', Exception(_error));
          return null;
        }
      }

      _error = 'استجابة غير متوقعة من الخادم';
      return null;
    } on PostgrestException catch (e) {
      _error = 'خطأ في قاعدة البيانات: ${e.message}';
      AppLogger.error('Database error adding user', e);
      return null;
    } catch (e) {
      _error = 'خطأ في إضافة المستخدم: $e';
      AppLogger.error('Add user error', e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user by admin
  /// Uses RPC function to update both auth.users and profiles
  Future<bool> updateUserByAdmin({
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
    String? password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Updating user via RPC: $userId');

      final response = await Supabase.instance.client.rpc(
        'admin_update_user',
        params: {
          'p_user_id': userId,
          'new_full_name': fullName,
          'new_email': email,
          'new_phone': phone,
          'new_role': role.value,
          'new_password': (password != null && password.isNotEmpty)
              ? password
              : null,
        },
      );

      AppLogger.info('📦 Update user response: $response');

      if (response is Map) {
        if (response['success'] == true) {
          AppLogger.info('✅ User updated successfully');
          await fetchAllUsers();
          return true;
        } else {
          _error = response['error']?.toString() ?? 'فشل في تحديث المستخدم';
          AppLogger.error('Update user failed', Exception(_error));
          return false;
        }
      }

      _error = 'استجابة غير متوقعة من الخادم';
      return false;
    } catch (e) {
      _error = 'خطأ في تحديث المستخدم: $e';
      AppLogger.error('Update user error', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle user active status
  /// Uses RPC function to ban/unban in auth.users + update profiles
  Future<bool> toggleUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Toggling user status via RPC: $userId -> $isActive');

      final response = await Supabase.instance.client.rpc(
        'admin_toggle_user_status',
        params: {'p_user_id': userId, 'p_active': isActive},
      );

      AppLogger.info('📦 Toggle status response: $response');

      if (response is Map) {
        if (response['success'] == true) {
          AppLogger.info('✅ User status toggled successfully');
          await fetchAllUsers();
          return true;
        } else {
          _error =
              response['error']?.toString() ?? 'فشل في تغيير حالة المستخدم';
          AppLogger.error('Toggle status failed', Exception(_error));
          return false;
        }
      }

      _error = 'استجابة غير متوقعة من الخادم';
      return false;
    } catch (e) {
      _error = 'خطأ في تغيير حالة المستخدم: $e';
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
    _identityVersion++;
    _sessionExpiry?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
