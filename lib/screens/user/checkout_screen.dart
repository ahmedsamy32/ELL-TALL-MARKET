import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/shipping_address.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();
  // خيار الدفع عند الاستلام فقط
  final PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);
    // Pre-fill address if available
    if (authProvider.user?.address != null) {
      _parseAndFillAddress(authProvider.user?.address ?? '');
    }
    if (authProvider.user?.name != null) {
      _nameController.text = authProvider.user?.name ?? '';
    }
    if (authProvider.user?.phone != null) {
      _phoneController.text = authProvider.user?.phone ?? '';
    }

    // إضافة listeners لتحديث العنوان الكامل تلقائياً
    _setupAddressListeners();
  }

  void _setupAddressListeners() {
    _cityController.addListener(_updateFullAddress);
    _districtController.addListener(_updateFullAddress);
    _streetController.addListener(_updateFullAddress);
    _buildingController.addListener(_updateFullAddress);
    _floorController.addListener(_updateFullAddress);
    _apartmentController.addListener(_updateFullAddress);
    _landmarkController.addListener(_updateFullAddress);
  }

  void _updateFullAddress() {
    List<String> addressParts = [];

    if (_cityController.text.isNotEmpty) {
      addressParts.add(_cityController.text);
    }
    if (_districtController.text.isNotEmpty) {
      addressParts.add(_districtController.text);
    }
    if (_streetController.text.isNotEmpty) {
      addressParts.add(_streetController.text);
    }
    if (_buildingController.text.isNotEmpty) {
      addressParts.add('مبنى ${_buildingController.text}');
    }
    if (_floorController.text.isNotEmpty) {
      addressParts.add('الطابق ${_floorController.text}');
    }
    if (_apartmentController.text.isNotEmpty) {
      addressParts.add('شقة ${_apartmentController.text}');
    }
    if (_landmarkController.text.isNotEmpty) {
      addressParts.add('بالقرب من ${_landmarkController.text}');
    }

    _addressController.text = addressParts.join('، ');
  }

  void _parseAndFillAddress(String address) {
    // تحليل العنوان المحفوظ وملء الحقول
    if (address.isNotEmpty) {
      _addressController.text = address;
      // يمكن تحسين هذا لاحقاً لتحليل أجزاء العنوان المختلفة
    }
  }

  // دالة تحديد الموقع الحالي
  Future<void> _getCurrentLocation() async {
    try {
      // التحقق من أذونات الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تم رفض أذونات الموقع')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('أذونات الموقع مرفوضة نهائياً')));
        return;
      }

      // الحصول على الموقع الحالي
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('جاري تحديد موقعك...')));

      Position position = await Geolocator.getCurrentPosition();

      // تحويل الإحداثيات إلى عنوان
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // ملء الحقول تلقائياً
        _cityController.text = place.locality ?? place.administrativeArea ?? '';
        _districtController.text = place.subLocality ?? '';
        _streetController.text = place.street ?? '';

        // إظهار رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديد موقعك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد الموقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('إتمام الطلب'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معلومات التوصيل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _nameController,
                label: 'الاسم الكامل',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  if (value.length < 11) {
                    return 'رقم الهاتف يجب أن يكون 11 أرقام على الأقل';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // عنوان التوصيل التفصيلي
              Text(
                'عنوان التوصيل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),

              // زر تحديد الموقع الحالي
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: Icon(Icons.my_location),
                  label: Text('استخدام موقعي الحالي'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'المدينة',
                      hintText: 'مثل: القاهرة، الإسكندرية، الجيزة',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال المدينة';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _districtController,
                      label: 'الحي/المنطقة',
                      hintText: 'مثل: النزهة، المعادي، الزمالك',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال الحي';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _streetController,
                label: 'اسم الشارع',
                hintText: 'مثل: شارع التحرير، شارع المعز، طريق النصر',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم الشارع';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _buildingController,
                      label: 'رقم المبنى',
                      hintText: 'مثل: 15، 23أ',
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _floorController,
                      label: 'الطابق',
                      hintText: 'مثل: 3، الأرضي',
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _apartmentController,
                      label: 'رقم الشقة',
                      hintText: 'مثل: 5، 12أ',
                      keyboardType: TextInputType.text,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _landmarkController,
                label: 'علامة مميزة قريبة (اختياري)',
                hintText: 'مثل: بجانب مسجد النور، أمام صيدلية الشفاء',
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _addressController,
                label: 'العنوان الكامل',
                maxLines: 2,
                hintText:
                    'سيتم ملء هذا الحقل تلقائياً بناءً على التفاصيل أعلاه',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال العنوان الكامل';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              CustomTextField(
                controller: _notesController,
                label: 'ملاحظات إضافية (اختياري)',
                maxLines: 3,
              ),
              SizedBox(height: 24),

              // قسم طريقة الدفع - الدفع عند الاستلام فقط
              Text(
                'طريقة الدفع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.money, color: Theme.of(context).primaryColor),
                    SizedBox(width: 12),
                    Text('الدفع عند الاستلام', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),

              SizedBox(height: 24),
              // ملخص الطلب
              _buildOrderSummary(cartProvider),
              SizedBox(height: 24),

              CustomButton(
                text: 'تأكيد الطلب',
                onPressed: () => _submitOrder(context),
                isLoading: false,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cartProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص الطلب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Divider(),
          _buildSummaryRow('إجمالي المنتجات', '${cartProvider.total} ريال'),
          _buildSummaryRow('رسوم التوصيل', '${cartProvider.deliveryFee} ريال'),
          if (cartProvider.discount > 0)
            _buildSummaryRow('الخصم', '${cartProvider.discount} ريال'),
          Divider(),
          _buildSummaryRow(
            'الإجمالي النهائي',
            '${cartProvider.finalTotal} ريال',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);

      // إنشاء عنوان شحن مفصل
      final shippingAddress = ShippingAddress(
        formattedAddress: _addressController.text,
        phone: _phoneController.text,
        city: _cityController.text,
        area: _districtController.text,
        street: _streetController.text,
        buildingNo: _buildingController.text,
        floorNo: _floorController.text,
        apartmentNo: _apartmentController.text,
        additionalDirections: _landmarkController.text.isNotEmpty
            ? 'بالقرب من ${_landmarkController.text}'
            : null,
      );

      // Convert cart items to order items
      final orderItems = cartProvider.items
          .map(
            (cartItem) => OrderItemModel(
              id: '', // Backend will generate
              orderId: '', // Backend will generate
              productId: cartItem.product.id,
              quantity: cartItem.quantity,
              unitPrice: cartItem.product.price,
              totalPrice: cartItem.product.price * cartItem.quantity,
              productName: cartItem.product.name,
              productImage: cartItem.product.images.isNotEmpty
                  ? cartItem.product.images.first
                  : '',
              notes: null,
            ),
          )
          .toList();

      // Construct OrderModel
      final order = OrderModel(
        id: '', // Backend will generate
        userId: authProvider.user?.id ?? '',
        storeId: cartProvider.items.isNotEmpty
            ? cartProvider.items.first.product.storeId
            : '',
        captainId: null,
        status: OrderStatus.pending,
        totalAmount: cartProvider.total,
        deliveryFee: cartProvider.deliveryFee,
        discountAmount: cartProvider.discount,
        finalAmount: cartProvider.finalTotal,
        shippingAddress: shippingAddress,
        paymentMethod: _paymentMethod,
        paymentStatus: PaymentStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        cancellationReason: null,
        paymentCollectedAt: null,
        paymentTransferredAt: null,
        paymentCollectedBy: null,
        items: orderItems,
      );

      final success = await orderProvider.createOrder(order);
      if (success) {
        await cartProvider.clearCart();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/orders');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء الطلب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إنشاء الطلب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
