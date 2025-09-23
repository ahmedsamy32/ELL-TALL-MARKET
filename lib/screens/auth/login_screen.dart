import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart'; // ✅ Firebase Auth Provider
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart'; // ✅ SnackBar Helper
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(FirebaseAuthProvider authProvider) async {
    // التحقق من صحة البيانات قبل الإرسال
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // التحقق من البريد الإلكتروني
    if (!SnackBarHelper.validateEmail(context, email)) return;

    // التحقق من كلمة المرور
    if (!SnackBarHelper.validatePassword(context, password)) return;

    setState(() => _isLoading = true);

    // عرض رسالة تحميل
    SnackBarHelper.showLoading(context, '🔄 جاري تسجيل الدخول...');

    try {
      print("🔄 [DEBUG] بدء تسجيل الدخول العادي...");
      final success = await authProvider.login(
        email,
        password,
        context,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      print("🔄 [DEBUG] نتيجة تسجيل الدخول العادي: $success");

      if (!success) {
        print("❌ [DEBUG] فشل تسجيل الدخول العادي");
        SnackBarHelper.showError(
          context,
          '❌ فشل تسجيل الدخول - تأكد من صحة البيانات',
        );
      } else {
        print("✅ [DEBUG] نجح تسجيل الدخول العادي");
        SnackBarHelper.showSuccess(context, '✅ تم تسجيل الدخول بنجاح!');
      }
    } on FirebaseAuthException catch (e) {
      print(
        "❌ [DEBUG] FirebaseAuthException في Login: ${e.code} - ${e.message}",
      );
      if (!mounted) return;

      // استخدام المساعد لمعالجة أخطاء Firebase
      SnackBarHelper.handleFirebaseError(context, e.code, e.message);
    } catch (e) {
      if (!mounted) return;

      // معالجة خاصة لأخطاء الاتصال
      if (e.toString().contains('لا يمكن الاتصال بالخادم') ||
          e.toString().contains('مشكلة في الاتصال بالخادم') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection terminated') ||
          e.toString().contains('SocketException')) {
        SnackBarHelper.showWarning(
          context,
          '🌐 مشكلة في الاتصال بالإنترنت',
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _handleLogin(authProvider),
          ),
        );
      } else {
        SnackBarHelper.showError(
          context,
          '❌ حدث خطأ غير متوقع\n${e.toString()}',
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    // عرض رسالة تحميل
    SnackBarHelper.showLoading(context, '🔄 جاري تسجيل الدخول بواسطة جوجل...');

    try {
      print("🔄 [DEBUG] بدء تسجيل دخول Google في Login...");
      final authProvider = Provider.of<FirebaseAuthProvider>(
        context,
        listen: false,
      );

      final success = await authProvider.signInWithGoogle();
      if (!mounted) return;

      print("🔄 [DEBUG] نتيجة تسجيل Google في Login: $success");

      if (success) {
        print("✅ [DEBUG] نجح تسجيل Google في Login");
        SnackBarHelper.showSuccess(
          context,
          '✅ تم تسجيل الدخول بواسطة جوجل بنجاح!',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        print("❌ [DEBUG] فشل تسجيل Google في Login");
        SnackBarHelper.showError(context, '❌ فشل تسجيل الدخول بواسطة جوجل');
      }
    } catch (e) {
      print("❌ [DEBUG] خطأ في Google Login: $e");
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في تسجيل الدخول بواسطة جوجل',
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);

    // عرض رسالة تحميل
    SnackBarHelper.showLoading(
      context,
      '🔄 جاري تسجيل الدخول بواسطة فيسبوك...',
    );

    try {
      print("🔄 [DEBUG] بدء تسجيل دخول Facebook في Login...");
      final authProvider = Provider.of<FirebaseAuthProvider>(
        context,
        listen: false,
      );

      final success = await authProvider.signInWithFacebook();
      if (!mounted) return;

      print("🔄 [DEBUG] نتيجة تسجيل Facebook في Login: $success");

      if (success) {
        print("✅ [DEBUG] نجح تسجيل Facebook في Login");
        SnackBarHelper.showSuccess(
          context,
          '✅ تم تسجيل الدخول بواسطة فيسبوك بنجاح!',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        print("❌ [DEBUG] فشل تسجيل Facebook في Login");
        SnackBarHelper.showError(context, '❌ فشل تسجيل الدخول بواسطة فيسبوك');
      }
    } catch (e) {
      print("❌ [DEBUG] خطأ في Facebook Login: $e");
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في تسجيل الدخول بواسطة فيسبوك',
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPasswordResetDialog() {
    // تحقق من إدخال البريد الإلكتروني أولاً
    if (_emailController.text.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        '⚠️ يرجى إدخال البريد الإلكتروني أولاً',
      );
      return;
    }

    // التحقق من صحة البريد الإلكتروني
    if (!SnackBarHelper.validateEmail(context, _emailController.text)) {
      return; // validateEmail سيعرض رسالة الخطأ
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("استعادة كلمة المرور"),
        content: Text(
          "سيتم إرسال رابط استعادة كلمة المرور إلى:\n${_emailController.text}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // إغلاق الحوار أولاً

              // عرض رسالة تحميل
              SnackBarHelper.showLoading(
                context,
                '🔄 جاري إرسال رابط الاستعادة...',
              );

              try {
                final authProvider = Provider.of<FirebaseAuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.sendPasswordResetEmail(
                  _emailController.text.trim(),
                );
                if (!mounted) return;

                SnackBarHelper.showSuccess(
                  context,
                  '✅ تم إرسال رابط الاستعادة إلى بريدك الإلكتروني',
                  duration: const Duration(seconds: 4),
                );
              } catch (e) {
                if (!mounted) return;
                SnackBarHelper.showError(
                  context,
                  '❌ فشل إرسال رابط الاستعادة. تحقق من البريد الإلكتروني.',
                  duration: const Duration(seconds: 4),
                );
              }
            },
            child: const Text("إرسال"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<FirebaseAuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.grey[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔑 الشعار والعنوان
                        Icon(
                          Icons.lock_outline,
                          size: 70,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "🔑 تسجيل الدخول",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "أدخل بياناتك للمتابعة",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 📧 البريد الإلكتروني
                        CustomTextField(
                          controller: _emailController,
                          label: "البريد الإلكتروني أو رقم الهاتف",
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال البريد الإلكتروني";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 🔒 كلمة المرور
                        CustomTextField(
                          controller: _passwordController,
                          label: "كلمة المرور",
                          isPasswordField: _obscurePassword,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          enabled: !_isLoading,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال كلمة المرور";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ✅ تذكرني ونسيت كلمة المرور
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(
                                            () => _rememberMe = value ?? false,
                                          );
                                        },
                                ),
                                Text(
                                  "تذكرني",
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _showPasswordResetDialog,
                              child: Text(
                                "نسيت كلمة المرور؟",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 🟢 زر تسجيل الدخول
                        CustomButton(
                          text: _isLoading
                              ? "جاري تسجيل الدخول..."
                              : "تسجيل الدخول",
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin(authProvider),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),

                        const SizedBox(height: 32),

                        // ➖ خط فاصل
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                "أو",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 🔵 أزرار التسجيل الاجتماعي
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Image.asset(
                                'assets/icons/icons8-google-192.png',
                                width: 40,
                                height: 40,
                              ),
                              onPressed: _isLoading ? null : _handleGoogleLogin,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Image.asset(
                                'assets/icons/icons8-facebook-96.png',
                                width: 40,
                                height: 40,
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : _handleFacebookLogin,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // 📝 رابط إنشاء حساب
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "ليس لديك حساب؟ ",
                              style: theme.textTheme.bodyMedium,
                            ),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.register,
                                      );
                                    },
                              child: Text(
                                "إنشاء حساب جديد",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
