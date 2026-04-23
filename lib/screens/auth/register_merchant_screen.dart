import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/services/merchant_draft_service.dart';
import 'package:ell_tall_market/widgets/address/address_form_section.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';

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

  // Controllers - عنوان المتجر (structured)
  final _storeGovernorateController = TextEditingController();
  final _storeCityController = TextEditingController();
  final _storeAreaController = TextEditingController();
  final _storeStreetController = TextEditingController();
  final _storeLandmarkController = TextEditingController();

  // Location (lat/lng)
  LatLng? _storePosition;

  // Summary preview under the address section
  String? _storeSummaryCity;
  String? _storeSummaryGovernorate;
  List<DeliveryZonePricingModel> _ownerZones = <DeliveryZonePricingModel>[];

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
  final _storeDescriptionFocus = FocusNode();

  // FocusNodes - عنوان المتجر
  final _storeGovernorateFocus = FocusNode();
  final _storeCityFocus = FocusNode();
  final _storeStreetFocus = FocusNode();

  // Form Keys
  final _formKey = GlobalKey<FormState>();
  final _storeAddressSectionFormKey = GlobalKey<FormState>();

  // Scroll targets for required sections/inputs
  final _firstNameFieldKey = GlobalKey();
  final _middleNameFieldKey = GlobalKey();
  final _lastNameFieldKey = GlobalKey();
  final _emailFieldKey = GlobalKey();
  final _phoneFieldKey = GlobalKey();

  final _storeNameFieldKey = GlobalKey();
  final _storeMapSectionKey = GlobalKey();
  final _storeCategorySectionKey = GlobalKey();

  final _passwordFieldKey = GlobalKey();
  final _confirmPasswordFieldKey = GlobalKey();
  final _termsSectionKey = GlobalKey();

  // State
  bool _isLoading = false;
  bool _agreeToTerms = false;
  String _currentPassword = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // Multi-step flow - 3 خطوات محسّنة
  int _currentStep =
      0; // 0: Store Info, 1: Personal Info, 2: Security (manual only)

  // Debounce validation
  // Draft save debounce
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadOwnerZones();
    _passwordController.addListener(() {
      // Update password strength indicator without triggering validation on every keystroke
      if (mounted) setState(() => _currentPassword = _passwordController.text);
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

    // Store structured address listeners
    _storeGovernorateController.addListener(_scheduleDraftSave);
    _storeCityController.addListener(_scheduleDraftSave);
    _storeAreaController.addListener(_scheduleDraftSave);
    _storeStreetController.addListener(_scheduleDraftSave);
    _storeLandmarkController.addListener(_scheduleDraftSave);

    _storeGovernorateController.addListener(_syncStoreAddressController);
    _storeCityController.addListener(_syncStoreAddressController);
    _storeAreaController.addListener(_syncStoreAddressController);
    _storeStreetController.addListener(_syncStoreAddressController);
    _storeLandmarkController.addListener(_syncStoreAddressController);
    // استرجاع المسودة إن وجدت
    _restoreDraftIfAny();
  }

  Future<void> _loadOwnerZones() async {
    final zones = await DeliveryZonePricingService.getActiveZones();
    if (!mounted) return;
    setState(() {
      _ownerZones = zones;
    });
  }

  List<String> get _governorateOptions {
    final values = _ownerZones
        .map((z) => z.governorate.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _cityOptions {
    final gov = _storeGovernorateController.text.trim();
    if (gov.isEmpty) return const <String>[];

    final values = _ownerZones
        .where((z) => z.governorate.trim() == gov)
        .map((z) => (z.city ?? '').trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _areaOptions {
    final gov = _storeGovernorateController.text.trim();
    final city = _storeCityController.text.trim();
    if (gov.isEmpty) return const <String>[];

    final values = _ownerZones
        .where((z) {
          if (z.governorate.trim() != gov) return false;
          final zoneCity = (z.city ?? '').trim();
          if (city.isEmpty) return zoneCity.isEmpty;
          return zoneCity == city;
        })
        .map((z) => (z.area ?? '').trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  bool get _hasOwnerZoneOptions => _ownerZones.isNotEmpty;

  void _handleStoreGovernorateSelection(String governorate) {
    setState(() {
      final selected = governorate.trim();
      _storeGovernorateController.text = selected;
      _storeSummaryGovernorate = selected.isEmpty ? null : selected;

      final validCities = _ownerZones
          .where((z) => z.governorate.trim() == selected)
          .map((z) => (z.city ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_storeCityController.text.trim().isNotEmpty &&
          !validCities.contains(_storeCityController.text.trim())) {
        _storeCityController.clear();
        _storeSummaryCity = null;
      }

      _storeAreaController.clear();
    });
  }

  void _handleStoreCitySelection(String city) {
    setState(() {
      final selected = city.trim();
      _storeCityController.text = selected;
      _storeSummaryCity = selected.isEmpty ? null : selected;

      final validAreas = _ownerZones
          .where(
            (z) =>
                z.governorate.trim() ==
                    _storeGovernorateController.text.trim() &&
                (z.city ?? '').trim() == selected,
          )
          .map((z) => (z.area ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_storeAreaController.text.trim().isNotEmpty &&
          !validAreas.contains(_storeAreaController.text.trim())) {
        _storeAreaController.clear();
      }
    });
  }

  String _composeStoreAddress() {
    final parts = <String>[
      _storeGovernorateController.text.trim(),
      _storeCityController.text.trim(),
      _storeAreaController.text.trim(),
      _storeStreetController.text.trim(),
      _storeLandmarkController.text.trim(),
    ].where((e) => e.isNotEmpty).toList();

    return parts.join('، ');
  }

  void _syncStoreAddressController() {
    final composed = _composeStoreAddress();
    if (_storeAddressController.text.trim() == composed.trim()) return;

    // Keep cursor stable when we update programmatically
    _storeAddressController.value = TextEditingValue(
      text: composed,
      selection: TextSelection.collapsed(offset: composed.length),
    );
  }

  // dispose merged below with other disposals

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
      storeGovernorate: _storeGovernorateController.text.trim(),
      storeCity: _storeCityController.text.trim(),
      storeArea: _storeAreaController.text.trim(),
      storeStreet: _storeStreetController.text.trim(),
      storeLandmark: _storeLandmarkController.text.trim(),
      storeLatitude: _storePosition?.latitude,
      storeLongitude: _storePosition?.longitude,
      storeDescription: _storeDescriptionController.text.trim(),
      category: _selectedCategory,
    );
    await MerchantDraftService.save(draft);
    // No setState needed here - just persisting data
  }

  Future<void> _restoreDraftIfAny() async {
    final draft = await MerchantDraftService.load();
    if (!mounted || draft == null) return;
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
    if (draft.storeGovernorate?.isNotEmpty == true) {
      _storeGovernorateController.text = draft.storeGovernorate!;
      _storeSummaryGovernorate = draft.storeGovernorate;
    }
    if (draft.storeCity?.isNotEmpty == true) {
      _storeCityController.text = draft.storeCity!;
      _storeSummaryCity = draft.storeCity;
    }
    if (draft.storeArea?.isNotEmpty == true) {
      _storeAreaController.text = draft.storeArea!;
    }
    if (draft.storeStreet?.isNotEmpty == true) {
      _storeStreetController.text = draft.storeStreet!;
    } else if (draft.storeAddress?.isNotEmpty == true) {
      // Backward-compat: old drafts only had a single address string.
      // Put it into street field as a best-effort fallback.
      _storeStreetController.text = draft.storeAddress!;
    }
    if (draft.storeLandmark?.isNotEmpty == true) {
      _storeLandmarkController.text = draft.storeLandmark!;
    }
    if (draft.storeLatitude != null && draft.storeLongitude != null) {
      _storePosition = LatLng(draft.storeLatitude!, draft.storeLongitude!);
    }

    // Keep legacy string controller in sync for payload/draft compatibility.
    _syncStoreAddressController();
    if (draft.storeDescription?.isNotEmpty == true) {
      _storeDescriptionController.text = draft.storeDescription!;
    }
    if (draft.category != null && draft.category!.isNotEmpty) {
      setState(() => _selectedCategory = draft.category);
    }
    // إعلام بسيط للمستخدم
    if (mounted) {
      SnackBarHelper.showInfo(context, 'تم استرجاع مسودة بيانات المتجر');
    }
  }

  bool _validateStep(int step) {
    void scrollToKey(GlobalKey key) {
      final targetContext = key.currentContext;
      if (targetContext == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = key.currentContext;
        if (c == null) return;
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      });
    }

    void enableAutovalidate() {
      if (!mounted) return;
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }

    void focusFirstInvalidField() {
      if (!mounted) return;

      if (step == 0) {
        if (_firstNameController.text.trim().isEmpty) {
          scrollToKey(_firstNameFieldKey);
          _firstNameFocus.requestFocus();
        } else if (_middleNameController.text.trim().isEmpty) {
          scrollToKey(_middleNameFieldKey);
          _middleNameFocus.requestFocus();
        } else if (_lastNameController.text.trim().isEmpty) {
          scrollToKey(_lastNameFieldKey);
          _lastNameFocus.requestFocus();
        } else if (_emailController.text.trim().isEmpty) {
          scrollToKey(_emailFieldKey);
          _emailFocus.requestFocus();
        } else {
          scrollToKey(_phoneFieldKey);
          _phoneFocus.requestFocus();
        }
        return;
      }

      if (step == 1) {
        if (_storeNameController.text.trim().isEmpty) {
          scrollToKey(_storeNameFieldKey);
          _storeNameFocus.requestFocus();
        } else if (_storeGovernorateController.text.trim().isEmpty) {
          scrollToKey(_storeMapSectionKey);
          _storeGovernorateFocus.requestFocus();
        } else if (_storeCityController.text.trim().isEmpty) {
          scrollToKey(_storeMapSectionKey);
          _storeCityFocus.requestFocus();
        } else if (_storeStreetController.text.trim().isEmpty) {
          scrollToKey(_storeMapSectionKey);
          _storeStreetFocus.requestFocus();
        }
        return;
      }

      // step == 2
      if (_passwordController.text.isEmpty) {
        scrollToKey(_passwordFieldKey);
        _passwordFocus.requestFocus();
      } else {
        scrollToKey(_confirmPasswordFieldKey);
        _confirmPasswordFocus.requestFocus();
      }
    }

    if (step == 0) {
      // خطوة 1: البيانات الشخصية
      if (_firstNameController.text.trim().isEmpty ||
          _middleNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        _showWarningMessage('يرجى إكمال البيانات الشخصية');
        enableAutovalidate();
        _formKey.currentState?.validate();
        focusFirstInvalidField();
        return false;
      }
      return true;
    } else if (step == 1) {
      // خطوة 2: بيانات المتجر
      if (_storeNameController.text.trim().isEmpty ||
          _storeGovernorateController.text.trim().isEmpty ||
          _storeCityController.text.trim().isEmpty ||
          _storeStreetController.text.trim().isEmpty) {
        _showWarningMessage('يرجى إكمال بيانات المتجر');
        enableAutovalidate();
        _formKey.currentState?.validate();
        focusFirstInvalidField();
        return false;
      }

      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showWarningMessage('يرجى اختيار فئة المتجر');
        enableAutovalidate();
        scrollToKey(_storeCategorySectionKey);
        return false;
      }
      return true;
    } else {
      // خطوة 3: الأمان (للتسجيل اليدوي فقط)
      if (_passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        _showWarningMessage('يرجى إدخال كلمة المرور');
        enableAutovalidate();
        _formKey.currentState?.validate();
        focusFirstInvalidField();
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showWarningMessage('كلمتا المرور غير متطابقتين');
        enableAutovalidate();
        _formKey.currentState?.validate();
        _confirmPasswordFocus.requestFocus();
        return false;
      }
      if (!_agreeToTerms) {
        _showWarningMessage('يجب الموافقة على الشروط والأحكام');
        enableAutovalidate();
        scrollToKey(_termsSectionKey);
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
    _storeGovernorateController.dispose();
    _storeCityController.dispose();
    _storeAreaController.dispose();
    _storeStreetController.dispose();
    _storeLandmarkController.dispose();
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _storeNameFocus.dispose();
    _storeDescriptionFocus.dispose();
    _storeGovernorateFocus.dispose();
    _storeCityFocus.dispose();
    _storeStreetFocus.dispose();
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
    if (errorMessage.contains('merchant_store_name_required')) {
      return '⚠️ يرجى إدخال اسم المتجر';
    }
    if (errorMessage.contains('merchant_store_governorate_required')) {
      return '⚠️ يرجى اختيار المحافظة';
    }
    if (errorMessage.contains('merchant_store_city_required')) {
      return '⚠️ يرجى اختيار المدينة';
    }
    if (errorMessage.contains('merchant_store_street_required')) {
      return '⚠️ يرجى إدخال الشارع';
    }
    if (errorMessage.contains('merchant_store_address_required')) {
      return '⚠️ يرجى إدخال عنوان المتجر';
    }
    if (errorMessage.contains('Database error saving new user') ||
        errorMessage.contains('unexpected_failure')) {
      return 'تعذر إنشاء الحساب حالياً. تأكد من إكمال البيانات المطلوبة ثم أعد المحاولة.';
    }
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
    if (!_validateStep(_currentStep) ||
        !(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
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

    // Ensure legacy address string is synced before submission.
    _syncStoreAddressController();

    // في وضع التسجيل الصارم (Strict trigger) لازم يكون العنوان النهائي موجود.
    if (_storeAddressController.text.trim().isEmpty) {
      _showWarningMessage('يرجى إدخال عنوان المتجر بشكل كامل');
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
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
        storeGovernorate: _storeGovernorateController.text.trim(),
        storeCity: _storeCityController.text.trim(),
        storeArea: _storeAreaController.text.trim(),
        storeStreet: _storeStreetController.text.trim(),
        storeLandmark: _storeLandmarkController.text.trim(),
        storeLatitude: _storePosition?.latitude,
        storeLongitude: _storePosition?.longitude,
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
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return _buildWebLayout(context, theme);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: ResponsiveCenter(
        maxWidth: 700,
        child: SafeArea(
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
                                child: Container(
                                  key: _firstNameFieldKey,
                                  child: CustomTextField(
                                    controller: _firstNameController,
                                    label: 'الاسم الأول',
                                    hintText: 'مثال: أحمد',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    focusNode: _firstNameFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        _middleNameFocus.requestFocus(),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'مطلوب';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  key: _middleNameFieldKey,
                                  child: CustomTextField(
                                    controller: _middleNameController,
                                    label: 'الاسم الأوسط',
                                    hintText: 'مثال: سامي',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    focusNode: _middleNameFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        _lastNameFocus.requestFocus(),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'مطلوب';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: _lastNameFieldKey,
                            child: CustomTextField(
                              controller: _lastNameController,
                              label: 'اسم العائلة',
                              hintText: 'مثال: عبد الهادي',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              focusNode: _lastNameFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _emailFocus.requestFocus(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'اسم العائلة مطلوب';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: _emailFieldKey,
                            child: CustomTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hintText: 'example@gmail.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              keyboardType: TextInputType.emailAddress,
                              focusNode: _emailFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _phoneFocus.requestFocus(),
                              validator: Validators.validateEmail,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: _phoneFieldKey,
                            child: CustomTextField(
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
                          Container(
                            key: _storeNameFieldKey,
                            child: CustomTextField(
                              controller: _storeNameController,
                              label: 'اسم المتجر',
                              hintText: 'أدخل اسم متجرك',
                              prefixIcon: const Icon(Icons.storefront_outlined),
                              focusNode: _storeNameFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _storeGovernorateFocus.requestFocus(),
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
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: _storeMapSectionKey,
                            child: AddressLocationFormSection(
                              userType: MapUserType.merchant,
                              formType: AddressFormType.store,
                              formKey: _storeAddressSectionFormKey,
                              // IMPORTANT: this screen already has a parent Form.
                              wrapInForm: false,
                              governorateController:
                                  _storeGovernorateController,
                              cityController: _storeCityController,
                              areaController: _storeAreaController,
                              streetController: _storeStreetController,
                              landmarkController: _storeLandmarkController,
                              governorateFocus: _storeGovernorateFocus,
                              cityFocus: _storeCityFocus,
                              streetFocus: _storeStreetFocus,
                              position: _storePosition,
                              requirePosition: false,
                              showMapPicker: false,
                              onPositionChanged: (pos) {
                                setState(() {
                                  _storePosition = pos;
                                });
                              },
                              onGovernorateChanged:
                                  _handleStoreGovernorateSelection,
                              onCityChanged: _handleStoreCitySelection,
                              summaryCity: _storeSummaryCity,
                              summaryGovernorate: _storeSummaryGovernorate,
                              governorateOptions: _hasOwnerZoneOptions
                                  ? _governorateOptions
                                  : null,
                              cityOptions: _hasOwnerZoneOptions
                                  ? _cityOptions
                                  : null,
                              areaOptions: _hasOwnerZoneOptions
                                  ? _areaOptions
                                  : null,
                              updateLocationProvider: false,
                              refreshNearbyStores: false,
                              autofillAllFieldsFromMap: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _storeDescriptionController,
                            label: 'وصف المتجر',
                            hintText: 'اكتب نبذة مختصرة عن متجرك',
                            prefixIcon: const Icon(Icons.description_outlined),
                            focusNode: _storeDescriptionFocus,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                          ),

                          const SizedBox(height: 16),

                          // Store logo (mandatory)
                          // Category Dropdown
                          Container(
                            key: _storeCategorySectionKey,
                            child: DropdownButtonFormField<String>(
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                          Container(
                            key: _passwordFieldKey,
                            child: CustomTextField(
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
                          ),
                          const SizedBox(height: 12),
                          PasswordStrengthIndicator(password: _currentPassword),
                          const SizedBox(height: 16),
                          Container(
                            key: _confirmPasswordFieldKey,
                            child: CustomTextField(
                              controller: _confirmPasswordController,
                              label: 'تأكيد كلمة المرور',
                              hintText: 'أعد إدخال كلمة المرور',
                              prefixIcon: const Icon(Icons.lock),
                              isPasswordField: true,
                              focusNode: _confirmPasswordFocus,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _registerMerchant(),
                              validator: (v) =>
                                  Validators.validateConfirmPassword(
                                    v,
                                    _passwordController.text,
                                  ),
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
                          Container(
                            key: _termsSectionKey,
                            child: _buildTermsCheckbox(theme),
                          ),

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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: AppShimmer.wrap(
                      context,
                      child: AppShimmer.circle(context, size: 20),
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
                Text.rich(
                  TextSpan(
                    text: 'الشروط والأحكام',
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
                ),
                const Text(' و'),
                Text.rich(
                  TextSpan(
                    text: 'سياسة الخصوصية',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Web / Desktop Two-Column Layout
  // =====================================================

  Widget _buildWebLayout(BuildContext context, ThemeData theme) {
    return Scaffold(
      body: Row(
        children: [
          // ── الجانب الأيسر: لوحة العلامة التجارية ──
          Expanded(flex: 4, child: _buildBrandingPanel(theme)),
          // ── الجانب الأيمن: النموذج المتعدد الخطوات ──
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // ── هيدر الويب ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
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
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.store_mall_directory_rounded,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تسجيل تاجر جديد',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A237E),
                                ),
                              ),
                              Text(
                                _currentStep == 0
                                    ? 'الخطوة 1 من 3: البيانات الشخصية'
                                    : _currentStep == 1
                                    ? 'الخطوة 2 من 3: بيانات المتجر'
                                    : 'الخطوة 3 من 3: الأمان والشروط',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── محتوى النموذج ──
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 56,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autovalidateMode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProgress(),
                              const SizedBox(height: 28),

                              // ── خطوة 1: البيانات الشخصية ──
                              if (_currentStep == 0) ...[
                                _buildStep0Content(theme),
                              ],

                              // ── خطوة 2: بيانات المتجر ──
                              if (_currentStep == 1) ...[
                                _buildStep1Content(theme),
                              ],

                              // ── خطوة 3: الأمان ──
                              if (_currentStep == 2) ...[
                                _buildStep2Content(theme),
                              ],

                              _buildStepControls(theme),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'لديك حساب بالفعل؟',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                          context,
                                          AppRoutes.login,
                                        ),
                                    child: const Text('تسجيل الدخول'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // خطوة 1: البيانات الشخصية
  Widget _buildStep0Content(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 20),
        // الاسم الأول + الأوسط + العائلة في صف واحد
        Row(
          children: [
            Expanded(
              child: Container(
                key: _firstNameFieldKey,
                child: CustomTextField(
                  controller: _firstNameController,
                  label: 'الاسم الأول',
                  hintText: 'مثال: أحمد',
                  prefixIcon: const Icon(Icons.person_outline),
                  focusNode: _firstNameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _middleNameFocus.requestFocus(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الاسم الأول مطلوب';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                key: _middleNameFieldKey,
                child: CustomTextField(
                  controller: _middleNameController,
                  label: 'الاسم الأوسط',
                  hintText: 'مثال: سامي',
                  prefixIcon: const Icon(Icons.person_outline),
                  focusNode: _middleNameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _lastNameFocus.requestFocus(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الاسم الأوسط مطلوب';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                key: _lastNameFieldKey,
                child: CustomTextField(
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // البريد + الهاتف في صف
        Row(
          children: [
            Expanded(
              child: Container(
                key: _emailFieldKey,
                child: CustomTextField(
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                key: _phoneFieldKey,
                child: CustomTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hintText: '*********01',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+20 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  focusNode: _phoneFocus,
                  textInputAction: TextInputAction.done,
                  validator: Validators.validatePhone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // خطوة 2: بيانات المتجر
  Widget _buildStep1Content(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 20),
        Container(
          key: _storeNameFieldKey,
          child: CustomTextField(
            controller: _storeNameController,
            label: 'اسم المتجر',
            hintText: 'أدخل اسم متجرك',
            prefixIcon: const Icon(Icons.storefront_outlined),
            focusNode: _storeNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _storeGovernorateFocus.requestFocus(),
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
        ),
        const SizedBox(height: 16),
        Container(
          key: _storeMapSectionKey,
          child: AddressLocationFormSection(
            userType: MapUserType.merchant,
            formType: AddressFormType.store,
            formKey: _storeAddressSectionFormKey,
            wrapInForm: false,
            governorateController: _storeGovernorateController,
            cityController: _storeCityController,
            areaController: _storeAreaController,
            streetController: _storeStreetController,
            landmarkController: _storeLandmarkController,
            governorateFocus: _storeGovernorateFocus,
            cityFocus: _storeCityFocus,
            streetFocus: _storeStreetFocus,
            position: _storePosition,
            requirePosition: false,
            showMapPicker: false,
            onPositionChanged: (pos) => setState(() => _storePosition = pos),
            onGovernorateChanged: _handleStoreGovernorateSelection,
            onCityChanged: _handleStoreCitySelection,
            summaryCity: _storeSummaryCity,
            summaryGovernorate: _storeSummaryGovernorate,
            governorateOptions: _hasOwnerZoneOptions
                ? _governorateOptions
                : null,
            cityOptions: _hasOwnerZoneOptions ? _cityOptions : null,
            areaOptions: _hasOwnerZoneOptions ? _areaOptions : null,
            updateLocationProvider: false,
            refreshNearbyStores: false,
            autofillAllFieldsFromMap: true,
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _storeDescriptionController,
          label: 'وصف المتجر',
          hintText: 'اكتب نبذة مختصرة عن متجرك',
          prefixIcon: const Icon(Icons.description_outlined),
          focusNode: _storeDescriptionFocus,
          textInputAction: TextInputAction.done,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 16),
        Container(
          key: _storeCategorySectionKey,
          child: DropdownButtonFormField<String>(
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
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
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
                return DropdownMenuItem<String>(
                  value: category['id']?.toString() ?? '',
                  child: Text(category['name']?.toString() ?? ''),
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
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // خطوة 3: الأمان
  Widget _buildStep2Content(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 20),
        // كلمة المرور + تأكيد كلمة المرور جنباً إلى جنب
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                key: _passwordFieldKey,
                child: CustomTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  hintText: 'أدخل كلمة مرور قوية',
                  prefixIcon: const Icon(Icons.lock_outline),
                  isPasswordField: true,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                  validator: Validators.validatePassword,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                key: _confirmPasswordFieldKey,
                child: CustomTextField(
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PasswordStrengthIndicator(password: _currentPassword),
        const SizedBox(height: 20),
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
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سيتم إنشاء حسابك وبيانات متجرك مباشرة بعد تأكيد بريدك الإلكتروني',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(key: _termsSectionKey, child: _buildTermsCheckbox(theme)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBrandingPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade700, const Color(0xFF1A237E)],
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
                      'انضم كتاجر',
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
                      'وسّع أعمالك واوصل لآلاف العملاء',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 52),
                  _webFeatureRow(
                    Icons.storefront_rounded,
                    'أنشئ متجرك في دقائق',
                  ),
                  _webFeatureRow(Icons.people_rounded, 'اوصل لآلاف العملاء'),
                  _webFeatureRow(
                    Icons.bar_chart_rounded,
                    'تتبع مبيعاتك وأرباحك',
                  ),
                  _webFeatureRow(
                    Icons.local_shipping_rounded,
                    'توصيل سريع ومضمون',
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
