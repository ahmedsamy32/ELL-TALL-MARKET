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

// 📦 نموذج موحد لبيانات العنوان (تقليل عدد Controllers)
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

  void loadFrom(AddressModel address) {
    governorate = address.governorate;
    city = address.city;
    street = address.street;
    district = address.area ?? '';
    building = address.buildingNumber ?? '';
    floor = address.floorNumber ?? '';
    apartment = address.apartmentNumber ?? '';
    landmark = address.notes ?? '';
    label = address.label;
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
      'governorate': governorate.trim(),
      'city': city.trim(),
      'street': street.trim(),
      'area': district.trim().isNotEmpty ? district.trim() : null,
      'building_number': building.trim().isNotEmpty ? building.trim() : null,
      'floor_number': floor.trim().isNotEmpty ? floor.trim() : null,
      'apartment_number': apartment.trim().isNotEmpty ? apartment.trim() : null,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'notes': landmark.trim().isNotEmpty ? landmark.trim() : null,
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

  // 🔄 لأن TextFormField(initialValue) لا يعيد التزامن بعد أول build
  // نستخدم revision لإجبار إعادة إنشاء الحقول عند تحميل/مسح البيانات.
  int _formRevision = 0;

  // 📍 Controllers للحقول النصية فقط (تقليل من 9 إلى 0 - نستخدم TextFormField مع onChanged)
  // Note: _formKey reserved for future form validation
  // final _formKey = GlobalKey<FormState>();

  GoogleMapController? _mapController;
  Completer<GoogleMapController>? _mapCompleter;

  LatLng? selectedPosition;
  bool isLoadingLocation = false;
  bool isLoadingAddressFromMap = false;
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

  /// التحقق من اكتمال البيانات الأساسية
  bool get isAddressComplete {
    return selectedPosition != null &&
        _formData.governorate.trim().isNotEmpty &&
        _formData.city.trim().isNotEmpty &&
        _formData.street.trim().isNotEmpty;
  }

  /// نسبة اكتمال العنوان (0-100)
  int get addressCompletionPercentage {
    int filledFields = 0;
    const totalRequiredFields = 4;
    const totalOptionalFields = 5;

    if (selectedPosition != null) filledFields++;
    if (_formData.governorate.trim().isNotEmpty) filledFields++;
    if (_formData.city.trim().isNotEmpty) filledFields++;
    if (_formData.street.trim().isNotEmpty) filledFields++;

    if (_formData.district.trim().isNotEmpty) filledFields++;
    if (_formData.building.trim().isNotEmpty) filledFields++;
    if (_formData.floor.trim().isNotEmpty) filledFields++;
    if (_formData.apartment.trim().isNotEmpty) filledFields++;
    if (_formData.landmark.trim().isNotEmpty) filledFields++;

    final requiredScore =
        (filledFields.clamp(0, totalRequiredFields) / totalRequiredFields) * 70;
    final optionalScore =
        ((filledFields - totalRequiredFields).clamp(0, totalOptionalFields) /
            totalOptionalFields) *
        30;

    return (requiredScore + optionalScore).round();
  }

  @override
  void initState() {
    super.initState();
    _mapCompleter = Completer<GoogleMapController>();
    AppLogger.info('🏠 بدء AddressesScreen');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultAddress();
      _loadMapPickerData();
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
          String fullAddress = args['address'];
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

        if (args['position'] != null) {
          selectedPosition = args['position'];
          AppLogger.info('✅ تم تحديد الموقع: $selectedPosition');
        }

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
    // Plus codes typically contain '+' and are alphanumeric
    // Format: XXXX+XX or XXXXX+XXX (with optional area prefix)
    final plusCodePattern = RegExp(
      r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,3}$',
      caseSensitive: false,
    );
    return plusCodePattern.hasMatch(text.trim());
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

  /// Set custom map style (optional - for better UX)
  void _setMapStyle(GoogleMapController controller) {
    _mapController = controller;
    if (!_mapCompleter!.isCompleted) {
      _mapCompleter!.complete(controller);
    }
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
              city = place.subLocality!;
            }
            _formData.city = city;
          }

          if (_formData.district.isEmpty) {
            String district = '';
            if (place.subLocality?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.subLocality!)) {
                if (place.subLocality != _formData.city) {
                  district = place.subLocality!;
                }
              }
            }
            if (district.isEmpty && (place.name?.isNotEmpty ?? false)) {
              if (!_isPlusCode(place.name!) && place.name != _formData.city) {
                district = place.name!;
              }
            }
            _formData.district = district;
          }

          if (_formData.street.isEmpty) {
            String street = '';
            if (place.thoroughfare?.isNotEmpty ?? false) {
              if (!_isPlusCode(place.thoroughfare!)) {
                street = place.thoroughfare!;
              }
            }
            if (street.isEmpty && (place.name?.isNotEmpty ?? false)) {
              if (!_isPlusCode(place.name!)) {
                street = place.name!;
              }
            }
            if (street.isNotEmpty) {
              if (place.subThoroughfare?.isNotEmpty ?? false) {
                if (!_isPlusCode(place.subThoroughfare!)) {
                  if (street != place.subThoroughfare) {
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

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      AppLogger.warning('User not logged in when trying to save address');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    if (selectedPosition == null) {
      AppLogger.warning('No location selected from map');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.map, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'يرجى اختيار الموقع من الخريطة أولاً\n👆 اضغط على "📍 اختيار من الخريطة"',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'فتح الخريطة',
            textColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedMapScreen(
                    userType: MapUserType.customer,
                    actionType: MapActionType.pickLocation,
                    initialPosition: selectedPosition,
                    onLocationSelectedDetails: (details) {
                      if (!mounted) return;
                      setState(() {
                        selectedPosition = details.position;
                        _formData.governorate = details.governorate ?? '';
                        _formData.city = details.city ?? '';
                        final street = (details.street ?? '').trim();
                        _formData.street = street.isNotEmpty
                            ? street
                            : _extractStreetFromAddress(details.address);

                        final district = (details.district ?? '').trim();
                        _formData.district = district.isNotEmpty
                            ? district
                            : _extractDistrictFromAddress(
                                details.address,
                                city: _formData.city,
                                governorate: _formData.governorate,
                              );

                        _formRevision++;
                      });

                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(details.position, 16),
                      );
                    },
                  ),
                ),
              );
              if (!mounted) return;
            },
          ),
        ),
      );
      return;
    }

    // Validate coordinates
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

    // ✅ التحقق باستخدام النموذج الموحد
    final missingFields = <String>[];
    if (_formData.governorate.trim().isEmpty) missingFields.add('المحافظة');
    if (_formData.city.trim().isEmpty) missingFields.add('المركز');
    if (_formData.street.trim().isEmpty) missingFields.add('الشارع');

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى إكمال الحقول التالية:\n• ${missingFields.join('\n• ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final label = _formData.label.trim().isNotEmpty
        ? _formData.label.trim()
        : selectedAddressType;

    setState(() => isSavingAddress = true);

    try {
      AppLogger.info('Starting address save process...');

      if (saveAsDefault) {
        AppLogger.info('Setting address as default, unsetting others...');
        await Supabase.instance.client
            .from('addresses')
            .update({'is_default': false})
            .eq('client_id', userId)
            .timeout(const Duration(seconds: 10));
        if (!mounted) return;
      }

      // ✅ استخدام النموذج الموحد لإنشاء البيانات
      final addressData = _formData.toMap(
        userId,
        label,
        selectedPosition,
        saveAsDefault,
      );

      if (currentEditingAddressId != null) {
        AppLogger.info('Updating existing address: $currentEditingAddressId');
        await Supabase.instance.client
            .from('addresses')
            .update(addressData)
            .eq('id', currentEditingAddressId!)
            .timeout(const Duration(seconds: 15));
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
        await Supabase.instance.client
            .from('addresses')
            .insert(addressData)
            .select()
            .timeout(const Duration(seconds: 15));
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
      body: SafeArea(
        child: Column(
          children: [
            // Map Section with rounded corners
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            selectedPosition ?? const LatLng(30.0444, 31.2357),
                        zoom: selectedPosition != null ? 16 : 14,
                      ),
                      onMapCreated: (controller) {
                        _setMapStyle(controller);

                        if (selectedPosition != null) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(selectedPosition!, 16),
                            );
                            AppLogger.info('✅ تم تحريك الخريطة عند الإنشاء');
                          });
                        }
                      },
                      markers: selectedPosition != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: selectedPosition!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                                infoWindow: const InfoWindow(
                                  title: 'الموقع المحدد',
                                ),
                              ),
                            }
                          : {},
                      mapType: MapType.normal,
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                      buildingsEnabled: true,
                      trafficEnabled: false,
                    ),
                  ],
                ),
              ),
            ),

            // Form Section
            Expanded(
              flex: 3,
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

                        const SizedBox(height: 12),

                        // Map picker button
                        OutlinedButton.icon(
                          onPressed: () async {
                            final authProvider = Provider.of<SupabaseProvider>(
                              context,
                              listen: false,
                            );
                            final userId = authProvider.currentUser?.id;

                            if (userId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى تسجيل الدخول أولاً'),
                                ),
                              );
                              return;
                            }

                            // استخدام الخريطة المتقدمة الجديدة
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdvancedMapScreen(
                                  userType: MapUserType.customer,
                                  actionType: MapActionType.pickLocation,
                                  initialPosition: selectedPosition,
                                  onLocationSelectedDetails: (details) {
                                    if (!mounted) return;
                                    setState(() {
                                      selectedPosition = details.position;
                                      _formData.governorate =
                                          details.governorate ?? '';
                                      _formData.city = details.city ?? '';
                                      final street = (details.street ?? '')
                                          .trim();
                                      _formData.street = street.isNotEmpty
                                          ? street
                                          : _extractStreetFromAddress(
                                              details.address,
                                            );

                                      final district = (details.district ?? '')
                                          .trim();
                                      _formData.district = district.isNotEmpty
                                          ? district
                                          : _extractDistrictFromAddress(
                                              details.address,
                                              city: _formData.city,
                                              governorate:
                                                  _formData.governorate,
                                            );

                                      _formRevision++;
                                    });

                                    if (selectedPosition != null) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          selectedPosition!,
                                          16,
                                        ),
                                      );
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم تحديد الموقع من الخريطة: ${details.address}',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map_rounded),
                          label: const Text(
                            '🗺️ اختر من الخريطة',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Divider with text
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: colorScheme.outline),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'أكمل باقي العنوان اختياري',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: colorScheme.outline),
                            ),
                          ],
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
                                      isSelected: selectedAddressType == 'أخرى',
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                  ),
                                ),

                              if (selectedAddressType == 'أخرى')
                                const SizedBox(height: 16),

                              const SizedBox(height: 20),

                              // نفس إجراءات التاجر: ترتيب الخانات
                              // المحافظة - المركز - القرية/الحي - الشارع - العلامة
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _formData.governorate,
                                      onChanged: (value) {
                                        _formData.governorate = value;
                                        setState(() {});
                                      },
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(fontSize: 15),
                                      decoration: InputDecoration(
                                        labelText: 'المحافظة',
                                        labelStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.map_outlined,
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
                                      initialValue: _formData.city,
                                      onChanged: (value) {
                                        _formData.city = value;
                                        setState(() {});
                                      },
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(fontSize: 15),
                                      decoration: InputDecoration(
                                        labelText: 'المركز',
                                        labelStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.location_city,
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

                              TextFormField(
                                initialValue: _formData.district,
                                onChanged: (value) {
                                  _formData.district = value;
                                  setState(() {});
                                },
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'القرية / الحي (اختياري)',
                                  labelStyle: const TextStyle(fontSize: 14),
                                  prefixIcon: const Icon(
                                    Icons.cottage_outlined,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                initialValue: _formData.street,
                                onChanged: (value) {
                                  _formData.street = value;
                                  setState(() {});
                                },
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'الشارع',
                                  labelStyle: const TextStyle(fontSize: 14),
                                  prefixIcon: const Icon(Icons.route, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
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
                                  fillColor: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                initialValue: _formData.landmark,
                                onChanged: (value) {
                                  _formData.landmark = value;
                                  setState(() {});
                                },
                                maxLines: 2,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'علامة مميزة (اختياري)',
                                  labelStyle: const TextStyle(fontSize: 14),
                                  hintText: 'بجانب مسجد النور، أمام بنك مصر',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.near_me_rounded,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),

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
                                  : colorScheme.outline.withValues(alpha: 0.3),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: colorScheme.onSurfaceVariant,
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

                        // مؤشر اكتمال العنوان (Address Completion Indicator)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: addressCompletionPercentage == 100
                                ? Colors.green.withValues(alpha: 0.1)
                                : addressCompletionPercentage >= 70
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: addressCompletionPercentage == 100
                                  ? Colors.green
                                  : addressCompletionPercentage >= 70
                                  ? Colors.orange
                                  : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    addressCompletionPercentage == 100
                                        ? Icons.check_circle
                                        : addressCompletionPercentage >= 70
                                        ? Icons.warning_amber_rounded
                                        : Icons.error_outline,
                                    color: addressCompletionPercentage == 100
                                        ? Colors.green
                                        : addressCompletionPercentage >= 70
                                        ? Colors.orange
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'اكتمال البيانات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: addressCompletionPercentage == 100
                                          ? Colors.green[900]
                                          : addressCompletionPercentage >= 70
                                          ? Colors.orange[900]
                                          : Colors.red[900],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$addressCompletionPercentage%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: addressCompletionPercentage == 100
                                          ? Colors.green[900]
                                          : addressCompletionPercentage >= 70
                                          ? Colors.orange[900]
                                          : Colors.red[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: addressCompletionPercentage / 100,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation(
                                    addressCompletionPercentage == 100
                                        ? Colors.green
                                        : addressCompletionPercentage >= 70
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                addressCompletionPercentage == 100
                                    ? '✅ جميع البيانات الأساسية مكتملة'
                                    : addressCompletionPercentage >= 70
                                    ? '⚠️ بعض البيانات الاختيارية ناقصة'
                                    : '❌ يرجى إكمال البيانات الأساسية (الموقع، المحافظة، المركز، الشارع)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Save button
                        FilledButton.icon(
                          onPressed: (isAddressComplete && !isSavingAddress)
                              ? saveAddress
                              : null,
                          icon: isSavingAddress
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
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
                            Text(
                              'يجب اختيار الموقع من الخريطة أولاً',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
    );
  }

  @override
  void dispose() {
    // ✅ تنظيف موارد الخريطة
    _mapController?.dispose();
    _mapCompleter = null;

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
    final parts = <String>[];

    if (address.buildingNumber?.isNotEmpty ?? false) {
      parts.add('${address.buildingNumber}');
    }
    if (address.street.isNotEmpty) {
      parts.add(address.street);
    }
    if (address.area?.isNotEmpty ?? false) {
      parts.add(address.area!);
    }
    if (address.city.isNotEmpty) {
      parts.add(address.city);
    }

    return parts.join('، ');
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
                                  child: Text(
                                    address.label,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (address.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'افتراضي',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                PopupMenuButton<String>(
                                  tooltip: 'خيارات',
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: colorScheme.onSurface,
                                    size: 24,
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

                            // Notes if available
                            if (address.notes?.isNotEmpty ?? false) ...[
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
                                      address.notes!,
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
