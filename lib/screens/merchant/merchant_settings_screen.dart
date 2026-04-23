import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/services/permission_service.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/services/merchant_service.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/widgets/address/address_form_section.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';

class MerchantSettingsScreen extends StatefulWidget {
  final bool scrollToSections;

  const MerchantSettingsScreen({super.key, this.scrollToSections = false});

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen>
    with SingleTickerProviderStateMixin {
  StoreModel? _store;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _coverUrl;
  String? _currentMerchantId;
  VoidCallback? _mpListenerRef;
  int _logoCacheBuster = DateTime.now().millisecondsSinceEpoch;
  int _coverCacheBuster = DateTime.now().millisecondsSinceEpoch;
  String _deliveryMode = 'store';
  TabController? _tabController;
  int _currentTabIndex = 0;

  Uint8List? _pendingLogoBytes;
  String? _pendingLogoFileName;
  Uint8List? _pendingCoverBytes;
  String? _pendingCoverFileName;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _governorateCtrl = TextEditingController();
  final _deliveryRadiusCtrl = TextEditingController(text: '7');
  final _deliveryFeeCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _deliveryTimeCtrl = TextEditingController();

  // FocusNodes للحقول المطلوبة
  final _streetFocus = FocusNode();
  final _governorateFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _deliveryRadiusFocus = FocusNode();

  final _addressFormKey = GlobalKey<FormState>();

  // تتبع الحقول التي بها أخطاء (لشاشة التوصيل)
  String? _deliveryRadiusError;

  bool _isOpen = true;
  bool get _isStoreDelivery => _deliveryMode == 'store';
  bool get _isAppDelivery => _deliveryMode == 'app';

  String? _storeCity;
  String? _storeGovernorate;
  double? _storeLatitude;
  double? _storeLongitude;
  List<DeliveryZonePricingModel> _ownerZones = <DeliveryZonePricingModel>[];

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _windows = [];
  List<Map<String, dynamic>> _sections = [];
  final Map<String, bool> _paymentActive = {
    'cash': false,
    'card': false,
    'wallet': false,
  };
  static const int _pageSize = 10;
  int _sectionsVisible = _pageSize;
  int _branchesVisible = _pageSize;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.scrollToSections ? 1 : 0;
    _ensureTabController();
    _loadOwnerZones();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachMerchantProviderListener();
      _ensureMerchantAvailable();
    });
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
    final gov = _governorateCtrl.text.trim();
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
    final gov = _governorateCtrl.text.trim();
    final city = _cityCtrl.text.trim();
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

  void _handleGovernorateSelection(String governorate) {
    setState(() {
      final selected = governorate.trim();
      _governorateCtrl.text = selected;
      _storeGovernorate = selected.isEmpty ? null : selected;

      final validCities = _ownerZones
          .where((z) => z.governorate.trim() == selected)
          .map((z) => (z.city ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_cityCtrl.text.trim().isNotEmpty &&
          !validCities.contains(_cityCtrl.text.trim())) {
        _cityCtrl.clear();
        _storeCity = null;
      }

      _areaCtrl.clear();
    });
  }

  void _handleCitySelection(String city) {
    setState(() {
      final selected = city.trim();
      _cityCtrl.text = selected;
      _storeCity = selected.isEmpty ? null : selected;

      final validAreas = _ownerZones
          .where(
            (z) =>
                z.governorate.trim() == _governorateCtrl.text.trim() &&
                (z.city ?? '').trim() == selected,
          )
          .map((z) => (z.area ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_areaCtrl.text.trim().isNotEmpty &&
          !validAreas.contains(_areaCtrl.text.trim())) {
        _areaCtrl.clear();
      }
    });
  }

  Future<void> _ensureMerchantAvailable() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final mp = context.read<MerchantProvider>();
    final auth = context.read<SupabaseProvider>();

    if (mp.selectedMerchant != null) {
      _currentMerchantId = mp.selectedMerchant!.id;
      await _loadForMerchant(_currentMerchantId!);
      return;
    }

    if (auth.isLoggedIn && auth.currentUserProfile != null) {
      if (!mp.isLoading) {
        try {
          await mp.fetchMerchantByProfileId(auth.currentUserProfile!.id);
          if (!mounted) return;
          if (mp.selectedMerchant != null) {
            _currentMerchantId = mp.selectedMerchant!.id;
            await _loadForMerchant(_currentMerchantId!);
            return;
          }
        } catch (_) {}
      }

      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        if (mp.selectedMerchant != null) {
          _currentMerchantId = mp.selectedMerchant!.id;
          await _loadForMerchant(_currentMerchantId!);
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد تاجر محدد';
      });
    }
  }

  Future<void> _loadForMerchant(String merchantId) async {
    try {
      final store = await StoreService.getStoreByMerchantIdV2(merchantId);
      if (!mounted) return;
      setState(() {
        _store = store;
        _loading = false;
        _error = null;
        _logoCacheBuster = DateTime.now().millisecondsSinceEpoch;
        _coverUrl = store?.coverUrl ?? _coverUrl;
        _deliveryMode = store?.deliveryMode ?? _deliveryMode;
      });
      if (store != null) {
        _nameCtrl.text = store.name;
        _descCtrl.text = store.description ?? '';
        _phoneCtrl.text = store.phone ?? '';
        // تحميل الحقول المفصّلة من القاعدة (والfallback لتحليل العنوان المدمج)
        _governorateCtrl.text = store.governorate ?? '';
        _cityCtrl.text = store.city ?? '';
        _areaCtrl.text = store.area ?? '';
        _streetCtrl.text = store.street ?? '';
        _landmarkCtrl.text = store.landmark ?? '';

        if (_governorateCtrl.text.trim().isEmpty &&
            _cityCtrl.text.trim().isEmpty &&
            _streetCtrl.text.trim().isEmpty &&
            store.address.trim().isNotEmpty) {
          _parseAddressToFields(store.address);
        }
        _storeLatitude = store.latitude;
        _storeLongitude = store.longitude;
        _deliveryRadiusCtrl.text = store.deliveryRadiusKm.toStringAsFixed(0);
        _deliveryFeeCtrl.text = store.deliveryFee.toStringAsFixed(0);
        _minOrderCtrl.text = store.minOrder.toStringAsFixed(0);
        _deliveryTimeCtrl.text = store.deliveryTime.toString();
        _isOpen = store.isOpen;
        _deliveryMode = store.deliveryMode;

        if ((_coverUrl == null || _coverUrl!.isEmpty)) {
          try {
            final cover = await StoreService.getStoreCoverUrl(store.id);
            if (mounted && cover != null) {
              setState(() {
                _coverUrl = cover;
                _coverCacheBuster = DateTime.now().millisecondsSinceEpoch;
              });
            }
          } catch (_) {}
        }

        try {
          final results = await Future.wait([
            StoreService.getStoreBranches(store.id),
            StoreService.getStorePaymentMethods(store.id),
            StoreService.getStoreOrderWindows(store.id),
            StoreService.getStoreSections(store.id),
          ]);

          if (!mounted) return;

          final branches = List<Map<String, dynamic>>.from(results[0] as List);
          final payments = List<Map<String, dynamic>>.from(results[1] as List);
          final windows = List<Map<String, dynamic>>.from(results[2] as List);
          final sections = List<Map<String, dynamic>>.from(results[3] as List);

          setState(() {
            _branches = branches;
            _windows = _normalizeWindows(windows);
            _sections = sections;
            _branchesVisible = math.min(_pageSize, _branches.length);
            _sectionsVisible = math.min(_pageSize, _sections.length);
            for (final m in ['cash', 'card', 'wallet']) {
              final row = payments.firstWhere(
                (e) => (e['method'] as String) == m,
                orElse: () => {},
              );
              _paymentActive[m] = row.isNotEmpty
                  ? (row['is_active'] == true)
                  : false;
            }
          });

          if (widget.scrollToSections) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _currentTabIndex = 1;
              _tabController?.animateTo(1);
            });
          }
        } catch (e) {
          AppLogger.warning('⚠️ تحذير: فشل تحميل بعض الإعدادات الثانوية: $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل بيانات المتجر';
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    final mp = context.read<MerchantProvider>();
    final merchant = mp.selectedMerchant;
    if (merchant == null) {
      return _ensureMerchantAvailable();
    }
    _currentMerchantId = merchant.id;
    return _loadForMerchant(merchant.id);
  }

  void _attachMerchantProviderListener() {
    final mp = context.read<MerchantProvider>();
    _mpListenerRef = () {
      if (!mounted) return;
      final m = mp.selectedMerchant;
      if (m != null && m.id != _currentMerchantId) {
        _currentMerchantId = m.id;
        // تأجيل التحميل حتى ينتهي الـ build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadForMerchant(m.id);
        });
      }
    };
    mp.addListener(_mpListenerRef!);
  }

  @override
  void dispose() {
    try {
      final mp = context.read<MerchantProvider>();
      if (_mpListenerRef != null) {
        mp.removeListener(_mpListenerRef!);
        _mpListenerRef = null;
      }
    } catch (_) {}
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _governorateCtrl.dispose();
    _deliveryRadiusCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _minOrderCtrl.dispose();
    _deliveryTimeCtrl.dispose();
    _streetFocus.dispose();
    _governorateFocus.dispose();
    _cityFocus.dispose();
    _deliveryRadiusFocus.dispose();
    _tabController?.removeListener(_handleTabSelectionChange);
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(String type) async {
    if (_store == null) return;

    try {
      // احفظ الألوان قبل أي async gap
      final primaryColor = Theme.of(context).colorScheme.primary;
      final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

      // التحقق من الأذونات أولاً
      final permissionService = PermissionService();
      final permissionResult = await permissionService
          .requestGalleryPermission();

      if (!permissionResult.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permissionResult.message ?? 'تم رفض إذن الوصول للصور',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final picker = ImagePicker();

      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
      );

      // تحقق من mounted بعد العودة من picker
      if (!mounted) return;
      if (file == null) return;

      // القص إلزامي - إذا لم يتم القص، لا يتم رفع الصورة
      final bool isLogo = type == 'logo';

      try {
        final cropper = ImageCropper();
        final cropped = await cropper.cropImage(
          sourcePath: file.path,
          compressQuality: 90,
          aspectRatio: isLogo
              ? const CropAspectRatio(ratioX: 1, ratioY: 1)
              : const CropAspectRatio(ratioX: 16, ratioY: 9),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'قص الصورة',
              toolbarColor: primaryColor,
              toolbarWidgetColor: onPrimaryColor,
              statusBarLight: false,
              activeControlsWidgetColor: primaryColor,
              // نثبت نسبة القص لكلٍ من الشعار والغلاف
              // الشعار 1:1 والغلاف 16:9 (محددة في aspectRatio أعلاه)
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'قص الصورة',
              // نثبت نسبة القص على iOS أيضًا
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        // تحقق من mounted بعد العودة من cropper
        if (!mounted) return;

        // إذا ألغى المستخدم القص، لا نرفع الصورة
        if (cropped == null) {
          AppLogger.info('ℹ️ تم إلغاء القص من قبل المستخدم');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء العملية'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // استخدم الصورة المقصوصة
        final bytes = await cropped.readAsBytes();

        // تحقق من mounted بعد قراءة الملف
        if (!mounted) return;

        // استخرج اسم الملف بشكل صحيح (يدعم Windows و Android)
        final pathParts = cropped.path.replaceAll('\\', '/').split('/');
        final fileName = pathParts.last;

        // خزّن الصورة مؤقتاً لعرض المعاينة، والرفع يكون عند الضغط على "حفظ التغييرات"
        setState(() {
          if (type == 'logo') {
            _pendingLogoBytes = bytes;
            _pendingLogoFileName = fileName;
          } else {
            _pendingCoverBytes = bytes;
            _pendingCoverFileName = fileName;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'logo'
                  ? 'تم تعيين الشعار. اضغط "حفظ التغييرات" لإتمام الرفع'
                  : 'تم تعيين الغلاف. اضغط "حفظ التغييرات" لإتمام الرفع',
            ),
          ),
        );
      } on MissingPluginException catch (e) {
        // القص غير متوفر على المنصة - نلغي العملية
        AppLogger.warning(
          '⚠️ MissingPluginException: القص غير متاح على هذه المنصة: $e',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عذراً، ميزة القص غير متاحة على هذا الجهاز'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } on PlatformException catch (e) {
        // خطأ في النظام - نلغي العملية
        AppLogger.error('⚠️ PlatformException في القص', e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في النظام: ${e.message ?? "غير معروف"}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      } catch (e) {
        // أي خطأ آخر - نلغي العملية
        AppLogger.error('⚠️ خطأ في قص الصورة', e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر قص الصورة. الرجاء المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    } on PlatformException catch (e) {
      AppLogger.error('❌ PlatformException في اختيار الصورة', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار الصورة: ${e.message ?? e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error('خطأ في رفع الصورة', e, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تعيين الصورة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<_ImageUploadResult> _uploadPendingImagesConcurrently() async {
    if (_store == null) return const _ImageUploadResult();

    final logoFuture =
        (_pendingLogoBytes != null && _pendingLogoFileName != null)
        ? StoreService.uploadStoreImageV2(
            storeId: _store!.id,
            bytes: _pendingLogoBytes!,
            fileName: _pendingLogoFileName!,
            type: 'logo',
          )
        : Future<String?>.value(null);

    final coverFuture =
        (_pendingCoverBytes != null && _pendingCoverFileName != null)
        ? StoreService.uploadStoreImageV2(
            storeId: _store!.id,
            bytes: _pendingCoverBytes!,
            fileName: _pendingCoverFileName!,
            type: 'cover',
          )
        : Future<String?>.value(null);

    final results = await Future.wait<String?>([logoFuture, coverFuture]);
    return _ImageUploadResult(logoUrl: results[0], coverUrl: results[1]);
  }

  Future<void> _save() async {
    if (_store == null) return;
    final mp = context.read<MerchantProvider>();
    final merchant = mp.selectedMerchant;
    if (merchant == null) return;

    // ✅ التحقق من فورم العنوان (Best practices: Form + TextFormField validators)
    final addressFormState = _addressFormKey.currentState;
    final addressValid =
        addressFormState?.validate() ?? _isAddressFieldsValid();
    if (!addressValid) {
      _showValidationError(
        'من فضلك أكمل بيانات العنوان المطلوبة قبل الحفظ',
        0,
        null,
      );
      return;
    }

    final streetText = _streetCtrl.text.trim();
    final landmarkText = _landmarkCtrl.text.trim();
    final areaText = _areaCtrl.text.trim();
    final cityText = _cityCtrl.text.trim();
    final governorateText = _governorateCtrl.text.trim();

    _storeCity = cityText.isEmpty ? null : cityText;
    _storeGovernorate = governorateText.isEmpty ? null : governorateText;

    // نطاق التوصيل - استخدام القيمة الافتراضية 7 كم إذا كان فارغاً
    final deliveryRadiusText = _deliveryRadiusCtrl.text.trim();
    double deliveryRadius = double.tryParse(deliveryRadiusText) ?? 7.0;
    if (deliveryRadius <= 0) {
      deliveryRadius = 7.0;
    }

    final parts = <String>[];
    if (governorateText.isNotEmpty) parts.add(governorateText);
    if (cityText.isNotEmpty) parts.add(cityText);
    if (areaText.isNotEmpty) parts.add(areaText);
    parts.add(streetText);
    if (landmarkText.isNotEmpty) parts.add(landmarkText);

    final addressText = parts.join('، ');

    setState(() => _saving = true);
    try {
      final uploads = await _uploadPendingImagesConcurrently();
      final newLogoUrl = uploads.logoUrl;
      final newCoverUrl = uploads.coverUrl;

      // 2) استكمال حفظ الحقول النصية وباقي الإعدادات
      final deliveryFee = double.tryParse(_deliveryFeeCtrl.text.trim());
      final minOrder = double.tryParse(_minOrderCtrl.text.trim());
      final deliveryTime = int.tryParse(_deliveryTimeCtrl.text.trim());

      // 🔍 Debug: طباعة قيم الموقع قبل الحفظ
      AppLogger.info('حفظ بيانات المتجر:');
      AppLogger.info('  - العنوان المركب: $addressText');
      AppLogger.info('  - Latitude: $_storeLatitude');
      AppLogger.info('  - Longitude: $_storeLongitude');

      // تحديث جدول المتجر (stores)
      final storeUpdateFuture = StoreService.updateStoreFieldsV2(
        storeId: _store!.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        governorate: governorateText.isEmpty ? null : governorateText,
        city: cityText.isEmpty ? null : cityText,
        area: areaText.isEmpty ? null : areaText,
        street: streetText,
        landmark: landmarkText.isEmpty ? null : landmarkText,
        latitude: _storeLatitude,
        longitude: _storeLongitude,
        deliveryRadiusKm: deliveryRadius,
        deliveryTime: deliveryTime,
        isOpen: _isOpen,
        deliveryFee: deliveryFee,
        minOrder: minOrder,
        imageUrl: newLogoUrl,
        coverUrl: newCoverUrl,
        deliveryMode: _deliveryMode,
      );

      final merchantUpdateFuture = MerchantService.updateMerchant(
        merchantId: merchant.id,
        storeName: _nameCtrl.text.trim(),
        address: addressText,
        storeDescription: _descCtrl.text.trim(),
      );

      final updated = await storeUpdateFuture;
      await merchantUpdateFuture;

      // حفظ طرق الدفع
      final paymentUpdateFutures = _paymentActive.entries.map((entry) {
        return StoreService.setStorePaymentMethod(
          storeId: _store!.id,
          method: entry.key,
          isActive: entry.value,
        );
      }).toList();
      await Future.wait(paymentUpdateFutures);

      // تحديث بيانات التاجر في الـ Provider عشان التغييرات تظهر فوراً
      await mp.fetchMerchantById(merchant.id);

      // حدّث الـ state بالصور الجديدة وصفّر الحالات المعلّقة
      setState(() {
        _store = updated ?? _store;
        if (newLogoUrl != null) {
          _pendingLogoBytes = null;
          _pendingLogoFileName = null;
          _logoCacheBuster = DateTime.now().millisecondsSinceEpoch;
        }
        if (newCoverUrl != null) {
          _coverUrl = newCoverUrl;
          _pendingCoverBytes = null;
          _pendingCoverFileName = null;
          _coverCacheBuster = DateTime.now().millisecondsSinceEpoch;
        }
      });

      if (mounted) {
        _showSuccessSnackBar('تم حفظ التغييرات بنجاح ✓');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل الحفظ: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Removed global categories add dialog. Merchant uses store-specific sections dialogs below.

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loading) {
      return _buildShimmerSettings();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: color.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: text.bodyLarge),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_store == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, color: color.onSurfaceVariant, size: 48),
            const SizedBox(height: 12),
            Text('لا يوجد متجر مرتبط بالحساب', style: text.bodyLarge),
          ],
        ),
      );
    }

    _ensureTabController();
    final controller = _tabController!;

    final tabs = const [
      Tab(icon: Icon(Icons.storefront_outlined), text: 'معلومات المتجر'),
      Tab(icon: Icon(Icons.category_outlined), text: 'الأقسام'),
      Tab(icon: Icon(Icons.local_shipping_outlined), text: 'التوصيل والمواعيد'),
      Tab(icon: Icon(Icons.apartment_outlined), text: 'الفروع والدفع'),
    ];

    return ResponsiveCenter(
      maxWidth: 700,
      child: Stack(
        children: [
          Column(
            children: [
              Material(
                color: color.surface,
                elevation: 1,
                child: SafeArea(
                  bottom: false,
                  child: TabBar(
                    controller: controller,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsetsDirectional.zero,
                    labelPadding: const EdgeInsetsDirectional.only(
                      start: 6,
                      end: 14,
                    ),
                    labelColor: color.primary,
                    unselectedLabelColor: color.onSurfaceVariant,
                    indicatorColor: color.primary,
                    tabs: tabs,
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: [
                    _buildStoreInfoTab(),
                    _buildSectionsTab(),
                    _buildDeliveryScheduleTab(),
                    _buildBranchesPaymentTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_saving)
            Container(
              color: Colors.black.withValues(alpha: 0.1),
              alignment: Alignment.center,
              child: AppShimmer.centeredLines(context, lines: 2),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Center(
                child: FloatingActionButton.extended(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              color.onPrimaryContainer,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التغييرات'),
                  elevation: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSettings() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _shimmerBox(height: 48, radius: 12),
          const SizedBox(height: 16),
          _shimmerBox(height: 160, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(height: 200, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(height: 220, radius: 12),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return AppShimmer.wrap(
      context,
      child: AppShimmer.box(
        context,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildStoreInfoTab() {
    final color = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _profileHeader(color),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('معلومات المتجر العامة'),
                _card([
                  _textField(
                    _nameCtrl,
                    label: 'اسم المتجر',
                    icon: Icons.store,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 8),
                  _textField(
                    _descCtrl,
                    label: 'وصف المتجر',
                    icon: Icons.notes,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionTitle('معلومات التواصل'),
                _card([
                  _textField(
                    _phoneCtrl,
                    label: 'رقم الهاتف',
                    icon: Icons.phone,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 16),
                  AddressLocationFormSection(
                    userType: MapUserType.merchant,
                    formType: AddressFormType.store,
                    formKey: _addressFormKey,
                    governorateController: _governorateCtrl,
                    cityController: _cityCtrl,
                    areaController: _areaCtrl,
                    streetController: _streetCtrl,
                    landmarkController: _landmarkCtrl,
                    governorateFocus: _governorateFocus,
                    cityFocus: _cityFocus,
                    streetFocus: _streetFocus,
                    position: _storeLatitude != null && _storeLongitude != null
                        ? LatLng(_storeLatitude!, _storeLongitude!)
                        : null,
                    requirePosition: false,
                    showMapPicker: false,
                    onPositionChanged: (pos) {
                      setState(() {
                        _storeLatitude = pos?.latitude;
                        _storeLongitude = pos?.longitude;
                      });
                    },
                    onGovernorateChanged: _handleGovernorateSelection,
                    onCityChanged: _handleCitySelection,
                    governorateOptions: _hasOwnerZoneOptions
                        ? _governorateOptions
                        : null,
                    cityOptions: _hasOwnerZoneOptions ? _cityOptions : null,
                    areaOptions: _hasOwnerZoneOptions ? _areaOptions : null,
                    summaryCity: _storeCity,
                    summaryGovernorate: _storeGovernorate,
                    // لا نحدّث LocationProvider هنا لأن ده موقع متجر.
                    updateLocationProvider: false,
                    refreshNearbyStores: false,
                    // الافتراضي: يملأ المحافظة + المركز فقط.
                    autofillAllFieldsFromMap: false,
                  ),
                ]),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryScheduleTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _sectionTitle('إعدادات التوصيل'),
          _buildDeliverySettingsCard(),
          const SizedBox(height: 16),
          _sectionTitle('مواعيد العمل'),
          _buildWorkingHoursCard(),
          const SizedBox(height: 24),
          _sectionTitle('حالة المتجر'),
          _buildStoreStatusFooter(),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final preview = _windows.take(2).toList();
    final remaining = _windows.length - preview.length;
    return _card([
      if (_windows.isEmpty) ...[
        Text(
          'لم يتم إضافة أي مواعيد عمل بعد.',
          style: theme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
      ] else ...[
        ...preview.map(_workingHourPreviewTile),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'و$remaining مواعيد إضافية',
              style: theme.bodySmall?.copyWith(color: color.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
      ],
      FilledButton.icon(
        onPressed: () async {
          await _showWindowsBottomSheet();
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.schedule),
        label: const Text('إدارة مواعيد العمل'),
      ),
    ]);
  }

  Widget _workingHourPreviewTile(Map<String, dynamic> window) {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final day = _dayName(window['day_of_week'] as int? ?? 0);
    final open = (window['open_time'] as String?) ?? '';
    final close = (window['close_time'] as String?) ?? '';
    final active = window['is_active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.surfaceContainerLow,
        border: Border.all(color: color.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.schedule_outlined,
            color: active ? color.primary : color.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$open → $close',
                  style: theme.bodyMedium?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (active ? color.primaryContainer : color.errorContainer)
                  .withValues(alpha: active ? 0.6 : 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              active ? 'نشط' : 'معطل',
              style: theme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? color.primary : color.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWindowsBottomSheet() async {
    if (!mounted) return;
    final controller = ScrollController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final color = Theme.of(ctx).colorScheme;
          final theme = Theme.of(ctx).textTheme;
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: Container(
              decoration: BoxDecoration(
                color: color.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: StatefulBuilder(
                builder: (ctx, setModalState) {
                  final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
                  final allDaysUsed = _windows.length >= 7;
                  final listContent = _windows.isEmpty
                      ? SingleChildScrollView(
                          controller: controller,
                          padding: const EdgeInsets.only(top: 24),
                          child: _buildEmptyWindowsState(),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: _windows.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) => _windowTile(
                            _windows[index],
                            onChanged: () => setModalState(() {}),
                          ),
                        );
                  return SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16 + bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: color.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'مواعيد العمل',
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: listContent),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving || allDaysUsed
                                ? null
                                : () async {
                                    await _showWindowDialog();
                                    setModalState(() {});
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة موعد'),
                          ),
                          if (allDaysUsed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'تم استخدام جميع أيام الأسبوع.',
                                style: theme.bodySmall?.copyWith(
                                  color: color.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildBranchesPaymentTab() {
    final branchesLimit = math.min(_branchesVisible, _branches.length);
    final branchesToShow = _branches.take(branchesLimit).toList();
    final hasMoreBranches = _branches.length > branchesLimit;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _sectionTitle('الفروع'),
          _card([
            if (_branches.isEmpty)
              _buildEmptyBranchesState()
            else ...[
              ...branchesToShow.map((b) => _branchTile(b)),
              if (hasMoreBranches) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _branchesVisible = math.min(
                          _branches.length,
                          _branchesVisible + _pageSize,
                        );
                      });
                    },
                    icon: const Icon(Icons.expand_more),
                    label: const Text('عرض المزيد'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _showBranchDialog(),
                  icon: const Icon(Icons.add_business),
                  label: const Text('إضافة فرع'),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          _sectionTitle('طرق الدفع'),
          _buildPaymentMethodsCard(),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final activeCount = _paymentActive.values.where((v) => v).length;

    return _card([
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.payment, color: color.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طرق الدفع المتاحة',
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeCount > 0
                      ? '$activeCount ${activeCount == 1 ? "طريقة" : "طرق"} مفعلة'
                      : 'لم يتم تفعيل أي طريقة دفع',
                  style: theme.bodySmall?.copyWith(
                    color: activeCount > 0
                        ? color.primary
                        : color.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () async {
          await _showPaymentMethodsBottomSheet();
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.settings),
        label: const Text('إدارة طرق الدفع'),
      ),
    ]);
  }

  Future<void> _showPaymentMethodsBottomSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final color = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) => FractionallySizedBox(
            heightFactor: 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: color.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: color.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: color.primary),
                        const SizedBox(width: 12),
                        Text(
                          'طرق الدفع',
                          style: theme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _paymentMethodTile(
                          method: 'cash',
                          title: 'الدفع نقداً',
                          subtitle: 'الدفع عند استلام الطلب',
                          icon: Icons.payments_outlined,
                          onChanged: (value) {
                            _togglePaymentLocal('cash', value);
                            setLocal(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        _paymentMethodTile(
                          method: 'wallet',
                          title: 'المحفظة الإلكترونية',
                          subtitle: 'استخدام رصيد المحفظة في التطبيق',
                          icon: Icons.account_balance_wallet_outlined,
                          onChanged: (value) {
                            _togglePaymentLocal('wallet', value);
                            setLocal(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: 0.5,
                          child: _paymentMethodTile(
                            method: 'card',
                            title: 'البطاقات الائتمانية',
                            subtitle: 'قريباً - قيد التطوير',
                            icon: Icons.credit_card,
                            onChanged: null, // معطل مؤقتاً
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _paymentMethodTile({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
    ValueChanged<bool>? onChanged, // جعله nullable
  }) {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final isActive = _paymentActive[method] ?? false;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isActive
          ? color.primaryContainer.withValues(alpha: 0.3)
          : color.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? color.primary.withValues(alpha: 0.5)
              : color.outlineVariant,
          width: isActive ? 2 : 1,
        ),
      ),
      child: SwitchListTile.adaptive(
        value: isActive,
        onChanged: (_saving || onChanged == null) ? null : onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? color.primaryContainer
                : color.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive ? color.primary : color.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: theme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? color.onSurface : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.bodySmall?.copyWith(color: color.onSurfaceVariant),
        ),
      ),
    );
  }

  void _ensureTabController() {
    if (_tabController != null) return;
    final initialIndex = _currentTabIndex.clamp(0, 3).toInt();
    final controller = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    controller.addListener(_handleTabSelectionChange);
    _tabController = controller;
  }

  void _handleTabSelectionChange() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) {
      return;
    }
    _currentTabIndex = controller.index;
  }

  Widget _buildSectionsTab() {
    final sectionsLimit = math.min(_sectionsVisible, _sections.length);
    final sectionsToShow = _sections.take(sectionsLimit).toList();
    final hasMoreSections = _sections.length > sectionsLimit;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _sectionTitle('أقسام المتجر'),
          _card([
            if (_sections.isEmpty)
              _buildEmptySectionsState()
            else ...[
              ...sectionsToShow.map((s) => _sectionTile(s)),
              if (hasMoreSections) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sectionsVisible = math.min(
                          _sections.length,
                          _sectionsVisible + _pageSize,
                        );
                      });
                    },
                    icon: const Icon(Icons.expand_more),
                    label: const Text('عرض المزيد'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _showSectionDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة قسم'),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  // ====== UI Tiles for new entities ======
  Widget _branchTile(Map<String, dynamic> b) {
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: color.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: color.secondary,
            size: 24,
          ),
        ),
        title: Text(
          b['name'] ?? 'فرع بدون اسم',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: color.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: color.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b['address'] ?? 'لا يوجد عنوان',
                  style: TextStyle(fontSize: 13, color: color.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) async {
            if (value == 'edit') {
              _showBranchDialog(branch: b);
            } else if (value == 'delete') {
              final ok = await _confirm(context, 'حذف الفرع؟');
              if (!ok) return;
              setState(() => _saving = true);
              try {
                await StoreService.deleteStoreBranch(b['id'] as String);
                setState(
                  () => _branches.removeWhere((x) => x['id'] == b['id']),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: color.secondary),
                  const SizedBox(width: 12),
                  const Text('تعديل'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: color.error),
                  const SizedBox(width: 12),
                  const Text('حذف'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(Map<String, dynamic> s) {
    final active = s['is_active'] == true;
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: active
          ? color.surfaceContainerLow
          : color.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? color.primary.withValues(alpha: 0.2)
              : color.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? color.primaryContainer
                : color.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.category_rounded,
            color: active ? color.primary : color.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                s['name'] ?? 'قسم بدون اسم',
                style: TextStyle(
                  color: active ? color.onSurface : color.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? color.primaryContainer
                    : color.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.check_circle : Icons.visibility_off,
                    size: 12,
                    color: active ? color.primary : color.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    active ? 'نشط' : 'معطل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? color.primary : color.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s['description'] != null &&
                  (s['description'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    s['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: color.onSurfaceVariant,
                    ),
                  ),
                ),
              Row(
                children: [
                  Icon(
                    Icons.sort,
                    size: 14,
                    color: color.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الترتيب: ${s['display_order'] ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) async {
            if (value == 'edit') {
              _showSectionDialog(section: s);
            } else if (value == 'toggle') {
              setState(() => _saving = true);
              try {
                final updated = await StoreService.updateStoreSection(
                  s['id'] as String,
                  {'is_active': !active},
                );
                if (updated != null) {
                  final idx = _sections.indexWhere((x) => x['id'] == s['id']);
                  if (idx >= 0) setState(() => _sections[idx] = updated);
                }
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            } else if (value == 'delete') {
              final ok = await _confirm(context, 'حذف القسم؟');
              if (!ok) return;
              setState(() => _saving = true);
              try {
                await StoreService.deleteStoreSection(s['id'] as String);
                setState(
                  () => _sections.removeWhere((x) => x['id'] == s['id']),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: color.primary),
                  const SizedBox(width: 12),
                  const Text('تعديل'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    active ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: active ? color.error : color.tertiary,
                  ),
                  const SizedBox(width: 12),
                  Text(active ? 'تعطيل' : 'تفعيل'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: color.error),
                  const SizedBox(width: 12),
                  const Text('حذف'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة موعد عمل محسّنة
  Widget _windowTile(Map<String, dynamic> w, {VoidCallback? onChanged}) {
    final active = w['is_active'] == true;
    final day = _dayName(w['day_of_week'] as int? ?? 0);
    final open = (w['open_time'] as String?) ?? '';
    final close = (w['close_time'] as String?) ?? '';
    final color = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: active
          ? color.surfaceContainerLow
          : color.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? color.tertiary.withValues(alpha: 0.2)
              : color.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? color.tertiaryContainer
                : color.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.schedule_rounded,
            color: active ? color.tertiary : color.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: active ? color.onSurface : color.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? color.tertiaryContainer
                    : color.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.check_circle : Icons.visibility_off,
                    size: 12,
                    color: active ? color.tertiary : color.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    active ? 'نشط' : 'معطل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? color.tertiary : color.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                size: 14,
                color: color.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '$open → $close',
                style: TextStyle(
                  fontSize: 13,
                  color: color.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) async {
            if (value == 'edit') {
              await _showWindowDialog(window: w);
              onChanged?.call();
            } else if (value == 'toggle') {
              setState(() => _saving = true);
              try {
                final updated = await StoreService.updateStoreOrderWindow(
                  w['id'] as String,
                  {'is_active': !active},
                );
                if (updated != null) {
                  final idx = _windows.indexWhere((x) => x['id'] == w['id']);
                  if (idx >= 0) {
                    setState(() {
                      _windows[idx] = updated;
                      _windows = _normalizeWindows(_windows);
                    });
                  }
                  onChanged?.call();
                }
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            } else if (value == 'delete') {
              final ok = await _confirm(context, 'حذف الموعد؟');
              if (!ok) return;
              setState(() => _saving = true);
              try {
                await StoreService.deleteStoreOrderWindow(w['id'] as String);
                setState(() {
                  _windows.removeWhere((x) => x['id'] == w['id']);
                  _windows = _normalizeWindows(_windows);
                });
                onChanged?.call();
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: color.tertiary),
                  const SizedBox(width: 12),
                  const Text('تعديل'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    active ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: active ? color.error : color.tertiary,
                  ),
                  const SizedBox(width: 12),
                  Text(active ? 'تعطيل' : 'تفعيل'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: color.error),
                  const SizedBox(width: 12),
                  const Text('حذف'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Actions for new entities ======
  void _togglePaymentLocal(String method, bool value) {
    setState(() {
      _paymentActive[method] = value;
    });
  }

  Future<void> _showBranchDialog({Map<String, dynamic>? branch}) async {
    if (_store == null) return;
    final name = TextEditingController(text: branch?['name'] ?? '');
    final address = TextEditingController(text: branch?['address'] ?? '');
    final phone = TextEditingController(text: branch?['phone'] ?? '');

    final isEdit = branch != null;
    final saved =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final color = Theme.of(ctx).colorScheme;
            final theme = Theme.of(ctx).textTheme;
            return FractionallySizedBox(
              heightFactor: 0.70,
              child: Container(
                decoration: BoxDecoration(
                  color: color.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: color.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEdit ? Icons.edit : Icons.add_business,
                            color: color.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEdit ? 'تعديل الفرع' : 'إضافة فرع جديد',
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: name,
                              decoration: const InputDecoration(
                                labelText: 'اسم الفرع',
                                hintText: 'مثال: الفرع الرئيسي',
                                prefixIcon: Icon(Icons.store),
                                border: OutlineInputBorder(),
                              ),
                              autofocus: !isEdit,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  FocusScope.of(ctx).nextFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: address,
                              decoration: const InputDecoration(
                                labelText: 'العنوان',
                                hintText: 'عنوان الفرع بالتفصيل',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  FocusScope.of(ctx).nextFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phone,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف (اختياري)',
                                hintText: '01xxxxxxxxx',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.pop(ctx, true),
                                icon: const Icon(Icons.check),
                                label: const Text('حفظ'),
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
        ) ??
        false;
    if (saved != true) return;

    setState(() => _saving = true);
    try {
      if (isEdit) {
        final updated = await StoreService.updateStoreBranch(
          branch['id'] as String,
          {
            'name': name.text.trim(),
            'address': address.text.trim(),
            'phone': phone.text.trim(),
          }..removeWhere((k, v) => v == null || (v is String && v.isEmpty)),
        );
        if (updated != null) {
          final idx = _branches.indexWhere((x) => x['id'] == branch['id']);
          if (idx >= 0) setState(() => _branches[idx] = updated);
        }
      } else {
        final added = await StoreService.addStoreBranch(
          storeId: _store!.id,
          name: name.text.trim(),
          address: address.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        );
        if (added != null) {
          setState(() {
            _branches.insert(0, added);
            _branchesVisible = math.min(
              _branches.length,
              math.max(_branchesVisible, _pageSize),
            );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ الفرع: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSectionDialog({Map<String, dynamic>? section}) async {
    if (_store == null) return;
    final name = TextEditingController(text: section?['name'] ?? '');
    final description = TextEditingController(
      text: section?['description'] ?? '',
    );
    final displayOrder = TextEditingController(
      text:
          section?['display_order']?.toString() ?? _sections.length.toString(),
    );
    bool active = section?['is_active'] == true;
    final isEdit = section != null;

    final saved =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final color = Theme.of(ctx).colorScheme;
            final theme = Theme.of(ctx).textTheme;
            return StatefulBuilder(
              builder: (ctx, setLocal) => FractionallySizedBox(
                heightFactor: 0.70,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: color.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isEdit ? Icons.edit : Icons.add_circle_outline,
                              color: color.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isEdit ? 'تعديل القسم' : 'إضافة قسم جديد',
                              style: theme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                  labelText: 'اسم القسم',
                                  hintText:
                                      'مثال: مقبلات، أطباق رئيسية، بناطيل',
                                  prefixIcon: Icon(Icons.category),
                                  border: OutlineInputBorder(),
                                ),
                                autofocus: !isEdit,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    FocusScope.of(ctx).nextFocus(),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: description,
                                decoration: const InputDecoration(
                                  labelText: 'الوصف (اختياري)',
                                  hintText: 'وصف مختصر للقسم',
                                  prefixIcon: Icon(Icons.notes),
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    FocusScope.of(ctx).nextFocus(),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: displayOrder,
                                decoration: const InputDecoration(
                                  labelText: 'ترتيب العرض',
                                  prefixIcon: Icon(Icons.sort),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) =>
                                    FocusScope.of(ctx).unfocus(),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('تفعيل القسم'),
                                subtitle: const Text('سيظهر القسم للعملاء'),
                                value: active,
                                onChanged: (v) => setLocal(() => active = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Footer
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('إلغاء'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  icon: const Icon(Icons.check),
                                  label: const Text('حفظ'),
                                ),
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
          },
        ) ??
        false;
    if (saved != true) return;

    setState(() => _saving = true);
    try {
      final order = int.tryParse(displayOrder.text.trim()) ?? _sections.length;
      if (isEdit) {
        final updated =
            await StoreService.updateStoreSection(section['id'] as String, {
              'name': name.text.trim(),
              'description': description.text.trim().isEmpty
                  ? null
                  : description.text.trim(),
              'display_order': order,
              'is_active': active,
            });
        if (updated != null) {
          final idx = _sections.indexWhere((x) => x['id'] == section['id']);
          if (idx >= 0) setState(() => _sections[idx] = updated);
        }
      } else {
        final added = await StoreService.addStoreSection(
          storeId: _store!.id,
          name: name.text.trim(),
          description: description.text.trim().isEmpty
              ? null
              : description.text.trim(),
          displayOrder: order,
          isActive: active,
        );
        if (added != null) {
          setState(() {
            _sections.add(added);
            _sections.sort(
              (a, b) => (a['display_order'] as int).compareTo(
                b['display_order'] as int,
              ),
            );
            _sectionsVisible = math.min(
              _sections.length,
              math.max(_sectionsVisible, _pageSize),
            );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ القسم: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showWindowDialog({Map<String, dynamic>? window}) async {
    if (_store == null) return;
    if (window == null && _windows.length >= 7) {
      _showErrorSnackBar('تم تسجيل جميع أيام الأسبوع بالفعل.');
      return;
    }
    final isEdit = window != null;
    final currentWindowId = window?['id'];

    // حساب الأيام المستخدمة (باستثناء اليوم الحالي في حالة التعديل)
    final usedDays = _windows
        .where(
          (w) =>
              !(isEdit &&
                  currentWindowId != null &&
                  w['id'] == currentWindowId),
        )
        .map((w) => w['day_of_week'] as int?)
        .whereType<int>()
        .toSet();

    int day = (window?['day_of_week'] as int?) ?? 0;

    // في حالة الإضافة، اختر أول يوم متاح
    if (!isEdit) {
      final firstAvailable = List.generate(
        7,
        (i) => i,
      ).firstWhere((d) => !usedDays.contains(d), orElse: () => day);
      day = firstAvailable;
    }

    TimeOfDay open = _parseTime(window?['open_time'] as String?);
    TimeOfDay close = _parseTime(window?['close_time'] as String?);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // حساب الأيام المتاحة (غير المستخدمة أو اليوم الحالي)
          final availableDays = List.generate(
            7,
            (i) => i,
          ).where((d) => !usedDays.contains(d) || d == day).toList();

          // تأكد من أن اليوم المختار موجود في القائمة المتاحة
          if (!availableDays.contains(day) && availableDays.isNotEmpty) {
            day = availableDays.first;
          }

          return AlertDialog(
            title: Text(isEdit ? 'تعديل موعد' : 'إضافة موعد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: availableDays.isEmpty ? null : day,
                  items: availableDays
                      .map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(_dayName(i)),
                        ),
                      )
                      .toList(),
                  onChanged: availableDays.isEmpty
                      ? null
                      : (v) {
                          if (v == null) return;
                          setLocal(() => day = v);
                        },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: open,
                          );
                          if (picked != null) setLocal(() => open = picked);
                        },
                        child: Text('من ${_formatTime(open)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: close,
                          );
                          if (picked != null) setLocal(() => close = picked);
                        },
                        child: Text('إلى ${_formatTime(close)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) return;

    setState(() => _saving = true);
    try {
      final openStr = _toPgTime(open);
      final closeStr = _toPgTime(close);
      if (isEdit) {
        final updated = await StoreService.updateStoreOrderWindow(
          window['id'] as String,
          {'day_of_week': day, 'open_time': openStr, 'close_time': closeStr},
        );
        if (updated != null) {
          final idx = _windows.indexWhere((x) => x['id'] == window['id']);
          if (idx >= 0) {
            setState(() {
              _windows[idx] = updated;
              _windows = _normalizeWindows(_windows);
            });
          }
        }
      } else {
        final added = await StoreService.addStoreOrderWindow(
          storeId: _store!.id,
          dayOfWeek: day,
          openTime: openStr,
          closeTime: closeStr,
        );
        if (added != null) {
          setState(() {
            _windows.add(added);
            _windows = _normalizeWindows(_windows);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ الموعد: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _normalizeWindows(List<dynamic> rawWindows) {
    final unique = <int, Map<String, dynamic>>{};
    for (final item in rawWindows) {
      if (item is! Map) continue;
      final mapItem = Map<String, dynamic>.from(item);
      final day = (mapItem['day_of_week'] as int?) ?? -1;
      if (day < 0 || day > 6) continue;
      unique[day] = mapItem;
    }
    final sorted = unique.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => e.value).toList();
  }

  bool _isAddressFieldsValid() {
    return _governorateCtrl.text.trim().isNotEmpty &&
        _cityCtrl.text.trim().isNotEmpty &&
        _streetCtrl.text.trim().isNotEmpty;
  }

  // ===== Helpers =====
  Future<bool> _confirm(BuildContext context, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // عرض SnackBar محسّن مع أيقونات وألوان
  void _showSuccessSnackBar(
    String message, {
    String? action,
    VoidCallback? onAction,
  }) {
    final color = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: color.onPrimaryContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: color.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action != null && onAction != null
            ? SnackBarAction(
                label: action,
                textColor: color.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final color = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: color.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: color.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// يعرض خطأ وينتقل إلى التاب والحقل المطلوب
  void _showValidationError(
    String message,
    int tabIndex,
    FocusNode? focusNode, {
    String? fieldName,
  }) {
    // تعيين رسالة الخطأ للحقل المناسب (مستخدم حالياً لنطاق التوصيل فقط)
    setState(() {
      _deliveryRadiusError = null;

      if (fieldName == 'deliveryRadius') {
        _deliveryRadiusError = message;
      }
    });

    // الانتقال إلى التاب الصحيح أولاً
    if (_tabController != null && _tabController!.index != tabIndex) {
      _tabController!.animateTo(tabIndex);
    }

    // عرض رسالة الخطأ
    _showErrorSnackBar(message);

    // الانتقال إلى الحقل بعد انتهاء الأنيميشن
    if (focusNode != null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    }
  }

  /// تفكيك العنوان المدمج إلى الحقول المنفصلة
  /// الترتيب: المحافظة - المدينة/المركز - القرية/الحي - الشارع - العلامة
  void _parseAddressToFields(String address) {
    if (address.isEmpty) return;

    final parts = address.split(RegExp(r'[،,]')).map((p) => p.trim()).toList();

    for (final part in parts) {
      if (part.isEmpty) continue;

      // 1. المحافظة
      if (part.startsWith('محافظة ')) {
        _governorateCtrl.text = part.replaceFirst('محافظة ', '');
        _storeGovernorate = _governorateCtrl.text;
      }
      // 2. المدينة/المركز (خانة واحدة)
      else if (part.startsWith('مركز ')) {
        _cityCtrl.text = part.replaceFirst('مركز ', '');
        _storeCity = _cityCtrl.text;
      } else if (part.startsWith('مدينة ')) {
        _cityCtrl.text = part.replaceFirst('مدينة ', '');
        _storeCity = _cityCtrl.text;
      }
      // 3. القرية/الحي (خانة واحدة)
      else if (part.startsWith('قرية ')) {
        _areaCtrl.text = part.replaceFirst('قرية ', '');
      } else if (part.startsWith('حي ')) {
        _areaCtrl.text = part.replaceFirst('حي ', '');
      }
      // التعرف الذكي على الحقول
      else if (_governorateCtrl.text.isEmpty && _isGovernorate(part)) {
        _governorateCtrl.text = part;
        _storeGovernorate = part;
      } else if (_cityCtrl.text.isEmpty && _isCity(part)) {
        _cityCtrl.text = part;
        _storeCity = part;
      } else if (_areaCtrl.text.isEmpty && _isVillageOrDistrict(part)) {
        _areaCtrl.text = part;
      }
      // 4. الشارع (أول قيمة غير إدارية)
      else if (_streetCtrl.text.isEmpty && !_isAdministrative(part)) {
        _streetCtrl.text = part;
      }
      // 5. العلامة المميزة (ثاني قيمة غير إدارية)
      else if (_landmarkCtrl.text.isEmpty && !_isAdministrative(part)) {
        _landmarkCtrl.text = part;
      }
    }
  }

  /// التحقق إذا كان النص يبدو كمحافظة (بدون قائمة ثابتة)
  bool _isGovernorate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // إذا بدأ بـ "محافظة" فهو محافظة
    if (trimmed.startsWith('محافظة')) return true;

    // إذا كان جزء من المحافظة المخزنة حالياً
    if (_storeGovernorate != null &&
        _storeGovernorate!.isNotEmpty &&
        (trimmed.contains(_storeGovernorate!) ||
            _storeGovernorate!.contains(trimmed))) {
      return true;
    }

    return false;
  }

  /// التحقق إذا كان النص يبدو كمدينة أو مركز
  /// المدينة والمركز = خانة واحدة
  bool _isCity(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('مدينة') ||
        trimmed.startsWith('مركز') ||
        trimmed.contains('مركز');
  }

  /// التحقق إذا كان النص يبدو كقرية أو حي
  bool _isVillageOrDistrict(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('قرية') || trimmed.startsWith('حي');
  }

  /// التحقق من أن النص إداري (لا يجب وضعه في حقل الشارع)
  /// الترتيب: المحافظة - المدينة/المركز - القرية/الحي - الشارع - العلامة
  bool _isAdministrative(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    return trimmed.startsWith('محافظة') || // المحافظة
        trimmed.startsWith('مدينة') || // المدينة/المركز
        trimmed.startsWith('مركز') || // المدينة/المركز
        trimmed.startsWith('قرية') || // القرية/الحي
        trimmed.startsWith('حي') || // القرية/الحي
        lower.startsWith('egypt') ||
        trimmed == 'مصر';
  }

  // حالة فارغة محسّنة للأقسام
  Widget _buildEmptySectionsState() {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.primaryContainer.withValues(alpha: 0.1),
            color.secondaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: color.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'ابدأ بتنظيم منتجاتك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف أقسام لتصنيف منتجاتك\n(مثل: مقبلات، أطباق رئيسية، حلويات، مشروبات)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _showSectionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول قسم'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // حالة فارغة محسّنة للفروع
  Widget _buildEmptyBranchesState() {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.secondaryContainer.withValues(alpha: 0.1),
            color.tertiaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.secondary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: color.secondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'أضف فروعك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف فروع متجرك وحدد مواقعها\nلسهولة التوصيل والإدارة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _showBranchDialog(),
            icon: const Icon(Icons.add_business),
            label: const Text('إضافة فرع جديد'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // حالة فارغة محسّنة لنوافذ الطلبات
  Widget _buildEmptyWindowsState() {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.primaryContainer.withValues(alpha: 0.15),
            color.secondaryContainer.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.primary.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.access_time_outlined,
            size: 64,
            color: color.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'نظّم أوقات العمل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'حدد مواعيد استقبال الطلبات\nلكل يوم من أيام الأسبوع',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _showWindowDialog(),
            icon: const Icon(Icons.schedule),
            label: const Text('إضافة موعد'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _dayName(int i) {
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    if (i < 0 || i > 6) return days[0];
    return days[i];
  }

  TimeOfDay _parseTime(String? s) {
    if (s == null || s.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _toPgTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _cacheBustedUrl(String url, int cacheBuster) {
    if (cacheBuster <= 0) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}cb=$cacheBuster';
  }

  Widget _card(List<Widget> children) {
    final color = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shadowColor: color.shadow,
      surfaceTintColor: color.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDeliverySettingsCard() {
    return _card([
      _buildDeliveryModeSelector(),
      const SizedBox(height: 16),
      _buildDeliveryModeInfoBanner(),
      const SizedBox(height: 20),
      _buildDeliveryInputGrid(),
    ]);
  }

  Widget _buildDeliveryModeInfoBanner() {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    final icon = _isStoreDelivery
        ? Icons.storefront_rounded
        : Icons.delivery_dining_rounded;
    final title = _isStoreDelivery
        ? 'المتجر مسؤول عن التوصيل'
        : 'التطبيق يتولى التوصيل بالكامل';
    final subtitle = _isStoreDelivery
        ? 'حدد الرسوم، الحد الأدنى، ومدة التوصيل وسيتم تطبيقها مباشرة على كل الطلبات.'
        : 'سيتم حساب رسوم ووقت التوصيل تلقائياً من التطبيق، ولن يحتاج العميل لرسوم إضافية منك.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.bodySmall?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInputGrid() {
    final disable = _isAppDelivery;
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_outlined, color: color.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'إعدادات الطلبات',
              style: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _textField(
          _deliveryRadiusCtrl,
          label: 'نطاق التوصيل (كم)',
          icon: Icons.radar_outlined,
          focusNode: _deliveryRadiusFocus,
          errorText: _deliveryRadiusError,
          enabled: !disable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helperText: disable
              ? 'يتم تحديد نطاق التوصيل من التطبيق تلقائياً (القيمة الافتراضية: 7 كم)'
              : 'أقصى مسافة للتوصيل من موقع المتجر (افتراضي: 7 كم)',
          helperMaxLines: 2,
          textInputAction: TextInputAction.next,
          onChanged: (v) {
            if (_deliveryRadiusError != null) {
              setState(() => _deliveryRadiusError = null);
            }
          },
          onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _textField(
          _minOrderCtrl,
          label: 'الحد الأدنى للطلب (جنيه)',
          icon: Icons.shopping_cart_outlined,
          keyboardType: TextInputType.number,
          helperText: 'الحد الأدنى لقيمة الطلب (مثال: 50 جنيه)',
          helperMaxLines: 1,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _textField(
          _deliveryFeeCtrl,
          label: 'رسوم التوصيل (جنيه)',
          icon: Icons.local_shipping_outlined,
          enabled: !disable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helperText: disable
              ? 'يتم احتساب رسوم التوصيل من التطبيق تلقائياً'
              : 'رسوم التوصيل الافتراضية لكل طلب',
          helperMaxLines: 2,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        _textField(
          _deliveryTimeCtrl,
          label: 'وقت التوصيل المتوقع (دقيقة)',
          icon: Icons.access_time_outlined,
          enabled: !disable,
          keyboardType: TextInputType.number,
          helperText: disable
              ? 'فريق التوصيل في التطبيق يحدد الوقت'
              : 'متوسط الوقت للوصول للعميل (مثال: 30 دقيقة)',
          helperMaxLines: 2,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: () => FocusScope.of(context).unfocus(),
        ),
      ],
    );
  }

  Widget _buildStoreStatusTile() {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('المتجر مفتوح'),
      subtitle: const Text(
        'أغلق المتجر مؤقتاً لإيقاف استقبال الطلبات بالكامل.',
      ),
      value: _isOpen,
      visualDensity: VisualDensity.compact,
      onChanged: (value) => setState(() => _isOpen = value),
    );
  }

  Widget _buildStoreStatusFooter() {
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: color.shadow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _buildStoreStatusTile(),
      ),
    );
  }

  Widget _buildDeliveryModeSelector() {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: color.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'طريقة التوصيل',
              style: theme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'اختر من سيقوم بتوصيل طلباتك للعملاء',
          style: theme.bodySmall?.copyWith(
            color: color.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _deliveryOptionTile(
                title: 'المتجر يوصّل بنفسه',
                subtitle: 'مناديب خاصة أو توصيل داخلي',
                icon: Icons.storefront,
                isSelected: _isStoreDelivery,
                onTap: _saving
                    ? null
                    : () => setState(() => _deliveryMode = 'store'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _deliveryOptionTile(
                title: 'التطبيق يتولى التوصيل',
                subtitle: 'مندوب التطبيق يحسب التكلفة',
                icon: Icons.local_shipping_outlined,
                isSelected: _isAppDelivery,
                onTap: _saving
                    ? null
                    : () => setState(() => _deliveryMode = 'app'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _deliveryOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final color = Theme.of(context).colorScheme;
    final borderColor = isSelected
        ? color.primary
        : color.outlineVariant.withValues(alpha: 0.7);
    final bgColor = isSelected
        ? color.primary.withValues(alpha: 0.08)
        : color.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? color.primary : color.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color.primary : color.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ترويسة بستايل فيسبوك: غلاف + شعار دائري متداخل
  Widget _profileHeader(ColorScheme color) {
    final logoUrl = _store?.imageUrl;
    final coverUrl = _coverUrl;
    // أضف timestamp لكسر الكاش وإجبار إعادة التحميل
    final logoKey = logoUrl != null && logoUrl.isNotEmpty
        ? ValueKey('logo_${logoUrl}_${DateTime.now().millisecondsSinceEpoch}')
        : null;
    final coverKey = coverUrl != null && coverUrl.isNotEmpty
        ? ValueKey('cover_${coverUrl}_${DateTime.now().millisecondsSinceEpoch}')
        : null;

    // احسب الارتفاع بناءً على نسبة 16:9
    final screenWidth = MediaQuery.of(context).size.width;
    final coverHeight = (screenWidth * 9) / 16; // نسبة 16:9

    return SizedBox(
      height: coverHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // صورة الغلاف
          Positioned.fill(
            child: Container(
              color: color.surfaceContainerHighest,
              child: _pendingCoverBytes != null
                  ? Image.memory(_pendingCoverBytes!, fit: BoxFit.cover)
                  : (coverUrl != null && coverUrl.isNotEmpty)
                  ? Image.network(
                      _cacheBustedUrl(coverUrl, _coverCacheBuster),
                      fit: BoxFit.cover,
                      key: coverKey,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.surfaceContainerHighest,
                            color.surfaceContainer,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: color.onSurface.withValues(alpha: 0.6),
                          size: 48,
                        ),
                      ),
                    ),
            ),
          ),
          // زر تغيير الغلاف (أعلى يسار)
          Positioned(
            top: 8,
            left: 8,
            child: FilledButton.tonalIcon(
              onPressed: _saving ? null : () => _pickAndUploadImage('cover'),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('تغيير الغلاف'),
            ),
          ),
          // الشعار الدائري + زر كاميرا قابل للنقر فقط (داخل حدود الـ header)
          Positioned(
            bottom: -30,
            right: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // IgnorePointer لمنع CircleAvatar من استهلاك الضغط
                IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: color.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: color.surfaceContainerHighest,
                      backgroundImage: _pendingLogoBytes != null
                          ? MemoryImage(_pendingLogoBytes!)
                          : ((logoUrl != null && logoUrl.isNotEmpty)
                                ? NetworkImage(
                                        _cacheBustedUrl(
                                          logoUrl,
                                          _logoCacheBuster,
                                        ),
                                      )
                                      as ImageProvider
                                : null),
                      key: logoKey,
                      child:
                          (_pendingLogoBytes == null &&
                              (logoUrl == null || logoUrl.isEmpty))
                          ? Icon(
                              Icons.store,
                              color: color.onSurface.withValues(alpha: 0.6),
                            )
                          : null,
                    ),
                  ),
                ),
                // زر الكاميرا فقط هو القابل للنقر
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      shape: const CircleBorder(),
                      color: _saving
                          ? color.primary.withValues(alpha: 0.6)
                          : color.primary,
                      elevation: 3,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _saving
                            ? null
                            : () => _pickAndUploadImage('logo'),
                        child: Center(
                          child: Icon(
                            Icons.camera_alt,
                            size: 22,
                            color: color.onPrimary,
                          ),
                        ),
                      ),
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

  Widget _textField(
    TextEditingController ctrl, {
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? helperText,
    int? helperMaxLines,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    FocusNode? focusNode,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    final color = Theme.of(context).colorScheme;

    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction:
          textInputAction ??
          (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
      onSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: hasError ? TextStyle(color: color.error) : null,
        prefixIcon: Icon(icon, color: hasError ? color.error : null),
        border: const OutlineInputBorder(),
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderSide: BorderSide(color: color.error, width: 2),
              )
            : null,
        focusedBorder: hasError
            ? OutlineInputBorder(
                borderSide: BorderSide(color: color.error, width: 2),
              )
            : null,
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // Removed categories management - merchant selects category during registration only
}

class _ImageUploadResult {
  final String? logoUrl;
  final String? coverUrl;

  const _ImageUploadResult({this.logoUrl, this.coverUrl});
}
