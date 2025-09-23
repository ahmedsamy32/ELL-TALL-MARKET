import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/user_model.dart'; // Moving this up
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _fillManualAddress(authProvider.user?.address ?? '');
  }

  void _fillManualAddress(String address) {
    if (address.isEmpty) return;
    // تقسيم العنوان إلى أجزاء مفصولة بفاصلة
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.isNotEmpty) {
      governorateController.text = parts.isNotEmpty ? parts[0] : '';
    }
    if (parts.length > 1) {
      cityController.text = parts[1];
    }
    if (parts.length > 2) {
      districtController.text = parts[2];
    }
    if (parts.length > 3) {
      streetController.text = parts[3];
    }
  }

  Future<void> detectCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      selectedPosition = LatLng(position.latitude, position.longitude);
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedPosition!, 16),
      );

      // تحويل الإحداثيات إلى عنوان فعلي
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        governorateController.text = place.administrativeArea ?? '';
        cityController.text = place.locality ?? '';
        districtController.text = place.subLocality ?? '';
        streetController.text = place.street ?? '';
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في تحديد الموقع: $e')));
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  void saveAddress() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final addressParts = [
      governorateController.text,
      cityController.text,
      districtController.text,
      streetController.text,
      if (buildingController.text.isNotEmpty) 'مبنى ${buildingController.text}',
      if (floorController.text.isNotEmpty) 'الطابق ${floorController.text}',
      if (apartmentController.text.isNotEmpty)
        'شقة ${apartmentController.text}',
      if (landmarkController.text.isNotEmpty)
        'بالقرب من ${landmarkController.text}',
    ].where((e) => e.isNotEmpty).join(', ');

    if (addressParts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تحديد العنوان أولاً')));
      return;
    }

    // Creating a new user model with updated address
    final updatedUser = UserModel(
      id: authProvider.user!.id,
      name: authProvider.user!.name,
      email: authProvider.user!.email,
      phone: authProvider.user!.phone,
      type: authProvider.user!.type,
      createdAt: authProvider.user!.createdAt,
      isActive: authProvider.user!.isActive,
      address: addressParts, // Set the new address
      // Copy other fields from existing user
      avatarUrl: authProvider.user!.avatarUrl,
      updatedAt: DateTime.now(),
      lastLogin: authProvider.user!.lastLogin,
      loginCount: authProvider.user!.loginCount,
      storeId: authProvider.user!.storeId,
      preferredPaymentMethod: authProvider.user!.preferredPaymentMethod,
      storeName: authProvider.user!.storeName,
      storeDescription: authProvider.user!.storeDescription,
      storeLogoUrl: authProvider.user!.storeLogoUrl,
      storeCoverUrl: authProvider.user!.storeCoverUrl,
      storeAddress: authProvider.user!.storeAddress,
      storeLocation: authProvider.user!.storeLocation,
      storeCategory: authProvider.user!.storeCategory,
      storeRating: authProvider.user!.storeRating,
      storeRatingCount: authProvider.user!.storeRatingCount,
    );

    // Updating the user data in the database and then inside AuthProvider
    final success = await authProvider.updateUser(updatedUser);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان بنجاح')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء حفظ العنوان')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('العنوان')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: selectedPosition ?? LatLng(30.0444, 31.2357),
                zoom: 14,
              ),
              onMapCreated: (controller) => mapController = controller,
              markers: selectedPosition != null
                  ? {
                      Marker(
                        markerId: MarkerId('selected'),
                        position: selectedPosition!,
                      ),
                    }
                  : {},
              onTap: (position) {
                setState(() {
                  selectedPosition = position;
                });
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoadingLocation ? null : detectCurrentLocation,
                    icon: Icon(Icons.my_location),
                    label: Text(
                      isLoadingLocation
                          ? 'جاري التحميل...'
                          : 'استخدام موقعي الحالي',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'أو أدخل العنوان يدويًا',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // المحافظة والمدينة
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: governorateController,
                          decoration: InputDecoration(
                            labelText: 'المحافظة',
                            hintText: 'مثل: القاهرة، الجيزة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'المدينة/المنطقة',
                            hintText: 'مثل: مدينة نصر، المعادي',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // الحي والشارع
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: districtController,
                          decoration: InputDecoration(
                            labelText: 'الحي',
                            hintText: 'مثل: الحي الأول، النزهة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: streetController,
                          decoration: InputDecoration(
                            labelText: 'الشارع',
                            hintText: 'مثل: شارع التحرير',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // تفاصيل المبنى
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: buildingController,
                          decoration: InputDecoration(
                            labelText: 'رقم المبنى',
                            hintText: 'مثل: 15، 23أ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: floorController,
                          decoration: InputDecoration(
                            labelText: 'الطابق',
                            hintText: 'مثل: 3، الأرضي',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: apartmentController,
                          decoration: InputDecoration(
                            labelText: 'الشقة',
                            hintText: 'مثل: 5، 12أ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // العلامة المميزة
                  TextField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: 'علامة مميزة (اختياري)',
                      hintText: 'مثل: بجانب مسجد النور، أمام بنك مصر',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saveAddress,
                    child: Text('حفظ العنوان'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
