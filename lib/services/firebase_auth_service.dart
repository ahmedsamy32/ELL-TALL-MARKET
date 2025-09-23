import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/config/admin_config.dart';
import 'package:ell_tall_market/services/supabase_user_service.dart';
import 'package:ell_tall_market/services/google_signin_service.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseUserService _supabaseUserService = SupabaseUserService();

  /// الحصول على المستخدم الحالي
  User? get currentFirebaseUser => _auth.currentUser;

  /// الحصول على معلومات المستخدم الكاملة من Supabase
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        // جلب معلومات المستخدم من Supabase باستخدام Firebase UID
        return await _supabaseUserService.getUserByFirebaseId(firebaseUser.uid);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] Error getting current user: $e');
      }
      return null;
    }
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('🔐 [FirebaseAuthService] تسجيل الدخول: $email');
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // التحقق من وجود المستخدم في Supabase
        var userModel = await _supabaseUserService.getUserByFirebaseId(
          credential.user!.uid,
        );

        userModel ??= await _createUserInSupabase(credential.user!);

        // تحديث آخر تسجيل دخول
        if (userModel != null) {
          await _supabaseUserService.updateLastLogin(userModel.id);
        }

        return userModel;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في تسجيل الدخول: $e');
      }
      rethrow;
    }
  }

  /// إنشاء حساب جديد
  Future<UserModel?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserType userType,
    String? phone,
    String? adminSecretCode,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('👤 [FirebaseAuthService] إنشاء حساب جديد: $email');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // تحديث ملف Firebase Auth
        await credential.user!.updateDisplayName(name);

        // تحديد نوع المستخدم
        UserType finalUserType = userType;
        if (AdminDetectionConfig.isAdmin(
          email: email,
          password: password,
          secretCode: adminSecretCode,
        )) {
          finalUserType = UserType.admin;
        }

        // إنشاء المستخدم في Supabase
        final userModel = UserModel(
          id: '', // سيتم تعيينه من Supabase
          firebaseId: credential.user!.uid,
          name: name,
          email: email,
          phone: phone ?? '',
          type: finalUserType,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final createdUser = await _supabaseUserService.createUser(userModel);

        if (kDebugMode) {
          debugPrint('✅ [FirebaseAuthService] تم إنشاء المستخدم بنجاح');
        }

        return createdUser;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في إنشاء الحساب: $e');
      }
      rethrow;
    }
  }

  /// تسجيل الدخول بـ Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        debugPrint('🟡 [FirebaseAuthService] تسجيل الدخول بـ Google');
      }

      // بدء عملية تسجيل الدخول مع Google
      await GoogleSignInService.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignInService.instance
          .signIn();
      if (googleUser == null) {
        if (kDebugMode) {
          debugPrint(
            '🔸 [FirebaseAuthService] المستخدم ألغى تسجيل الدخول بـ Google',
          );
        }
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // التحقق من وجود المستخدم في Supabase أو إنشاؤه
        var userModel = await _supabaseUserService.getUserByFirebaseId(
          userCredential.user!.uid,
        );

        userModel ??= await _createUserInSupabase(userCredential.user!);

        if (kDebugMode) {
          debugPrint('✅ [FirebaseAuthService] تم تسجيل الدخول بـ Google بنجاح');
        }

        return userModel;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في تسجيل الدخول بـ Google: $e');
      }
      rethrow;
    }
  }

  /// تسجيل الدخول بـ Facebook
  Future<UserModel?> signInWithFacebook() async {
    try {
      if (kDebugMode) {
        debugPrint('🔵 [FirebaseAuthService] تسجيل الدخول بـ Facebook');
      }

      // بدء عملية تسجيل الدخول مع Facebook
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(result.accessToken!.tokenString);

        final userCredential = await _auth.signInWithCredential(
          facebookAuthCredential,
        );

        if (userCredential.user != null) {
          // التحقق من وجود المستخدم في Supabase أو إنشاؤه
          var userModel = await _supabaseUserService.getUserByFirebaseId(
            userCredential.user!.uid,
          );

          userModel ??= await _createUserInSupabase(userCredential.user!);

          if (kDebugMode) {
            debugPrint(
              '✅ [FirebaseAuthService] تم تسجيل الدخول بـ Facebook بنجاح',
            );
          }

          return userModel;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FirebaseAuthService] خطأ في تسجيل الدخول بـ Facebook: $e',
        );
      }
      rethrow;
    }
  }

  /// إنشاء مستخدم في Supabase من Firebase User
  Future<UserModel?> _createUserInSupabase(User firebaseUser) async {
    try {
      // تحديد نوع المستخدم
      UserType userType = UserType.customer;
      if (AdminDetectionConfig.isAdminByEmail(firebaseUser.email ?? '')) {
        userType = UserType.admin;
      }

      final userModel = UserModel(
        id: '', // سيتم تعيينه من Supabase
        firebaseId: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'مستخدم',
        email: firebaseUser.email ?? '',
        phone: firebaseUser.phoneNumber ?? '',
        type: userType,
        isActive: true,
        createdAt: DateTime.now(),
      );

      return await _supabaseUserService.createUser(userModel);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في إنشاء مستخدم Supabase: $e');
      }
      return null;
    }
  }

  /// إرسال رابط إعادة تعيين كلمة المرور
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        debugPrint(
          '✅ [FirebaseAuthService] تم إرسال رابط إعادة تعيين كلمة المرور',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FirebaseAuthService] خطأ في إرسال رابط إعادة التعيين: $e',
        );
      }
      rethrow;
    }
  }

  /// إرسال رابط تأكيد البريد الإلكتروني
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (kDebugMode) {
          debugPrint(
            '✅ [FirebaseAuthService] تم إرسال رابط تأكيد البريد الإلكتروني',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في إرسال رابط التأكيد: $e');
      }
      rethrow;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        GoogleSignInService.instance.signOut(),
        FacebookAuth.instance.logOut(),
      ]);

      if (kDebugMode) {
        debugPrint('✅ [FirebaseAuthService] تم تسجيل الخروج بنجاح');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في تسجيل الخروج: $e');
      }
      rethrow;
    }
  }

  /// تحديث كلمة المرور (يتطلب إعادة المصادقة)
  Future<bool> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // التحقق من طريقة تسجيل الدخول
      final providerData = user.providerData;
      bool isEmailPassword = false;

      for (final provider in providerData) {
        if (provider.providerId == 'password') {
          isEmailPassword = true;
          break;
        }
      }

      if (!isEmailPassword) {
        throw Exception(
          'لا يمكن تغيير كلمة المرور للحسابات المسجلة بـ Google أو Facebook',
        );
      }

      // إعادة المصادقة بكلمة المرور الحالية
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // تحديث كلمة المرور
      await user.updatePassword(newPassword);

      if (kDebugMode) {
        debugPrint('✅ [FirebaseAuthService] تم تحديث كلمة المرور بنجاح');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FirebaseAuthService] خطأ في تحديث كلمة المرور: ${e.code}',
        );
      }

      switch (e.code) {
        case 'wrong-password':
          throw Exception('كلمة المرور الحالية غير صحيحة');
        case 'weak-password':
          throw Exception('كلمة المرور الجديدة ضعيفة جداً');
        case 'requires-recent-login':
          throw Exception('يرجى تسجيل الدخول مرة أخرى قبل تغيير كلمة المرور');
        default:
          throw Exception('حدث خطأ في تحديث كلمة المرور: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ غير متوقع: $e');
      }
      rethrow;
    }
  }

  /// إعادة المصادقة للمستخدمين المسجلين بـ Google
  Future<bool> reauthenticateWithGoogle() async {
    try {
      await GoogleSignInService.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignInService.instance
          .signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final user = _auth.currentUser;
      if (user != null) {
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FirebaseAuthService] خطأ في إعادة المصادقة بـ Google: $e',
        );
      }
      rethrow;
    }
  }

  /// إعادة المصادقة للمستخدمين المسجلين بـ Facebook
  Future<bool> reauthenticateWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return false;

      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);

      final user = _auth.currentUser;
      if (user != null) {
        await user.reauthenticateWithCredential(facebookAuthCredential);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FirebaseAuthService] خطأ في إعادة المصادقة بـ Facebook: $e',
        );
      }
      rethrow;
    }
  }

  /// حذف الحساب
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // حذف من Supabase أولاً
        await _supabaseUserService.deleteUserByFirebaseId(user.uid);

        // ثم حذف من Firebase
        await user.delete();

        if (kDebugMode) {
          debugPrint('✅ [FirebaseAuthService] تم حذف الحساب بنجاح');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FirebaseAuthService] خطأ في حذف الحساب: $e');
      }
      rethrow;
    }
  }

  /// الاستماع لتغييرات حالة المصادقة
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
