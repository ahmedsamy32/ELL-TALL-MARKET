import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/services/firebase_auth_service.dart';
import 'package:ell_tall_market/services/network_manager.dart';

class FirebaseAuthProvider with ChangeNotifier {
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final NetworkManager _networkManager = NetworkManager();

  UserModel? _user;
  final List<UserModel> _allUsers = [];
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

  authProvider() {
    _initializeAuth();
    _initializeNetworkListener();
    _listenToAuthChanges();
  }

  Future<void> _initializeAuth() async {
    _user = await _firebaseAuthService.getCurrentUser();
    notifyListeners();
  }

  void _initializeNetworkListener() {
    _networkManager.networkStatusStream.listen((isConnected) {
      _isConnected = isConnected;
      notifyListeners();

      if (kDebugMode) {
        debugPrint(
          '🌐 Network status in authProvider: ${isConnected ? 'Connected' : 'Disconnected'}',
        );
      }
    });
  }

  void _listenToAuthChanges() {
    _firebaseAuthService.authStateChanges.listen((
      firebase_auth.User? firebaseUser,
    ) async {
      if (firebaseUser != null) {
        // المستخدم مسجل دخول
        _user = await _firebaseAuthService.getCurrentUser();
      } else {
        // المستخدم مسجل خروج
        _user = null;
      }
      notifyListeners();
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
          final user = await _firebaseAuthService.signInWithEmailAndPassword(
            email,
            password,
          );
          if (user == null) {
            throw Exception('فشل في تسجيل الدخول - بيانات غير صحيحة');
          }
          return user;
        },
        maxRetries: 3,
        delayBetweenRetries: const Duration(seconds: 2),
      );

      _user = loginResult;

      if (_user != null) {
        await _updateFCMToken();
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

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserType userType,
    String? adminSecretCode,
    File? storeImage,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      print("🔄 [DEBUG] authProvider.register() - بدء العملية");
      print(
        "🔄 [DEBUG] البيانات: name=$name, email=$email, userType=$userType",
      );

      if (!_networkManager.isConnected) {
        print("❌ [DEBUG] لا يوجد اتصال بالإنترنت");
        throw Exception(
          'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      }

      print(
        "🔄 [DEBUG] استدعاء FirebaseAuthService.createUserWithEmailAndPassword",
      );
      final user = await _firebaseAuthService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        userType: userType,
        phone: phone,
        adminSecretCode: adminSecretCode,
      );

      print(
        "🔄 [DEBUG] نتيجة createUserWithEmailAndPassword: ${user != null ? 'نجح' : 'فشل'}",
      );

      if (user != null) {
        print("✅ [DEBUG] تم إنشاء المستخدم بنجاح، تحديث FCM token");
        _user = user;
        await _updateFCMToken();
        notifyListeners();
        return true;
      }

      print("❌ [DEBUG] user = null - فشل إنشاء المستخدم");
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print(
        "❌ [DEBUG] FirebaseAuthException في authProvider.register(): ${e.code} - ${e.message}",
      );
      _setError(e.toString());
      rethrow; // إعادة إرسال FirebaseAuthException للصفحة
    } catch (e) {
      print("❌ [DEBUG] خطأ عام في authProvider.register(): $e");
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      print("🔄 [DEBUG] authProvider.signInWithGoogle() - بدء العملية");

      if (!_networkManager.isConnected) {
        print("❌ [DEBUG] لا يوجد اتصال بالإنترنت في Google SignIn");
        throw Exception(
          'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      }

      print("🔄 [DEBUG] استدعاء FirebaseAuthService.signInWithGoogle");
      final user = await _firebaseAuthService.signInWithGoogle();

      print(
        "🔄 [DEBUG] نتيجة signInWithGoogle: ${user != null ? 'نجح' : 'فشل'}",
      );

      if (user != null) {
        print("✅ [DEBUG] نجح Google SignIn، تحديث FCM token");
        _user = user;
        await _updateFCMToken();
        notifyListeners();
        return true;
      }

      print("❌ [DEBUG] user = null في Google SignIn");
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print(
        "❌ [DEBUG] FirebaseAuthException في Google SignIn: ${e.code} - ${e.message}",
      );
      _setError(e.toString());
      rethrow;
    } catch (e) {
      print("❌ [DEBUG] خطأ عام في authProvider.signInWithGoogle(): $e");
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithFacebook() async {
    _setLoading(true);
    _setError(null);

    try {
      if (!_networkManager.isConnected) {
        throw Exception(
          'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      }

      final user = await _firebaseAuthService.signInWithFacebook();

      if (user != null) {
        _user = user;
        await _updateFCMToken();
        notifyListeners();
        return true;
      }

      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print(
        "❌ [DEBUG] FirebaseAuthException في Facebook SignIn: ${e.code} - ${e.message}",
      );
      _setError(e.toString());
      rethrow;
    } catch (e) {
      print("❌ [DEBUG] خطأ عام في authProvider.signInWithFacebook(): $e");
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuthService.sendPasswordResetEmail(email);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _firebaseAuthService.sendEmailVerification();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _firebaseAuthService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _firebaseAuthService.deleteAccount();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      if (_user != null) {
        // TODO: إصلاح FCMService.updateUserToken بعد تحديث الخدمة
        if (kDebugMode) {
          debugPrint('📱 FCM Token update skipped for user: ${_user!.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to update FCM token: $e');
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Admin functions (تبقى نفسها لأنها تتعامل مع Supabase مباشرة)
  Future<void> loadAllUsers() async {
    if (!isAdmin) return;

    try {
      _setLoading(true);
      // استخدام SupabaseUserService لجلب جميع المستخدمين
      // _allUsers = await _supabaseUserService.getAllUsers();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllUsers() async {
    await loadAllUsers();
  }

  // ===== الطرق المفقودة =====
  Future<bool> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      _setLoading(true);
      _setError(null);
      return await _firebaseAuthService.updatePassword(
        currentPassword,
        newPassword,
      );
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> updateUser(UserModel updatedUser) async {
    try {
      _setLoading(true);
      _setError(null);
      // حفظ المستخدم محلياً مؤقتاً
      _user = updatedUser;
      notifyListeners();
      return updatedUser;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> updateProfile(UserModel updatedUser) async {
    return await updateUser(updatedUser);
  }

  Future<bool> deleteUser() async {
    try {
      _setLoading(true);
      _setError(null);
      // استخدام firebase auth مباشرة
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        _user = null;
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

  Future<bool> updatePreferredPayment(String paymentMethod) async {
    try {
      _setLoading(true);
      _setError(null);
      if (_user != null) {
        // إنشاء نسخة محدثة من المستخدم
        final updatedUser = UserModel(
          id: _user!.id,
          firebaseId: _user!.firebaseId,
          name: _user!.name,
          email: _user!.email,
          phone: _user!.phone,
          type: _user!.type,
          avatarUrl: _user!.avatarUrl,
          createdAt: _user!.createdAt,
          updatedAt: DateTime.now(),
          isActive: _user!.isActive,
          lastLogin: _user!.lastLogin,
          loginCount: _user!.loginCount,
          storeId: _user!.storeId,
          preferredPaymentMethod: paymentMethod,
          address: _user!.address,
          storeName: _user!.storeName,
          storeDescription: _user!.storeDescription,
          storeLogoUrl: _user!.storeLogoUrl,
          storeCoverUrl: _user!.storeCoverUrl,
          storeAddress: _user!.storeAddress,
          storeLocation: _user!.storeLocation,
          storeCategory: _user!.storeCategory,
          storeRating: _user!.storeRating,
          storeRatingCount: _user!.storeRatingCount,
        );

        final result = await updateUser(updatedUser);
        return result != null;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
