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
import '../services/facebook_signin_service.dart';
import '../services/notification_service.dart';

/// SupabaseProvider - manages authentication state
class SupabaseProvider with ChangeNotifier {
  ProfileModel? _currentProfile;
  User? _currentUser;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isProfileMissing = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

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
        // SupabaseService.getCurrentProfile() already has retry logic with timeouts
        // so we don't need an outer timeout here
        _loadProfile().catchError((e) {
          AppLogger.warning('Profile load error: $e');
          return Future.value(); // return empty Future to avoid crash
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
    if (_isProfileLoading) return;

    _isProfileLoading = true;
    notifyListeners();

    try {
      AppLogger.debug('🔄 Attempting to load profile...');

      // تحقق من وجود user قبل المحاولة
      if (_currentUser == null) {
        AppLogger.warning('⚠️ No user to load profile for');
        return;
      }

      // بدء محاولة تحميل بروفايل جديدة
      _isProfileMissing = false;

      _currentProfile = await SupabaseService.getCurrentProfile();
      if (_currentProfile != null) {
        AppLogger.info('✅ Profile loaded: ${_currentProfile?.fullName}');
      } else {
        AppLogger.warning(
          '⚠️ Profile data unavailable after load attempt (userId: ${_currentUser?.id})',
        );

        // إذا لم نجد profile (maybeSingle = null) نحاول إنشاءه ثم إعادة التحميل.
        final ensured = await SupabaseService.ensureCurrentProfileExists();
        if (ensured) {
          _currentProfile = await SupabaseService.getCurrentProfile();

          if (_currentProfile != null) {
            AppLogger.info(
              '✅ Profile loaded after ensure: ${_currentProfile?.fullName}',
            );
          } else {
            AppLogger.warning(
              '⚠️ Profile still unavailable after ensure (possible RLS denial)',
            );
          }
        }

        // إذا مازال null بعد ensure، نعتبره بروفايل مفقود/غير قابل للقراءة
        if (_currentProfile == null) {
          _isProfileMissing = true;
        }
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
            _isProfileMissing = false;
          } else {
            AppLogger.warning('⚠️ Profile data still unavailable after retry');
            _isProfileMissing = true;
          }
          notifyListeners();
        } catch (retryError) {
          AppLogger.warning('⚠️ Profile load failed after retry: $retryError');
          _currentProfile = null;
          _isProfileMissing = true;
          notifyListeners();
        }
      } else {
        AppLogger.warning('⚠️ User logged out during profile load');
        _currentProfile = null;
        _isProfileMissing = false;
        notifyListeners();
      }
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh the current profile from the `profiles` table.
  Future<void> refreshCurrentProfile() async {
    await _loadProfile();
  }

  /// Handle auth state changes
  void _handleAuthStateChange(AuthState authState) async {
    AppLogger.debug('Auth state changed: ${authState.event}');

    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        _currentUser = authState.session?.user;
        _isProfileMissing = false;
        _isLoading = false; // Clear loading state
        _error = null; // Clear any previous errors
        AppLogger.info('✅ User signed in: ${_currentUser?.email}');
        notifyListeners(); // Update UI immediately
        // Load profile first, then save FCM token with correct role
        _loadProfileThenSaveToken();
        break;
      case AuthChangeEvent.signedOut:
        _currentUser = null;
        _currentProfile = null;
        _isProfileMissing = false;
        _isLoading = false;
        _error = null;
        AppLogger.info('User signed out');
        notifyListeners();
        break;
      case AuthChangeEvent.userUpdated:
        _currentUser = authState.session?.user;
        _isProfileMissing = false;
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

  /// Load profile then save FCM device token with correct role
  Future<void> _loadProfileThenSaveToken() async {
    try {
      // 1) Wait for profile to load so we know the user's role
      await _loadProfile();

      // 2) Now save FCM token with the correct role
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
      // حذف device token قبل تسجيل الخروج لمنع وصول إشعارات لمستخدم آخر
      await NotificationServiceEnhanced.instance
          .removeDeviceTokenForCurrentUser();
      await NotificationServiceEnhanced.instance.unsubscribeFromAllTopics();

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
        // ✅ الويب يستخدم URL حقيقي، الموبايل يستخدم Deep Link
        redirectTo: kIsWeb
            ? '${Uri.base.origin}/auth/callback'
            : 'elltallmarket://auth/callback',
        // ✅ الويب يفتح popup في نفس النافذة، الموبايل يفتح متصفح خارجي
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
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

  /// Sign in with Facebook
  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await FacebookSignInService.instance
          .signInWithFacebook();

      if (response != null && response.user != null) {
        _currentUser = response.user;
        await _loadProfile();
        return true;
      }

      return false;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'خطأ في تسجيل الدخول بفيسبوك: $e';
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
    _authSubscription?.cancel();
    super.dispose();
  }
}
