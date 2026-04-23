import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/utils/navigation_service.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/address_model.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/services/location_service.dart';
import 'package:ell_tall_market/services/address_service.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/widgets/address/address_form_section.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/screens/user/order_tracking_screen.dart';
import 'package:ell_tall_market/screens/user/order_history_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late AppSettingsProvider _settingsProvider;
  bool _didInitDependencies = false;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _userPhoneController =
      TextEditingController(); // رقم هاتف المستخدم الرئيسي

  final FocusNode _userPhoneFocus = FocusNode();
  final FocusNode _receiverNameFocus = FocusNode();
  final FocusNode _receiverPhoneFocus = FocusNode();
  final GlobalKey _addressSectionKey = GlobalKey();
  final GlobalKey _phoneSectionKey = GlobalKey();

  final Map<String, double> _merchantDiscounts = {};
  Map<String, dynamic>? _appliedCoupon;
  bool _isApplyingCoupon = false;

  bool _isReceiverAccountOwner = true;
  bool _isEditingPhone = false; // وضع التعديل على رقم الهاتف

  List<AddressModel> _savedAddresses = <AddressModel>[];
  AddressModel? _selectedAddress;
  List<DeliveryZonePricingModel> _activeDeliveryZones =
      <DeliveryZonePricingModel>[];

  double _swipeValue = 0.0;
  final double _swipeThreshold = 0.85;

  // Address Form Controllers
  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _governorateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingNumberController =
      TextEditingController();
  final TextEditingController _floorNumberController = TextEditingController();
  final TextEditingController _apartmentNumberController =
      TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _addressNotesController = TextEditingController();

  // Address Form FocusNodes
  final FocusNode _governorateFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _streetFocus = FocusNode();

  // Address position from map
  LatLng? _newAddressPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDependencies) return;
    _didInitDependencies = true;

    _settingsProvider = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );

    _loadSavedAddresses();
    _loadUserPhone(); // تحميل رقم الهاتف المحفوظ
    _loadActiveDeliveryZones();
  }

  Future<void> _loadActiveDeliveryZones() async {
    final zones = await DeliveryZonePricingService.getActiveZones();
    if (!mounted) return;
    setState(() {
      _activeDeliveryZones = zones;
    });
  }

  /// تحميل رقم الهاتف المحفوظ في البروفايل
  void _loadUserPhone() {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final phone = authProvider.currentUserProfile?.phone;
    if (phone != null && phone.isNotEmpty) {
      _userPhoneController.text = phone;
    }
  }

  /// حفظ رقم الهاتف في البروفايل
  Future<bool> _savePhoneToProfile() async {
    final phone = _userPhoneController.text.trim();
    if (phone.isEmpty) return false;

    final validation = Validators.validatePhone(phone);
    if (validation != null) return false;

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final currentProfile = authProvider.currentUserProfile;
      if (currentProfile == null) return false;

      // تحديث البروفايل برقم الهاتف الجديد
      final updatedProfile = ProfileModel(
        id: currentProfile.id,
        fullName: currentProfile.fullName,
        email: currentProfile.email,
        phone: phone,
        avatarUrl: currentProfile.avatarUrl,
        role: currentProfile.role,
        isActive: currentProfile.isActive,
        isOnline: currentProfile.isOnline,
        birthDate: currentProfile.birthDate,
        gender: currentProfile.gender,
        createdAt: currentProfile.createdAt,
        updatedAt: DateTime.now(),
      );

      final success = await authProvider.updateProfile(updatedProfile);
      if (success) {
        await authProvider.refreshProfile();
        AppLogger.info('✅ تم حفظ رقم الهاتف بنجاح: $phone');
      }
      return success;
    } catch (e) {
      AppLogger.error('❌ فشل حفظ رقم الهاتف', e);
      return false;
    }
  }

  String _formatAddressForDisplay(String? address) {
    final raw = (address ?? '').trim();
    if (raw.isEmpty) return '';

    var value = raw;

    // Remove common coordinate fragments if present.
    value = value.replaceAll(
      RegExp(
        r'\([^)]*(lat|lng|latitude|longitude)[^)]*\)',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(r'(lat|latitude)\s*:\s*-?\d+(?:\.\d+)?', caseSensitive: false),
      '',
    );
    value = value.replaceAll(
      RegExp(r'(lng|longitude)\s*:\s*-?\d+(?:\.\d+)?', caseSensitive: false),
      '',
    );

    value = value.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    value = value.replaceAll(RegExp(r'\s+,\s+'), ', ').trim();
    value = value.replaceAll(RegExp(r',\s*,'), ',').trim();

    return value;
  }

  String _normalizeZoneValue(String? input) {
    var value = (input ?? '').trim().toLowerCase();
    value = value
        .replaceFirst(RegExp(r'^محافظة\s+'), '')
        .replaceFirst(RegExp(r'^مدينة\s+'), '')
        .replaceFirst(RegExp(r'^مركز\s+'), '')
        .replaceFirst(RegExp(r'^حي\s+'), '')
        .replaceFirst(RegExp(r'^منطقة\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }

  DeliveryZonePricingModel? _resolveDeliveryZone(AddressModel? address) {
    if (address == null || _activeDeliveryZones.isEmpty) return null;

    final addressGov = _normalizeZoneValue(address.governorate);
    final addressCity = _normalizeZoneValue(address.city);
    final addressArea = _normalizeZoneValue(address.area);

    final candidates = _activeDeliveryZones.where((zone) {
      final zoneGov = _normalizeZoneValue(zone.governorate);
      if (zoneGov.isEmpty || zoneGov != addressGov) return false;

      final zoneCity = _normalizeZoneValue(zone.city);
      if (zoneCity.isNotEmpty && zoneCity != addressCity) return false;

      final zoneArea = _normalizeZoneValue(zone.area);
      if (zoneArea.isNotEmpty && zoneArea != addressArea) return false;

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aScore =
          ((a.city ?? '').trim().isNotEmpty ? 1 : 0) +
          ((a.area ?? '').trim().isNotEmpty ? 1 : 0);
      final bScore =
          ((b.city ?? '').trim().isNotEmpty ? 1 : 0) +
          ((b.area ?? '').trim().isNotEmpty ? 1 : 0);
      return bScore.compareTo(aScore);
    });

    return candidates.first;
  }

  double _getAppDeliveryFeeBySelectedZone() {
    final matchedZone = _resolveDeliveryZone(_selectedAddress);
    if (matchedZone != null) return matchedZone.fee;
    return _settingsProvider.appSettings.appDeliveryBaseFee;
  }

  double _calculateTotalDeliveryFee(CartProvider cartProvider) {
    double totalDeliveryFee = 0.0;
    bool hasAppDelivery = false;
    final processedStores = <String>{};

    for (final item in cartProvider.cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      final store = product?['stores'] as Map<String, dynamic>?;

      final storeId = (store?['id'] ?? item['store_id'] ?? product?['store_id'])
          ?.toString();
      if (storeId == null || storeId.isEmpty) continue;

      if (processedStores.contains(storeId)) continue;
      processedStores.add(storeId);

      final deliveryMode = store?['delivery_mode'] as String? ?? 'store';

      if (deliveryMode == 'store') {
        final fee = (store?['delivery_fee'] as num?)?.toDouble() ?? 0.0;
        totalDeliveryFee += fee;
      } else {
        hasAppDelivery = true;
      }
    }

    if (hasAppDelivery) {
      totalDeliveryFee += _getAppDeliveryFeeBySelectedZone();
    }

    return totalDeliveryFee;
  }

  // حساب الخصم الإجمالي
  double get _totalDiscount {
    return _merchantDiscounts.values.fold(
      0.0,
      (sum, discount) => sum + discount,
    );
  }

  /// التحقق من جميع المتاجر في السلة ضد عنوان معين باستخدام PostGIS
  /// يعيد قائمة بأسماء المتاجر التي خارج نطاق التوصيل
  Future<List<String>> _getStoresOutOfRange(
    CartProvider cartProvider,
    AddressModel? address,
  ) async {
    if (address == null) {
      return [];
    }

    final storesOutOfRange = <String>[];
    final processedStores = <String>{};

    final addressCity = _normalizeZoneValue(address.city);

    // نظام المدينة: لو مفيش إحداثيات، نعتمد على تطابق المدينة فقط.
    if (address.latitude == null || address.longitude == null) {
      for (var item in cartProvider.cartItems) {
        final product = item['product'] as Map<String, dynamic>?;
        if (product == null || product['stores'] == null) continue;

        final store = product['stores'] as Map<String, dynamic>;
        final storeId = store['id'] as String? ?? '';
        final storeName = store['name'] as String? ?? 'متجر غير معروف';

        if (processedStores.contains(storeId)) continue;
        processedStores.add(storeId);

        final storeCity = _normalizeZoneValue(store['city'] as String?);
        if (addressCity.isNotEmpty &&
            storeCity.isNotEmpty &&
            storeCity != addressCity) {
          storesOutOfRange.add(storeName);
        }
      }

      return storesOutOfRange;
    }

    AppLogger.info('📍 التحقق من نطاق التوصيل للعنوان:');
    AppLogger.info('  Lat: ${address.latitude}, Lng: ${address.longitude}');

    for (var item in cartProvider.cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product != null && product['stores'] != null) {
        final store = product['stores'] as Map<String, dynamic>;
        final storeId = store['id'] as String? ?? '';
        final storeName = store['name'] as String? ?? 'متجر غير معروف';

        // تجنب التحقق من نفس المتجر مرتين
        if (processedStores.contains(storeId)) continue;
        processedStores.add(storeId);

        // ✅ شرط النظام الجديد: المتجر لازم يكون في نفس مدينة العميل
        final storeCity = _normalizeZoneValue(store['city'] as String?);
        if (addressCity.isNotEmpty &&
            storeCity.isNotEmpty &&
            storeCity != addressCity) {
          AppLogger.warning(
            '  ❌ اختلاف المدينة: المتجر في ${store['city']} والعميل في ${address.city}',
          );
          storesOutOfRange.add(storeName);
          continue;
        }

        try {
          AppLogger.info('🏪 التحقق من متجر: $storeName (ID: $storeId)');

          // استخدام PostGIS للتحقق من إمكانية التوصيل
          final deliveryCheck = await LocationService.canDeliverToLocation(
            storeId: storeId,
            latitude: address.latitude!,
            longitude: address.longitude!,
          );

          if (deliveryCheck != null) {
            final canDeliver = deliveryCheck['can_deliver'] as bool? ?? false;
            final distance = deliveryCheck['distance_km'] as double? ?? 0.0;

            AppLogger.info('  📊 النتيجة:');
            AppLogger.info('    - يمكن التوصيل: $canDeliver');
            AppLogger.info('    - المسافة: ${distance.toStringAsFixed(2)} كم');

            if (!canDeliver) {
              AppLogger.warning('  ❌ المتجر خارج نطاق التوصيل');
              storesOutOfRange.add(storeName);
            } else {
              AppLogger.info('  ✅ المتجر داخل نطاق التوصيل');
            }
          } else {
            // تنفيذ تحقق يدوي إذا فشلت وظيفة RPC أو لم ترجع بيانات

            // 1. التحقق من تطابق المحافظة (Strict Governorate Check)
            final storeGov = store['governorate'] as String?;
            final addrGov = address.governorate;

            if (storeGov != null &&
                addrGov != null &&
                storeGov.trim().isNotEmpty &&
                addrGov.trim().isNotEmpty &&
                storeGov.trim() != addrGov.trim()) {
              AppLogger.warning(
                '  ❌ اختلاف المحافظة: المتجر في $storeGov والعميل في $addrGov',
              );
              storesOutOfRange.add(storeName);
              continue;
            }

            // 2. التحقق من المسافة حسب نظام التوصيل (Distance Check by Delivery Mode)
            final deliveryMode = store['delivery_mode'] as String? ?? 'store';
            final storeLat = (store['latitude'] as num?)?.toDouble();
            final storeLng = (store['longitude'] as num?)?.toDouble();

            // تحديد نطاق التوصيل حسب النظام
            final double radius;
            if (deliveryMode == 'app') {
              // نظام توصيل التطبيق - يستخدم إعدادات الأدمن
              radius = _settingsProvider.appSettings.appDeliveryMaxDistance;
              AppLogger.info('  📦 نظام التوصيل: التطبيق (نطاق $radius كم)');
            } else {
              // نظام توصيل المتجر - يستخدم نطاق المتجر
              radius = (store['delivery_radius_km'] as num?)?.toDouble() ?? 7.0;
              AppLogger.info('  🏪 نظام التوصيل: المتجر (نطاق $radius كم)');
            }

            if (storeLat != null && storeLng != null) {
              final distance = LocationService.calculateDistance(
                lat1: address.latitude!,
                lon1: address.longitude!,
                lat2: storeLat,
                lon2: storeLng,
              );

              AppLogger.info(
                '  📏 التحقق اليدوي: المسافة ${distance.toStringAsFixed(2)} كم، النطاق $radius كم',
              );

              if (distance > radius) {
                AppLogger.warning('  ❌ المتجر خارج نطاق التوصيل (تحقق يدوي)');
                storesOutOfRange.add(storeName);
              } else {
                AppLogger.info('  ✅ المتجر داخل نطاق التوصيل (تحقق يدوي)');
              }
            } else {
              AppLogger.info(
                'ℹ️ لا توجد إحداثيات للمتجر "$storeName" - السماح بالطلب',
              );
            }
          }
        } catch (e) {
          AppLogger.error('  ❌ خطأ في التحقق من المتجر: $e');
          // في حالة الخطأ، نسمح بالطلب (قد يكون خطأ تقني مؤقت)
          AppLogger.warning('  ⚠️ السماح بالطلب بسبب خطأ تقني');
        }
      }
    }

    return storesOutOfRange;
  }

  // تطبيق الكوبون
  Future<void> _applyCoupon(
    BuildContext context,
    CartProvider cartProvider,
  ) async {
    if (_couponController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز الكوبون'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isApplyingCoupon = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final supabase = Supabase.instance.client;
      final couponCode = _couponController.text.trim().toUpperCase();

      // جلب بيانات الكوبون
      final response = await supabase
          .from('coupons')
          .select('*')
          .eq('code', couponCode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('كوبون غير صحيح أو غير موجود');
      }

      final coupon = response;

      // التحقق من تاريخ بداية صلاحية الكوبون
      if (coupon['valid_from'] != null) {
        final startDate = DateTime.parse(coupon['valid_from']);
        if (startDate.isAfter(DateTime.now())) {
          throw Exception('هذا الكوبون لم يبدأ بعد');
        }
      }

      // التحقق من تاريخ انتهاء صلاحية الكوبون
      if (coupon['valid_until'] != null) {
        final expiryDate = DateTime.parse(coupon['valid_until']);
        if (expiryDate.isBefore(DateTime.now())) {
          throw Exception('هذا الكوبون منتهي الصلاحية');
        }
      }

      // التحقق من الحد الأقصى للاستخدام الكلي
      if (coupon['usage_limit'] != null &&
          (coupon['used_count'] ?? 0) >= coupon['usage_limit']) {
        throw Exception('تم استخدام هذا الكوبون بالحد الأقصى');
      }

      // التحقق من الحد الأقصى للاستخدام لكل مستخدم
      final userId = supabase.auth.currentUser?.id;
      if (userId != null && coupon['usage_limit_per_user'] != null) {
        final usageCount = await supabase
            .from('coupon_usage')
            .select('id')
            .eq('coupon_id', coupon['id'])
            .eq('user_id', userId);
        if ((usageCount as List).length >=
            (coupon['usage_limit_per_user'] as int)) {
          throw Exception('لقد استخدمت هذا الكوبون من قبل');
        }
      }

      if (!mounted) return;

      // تحديد نوع الكوبون: خاص بمتجر، خاص بتاجر، أو عام
      final storeId = coupon['store_id'] as String?;
      final merchantId = coupon['merchant_id'] as String?;

      if (storeId != null) {
        // كوبون خاص بمتجر معين
        await _applyStoreCoupon(coupon, cartProvider, storeId);
      } else if (merchantId != null) {
        // كوبون خاص بتاجر معين (كل متاجره)
        await _applyMerchantCoupon(coupon, cartProvider);
      } else {
        // كوبون عام يعمل على كل المنتجات
        await _applyGlobalCoupon(coupon, cartProvider);
      }
    } catch (e) {
      if (!mounted) return;

      // رسالة خطأ محسّنة حسب نوع الخطأ
      String errorMsg;
      IconData errorIcon;
      Color errorColor;

      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Connection closed') ||
          errStr.contains('HandshakeException')) {
        errorMsg = 'لا يوجد اتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى';
        errorIcon = Icons.wifi_off_rounded;
        errorColor = Colors.orange.shade700;
      } else if (errStr.contains('TimeoutException')) {
        errorMsg = 'انتهت مهلة الاتصال. حاول مرة أخرى';
        errorIcon = Icons.timer_off_rounded;
        errorColor = Colors.orange.shade700;
      } else {
        errorMsg = errStr.replaceAll('Exception: ', '');
        errorIcon = Icons.error_outline_rounded;
        errorColor = Colors.red.shade700;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(errorIcon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplyingCoupon = false);
      }
    }
  }

  // تطبيق كوبون خاص بمتجر معين
  Future<void> _applyStoreCoupon(
    Map<String, dynamic> coupon,
    CartProvider cartProvider,
    String storeId,
  ) async {
    if (!mounted) return;

    final couponType = coupon['coupon_type'] as String? ?? 'percentage';

    // جلب اسم المتجر
    String storeName = 'المتجر';
    try {
      final storeData = await _supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();
      if (storeData != null) {
        storeName = storeData['name'] as String? ?? 'المتجر';
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل جلب اسم المتجر', e);
    }

    // فلترة منتجات هذا المتجر فقط
    final storeItems = cartProvider.cartItems.where((item) {
      final product = item['product'] as Map<String, dynamic>;
      final store = product['stores'] as Map<String, dynamic>?;
      final itemStoreId =
          (store?['id'] ?? item['store_id'] ?? product['store_id'])?.toString();
      return itemStoreId == storeId;
    }).toList();

    if (storeItems.isEmpty) {
      throw Exception('لا توجد منتجات من $storeName في السلة');
    }

    // ── Flash Sale: التحقق من ساعات التفعيل ──
    if (couponType == 'flash_sale') {
      final startH = coupon['active_hours_start'] as int?;
      final endH = coupon['active_hours_end'] as int?;
      if (startH != null && endH != null) {
        final nowHour = DateTime.now().hour;
        bool inRange;
        if (startH <= endH) {
          inRange = nowHour >= startH && nowHour < endH;
        } else {
          inRange = nowHour >= startH || nowHour < endH;
        }
        if (!inRange) {
          String formatHour(int h) {
            if (h == 0) return '12 ص';
            if (h < 12) return '$h ص';
            if (h == 12) return '12 م';
            return '${h - 12} م';
          }

          throw Exception(
            'هذا العرض متاح فقط من ${formatHour(startH)} إلى ${formatHour(endH)} ⚡',
          );
        }
      }
    }

    // حساب مجموع منتجات المتجر + عدد العناصر
    double storeSubtotal = 0;
    int totalQuantity = 0;
    for (var item in storeItems) {
      storeSubtotal += (item['total_price'] as num).toDouble();
      totalQuantity += (item['quantity'] as int?) ?? 1;
    }

    // ── Product Specific: فلتر المنتجات المؤهلة فقط ──
    double eligibleAmount = storeSubtotal;
    if (couponType == 'product_specific') {
      final productIds = _parseProductIds(coupon['product_ids']);
      if (productIds.isNotEmpty) {
        eligibleAmount = 0;
        bool hasMatch = false;
        for (var item in storeItems) {
          final product = item['product'] as Map<String, dynamic>;
          if (productIds.contains(product['id'])) {
            eligibleAmount += (item['total_price'] as num).toDouble();
            hasMatch = true;
          }
        }
        if (!hasMatch) {
          throw Exception('لا توجد منتجات مؤهلة لهذا الكوبون في سلتك');
        }
      }
    }

    // التحقق من الحد الأدنى
    final minOrderAmount = (coupon['minimum_order_amount'] as num?)?.toDouble();
    if (minOrderAmount != null && storeSubtotal < minOrderAmount) {
      throw Exception(
        'الحد الأدنى لطلب $storeName هو ${minOrderAmount.toStringAsFixed(2)} ج.م',
      );
    }

    // حساب الخصم
    double discount = _calculateCouponDiscount(
      coupon: coupon,
      couponType: couponType,
      orderAmount: storeSubtotal,
      totalQuantity: totalQuantity,
      eligibleAmount: eligibleAmount,
    );

    // حفظ الكوبون المطبق
    setState(() {
      _appliedCoupon = coupon;
      _merchantDiscounts[storeId] = discount;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تطبيق خصم ${discount.toStringAsFixed(2)} ج.م على منتجات $storeName',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // تطبيق كوبون خاص بتاجر
  Future<void> _applyMerchantCoupon(
    Map<String, dynamic> coupon,
    CartProvider cartProvider,
  ) async {
    if (!mounted) return;

    final merchantId = coupon['merchant_id'];

    // جلب اسم التاجر بشكل منفصل
    String merchantName = 'التاجر';
    try {
      final merchantData = await _supabase
          .from('merchants')
          .select('name')
          .eq('id', merchantId)
          .maybeSingle();
      if (merchantData != null) {
        merchantName = merchantData['name'] as String? ?? 'التاجر';
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل جلب اسم التاجر', e);
    }

    final couponType = coupon['coupon_type'] as String? ?? 'percentage';

    // فلترة منتجات هذا التاجر فقط
    final merchantItems = cartProvider.cartItems.where((item) {
      final product = item['product'] as Map<String, dynamic>;
      final store = product['stores'] as Map<String, dynamic>?;
      return store?['merchant_id'] == merchantId;
    }).toList();

    if (merchantItems.isEmpty) {
      throw Exception('لا توجد منتجات من $merchantName في السلة');
    }

    // ── Flash Sale: التحقق من ساعات التفعيل ──
    if (couponType == 'flash_sale') {
      final startH = coupon['active_hours_start'] as int?;
      final endH = coupon['active_hours_end'] as int?;
      if (startH != null && endH != null) {
        final nowHour = DateTime.now().hour;
        bool inRange;
        if (startH <= endH) {
          inRange = nowHour >= startH && nowHour < endH;
        } else {
          inRange = nowHour >= startH || nowHour < endH;
        }
        if (!inRange) {
          String formatHour(int h) {
            if (h == 0) return '12 ص';
            if (h < 12) return '$h ص';
            if (h == 12) return '12 م';
            return '${h - 12} م';
          }

          throw Exception(
            'هذا العرض متاح فقط من ${formatHour(startH)} إلى ${formatHour(endH)} ⚡',
          );
        }
      }
    }

    // حساب مجموع منتجات التاجر + عدد العناصر
    double merchantSubtotal = 0;
    int totalQuantity = 0;
    for (var item in merchantItems) {
      merchantSubtotal += (item['total_price'] as num).toDouble();
      totalQuantity += (item['quantity'] as int?) ?? 1;
    }

    // ── Product Specific: فلتر المنتجات المؤهلة فقط ──
    double eligibleAmount = merchantSubtotal;
    if (couponType == 'product_specific') {
      final productIds = _parseProductIds(coupon['product_ids']);
      if (productIds.isNotEmpty) {
        eligibleAmount = 0;
        bool hasMatch = false;
        for (var item in merchantItems) {
          final product = item['product'] as Map<String, dynamic>;
          if (productIds.contains(product['id'])) {
            eligibleAmount += (item['total_price'] as num).toDouble();
            hasMatch = true;
          }
        }
        if (!hasMatch) {
          throw Exception('لا توجد منتجات مؤهلة لهذا الكوبون في سلتك');
        }
      }
    }

    // التحقق من الحد الأدنى
    final minOrderAmount = (coupon['minimum_order_amount'] as num?)?.toDouble();
    if (minOrderAmount != null && merchantSubtotal < minOrderAmount) {
      throw Exception(
        'الحد الأدنى لطلب $merchantName هو ${minOrderAmount.toStringAsFixed(2)} ج.م',
      );
    }

    // حساب الخصم
    double discount = _calculateCouponDiscount(
      coupon: coupon,
      couponType: couponType,
      orderAmount: merchantSubtotal,
      totalQuantity: totalQuantity,
      eligibleAmount: eligibleAmount,
    );

    // حفظ الكوبون المطبق
    setState(() {
      _appliedCoupon = coupon;
      _merchantDiscounts[merchantId] = discount;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تطبيق خصم ${discount.toStringAsFixed(2)} ج.م على منتجات $merchantName',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // تطبيق كوبون عام
  Future<void> _applyGlobalCoupon(
    Map<String, dynamic> coupon,
    CartProvider cartProvider,
  ) async {
    if (!mounted) return;

    final subtotal = cartProvider.subtotal;
    final couponType = coupon['coupon_type'] as String? ?? 'percentage';

    // ── Flash Sale: التحقق من ساعات التفعيل ──
    if (couponType == 'flash_sale') {
      final startH = coupon['active_hours_start'] as int?;
      final endH = coupon['active_hours_end'] as int?;
      if (startH != null && endH != null) {
        final nowHour = DateTime.now().hour;
        bool inRange;
        if (startH <= endH) {
          inRange = nowHour >= startH && nowHour < endH;
        } else {
          inRange = nowHour >= startH || nowHour < endH;
        }
        if (!inRange) {
          String formatHour(int h) {
            if (h == 0) return '12 ص';
            if (h < 12) return '$h ص';
            if (h == 12) return '12 م';
            return '${h - 12} م';
          }

          throw Exception(
            'هذا العرض متاح فقط من ${formatHour(startH)} إلى ${formatHour(endH)} ⚡',
          );
        }
      }
    }

    // ── Product Specific: فلتر المنتجات المؤهلة فقط ──
    double eligibleAmount = subtotal;
    if (couponType == 'product_specific') {
      final productIds = _parseProductIds(coupon['product_ids']);
      if (productIds.isNotEmpty) {
        eligibleAmount = 0;
        bool hasMatch = false;
        for (var item in cartProvider.cartItems) {
          final product = item['product'] as Map<String, dynamic>;
          if (productIds.contains(product['id'])) {
            eligibleAmount += (item['total_price'] as num).toDouble();
            hasMatch = true;
          }
        }
        if (!hasMatch) {
          throw Exception('لا توجد منتجات مؤهلة لهذا الكوبون في سلتك');
        }
      }
    }

    // عدد العناصر
    int totalQuantity = 0;
    for (var item in cartProvider.cartItems) {
      totalQuantity += (item['quantity'] as int?) ?? 1;
    }

    // التحقق من الحد الأدنى
    final minOrderAmount = (coupon['minimum_order_amount'] as num?)?.toDouble();
    if (minOrderAmount != null && subtotal < minOrderAmount) {
      throw Exception(
        'الحد الأدنى للطلب هو ${minOrderAmount.toStringAsFixed(2)} ج.م',
      );
    }

    // حساب الخصم
    double discount = _calculateCouponDiscount(
      coupon: coupon,
      couponType: couponType,
      orderAmount: subtotal,
      totalQuantity: totalQuantity,
      eligibleAmount: eligibleAmount,
    );

    // حفظ الكوبون المطبق
    setState(() {
      _appliedCoupon = coupon;
      _merchantDiscounts['global'] = discount;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تطبيق خصم ${discount.toStringAsFixed(2)} ج.م على طلبك',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── حساب الخصم حسب نوع الكوبون ──
  double _calculateCouponDiscount({
    required Map<String, dynamic> coupon,
    required String couponType,
    required double orderAmount,
    int totalQuantity = 1,
    double? eligibleAmount,
  }) {
    double discount = 0;
    final discountValue = (coupon['discount_value'] as num?)?.toDouble() ?? 0;
    final maxDiscount = (coupon['maximum_discount_amount'] as num?)?.toDouble();

    switch (couponType) {
      case 'percentage':
        discount = orderAmount * (discountValue / 100);
        break;
      case 'fixed_amount':
        discount = discountValue;
        break;
      case 'free_delivery':
        discount = 0; // يتم التعامل معه منفصلاً
        break;
      case 'product_specific':
        final base = eligibleAmount ?? orderAmount;
        discount = base * (discountValue / 100);
        break;
      case 'tiered_quantity':
        final tiers = _parseQuantityTiers(coupon['quantity_tiers']);
        double tierPercent = 0;
        for (final tier in tiers) {
          if (totalQuantity >= (tier['min_quantity'] as int? ?? 0)) {
            tierPercent = (tier['discount_percent'] as num?)?.toDouble() ?? 0;
          }
        }
        if (tierPercent > 0) {
          discount = orderAmount * (tierPercent / 100);
        }
        break;
      case 'flash_sale':
        discount = orderAmount * (discountValue / 100);
        break;
      default:
        discount = orderAmount * (discountValue / 100);
    }

    // تطبيق الحد الأقصى
    if (maxDiscount != null && discount > maxDiscount) {
      discount = maxDiscount;
    }

    return discount > orderAmount ? orderAmount : discount;
  }

  // ── تحليل product_ids من الاستجابة ──
  List<String> _parseProductIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // ── تحليل quantity_tiers من الاستجابة ──
  List<Map<String, dynamic>> _parseQuantityTiers(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .where((m) => m.isNotEmpty)
          .toList()
        ..sort(
          (a, b) => (a['min_quantity'] as int? ?? 0).compareTo(
            b['min_quantity'] as int? ?? 0,
          ),
        );
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList()..sort(
            (a, b) => (a['min_quantity'] as int? ?? 0).compareTo(
              b['min_quantity'] as int? ?? 0,
            ),
          );
        }
      } catch (_) {}
    }
    return [];
  }

  /// لصق كود الكوبون من الحافظة
  Future<void> _pasteCouponFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;

      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        setState(() {
          _couponController.text = clipboardData.text!.trim().toUpperCase();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم لصق الكوبون'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد نص في الحافظة'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل اللصق من الحافظة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // تحميل العناوين المحفوظة
  Future<void> _loadSavedAddresses() async {
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final userId = authProvider.currentUser?.id;

      if (userId == null) return;

      final response = await _supabase
          .from('addresses')
          .select()
          .eq('client_id', userId)
          .order('is_default', ascending: false);

      if (mounted) {
        setState(() {
          _savedAddresses = (response as List)
              .map((e) => AddressModel.fromMap(e))
              .toList();

          // اختيار العنوان الافتراضي تلقائياً
          if (_savedAddresses.isNotEmpty) {
            _selectedAddress = _savedAddresses.firstWhere(
              (addr) => addr.isDefault,
              orElse: () => _savedAddresses.first,
            );
          }
        });
      }
    } catch (e) {
      // يمكن إضافة رسالة خطأ هنا إذا لزم الأمر
    }
  }

  // عرض Bottom Sheet لاختيار العنوان
  void _showAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (scrollContext, scrollController) => SafeArea(
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // العنوان
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'العنوان',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // قائمة العناوين
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // زر إضافة عنوان جديد
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.blue),
                      ),
                      title: const Text(
                        '+ إضافة جديدة',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showAddAddressBottomSheet();
                      },
                    ),

                    const Divider(height: 32),

                    // العناوين المحفوظة
                    if (_savedAddresses.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'لا توجد عناوين محفوظة',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ..._savedAddresses.map(
                        (address) => _buildAddressCard(address),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء بطاقة العنوان
  Widget _buildAddressCard(AddressModel address) {
    final isSelected = _selectedAddress?.id == address.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.location_on,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
        title: Text(
          address.label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          _formatAddressForDisplay(address.address),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () async {
          // التحقق من جميع المتاجر قبل اختيار العنوان
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );
          final storesOutOfRange = await _getStoresOutOfRange(
            cartProvider,
            address,
          );

          if (storesOutOfRange.isNotEmpty) {
            // عرض رسالة تحذيرية
            if (!mounted) return;
            Navigator.pop(context); // إغلاق قائمة العناوين أولاً
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange[700],
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'تنبيه: متاجر خارج نطاق التوصيل',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العنوان المحدد: ${address.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAddressForDisplay(address.formattedAddress),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'المتاجر التالية لا توصل لهذا العنوان:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...storesOutOfRange.map(
                      (storeName) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.store, size: 16, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                storeName,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'يرجى اختيار عنوان آخر أو حذف المنتجات من المتاجر المذكورة من السلة.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            );
            return;
          }

          // جميع المتاجر ضمن النطاق - اختر العنوان
          if (mounted) {
            setState(() {
              _selectedAddress = address;
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // عرض Bottom Sheet لإدخال بيانات الشخص الآخر
  void _showReceiverBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              const Text(
                'بيانات المستلم',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // رسالة التنبيه
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber[900],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'يتم الاتصال بالمستلم الآخر في حالة عدم رد المستخدم الأساسي أو وجود مشكلة في التواصل معه',
                        style: TextStyle(
                          color: Colors.amber[900],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // حقل الاسم
              TextField(
                controller: _receiverNameController,
                focusNode: _receiverNameFocus,
                decoration: InputDecoration(
                  labelText: 'اسم المستلم',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // حقل رقم الهاتف
              TextField(
                controller: _receiverPhoneController,
                focusNode: _receiverPhoneFocus,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '', // إخفاء العداد
                ),
              ),
              const SizedBox(height: 24),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // التحقق من الاسم
                    if (_receiverNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال اسم المستلم'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      _receiverNameFocus.requestFocus();
                      return;
                    }

                    // التحقق من رقم الهاتف
                    final phoneValidation = Validators.validatePhone(
                      _receiverPhoneController.text.trim(),
                    );
                    if (phoneValidation != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(phoneValidation),
                          backgroundColor: Colors.red,
                        ),
                      );
                      _receiverPhoneFocus.requestFocus();
                      return;
                    }

                    setState(() {
                      _isReceiverAccountOwner = false;
                    });
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'حفظ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// مسح حقول نموذج العنوان
  void _clearAddressForm() {
    _labelController.clear();
    _governorateController.clear();
    _cityController.clear();
    _areaController.clear();
    _streetController.clear();
    _buildingNumberController.clear();
    _floorNumberController.clear();
    _apartmentNumberController.clear();
    _landmarkController.clear();
    _addressNotesController.clear();
    _newAddressPosition = null;
  }

  void _scrollToKey(GlobalKey key) {
    final currentContext = key.currentContext;
    if (currentContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  /// عرض BottomSheet لإضافة عنوان جديد
  void _showAddAddressBottomSheet() {
    _clearAddressForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (scrollContext, scrollController) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // العنوان
                  const Text(
                    'إضافة عنوان جديد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // نموذج العنوان
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: StatefulBuilder(
                        builder: (context, setInnerState) {
                          final labels = [
                            {'name': 'المنزل', 'icon': Icons.home_rounded},
                            {'name': 'العمل', 'icon': Icons.work_rounded},
                            {'name': 'أخرى', 'icon': Icons.label_rounded},
                          ];

                          final currentLabel = _labelController.text.trim();
                          final bool isPredefined = labels.any(
                            (l) => l['name'] == currentLabel,
                          );
                          final String selectedType = currentLabel.isEmpty
                              ? 'المنزل'
                              : (isPredefined ? currentLabel : 'أخرى');

                          if (currentLabel.isEmpty) {
                            _labelController.text = 'المنزل';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'نوع العنوان',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: labels.map((l) {
                                  final bool isSelected =
                                      selectedType == l['name'];
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _AddressTypeChip(
                                        label: l['name'] as String,
                                        icon: l['icon'] as IconData,
                                        isSelected: isSelected,
                                        onTap: () {
                                          setInnerState(() {
                                            _labelController.text =
                                                l['name'] as String;
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              if (selectedType == 'أخرى') ...[
                                TextFormField(
                                  controller: _labelController,
                                  decoration: InputDecoration(
                                    labelText: 'اسم العنوان',
                                    hintText: 'مثال: منزل العائلة، النادي...',
                                    prefixIcon: const Icon(Icons.label_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'الرجاء إدخال اسم للعنوان';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              AddressFormSection(
                                formKey: _addressFormKey,
                                formType: AddressFormType.residential,
                                governorateController: _governorateController,
                                cityController: _cityController,
                                areaController: _areaController,
                                streetController: _streetController,
                                landmarkController: _landmarkController,
                                labelController: null,
                                buildingNumberController:
                                    _buildingNumberController,
                                floorNumberController: _floorNumberController,
                                apartmentNumberController:
                                    _apartmentNumberController,
                                notesController: _addressNotesController,
                                governorateFocus: _governorateFocus,
                                cityFocus: _cityFocus,
                                streetFocus: _streetFocus,
                                position: _newAddressPosition,
                                requirePosition: true,
                                onPickFromMap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdvancedMapScreen(
                                        userType: MapUserType.customer,
                                        actionType: MapActionType.pickLocation,
                                        initialPosition: _newAddressPosition,
                                        onLocationSelectedDetails: (details) {
                                          setSheetState(() {
                                            _newAddressPosition =
                                                details.position;
                                            final components =
                                                AddressService.extractComponentsFromDetails(
                                                  details,
                                                );
                                            _governorateController.text =
                                                components['governorate'] ?? '';
                                            _cityController.text =
                                                components['city'] ?? '';
                                            if ((components['area'] ?? '')
                                                .isNotEmpty) {
                                              _areaController.text =
                                                  components['area']!;
                                            }
                                            if ((components['street'] ?? '')
                                                .isNotEmpty) {
                                              _streetController.text =
                                                  components['street']!;
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _saveNewAddress(sheetContext),
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ العنوان'),
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

  /// حفظ العنوان الجديد
  Future<void> _saveNewAddress(BuildContext sheetContext) async {
    // التحقق من صحة النموذج
    if (!_addressFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // التحقق من اختيار الموقع
    if (_newAddressPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الموقع من الخريطة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = _supabase.auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول لحفظ العنوان'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // بناء العنوان الكامل
      final addressParts = [
        _streetController.text.trim(),
        if (_areaController.text.trim().isNotEmpty) _areaController.text.trim(),
        _cityController.text.trim(),
        _governorateController.text.trim(),
      ];
      addressParts.join('، ');

      final isFirstAddress = _savedAddresses.isEmpty;

      final addressData = {
        'client_id': userId,
        'label': _labelController.text.trim().isEmpty
            ? 'عنوان جديد'
            : _labelController.text.trim(),
        'governorate': _governorateController.text.trim(),
        'city': _cityController.text.trim(),
        'area': _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        'street': _streetController.text.trim(),
        'building_number': _buildingNumberController.text.trim().isEmpty
            ? null
            : _buildingNumberController.text.trim(),
        'floor_number': _floorNumberController.text.trim().isEmpty
            ? null
            : _floorNumberController.text.trim(),
        'apartment_number': _apartmentNumberController.text.trim().isEmpty
            ? null
            : _apartmentNumberController.text.trim(),
        'landmark': _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        'latitude': _newAddressPosition!.latitude,
        'longitude': _newAddressPosition!.longitude,
        'is_default': isFirstAddress,
      };

      final newAddress = await AddressService.upsertAddress(
        client: _supabase,
        userId: userId,
        addressData: addressData,
      );

      if (!mounted) return;

      setState(() {
        _selectedAddress = newAddress;
        _savedAddresses.insert(0, newAddress);
      });

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ العنوان بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.error('❌ فشل حفظ العنوان', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ العنوان. حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _couponController.dispose();
    _userPhoneController.dispose(); // رقم هاتف المستخدم الرئيسي
    _userPhoneFocus.dispose();
    _receiverNameFocus.dispose();
    _receiverPhoneFocus.dispose();
    // Address form controllers
    _labelController.dispose();
    _governorateController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _floorNumberController.dispose();
    _apartmentNumberController.dispose();
    _landmarkController.dispose();
    _addressNotesController.dispose();
    // Focus nodes
    _governorateFocus.dispose();
    _cityFocus.dispose();
    _streetFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('عملية الدفع'), centerTitle: true),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // قسم العنوان
                      Text(
                        'العنوان',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // بطاقة العنوان
                      InkWell(
                        onTap: _showAddressBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          key: _addressSectionKey,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _selectedAddress != null
                                              ? 'توصيل إلى'
                                              : 'اختر عنوان التوصيل',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedAddress != null
                                          ? _formatAddressForDisplay(
                                              _selectedAddress!.shortAddress,
                                            )
                                          : 'اضغط لاختيار أو إضافة عنوان',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // قسم رقم الهاتف
                      _buildPhoneSection(theme, colorScheme),

                      const SizedBox(height: 24),

                      // قسم من يستلم الطلب
                      Text(
                        'مين بيستلم هذا الطلب؟',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // خيار 1: صاحب الحساب
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isReceiverAccountOwner = true;
                            _receiverNameController.clear();
                            _receiverPhoneController.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isReceiverAccountOwner
                                ? colorScheme.primaryContainer.withValues(
                                    alpha: 0.3,
                                  )
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isReceiverAccountOwner
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.3),
                              width: _isReceiverAccountOwner ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isReceiverAccountOwner
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : Colors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: _isReceiverAccountOwner
                                      ? colorScheme.primary
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'صاحب الحساب',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _isReceiverAccountOwner
                                                ? colorScheme.onSurface
                                                : Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Provider.of<SupabaseProvider>(
                                            context,
                                          ).currentUserProfile?.fullName ??
                                          'المستخدم',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: _isReceiverAccountOwner
                                                ? colorScheme.onSurface
                                                      .withValues(alpha: 0.7)
                                                : Colors.grey.withValues(
                                                    alpha: 0.5,
                                                  ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isReceiverAccountOwner)
                                Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // خيار 2: شخص آخر
                      InkWell(
                        onTap: _showReceiverBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: !_isReceiverAccountOwner
                                ? colorScheme.primaryContainer.withValues(
                                    alpha: 0.3,
                                  )
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isReceiverAccountOwner
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.3),
                              width: !_isReceiverAccountOwner ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: !_isReceiverAccountOwner
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : Colors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  color: !_isReceiverAccountOwner
                                      ? colorScheme.primary
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'شخص آخر',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: !_isReceiverAccountOwner
                                                ? colorScheme.onSurface
                                                : Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      !_isReceiverAccountOwner &&
                                              _receiverNameController
                                                  .text
                                                  .isNotEmpty
                                          ? '${_receiverNameController.text} - ${_receiverPhoneController.text}'
                                          : 'اضغط لإدخال البيانات',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: !_isReceiverAccountOwner
                                                ? colorScheme.onSurface
                                                      .withValues(alpha: 0.7)
                                                : Colors.grey.withValues(
                                                    alpha: 0.5,
                                                  ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                !_isReceiverAccountOwner
                                    ? Icons.check_circle
                                    : Icons.arrow_forward_ios,
                                color: !_isReceiverAccountOwner
                                    ? colorScheme.primary
                                    : Colors.grey,
                                size: !_isReceiverAccountOwner ? 24 : 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // قسم طريقة الدفع
                      Text(
                        'طرق الدفع',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // خيار الدفع النقدي
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الدفع نقداً عند الاستلام',
                                    style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قد تطبق رسوم إضافية',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // قسم الكوبون
                      _buildCouponSection(context, cartProvider),

                      const SizedBox(height: 24),

                      // قسم الملاحظات
                      _buildNotesSection(context),

                      const SizedBox(height: 24),

                      // ملخص الطلب
                      _buildOrderSummary(cartProvider),

                      const SizedBox(height: 120), // مساحة للزر السفلي
                    ],
                  ),
                ),
              ),

              // زر اسحب للطلب
              _buildSwipeToConfirmButton(cartProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cartProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Text(
            'ملخص الطلب',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // قائمة المنتجات بصورة مصغرة
          ...cartProvider.cartItems.map((item) {
            final product = item['product'] as Map<String, dynamic>?;
            if (product == null) return const SizedBox.shrink();

            final name = product['name'] as String? ?? 'منتج';
            final quantity = item['quantity'] as int;
            final price = (product['price'] as num?)?.toDouble() ?? 0.0;
            final total = price * quantity;
            final imageUrl = product['image_url'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // صورة المنتج المصغرة
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: colorScheme.surfaceContainerHighest,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported,
                                  size: 24,
                                  color: colorScheme.outline,
                                );
                              },
                            )
                          : Icon(
                              Icons.shopping_bag,
                              size: 24,
                              color: colorScheme.outline,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // تفاصيل المنتج
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item['selected_options'] != null &&
                            (item['selected_options'] as Map).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              (item['selected_options'] as Map).entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(' | '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '$quantity × ${price.toStringAsFixed(2)} ج.م',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // السعر الإجمالي
                  Text(
                    '${total.toStringAsFixed(2)} ج.م',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          Divider(color: colorScheme.outline.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 12),

          // المجموع الفرعي
          _buildSummaryRow(
            'المجموع الفرعي',
            cartProvider.subtotal,
            colorScheme,
          ),
          const SizedBox(height: 12),

          // رسوم التوصيل
          _buildDeliveryFeesSection(cartProvider, colorScheme, theme),

          // الخصم إن وجد
          if (_totalDiscount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'الخصم',
              -_totalDiscount,
              colorScheme,
              valueColor: Colors.green,
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: colorScheme.outline.withValues(alpha: 0.3),
              height: 1,
            ),
          ),

          // الإجمالي النهائي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإجمالي',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_totalDiscount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'وفرت ${_totalDiscount.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${(cartProvider.subtotal + _calculateTotalDeliveryFee(cartProvider) - _totalDiscount).toStringAsFixed(2)} ج.م',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء قسم رسوم التوصيل مع توضيح الأنظمة
  Widget _buildDeliveryFeesSection(
    CartProvider cartProvider,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    // جمع تفاصيل كل متجر مع رسوم التوصيل
    final merchantStoreDetails = <Map<String, dynamic>>[];
    final appDeliveryCount = <String, int>{};
    final processedStores = <String>{};

    // تحليل كل منتج في السلة
    for (var item in cartProvider.cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product != null && product['stores'] != null) {
        final store = product['stores'] as Map<String, dynamic>;
        final storeId = store['id'] as String? ?? '';
        final storeName = store['name'] as String? ?? 'المتجر';

        // تجنب إضافة نفس المتجر مرتين
        if (processedStores.contains(storeId)) continue;
        processedStores.add(storeId);

        // الحقول الصحيحة: delivery_mode
        final deliveryMode = store['delivery_mode'] as String? ?? 'store';

        if (deliveryMode == 'store') {
          // المتاجر التي توصل بنفسها
          final fee = (store['delivery_fee'] as num?)?.toDouble() ?? 0.0;
          merchantStoreDetails.add({
            'name': storeName,
            'fee': fee,
            'mode': 'store',
          });
        } else {
          // متاجر توصيل التطبيق - نعد كم متجر
          appDeliveryCount[storeId] = 1;
        }
      }
    }

    // الحصول على رسوم التوصيل من إعدادات التطبيق/المنطقة
    final matchedZone = _resolveDeliveryZone(_selectedAddress);
    final appDeliveryFee = appDeliveryCount.isNotEmpty
        ? _getAppDeliveryFeeBySelectedZone()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عرض تفاصيل المتاجر التي توصل بنفسها
        ...merchantStoreDetails.map((storeDetail) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSummaryRow(
              'رسوم توصيل ${storeDetail['name']}',
              storeDetail['fee'],
              colorScheme,
            ),
          );
        }),

        // عرض رسوم توصيل التطبيق (بدون أسماء المتاجر)
        if (appDeliveryFee > 0) ...[
          if (merchantStoreDetails.isNotEmpty) const SizedBox(height: 8),
          _buildSummaryRow('رسوم التوصيل', appDeliveryFee, colorScheme),
          if (matchedZone != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'منطقة التسعير: ${matchedZone.scopeLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],

        // (تم حذف عرض "إجمالي رسوم التوصيل" حسب المطلوب)
      ],
    );
  }

  /// بناء صف في ملخص الطلب
  Widget _buildSummaryRow(
    String label,
    double value,
    ColorScheme colorScheme, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // زر اسحب للطلب
  Widget _buildSwipeToConfirmButton(CartProvider cartProvider) {
    return FutureBuilder<List<String>>(
      future: _getStoresOutOfRange(cartProvider, _selectedAddress),
      builder: (context, snapshot) {
        final storesOutOfRange = snapshot.data ?? [];
        final bool isOutOfRange = storesOutOfRange.isNotEmpty;
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر التحميل
              if (isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
                      const Text('جاري التحقق من نطاق التوصيل...'),
                    ],
                  ),
                ),
              ],

              // رسالة تحذيرية إذا كان العنوان خارج النطاق
              if (isOutOfRange) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'عنوانك خارج نطاق التوصيل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المتاجر خارج النطاق: ${storesOutOfRange.join("، ")}',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'يرجى اختيار عنوان آخر أو التواصل مع المتجر',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // عدد المنتجات والسعر الإجمالي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cartProvider.cartItems.length} منتجات',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(cartProvider.subtotal + _calculateTotalDeliveryFee(cartProvider) - _totalDiscount).toStringAsFixed(2)} ج.م.',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // زر السحب - معطل إذا كان خارج النطاق
              GestureDetector(
                onHorizontalDragUpdate: isOutOfRange
                    ? null
                    : (details) {
                        setState(() {
                          // السحب من اليسار لليمين
                          _swipeValue += details.primaryDelta! / 300;
                          _swipeValue = _swipeValue.clamp(0.0, 1.0);
                        });
                      },
                onHorizontalDragEnd: isOutOfRange
                    ? null
                    : (details) {
                        if (_swipeValue >= _swipeThreshold) {
                          _submitOrder(context);
                        } else {
                          setState(() {
                            _swipeValue = 0.0;
                          });
                        }
                      },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: isOutOfRange
                        ? Colors.grey[400] // رمادي إذا معطل
                        : const Color(0xFF0D6EFD),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Stack(
                    children: [
                      // الخلفية
                      Center(
                        child: Text(
                          isOutOfRange
                              ? '🚫 خارج نطاق التوصيل'
                              : (_swipeValue < _swipeThreshold
                                    ? '→ اسحب للطلب'
                                    : 'جاري المعالجة...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // الزر المتحرك - مخفي إذا معطل
                      if (!isOutOfRange)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          left:
                              _swipeValue *
                              (MediaQuery.of(context).size.width - 120),
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF0D6EFD),
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
      },
    );
  }

  /// بناء قسم كوبون الخصم
  Widget _buildCouponSection(BuildContext context, CartProvider cartProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'هل لديك كوبون خصم؟',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // إذا تم تطبيق كوبون
        if (_appliedCoupon != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كوبون: ${_appliedCoupon!['code']}',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _appliedCoupon!['merchant_id'] != null
                            ? 'خصم على منتجات ${_appliedCoupon!['merchants']?['name'] ?? 'تاجر محدد'}'
                            : 'خصم على كل المنتجات',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'وفرت: ${_totalDiscount.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red[700]),
                  onPressed: () {
                    setState(() {
                      _appliedCoupon = null;
                      _merchantDiscounts.clear();
                      _couponController.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إلغاء الكوبون'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  tooltip: 'إلغاء',
                ),
              ],
            ),
          ),
        ] else ...[
          // حقل إدخال الكوبون
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    hintText: 'أدخل رمز الكوبون',
                    prefixIcon: Icon(
                      Icons.local_offer,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.content_paste_rounded,
                        color: colorScheme.primary,
                      ),
                      tooltip: 'لصق',
                      onPressed: _isApplyingCoupon
                          ? null
                          : _pasteCouponFromClipboard,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_isApplyingCoupon,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isApplyingCoupon
                    ? null
                    : () => _applyCoupon(context, cartProvider),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isApplyingCoupon
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: AppShimmer.wrap(
                          context,
                          child: AppShimmer.circle(context, size: 20),
                        ),
                      )
                    : const Text('تطبيق'),
              ),
            ],
          ),

          // نصيحة
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الكوبونات الخاصة بتاجر معين تطبق فقط على منتجاته',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// بناء قسم رقم الهاتف
  Widget _buildPhoneSection(ThemeData theme, ColorScheme colorScheme) {
    final authProvider = Provider.of<SupabaseProvider>(context);
    final savedPhone = authProvider.currentUserProfile?.phone;
    final hasPhone = savedPhone != null && savedPhone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رقم الهاتف',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (hasPhone && !_isEditingPhone)
          // عرض رقم الهاتف المحفوظ مع زر التعديل
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.phone, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رقم التواصل',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        savedPhone,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingPhone = true;
                      _userPhoneController.text = savedPhone;
                    });
                    _userPhoneFocus.requestFocus();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'تعديل رقم الهاتف',
                  color: colorScheme.primary,
                ),
              ],
            ),
          )
        else if (_isEditingPhone || !hasPhone)
          // حقل إدخال أو تعديل رقم الهاتف
          Container(
            key: _phoneSectionKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEditingPhone
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEditingPhone
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.orange[300]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditingPhone)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'رقم الهاتف مطلوب لإتمام الطلب',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.edit_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تعديل رقم الهاتف',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userPhoneController,
                  focusNode: _userPhoneFocus,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '*********01',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    prefixText: '+20 ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isEditingPhone
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : Colors.orange[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    counterText: '', // إخفاء العداد
                  ),
                  onChanged: (value) {
                    setState(() {}); // تحديث الواجهة
                  },
                ),
                const SizedBox(height: 12),
                if (_isEditingPhone)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditingPhone = false;
                              _userPhoneController.clear();
                              _loadUserPhone(); // إعادة تحميل الرقم المحفوظ
                            });
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('إلغاء'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final phone = _userPhoneController.text.trim();
                            if (phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى إدخال رقم الهاتف'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final validation = Validators.validatePhone(phone);
                            if (validation != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(validation),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // حفظ رقم الهاتف
                            final success = await _savePhoneToProfile();
                            if (success) {
                              setState(() {
                                _isEditingPhone = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حفظ رقم الهاتف بنجاح'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('فشل حفظ رقم الهاتف'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('حفظ'),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'سيتم حفظ رقم الهاتف في حسابك للطلبات القادمة',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// بناء قسم الملاحظات الإضافية
  Widget _buildNotesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملاحظات إضافية',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'هل تود أن تخبرنا أي شيء آخر؟',
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.edit_note, color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Future<void> _submitOrder(BuildContext context) async {
    // التقاط المراجع قبل أي async gaps
    final navState = NavigationService.navigatorKey.currentState;
    final navContext = NavigationService.navigatorKey.currentContext;
    final messenger = navContext != null
        ? ScaffoldMessenger.of(navContext)
        : null;
    final fallbackMessenger = ScaffoldMessenger.of(context);

    // التقاط الـ providers قبل أي async operations
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (_selectedAddress == null) {
      (messenger ?? fallbackMessenger).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار عنوان التوصيل'),
          backgroundColor: Colors.red,
        ),
      );
      _scrollToKey(_addressSectionKey);
      setState(() => _swipeValue = 0.0);
      return;
    }

    // التحقق من رقم الهاتف
    final savedPhone = authProvider.currentUserProfile?.phone;
    final hasPhoneSaved = savedPhone != null && savedPhone.isNotEmpty;

    if (!hasPhoneSaved) {
      // رقم الهاتف غير محفوظ - يجب إدخاله
      final enteredPhone = _userPhoneController.text.trim();
      if (enteredPhone.isEmpty) {
        (messenger ?? fallbackMessenger).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال رقم الهاتف'),
            backgroundColor: Colors.red,
          ),
        );
        _scrollToKey(_phoneSectionKey);
        _userPhoneFocus.requestFocus();
        setState(() => _swipeValue = 0.0);
        return;
      }

      // التحقق من صحة رقم الهاتف
      final phoneValidation = Validators.validatePhone(enteredPhone);
      if (phoneValidation != null) {
        (messenger ?? fallbackMessenger).showSnackBar(
          SnackBar(content: Text(phoneValidation), backgroundColor: Colors.red),
        );
        _scrollToKey(_phoneSectionKey);
        _userPhoneFocus.requestFocus();
        setState(() => _swipeValue = 0.0);
        return;
      }

      // حفظ رقم الهاتف في البروفايل
      (messenger ?? fallbackMessenger).showSnackBar(
        const SnackBar(
          content: Text('جاري حفظ رقم الهاتف...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );

      final phoneSaved = await _savePhoneToProfile();
      if (!mounted) return;

      if (!phoneSaved) {
        (messenger ?? fallbackMessenger).showSnackBar(
          const SnackBar(
            content: Text('فشل حفظ رقم الهاتف. حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _swipeValue = 0.0);
        return;
      }
    }

    if (!mounted) return;

    try {
      if (cartProvider.cartItems.isEmpty) {
        (messenger ?? fallbackMessenger).showSnackBar(
          const SnackBar(
            content: Text('السلة فارغة'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _swipeValue = 0.0);
        return;
      }

      // التحقق النهائي: جميع المتاجر يجب أن تكون ضمن نطاق التوصيل
      final storesOutOfRange = await _getStoresOutOfRange(
        cartProvider,
        _selectedAddress!,
      );

      if (storesOutOfRange.isNotEmpty) {
        // عرض رسالة خطأ مفصلة
        if (!mounted) return;
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'خارج نطاق التوصيل',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عنوان التوصيل: ${_selectedAddress!.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAddressForDisplay(_selectedAddress!.formattedAddress),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'المتاجر التالية لا توصل لهذا العنوان:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...storesOutOfRange.map(
                  (storeName) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            storeName,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Text(
                    'لإتمام الطلب، يرجى:\n'
                    '• اختيار عنوان توصيل آخر، أو\n'
                    '• حذف المنتجات من المتاجر المذكورة من السلة',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        setState(() => _swipeValue = 0.0);
        return;
      }

      final orderGroupId = const Uuid().v4();

      // تجميع العناصر حسب المتجر
      Map<String, List<Map<String, dynamic>>> itemsByStore = {};

      for (var item in cartProvider.cartItems) {
        final product = item['product'] as Map<String, dynamic>?;
        final storeId = (item['store_id'] ?? product?['store_id']) as String?;
        if (storeId == null) {
          throw Exception('تعذر تحديد المتجر لأحد عناصر السلة');
        }
        itemsByStore.putIfAbsent(storeId, () => []);
        itemsByStore[storeId]!.add(item);
      }

      // إنشاء طلب لكل متجر
      for (var entry in itemsByStore.entries) {
        String storeId = entry.key;
        List<Map<String, dynamic>> storeItems = entry.value;

        // حساب إجمالي المتجر
        double storeSubtotal = 0;
        Map<String, dynamic>? storeData;
        for (var item in storeItems) {
          storeSubtotal += (item['total_price'] as num).toDouble();
          if (storeData == null) {
            final product = item['product'] as Map<String, dynamic>;
            storeData = product['stores'] as Map<String, dynamic>;
          }
        }

        // حساب رسوم التوصيل لهذا المتجر
        double deliveryFee = 0.0;
        if (storeData != null) {
          final deliveryMode = storeData['delivery_mode'] as String? ?? 'store';
          if (deliveryMode == 'store') {
            deliveryFee =
                (storeData['delivery_fee'] as num?)?.toDouble() ?? 0.0;
          } else {
            deliveryFee = _getAppDeliveryFeeBySelectedZone();
          }
        }

        double cashFee = 0.0; // إزالة رسوم الكاش لأنها غير موجودة في السلة
        double taxAmount = 0.0; // إزالة الضريبة لأنها غير موجودة في السلة

        // إنشاء الطلب
        final order = OrderModel(
          id: '',
          clientId: authProvider.currentUser!.id,
          storeId: storeId,
          orderGroupId: orderGroupId,
          totalAmount: storeSubtotal + deliveryFee + cashFee + taxAmount,
          deliveryFee: deliveryFee,
          taxAmount: taxAmount,
          deliveryAddress: _formatAddressForDisplay(
            _selectedAddress!.formattedAddress,
          ),
          status: OrderStatus.pending,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.pending,
          createdAt: DateTime.now(),
        );

        String? newOrderId = await orderProvider.createOrder(order);
        // إضافة عناصر الطلب
        final orderItemsData = storeItems.map((item) {
          final product = item['product'] as Map<String, dynamic>?;
          final productId = item['product_id'] ?? product?['id'];
          final productName =
              item['product_name'] ?? product?['name'] ?? 'منتج';
          final productPriceRaw =
              item['product_price'] ?? product?['price'] ?? 0.0;
          final quantityRaw = item['quantity'] ?? 1;
          final productPrice = productPriceRaw is num
              ? productPriceRaw
              : double.tryParse(productPriceRaw.toString()) ?? 0.0;
          final quantity = quantityRaw is num
              ? quantityRaw
              : int.tryParse(quantityRaw.toString()) ?? 1;
          final totalPrice = item['total_price'] ?? productPrice * quantity;

          return {
            'order_id': newOrderId,
            'product_id': productId,
            'product_name': productName,
            'product_price': productPrice,
            'quantity': quantity,
            'total_price': totalPrice,
            'selected_options': item['selected_options'],
            'special_instructions': item['special_instructions'],
          };
        }).toList();

        await _supabase.from('order_items').insert(orderItemsData);
      }

      // مسح السلة
      await cartProvider.clearCart();

      if (!mounted) return;

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // الانتقال إلى صفحة تتبع طلب واحد (بدون واجهة مجموعة)
      final List<OrderModel> orders = await OrderService.getOrdersByGroupId(
        orderGroupId,
      );
      final firstOrder = orders.isNotEmpty ? orders.first : null;

      if (!context.mounted) return;

      final route = firstOrder == null
          ? MaterialPageRoute(builder: (_) => const OrderHistoryScreen())
          : MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(
                orderId: firstOrder.id,
                orderNumber: firstOrder.orderNumber,
              ),
            );

      if (navState != null) {
        navState.pushReplacement(route);
      } else {
        Navigator.pushReplacement(context, route);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ: $e';

        // رسالة خطأ مخصصة لمشكلة RLS
        if (e.toString().contains('row-level security')) {
          errorMessage = 'خطأ في الصلاحيات. يرجى التواصل مع الدعم الفني.';
        }

        (messenger ?? fallbackMessenger).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _swipeValue = 0.0);
      }
    }
  }
}

// Address Type Chip Widget
class _AddressTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
