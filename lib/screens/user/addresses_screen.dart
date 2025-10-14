import 'package:flutter/material.dart';
// Moving this up
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/address_Model.dart';
import 'package:ell_tall_market/core/logger.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  _AddressesScreenState createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  TextEditingController governorateController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController districtController = TextEditingController();
  TextEditingController streetController = TextEditingController();
  TextEditingController buildingController = TextEditingController();
  TextEditingController floorController = TextEditingController();
  TextEditingController apartmentController = TextEditingController();
  TextEditingController landmarkController = TextEditingController();
  GoogleMapController? mapController;
  LatLng? selectedPosition;
  bool isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // Load user's default address if exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultAddress();
    });
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

          // Fill the form with existing address data
          cityController.text = address.city;
          streetController.text = address.street;
          districtController.text = address.area ?? '';
          buildingController.text = address.buildingNumber ?? '';
          floorController.text = address.floorNumber ?? '';
          apartmentController.text = address.apartmentNumber ?? '';
          landmarkController.text = address.notes ?? '';

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
      // Don't crash the app - just log the error
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

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      selectedPosition = LatLng(position.latitude, position.longitude);
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedPosition!, 16),
      );

      // تحويل الإحداثيات إلى عنوان فعلي
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          governorateController.text = place.administrativeArea ?? '';
          cityController.text = place.locality ?? '';
          districtController.text = place.subLocality ?? '';
          streetController.text = place.street ?? '';
        }
      } catch (e) {
        AppLogger.warning('Failed to get address from coordinates: $e');
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
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    // Validate required fields
    if (cityController.text.isEmpty || streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المدينة والشارع على الأقل')),
      );
      return;
    }

    try {
      // Prepare address data for database
      final addressData = {
        'client_id': userId,
        'label': 'المنزل', // Default label
        'city': cityController.text.trim(),
        'street': streetController.text.trim(),
        'area': districtController.text.trim().isNotEmpty
            ? districtController.text.trim()
            : null,
        'building_number': buildingController.text.trim().isNotEmpty
            ? buildingController.text.trim()
            : null,
        'floor_number': floorController.text.trim().isNotEmpty
            ? floorController.text.trim()
            : null,
        'apartment_number': apartmentController.text.trim().isNotEmpty
            ? apartmentController.text.trim()
            : null,
        'latitude': selectedPosition?.latitude,
        'longitude': selectedPosition?.longitude,
        'notes': landmarkController.text.trim().isNotEmpty
            ? landmarkController.text.trim()
            : null,
        'is_default': true, // Set as default address
      };

      // Check if user already has a default address
      final existingAddress = await Supabase.instance.client
          .from('addresses')
          .select()
          .eq('client_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (existingAddress != null) {
        // Update existing default address
        await Supabase.instance.client
            .from('addresses')
            .update(addressData)
            .eq('id', existingAddress['id']);
      } else {
        // Insert new address
        await Supabase.instance.client.from('addresses').insert(addressData);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان بنجاح')));
      }
    } catch (e) {
      AppLogger.error('Error saving address', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ العنوان: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('📍 عنوان التوصيل'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
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
                        zoom: 14,
                      ),
                      onMapCreated: (controller) => mapController = controller,
                      markers: selectedPosition != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: selectedPosition!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueBlue,
                                ),
                              ),
                            }
                          : {},
                      onTap: (position) {
                        setState(() {
                          selectedPosition = position;
                        });
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    // Hint overlay
                    if (selectedPosition == null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'اضغط على الخريطة لتحديد موقعك',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Location button
                      FilledButton.tonalIcon(
                        onPressed: isLoadingLocation
                            ? null
                            : detectCurrentLocation,
                        icon: isLoadingLocation
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          isLoadingLocation
                              ? 'جاري تحديد الموقع...'
                              : '📍 استخدام موقعي الحالي',
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider with text
                      Row(
                        children: [
                          Expanded(child: Divider(color: colorScheme.outline)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'أو أدخل العنوان يدويًا',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: colorScheme.outline)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // المحافظة والمدينة
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: governorateController,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'المحافظة',
                                labelStyle: const TextStyle(fontSize: 14),
                                hintText: 'القاهرة',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: const Icon(
                                  Icons.location_city_rounded,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withOpacity(0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: cityController,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'المدينة *',
                                labelStyle: const TextStyle(fontSize: 14),
                                hintText: 'مدينة نصر',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: const Icon(
                                  Icons.location_on_rounded,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // الحي والشارع
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: districtController,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'الحي',
                                labelStyle: const TextStyle(fontSize: 14),
                                hintText: 'الحي الأول',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: const Icon(
                                  Icons.apartment_rounded,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: streetController,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'الشارع *',
                                labelStyle: const TextStyle(fontSize: 14),
                                hintText: 'التحرير',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: const Icon(
                                  Icons.signpost_rounded,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // رقم المبنى والطابق
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: buildingController,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'رقم المبنى',
                                labelStyle: const TextStyle(fontSize: 14),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: floorController,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'الطابق',
                                labelStyle: const TextStyle(fontSize: 14),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
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
                      TextField(
                        controller: apartmentController,
                        keyboardType: TextInputType.text,
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
                          fillColor: colorScheme.surfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // العلامة المميزة
                      TextField(
                        controller: landmarkController,
                        maxLines: 2,
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
                          fillColor: colorScheme.surfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      FilledButton.icon(
                        onPressed: saveAddress,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          'حفظ العنوان',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Required fields note
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
                            '* حقول مطلوبة',
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    governorateController.dispose();
    cityController.dispose();
    districtController.dispose();
    streetController.dispose();
    buildingController.dispose();
    floorController.dispose();
    apartmentController.dispose();
    landmarkController.dispose();
    super.dispose();
  }
}
