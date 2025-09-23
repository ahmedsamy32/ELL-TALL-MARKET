import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/services/firebase_auth_service.dart';
import 'package:ell_tall_market/services/supabase_user_service.dart';
import 'package:ell_tall_market/services/fcm_service.dart';
import 'package:ell_tall_market/services/network_manager.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final SupabaseUserService _userService = SupabaseUserService();
  final NetworkManager _networkManager = NetworkManager();

  UserModel? _user;
  List<UserModel> _allUsers = [];
  bool _isLoading = false;
  String? _error;
  bool _isConnected = true;

  // ================= Getters =================
  UserModel? get user => _user;
  List<UserModel> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.type == UserType.admin;
  bool get isMerchant => _user?.type == UserType.merchant;
  bool get isCaptain => _user?.type == UserType.captain;
  bool get isCustomer => _user?.type == UserType.customer;
  bool get isConnected => _isConnected;

  AuthProvider() {
    _initializeAuth();
    _initializeNetworkListener();
  }

  Future<void> _initializeAuth() async {
    _user = await _authService.getCurrentUser();
    notifyListeners();
  }

  void _initializeNetworkListener() {
    _networkManager.networkStatusStream.listen((isConnected) {
      _isConnected = isConnected;
      notifyListeners();

      if (kDebugMode) {
        debugPrint(
          '🌐 Network status in AuthProvider: ${isConnected ? 'Connected' : 'Disconnected'}',
        );
      }
    });
  }

  Future<bool> login(
    String email,
    String password,
    BuildContext context, {
    bool rememberMe = false,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // التحقق من الاتصال أولاً
      if (!_networkManager.isConnected) {
        throw Exception(
          'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      }

      // استخدام مدير الشبكة لإعادة المحاولة عند انقطاع الاتصال
      final loginResult = await _networkManager.retryWhenConnected(
        () async {
          final user = await _authService.signInWithEmailAndPassword(
            email,
            password,
          );
          if (user == null) {
            throw Exception('فشل في تسجيل الدخول - بيانات غير صحيحة');
          }
          return user; // الآن يُرجع UserModel وليس UserModel?
        },
        maxRetries: 3,
        delayBetweenRetries: const Duration(seconds: 2),
      );

      _user = loginResult;

      if (_user != null) {
        await _updateFCMToken(); // Add FCM token after login
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
    UserModel user,
    String password,
    BuildContext context, {
    File? storeImage,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.createUserWithEmailAndPassword(
        name: user.name,
        email: user.email,
        password: password,
        phone: user.phone,
        userType: user.type,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await _clearFCMToken(); // Clear FCM token before logout
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithGoogle(BuildContext context) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.signInWithGoogle();
      notifyListeners();
      return _user != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithFacebook(BuildContext context) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.signInWithFacebook();
      notifyListeners();
      return _user != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      if (kDebugMode) print('❌ Error sending email verification: $e');
      throw Exception('فشل في إرسال رابط التحقق من البريد الإلكتروني');
    }
  }

  // ================= User Management =================
  Future<void> fetchAllUsers() async {
    _setLoading(true);
    try {
      final response = await _userService.getAllUsers();
      _allUsers = response; // getAllUsers يرجع List<UserModel> مباشرة
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching users: $e');
      _setError(e.toString());
      _allUsers = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUser(UserModel updatedUser) async {
    _setLoading(true);
    _setError(null);

    try {
      await _userService.updateUser(updatedUser.id, {
        'name': updatedUser.name,
        'phone': updatedUser.phone,
        'type': updatedUser.type.toString().split('.').last,
      });
      _user = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? imageUrl,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      if (_user == null) throw 'User not logged in';

      final updatedUser = await _userService.updateUser(_user!.id, {
        'name': name,
        'phone': phone,
        if (imageUrl != null) 'avatar_url': imageUrl,
      });

      if (updatedUser != null) {
        // Refresh the user data
        _user = await _authService.getCurrentUser();
        notifyListeners();
      }

      return updatedUser != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      if (_user == null) throw 'User not logged in';

      return await _authService.updatePassword(currentPassword, newPassword);
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteUser(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _userService.deleteUserByFirebaseId(_user!.firebaseId!);
      // إذا لم يحدث exception، فالحذف نجح
      _user = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePreferredPayment(String paymentMethod) async {
    _setLoading(true);
    _setError(null);

    try {
      if (_user == null) throw 'User not logged in';

      final updatedUser = await _userService.updateUser(_user!.id, {
        'preferred_payment': paymentMethod,
      });

      if (updatedUser != null) {
        // Refresh user data to get updated payment method
        _user = await _authService.getCurrentUser();
        notifyListeners();
      }

      return updatedUser != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== FCM Token Management =====
  Future<void> _updateFCMToken() async {
    try {
      if (_user != null) {
        final fcmService = FCMService();
        await fcmService.saveTokenToDatabase(_user!.id);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating FCM token: $e');
    }
  }

  Future<void> _clearFCMToken() async {
    try {
      final fcmService = FCMService();
      await fcmService.deleteToken();
    } catch (e) {
      if (kDebugMode) print('❌ Error clearing FCM token: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
