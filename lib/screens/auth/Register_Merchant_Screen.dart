import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';
import 'package:ell_tall_market/widgets/password_strength_indicator.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// شاشة تسجيل التاجر الجديد
/// تم تحديثها لاستخدام Supabase Auth حسب الوثائق الرسمية
/// https://supabase.com/docs/reference/dart/installing
/// https://supabase.com/docs/reference/dart/auth-signup
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
  String _currentPassword = '';
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  // Category dropdown state
  final List<String> _categories = [
    'صيدلية',
    'سوبر ماركت',
    'مكتبة',
    'ملابس',
    'أخرى',
  ];
  String? _selectedCategory;

  final GlobalKey<FormState> _step1FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step2FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step3FormKey = GlobalKey<FormState>();
  late final List<GlobalKey<FormState>> _formKeys = [
    _step1FormKey,
    _step2FormKey,
    _step3FormKey,
  ];

  @override
  void initState() {
    super.initState();
    // إضافة مستمع لتحديث مؤشر قوة كلمة المرور
    _passwordController.addListener(() {
      setState(() {
        _currentPassword = _passwordController.text;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // تسجيل التاجر باستخدام الوثائق الرسمية لـ Supabase
  Future<void> _registerMerchant(SupabaseProvider authProvider) async {
    if (!_validateAllSteps()) {
      SnackBarHelper.showWarning(
        context,
        "⚠️ يرجى تعبئة جميع البيانات بشكل صحيح",
      );
      return;
    }

    setState(() => _isLoading = true);

    // عرض رسالة تحميل
    SnackBarHelper.showLoading(context, '🔄 جاري إنشاء حساب التاجر...');

    try {
      AppLogger.debug(
        "[RegisterMerchant] بدء تسجيل التاجر باستخدام Supabase Auth",
      );

      // استخدام registerWithEmailVerification مباشرة حسب الوثائق الرسمية
      final response = await authProvider.registerWithEmailVerification(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        userType: UserRole.merchant.value,
      );

      AppLogger.debug("[RegisterMerchant] نتيجة التسجيل: $response");

      if (!mounted) return;

      // معالجة نتائج التسجيل حسب الوثائق الرسمية
      switch (response) {
        case 'success':
          // تم التسجيل والتأكيد بنجاح
          AppLogger.info("[RegisterMerchant] تم التسجيل والتأكيد بنجاح");
          SnackBarHelper.showSuccess(
            context,
            "✅ تم إنشاء حساب التاجر وتأكيده بنجاح! مرحباً بك في متجرك",
          );
          Navigator.pushReplacementNamed(context, AppRoutes.merchantDashboard);
          break;

        case 'successPendingVerification':
          // تم التسجيل ولكن يحتاج تأكيد البريد الإلكتروني
          AppLogger.info("[RegisterMerchant] تم التسجيل - ينتظر تأكيد البريد");
          SnackBarHelper.showSuccess(
            context,
            "📧 تم إنشاء حساب التاجر! يرجى تأكيد بريدك الإلكتروني",
          );
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.emailConfirmation,
            arguments: {
              'email': _emailController.text.trim(),
              'userRole': 'merchant',
            },
          );
          break;

        case 'emailAlreadyExists':
          // البريد مستخدم مسبقاً
          AppLogger.warning(
            "[RegisterMerchant] البريد الإلكتروني مستخدم مسبقاً",
          );
          SnackBarHelper.showWarning(
            context,
            "📧 هذا البريد الإلكتروني مسجل مسبقاً. يرجى تسجيل الدخول أو استخدام بريد آخر",
          );
          break;

        case 'emailAlreadyVerified':
          // البريد مؤكد مسبقاً
          AppLogger.info("[RegisterMerchant] البريد الإلكتروني مؤكد مسبقاً");
          SnackBarHelper.showInfo(
            context,
            "✅ هذا البريد الإلكتروني مسجل ومؤكد مسبقاً. يمكنك تسجيل الدخول",
          );
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          break;

        case 'weakPassword':
          SnackBarHelper.showError(
            context,
            "🔐 كلمة المرور ضعيفة. يجب أن تكون 6 أحرف على الأقل",
          );
          break;

        case 'invalidEmail':
          SnackBarHelper.showError(
            context,
            "📧 البريد الإلكتروني غير صالح. تحقق من صيغة البريد",
          );
          break;

        case 'networkError':
          SnackBarHelper.showError(
            context,
            "🌐 لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى",
          );
          break;

        default:
          // خطأ غير متوقع
          AppLogger.error("[RegisterMerchant] خطأ غير متوقع: $response");
          SnackBarHelper.showError(
            context,
            response.isNotEmpty
                ? response
                : "❌ حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى",
          );
          break;
      }
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error("[RegisterMerchant] خطأ في التسجيل: $e", e, st);

      // استخراج الرسالة من Exception إذا كانت موجودة
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // إزالة "Exception: "
      }

      // عرض الرسالة المفصلة
      SnackBarHelper.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
        SnackBarHelper.showSuccess(context, '📸 تم اختيار صورة المتجر بنجاح!');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, '❌ تعذر اختيار الصورة: $e');
    }
  }

  // التحقق من صحة جميع الخطوات
  // إضافة تحقق من اختيار الفئة
  String? _validateCategory(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى اختيار فئة المتجر';
    }
    return null;
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      items: _categories
          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedCategory = val;
        });
      },
      decoration: InputDecoration(
        labelText: 'فئة المتجر',
        hintText: 'اختر نوع النشاط التجاري',
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: _validateCategory,
    );
  }

  bool _validateAllSteps() {
    // التحقق من الخطوة الأولى
    if (_step1FormKey.currentState?.validate() != true) {
      setState(() => _currentStep = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      SnackBarHelper.showWarning(
        context,
        "⚠️ يرجى إكمال البيانات الشخصية أولاً",
      );
      return false;
    }

    // التحقق من الخطوة الثانية
    if (_step2FormKey.currentState?.validate() != true) {
      setState(() => _currentStep = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      SnackBarHelper.showWarning(context, "⚠️ يرجى إكمال بيانات المتجر");
      return false;
    }

    // التحقق من الخطوة الثالثة
    if (_step3FormKey.currentState?.validate() != true) {
      setState(() => _currentStep = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      SnackBarHelper.showWarning(context, "⚠️ يرجى إكمال بيانات كلمة المرور");
      return false;
    }

    return true;
  }

  Widget _personalInfoPage() {
    return SingleChildScrollView(
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👤 البيانات الشخصية',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _nameController,
              label: 'الاسم الكامل',
              hintText: 'أدخل اسمك الكامل',
              prefixIcon: const Icon(Icons.person_outline),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController,
              label: 'البريد الإلكتروني',
              hintText: 'example@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            // رقم الهاتف
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم الهاتف',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: Validators.validatePhone,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف',
                              hintText: '*********01',
                              prefixText: '+20 ', // Add Egypt country code
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 22,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
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
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _storeInfoPage() {
    return SingleChildScrollView(
      child: Form(
        key: _step2FormKey,
        child: Column(
          children: [
            Text(
              '🏪 بيانات المتجر',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A5AE0), Color(0xFF8F7BFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6A5AE0,
                            ).withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 4),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 45,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedImage == null
                          ? '📸 اختر صورة المتجر'
                          : '🔄 تغيير الصورة',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر من المعرض أو التقط صورة جديدة',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _storeNameController,
              label: 'اسم المتجر',
              hintText: 'أدخل اسم متجرك التجاري',
              prefixIcon: const Icon(Icons.storefront_outlined),
              validator: (v) => Validators.validateRequired(v, 'اسم المتجر'),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _addressController,
              label: 'عنوان المتجر',
              hintText: 'المدينة، الحي، الشارع',
              prefixIcon: const Icon(Icons.location_on_outlined),
              validator: Validators.validateAddress,
            ),
            const SizedBox(height: 16),
            // Dropdown for category
            _buildCategoryDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _passwordPage() {
    return SingleChildScrollView(
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔒 بيانات تسجيل الدخول',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _passwordController,
              label: 'كلمة المرور',
              hintText: 'أدخل كلمة مرور قوية (8 أحرف على الأقل)',
              prefixIcon: const Icon(Icons.lock_outline),
              isPasswordField: true,
              validator: Validators.validatePassword,
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

            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'تأكيد كلمة المرور',
              hintText: 'أعد إدخال كلمة المرور',
              prefixIcon: const Icon(Icons.lock),
              isPasswordField: true,
              validator: (v) => Validators.validateConfirmPassword(
                v,
                _passwordController.text,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _next(SupabaseProvider authProvider) {
    final currentKey = _formKeys[_currentStep];
    final valid = currentKey.currentState?.validate() == true;

    if (!valid) {
      // عرض رسالة توضيحية حسب الخطوة الحالية
      switch (_currentStep) {
        case 0:
          {
            SnackBarHelper.showWarning(
              context,
              "⚠️ يرجى إكمال البيانات الشخصية بشكل صحيح",
            );
            break;
          }
        case 1:
          {
            SnackBarHelper.showWarning(
              context,
              "⚠️ يرجى إكمال بيانات المتجر بشكل صحيح",
            );
            break;
          }
        case 2:
          {
            SnackBarHelper.showWarning(
              context,
              "⚠️ يرجى إكمال بيانات كلمة المرور بشكل صحيح",
            );
            break;
          }
      }
      return;
    }

    if (_currentStep < _formKeys.length - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      // عرض رسالة تشجيعية
      switch (_currentStep) {
        case 1:
          {
            SnackBarHelper.showInfo(
              context,
              "✅ تم حفظ البيانات الشخصية بنجاح!",
            );
            break;
          }
        case 2:
          {
            SnackBarHelper.showInfo(context, "✅ تم حفظ بيانات المتجر بنجاح!");
            break;
          }
      }
    } else {
      _registerMerchant(authProvider);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<SupabaseProvider>(context);

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
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFC), Color(0xFFEDF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 24),
                      _buildProgressBar(),
                      const SizedBox(height: 20),
                      _buildStepIndicators(),
                      const SizedBox(height: 28),
                      _buildPages(theme, authProvider),
                      const SizedBox(height: 32),
                      _buildBottomButtons(authProvider),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'جاري إنشاء حساب التاجر...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6A5AE0), Color(0xFF8F7BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A5AE0).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.store_mall_directory,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل تاجر جديد 🛒',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أنشئ حساب متجرك وابدأ البيع الآن',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final stepsCount = 3;
    final progress = (_currentStep + 1) / stepsCount;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 12,
            child: Stack(
              children: [
                Container(color: Colors.grey.shade300.withValues(alpha: 0.4)),
                LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: constraints.maxWidth * progress,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A5AE0), Color(0xFFFF9E80)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'الخطوة ${_currentStep + 1} من $stepsCount',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6A5AE0),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicators() {
    final labels = ['البيانات الشخصية', 'بيانات المتجر', 'كلمة المرور'];
    final icons = [
      Icons.person_outline,
      Icons.storefront_outlined,
      Icons.lock_outline,
    ];

    return Row(
      children:
          List.generate(labels.length, (i) {
            final active = i == _currentStep;
            final completed = i < _currentStep;

            return Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active || completed
                          ? const LinearGradient(
                              colors: [Color(0xFF6A5AE0), Color(0xFFFF9E80)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: active || completed ? null : Colors.white,
                      boxShadow: [
                        if (active || completed)
                          BoxShadow(
                            color: const Color(
                              0xFF6A5AE0,
                            ).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                      ],
                      border: !active && !completed
                          ? Border.all(color: Colors.grey.shade300)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          completed ? Icons.check_circle : icons[i],
                          color: active || completed
                              ? Colors.white
                              : Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: active || completed
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).expand((w) sync* {
            yield w;
            if (labels.indexOf(labels.last) != labels.length - 1) {
              yield const SizedBox(width: 8);
            }
          }).toList(),
    );
  }

  Widget _buildPages(ThemeData theme, SupabaseProvider authProvider) {
    return Container(
      height: 650, // ارتفاع ثابت أكبر لاستيعاب المحتوى الإضافي
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _pageWrapper(_personalInfoPage()),
          _pageWrapper(_storeInfoPage()),
          _pageWrapper(_passwordPage()),
        ],
      ),
    );
  }

  Widget _pageWrapper(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }

  Widget _buildBottomButtons(SupabaseProvider authProvider) {
    final isLast = _currentStep == _formKeys.length - 1;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _back,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back_ios, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'رجوع',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _next(authProvider),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              backgroundColor: const Color(0xFF6A5AE0),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? '✅ تسجيل التاجر' : 'التالي',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLast ? Icons.check : Icons.arrow_forward_ios,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
