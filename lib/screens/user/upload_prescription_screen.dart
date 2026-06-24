import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/address_model.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';

class UploadPrescriptionScreen extends StatefulWidget {
  final StoreModel? initialStore;
  final String? prescriptionUrl;
  final String? initialNotes;

  const UploadPrescriptionScreen({
    super.key,
    this.initialStore,
    this.prescriptionUrl,
    this.initialNotes,
  });

  @override
  State<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  final _supabase = Supabase.instance.client;
  final _notesController = TextEditingController();

  StoreModel? _selectedStore;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _existingPrescriptionUrl;
  List<AddressModel> _savedAddresses = [];
  AddressModel? _selectedAddress;
  List<DeliveryZonePricingModel> _activeDeliveryZones = [];

  bool _isLoadingStores = false;
  bool _isLoadingAddresses = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStore = widget.initialStore;
    _existingPrescriptionUrl = widget.prescriptionUrl;
    if (widget.initialNotes != null) {
      _notesController.text = widget.initialNotes!;
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadPharmacies(),
      _loadAddresses(),
      _loadActiveDeliveryZones(),
    ]);
  }

  Future<void> _loadPharmacies() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    if (storeProvider.stores.isEmpty) {
      setState(() => _isLoadingStores = true);
      try {
        await storeProvider.fetchStores(refresh: true);
      } catch (e) {
        AppLogger.error('Failed to load stores for prescription', e);
      } finally {
        if (mounted) setState(() => _isLoadingStores = false);
      }
    }
  }

  Future<void> _loadAddresses() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingAddresses = true);
    try {
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('client_id', userId)
          .order('is_default', ascending: false);

      if (mounted) {
        setState(() {
          _savedAddresses = (response as List)
              .map((e) => AddressModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();

          if (_savedAddresses.isNotEmpty) {
            _selectedAddress = _savedAddresses.firstWhere(
              (addr) => addr.isDefault,
              orElse: () => _savedAddresses.first,
            );
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load addresses for prescription', e);
    } finally {
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _loadActiveDeliveryZones() async {
    try {
      final zones = await DeliveryZonePricingService.getActiveZones();
      if (!mounted) return;
      setState(() {
        _activeDeliveryZones = zones;
      });
    } catch (e) {
      AppLogger.error('Failed to load active delivery zones for prescription', e);
    }
  }

  String _normalizeZoneValue(String? input) {
    var value = (input ?? '').trim().toLowerCase();
    value = value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ـ', '')
        .replaceFirst(RegExp(r'^محافظة\s+'), '')
        .replaceFirst(RegExp(r'^مدينة\s+'), '')
        .replaceFirst(RegExp(r'^مركز\s+'), '')
        .replaceFirst(RegExp(r'^حي\s+'), '')
        .replaceFirst(RegExp(r'^منطقة\s+'), '')
        .replaceAll(RegExp(r'[\-–—_,،.]'), ' ')
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

  double _calculateTotalDeliveryFee() {
    if (_selectedAddress == null) return 0.0;
    final matchedZone = _resolveDeliveryZone(_selectedAddress);
    if (matchedZone != null) return matchedZone.fee;
    
    try {
      final settingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
      return settingsProvider.appSettings.appDeliveryBaseFee;
    } catch (e) {
      AppLogger.warning('AppSettingsProvider not available, defaulting to 0.0 delivery fee', e);
      return 0.0;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedImage = pickedFile;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      AppLogger.error('Error picking image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في اختيار الصورة. يرجى التحقق من الأذونات.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر مصدر صورة الروشتة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'الكاميرا',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      _buildSourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'المعرض',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadPrescription(String userId) async {
    if (_pickedImageBytes == null || _pickedImage == null) return null;

    try {
      final fileExt = _pickedImage!.name.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'avatars/user_$userId/prescription_$timestamp.$fileExt';

      await _supabase.storage.from('profiles').uploadBinary(
            filePath,
            _pickedImageBytes!,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final publicUrl = _supabase.storage.from('profiles').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      AppLogger.error('Failed to upload prescription image', e);
      return null;
    }
  }

  Future<void> _submitOrder() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً لإرسال الطلب'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الصيدلية أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pickedImageBytes == null && _existingPrescriptionUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تصوير أو إرفاق صورة الروشتة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد عنوان التوصيل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = authProvider.currentUser!.id;

      // 1. Upload prescription image (if new image picked, otherwise reuse existing)
      String? prescriptionUrl = _existingPrescriptionUrl;
      if (_pickedImageBytes != null) {
        final uploadedUrl = await _uploadPrescription(userId);
        if (uploadedUrl == null) {
          throw Exception('فشل رفع صورة الروشتة. يرجى المحاولة لاحقاً.');
        }
        prescriptionUrl = uploadedUrl;
      }

      // 2. Extract prescription URL and notes cleanly
      final userNotes = _notesController.text.trim();

      // 3. Create the order with pending status and 0.0 total amount
      final orderGroupId = const Uuid().v4();
      final order = OrderModel(
        id: '',
        clientId: userId,
        storeId: _selectedStore!.id,
        orderGroupId: orderGroupId,
        totalAmount: 0.0,
        deliveryFee: _calculateTotalDeliveryFee(),
        taxAmount: 0.0,
        discountAmount: 0.0,
        deliveryAddress: _selectedAddress!.formattedAddress,
        deliveryLatitude: _selectedAddress!.latitude,
        deliveryLongitude: _selectedAddress!.longitude,
        deliveryNotes: userNotes.isEmpty ? null : userNotes,
        prescriptionUrl: prescriptionUrl,
        clientPhone: authProvider.currentUserProfile?.phone ?? '',
        status: OrderStatus.pending,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.pending,
        createdAt: DateTime.now(),
      );

      final newOrderId = await orderProvider.createOrder(order);
      if (newOrderId == null) {
        throw Exception(orderProvider.error ?? 'تعذر إنشاء الطلب حالياً');
      }

      // 4. Create dummy order item to satisfy validation
      final dummyItem = {
        'order_id': newOrderId,
        'product_id': null,
        'product_name': 'طلب روشتة صيدلية',
        'product_price': 0.0,
        'quantity': 1,
        'total_price': 0.0,
      };

      await _supabase.from('order_items').insert(dummyItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الروشتة بنجاح! جاري المراجعة من الصيدلي.'),
            backgroundColor: Colors.green,
          ),
        );

        // Redirect to order tracking
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.orderTracking,
          arguments: {
            'orderId': newOrderId,
            'orderGroupId': orderGroupId,
          },
        );
      }
    } catch (e) {
      AppLogger.error('Failed to submit prescription order', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final pharmacies = storeProvider.stores.where((store) {
      final cat = store.category?.trim() ?? '';
      final name = store.name.trim();
      return cat == 'صيدلية' ||
          cat == '27fb2938-4949-4720-bbe1-56816279db0a' ||
          name.contains('صيدلية') ||
          name.contains('صيدليه');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلب أدوية بروشتة 📄',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _isLoadingStores
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pharmacy Selection
                      _buildSectionHeader('الصيدلية المستهدفة', Icons.local_pharmacy_rounded),
                      _buildPharmacyCard(pharmacies),
                      const SizedBox(height: 24),
  
                      // Prescription Capture
                      _buildSectionHeader('صورة الروشتة', Icons.image_search_rounded),
                      _buildPrescriptionPickerCard(),
                      const SizedBox(height: 24),
  
                      // Address Selection
                      _buildSectionHeader('عنوان التوصيل', Icons.location_on_rounded),
                      _buildAddressSelector(),
                      _buildDeliveryFeeSummary(),
                      const SizedBox(height: 24),
  
                      // Delivery Notes
                      _buildSectionHeader('ملاحظات إضافية', Icons.note_alt_rounded),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'اكتب أي ملاحظات إضافية هنا (مثل: أقبل البدائل في حال عدم توفر الدواء الأصلي)',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 32),
  
                      // Submit Button
                      CustomButton(
                        text: 'إرسال الطلب للصيدلية',
                        isLoading: _isSubmitting,
                        onPressed: _submitOrder,
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard(List<StoreModel> pharmacies) {
    if (_selectedStore != null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedStore!.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedStore!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, color: AppColors.grey),
                        ),
                      )
                    : const Icon(Icons.store, color: AppColors.grey, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStore!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStore!.address,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.initialStore == null)
                TextButton(
                  onPressed: () => _showPharmacySelectionDialog(pharmacies),
                  child: const Text('تغيير'),
                ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showPharmacySelectionDialog(pharmacies),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.local_pharmacy_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'اضغط هنا لتحديد الصيدلية المطلوبة',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showPharmacySelectionDialog(List<StoreModel> pharmacies) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اختر الصيدلية', style: TextStyle(fontWeight: FontWeight.bold)),
            content: pharmacies.isEmpty
                ? const Text('عذراً، لا توجد صيدليات متاحة حالياً.')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pharmacies.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final store = pharmacies[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade100,
                            backgroundImage: store.imageUrl != null ? NetworkImage(store.imageUrl!) : null,
                            child: store.imageUrl == null ? const Icon(Icons.store, color: AppColors.grey) : null,
                          ),
                          title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(store.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            setState(() {
                              _selectedStore = store;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionPickerCard() {
    if (_pickedImageBytes != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: Image.memory(
                _pickedImageBytes!,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _pickedImage = null;
                      _pickedImageBytes = null;
                    });
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('تغيير الصورة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_existingPrescriptionUrl != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: Image.network(
                _existingPrescriptionUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _existingPrescriptionUrl = null;
                    });
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('تغيير الصورة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _showImageSourceSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_enhance_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'التقط صورة للروشتة أو اخترها من المعرض',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'تأكد من وضوح الصورة وتفاصيل أسماء الأدوية',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSelector() {
    if (_isLoadingAddresses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedAddresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          children: [
            const Text(
              'لم تقم بإضافة أي عناوين توصيل بعد.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.addresses);
                _loadAddresses();
              },
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('إضافة عنوان جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AddressModel>(
            value: _selectedAddress,
            isExpanded: true,
            hint: const Text('اختر عنوان التوصيل'),
            items: _savedAddresses.map((AddressModel address) {
              return DropdownMenuItem<AddressModel>(
                value: address,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            address.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            address.formattedAddress,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (AddressModel? newValue) {
              setState(() {
                _selectedAddress = newValue;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryFeeSummary() {
    if (_selectedAddress == null) return const SizedBox.shrink();

    final fee = _calculateTotalDeliveryFee();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'سعر التوصيل المقدر:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Text(
            '${fee.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
