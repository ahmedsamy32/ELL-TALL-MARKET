import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/utils/snackbar_helper.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/services/network_manager.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';
import 'package:ell_tall_market/widgets/password_strength_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:ell_tall_market/services/merchant_draft_service.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// شاشة تسجيل التاجر
///
/// التدفق (3 خطوات):
/// 1. البيانات الشخصية أولاً
/// 2. بيانات المتجر (تُحفظ مسودة تلقائياً)
/// 3. الأمان (كلمة المرور)
class RegisterMerchantScreen extends StatefulWidget {
  const RegisterMerchantScreen({super.key});

  @override
  State<RegisterMerchantScreen> createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  // Controllers - البيانات الشخصية + بيانات المتجر
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controllers - بيانات المتجر
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storeDescriptionController = TextEditingController();

  // State - الفئة المختارة
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;

  // FocusNodes للتنقل بين الحقول
  final _firstNameFocus = FocusNode();
  final _middleNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _storeNameFocus = FocusNode();
  final _storeAddressFocus = FocusNode();
  final _storeDescriptionFocus = FocusNode();

  // Form Keys
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isLoading = false;
  bool _agreeToTerms = false;
  String _currentPassword = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // Multi-step flow - 3 خطوات محسّنة
  int _currentStep =
      0; // 0: Store Info, 1: Personal Info, 2: Security (manual only)

  // Store logo
  final ImagePicker _picker = ImagePicker();
  XFile? _storeLogo;

