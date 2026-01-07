import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/core/logger.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  final String? password; // كلمة المرور للتحقق من التأكيد
  final String? userType; // نوع المستخدم (merchant أو client)

  const EmailConfirmationScreen({
    super.key,
    required this.email,
    this.password,
    this.userType,
  });

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _fadeController;
  late Animation<double> _iconAnimation;
  late Animation<double> _fadeAnimation;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();

    // طباعة معلومات التتبع عند تحميل الشاشة
    AppLogger.debug("تحميل شاشة تأكيد البريد");
    AppLogger.info("البريد المستلم: ${widget.email}");

    // فحص المعاملات أيضاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      AppLogger.info("معاملات التوجيه: $args");
      if (args is Map<String, dynamic>) {
        AppLogger.info("الإيميل من المعاملات: ${args['email']}");
        AppLogger.info("نوع المستخدم من المعاملات: ${args['userType']}");

        // Check if there's an expired link error in arguments
        if (args['expired_link'] == true) {
          final errorMessage =
              args['error_message'] as String? ?? 'انتهت صلاحية رابط التأكيد';
          _handleExpiredLinkError(errorMessage);
          return; // لا نعرض أخطاء Provider إذا كان هناك خطأ رابط منتهي
        }
      }

      // مسح الأخطاء السابقة من Provider أولاً
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      authProvider.clearError();

      // ملاحظة: لا نحتاج للتحقق من errorMessage هنا لأننا مسحناها
      // فقط روابط Deep Links المنتهية هي التي تعرض رسالة خطأ
    });

    AppLogger.debug("نجح استلام معاملات التوجيه");

    // تحكم في أنيميشن الأيقونة
    _iconController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // تحكم في أنيميشن التلاشي
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // بدء الأنيميشن
    _iconController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _iconController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Handle expired or invalid email link errors
  void _handleExpiredLinkError([String? customMessage]) {
    if (!mounted) return;

    final message = customMessage ?? 'انتهت صلاحية رابط التأكيد';

    // Show warning and resend immediately
    SnackBarHelper.showWarning(
      context,
      '⚠️ $message. جاري إرسال رابط جديد...',
      duration: const Duration(seconds: 3),
    );

    // Resend immediately without delay
    _resendConfirmationEmail();
  }

  Future<void> _resendConfirmationEmail() async {
    if (_isResending) return;

    // الحصول على الإيميل الصحيح
    String emailToUse = widget.email;
    if (emailToUse.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('email')) {
        emailToUse = args['email'] ?? '';
      }
    }

    if (emailToUse.isEmpty) {
      SnackBarHelper.showError(
        context,
        '❌ البريد الإلكتروني غير محدد. لا يمكن إعادة الإرسال',
      );
      return;
    }

    AppLogger.info('🔄 بدء إعادة إرسال تأكيد البريد إلى: $emailToUse');

    setState(() {
      _isResending = true;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      AppLogger.debug('📤 استدعاء resendEmailConfirmationSimple...');
      await authProvider.resendEmailConfirmationSimple(emailToUse);

      AppLogger.info('✅ نجح إرسال تأكيد البريد');

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          '✅ تم إعادة إرسال رسالة التأكيد بنجاح!',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      AppLogger.error('❌ فشل في إعادة إرسال تأكيد البريد', e);

      if (mounted) {
        String errorMessage = e.toString();

        if (errorMessage.contains('rate_limit') ||
            errorMessage.contains('too_many_requests') ||
            errorMessage.contains('email_rate_limit_exceeded')) {
          SnackBarHelper.showWarning(
            context,
            '⏳ تم إرسال عدد كبير من الرسائل. انتظر قليلاً قبل المحاولة مرة أخرى',
            duration: const Duration(seconds: 4),
          );
        } else if (errorMessage.contains('invalid_email') ||
            errorMessage.contains('email_not_found')) {
          SnackBarHelper.showError(
            context,
            '❌ البريد الإلكتروني غير صحيح أو غير موجود',
          );
        } else {
          SnackBarHelper.showError(
            context,
            '❌ فشل في إعادة إرسال رسالة التأكيد: ${e.toString()}',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  /// التحقق من تأكيد البريد ثم الانتقال لتسجيل الدخول
  Future<void> _checkConfirmationAndLogin() async {
    try {
      // الحصول على البريد الإلكتروني
      String emailToCheck = widget.email;
      String? passwordToCheck = widget.password;

      if (emailToCheck.isEmpty) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map<String, dynamic>) {
          emailToCheck = args['email'] ?? '';
          passwordToCheck = args['password'];
        }
      }

      if (emailToCheck.isEmpty) {
        SnackBarHelper.showError(context, '❌ البريد الإلكتروني غير محدد');
        return;
      }

      // إذا مافيش كلمة مرور، نوجه مباشرة لتسجيل الدخول
      if (passwordToCheck == null || passwordToCheck.isEmpty) {
        AppLogger.info('⚠️ لا توجد كلمة مرور - التوجيه لتسجيل الدخول');

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        SnackBarHelper.showInfo(
          context,
          'ℹ️ سيتم توجيهك لتسجيل الدخول',
          duration: const Duration(seconds: 2),
        );

        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.login,
            arguments: {'prefillEmail': emailToCheck},
          );
        }
        return;
      }

      SnackBarHelper.showLoading(context, '� جاري التحقق من حالة التأكيد...');

      // محاولة تسجيل دخول بكلمة المرور الحقيقية
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailToCheck,
          password: passwordToCheck,
        );

        // ✅ نجح تسجيل الدخول = البريد مؤكد!
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        AppLogger.info('✅ تم تسجيل الدخول بنجاح - البريد مؤكد');

        // فحص نوع المستخدم من arguments
        final args = ModalRoute.of(context)?.settings.arguments;
        final String? userType = args is Map<String, dynamic>
            ? args['userType']
            : widget.userType;
        final bool isMerchant = userType == 'merchant';

        // ملاحظة: سجل التاجر يتم إنشاؤه تلقائياً عبر trigger في قاعدة البيانات
        // عند إنشاء profile بـ role='merchant'، يتم إنشاء سجل في merchants تلقائياً

        SnackBarHelper.showSuccess(
          context,
          isMerchant
              ? '✅ رائع! بريدك الإلكتروني مؤكد ✓\n\nجاري نقلك لإكمال بيانات المتجر...'
              : '✅ رائع! بريدك الإلكتروني مؤكد ✓\n\nجاري نقلك لصفحة تسجيل الدخول...',
          duration: const Duration(seconds: 2),
        );

        // لا نحتاج تسجيل الخروج إذا كان تاجر (سيحتاج الجلسة لإنشاء المتجر)
        if (!isMerchant) {
          // تسجيل الخروج لأننا كنا بنجرب فقط
          await Supabase.instance.client.auth.signOut();
        }

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // توجيه المستخدم (تاجر أو عميل) لتسجيل الدخول
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.login,
            arguments: {'prefillEmail': emailToCheck},
          );
        }
      } on AuthException catch (authError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        final errorMessage = authError.message.toLowerCase();
        AppLogger.info('🔍 نتيجة التحقق: ${authError.message}');

        if (errorMessage.contains('email not confirmed') ||
            errorMessage.contains('email_not_confirmed') ||
            errorMessage.contains('confirm your email')) {
          // ❌ البريد غير مؤكد
          AppLogger.warning('⏳ البريد غير مؤكد');

          SnackBarHelper.showWarning(
            context,
            '⏳ البريد الإلكتروني لم يتم تأكيده بعد!\n\n'
            '📧 تحقق من صندوق بريدك واضغط على رابط التأكيد\n\n'
            '💡 لم تجد الرسالة؟\n'
            '• تحقق من مجلد Spam\n'
            '• اضغط "إعادة إرسال رسالة التأكيد"',
            duration: const Duration(seconds: 6),
          );
        } else if (errorMessage.contains('invalid login credentials') ||
            errorMessage.contains('invalid email or password')) {
          // كلمة المرور خاطئة - ممكن المستخدم غيرها
          SnackBarHelper.showWarning(
            context,
            '⚠️ كلمة المرور غير صحيحة\n\n'
            'استخدم زر "لدي حساب مؤكد - تسجيل الدخول"\n'
            'وأدخل كلمة المرور الصحيحة',
            duration: const Duration(seconds: 5),
          );
        } else if (errorMessage.contains('security purposes') ||
            errorMessage.contains('rate limit')) {
          SnackBarHelper.showWarning(
            context,
            '⏰ انتظر قليلاً ثم حاول مرة أخرى',
            duration: const Duration(seconds: 4),
          );
        } else {
          // خطأ آخر
          SnackBarHelper.showWarning(
            context,
            '⚠️ ${authError.message}\n\n'
            'استخدم زر "لدي حساب مؤكد - تسجيل الدخول"',
            duration: const Duration(seconds: 5),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      AppLogger.error('خطأ في فحص التأكيد', e);

      SnackBarHelper.showError(
        context,
        '❌ حدث خطأ في التحقق\n\nحاول مرة أخرى',
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // إذا لم يتم تمرير إيميل، نحاول الحصول عليه من المعاملات
    String emailToDisplay = widget.email;
    if (emailToDisplay.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('email')) {
        emailToDisplay = args['email'] ?? '';
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتدرجة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE3F2FD),
                  const Color(0xFFBBDEFB),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // أشكال ديكورية
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

          // المحتوى الرئيسي
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        24,
                  ),
                  child: IntrinsicHeight(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: -5,
                          ),
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // أيقونة البريد المتحركة
                            ScaleTransition(
                              scale: _iconAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(20),
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
                                child: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // العنوان الرئيسي
                            Text(
                              "📧 تأكيد البريد الإلكتروني",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF1A237E),
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 12),

                            // الرسالة التوضيحية
                            Text(
                              "تم إنشاء حسابك بنجاح! ✨",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 10),

                            // تفاصيل التأكيد
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    "تم إرسال رابط تأكيد إلى:",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      emailToDisplay.isNotEmpty
                                          ? emailToDisplay
                                          : "البريد الإلكتروني غير محدد",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: emailToDisplay.isNotEmpty
                                                ? theme.colorScheme.primary
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // التعليمات
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.amber[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "اضغط على الرابط في بريدك الإلكتروني لتأكيد حسابك والبدء في التسوق",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.amber[800],
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // زر إعادة الإرسال
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isResending
                                    ? null
                                    : _resendConfirmationEmail,
                                icon: _isResending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _isResending
                                      ? "جاري الإرسال..."
                                      : "إعادة إرسال رسالة التأكيد",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // زر "لقد أكدت البريد"
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _checkConfirmationAndLogin,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "لقد أكدت البريد - تحقق وادخل",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // زر الذهاب لتسجيل الدخول
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _goToLogin,
                                icon: Icon(
                                  Icons.login_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                label: Text(
                                  "لدي حساب مؤكد - تسجيل الدخول",
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // نصائح إضافية
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.grey[600],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "نصائح مفيدة:",
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTip(
                                    "• تحقق من مجلد الرسائل غير المرغوب فيها (Spam)",
                                  ),
                                  _buildTip(
                                    "• قد يستغرق وصول الإيميل بضع دقائق",
                                  ),
                                  _buildTip(
                                    "• تأكد من كتابة البريد الإلكتروني بشكل صحيح",
                                  ),
                                  _buildTip(
                                    "• صلاحية رابط التأكيد محدودة - اطلب رابط جديد إذا انتهت",
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
          fontSize: 13,
          height: 1.3,
        ),
      ),
    );
  }
}
