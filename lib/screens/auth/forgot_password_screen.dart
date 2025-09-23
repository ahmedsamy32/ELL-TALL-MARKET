import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isEmailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          _emailController.text.trim(),
        );

        setState(() {
          _isEmailSent = true;
          _errorMessage = null;
        });
      } on AuthException catch (e) {
        setState(() {
          _errorMessage = _getErrorMessage(e.message);
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع: $e';
        });
      }
    }
  }

  String _getErrorMessage(String errorMessage) {
    if (errorMessage.contains('Email not confirmed')) {
      return 'البريد الإلكتروني غير مؤكد';
    } else if (errorMessage.contains('Invalid email')) {
      return 'البريد الإلكتروني غير صالح';
    } else if (errorMessage.contains('User not found')) {
      return 'البريد الإلكتروني غير مسجل في النظام';
    } else if (errorMessage.contains('Too many requests')) {
      return 'تم طلب العديد من محاولات الاستعادة. يرجى الانتظار قليلاً';
    }
    return 'فشل إرسال رابط الاستعادة';
  }

  @override
  Widget build(BuildContext context) {
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
                        // 🔒 الشعار والعنوان
                        Icon(
                          Icons.lock_open_outlined,
                          size: 70,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "🔒 إعادة تعيين كلمة المرور",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "أ��خل بريدك الإلكتروني لتلقي رابط إعادة التعيين",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        if (!_isEmailSent) ...[
                          // 📧 حقل البريد الإلكتروني
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
                          const SizedBox(height: 24),

                          // 🚨 رسالة الخطأ
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50]!, // non-null
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!), // non-null
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_errorMessage != null) const SizedBox(height: 16),

                          // 🟢 زر الإرسال
                          CustomButton(
                            text: "إرسال رابط إعادة التعيين",
                            onPressed: _sendResetLink,
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ] else ...[
                          // ✅ تأكيد الإرسال
                          const Icon(
                            Icons.check_circle_outline,
                            size: 80,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "✅ تم إرسال رابط إعادة التعيين",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "تم إرسال رابط إعادة تعيين كلمة المرور إلى:",
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _emailController.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "يرجى التحقق من بريدك الإلكتروني ومتابعة التعليمات لإعادة تعيين كلمة المرور",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // 🔵 زر العودة
                          CustomButton(
                            text: "العودة لتسجيل الدخول",
                            onPressed: () => Navigator.pop(context),
                            backgroundColor: Colors.blue[50],
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // 🔗 رابط العودة لتسجيل الدخول (يظهر فقط قبل الإرسال)
                        if (!_isEmailSent)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              "تذكرت كلمة المرور؟ تسجيل الدخول",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}