  // Debounce validation
  // Draft save debounce
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _passwordController.addListener(() {
      // تحديث مؤشّر قوة كلمة المرور فقط بدون تشغيل التحقق مع كل ضغطة
      setState(() => _currentPassword = _passwordController.text);
    });
    // حفظ مسودة البيانات تلقائياً (بدون كلمات المرور)
    _firstNameController.addListener(_scheduleDraftSave);
    _middleNameController.addListener(_scheduleDraftSave);
    _lastNameController.addListener(_scheduleDraftSave);
    _emailController.addListener(_scheduleDraftSave);
    _phoneController.addListener(_scheduleDraftSave);
    _storeNameController.addListener(_scheduleDraftSave);
    _storeAddressController.addListener(_scheduleDraftSave);
    _storeDescriptionController.addListener(_scheduleDraftSave);
    // استرجاع المسودة إن وجدت
    _restoreDraftIfAny();
  }

  // dispose merged below with other disposals

  // Pick store logo
  Future<void> _pickStoreLogo() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null) {
        // معالجة الشعار ليكون 300x300 PNG بنسبة 1:1
        final processed = await _processAndSaveLogo(image);
        setState(() {
          _storeLogo = processed != null ? XFile(processed.path) : image;
        });
        _scheduleDraftSave();
      }
    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء اختيار الصورة');
    }
  }

  // يعالج الصورة إلى مربعة 300x300 ويحفظها كـ PNG في مجلد مؤقت
  Future<File?> _processAndSaveLogo(XFile source) async {
    try {
      final bytes = await File(source.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // قص مركزي لمربع اعتماداً على البعد الأصغر
      final minSide = math.min(decoded.width, decoded.height);
      final cropX = ((decoded.width - minSide) / 2).floor();
      final cropY = ((decoded.height - minSide) / 2).floor();
      final squared = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: minSide,
        height: minSide,
      );

      // تغيير الحجم إلى 300x300
      final resized = img.copyResize(
        squared,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.cubic,
      );

      // ترميز إلى PNG للحفاظ على الشفافية والجودة
      final pngBytes = img.encodePng(resized, level: 6);
      final tempDir = Directory.systemTemp;
      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File('${tempDir.path}/$filename');
      await outFile.writeAsBytes(pngBytes, flush: true);
      return outFile;
    } catch (_) {
      return null;
    }
  }

  // Upload store logo to Supabase Storage and return public URL
  Future<String?> _uploadStoreLogo() async {
    if (_storeLogo == null) return null;
    try {
      // نُجبر الامتداد على PNG لأننا قمنا بالمعالجة مسبقاً
      const ext = 'png';
      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'logos/$filename';

      final file = File(_storeLogo!.path);
      final url = await SupabaseConfig.uploadFile('stores', path, file);
      return url;
    } on Exception catch (e) {
      // معالجة رسائل خطأ محددة
      final errorMsg = e.toString();
      if (errorMsg.contains('صلاحية') || errorMsg.contains('policy')) {
        _showErrorMessage('خطأ في صلاحيات رفع الملفات. يرجى المحاولة لاحقاً.');
      } else if (errorMsg.contains('مصادق') ||
          errorMsg.contains('تسجيل الدخول')) {
        _showErrorMessage('يجب تسجيل الدخول أولاً لرفع الصورة');
      } else {
        _showErrorMessage('تعذر رفع صورة المتجر. يرجى المحاولة مرة أخرى.');
      }
      return null;
    } catch (e) {
      _showErrorMessage('حدث خطأ غير متوقع أثناء رفع الصورة');
      return null;
    }
  }

  // Draft persistence helpers
  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    final fullName =
        '${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final draft = MerchantDraft(
      fullName: fullName.isEmpty ? null : fullName,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      storeName: _storeNameController.text.trim(),
      storeAddress: _storeAddressController.text.trim(),
      storeDescription: _storeDescriptionController.text.trim(),
      category: _selectedCategory,
      logoPath: _storeLogo?.path,
    );
    await MerchantDraftService.save(draft);
  }

  Future<void> _restoreDraftIfAny() async {
    final draft = await MerchantDraftService.load();
    if (draft == null) return;
    // بيانات شخصية
    if (draft.fullName?.isNotEmpty == true) {
      // تقسيم الاسم الكامل إلى 3 أجزاء
      final nameParts = draft.fullName!.split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts[0];
      }
      if (nameParts.length > 1) {
        _middleNameController.text = nameParts[1];
      }
      if (nameParts.length > 2) {
        _lastNameController.text = nameParts.sublist(2).join(' ');
      }
    }
    if (draft.email?.isNotEmpty == true) {
      _emailController.text = draft.email!;
    }
    if (draft.phone?.isNotEmpty == true) {
      _phoneController.text = draft.phone!;
    }
    if (draft.storeName?.isNotEmpty == true) {
      _storeNameController.text = draft.storeName!;
    }
    if (draft.storeAddress?.isNotEmpty == true) {
      _storeAddressController.text = draft.storeAddress!;
    }
    if (draft.storeDescription?.isNotEmpty == true) {
      _storeDescriptionController.text = draft.storeDescription!;
    }
    if (draft.category != null && draft.category!.isNotEmpty) {
      setState(() => _selectedCategory = draft.category);
    }
    if (draft.logoPath != null && draft.logoPath!.isNotEmpty) {
      try {
        final file = File(draft.logoPath!);
        if (await file.exists()) {
          setState(() => _storeLogo = XFile(draft.logoPath!));
        }
      } catch (_) {}
    }
    // إعلام بسيط للمستخدم
    if (mounted) {
      SnackBarHelper.showInfo(context, 'تم استرجاع مسودة بيانات المتجر');
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      // خطوة 1: البيانات الشخصية
      if (_firstNameController.text.trim().isEmpty ||
          _middleNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        _showWarningMessage('يرجى إكمال البيانات الشخصية');
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
        if (_firstNameController.text.trim().isEmpty) {
          _firstNameFocus.requestFocus();
        } else if (_middleNameController.text.trim().isEmpty) {
          _middleNameFocus.requestFocus();
        } else if (_lastNameController.text.trim().isEmpty) {
          _lastNameFocus.requestFocus();
        } else if (_emailController.text.trim().isEmpty) {
          _emailFocus.requestFocus();
        } else {
          _phoneFocus.requestFocus();
        }
        return false;
      }
      return true;
    } else if (step == 1) {
      // خطوة 2: بيانات المتجر
      if (_storeNameController.text.trim().isEmpty ||
          _storeAddressController.text.trim().isEmpty) {
        _showWarningMessage('يرجى إكمال بيانات المتجر');
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
        if (_storeNameController.text.trim().isEmpty) {
          _storeNameFocus.requestFocus();
        } else {
          _storeAddressFocus.requestFocus();
        }
        return false;
      }
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showWarningMessage('يرجى اختيار فئة المتجر');
        return false;
      }
      if (_storeLogo == null) {
        _showWarningMessage('يرجى اختيار صورة للمتجر (إجباري)');
        return false;
      }
      return true;
    } else {
      // خطوة 3: الأمان (للتسجيل اليدوي فقط)
      if (_passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        _showWarningMessage('يرجى إدخال كلمة المرور');
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showWarningMessage('كلمتا المرور غير متطابقتين');
        return false;
      }
      if (!_agreeToTerms) {
        _showWarningMessage('يجب الموافقة على الشروط والأحكام');
        return false;
      }
      return true;
    }
  }

  Future<bool> _checkStoreNameUnique() async {
    final rawName = _storeNameController.text.trim();
    if (rawName.isEmpty) return false;
    try {
      final ok = await Validators.isStoreNameUnique(rawName);
      if (!ok) {
        _showWarningMessage('اسم المتجر مستخدم بالفعل، يرجى اختيار اسم آخر');
        _storeNameFocus.requestFocus();
        return false;
      }
      return true;
    } catch (e, st) {
      AppLogger.error('[RegisterMerchant] فشل التحقق من اسم المتجر', e, st);
      _showWarningMessage(
        'تعذر التحقق من توفر اسم المتجر حالياً، حاول مرة أخرى',
      );
      return false;
    }
  }

  /// تحميل الفئات من قاعدة البيانات
  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name, description, icon')
          .eq('is_active', true)
          .order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoadingCategories = false;
      });

      if (_categories.isEmpty) {
        AppLogger.warning(
          "[RegisterMerchant] ⚠️ لا توجد فئات نشطة في قاعدة البيانات",
        );
      } else {
        AppLogger.info(
          "[RegisterMerchant] ✅ تم تحميل ${_categories.length} فئة",
        );
      }
    } catch (e) {
      AppLogger.error("[RegisterMerchant] خطأ في تحميل الفئات", e);
      setState(() => _isLoadingCategories = false);

      // عرض رسالة للمستخدم
      if (mounted) {
        _showWarningMessage(
          "⚠️ حدث خطأ في تحميل الفئات\nيرجى المحاولة مرة أخرى",
        );
      }
    }
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
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storeDescriptionController.dispose();
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _storeNameFocus.dispose();
    _storeAddressFocus.dispose();
    _storeDescriptionFocus.dispose();
    super.dispose();
  }

  // تمت إزالة جدولة التحقق المباشر أثناء الكتابة لتحسين الأداء

  /// فحص الاتصال بالإنترنت
  Future<bool> _checkInternetAndShowDialog() async {
    final hasInternet = NetworkManager().isConnected;
    if (!hasInternet) {
      _showNoInternetDialog();
      return false;
    }
    return true;
  }

  /// عرض نافذة عدم وجود اتصال
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('لا يوجد اتصال بالإنترنت'),
          ],
        ),
        content: const Text(
          'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _registerMerchant();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  /// تحويل رسائل الخطأ لرسائل مفهومة
  String _getErrorMessage(String errorMessage) {
    if (errorMessage.contains('HandshakeException')) {
      return 'مشكلة في الاتصال بالخادم 🌐\nيرجى المحاولة مرة أخرى';
    } else if (errorMessage.contains('User already registered')) {
      return 'هذا البريد مسجل ومؤكد مسبقاً 📧';
    } else if (errorMessage.contains('over_email_send_rate_limit') ||
        errorMessage.contains('Email rate limit exceeded') ||
        errorMessage.contains('you can only request this after')) {
      final match = RegExp(r'after (\d+) seconds').firstMatch(errorMessage);
      final seconds = match != null ? match.group(1) : '60';
      return '⏰ تم إرسال عدد كبير من الطلبات\n\nيرجى الانتظار $seconds ثانية قبل المحاولة مرة أخرى';
    } else if (errorMessage.contains('Connection refused') ||
        errorMessage.contains('SocketException') ||
        errorMessage.contains('TimeoutException')) {
      return 'مشكلة في الاتصال بالخادم 🌐\nيرجى التحقق من الإنترنت';
    } else {
      return 'حدث خطأ غير متوقع ⚠️\n${errorMessage.length > 100 ? errorMessage.substring(0, 100) : errorMessage}';
    }
  }

  // Helpers: clear and show snackbars consistently
  void _clearSnackbars() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _showWarningMessage(String message) {
    if (!mounted) return;
    _clearSnackbars();
    SnackBarHelper.showWarning(context, message);
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    _clearSnackbars();
    SnackBarHelper.showError(context, message);
  }

  /// تسجيل التاجر - المرحلة 1: البيانات الشخصية فقط
  Future<void> _registerMerchant() async {
    // التحقق من صحة الخطوة الحالية
    if (!_validateStep(_currentStep) || !_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      SnackBarHelper.showWarning(context, "⚠️ يرجى إكمال جميع البيانات");
      return;
    }

    // التحقق من الموافقة على الشروط
    if (!_agreeToTerms) {
      SnackBarHelper.showWarning(
        context,
        "⚠️ يجب الموافقة على الشروط والأحكام",
      );
      return;
    }

    // التحقق من تطابق كلمة المرور
    if (_passwordController.text != _confirmPasswordController.text) {
      SnackBarHelper.showWarning(context, "⚠️ كلمتا المرور غير متطابقتين");
      return;
    }

    // 1. فحص الاتصال بالإنترنت
    if (!await _checkInternetAndShowDialog()) {
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<SupabaseProvider>();

    // تحقّق أخير من تفرّد اسم المتجر قبل الرفع/التسجيل لتجنب التضارب
    final uniqueBeforeSubmit = await _checkStoreNameUnique();
    if (!uniqueBeforeSubmit) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 2. التحقق من أن البريد غير مسجل مسبقاً
      try {
        final existingUser = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('email', email)
            .maybeSingle();

        if (existingUser != null) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          _clearSnackbars();
          SnackBarHelper.showWarning(
            context,
            "⚠️ هذا البريد مسجل مسبقاً!\nجاري التوجيه لتسجيل الدخول...",
            duration: const Duration(seconds: 2),
          );

          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.login,
                arguments: {'prefillEmail': email},
              );
            }
          });
          return;
        }
      } catch (e) {
        AppLogger.error("[RegisterMerchant] فشل التحقق من البريد", e);
        // نكمل التسجيل، وسيتم اكتشاف البريد المكرر من Auth
      }

      if (!mounted) return;

      AppLogger.info("[RegisterMerchant] 🔄 بدء عملية تسجيل التاجر: $email");

      // إظهار رسالة تحميل
      if (!mounted) return;
      _clearSnackbars();
      SnackBarHelper.showLoading(context, "⏳ جاري إنشاء حسابك...");

      // 3. تسجيل حساب التاجر في Supabase Auth مع بيانات المتجر الكاملة
      // ملاحظة: سيتم إرسال البيانات في metadata وسيقوم trigger handle_new_user بـ:
      // - إنشاء سجل في profiles
      // - إنشاء سجل في merchants مع البيانات المدخلة
      // - إنشاء سجل في stores مع البيانات المدخلة (بدون قيم افتراضية)
      final fullName =
          '${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();
      final authResponse = await authProvider.signUp(
        email: email,
        password: password,
        name: fullName,
        phone: _phoneController.text.trim(),
        userType: UserRole.merchant.value,
        storeName: _storeNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        storeDescription: _storeDescriptionController.text.trim().isEmpty
            ? null
            : _storeDescriptionController.text.trim(),
        category: _selectedCategory, // إرسال الفئة المختارة
        storeLogoUrl: null, // سنرفع الصورة بعد نجاح التسجيل
      );

      if (authResponse?.user == null) {
        final errorMsg =
            authProvider.errorMessage ?? 'فشل التسجيل - لم يتم إنشاء المستخدم';
        AppLogger.error("[RegisterMerchant] فشل التسجيل: $errorMsg");
        throw Exception(errorMsg);
      }

      AppLogger.info(
        "[RegisterMerchant] ✅ تم إنشاء حساب التاجر: ${authResponse!.user!.id}",
      );

      // 4. رفع صورة المتجر بعد نجاح التسجيل (المستخدم الآن مصادق)
      String? logoUrl;
      if (_storeLogo != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        SnackBarHelper.showLoading(context, "⏳ جاري رفع صورة المتجر...");

        logoUrl = await _uploadStoreLogo();

        // إذا فشل رفع الصورة، نكمل التسجيل بدونها
        if (logoUrl != null) {
          // تحديث رابط الصورة في قاعدة البيانات
          try {
            await Supabase.instance.client
                .from('stores')
                .update({'logo_url': logoUrl})
                .eq('id', authResponse.user!.id);
            AppLogger.info("[RegisterMerchant] ✅ تم تحديث صورة المتجر");
          } catch (e) {
            AppLogger.error("[RegisterMerchant] فشل تحديث صورة المتجر", e);
            // نكمل التسجيل حتى لو فشل التحديث
          }
        }
      }

      // ملاحظة مهمة: سيتم إنشاء السجلات التالية تلقائياً عبر trigger:
      // ✅ Profile: في جدول profiles (id, full_name, email, phone, role)
      // ✅ Merchant: في جدول merchants (id, store_name, store_description, address)
      // ✅ Store: في جدول stores (مع البيانات المدخلة فقط، بدون قيم افتراضية)
      // 📝 ملاحظة: يجب على التاجر إكمال بيانات المتجر (الفئة، ساعات العمل، رسوم التوصيل...) لاحقاً
      // كل هذا يحدث في transaction واحدة آمنة عبر SECURITY DEFINER trigger

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 5. عرض رسالة النجاح والتوجيه لصفحة تأكيد البريد
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      SnackBarHelper.showSuccess(
        context,
        "✅ تم إنشاء حسابك ومتجرك بنجاح!\nيرجى تأكيد بريدك الإلكتروني للمتابعة...",
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 1500));

      // مسح المسودة بعد نجاح إنشاء الحساب
      await MerchantDraftService.clear();

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.emailConfirmation,
        arguments: {
          'email': email,
          'password': password,
          'userType': 'merchant', // 🔥 مهم: لمعرفة أنه تاجر
        },
      );
    } on AuthException catch (e) {
      AppLogger.error("[RegisterMerchant] Auth Error", e);
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).clearSnackBars();

      // معالجة خاصة لحالة البريد المسجل مسبقاً
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('already') ||
          errorMsg.contains('exist') ||
          errorMsg.contains('registered') ||
          errorMsg.contains('duplicate') ||
          e.statusCode == '409') {
        SnackBarHelper.showWarning(
          context,
          "⚠️ هذا البريد مسجل مسبقاً!\nجاري التوجيه لتسجيل الدخول...",
          duration: const Duration(seconds: 2),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.login,
              arguments: {'prefillEmail': _emailController.text.trim()},
            );
          }
        });
        return;
      }

      if (!mounted) return;
      String message = _getErrorMessage(e.message);
      _showErrorMessage(message);
    } catch (e, st) {
      AppLogger.error("[RegisterMerchant] خطأ غير متوقع", e, st);
      if (!mounted) return;

      setState(() => _isLoading = false);

      String errorText;
      if (e is Exception) {
        errorText = e.toString().replaceAll('Exception: ', '');
      } else {
        errorText = e.toString();
      }

      String message = _getErrorMessage(errorText);
      _showErrorMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme),

            // Content with multi-step flow
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress indicator
                      _buildProgress(),
                      const SizedBox(height: 16),

                      // ═══════════════════════════════════════════
                      // خطوة 1: البيانات الشخصية أولاً
                      // ═══════════════════════════════════════════
                      if (_currentStep == 0) ...[
                        _buildSectionHeader(
                          theme,
                          Icons.person_outline_rounded,
                          'البيانات الشخصية',
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'أدخل بياناتك الشخصية أولاً',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // الاسم الأول والأوسط في صف واحد
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _firstNameController,
                                label: 'الاسم الأول',
                                hintText: 'مثال: أحمد',
                                prefixIcon: const Icon(Icons.person_outline),
                                focusNode: _firstNameFocus,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _middleNameFocus.requestFocus(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'مطلوب';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _middleNameController,
                                label: 'الاسم الأوسط',
                                hintText: 'مثال: سامي',
                                prefixIcon: const Icon(Icons.person_outline),
                                focusNode: _middleNameFocus,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _lastNameFocus.requestFocus(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'مطلوب';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _lastNameController,
                          label: 'اسم العائلة',
                          hintText: 'مثال: عبد الهادي',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          focusNode: _lastNameFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'اسم العائلة مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          hintText: 'example@gmail.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          hintText: '*********01',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: '+20 ',
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          focusNode: _phoneFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (_validateStep(0)) {
                              setState(() => _currentStep = 1);
                            }
                          },
                          validator: Validators.validatePhone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],

                      // ═══════════════════════════════════════════
                      // خطوة 2: بيانات المتجر
                      // ═══════════════════════════════════════════
                      if (_currentStep == 1) ...[
                        _buildSectionHeader(
                          theme,
                          Icons.store_outlined,
                          'بيانات المتجر',
                          Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'أخبرنا عن متجرك',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _storeNameController,
                          label: 'اسم المتجر',
                          hintText: 'أدخل اسم متجرك',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          focusNode: _storeNameFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _storeAddressFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'اسم المتجر مطلوب';
                            }
                            if (value.trim().length < 3) {
                              return 'اسم المتجر يجب أن يكون 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _storeAddressController,
                          label: 'عنوان المتجر',
                          hintText: 'أدخل عنوان متجرك',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          focusNode: _storeAddressFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _storeDescriptionFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'عنوان المتجر مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _storeDescriptionController,
                          label: 'وصف المتجر (اختياري)',
                          hintText: 'اكتب نبذة مختصرة عن متجرك',
                          prefixIcon: const Icon(Icons.description_outlined),
                          focusNode: _storeDescriptionFocus,
                          textInputAction: TextInputAction.done,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                        ),

                        const SizedBox(height: 16),

                        // Store logo (mandatory)
                        _buildStoreLogoPicker(theme),

                        const SizedBox(height: 16),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'فئة المتجر',
                            hintText: _isLoadingCategories
                                ? 'جاري التحميل...'
                                : _categories.isEmpty
                                ? 'لا توجد فئات متاحة'
                                : 'اختر فئة المتجر',
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          menuMaxHeight: 300,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'اختر فئة المتجر',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            ..._categories.map((category) {
                              final iconName = category['icon']?.toString();
                              IconData iconData = Icons.store;

                              if (iconName != null) {
                                switch (iconName) {
                                  case 'restaurant':
                                    iconData = Icons.restaurant;
                                    break;
                                  case 'local_grocery_store':
                                    iconData = Icons.local_grocery_store;
                                    break;
                                  case 'devices':
                                    iconData = Icons.devices;
                                    break;
                                  case 'checkroom':
                                    iconData = Icons.checkroom;
                                    break;
                                  case 'spa':
                                    iconData = Icons.spa;
                                    break;
                                  case 'home':
                                    iconData = Icons.home;
                                    break;
                                  case 'sports':
                                    iconData = Icons.sports;
                                    break;
                                  case 'menu_book':
                                    iconData = Icons.menu_book;
                                    break;
                                  case 'toys':
                                    iconData = Icons.toys;
                                    break;
                                  case 'pets':
                                    iconData = Icons.pets;
                                    break;
                                  case 'room_service':
                                    iconData = Icons.room_service;
                                    break;
                                  default:
                                    iconData = Icons.store;
                                }
                              }

                              return DropdownMenuItem<String>(
                                value: category['id']?.toString() ?? '',
                                child: Row(
                                  children: [
                                    Icon(
                                      iconData,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      category['name']?.toString() ??
                                          'غير محدد',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: _isLoadingCategories
                              ? null
                              : (value) {
                                  setState(() => _selectedCategory = value);
                                  _scheduleDraftSave();
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى اختيار فئة المتجر';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),
                      ],

                      // تمت إزالة بطاقة معلومات OAuth لعدم استخدامها للتجار

                      // ═══════════════════════════════════════════
                      // خطوة 3: الأمان والشروط (للتسجيل اليدوي فقط)
                      // ═══════════════════════════════════════════
                      if (_currentStep == 2) ...[
                        _buildSectionHeader(
                          theme,
                          Icons.lock_outline_rounded,
                          'تأمين الحساب',
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اختر كلمة مرور قوية لحماية حسابك',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          hintText: 'أدخل كلمة مرور قوية',
                          prefixIcon: const Icon(Icons.lock_outline),
                          isPasswordField: true,
                          focusNode: _passwordFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _confirmPasswordFocus.requestFocus(),
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: 12),
                        PasswordStrengthIndicator(password: _currentPassword),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: 'تأكيد كلمة المرور',
                          hintText: 'أعد إدخال كلمة المرور',
                          prefixIcon: const Icon(Icons.lock),
                          isPasswordField: true,
                          focusNode: _confirmPasswordFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _registerMerchant(),
                          validator: (v) => Validators.validateConfirmPassword(
                            v,
                            _passwordController.text,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.green.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'سيتم إنشاء حسابك وبيانات متجرك مباشرة بعد تأكيد بريدك الإلكتروني',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Terms & Conditions
                        _buildTermsCheckbox(theme),

                        const SizedBox(height: 24),
                      ],

                      // ═══════════════════════════════════════════
                      // أزرار التحكم بالخطوات
                      // ═══════════════════════════════════════════
                      _buildStepControls(theme),

                      const SizedBox(height: 16),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'لديك حساب بالفعل؟',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              );
                            },
                            child: const Text('تسجيل الدخول'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _buildStepCircle(0, '1', 'البيانات'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1 ? cs.primary : cs.surfaceContainerHighest,
          ),
        ),
        _buildStepCircle(1, '2', 'المتجر'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 2 ? cs.primary : cs.surfaceContainerHighest,
          ),
        ),
        _buildStepCircle(2, '3', 'الأمان'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, String title) {
    final cs = Theme.of(context).colorScheme;
    final active = _currentStep == step;
    final done = _currentStep > step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: done || active ? cs.primary : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: done || active ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildStoreLogoPicker(ThemeData theme) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'صورة المتجر (إجباري)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _SpecChip(label: 'PNG'),
            const SizedBox(width: 8),
            _SpecChip(label: '300×300'),
            const SizedBox(width: 8),
            _SpecChip(label: 'نسبة 1:1'),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickStoreLogo,
          borderRadius: BorderRadius.circular(12),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 220,
              ), // تصغير المعاينة
              child: AspectRatio(
                aspectRatio: 1, // مربع تماماً
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _storeLogo == null ? cs.outline : cs.primary,
                      width: 1.5,
                    ),
                  ),
                  child: _storeLogo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط لاختيار صورة شعار المتجر',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox.expand(
                            child: Image.file(
                              File(_storeLogo!.path),
                              fit: BoxFit
                                  .contain, // احتواء الصورة بالكامل بدون قص
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'يفضّل خلفية شفافة أو بيضاء للحفاظ على وضوح الشعار',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // (سيتم نقل _SpecChip إلى أعلى مستوى بعد نهاية الكلاس)

  Widget _buildStepControls(ThemeData theme) {
    final isLast = _currentStep == 2; // الخطوة الأخيرة هي رقم 2
    return Row(
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _currentStep -= 1);
                  },
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('السابق'),
          ),
        if (_currentStep > 0) const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    if (!isLast) {
                      if (_validateStep(_currentStep)) {
                        // في خطوة بيانات المتجر، تحقّق من تفرّد الاسم قبل المتابعة
                        if (_currentStep == 1) {
                          final ok = await _checkStoreNameUnique();
                          if (!ok) return; // لا تنتقل للخطوة التالية
                        }
                        setState(() => _currentStep += 1);
                      }
                    } else {
                      await _registerMerchant();
                    }
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isLast
                        ? Icons.how_to_reg_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              _isLoading
                  ? 'جاري المعالجة...'
                  : isLast
                  ? 'إنشاء حساب التاجر'
                  : 'التالي',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.store_mall_directory_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل تاجر جديد',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentStep == 0
                      ? 'الخطوة 1 من 3: البيانات الشخصية'
                      : _currentStep == 1
                      ? 'الخطوة 2 من 3: بيانات المتجر'
                      : 'الخطوة 3 من 3: الأمان والشروط',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() => _agreeToTerms = value ?? false);
            },
            activeColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              children: [
                const Text('أوافق على '),
                GestureDetector(
                  onTap: () {
                    // Note: Navigate to terms page
                  },
                  child: Text(
                    'الشروط والأحكام',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(' و'),
                GestureDetector(
                  onTap: () {
                    // Note: Navigate to privacy policy page
                  },
                  child: Text(
                    'سياسة الخصوصية',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ويدجت بسيطة لعرض مواصفات الشعار (Top-level)
class _SpecChip extends StatelessWidget {
  final String label;
  const _SpecChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    );
  }
}
