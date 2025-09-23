import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration(FirebaseAuthProvider authProvider) async {
    // التحقق من جميع الحقول أولاً باستخدام SnackBarHelper
    if (!SnackBarHelper.validateName(context, _nameController.text)) return;
    if (!SnackBarHelper.validateEmail(context, _emailController.text)) return;
    if (!SnackBarHelper.validatePhone(context, _phoneController.text)) return;
    if (!SnackBarHelper.validatePassword(context, _passwordController.text)) {
      return;
    }
    if (!SnackBarHelper.validatePasswordConfirmation(
      context,
      _passwordController.text,
      _confirmPasswordController.text,
    )) {
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        SnackBarHelper.showWarning(
          context,
          '⚠️ يجب الموافقة على الشروط والأحكام أولاً',
        );
        return;
      }

      // إظهار مؤشر التحميل
      SnackBarHelper.showLoading(context, '🔄 جاري إنشاء الحساب...');

      try {
        print("🔄 [DEBUG] بدء عملية التسجيل...");
        final success = await authProvider.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
          userType: UserType.customer,
        );

        print("🔄 [DEBUG] نتيجة التسجيل: $success");

        if (success) {
          print("✅ [DEBUG] نجح التسجيل - عرض رسالة نجاح");
          SnackBarHelper.showSuccess(
            context,
            '✅ تم إنشاء الحساب بنجاح! تحقق من بريدك الإلكتروني.',
            duration: const Duration(seconds: 4),
          );

          print("🔄 [DEBUG] الانتقال للصفحة الرئيسية...");
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else {
          print("❌ [DEBUG] فشل التسجيل - success = false");
          SnackBarHelper.showError(
            context,
            '❌ فشل في إنشاء الحساب، يرجى المحاولة مرة أخرى',
          );
        }
      } on FirebaseAuthException catch (e) {
        print("❌ [DEBUG] FirebaseAuthException: ${e.code} - ${e.message}");
        if (e.code == 'email-already-in-use') {
          _showEmailAlreadyUsedDialog();
        } else {
          SnackBarHelper.handleFirebaseError(
            context,
            e.code,
            e.message ?? 'خطأ في التسجيل',
          );
        }
      } catch (e) {
        print("❌ [DEBUG] خطأ عام: $e");
        SnackBarHelper.showError(
          context,
          '❌ حدث خطأ غير متوقع أثناء التسجيل',
          duration: const Duration(seconds: 4),
        );
      }
    } else {
      print("❌ [DEBUG] فشل التحقق من صحة النموذج");
      SnackBarHelper.showWarning(
        context,
        '⚠️ يرجى التحقق من صحة البيانات المدخلة',
      );
    }
  }

  // تسجيل بواسطة Google
  Future<void> _handleGoogleRegister() async {
    try {
      print("🔄 [DEBUG] بدء تسجيل دخول Google...");
      final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);

      SnackBarHelper.showLoading(context, '🔄 جاري التسجيل بواسطة جوجل...');

      final success = await authProvider.signInWithGoogle();
      if (!mounted) return;

      print("🔄 [DEBUG] نتيجة تسجيل Google: $success");

      if (success) {
        print("✅ [DEBUG] نجح تسجيل Google");
        SnackBarHelper.showSuccess(context, '✅ تم التسجيل بواسطة جوجل بنجاح!');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        print("❌ [DEBUG] فشل تسجيل Google");
        SnackBarHelper.showError(context, '❌ فشل التسجيل بواسطة جوجل');
      }
    } catch (e) {
      print("❌ [DEBUG] خطأ في Google: $e");
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في التسجيل بواسطة جوجل',
        duration: const Duration(seconds: 4),
      );
    }
  }

  // تسجيل بواسطة Facebook
  Future<void> _handleFacebookRegister() async {
    try {
      print("🔄 [DEBUG] بدء تسجيل دخول Facebook...");
      final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري التسجيل بواسطة فيسبوك...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await authProvider.signInWithFacebook();
      if (!mounted) return;

      print("🔄 [DEBUG] نتيجة تسجيل Facebook: $success");

      if (success) {
        print("✅ [DEBUG] نجح تسجيل Facebook");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التسجيل بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        print("❌ [DEBUG] فشل تسجيل Facebook");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل التسجيل بواسطة فيسبوك'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ [DEBUG] خطأ في Facebook: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في التسجيل بواسطة فيسبوك: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmailAlreadyUsedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("البريد الإلكتروني مستخدم مسبقاً"),
        content: const Text(
          "هذا البريد الإلكتروني مسجل بالفعل. هل تريد تسجيل الدخول بدلاً من ذلك؟",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: const Text("تسجيل الدخول"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordResetDialog();
            },
            child: const Text("نسيت كلمة المرور"),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("استعادة كلمة المرور"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "سيتم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني.",
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authProvider = Provider.of<FirebaseAuthProvider>(
                    context,
                    listen: false,
                  );
                  await authProvider.sendPasswordResetEmail(
                    _emailController.text.trim(),
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم إرسال رابط الاستعادة إلى بريدك الإلكتروني",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("فشل إرسال رابط الاستعادة: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("إرسال رابط الاستعادة"),
            ),
          ],
        ),
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
            colors: [Colors.blue.shade50, Colors.blue.shade100],
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
                        // الشعار والعنوان
                        Icon(
                          Icons.shopping_cart,
                          size: 70,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "🛒 إنشاء حساب جديد",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "سجل للشراء وتتبع طلباتك بسهولة",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // الاسم الكامل
                        CustomTextField(
                          controller: _nameController,
                          label: "الاسم الكامل",
                          prefixIcon: const Icon(Icons.person_outline),
                          validator: (value) => value?.isEmpty ?? true
                              ? "يرجى إدخال الاسم الكامل"
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // البريد الإلكتروني
                        CustomTextField(
                          controller: _emailController,
                          label: "البريد الإلكتروني",
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال البريد الإلكتروني";
                            }
                            if (!value.contains("@") || !value.contains(".")) {
                              return "البريد الإلكتروني غير صالح";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // رقم الهاتف
                        CustomTextField(
                          controller: _phoneController,
                          label: "رقم الهاتف",
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: "+20 ",
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال رقم الهاتف";
                            }
                            if (value.length < 10) {
                              return "رقم الهاتف يجب أن يكون 10 أرقام على الأقل";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // كلمة المرور
                        CustomTextField(
                          controller: _passwordController,
                          label: "كلمة المرور",
                          isPasswordField: true,
                          prefixIcon: const Icon(Icons.lock_outline),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال كلمة المرور";
                            }
                            if (value.length < 6) {
                              return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // تأكيد كلمة المرور
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: "تأكيد كلمة المرور",
                          isPasswordField: true,
                          prefixIcon: const Icon(Icons.lock_outline),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى تأكيد كلمة المرور";
                            }
                            if (value != _passwordController.text) {
                              return "كلمة المرور غير متطابقة";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // الموافقة على الشروط
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) {
                                setState(() => _agreeToTerms = value ?? false);
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // يمكنك إضافة شاشة الشروط والأحكام هنا
                                },
                                child: Text(
                                  "أوافق على الشروط والأحكام",
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // زر التسجيل
                        CustomButton(
                          text: authProvider.isLoading
                              ? "جاري إنشاء الحساب..."
                              : "تسجيل",
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _handleRegistration(authProvider),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),

                        const SizedBox(height: 24),

                        // أو التسجيل بـ Google و Facebook
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                "أو",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // أزرار التسجيل الاجتماعي
                        Row(
                          children: [
                            // زر Google
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleGoogleRegister,
                                icon: Image.asset(
                                  'assets/icons/icons8-google-192.png',
                                  width: 20,
                                  height: 20,
                                ),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // زر Facebook
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleFacebookRegister,
                                icon: Image.asset(
                                  'assets/icons/icons8-facebook-96.png',
                                  width: 20,
                                  height: 20,
                                ),
                                label: const Text('Facebook'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // أو تسجيل الدخول
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "لديك حساب بالفعل؟ ",
                              style: theme.textTheme.bodyMedium,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              },
                              child: Text(
                                "تسجيل الدخول",
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
