import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';
import 'dart:io';

class RegisterMerchantScreen extends StatefulWidget {
  const RegisterMerchantScreen({super.key});

  @override
  _RegisterMerchantScreenState createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  final _nameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  File? _selectedImage;
  int _currentStep = 0;
  bool _isLoading = false;

  // مفاتيح لكل خطوة للتحقق من صحتها
  final GlobalKey<FormState> _step1FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step2FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step3FormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // تسجيل التاجر
  Future<void> _registerMerchant(FirebaseAuthProvider authProvider) async {
    if (!_validateAllSteps()) {
      _showErrorSnackBar("يرجى تعبئة جميع البيانات بشكل صحيح");
      return;
    }

    setState(() => _isLoading = true);
    try {
      print("🔄 [DEBUG] بدء تسجيل التاجر...");
      // تسجيل التاجر باستخدام Firebase Auth Provider
      final success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        userType: UserType.merchant,
        storeImage: _selectedImage,
      );

      print("🔄 [DEBUG] نتيجة تسجيل التاجر: $success");

      if (!success) {
        print("❌ [DEBUG] فشل تسجيل التاجر - success = false");
        throw Exception("فشل في إنشاء المستخدم");
      }

      if (!mounted) return;

      print("✅ [DEBUG] نجح تسجيل التاجر");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إنشاء الحساب بنجاح! تحقق من بريدك الإلكتروني."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pushReplacementNamed(context, AppRoutes.merchantDashboard);
    } on FirebaseAuthException catch (e) {
      print(
        "❌ [DEBUG] FirebaseAuthException في تسجيل التاجر: ${e.code} - ${e.message}",
      );
      String message = e.code == 'email-already-in-use'
          ? "البريد الإلكتروني مستخدم بالفعل"
          : e.code == 'invalid-email'
          ? "البريد الإلكتروني غير صالح"
          : e.code == 'weak-password'
          ? "كلمة المرور ضعيفة جداً"
          : "حدث خطأ في تسجيل الحساب: ${e.message}";
      _showErrorSnackBar(message);
    } catch (e) {
      print("❌ [DEBUG] خطأ عام في تسجيل التاجر: $e");
      _showErrorSnackBar("حدث خطأ أثناء التسجيل: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // عرض رسالة خطأ
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // التحقق من صحة جميع الخطوات
  bool _validateAllSteps() {
    return _step1FormKey.currentState?.validate() == true &&
        _step2FormKey.currentState?.validate() == true &&
        _step3FormKey.currentState?.validate() == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<FirebaseAuthProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("تسجيل تاجر جديد"),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Stepper(
            currentStep: _currentStep,
            onStepTapped: (step) {
              setState(() => _currentStep = step);
            },
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _registerMerchant(authProvider);
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                Navigator.pop(context);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text("رجوع"),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _currentStep == 2 ? "تسجيل التاجر" : "التالي",
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
            steps: [
              // Step 1: البيانات الشخصية
              Step(
                title: const Text("البيانات الشخصية"),
                content: Form(
                  key: _step1FormKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: "الاسم الكامل",
                        hintText: "أدخل اسمك الكامل",
                        prefixIcon: const Icon(Icons.person),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "الاسم مطلوب";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        label: "البريد الإلكتروني",
                        hintText: "example@gmail.com",
                        prefixIcon: const Icon(Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "البريد الإلكتروني مطلوب";
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return "البريد الإلكتروني غير صحيح";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _phoneController,
                        label: "رقم الهاتف",
                        hintText: "05xxxxxxxx",
                        prefixIcon: const Icon(Icons.phone),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "رقم الهاتف مطلوب";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 0,
              ),

              // Step 2: بيانات المتجر
              Step(
                title: const Text("بيانات المتجر"),
                content: Form(
                  key: _step2FormKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _storeNameController,
                        label: "اسم المتجر",
                        hintText: "أدخل اسم متجرك",
                        prefixIcon: const Icon(Icons.store),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "اسم المتجر مطلوب";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _addressController,
                        label: "العنوان",
                        hintText: "عنوان المتجر",
                        prefixIcon: const Icon(Icons.location_on),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "العنوان مطلوب";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 1,
              ),

              // Step 3: كلمة المرور
              Step(
                title: const Text("كلمة المرور"),
                content: Form(
                  key: _step3FormKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _passwordController,
                        label: "كلمة المرور",
                        hintText: "أدخل كلمة مرور قوية",
                        prefixIcon: const Icon(Icons.lock),
                        isPasswordField: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "كلمة المرور مطلوبة";
                          }
                          if (value.length < 6) {
                            return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: "تأكيد كلمة المرور",
                        hintText: "أعد إدخال كلمة المرور",
                        prefixIcon: const Icon(Icons.lock_outline),
                        isPasswordField: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "تأكيد كلمة المرور مطلوب";
                          }
                          if (value != _passwordController.text) {
                            return "كلمة المرور غير متطابقة";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 2,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
