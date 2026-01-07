import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/navigation_service.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/address_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/validators.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/services/location_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _notesController = TextEditingController();
  late SettingsProvider _settingsProvider;

  // العنوان المحدد
  AddressModel? _selectedAddress;
  List<AddressModel> _savedAddresses = [];

  // من يستلم الطلب
  bool _isReceiverAccountOwner = true; // true = صاحب الحساب, false = شخص آخر
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();

  // الكوبونات
  final _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  bool _isApplyingCoupon = false;
  final Map<String, double> _merchantDiscounts = {}; // خصم لكل متجر

  // Swipe to confirm
  double _swipeValue = 0.0;
  final double _swipeThreshold = 0.85;

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _loadSavedAddresses();
  }

  /// حساب إجمالي رسوم التوصيل من جميع المتاجر
  double _calculateTotalDeliveryFee(CartProvider cartProvider) {
    final processedStores = <String>{};
    double totalDeliveryFee = 0;
    bool hasAppDelivery = false;

    // الحصول على إعدادات التطبيق
    final appDeliveryFee = _settingsProvider.appSettings.appDeliveryBaseFee;

    // تحليل كل منتج في السلة
    for (var item in cartProvider.cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product != null && product['stores'] != null) {
        final store = product['stores'] as Map<String, dynamic>;
        final storeId = store['id'] as String? ?? '';

        // تجنب حساب نفس المتجر مرتين
        if (processedStores.contains(storeId)) continue;
        processedStores.add(storeId);

        // الحقول الصحيحة: delivery_mode و delivery_fee
        final deliveryMode = store['delivery_mode'] as String? ?? 'store';

        if (deliveryMode == 'store') {
          // توصيل المتجر - استخدم delivery_fee
          final fee = (store['delivery_fee'] as num?)?.toDouble() ?? 0.0;
          totalDeliveryFee += fee;
        } else {
          // توصيل التطبيق - نسجل أنه موجود فقط
          hasAppDelivery = true;
        }
      }
    }

    // إضافة رسوم توصيل التطبيق مرة واحدة فقط
    if (hasAppDelivery) {
      totalDeliveryFee += appDeliveryFee;
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
    if (address == null ||
        address.latitude == null ||
        address.longitude == null) {
      return [];
    }

    final storesOutOfRange = <String>[];
    final processedStores = <String>{};

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
            // إذا لم تكن هناك بيانات موقع للمتجر، نعتبره خارج النطاق
            AppLogger.warning('  ⚠️ لا توجد بيانات موقع للمتجر');
            storesOutOfRange.add(storeName);
          }
        } catch (e) {
          AppLogger.error('  ❌ خطأ في التحقق من المتجر: $e');
          // في حالة الخطأ، نضيف المتجر للقائمة احتياطياً
          storesOutOfRange.add(storeName);
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
          .select('*, merchants(id, name)')
          .eq('code', couponCode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('كوبون غير صحيح');
      }

      final coupon = response;

      // التحقق من صلاحية الكوبون
      final expiryDate = DateTime.parse(coupon['expiry_date']);
      if (expiryDate.isBefore(DateTime.now())) {
        throw Exception('هذا الكوبون منتهي الصلاحية');
      }

      // التحقق من الحد الأقصى للاستخدام
      if (coupon['max_uses'] != null &&
          coupon['current_uses'] >= coupon['max_uses']) {
        throw Exception('تم استخدام هذا الكوبون بالحد الأقصى');
      }

      // إذا كان الكوبون خاص بتاجر معين
      if (!mounted) return;
      if (coupon['merchant_id'] != null) {
        await _applyMerchantCoupon(coupon, cartProvider);
      } else {
        // كوبون عام
        await _applyGlobalCoupon(coupon, cartProvider);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplyingCoupon = false);
      }
    }
  }

  // تطبيق كوبون خاص بتاجر
  Future<void> _applyMerchantCoupon(
    Map<String, dynamic> coupon,
    CartProvider cartProvider,
  ) async {
    if (!mounted) return;

    final merchantId = coupon['merchant_id'];
    final merchantName = coupon['merchants']?['name'] ?? 'التاجر';

    // فلترة منتجات هذا التاجر فقط
    final merchantItems = cartProvider.cartItems.where((item) {
      final product = item['product'] as Map<String, dynamic>;
      final store = product['stores'] as Map<String, dynamic>?;
      return store?['merchant_id'] == merchantId;
    }).toList();

    if (merchantItems.isEmpty) {
      throw Exception('لا توجد منتجات من $merchantName في السلة');
    }

    // حساب مجموع منتجات التاجر
    double merchantSubtotal = 0;
    for (var item in merchantItems) {
      merchantSubtotal += (item['total_price'] as num).toDouble();
    }

    // التحقق من الحد الأدنى
    final minOrderAmount = (coupon['min_order_amount'] as num?)?.toDouble();
    if (minOrderAmount != null && merchantSubtotal < minOrderAmount) {
      throw Exception(
        'الحد الأدنى لطلب $merchantName هو ${minOrderAmount.toStringAsFixed(2)} ج.م',
      );
    }

    // حساب الخصم
    double discount = 0;
    if (coupon['discount_type'] == 'percentage') {
      discount = merchantSubtotal * (coupon['discount_value'] / 100);
      if (coupon['max_discount'] != null) {
        final maxDiscount = (coupon['max_discount'] as num).toDouble();
        discount = discount > maxDiscount ? maxDiscount : discount;
      }
    } else {
      discount = (coupon['discount_value'] as num).toDouble();
    }

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

    // التحقق من الحد الأدنى
    final minOrderAmount = (coupon['min_order_amount'] as num?)?.toDouble();
    if (minOrderAmount != null && subtotal < minOrderAmount) {
      throw Exception(
        'الحد الأدنى للطلب هو ${minOrderAmount.toStringAsFixed(2)} ج.م',
      );
    }

    // حساب الخصم
    double discount = 0;
    if (coupon['discount_type'] == 'percentage') {
      discount = subtotal * (coupon['discount_value'] / 100);
      if (coupon['max_discount'] != null) {
        final maxDiscount = (coupon['max_discount'] as num).toDouble();
        discount = discount > maxDiscount ? maxDiscount : discount;
      }
    } else {
      discount = (coupon['discount_value'] as num).toDouble();
    }

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
                      onTap: () async {
                        Navigator.pop(sheetContext);

                        // الحصول على معلومات جميع المتاجر من السلة
                        final cartProvider = Provider.of<CartProvider>(
                          context,
                          listen: false,
                        );

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdvancedMapScreen(
                              userType: MapUserType.customer,
                              actionType: MapActionType.pickLocation,
                              onLocationSelected: (position, address) async {
                                if (mounted) {
                                  // إنشاء AddressModel مؤقت للتحقق من نطاق التوصيل
                                  final tempAddress = AddressModel(
                                    id: '',
                                    clientId: '',
                                    label: label,
                                    city: '',
                                    governorate: '',
                                    street: street,
                                    buildingNumber: buildingNumber,
                                    floorNumber: floor ?? '',
                                    apartmentNumber: apartment ?? '',
                                    notes: additionalDirections ?? '',
                                    latitude: selectedLocation.latitude,
                                    longitude: selectedLocation.longitude,
                                    isDefault: false,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  );

                                  // التحقق من جميع المتاجر في السلة
                                  final storesOutOfRange =
                                      await _getStoresOutOfRange(
                                        cartProvider,
                                        tempAddress,
                                      );

                                  if (storesOutOfRange.isNotEmpty) {
                                    // عرض رسالة تحذيرية
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'الموقع المحدد على الخريطة',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[900],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'المتاجر التالية لا توصل لهذا العنوان:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...storesOutOfRange.map(
                                              (storeName) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.store,
                                                      size: 16,
                                                      color: Colors.orange[700],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text('• $storeName'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('حسناً'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return; // لا نحفظ العنوان
                                  }

                                  // جميع المتاجر ضمن النطاق - احفظ العنوان
                                  setState(() {
                                    _selectedAddress = AddressModel(
                                      id: DateTime.now().millisecondsSinceEpoch
                                          .toString(),
                                      clientId:
                                          _supabase.auth.currentUser?.id ?? '',
                                      label: label,
                                      governorate: '',
                                      street: street,
                                      city: '',
                                      buildingNumber: buildingNumber,
                                      floorNumber: floor ?? '',
                                      apartmentNumber: apartment ?? '',
                                      notes: additionalDirections ?? '',
                                      latitude: position.latitude,
                                      longitude: position.longitude,
                                      isDefault: false,
                                      createdAt: DateTime.now(),
                                    );
                                  });

                                  AppLogger.info(
                                    '✅ تم حفظ موقع التوصيل: $address',
                                  );

                                  // ملاحظة: لا نحتاج Navigator.pop هنا
                                  // لأن _confirmLocation في AdvancedMapScreen تتولى الإغلاق
                                }
                              },
                            ),
                          ),
                        );
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
          '${address.city}, ${address.street}',
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
            Navigator.pop(context); // إغلاق قائمة العناوين أولاً
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
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
                      address.formattedAddress,
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
          setState(() {
            _selectedAddress = address;
          });
          Navigator.pop(context);
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

  @override
  void dispose() {
    _notesController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('عملية الدفع'), centerTitle: true),
      body: SafeArea(
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
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
                                            : 'التغيير لنقطة نون / مركز استلام',
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
                                        ? '${_selectedAddress!.city}, ${_selectedAddress!.street}...'
                                        : 'اضغط لاختيار أو إضافة عنوان',
                                    style: theme.textTheme.bodyLarge?.copyWith(
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
                                    ? colorScheme.primary.withValues(alpha: 0.1)
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
                                    style: theme.textTheme.bodyLarge?.copyWith(
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _isReceiverAccountOwner
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.7,
                                            )
                                          : Colors.grey.withValues(alpha: 0.5),
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
                                    ? colorScheme.primary.withValues(alpha: 0.1)
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
                                    style: theme.textTheme.bodyLarge?.copyWith(
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: !_isReceiverAccountOwner
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.7,
                                            )
                                          : Colors.grey.withValues(alpha: 0.5),
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

    // الحصول على رسوم التوصيل من إعدادات التطبيق
    final appDeliveryFee = appDeliveryCount.isNotEmpty
        ? _settingsProvider.appSettings.appDeliveryBaseFee
        : 0.0;

    // حساب إجمالي رسوم التوصيل
    final totalDeliveryFee = _calculateTotalDeliveryFee(cartProvider);

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
        ],

        // إجمالي رسوم التوصيل
        if (totalDeliveryFee > 0) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'إجمالي رسوم التوصيل',
            totalDeliveryFee,
            colorScheme,
            valueColor: theme.colorScheme.primary,
          ),
        ],
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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

    if (_selectedAddress == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار عنوان التوصيل'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _swipeValue = 0.0);
      return;
    }

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      if (cartProvider.cartItems.isEmpty) {
        messenger?.showSnackBar(
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
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
                    _selectedAddress!.formattedAddress,
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
        }
        setState(() => _swipeValue = 0.0);
        return;
      }

      // تجميع العناصر حسب المتجر
      Map<String, List<Map<String, dynamic>>> itemsByStore = {};

      for (var item in cartProvider.cartItems) {
        String storeId = item['product']['store_id'];
        if (!itemsByStore.containsKey(storeId)) {
          itemsByStore[storeId] = [];
        }
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
            deliveryFee = _settingsProvider.appSettings.appDeliveryBaseFee;
          }
        }

        double cashFee = 0.0; // إزالة رسوم الكاش لأنها غير موجودة في السلة
        double taxAmount = 0.0; // إزالة الضريبة لأنها غير موجودة في السلة

        // إنشاء الطلب
        final order = OrderModel(
          id: '',
          clientId: authProvider.currentUser!.id,
          storeId: storeId,
          totalAmount: storeSubtotal + deliveryFee + cashFee + taxAmount,
          deliveryFee: deliveryFee,
          taxAmount: taxAmount,
          deliveryAddress: _selectedAddress!.formattedAddress,
          status: OrderStatus.pending,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.pending,
          createdAt: DateTime.now(),
        );

        String? newOrderId = await orderProvider.createOrder(order);
        if (newOrderId == null) {
          throw Exception('فشل في إنشاء الطلب');
        }

        // إضافة عناصر الطلب
        for (var item in storeItems) {
          await _supabase.from('order_items').insert({
            'order_id': newOrderId,
            'product_id': item['product_id'],
            'product_name': item['product']['name'],
            'product_price': item['product']['price'],
            'quantity': item['quantity'],
            'total_price': item['total_price'],
          });
        }
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

      // الانتقال إلى صفحة تاريخ الطلبات
      navState?.pushReplacementNamed(AppRoutes.orderHistory);
    } catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ: $e';

        // رسالة خطأ مخصصة لمشكلة RLS
        if (e.toString().contains('row-level security')) {
          errorMessage = 'خطأ في الصلاحيات. يرجى التواصل مع الدعم الفني.';
        }

        messenger?.showSnackBar(
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
