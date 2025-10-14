import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/widgets/order_card.dart';

class MerchantOrdersScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const MerchantOrdersScreen({
    required this.merchantId,
    required this.merchantName,
    super.key,
  });

  @override
  _MerchantOrdersScreenState createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  OrderStatus _selectedFilter = OrderStatus.pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchMerchantOrders(widget.merchantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.merchantName), centerTitle: true),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildOrdersList(orderProvider)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: OrderStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(status.displayName),
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

    final filteredOrders = provider.orders.where((order) {
      final status = OrderStatusExtension.fromDbValue(order.status.value);
      return status == _selectedFilter;
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
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
            _showOrderActions(order);
          },
        );
      },
    );
  }

  void _showOrderActions(OrderModel order) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final orderStatus = OrderStatusExtension.fromDbValue(
          order.status.value,
        );
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إجراءات الطلب #${order.id.substring(0, 8)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              if (orderStatus == OrderStatus.pending) ...[
                _buildActionButton(
                  'قبول الطلب',
                  Icons.check,
                  Colors.green,
                  () => _updateOrderStatus(order, OrderStatus.confirmed),
                ),
                _buildActionButton(
                  'رفض الطلب',
                  Icons.close,
                  Colors.red,
                  () => _updateOrderStatus(order, OrderStatus.cancelled),
                ),
              ],
              if (orderStatus == OrderStatus.confirmed)
                _buildActionButton(
                  'قيد التحضير',
                  Icons.inventory,
                  Colors.blue,
                  () => _updateOrderStatus(order, OrderStatus.inPreparation),
                ),
              if (orderStatus == OrderStatus.inPreparation)
                _buildActionButton(
                  'تم التجهيز',
                  Icons.local_shipping,
                  Colors.purple,
                  () => _updateOrderStatus(order, OrderStatus.ready),
                ),
              if (orderStatus == OrderStatus.ready)
                _buildActionButton(
                  'إرسال مع الكابتن',
                  Icons.delivery_dining,
                  Colors.orange,
                  () => _updateOrderStatus(order, OrderStatus.onTheWay),
                ),
              if (orderStatus == OrderStatus.onTheWay)
                _buildActionButton(
                  'تم التسليم للعميل',
                  Icons.check_circle,
                  Colors.green,
                  () => _updateOrderStatus(order, OrderStatus.delivered),
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      onTap: onPressed,
    );
  }

  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    try {
      Navigator.pop(context);
      await Provider.of<OrderProvider>(
        context,
        listen: false,
      ).updateOrderStatus(order.id, newStatus.dbValue);
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
