import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/address_model.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/services/address_service.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/widgets/address/address_form_section.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';

// 📦 نموذج لبيانات العنوان - يجمع البيانات في عنوان واحد عند الحفظ
class _AddressFormData {
  String governorate = '';
  String city = '';
  String district = '';
  String street = '';
  String building = '';
  String floor = '';
  String apartment = '';
  String landmark = '';
  String label = '';

  void clear() {
    governorate = '';
    city = '';
    district = '';
    street = '';
    building = '';
    floor = '';
    apartment = '';
    landmark = '';
    label = '';
  }

  void loadFrom(AddressModel addressModel) {
    governorate = addressModel.governorate ?? '';
    city = addressModel.city;
    district = addressModel.area ?? '';
    street = addressModel.street;
    building = addressModel.buildingNumber ?? '';
    floor = addressModel.floorNumber ?? '';
    apartment = addressModel.apartmentNumber ?? '';
    landmark = addressModel.landmark ?? '';
    label = addressModel.label;
  }

  /// بناء العنوان المدمج من الأجزاء
  String buildFullAddress() {
    final parts = <String>[];

    if (governorate.trim().isNotEmpty) parts.add(governorate.trim());
    if (city.trim().isNotEmpty) parts.add(city.trim());
    if (district.trim().isNotEmpty) parts.add(district.trim());
    if (street.trim().isNotEmpty) parts.add(street.trim());

    // إضافة تفاصيل المبنى
    final buildingParts = <String>[];
    if (building.trim().isNotEmpty) {
      buildingParts.add('عمارة ${building.trim()}');
    }
    if (floor.trim().isNotEmpty) {
      buildingParts.add('الطابق ${floor.trim()}');
    }
    if (apartment.trim().isNotEmpty) {
      buildingParts.add('شقة ${apartment.trim()}');
    }

    if (buildingParts.isNotEmpty) {
      parts.add(buildingParts.join(' - '));
    }

    return parts.join('، ');
  }

