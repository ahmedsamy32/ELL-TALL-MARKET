import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();

    // التحقق من وجود بريد إلكتروني مُرسل من صفحة التسجيل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['prefillEmail'] != null) {
        _emailController.text = args['prefillEmail'];
        AppLogger.info(
          "تم ملء البريد الإلكتروني تلقائياً: ${args['prefillEmail']}",
        );

        // إظهار رسالة ترحيبية
        SnackBarHelper.showInfo(
          context,
          '📧 تم ملء البريد الإلكتروني تلقائياً. أدخل كلمة المرور.',
          duration: const Duration(seconds: 3),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// إعادة إرسال رسالة التأكيد للبريد الإلكتروني
  Future<void> _resendConfirmationEmail(String email) async {
    try {
      AppLogger.info("📧 إعادة إرسال رسالة التأكيد إلى: $email");

      setState(() => _isLoading = true);

      SnackBarHelper.showLoading(context, '🔄 جاري إرسال رسالة التأكيد...');

      // إعادة إرسال رسالة التأكيد باستخدام Auth API (لا يحتاج RLS)
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      AppLogger.info("✅ تم إرسال رسالة التأكيد بنجاح");

      AppLogger.info("[Login] ✅ تم إعادة إرسال رسالة التأكيد إلى: $email");

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      SnackBarHelper.showSuccess(
        context,
        "✅ تم إرسال رسالة التأكيد!\n"
        "يرجى التحقق من بريدك الإلكتروني",
        duration: const Duration(seconds: 4),
      );

      // الانتقال لصفحة تأكيد البريد
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.emailConfirmation,
        arguments: {'email': email},
      );
    } on AuthException catch (e) {
      AppLogger.error("❌ خطأ Auth في إعادة الإرسال", e);

      AppLogger.error(
        "[Login] ❌ AuthException في إعادة إرسال التأكيد: ${e.message}",
        e,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      // معالجة أخطاء محددة
      String errorMsg = "❌ فشل إرسال رسالة التأكيد";

      if (e.message.contains('rate_limit') ||
          e.message.contains('too_many_requests')) {
        errorMsg =
            "⏰ تم إرسال كثير من الرسائل\nيرجى الانتظار قليلاً ثم المحاولة مرة أخرى";
      } else if (e.message.contains('not_found') ||
          e.message.contains('user_not_found')) {
        errorMsg = "❌ لم يتم العثور على المستخدم\nيرجى التسجيل أولاً";
      } else {
        errorMsg = "❌ فشل إرسال رسالة التأكيد\n${e.message}";
      }

      SnackBarHelper.showError(
        context,
        errorMsg,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      AppLogger.error("❌ خطأ عام في إعادة الإرسال", e);

      AppLogger.error("[Login] ❌ خطأ عام في إعادة إرسال التأكيد", e);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      SnackBarHelper.showError(
        context,
        "❌ حدث خطأ غير متوقع\nيرجى المحاولة مرة أخرى",
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin(SupabaseProvider authProvider) async {
    // تفعيل التحقق بعد أول محاولة تسجيل دخول
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      SnackBarHelper.showWarning(
        context,
        '⚠️ يرجى تصحيح الأخطاء في النموذج أولاً',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      AppLogger.info("[Login] 🔄 بدء السيناريو: فحص البريد $email");

      // 🔍 السيناريو 1: التحقق من وجود البريد في قاعدة البيانات
      AppLogger.info("═══════════════════════════════════════");
      AppLogger.info("🔍 الخطوة 1: فحص البريد في profiles...");
      AppLogger.info("   Email: $email");

      SnackBarHelper.showLoading(context, '🔄 جاري التحقق من البيانات...');

      final existingProfile = await Supabase.instance.client
          .from('profiles')
          .select('id, email, role')
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (existingProfile == null) {
        // ❌ السيناريو 2: البريد غير مسجل
        AppLogger.info("❌ السيناريو 2: البريد غير مسجل");
        AppLogger.info("   التوجيه: صفحة التسجيل");
        AppLogger.info("═══════════════════════════════════════");

        AppLogger.warning("[Login] ⚠️ البريد غير مسجل: $email");

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).clearSnackBars();

        SnackBarHelper.showInfo(
          context,
          "📧 هذا البريد غير مسجل\n"
          "سيتم توجيهك لإنشاء حساب جديد...",
          duration: const Duration(seconds: 2),
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          AppRoutes.register,
          arguments: {'prefillEmail': email},
        );

        return;
      }

      // ✅ البريد موجود - المتابعة بتسجيل الدخول
      AppLogger.info("✅ البريد موجود في قاعدة البيانات!");
      AppLogger.info("   Email: ${existingProfile['email']}");
      AppLogger.info("   Role: ${existingProfile['role']}");

      // ✨ السيناريو 3: المتابعة بتسجيل الدخول
      AppLogger.info("═══════════════════════════════════════");
      AppLogger.info("✨ السيناريو 3: المتابعة بتسجيل الدخول");
      AppLogger.info("═══════════════════════════════════════");

      ScaffoldMessenger.of(context).clearSnackBars();
      SnackBarHelper.showLoading(context, '🔄 جاري تسجيل الدخول...');

      AppLogger.info("[Login] بدء تسجيل الدخول - Email: $email");

      // تسجيل الدخول عبر Supabase
      final success = await authProvider.signIn(email, password);

      if (!mounted) return;

      if (success) {
        AppLogger.info("[Login] تم تسجيل الدخول بنجاح");

        ScaffoldMessenger.of(context).clearSnackBars();
        SnackBarHelper.showSuccess(context, '✅ تم تسجيل الدخول بنجاح!');

        // التنقل حسب دور المستخدم
        await authProvider.refreshProfile();
        final role = authProvider.currentProfile?.role;

        AppLogger.info("✅ الدور: $role");

        if (!mounted) return;

        if (role == UserRole.admin) {
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
        } else if (role == UserRole.deliveryCompanyAdmin) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.deliveryCompanyDashboard,
          );
        } else if (role == UserRole.merchant) {
          Navigator.pushReplacementNamed(context, AppRoutes.merchantDashboard);
        } else if (role == UserRole.captain) {
          Navigator.pushReplacementNamed(context, AppRoutes.captainDashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        AppLogger.warning("[Login] فشل تسجيل الدخول");

        ScaffoldMessenger.of(context).clearSnackBars();

        // التحقق من نوع الخطأ وعرض رسالة مناسبة
        final error = authProvider.errorMessage;
        if (error != null) {
          // فحص خطأ البريد غير المؤكد
          if (error.toLowerCase().contains('email_not_confirmed') ||
              error.toLowerCase().contains('email not confirmed')) {
            // عرض Dialog مع خيار إعادة الإرسال
            final shouldResend = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'البريد غير مؤكد',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'يجب تأكيد بريدك الإلكتروني قبل تسجيل الدخول.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'هل تريد إعادة إرسال رسالة التأكيد؟',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    label: const Text('إلغاء'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.send),
                    label: const Text('إعادة الإرسال'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (shouldResend == true && mounted) {
              await _resendConfirmationEmail(email);
            }
          } else if (error.contains('timeout') ||
              error.contains('connection') ||
              error.contains('network')) {
            SnackBarHelper.showError(
              context,
              '🌐 مشكلة في الاتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
              duration: const Duration(seconds: 5),
            );
          } else {
            SnackBarHelper.showError(context, _getAuthErrorMessage(error));
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      AppLogger.error("[Login] خطأ Supabase Auth: ${e.message}");

      // معالجة أخطاء Supabase المحددة
      String errorMessage = _getAuthErrorMessage(e.message);
      SnackBarHelper.showError(
        context,
        errorMessage,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) return;
      AppLogger.error("[Login] خطأ عام في تسجيل الدخول: $e");

      // معالجة أخطاء الشبكة والاتصال
      String errorMessage = e.toString();

      if (errorMessage.contains('AuthRetryableFetchException') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('SocketException') ||
          errorMessage.contains('connection')) {
        SnackBarHelper.showError(
          context,
          '🌐 مشكلة في الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.',
          duration: const Duration(seconds: 6),
        );
      } else {
        // استخراج الرسالة من Exception إذا كانت موجودة
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11); // إزالة "Exception: "
        }

        SnackBarHelper.showError(
          context,
          '❌ حدث خطأ في تسجيل الدخول. يرجى المحاولة مرة أخرى',
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// معالجة أخطاء Supabase Auth المحددة
  String _getAuthErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('invalid_credentials') ||
        lowerError.contains('invalid login credentials') ||
        lowerError.contains('invalid login cred') ||
        lowerError.contains('invalid login') ||
        lowerError.contains('invalid_grant')) {
      return '🔐 البريد الإلكتروني أو كلمة المرور غير صحيحة';
    } else if (lowerError.contains('email_not_confirmed') ||
        lowerError.contains('email not confirmed')) {
      return '📧 يجب تأكيد البريد الإلكتروني أولاً. تحقق من صندوق الوارد';
    } else if (lowerError.contains('too_many_requests') ||
        lowerError.contains('rate limit')) {
      return '⏰ محاولات كثيرة جداً. انتظر قليلاً وحاول مرة أخرى';
    } else if (lowerError.contains('network') ||
        lowerError.contains('connection')) {
      return '🌐 مشكلة في الاتصال بالإنترنت';
    } else {
      return '❌ حدث خطأ في تسجيل الدخول. يرجى المحاولة مرة أخرى';
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // Launch Google OAuth browser
      final launched = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (launched) {
        // Browser opened successfully - show message and wait for callback
        SnackBarHelper.showInfo(
          context,
          '🔄 يرجى إكمال تسجيل الدخول في المتصفح...',
        );

        // The actual sign-in will be handled by the deep link callback
        // and auth state listener. We'll listen for auth state changes
        // to navigate automatically.

        // Set up a one-time listener for auth state changes
        StreamSubscription<User?>? subscription;
        subscription = authProvider.authStateChanges.listen((user) {
          if (user != null && mounted) {
            // Cancel immediately to prevent multiple calls
            subscription?.cancel();

            // User signed in successfully via OAuth callback
            SnackBarHelper.showSuccess(
              context,
              '✅ تم تسجيل الدخول بواسطة جوجل بنجاح!',
            );

            // Navigate based on user role
            authProvider.refreshProfile().then((_) {
              if (!mounted) return;

              final userRole = authProvider.currentProfile?.role;
              switch (userRole) {
                case UserRole.admin:
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.adminDashboard,
                  );
                  break;
                case UserRole.deliveryCompanyAdmin:
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.deliveryCompanyDashboard,
                  );
                  break;
                case UserRole.merchant:
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.merchantDashboard,
                  );
                  break;
                case UserRole.captain:
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.captainDashboard,
                  );
                  break;
                case UserRole.client:
                default:
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                  break;
              }
            });
          }
        });

        // Cancel subscription after 60 seconds (timeout)
        Future.delayed(const Duration(seconds: 60), () {
          subscription?.cancel();
        });
      } else {
        // Failed to launch browser
        SnackBarHelper.showError(
          context,
          authProvider.errorMessage ?? '❌ فشل فتح متصفح Google',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في تسجيل الدخول بواسطة جوجل',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      final success = await authProvider.signInWithFacebook();

      if (!mounted) return;

      if (success) {
        SnackBarHelper.showSuccess(
          context,
          '✅ تم تسجيل الدخول بواسطة فيسبوك بنجاح!',
        );

        // التنقل حسب دور المستخدم
        await authProvider.refreshProfile();
        final role = authProvider.currentProfile?.role;

        if (!mounted) return;

        if (role == UserRole.admin) {
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
        } else if (role == UserRole.deliveryCompanyAdmin) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.deliveryCompanyDashboard,
          );
        } else if (role == UserRole.merchant) {
          Navigator.pushReplacementNamed(context, AppRoutes.merchantDashboard);
        } else if (role == UserRole.captain) {
          Navigator.pushReplacementNamed(context, AppRoutes.captainDashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        if (authProvider.error != null) {
          SnackBarHelper.showError(context, authProvider.error!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في تسجيل الدخول بواسطة فيسبوك',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPasswordResetDialog() {
    final email = _emailController.text.trim();
    final emailValidation = Validators.validateEmail(email);
    if (emailValidation != null) {
      SnackBarHelper.showWarning(context, '⚠️ $emailValidation');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("استعادة كلمة المرور"),
        content: Text(
          "سيتم إرسال رابط استعادة كلمة المرور إلى:\n${_emailController.text.trim()}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog

              if (!mounted) return;
              SnackBarHelper.showLoading(
                context, // Use screen context
                '🔄 جاري إرسال رابط الاستعادة...',
              );

              try {
                final authProvider = Provider.of<SupabaseProvider>(
                  context, // Use screen context
                  listen: false,
                );
                final success = await authProvider.resetPassword(
                  _emailController.text.trim(),
                );

                if (!mounted) return;

                if (success) {
                  SnackBarHelper.showSuccess(
                    context, // Use screen context
                    '✅ تم إرسال رابط استعادة كلمة المرور بنجاح!',
                  );
                } else {
                  SnackBarHelper.showError(
                    context, // Use screen context
                    authProvider.error ?? 'فشل إرسال رابط استعادة كلمة المرور',
                  );
                }
              } catch (e) {
                if (!mounted) return;

                // استخراج الرسالة من Exception إذا كانت موجودة
                String errorMessage = e.toString();
                if (errorMessage.startsWith('Exception: ')) {
                  errorMessage = errorMessage.substring(
                    11,
                  ); // إزالة "Exception: "
                }

                // عرض رسالة مخصصة حسب نوع الخطأ
                if (errorMessage.contains('البريد الإلكتروني غير صالح') ||
                    errorMessage.contains('invalid-email')) {
                  SnackBarHelper.showError(
                    context, // Use screen context
                    '📧 البريد الإلكتروني غير صالح. تحقق من كتابته بشكل صحيح.',
                  );
                } else if (errorMessage.contains('user-not-found') ||
                    errorMessage.contains('لا يوجد حساب')) {
                  SnackBarHelper.showError(
                    context, // Use screen context
                    '👤 لا يوجد حساب بهذا البريد الإلكتروني. تأكد من البريد أو قم بإنشاء حساب جديد.',
                  );
                } else if (errorMessage.contains('network') ||
                    errorMessage.contains('internet')) {
                  SnackBarHelper.showError(
                    context,
                    '🌐 مشكلة في الاتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.',
                  );
                } else {
                  SnackBarHelper.showError(
                    context,
                    '❌ فشل في إرسال رابط الاستعادة. يرجى المحاولة مرة أخرى.',
                  );
                }
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
    final authProvider = Provider.of<SupabaseProvider>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return _buildWebLayout(context, authProvider, theme);
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 700;
    final logoSize = isCompact ? 64.0 : 85.0;
    final titleSize = isCompact ? 22.0 : 26.0;
    final subtitleSize = isCompact ? 14.0 : 16.0;
    final verticalPadding = isCompact ? 8.0 : 16.0;
    final topGap = isCompact ? 12.0 : 20.0;
    final titleGap = isCompact ? 6.0 : 8.0;
    final sectionGap = isCompact ? 24.0 : 40.0;
    final fieldGap = isCompact ? 14.0 : 20.0;
    final actionGap = isCompact ? 22.0 : 32.0;
    final loginGap = isCompact ? 26.0 : 36.0;
    final dividerGap = isCompact ? 20.0 : 28.0;
    final socialGap = isCompact ? 20.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A237E),
              size: 20,
            ),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: ResponsiveCenter(
        maxWidth: 600,
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                Colors.white,
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autovalidateMode,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🛒 الشعار والعنوان المحسن
                          Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icons/icon.png',
                                fit: BoxFit.cover,
                                width: logoSize,
                                height: logoSize,
                              ),
                            ),
                          ),
                          SizedBox(height: topGap),

                          Text(
                            "مرحباً بعودتك! 👋",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFF2D3748),
                              fontWeight: FontWeight.bold,
                              fontSize: titleSize,
                            ),
                          ),
                          SizedBox(height: titleGap),
                          Text(
                            "سجل دخولك لمتابعة التسوق والعروض الحصرية",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF718096),
                              fontSize: subtitleSize,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: sectionGap),

                          // 📧 البريد الإلكتروني المحسن
                          _buildModernTextField(
                            controller: _emailController,
                            label: "البريد الإلكتروني",
                            hintText: "example@gmail.com",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            focusNode: _emailFocus,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: Validators.validateEmail,
                            enabled: !_isLoading,
                          ),
                          SizedBox(height: fieldGap),

                          // 🔒 كلمة المرور المحسنة
                          _buildModernTextField(
                            controller: _passwordController,
                            label: "كلمة المرور",
                            hintText: "أدخل كلمة المرور",
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            focusNode: _passwordFocus,
                            onFieldSubmitted: (_) => _handleLogin(authProvider),
                            validator: Validators.validatePassword,
                            enabled: !_isLoading,
                          ),
                          SizedBox(height: fieldGap),

                          // ✅ تذكرني ونسيت كلمة المرور
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _rememberMe
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: _rememberMe
                                                ? theme.colorScheme.primary
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: _rememberMe
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "تذكرني",
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF4A5568),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _showPasswordResetDialog,
                                child: Text(
                                  "نسيت كلمة المرور؟",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: actionGap),

                          // 🟢 زر تسجيل الدخول
                          _buildModernButton(
                            onPressed: () => _handleLogin(authProvider),
                            text: "تسجيل الدخول 🚀",
                            isLoading: _isLoading,
                            theme: theme,
                          ),
                          SizedBox(height: loginGap),

                          // ➖ فاصل أنيق
                          _buildDivider(),
                          SizedBox(height: dividerGap),

                          // 🔵 أزرار التسجيل الاجتماعي
                          Row(
                            children: [
                              _buildSocialButton(
                                onTap: _isLoading ? null : _handleGoogleLogin,
                                iconPath: 'assets/icons/icons8-google-192.png',
                                label: 'Google',
                                enabled: !_isLoading,
                              ),
                              const SizedBox(width: 12),
                              _buildSocialButton(
                                onTap: _isLoading ? null : _handleFacebookLogin,
                                iconPath: 'assets/icons/icons8-facebook-96.png',
                                label: 'Facebook',
                                enabled: !_isLoading,
                              ),
                            ],
                          ),
                          SizedBox(height: socialGap),

                          // 📝 رابط إنشاء حساب
                          _buildSignupLink(theme),
                        ],
                      ),
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

  // بناء حقل إدخال حديث
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    required bool enabled,
    TextInputType? keyboardType,
    bool isPassword = false,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        enabled: enabled,
        obscureText: isPassword ? _obscurePassword : false,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        focusNode: focusNode,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D3748),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[600],
                    size: 22,
                  ),
                  onPressed: enabled
                      ? () =>
                            setState(() => _obscurePassword = !_obscurePassword)
                      : null,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          errorStyle: const TextStyle(
            color: Colors.red,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // بناء زر حديث
  Widget _buildModernButton({
    required VoidCallback onPressed,
    required String text,
    required bool isLoading,
    required ThemeData theme,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading
            ? null
            : LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: isLoading ? Colors.grey[300] : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: AppShimmer.wrap(
                          context,
                          child: AppShimmer.circle(context, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "جاري تسجيل الدخول...",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // بناء فاصل أنيق
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.grey[300]!],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            "أو",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[300]!, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // بناء زر التواصل الاجتماعي
  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required String iconPath,
    required String label,
    required bool enabled,
  }) {
    return Expanded(
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    iconPath,
                    width: 24,
                    height: 24,
                    color: enabled ? null : Colors.grey[400],
                    colorBlendMode: enabled ? null : BlendMode.saturation,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? const Color(0xFF4A5568)
                          : Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // بناء رابط التسجيل
  Widget _buildSignupLink(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "ليس لديك حساب؟ ",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF718096),
              fontSize: 16,
            ),
          ),
          MouseRegion(
            cursor: _isLoading
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.register),
              child: Text(
                "إنشاء حساب جديد",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Web / Desktop Two-Column Layout
  // =====================================================

  Widget _buildWebLayout(
    BuildContext context,
    SupabaseProvider authProvider,
    ThemeData theme,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // ── الجانب الأيسر: لوحة العلامة التجارية ──
          Expanded(flex: 4, child: _buildBrandingPanel(theme)),
          // ── الجانب الأيمن: نموذج تسجيل الدخول ──
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 56,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autovalidateMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── زر الرجوع ──
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                  color: Color(0xFF1A237E),
                                ),
                                onPressed: () => Navigator.pop(context),
                                tooltip: 'رجوع',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'مرحباً بعودتك! 👋',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFF1A237E),
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سجل دخولك لمتابعة التسوق والعروض الحصرية',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF718096),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildModernTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني',
                            hintText: 'example@gmail.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            focusNode: _emailFocus,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: Validators.validateEmail,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          _buildModernTextField(
                            controller: _passwordController,
                            label: 'كلمة المرور',
                            hintText: 'أدخل كلمة المرور',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            focusNode: _passwordFocus,
                            onFieldSubmitted: (_) => _handleLogin(authProvider),
                            validator: Validators.validatePassword,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _rememberMe
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: _rememberMe
                                                ? theme.colorScheme.primary
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: _rememberMe
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تذكرني',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF4A5568),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _showPasswordResetDialog,
                                child: Text(
                                  'نسيت كلمة المرور؟',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildModernButton(
                            onPressed: () => _handleLogin(authProvider),
                            text: 'تسجيل الدخول 🚀',
                            isLoading: _isLoading,
                            theme: theme,
                          ),
                          const SizedBox(height: 32),
                          _buildDivider(),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _buildSocialButton(
                                onTap: _isLoading ? null : _handleGoogleLogin,
                                iconPath: 'assets/icons/icons8-google-192.png',
                                label: 'Google',
                                enabled: !_isLoading,
                              ),
                              const SizedBox(width: 12),
                              _buildSocialButton(
                                onTap: _isLoading ? null : _handleFacebookLogin,
                                iconPath: 'assets/icons/icons8-facebook-96.png',
                                label: 'Facebook',
                                enabled: !_isLoading,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildSignupLink(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, const Color(0xFF1A237E)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      'التل ماركت',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'تسوّق بذكاء، ادفع بأمان',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 52),
                  _webFeatureRow(
                    Icons.local_shipping_rounded,
                    'توصيل سريع لباب بيتك',
                  ),
                  _webFeatureRow(
                    Icons.local_offer_rounded,
                    'أفضل الأسعار والعروض',
                  ),
                  _webFeatureRow(
                    Icons.verified_user_rounded,
                    'دفع آمن ومضمون 100%',
                  ),
                  _webFeatureRow(
                    Icons.track_changes_rounded,
                    'تتبع طلباتك لحظة بلحظة',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
