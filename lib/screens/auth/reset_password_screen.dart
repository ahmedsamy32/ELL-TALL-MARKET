import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/validators.dart';

/// 🔑 شاشة استعادة كلمة المرور مع دعم Supabase Auth
/// تم تحديثها لاستخدام الوثائق الرسمية
/// https://supabase.com/docs/reference/dart/auth-resetpasswordforemail
/// https://supabase.com/docs/reference/dart/auth-updateuser
class ResetPasswordScreen extends StatefulWidget {
  final String? token; // token من Supabase recovery link
  final String? tokenHash; // tokenHash من Supabase recovery link
  final String? type; // نوع العملية (recovery)

  const ResetPasswordScreen({super.key, this.token, this.tokenHash, this.type});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResetMode = false; // true إذا جاء المستخدم من رابط recovery
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _verifiedEmail;

  @override
  void initState() {
    super.initState();

    // التحقق من وجود token للدخول في وضع إعادة تعيين كلمة المرور
    if (widget.token != null && widget.tokenHash != null) {
      _isResetMode = true;
      _verifyRecoveryToken();
    }
  }

  /// ✅ التحقق من token recovery من Supabase
  Future<void> _verifyRecoveryToken() async {
    if (widget.token == null || widget.tokenHash == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // التحقق من token باستخدام Supabase Auth
      await authProvider.verifyPasswordResetToken(widget.token!);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم التحقق من الرابط بنجاح. يمكنك الآن تغيير كلمة المرور',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isResetMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ رابط غير صالح أو منتهي الصلاحية: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 📧 إرسال رابط استعادة كلمة المرور
  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      await authProvider.sendPasswordResetEmailSimple(
        _emailController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // العودة للشاشة السابقة بعد الإرسال
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل في إرسال الرابط: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🔐 تأكيد استعادة كلمة المرور باستخدام Supabase Auth
  Future<void> _confirmPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // تحديث كلمة المرور باستخدام Supabase Auth
      await authProvider.updatePasswordWithSupabase(_passwordController.text);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تغيير كلمة المرور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // الانتقال لشاشة تسجيل الدخول
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل في تغيير كلمة المرور: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isResetMode ? 'إعادة تعيين كلمة المرور' : 'استعادة كلمة المرور',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الأيقونة والعنوان
              _buildHeader(),

              const SizedBox(height: 40),

              // النموذج
              _isResetMode ? _buildPasswordResetForm() : _buildEmailForm(),

              const SizedBox(height: 30),

              // زر الإجراء
              _buildActionButton(),

              const SizedBox(height: 20),

              // رابط العودة لتسجيل الدخول
              _buildBackToLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  /// 📋 رأس الشاشة
  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              _isResetMode ? Icons.lock_reset : Icons.mail_outline,
              size: 40,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            _isResetMode ? 'إعادة تعيين كلمة المرور' : 'استعادة كلمة المرور',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _isResetMode
                ? 'أدخل كلمة المرور الجديدة لحسابك${_verifiedEmail != null ? '\n$_verifiedEmail' : ''}'
                : 'أدخل بريدك الإلكتروني وسنرسل لك رابط استعادة كلمة المرور',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 📧 نموذج إدخال البريد الإلكتروني
  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              hintText: 'أدخل بريدك الإلكتروني',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            validator: Validators.validateEmail,
          ),
        ],
      ),
    );
  }

  /// 🔐 نموذج إعادة تعيين كلمة المرور
  Widget _buildPasswordResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // كلمة المرور الجديدة
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              hintText: 'أدخل كلمة مرور قوية',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            validator: Validators.validatePassword,
          ),

          const SizedBox(height: 20),

          // تأكيد كلمة المرور
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              hintText: 'أعد إدخال كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'كلمتا المرور غير متطابقتين';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// 🔘 زر الإجراء
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (_isResetMode ? _confirmPasswordReset : _sendResetEmail),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isResetMode
                    ? 'تأكيد كلمة المرور الجديدة'
                    : 'إرسال رابط الاستعادة',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  /// 🔗 رابط العودة لتسجيل الدخول
  Widget _buildBackToLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        child: Text(
          'العودة إلى تسجيل الدخول',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