  Map<String, dynamic> toMap(
    String userId,
    String label,
    LatLng? position,
    bool isDefault,
  ) {
    return {
      'client_id': userId,
      'label': label,
      'governorate': governorate.trim().isEmpty ? null : governorate.trim(),
      'city': city.trim(),
      'area': district.trim().isEmpty ? null : district.trim(),
      'street': street.trim(),
      'building_number': building.trim().isEmpty ? null : building.trim(),
      'floor_number': floor.trim().isEmpty ? null : floor.trim(),
      'apartment_number': apartment.trim().isEmpty ? null : apartment.trim(),
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'landmark': landmark.trim().isNotEmpty ? landmark.trim() : null,
      'is_default': isDefault,
    };
  }
}

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen>
    with AutomaticKeepAliveClientMixin {
  // 🎯 استخدام نموذج موحد بدلاً من 9 controllers
  final _formData = _AddressFormData();
  List<DeliveryZonePricingModel> _ownerZones = <DeliveryZonePricingModel>[];

  // ✅ فورم عام للعناوين + الوكيشن (validators + map)
  final _addressFormKey = GlobalKey<FormState>();
  final _governorateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  final _governorateFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _streetFocus = FocusNode();

  // 🔄 لأن TextFormField(initialValue) لا يعيد التزامن بعد أول build
  // نستخدم revision لإجبار إعادة إنشاء الحقول عند تحميل/مسح البيانات.
  int _formRevision = 0;

  GoogleMapController? _mapController;

  LatLng? selectedPosition;
  bool isLoadingLocation = false;
  bool isSavingAddress = false;
  String selectedAddressType = 'المنزل';
  bool saveAsDefault = true;
  String? currentEditingAddressId;

  // 💾 Cache للعناوين المحملة
  List<AddressModel>? _cachedAddresses;
  DateTime? _lastAddressLoadTime;
  static const _cacheDuration = Duration(minutes: 5);

  // 🔄 Retry logic (used in _loadAddressesWithRetry)
  static const _maxRetries = 3;

  // 🔧 AutomaticKeepAliveClientMixin - للحفاظ على حالة الصفحة
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('🏠 بدء AddressesScreen');

    _syncControllersFromFormData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOwnerZones();
      _loadDefaultAddress();
      _loadMapPickerData();
    });
  }

  Future<void> _loadOwnerZones() async {
    final zones = await DeliveryZonePricingService.getActiveZones();
    if (!mounted) return;

    setState(() {
      _ownerZones = zones;
    });
  }

  void _syncControllersFromFormData() {
    _governorateCtrl.text = _formData.governorate;
    _cityCtrl.text = _formData.city;
    _districtCtrl.text = _formData.district;
    _streetCtrl.text = _formData.street;
    _landmarkCtrl.text = _formData.landmark;
  }

  void _syncFormDataFromControllers() {
    _formData.governorate = _governorateCtrl.text;
    _formData.city = _cityCtrl.text;
    _formData.district = _districtCtrl.text;
    _formData.street = _streetCtrl.text;
    _formData.landmark = _landmarkCtrl.text;
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
      _formData.governorate = governorate;
      _governorateCtrl.text = governorate;

      final validCities = _ownerZones
          .where((z) => z.governorate.trim() == governorate)
          .map((z) => (z.city ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_cityCtrl.text.trim().isNotEmpty &&
          !validCities.contains(_cityCtrl.text.trim())) {
        _cityCtrl.clear();
        _formData.city = '';
      }

      _districtCtrl.clear();
      _formData.district = '';
    });
  }

  void _handleCitySelection(String city) {
    setState(() {
      _formData.city = city;
      _cityCtrl.text = city;

      final validAreas = _ownerZones
          .where(
            (z) =>
                z.governorate.trim() == _governorateCtrl.text.trim() &&
                (z.city ?? '').trim() == city,
          )
          .map((z) => (z.area ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toSet();

      if (_districtCtrl.text.trim().isNotEmpty &&
          !validAreas.contains(_districtCtrl.text.trim())) {
        _districtCtrl.clear();
        _formData.district = '';
      }
    });
  }

  /// تحميل البيانات المُرسلة من AdvancedMapScreen
  void _loadMapPickerData() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args != null && args is Map) {
      AppLogger.info('📍 تحميل بيانات من AdvancedMap: $args');

      setState(() {
        if (args['governorate'] != null) {
          _formData.governorate = args['governorate'];
          AppLogger.info('✅ المحافظة: ${args['governorate']}');
        }
        if (args['city'] != null) {
          _formData.city = args['city'];
          AppLogger.info('✅ المركز: ${args['city']}');
        }

        final argStreet = (args['street'] as String?)?.trim();
        final argDistrict = (args['district'] as String?)?.trim();

        if (argStreet != null && argStreet.isNotEmpty) {
          _formData.street = argStreet;
          AppLogger.info('✅ الشارع (مُهيكل): $argStreet');
        }

        if (argDistrict != null && argDistrict.isNotEmpty) {
          _formData.district = argDistrict;
          AppLogger.info('✅ القرية/الحي (مُهيكل): $argDistrict');
        }

        if (args['address'] != null) {
          final fullAddress = (args['address'] as String).trim();
          AppLogger.info('✅ العنوان الكامل: $fullAddress');

          if (_formData.street.trim().isEmpty) {
            final street = _extractStreetFromAddress(fullAddress);
            if (street.isNotEmpty) {
              _formData.street = street;
              AppLogger.info('✅ الشارع: $street');
            }
          }

          if (_formData.district.trim().isEmpty) {
            final district = _extractDistrictFromAddress(
              fullAddress,
              city: _formData.city,
              governorate: _formData.governorate,
            );
            if (district.isNotEmpty) {
              _formData.district = district;
              AppLogger.info('✅ القرية/الحي: $district');
            }
          }
        }

        final pos = args['position'];
        if (pos is LatLng) {
          selectedPosition = pos;
          AppLogger.info('✅ تم تحديد الموقع: $selectedPosition');
        }

        _syncControllersFromFormData();
        _formRevision++;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _mapController != null && selectedPosition != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(selectedPosition!, 16),
          );
          AppLogger.info('📍 تم تحريك الكاميرا للموقع');
        }
      });
    }
  }

  /// Check if a string is a Plus Code (e.g., "7PPR+J3J")
  bool _isPlusCode(String text) {
    final plusCodePattern = RegExp(
      r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,3}$',
      caseSensitive: false,
    );
    return plusCodePattern.hasMatch(text.trim());
  }

  /// تحقق إذا كان النصان متشابهان (كامل أو جزئي)
  bool _isDuplicate(String? a, String? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return false;
    final aCanon = _canonicalForDedup(a);
    final bCanon = _canonicalForDedup(b);
    return aCanon == bCanon ||
        aCanon.contains(bCanon) ||
        bCanon.contains(aCanon);
  }

  /// تنظيف النص للمقارنة
  String _canonicalForDedup(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll('\u0640', '');
    s = s
        .replaceFirst(RegExp(r'^\s*محافظة\s+'), '')
        .replaceFirst(RegExp(r'^\s*مركز\s+'), '')
        .replaceFirst(RegExp(r'^\s*مدينة\s+'), '')
        .replaceFirst(RegExp(r'^\s*قرية\s+'), '')
        .replaceFirst(RegExp(r'^\s*حي\s+'), '');
    s = s
        .replaceAll(RegExp(r'[\-–—‑]+'), ' ')
        .replaceAll(RegExp(r'\s*(،|,)\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return s;
  }

  bool _looksAdministrative(String part) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return true;

    final lower = trimmed.toLowerCase();
    return trimmed.startsWith('محافظة') ||
        trimmed.startsWith('مركز') ||
        trimmed.startsWith('قرية') ||
        trimmed.startsWith('مدينة') ||
        trimmed == 'مصر' ||
        lower == 'egypt';
  }

  String _extractStreetFromAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split(RegExp(r'[،,]'));
    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      if (_isPlusCode(part)) continue;
      if (_looksAdministrative(part)) continue;
      return part;
    }
    return parts.first.trim();
  }

  String _extractDistrictFromAddress(
    String address, {
    required String city,
    required String governorate,
  }) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split(RegExp(r'[،,]'));
    final street = _extractStreetFromAddress(address);

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      if (_isPlusCode(part)) continue;
      if (_looksAdministrative(part)) continue;
      if (part == street) continue;
      if (city.trim().isNotEmpty && part == city.trim()) continue;
      if (governorate.trim().isNotEmpty && part == governorate.trim()) continue;

      return part;
    }

    return '';
  }

  /// 🔄 تحميل العناوين مع retry logic و caching
  Future<List<AddressModel>> _loadAddressesWithRetry(
    String userId, {
    int retryCount = 0,
  }) async {
    // ✅ التحقق من الـ cache أولاً
    if (_cachedAddresses != null && _lastAddressLoadTime != null) {
      final cacheAge = DateTime.now().difference(_lastAddressLoadTime!);
      if (cacheAge < _cacheDuration) {
        AppLogger.info(
          '📦 استخدام العناوين من الـ cache (عمر: ${cacheAge.inSeconds}s)',
        );
        return _cachedAddresses!;
      }
    }

    try {
      AppLogger.info('🔄 تحميل العناوين من السيرفر (محاولة ${retryCount + 1})');

      final response = await Supabase.instance.client
          .from('addresses')
          .select()
          .eq('client_id', userId)
          .order('is_default', ascending: false)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال'),
          );

      final addresses = (response as List)
          .map((data) => AddressModel.fromMap(data))
          .toList();

      // ✅ حفظ في الـ cache
      _cachedAddresses = addresses;
      _lastAddressLoadTime = DateTime.now();

      AppLogger.info('✅ تم تحميل ${addresses.length} عنوان');
      return addresses;
    } catch (e) {
      AppLogger.error('خطأ في تحميل العناوين (محاولة ${retryCount + 1})', e);

      // 🔄 Retry logic
      if (retryCount < _maxRetries) {
        AppLogger.info('⏳ إعادة المحاولة بعد ${(retryCount + 1) * 2} ثانية...');
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _loadAddressesWithRetry(userId, retryCount: retryCount + 1);
      }

      // إذا فشلت جميع المحاولات، استخدم الـ cache القديم إن وُجد
      if (_cachedAddresses != null) {
        AppLogger.warning('⚠️ استخدام العناوين من الـ cache القديم');
        return _cachedAddresses!;
      }

      rethrow;
    }
  }

  Future<void> _showSavedAddresses() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.login_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('يرجى تسجيل الدخول أولاً'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // 🚀 استخدام الدالة المحسّنة مع retry و cache
      final addresses = await _loadAddressesWithRetry(userId);

      if (!mounted) return;

      if (addresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.folder_off_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('لا توجد عناوين محفوظة'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show bottom sheet with addresses
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        useSafeArea: true,
        builder: (context) => _AddressListBottomSheet(
          addresses: addresses,
          onAddressSelected: (address) {
            AppLogger.info('✅ اختيار عنوان: ${address.label}');
            _loadAddressData(address);
            Navigator.pop(context);
          },
          onAddressDeleted: (addressId) async {
            await _deleteAddress(addressId);
            _cachedAddresses = null; // ❌ إلغاء الـ cache
            if (context.mounted) Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _showSavedAddresses();
            });
          },
          onSetDefault: (addressId) async {
            await _setAsDefault(addressId);
            _cachedAddresses = null; // ❌ إلغاء الـ cache
            if (context.mounted) Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _showSavedAddresses();
            });
          },
        ),
      );
    } catch (e) {
      AppLogger.error('Error loading addresses', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().contains('TimeoutException')
                        ? 'انتهت مهلة الاتصال. تحقق من الإنترنت'
                        : 'فشل في تحميل العناوين المحفوظة',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: _showSavedAddresses,
            ),
          ),
        );
      }
    }
  }

  void _loadAddressData(AddressModel address) {
    setState(() {
      currentEditingAddressId = address.id;
      _formData.loadFrom(address);
      selectedAddressType = address.label;
      saveAsDefault = address.isDefault;

      if (address.latitude != null && address.longitude != null) {
        selectedPosition = LatLng(address.latitude!, address.longitude!);
      }

      _formRevision++;
    });

    _syncControllersFromFormData();

    if (selectedPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedPosition!, 16),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحميل عنوان "${address.label}"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createNewAddress() {
    setState(() {
      currentEditingAddressId = null;
      _formData.clear();
      selectedPosition = null;
      selectedAddressType = 'المنزل';
      saveAsDefault = false;
      _formRevision++;
    });

    _syncControllersFromFormData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاهز لإضافة عنوان جديد'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _setAsDefault(String addressId) async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      // First, set all addresses to non-default
      await Supabase.instance.client
          .from('addresses')
          .update({'is_default': false})
          .eq('client_id', userId);

      // Then set the selected address as default
      await Supabase.instance.client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('تم تعيين العنوان كافتراضي'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error setting default address', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('فشل في تعيين العنوان الافتراضي')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await Supabase.instance.client
          .from('addresses')
          .delete()
          .eq('id', addressId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('تم حذف العنوان بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error deleting address', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('فشل في حذف العنوان')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadDefaultAddress() async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        AppLogger.warning('User not logged in - skipping address load');
        return;
      }

      // Load the default address from addresses table
      final response = await Supabase.instance.client
          .from('addresses')
          .select()
          .eq('client_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        try {
          final address = AddressModel.fromMap(response);

          // ✅ استخدام النموذج الموحد
          _formData.loadFrom(address);

          if (address.latitude != null && address.longitude != null) {
            selectedPosition = LatLng(address.latitude!, address.longitude!);
          }

          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          AppLogger.error('Error parsing address data', e);
        }
      }
    } catch (e) {
      AppLogger.error('Error loading address', e);
    }
  }

  Future<void> detectCurrentLocation() async {
    if (!mounted) return;

    setState(() => isLoadingLocation = true);
    try {
      // Check location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('إذن الموقع مرفوض بشكل دائم. يرجى تفعيله من الإعدادات');
      }

      // Get current position with timeout handling
      Position position;
      try {
        position =
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('انتهت مهلة تحديد الموقع');
              },
            );
      } on TimeoutException {
        // Try with lower accuracy if high accuracy times out
        AppLogger.warning('High accuracy timeout, trying with medium accuracy');
        position =
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 10),
              ),
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('فشل تحديد الموقع. تأكد من تفعيل GPS');
              },
            );
      }

      if (!mounted) return;

      selectedPosition = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedPosition!, 16),
      );

      // تحويل الإحداثيات إلى عنوان فعلي
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                AppLogger.warning(
                  'Geocoding timeout - location set without address details',
                );
                return [];
              },
            );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;

          // ✅ استخدام النموذج الموحد لملء البيانات
          if (_formData.governorate.isEmpty) {
            _formData.governorate = place.administrativeArea ?? '';
          }

          if (_formData.city.isEmpty) {
            String city = '';
            if (place.locality?.isNotEmpty ?? false) {
              city = place.locality!;
            } else if (place.subAdministrativeArea?.isNotEmpty ?? false) {
              city = place.subAdministrativeArea!;
            } else if (place.subLocality?.isNotEmpty ?? false) {
              // تأكد أنه ليس مكرر مع المحافظة
              if (!_isDuplicate(place.subLocality, _formData.governorate)) {
                city = place.subLocality!;
              }
            }
            _formData.city = city;
          }

          if (_formData.district.isEmpty) {
            String district = '';
            if (place.subLocality?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.subLocality!)) {
                // تأكد أنه ليس مكرر مع city أو governorate
                if (!_isDuplicate(place.subLocality, _formData.city) &&
                    !_isDuplicate(place.subLocality, _formData.governorate)) {
                  district = place.subLocality!;
                }
              }
            }
            if (district.isEmpty && (place.name?.isNotEmpty ?? false)) {
              if (!_isPlusCode(place.name!) &&
                  !_isDuplicate(place.name, _formData.city) &&
                  !_isDuplicate(place.name, _formData.governorate)) {
                district = place.name!;
              }
            }
            _formData.district = district;
          }

          if (_formData.street.isEmpty) {
            String street = '';
            if (place.thoroughfare?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.thoroughfare!) &&
                  !_isDuplicate(place.thoroughfare, _formData.city) &&
                  !_isDuplicate(place.thoroughfare, _formData.district)) {
                street = place.thoroughfare!;
              }
            }
            if (street.isEmpty && (place.name?.isNotEmpty ?? false)) {
              if (!_isPlusCode(place.name!) &&
                  !_isDuplicate(place.name, _formData.city) &&
                  !_isDuplicate(place.name, _formData.district)) {
                street = place.name!;
              }
            }
            if (street.isNotEmpty) {
              if (place.subThoroughfare?.isNotEmpty ?? false) {
                if (!_isPlusCode(place.subThoroughfare!)) {
                  if (!_isDuplicate(street, place.subThoroughfare)) {
                    street = '${place.subThoroughfare} $street';
                  }
                }
              }
            } else if (place.subThoroughfare?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.subThoroughfare!)) {
                street = place.subThoroughfare!;
              }
            }
            _formData.street = street;
          }

          if (_formData.building.isEmpty) {
            if (place.subThoroughfare?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.subThoroughfare!)) {
                final numbers = RegExp(
                  r'\d+',
                ).firstMatch(place.subThoroughfare!)?.group(0);
                if (numbers != null) {
                  _formData.building = numbers;
                }
              }
            }
          }

          // Log the placemark details for debugging
          AppLogger.info(
            'Geocoding result:\n'
            'name: ${place.name}\n'
            'administrativeArea: ${place.administrativeArea}\n'
            'subAdministrativeArea: ${place.subAdministrativeArea}\n'
            'locality: ${place.locality}\n'
            'subLocality: ${place.subLocality}\n'
            'thoroughfare: ${place.thoroughfare}\n'
            'subThoroughfare: ${place.subThoroughfare}',
          );

          // ✅ Update UI to show filled data
          if (mounted) {
            setState(() {});

            // Show success message with filled data
            String filledFields = '';
            if (_formData.governorate.isNotEmpty) {
              filledFields += 'المحافظة، ';
            }
            if (_formData.city.isNotEmpty) filledFields += 'المركز، ';
            if (_formData.district.isNotEmpty) filledFields += 'القرية/الحي، ';
            if (_formData.street.isNotEmpty) filledFields += 'الشارع';

            if (filledFields.isNotEmpty) {
              filledFields = filledFields.replaceAll(RegExp(r'،\s*$'), '');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ تم تعبئة: $filledFields'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.edit_location_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '📍 تم تحديد الموقع\nيرجى إدخال بيانات العنوان يدوياً',
                    ),
                  ),
                ],
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        AppLogger.warning('Failed to get address from coordinates: $e');

        // لا تملأ الحقول بقيم افتراضية - دع المستخدم يملأها يدوياً
        if (mounted) {
          setState(() {});
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.error('Location detection error', e);
      if (mounted) {
        String errorMessage = 'فشل في تحديد الموقع';

        // Parse error message
        String errorStr = e.toString();
        if (errorStr.contains('denied')) {
          errorMessage = 'تم رفض إذن الموقع. يرجى تفعيله من الإعدادات';
        } else if (errorStr.contains('timeout')) {
          errorMessage = 'انتهت مهلة تحديد الموقع. تأكد من تفعيل GPS';
        } else if (errorStr.contains('network')) {
          errorMessage = 'تحقق من اتصال الإنترنت';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), duration: Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingLocation = false);
      }
    }
  }

  void saveAddress() async {
    AppLogger.info('💾 حفظ العنوان...');

    // تأكد أن بيانات الحقول النصية متزامنة
    _syncFormDataFromControllers();

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      AppLogger.warning('User not logged in when trying to save address');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    final addressValid = _addressFormKey.currentState?.validate() ?? false;
    if (!addressValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إكمال الحقول المطلوبة في العنوان'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate coordinates only when user picked one (map is optional for now)
    if (selectedPosition != null) {
      final lat = selectedPosition!.latitude;
      final lng = selectedPosition!.longitude;

      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        AppLogger.error('Invalid coordinates', 'lat: $lat, lng: $lng');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'إحداثيات الموقع غير صحيحة\nيرجى اختيار موقع من الخريطة مرة أخرى',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    final label = _formData.label.trim().isNotEmpty
        ? _formData.label.trim()
        : selectedAddressType;

    setState(() => isSavingAddress = true);

    try {
      AppLogger.info('Starting address save process...');

      // ✅ استخدام النموذج الموحد لإنشاء البيانات
      final addressData = _formData.toMap(
        userId,
        label,
        selectedPosition,
        saveAsDefault,
      );

      if (currentEditingAddressId != null) {
        AppLogger.info('Updating existing address: $currentEditingAddressId');

        await AddressService.upsertAddress(
          client: Supabase.instance.client,
          userId: userId,
          addressId: currentEditingAddressId,
          addressData: addressData,
          unsetOtherDefaults: saveAsDefault,
        );
        if (!mounted) return;

        AppLogger.info('✅ Address updated successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث عنوان "$label" بنجاح'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        AppLogger.info('Inserting new address...');

        await AddressService.upsertAddress(
          client: Supabase.instance.client,
          userId: userId,
          addressData: addressData,
          unsetOtherDefaults: saveAsDefault,
        );
        if (!mounted) return;

        AppLogger.info('✅ Address inserted successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة عنوان "$label" بنجاح'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // ❌ إلغاء الـ cache بعد الحفظ
      _cachedAddresses = null;
      _lastAddressLoadTime = null;

      _createNewAddress();
    } catch (e) {
      AppLogger.error('Error saving address', e);
      if (mounted) {
        final errorMessage = e.toString().contains('TimeoutException')
            ? 'انتهت مهلة الاتصال. تحقق من الإنترنت'
            : 'حدث خطأ أثناء حفظ العنوان: ${e.toString()}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: saveAddress,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSavingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          currentEditingAddressId != null ? ' تعديل العنوان' : ' إضافة عنوان',
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        actions: [
          if (currentEditingAddressId != null)
            IconButton(
              onPressed: _createNewAddress,
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'عنوان جديد',
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: SafeArea(
          child: Column(
            children: [
              // Form Section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: RefreshIndicator(
                    onRefresh: _loadDefaultAddress,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Saved Addresses button
                          OutlinedButton.icon(
                            onPressed: _showSavedAddresses,
                            icon: const Icon(Icons.bookmarks_rounded),
                            label: const Text(
                              'عناويني المحفوظة',
                              style: TextStyle(fontSize: 15),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          KeyedSubtree(
                            key: ValueKey(_formRevision),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 20),

                                // Address Type Selection
                                Text(
                                  'نوع العنوان',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _AddressTypeChip(
                                        label: 'المنزل',
                                        icon: Icons.home_rounded,
                                        isSelected:
                                            selectedAddressType == 'المنزل',
                                        onTap: () {
                                          setState(() {
                                            selectedAddressType = 'المنزل';
                                            _formData.label = '';
                                            _formRevision++;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _AddressTypeChip(
                                        label: 'العمل',
                                        icon: Icons.work_rounded,
                                        isSelected:
                                            selectedAddressType == 'العمل',
                                        onTap: () {
                                          setState(() {
                                            selectedAddressType = 'العمل';
                                            _formData.label = '';
                                            _formRevision++;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _AddressTypeChip(
                                        label: 'أخرى',
                                        icon: Icons.location_on_rounded,
                                        isSelected:
                                            selectedAddressType == 'أخرى',
                                        onTap: () {
                                          setState(() {
                                            selectedAddressType = 'أخرى';
                                            _formRevision++;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Custom label for "أخرى"
                                if (selectedAddressType == 'أخرى')
                                  TextFormField(
                                    initialValue: _formData.label,
                                    onChanged: (value) {
                                      _formData.label = value;
                                    },
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'اسم العنوان',
                                      labelStyle: const TextStyle(fontSize: 14),
                                      hintText: 'بيت الجدة، النادي، المكتبة...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[400],
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.label_rounded,
                                        size: 20,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 18,
                                          ),
                                    ),
                                  ),

                                if (selectedAddressType == 'أخرى')
                                  const SizedBox(height: 16),

                                const SizedBox(height: 20),

                                // ✅ الفورم العام للعناوين + اختيار الموقع
                                // المحافظة - المركز - القرية/الحي - الشارع - العلامة
                                AddressLocationFormSection(
                                  userType: MapUserType.customer,
                                  formType: AddressFormType.residential,
                                  formKey: _addressFormKey,
                                  governorateController: _governorateCtrl,
                                  cityController: _cityCtrl,
                                  areaController: _districtCtrl,
                                  streetController: _streetCtrl,
                                  landmarkController: _landmarkCtrl,
                                  governorateFocus: _governorateFocus,
                                  cityFocus: _cityFocus,
                                  streetFocus: _streetFocus,
                                  position: selectedPosition,
                                  requirePosition: false,
                                  showMapPicker: false,
                                  onPositionChanged: (pos) {
                                    setState(() {
                                      selectedPosition = pos;
                                    });

                                    if (pos != null) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(pos, 16),
                                      );
                                    }
                                  },
                                  onGovernorateChanged: (v) {
                                    _handleGovernorateSelection(v);
                                  },
                                  onCityChanged: (v) {
                                    _handleCitySelection(v);
                                  },
                                  onAreaChanged: (v) {
                                    setState(() {
                                      _formData.district = v;
                                    });
                                  },
                                  governorateOptions: _hasOwnerZoneOptions
                                      ? _governorateOptions
                                      : null,
                                  cityOptions: _hasOwnerZoneOptions
                                      ? _cityOptions
                                      : null,
                                  areaOptions: _hasOwnerZoneOptions
                                      ? _areaOptions
                                      : null,
                                  summaryCity: _cityCtrl.text.trim().isEmpty
                                      ? null
                                      : _cityCtrl.text.trim(),
                                  summaryGovernorate:
                                      _governorateCtrl.text.trim().isEmpty
                                      ? null
                                      : _governorateCtrl.text.trim(),
                                  // يملأ المحافظة + المركز فقط (اتساقاً مع بقية التطبيق)
                                  autofillAllFieldsFromMap: false,
                                  // ✅ تشغيل PostGIS: تحديث الموقع + تحديث المتاجر القريبة
                                  updateLocationProvider: false,
                                  refreshNearbyStores: false,
                                  maxDistanceKm: 15,
                                ),

                                const SizedBox(height: 16),

                                // رقم المبنى والطابق
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _formData.building,
                                        onChanged: (value) {
                                          _formData.building = value;
                                        },
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(fontSize: 15),
                                        decoration: InputDecoration(
                                          labelText: 'رقم المبنى',
                                          labelStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                          hintText: '15',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[400],
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.home_work_rounded,
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 18,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _formData.floor,
                                        onChanged: (value) {
                                          _formData.floor = value;
                                        },
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(fontSize: 15),
                                        decoration: InputDecoration(
                                          labelText: 'الطابق',
                                          labelStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                          hintText: '3',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[400],
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.stairs_rounded,
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 18,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // رقم الشقة
                                TextFormField(
                                  initialValue: _formData.apartment,
                                  onChanged: (value) {
                                    _formData.apartment = value;
                                  },
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'رقم الشقة',
                                    labelStyle: const TextStyle(fontSize: 14),
                                    hintText: '5',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[400],
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.door_front_door_rounded,
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // تم نقل "علامة مميزة" داخل الفورم العام
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),

                          // Set as default checkbox
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: saveAsDefault
                                    ? colorScheme.primary
                                    : colorScheme.outline.withValues(
                                        alpha: 0.3,
                                      ),
                                width: saveAsDefault ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  saveAsDefault
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: saveAsDefault
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'تعيين كعنوان افتراضي',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: saveAsDefault
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface,
                                            ),
                                      ),
                                      Text(
                                        'سيتم استخدام هذا العنوان تلقائياً في الطلبات',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: saveAsDefault,
                                  autofocus: false,
                                  onChanged: (value) {
                                    setState(() {
                                      saveAsDefault = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Save button
                          FilledButton.icon(
                            onPressed: isSavingAddress ? null : saveAddress,
                            icon: isSavingAddress
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: AppShimmer.wrap(
                                      context,
                                      child: AppShimmer.circle(
                                        context,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    currentEditingAddressId != null
                                        ? Icons.update_rounded
                                        : Icons.add_location_rounded,
                                  ),
                            label: Text(
                              isSavingAddress
                                  ? 'جاري الحفظ...'
                                  : (currentEditingAddressId != null
                                        ? 'تحديث العنوان'
                                        : 'إضافة عنوان جديد'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[600],
                            ),
                          ),

                          // New Address button (if editing)
                          if (currentEditingAddressId != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _createNewAddress,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('عنوان جديد'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // العودة للصفحة السابقة (قبل الخريطة)
                                      int popCount = 1;

                                      // إذا جاء من الخريطة، نرجع خطوتين
                                      final args = ModalRoute.of(
                                        context,
                                      )?.settings.arguments;
                                      if (args != null &&
                                          args is Map &&
                                          args.containsKey('position')) {
                                        popCount = 2;
                                      }

                                      // العودة للخلف
                                      for (
                                        int i = 0;
                                        i < popCount &&
                                            Navigator.of(context).canPop();
                                        i++
                                      ) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    label: const Text('رجوع'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Info note
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'تم إيقاف الخريطة مؤقتاً — أدخل العنوان يدوياً',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
    );
  }

  @override
  void dispose() {
    // ✅ تنظيف موارد الحقول
    _governorateCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _governorateFocus.dispose();
    _cityFocus.dispose();
    _streetFocus.dispose();

    // ✅ تنظيف موارد الخريطة
    _mapController?.dispose();

    // ✅ إلغاء الـ cache
    _cachedAddresses = null;
    _lastAddressLoadTime = null;

    AppLogger.info('🧹 تنظيف موارد AddressesScreen');
    super.dispose();
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
      canRequestFocus: false,
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
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom Sheet Widget for Address List
class _AddressListBottomSheet extends StatelessWidget {
  final List<AddressModel> addresses;
  final Function(AddressModel) onAddressSelected;
  final Function(String) onAddressDeleted;
  final Function(String) onSetDefault;

  const _AddressListBottomSheet({
    required this.addresses,
    required this.onAddressSelected,
    required this.onAddressDeleted,
    required this.onSetDefault,
  });

  Color _getAddressColor(String? label) {
    switch (label?.toLowerCase()) {
      case 'المنزل':
      case 'home':
        return Colors.blue;
      case 'العمل':
      case 'work':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  IconData _getAddressIcon(String? label) {
    switch (label?.toLowerCase()) {
      case 'المنزل':
      case 'home':
        return Icons.home_rounded;
      case 'العمل':
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  String _formatAddress(AddressModel address) {
    // العنوان الكامل مخزن مباشرة
    if (address.address.isNotEmpty) {
      return address.address;
    }
    return 'عنوان غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bookmarks_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'عناويني المحفوظة',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${addresses.length} عنوان',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Address List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  final color = _getAddressColor(address.label);
                  final icon = _getAddressIcon(address.label);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: address.isDefault
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.2),
                        width: address.isDefault ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        AppLogger.info(
                          '🏠 تم اختيار العنوان: ${address.label}',
                        );
                        onAddressSelected(address);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with icon, label, and default badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.label,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 13,
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'افتراضي',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onPrimaryContainer,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'خيارات',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                    maxWidth: 40,
                                    maxHeight: 40,
                                  ),
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: colorScheme.onSurface,
                                    size: 22,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'default') {
                                      await onSetDefault(address.id);
                                    } else if (value == 'delete') {
                                      // Show confirmation dialog
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          icon: Icon(
                                            Icons.warning_rounded,
                                            color: Theme.of(
                                              dialogContext,
                                            ).colorScheme.error,
                                            size: 32,
                                          ),
                                          title: const Text('تأكيد الحذف'),
                                          content: Text(
                                            'هل تريد حذف عنوان "${address.label}"؟',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('إلغاء'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Theme.of(
                                                  dialogContext,
                                                ).colorScheme.error,
                                              ),
                                              child: const Text('حذف'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        onAddressDeleted(address.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (!address.isDefault)
                                      PopupMenuItem(
                                        value: 'default',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.star_rounded,
                                              size: 20,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('تعيين كافتراضي'),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: colorScheme.error,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'حذف',
                                            style: TextStyle(
                                              color: colorScheme.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Address details
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _formatAddress(address),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Landmark if available
                            if (address.landmark?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      address.landmark!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontStyle: FontStyle.italic,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Select button
                            FilledButton.icon(
                              onPressed: () => onAddressSelected(address),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('استخدام هذا العنوان'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
