import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';

class OrderDeliveryScreen extends StatefulWidget {
  final String orderId;

  const OrderDeliveryScreen({required this.orderId, super.key});

  @override
  State<OrderDeliveryScreen> createState() => _OrderDeliveryScreenState();
}

class _OrderDeliveryScreenState extends State<OrderDeliveryScreen> {
  OrderModel? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
    });
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.getOrderById(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = orderProvider.selectedOrder;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('فشل تحميل تفاصيل الطلب: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحميل تفاصيل الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تتبع التوصيل'), centerTitle: true),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : (_order == null
                ? Center(child: Text('فشل تحميل تفاصيل الطلب'))
                : _buildDeliveryInterface()),
    );
  }

  Widget _buildDeliveryInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMapSection(),
          const SizedBox(height: 24),
          _buildOrderInfo(),
          const SizedBox(height: 24),
          _buildCustomerInfo(),
          const SizedBox(height: 24),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final orderStatus = _parseOrderStatus(_order!.status.value);

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.map, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text('خريطة التتبع التفاعلية'),
                Text(
                  '(سيتم دمجها مع خدمة الخرائط)',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Chip(
              label: Text(
                _getStatusText(orderStatus),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _getStatusColor(orderStatus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    final order = _order!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('رقم الطلب:', '#${order.id.substring(0, 8)}'),
            _buildInfoRow('وقت الطلب:', order.createdAtFormatted),
            _buildInfoRow(
              'المجموع:',
              '${order.totalAmount.toStringAsFixed(2)} ر.س',
            ),
            const SizedBox(height: 8),
            const Text(
              'ملاحظات الطلب:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(order.notes ?? 'لا توجد ملاحظات'),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    final address = _order!.deliveryAddress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات التوصيل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('عنوان التوصيل:', address),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('اتصال'),
                    onPressed: () => _callCustomer(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, size: 20),
                    label: const Text('رسالة'),
                    onPressed: () => _messageCustomer(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    final orderStatus = _parseOrderStatus(_order!.status.value);

    return Column(
      children: [
        if (orderStatus == OrderStatus.ready)
          _buildActionButton(
            'تم استلام الطلب من المتجر',
            Icons.inventory,
            Colors.blue,
            () => _updateOrderStatus(OrderStatus.onTheWay),
          ),
        if (orderStatus == OrderStatus.onTheWay)
          _buildActionButton(
            'تم تسليم الطلب للعميل',
            Icons.check_circle,
            Colors.green,
            () => _updateOrderStatus(OrderStatus.delivered),
          ),
        if (orderStatus == OrderStatus.delivered)
          _buildActionButton(
            'تم التوصيل بنجاح',
            Icons.verified,
            Colors.green,
            () {},
          ),
        const SizedBox(height: 8),
        _buildActionButton(
          'الإبلاغ عن مشكلة',
          Icons.warning,
          Colors.red,
          _reportProblem,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(text),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  OrderStatus _parseOrderStatus(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
      case 'in_preparation':
        return OrderStatus.inPreparation;
      case 'ready':
        return OrderStatus.ready;
      case 'picked_up':
      case 'in_transit':
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.grey;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.inPreparation:
        return Colors.orange;
      case OrderStatus.ready:
        return Colors.purple;
      case OrderStatus.onTheWay:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.inPreparation:
        return 'يتم التحضير';
      case OrderStatus.ready:
        return 'جاهز للاستلام';
      case OrderStatus.onTheWay:
        return 'في الطريق';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  void _updateOrderStatus(OrderStatus newStatus) async {
    try {
      // await Provider.of<OrderProvider>(context, listen: false)
      //     .updateOrderStatus(_order!.id, newStatus.dbValue);
      if (kDebugMode) {
        print('تحديث حالة الطلب: ${_order!.id} إلى ${newStatus.dbValue}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث حالة الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrderDetails();
    } catch (e) {
      if (kDebugMode) {
        print('فشل تحديث حالة الطلب: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _callCustomer() {
    if (kDebugMode) {
      print('اتصال بالعميل');
    }
    // تنفيذ الاتصال بالعميل
  }

  void _messageCustomer() {
    if (kDebugMode) {
      print('إرسال رسالة للعميل');
    }
    // تنفيذ إرسال رسالة للعميل
  }

  void _reportProblem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإبلاغ عن مشكلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر نوع المشكلة:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              items:
                  [
                        'عنوان غير صحيح',
                        'عميل غير متاح',
                        'مشكلة في الدفع',
                        'منتج ناقص',
                        'أخرى',
                      ]
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged: (value) {},
              decoration: const InputDecoration(
                labelText: 'نوع المشكلة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف المشكلة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم الإبلاغ عن المشكلة بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
}
