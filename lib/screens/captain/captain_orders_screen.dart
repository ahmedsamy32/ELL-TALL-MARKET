import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/widgets/order_card.dart';

class CaptainOrdersScreen extends StatefulWidget {
  final String captainId;
  final String captainName;

  const CaptainOrdersScreen({
    required this.captainId,
    required this.captainName,
    super.key,
  });

  @override
  _CaptainOrdersScreenState createState() => _CaptainOrdersScreenState();
}

class _CaptainOrdersScreenState extends State<CaptainOrdersScreen> {
  OrderStatus _selectedFilter = OrderStatus.assignedToCaptain;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchCaptainOrders(widget.captainId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.captainName), centerTitle: true),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildOrdersList(orderProvider)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final statuses = [
      OrderStatus.assignedToCaptain,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(_getStatusText(status)),
                selected: _selectedFilter == status,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = status;
                  });
                },
              ),
            );
          }).toList(),

        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final filteredOrders = provider.getOrdersByStatus(_selectedFilter);

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'لا توجد طلبات تطابق الفلتر المحدد',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return OrderCard(
          order: order,
          onTap: () {
            _showOrderDetails(order);
          },
        );
      },
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'تفاصيل الطلب #${order.id.substring(0, 8)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildDetailRow('الحالة:', _getStatusText(order.status)),
              _buildDetailRow(
                'العنوان:',
                order.shippingAddress.formattedAddress,
              ),
              _buildDetailRow('الهاتف:', order.shippingAddress.phone),
              _buildDetailRow(
                'قيمة التوصيل:',
                '${order.deliveryFee.toStringAsFixed(2)} ر.س',
              ),
              _buildDetailRow(
                'المجموع:',
                '${order.total.toStringAsFixed(2)} ر.س',
              ),
              SizedBox(height: 16),
              Text('المنتجات:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('• ${item.productName} (×${item.quantity})'),
                ),
              ),
              SizedBox(height: 24),
              if (order.status != OrderStatus.delivered)
                ElevatedButton(
                  onPressed: () =>
                      _updateOrderStatus(order, _getNextStatus(order.status)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(_getActionText(order.status)),
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
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

  String _getActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.assignedToCaptain:
        return 'تم استلام الطلب من المتجر';
      case OrderStatus.pickedUp:
        return 'بدء التوصيل إلى العميل';
      case OrderStatus.onTheWay:
        return 'تم تسليم الطلب';
      default:
        return 'تحديث';
    }
  }

  OrderStatus _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.assignedToCaptain:
        return OrderStatus.pickedUp;
      case OrderStatus.pickedUp:
        return OrderStatus.onTheWay;
      case OrderStatus.onTheWay:
        return OrderStatus.delivered;
      default:
        return currentStatus;
    }
  }

  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    try {
      Navigator.pop(context);
      // await Provider.of<OrderProvider>(context, listen: false)
      //     .updateOrderStatus(order.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
