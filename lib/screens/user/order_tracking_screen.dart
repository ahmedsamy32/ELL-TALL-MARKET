import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/providers/order_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({required this.orderId, super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).getOrderById(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final order = provider.selectedOrder;
        final isLoading = provider.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: Text('تتبع الطلب #${widget.orderId.substring(0, 8)}'),
            centerTitle: true,
          ),
          body: isLoading
              ? Center(child: CircularProgressIndicator())
              : order == null
              ? _buildEmptyState()
              : _buildTrackingContent(order),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text('لم يتم العثور على بيانات الطلب'),
        ],
      ),
    );
  }

  Widget _buildTrackingContent(OrderModel order) {
    // Convert OrderModel.OrderStatus to order_enums.OrderStatus
    final status = OrderStatusExtension.fromDbValue(order.status.value);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(status),
          SizedBox(height: 24),
          _buildOrderDetails(order, status),
          SizedBox(height: 24),
          _buildMetaInfo(order),
        ],
      ),
    );
  }

  Widget _buildStatusSection(OrderStatus status) {
    final statuses = OrderStatus.values;
    final currentIndex = statuses.indexOf(status);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حالة الطلب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Column(
              children: statuses.asMap().entries.map((entry) {
                final index = entry.key;
                final entryStatus = entry.value;
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    entryStatus.displayName,
                    style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: isCurrent ? Text('الحالة الحالية') : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(OrderModel order, OrderStatus status) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الطلب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildDetailRow('الحالة الحالية', status.displayName),
            _buildDetailRow(
              'العنوان',
              order.deliveryAddress,
            ), // deliveryAddress is non-null
            _buildDetailRow('الإجمالي', order.totalAmountFormatted),
            if (order.notes?.isNotEmpty == true)
              _buildDetailRow('ملاحظات', order.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo(OrderModel order) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات إضافية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildDetailRow('تم الإنشاء في', order.createdAtFormatted),
            _buildDetailRow('آخر تحديث', order.updatedAtFormatted),
            _buildDetailRow('رقم الطلب', order.id),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
