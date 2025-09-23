import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';

class OrderDeliveryScreen extends StatefulWidget {
  final String orderId;

  const OrderDeliveryScreen({required this.orderId, super.key});

  @override
  _OrderDeliveryScreenState createState() => _OrderDeliveryScreenState();
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
      await Provider.of<OrderProvider>(context, listen: false)
          .getOrderById(widget.orderId);

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      setState(() {
        _order = orderProvider.selectedOrder;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: Text('تتبع التوصيل'),
        centerTitle: true,
      ),
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
                Text('(سيتم دمجها مع خدمة الخرائط)',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (_order != null)
            Positioned(
              top: 16,
              right: 16,
              child: Chip(
                label: Text(
                  _getStatusText(_order!.status),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: _getStatusColor(_order!.status),
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
            const Text('معلومات الطلب',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('رقم الطلب:', '#${order.id.substring(0, 8)}'),
            _buildInfoRow('وقت الطلب:', _formatDateTime(order.createdAt)),
            _buildInfoRow('قيمة التوصيل:', '${order.deliveryFee.toStringAsFixed(2)} ر.س'),
            _buildInfoRow('المجموع:', '${order.total.toStringAsFixed(2)} ر.س'),
            const SizedBox(height: 8),
            const Text('المنتجات:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${item.productName} (×${item.quantity})'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    final address = _order!.shippingAddress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات العميل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('الاسم:', address.formattedAddress),
            _buildInfoRow('الهاتف:', address.phone),
            _buildInfoRow('العنوان:', address.formattedAddress),
            if (address.additionalDirections != null)
              _buildInfoRow('ملاحظات:', address.additionalDirections!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('اتصال'),
                    onPressed: () => _callCustomer(address.phone),
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
                    onPressed: () => _messageCustomer(address.phone),
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
    final status = _order!.status;
    return Column(
      children: [
        if (status == OrderStatus.assignedToCaptain)
          _buildActionButton(
            'تم استلام الطلب من المتجر',
            Icons.inventory,
            Colors.blue,
                () => _updateOrderStatus(OrderStatus.pickedUp),
          ),
        if (status == OrderStatus.pickedUp)
          _buildActionButton(
            'بدء التوصيل إلى العميل',
            Icons.directions_car,
            Colors.orange,
                () => _updateOrderStatus(OrderStatus.onTheWay),
          ),
        if (status == OrderStatus.onTheWay)
          _buildActionButton(
            'تم تسليم الطلب',
            Icons.check_circle,
            Colors.green,
                () => _updateOrderStatus(OrderStatus.delivered),
          ),
        if (status == OrderStatus.delivered)
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

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
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
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.assignedToCaptain:
        return Colors.blue;
      case OrderStatus.pickedUp:
        return Colors.orange;
      case OrderStatus.onTheWay:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.assignedToCaptain:
        return 'تم التعيين';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.onTheWay:
        return 'في الطريق';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      default:
        return 'غير معروف';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _updateOrderStatus(OrderStatus newStatus) async {
    try {
      // await Provider.of<OrderProvider>(context, listen: false)
      //     .updateOrderStatus(_order!.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث حالة الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrderDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _callCustomer(String phoneNumber) {
    // تنفيذ الاتصال بالعميل
  }

  void _messageCustomer(String phoneNumber) {
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
              items: [
                'عنوان غير صحيح',
                'عميل غير متاح',
                'مشكلة في الدفع',
                'منتج ناقص',
                'أخرى'
              ].map((value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              )).toList(),
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
