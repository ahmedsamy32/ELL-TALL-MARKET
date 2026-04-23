import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/widgets/password_strength_indicator.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/services/network_manager.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'dart:async';
import 'package:ell_tall_market/services/merchant_draft_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Draft save debounce
  Timer? _draftSaveTimer;
  // بناء صندوق الشروط والأحكام
  Widget _buildTermsCheckbox(ThemeData theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1100),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() => _agreeToTerms = value ?? false);
                    },
                    activeColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: "أوافق على ",
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: "الشروط والأحكام",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pushNamed(
                              context,
                              AppRoutes.termsConditions,
                            ),
                        ),
                        const TextSpan(text: " و"),
                        TextSpan(
                          text: "سياسة الخصوصية",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pushNamed(
                              context,
                              AppRoutes.privacyPolicy,
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // FocusNodes للتحكم في الانتقال بين الحقول
  final _firstNameFocus = FocusNode();
  final _middleNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _currentPassword = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // إضافة مستمع لتحديث مؤشر قوة كلمة المرور
    _passwordController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPassword = _passwordController.text;
        });
      }
    });

    // حفظ مسودة البيانات الشخصية تلقائياً (بدون كلمات المرور)
    _firstNameController.addListener(_scheduleDraftSave);
    _middleNameController.addListener(_scheduleDraftSave);
    _lastNameController.addListener(_scheduleDraftSave);
    _emailController.addListener(_scheduleDraftSave);
    _phoneController.addListener(_scheduleDraftSave);

    // استرجاع المسودة إن وجدت
    _restoreDraftIfAny();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // Draft persistence helpers (client registration)
  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    final fullName = [
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((p) => p.isNotEmpty).join(' ');

    final draft = MerchantDraft(
      fullName: fullName,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    await MerchantDraftService.save(draft);
  }

  Future<void> _restoreDraftIfAny() async {
    final draft = await MerchantDraftService.load();
    if (!mounted || draft == null) return;
    if (draft.fullName?.isNotEmpty == true) {
      final parts = draft.fullName!.split(' ');
      _firstNameController.text = parts.isNotEmpty ? parts[0] : '';
      _middleNameController.text = parts.length > 1 ? parts[1] : '';
      _lastNameController.text = parts.length > 2
          ? parts.sublist(2).join(' ')
          : '';
    }
    if (draft.email?.isNotEmpty == true) {
      _emailController.text = draft.email!;
    }
    if (draft.phone?.isNotEmpty == true) {
      _phoneController.text = draft.phone!;
    }
  }

  // دالة مساعدة للعمليات التي تحتاج فحص الإنترنت
  Future<bool> _checkInternetAndShowDialog() async {
    final hasInternet = NetworkManager().isConnected;
    if (!hasInternet) {
      _showNoInternetDialog();
      return false;
    }
    return true;
  }

  // دالة مساعدة لمعالجة رسائل الخطأ المتكررة
  String _getErrorMessage(String errorMessage) {
    if (errorMessage.contains('HandshakeException') ||
        errorMessage.contains('Connection terminated') ||
        errorMessage.contains('SocketException') ||
        errorMessage.contains('Network is unreachable')) {
      return 'مشكلة في الاتصال بالخادم 🌐\n\nيرجى:\n• التحقق من اتصال الإنترنت\n• المحاولة مرة أخرى بعد قليل\n• إعادة تشغيل التطبيق إذا استمرت المشكلة';
    } else if (errorMessage.contains('timeout') ||
        errorMessage.contains('TimeoutException')) {
      return 'انتهت مهلة الاتصال ⏱️\n\nيرجى المحاولة مرة أخرى';
    } else if (errorMessage.contains('certificate') ||
        errorMessage.contains('SSL') ||
        errorMessage.contains('TLS')) {
      return 'مشكلة في أمان الاتصال 🔒\n\nيرجى:\n• التحقق من تاريخ ووقت الجهاز\n• المحاولة مرة أخرى\n• الاتصال بالدعم الفني';
    } else if (errorMessage.contains('over_email_send_rate_limit')) {
      // استخراج عدد الثواني من رسالة الخطأ
      final match = RegExp(r'after (\d+) seconds').firstMatch(errorMessage);
      final seconds = match != null ? match.group(1) : '60';
      return 'تم إرسال عدد كبير من الرسائل 📨\n\nيرجى الانتظار $seconds ثانية والمحاولة مرة أخرى';
    } else if (errorMessage.contains('User already registered') ||
        errorMessage.contains('already exists') ||
        errorMessage.contains('email_already_verified')) {
      return 'هذا البريد الإلكتروني مسجل ومؤكد مسبقاً 📧\n\nيرجى تسجيل الدخول بدلاً من إنشاء حساب جديد.';
    } else if (errorMessage.contains('foreign key constraint') ||
        errorMessage.contains('profiles_id_fkey') ||
        errorMessage.contains('foreign_key_error')) {
      return 'حدثت مشكلة في ربط بيانات الحساب 🔗\n\nهذا يحدث أحياناً بسبب:\n• البريد مسجل مسبقاً بحساب آخر\n• مشكلة مؤقتة في الخادم\n\nالحلول:\n✅ جرب تسجيل الدخول إذا كان لديك حساب\n✅ انتظر دقيقة واحدة ثم أعد المحاولة\n✅ تأكد من اتصال الإنترنت';
    } else if (errorMessage.contains('duplicate key value') ||
        errorMessage.contains('duplicate_email')) {
      return 'البيانات موجودة مسبقاً 📧\n\nهذا البريد الإلكتروني مسجل بالفعل.\nيرجى تسجيل الدخول بدلاً من إنشاء حساب جديد.';
    }
    return errorMessage;
  }

  // دالة مساعدة للتنقل لشاشة تأكيد البريد الإلكتروني
  Future<void> _navigateToEmailConfirmation(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.emailConfirmation,
        arguments: {
          'email': email,
          'password': password, // إرسال كلمة المرور للتحقق
        },
      );
    }
  }

  Future<void> _handleRegistration(SupabaseProvider authProvider) async {
    // تفعيل التحقق بعد أول محاولة تسجيل
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      SnackBarHelper.showWarning(
        context,
        '⚠️ يرجى تصحيح الأخطاء في النموذج أولاً',
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      if (!_agreeToTerms) {
        SnackBarHelper.showWarning(
          context,
          '⚠️ يجب الموافقة على الشروط والأحكام أولاً',
        );
        return;
      }

      // فحص الاتصال بالإنترنت أولاً
      AppLogger.debug("فحص الاتصال بالإنترنت...");
      if (!await _checkInternetAndShowDialog()) return;

      AppLogger.debug("تم التأكد من وجود اتصال بالإنترنت");

      final userEmail = _emailController.text.trim();
      final userPassword = _passwordController.text;
      final userName = [
        _firstNameController.text.trim(),
        _middleNameController.text.trim(),
        _lastNameController.text.trim(),
      ].where((p) => p.isNotEmpty).join(' ');
      final userPhone = _phoneController.text.trim();

      try {
        AppLogger.debug("🔄 بدء السيناريو: فحص البريد $userEmail");

        // ═══════════════════════════════════════════════════════════════
        // 🔍 السيناريو 1: التحقق من وجود البريد في قاعدة البيانات
        // ═══════════════════════════════════════════════════════════════
        if (!mounted) return;
        SnackBarHelper.showLoading(context, '🔄 جاري فحص البيانات...');

        final existingProfile = await Supabase.instance.client
            .from('profiles')
            .select('id, email, role')
            .eq('email', userEmail)
            .maybeSingle();

        if (!mounted) {
          AppLogger.warning("الشاشة غير مركبة - إنهاء العملية");
          return;
        }

        ScaffoldMessenger.of(context).clearSnackBars();

        if (existingProfile != null) {
          // ═══════════════════════════════════════════════════════════
          // ⚠️ السيناريو 2: البريد مسجل مسبقاً
          // ═══════════════════════════════════════════════════════════
          AppLogger.info(
            "السيناريو 2: البريد مسجل مسبقاً (${existingProfile['role']}) - توجيه لتسجيل الدخول",
          );

          SnackBarHelper.showInfo(
            context,
            '✅ هذا البريد مسجل مسبقاً. سيتم توجيهك لتسجيل الدخول.',
            duration: const Duration(seconds: 2),
          );

          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.login,
              arguments: {'prefillEmail': userEmail},
            );
          }
          return;
        }

        // ═══════════════════════════════════════════════════════════
        // ✨ السيناريو 3: البريد غير مسجل - إنشاء حساب جديد
        // ═══════════════════════════════════════════════════════════
        AppLogger.debug("السيناريو 3: البريد غير مسجل - إنشاء حساب جديد");
        SnackBarHelper.showLoading(context, '🔄 جاري إنشاء الحساب...');

        final registerResult = await authProvider.signUp(
          name: userName,
          email: userEmail,
          password: userPassword,
          phone: userPhone,
          userType: 'client',
        );

        if (!mounted) {
          AppLogger.warning("الشاشة غير مركبة - إنهاء العملية");
          return;
        }

        ScaffoldMessenger.of(context).clearSnackBars();

        if (registerResult?.user != null) {
          AppLogger.info("نجح إنشاء الحساب الجديد - توجيه لشاشة التأكيد");

          SnackBarHelper.showSuccess(
            context,
            '✅ تم إنشاء الحساب بنجاح! تحقق من بريدك الإلكتروني لتأكيد الحساب.',
            duration: const Duration(seconds: 3),
          );

          // مسح المسودة بعد نجاح إنشاء الحساب
          await MerchantDraftService.clear();

          await _navigateToEmailConfirmation(userEmail, userPassword);
        } else {
          if (!mounted) return;
          SnackBarHelper.showLoading(context, '🔄 جاري إنشاء الحساب...');

          final errorMessage = authProvider.errorMessage ?? 'حدث خطأ غير متوقع';
          String userFriendlyMessage = _getErrorMessage(errorMessage);

          SnackBarHelper.showError(
            context,
            '❌ $userFriendlyMessage',
            duration: const Duration(seconds: 5),
          );
        }
      } catch (e) {
        AppLogger.error("خطأ في عملية التسجيل", e);

        if (!mounted) {
          AppLogger.warning("الشاشة غير مركبة - لا يمكن عرض الخطأ");
          return;
        }

        ScaffoldMessenger.of(context).clearSnackBars();

        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        String userFriendlyMessage = _getErrorMessage(errorMessage);

        AppLogger.debug("رسالة الخطأ المعالجة: $userFriendlyMessage");

        SnackBarHelper.showError(
          context,
          '❌ $userFriendlyMessage',
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  // تسجيل بواسطة Google
  Future<void> _handleGoogleRegister() async {
    try {
      AppLogger.debug("فحص الاتصال قبل تسجيل Google...");
      if (!await _checkInternetAndShowDialog()) return;

      if (!mounted) return;

      AppLogger.debug("بدء تسجيل دخول Google...");
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // Launch Google OAuth browser
      final launched = await authProvider.signInWithGoogle();
      if (!mounted) return;

      AppLogger.info("نتيجة فتح متصفح Google: $launched");

      if (launched) {
        // Browser opened successfully - show message and wait for callback
        AppLogger.info("تم فتح متصفح Google بنجاح");
        SnackBarHelper.showInfo(context, '🔄 يرجى إكمال التسجيل في المتصفح...');

        // Set up a one-time listener for auth state changes
        StreamSubscription<User?>? subscription;
        subscription = authProvider.authStateChanges.listen((user) {
          if (user != null && mounted) {
            // Cancel immediately to prevent multiple calls
            subscription?.cancel();

            // User signed in successfully via OAuth callback
            ScaffoldMessenger.of(context).clearSnackBars();
            SnackBarHelper.showSuccess(
              context,
              '✅ تم التسجيل بواسطة جوجل بنجاح!',
            );
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        });

        // Cancel subscription after 60 seconds (timeout)
        Future.delayed(const Duration(seconds: 60), () {
          subscription?.cancel();
        });
      } else {
        AppLogger.warning("فشل فتح متصفح Google");
        SnackBarHelper.showError(
          context,
          authProvider.errorMessage ?? '❌ فشل فتح متصفح Google',
        );
      }
    } catch (e) {
      AppLogger.error("خطأ في Google", e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
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
      AppLogger.debug("فحص الاتصال قبل تسجيل Facebook...");
      if (!await _checkInternetAndShowDialog()) return;

      if (!mounted) return;

      AppLogger.debug("بدء تسجيل دخول Facebook...");
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      SnackBarHelper.showLoading(context, '🔄 جاري التسجيل بواسطة فيسبوك...');

      final success = await authProvider.signInWithFacebook();
      if (!mounted) return;

      // إخفاء مؤشر التحميل
      ScaffoldMessenger.of(context).clearSnackBars();

      AppLogger.info("نتيجة تسجيل Facebook: $success");

      if (success) {
        AppLogger.info("نجح تسجيل Facebook");
        SnackBarHelper.showSuccess(
          context,
          '✅ تم التسجيل بواسطة فيسبوك بنجاح!',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        AppLogger.warning("فشل تسجيل Facebook");
        SnackBarHelper.showError(context, '❌ فشل التسجيل بواسطة فيسبوك');
      }
    } catch (e) {
      AppLogger.error("خطأ في Facebook", e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في التسجيل بواسطة فيسبوك',
        duration: const Duration(seconds: 4),
      );
    }
  }

  // عرض حوار عدم وجود اتصال بالإنترنت
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Colors.orange.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "لا يوجد اتصال بالإنترنت",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "🌐 يحتاج التطبيق لاتصال قوي بالإنترنت للعمل بشكل صحيح",
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "نصائح لحل المشكلة:",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• تأكد من قوة إشارة الواي فاي (WiFi)"),
                  Text("• جرب استخدام بيانات الهاتف المحمول"),
                  Text("• تأكد من تاريخ ووقت الجهاز"),
                  Text("• أعد تشغيل التطبيق"),
                  Text("• تحقق من إعدادات جدار الحماية"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // إعادة فحص الاتصال
              final hasInternet = NetworkManager().isConnected;
              if (hasInternet) {
                SnackBarHelper.showSuccess(
                  context,
                  '✅ تم استعادة الاتصال بالإنترنت!',
                );
              } else {
                SnackBarHelper.showError(
                  context,
                  '❌ لا يزال لا يوجد اتصال بالإنترنت',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("إعادة المحاولة"),
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
    final topGap = isCompact ? 12.0 : 24.0;
    final titleGap = isCompact ? 6.0 : 12.0;
    final sectionGap = isCompact ? 24.0 : 40.0;
    final blockGap = isCompact ? 20.0 : 32.0;

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
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: ResponsiveCenter(
        maxWidth: 600,
        child: Stack(
          children: [
            // الخلفية المتدرجة مع الأشكال الديكورية
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE3F2FD), // أزرق فاتح جداً
                    const Color(0xFFBBDEFB), // أزرق فاتح
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // أشكال ديكورية خلفية
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withValues(alpha: 0.08),
                ),
              ),
            ),

            // المحتوى الرئيسي
            SafeArea(
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
                            // الهيدر المحسّن
                            Hero(
                              tag: 'shopping_icon',
                              child: Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
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
                            ),
                            SizedBox(height: topGap),

                            // العنوان والوصف
                            Text(
                              "🛒 إنشاء حساب جديد",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF1A237E),
                                fontWeight: FontWeight.bold,
                                fontSize: titleSize,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: titleGap),
                            Text(
                              "سجل للشراء وتتبع طلباتك بسهولة ✨",
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                                fontSize: subtitleSize,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: sectionGap),

                            // حقول الاسم (الأول + الثاني) في صف واحد
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnimatedTextField(
                                    controller: _firstNameController,
                                    label: "الاسم الأول 👤",
                                    hintText: "أحمد",
                                    icon: Icons.person_outline_rounded,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    focusNode: _firstNameFocus,
                                    onFieldSubmitted: (_) =>
                                        _middleNameFocus.requestFocus(),
                                    validator: Validators.validateName,
                                    delay: 100,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnimatedTextField(
                                    controller: _middleNameController,
                                    label: "الاسم الثاني 👤",
                                    hintText: "سامي",
                                    icon: Icons.person_outline_rounded,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    focusNode: _middleNameFocus,
                                    onFieldSubmitted: (_) =>
                                        _lastNameFocus.requestFocus(),
                                    validator: Validators.validateName,
                                    delay: 120,
                                  ),
                                ),
                              ],
                            ),

                            _buildAnimatedTextField(
                              controller: _lastNameController,
                              label: "اسم العائلة 👤",
                              hintText: "عبدالهادي",
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              focusNode: _lastNameFocus,
                              onFieldSubmitted: (_) =>
                                  _emailFocus.requestFocus(),
                              validator: Validators.validateName,
                              delay: 140,
                            ),

                            _buildAnimatedTextField(
                              controller: _emailController,
                              label: "البريد الإلكتروني 📧",
                              hintText: "example@email.com",
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              focusNode: _emailFocus,
                              onFieldSubmitted: (_) =>
                                  _phoneFocus.requestFocus(),
                              validator: Validators.validateEmail,
                              delay: 200,
                            ),

                            _buildAnimatedTextField(
                              controller: _phoneController,
                              label: "رقم الهاتف 📱",
                              hintText: "*********01",
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              prefixText: "+20 🇪🇬 ",
                              textInputAction: TextInputAction.next,
                              focusNode: _phoneFocus,
                              onFieldSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                              validator: Validators.validatePhone,
                              delay: 300,
                            ),

                            _buildAnimatedTextField(
                              controller: _passwordController,
                              label: "كلمة المرور 🔒",
                              hintText: "أدخل كلمة مرور قوية",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                              focusNode: _passwordFocus,
                              onFieldSubmitted: (_) =>
                                  _confirmPasswordFocus.requestFocus(),
                              validator: Validators.validatePassword,
                              delay: 400,
                            ),

                            // مؤشر قوة كلمة المرور مع الأنيميشن
                            TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 800),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: PasswordStrengthIndicator(
                                      password: _currentPassword,
                                    ),
                                  ),
                                );
                              },
                            ),

                            _buildAnimatedTextField(
                              controller: _confirmPasswordController,
                              label: "تأكيد كلمة المرور 🔒",
                              hintText: "أعد كتابة كلمة المرور",
                              icon: Icons.lock_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              focusNode: _confirmPasswordFocus,
                              onFieldSubmitted: (_) =>
                                  _handleRegistration(authProvider),
                              validator: (value) =>
                                  Validators.validateConfirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                              delay: 500,
                            ),

                            SizedBox(height: isCompact ? 16 : 24),

                            // الموافقة على الشروط المحسّنة
                            _buildTermsCheckbox(theme),

                            SizedBox(height: isCompact ? 20 : 28),

                            // زر التسجيل المحسّن
                            _buildRegisterButton(authProvider, theme),

                            SizedBox(height: blockGap),

                            // فاصل "أو"
                            _buildOrDivider(theme),

                            SizedBox(height: isCompact ? 16 : 24),

                            // أزرار التسجيل الاجتماعي المحسّنة
                            _buildSocialButtons(authProvider, theme),

                            SizedBox(height: blockGap),

                            // رابط تسجيل الدخول المحسّن
                            _buildLoginLink(theme),
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
      ),
    );
  }

  // بناء حقل إدخال متحرك
  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    required int delay,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? prefixText,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    // تحديد متغير الإخفاء حسب نوع الحقل
    bool obscureText = false;
    if (isPassword) {
      if (controller == _passwordController) {
        obscureText = _obscurePassword;
      } else if (controller == _confirmPasswordController) {
        obscureText = _obscureConfirmPassword;
      }
    }

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                validator: validator,
                keyboardType: keyboardType,
                obscureText: obscureText,
                textInputAction: textInputAction,
                onFieldSubmitted: onFieldSubmitted,
                focusNode: focusNode,
                maxLength: label.contains("رقم الهاتف") ? 11 : null,
                inputFormatters: label.contains("رقم الهاتف")
                    ? [
                        // Only allow numbers
                        FilteringTextInputFormatter.digitsOnly,
                      ]
                    : null,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixText: prefixText,
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, size: 22),
                  ),
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Icon(
                            obscureText
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              if (controller == _passwordController) {
                                _obscurePassword = !_obscurePassword;
                              } else if (controller ==
                                  _confirmPasswordController) {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              }
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1976D2),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  counterText: label.contains("رقم الهاتف") ? "" : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // بناء زر التسجيل المحسّن
  Widget _buildRegisterButton(SupabaseProvider authProvider, ThemeData theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1200),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: authProvider.isLoading
                    ? null
                    : () => _handleRegistration(authProvider),
                child: Center(
                  child: authProvider.isLoading
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
                            const Text(
                              "جاري إنشاء الحساب...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "إنشاء الحساب ✨",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // بناء فاصل "أو"
  Widget _buildOrDivider(ThemeData theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1300),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  "أو التسجيل عبر",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade400,
                        Colors.grey.shade300,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // بناء أزرار التسجيل الاجتماعي
  Widget _buildSocialButtons(SupabaseProvider authProvider, ThemeData theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1400),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Row(
              children: [
                // زر Google
                Expanded(
                  child: _buildSocialButton(
                    onTap: authProvider.isLoading
                        ? null
                        : _handleGoogleRegister,
                    iconPath: 'assets/icons/icons8-google-192.png',
                    label: 'Google',
                    backgroundColor: Colors.white,
                    borderColor: Colors.red.shade100,
                  ),
                ),
                const SizedBox(width: 16),
                // زر Facebook
                Expanded(
                  child: _buildSocialButton(
                    onTap: authProvider.isLoading
                        ? null
                        : _handleFacebookRegister,
                    iconPath: 'assets/icons/icons8-facebook-96.png',
                    label: 'Facebook',
                    backgroundColor: Colors.white,
                    borderColor: Colors.blue.shade100,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required String iconPath,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(iconPath, width: 22, height: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء رابط تسجيل الدخول
  Widget _buildLoginLink(ThemeData theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "لديك حساب بالفعل؟ ",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF718096),
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  child: Text(
                    "تسجيل الدخول",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          // ── الجانب الأيمن: نموذج التسجيل ──
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 56,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
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
                            '🛒 إنشاء حساب جديد',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFF1A237E),
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سجل للشراء وتتبع طلباتك بسهولة ✨',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 36),
                          // الاسم الأول + الثاني في صف
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedTextField(
                                  controller: _firstNameController,
                                  label: 'الاسم الأول 👤',
                                  hintText: 'أحمد',
                                  icon: Icons.person_outline_rounded,
                                  keyboardType: TextInputType.name,
                                  textInputAction: TextInputAction.next,
                                  focusNode: _firstNameFocus,
                                  onFieldSubmitted: (_) =>
                                      _middleNameFocus.requestFocus(),
                                  validator: Validators.validateName,
                                  delay: 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildAnimatedTextField(
                                  controller: _middleNameController,
                                  label: 'الاسم الثاني 👤',
                                  hintText: 'سامي',
                                  icon: Icons.person_outline_rounded,
                                  keyboardType: TextInputType.name,
                                  textInputAction: TextInputAction.next,
                                  focusNode: _middleNameFocus,
                                  onFieldSubmitted: (_) =>
                                      _lastNameFocus.requestFocus(),
                                  validator: Validators.validateName,
                                  delay: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // اسم العائلة كامل العرض
                          _buildAnimatedTextField(
                            controller: _lastNameController,
                            label: 'اسم العائلة 👤',
                            hintText: 'عبدالهادي',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            focusNode: _lastNameFocus,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            validator: Validators.validateName,
                            delay: 0,
                          ),
                          const SizedBox(height: 16),
                          // البريد + الهاتف في صف
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedTextField(
                                  controller: _emailController,
                                  label: 'البريد الإلكتروني 📧',
                                  hintText: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  focusNode: _emailFocus,
                                  onFieldSubmitted: (_) =>
                                      _phoneFocus.requestFocus(),
                                  validator: Validators.validateEmail,
                                  delay: 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildAnimatedTextField(
                                  controller: _phoneController,
                                  label: 'رقم الهاتف 📱',
                                  hintText: '*********01',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  prefixText: '+20 🇪🇬 ',
                                  textInputAction: TextInputAction.next,
                                  focusNode: _phoneFocus,
                                  onFieldSubmitted: (_) =>
                                      _passwordFocus.requestFocus(),
                                  validator: Validators.validatePhone,
                                  delay: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // كلمة المرور كامل العرض
                          _buildAnimatedTextField(
                            controller: _passwordController,
                            label: 'كلمة المرور 🔒',
                            hintText: 'أدخل كلمة مرور قوية',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            focusNode: _passwordFocus,
                            onFieldSubmitted: (_) =>
                                _confirmPasswordFocus.requestFocus(),
                            validator: Validators.validatePassword,
                            delay: 0,
                          ),
                          const SizedBox(height: 8),
                          PasswordStrengthIndicator(password: _currentPassword),
                          const SizedBox(height: 16),
                          // تأكيد كلمة المرور
                          _buildAnimatedTextField(
                            controller: _confirmPasswordController,
                            label: 'تأكيد كلمة المرور 🔒',
                            hintText: 'أعد كتابة كلمة المرور',
                            icon: Icons.lock_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            focusNode: _confirmPasswordFocus,
                            onFieldSubmitted: (_) =>
                                _handleRegistration(authProvider),
                            validator: (value) =>
                                Validators.validateConfirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                            delay: 0,
                          ),
                          const SizedBox(height: 24),
                          _buildTermsCheckbox(theme),
                          const SizedBox(height: 24),
                          _buildRegisterButton(authProvider, theme),
                          const SizedBox(height: 28),
                          _buildOrDivider(theme),
                          const SizedBox(height: 20),
                          _buildSocialButtons(authProvider, theme),
                          const SizedBox(height: 24),
                          _buildLoginLink(theme),
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
