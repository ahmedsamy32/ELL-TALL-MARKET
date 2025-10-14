import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';

class CaptainOrdersScreen extends StatefulWidget {
  final String captainId;
  final String captainName;

  const CaptainOrdersScreen({
    required this.captainId,
    required this.captainName,
    super.key,
  });

  @override
  State<CaptainOrdersScreen> createState() => _CaptainOrdersScreenState();
}

class _CaptainOrdersScreenState extends State<CaptainOrdersScreen> {
  OrderStatus _selectedFilter = OrderStatus.confirmed;

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
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.inPreparation,
      OrderStatus.ready,
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

    // فلترة الطلبات حسب الحالة المختارة
    final filteredOrders = provider.currentOrders.where((order) {
      return _parseOrderStatus(order.status.value) == _selectedFilter;
    }).toList();

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
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final orderStatus = _parseOrderStatus(order.status.value);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${order.id.substring(0, 8)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text(
                      _getStatusText(orderStatus),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(orderStatus),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text('العنوان: ${order.deliveryAddress}'),
              SizedBox(height: 4),
              Text('الملاحظات: ${order.notes ?? 'لا توجد'}'),
              SizedBox(height: 4),
              Text(
                'المجموع: ${order.totalAmount.toStringAsFixed(2)} ر.س',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final orderStatus = _parseOrderStatus(order.status.value);

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
              _buildDetailRow('رقم الطلب:', order.id.substring(0, 8)),
              _buildDetailRow('الحالة:', _getStatusText(orderStatus)),
              _buildDetailRow('العنوان:', order.deliveryAddress),
              _buildDetailRow('الملاحظات:', order.notes ?? 'لا توجد'),
              _buildDetailRow(
                'المجموع:',
                '${order.totalAmount.toStringAsFixed(2)} ر.س',
              ),
              _buildDetailRow('التاريخ:', order.createdAtFormatted),
              SizedBox(height: 24),
              if (orderStatus != OrderStatus.delivered &&
                  orderStatus != OrderStatus.cancelled)
                ElevatedButton(
                  onPressed: () =>
                      _updateOrderStatus(order, _getNextStatus(orderStatus)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(_getActionText(orderStatus)),
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
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 8),
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

  String _getActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'تأكيد الطلب';
      case OrderStatus.confirmed:
        return 'بدء التحضير';
      case OrderStatus.inPreparation:
        return 'جاهز للاستلام';
      case OrderStatus.ready:
        return 'بدء التوصيل';
      case OrderStatus.onTheWay:
        return 'تم التسليم';
      default:
        return 'تحديث';
    }
  }

  OrderStatus _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.inPreparation;
      case OrderStatus.inPreparation:
        return OrderStatus.ready;
      case OrderStatus.ready:
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
      //     .updateOrderStatus(order.id, newStatus.dbValue);
      if (kDebugMode) {
        print('تحديث حالة الطلب: ${order.id} إلى ${newStatus.dbValue}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
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
}
