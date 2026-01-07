import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';

import 'package:ell_tall_market/utils/app_colors.dart';

class CaptainDashboard extends StatefulWidget {
  const CaptainDashboard({super.key});

  @override
  State<CaptainDashboard> createState() => _CaptainDashboardState();
}

class _CaptainDashboardState extends State<CaptainDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final captainId = 'current_captain_id'; // استبدال بـ ID الكابتن الحقيقي
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchCaptainOrders(captainId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('لوحة تحكم الكابتن'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إحصائيات سريعة
            _buildQuickStats(orderProvider),
            SizedBox(height: 24),

            // الطلبات النشطة
            _buildActiveOrders(orderProvider),
            SizedBox(height: 24),

            // خريطة التوصيل
            _buildDeliveryMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(OrderProvider orderProvider) {
    final activeOrders = orderProvider.currentOrders;
    final completedOrders = orderProvider.pastOrders
        .where((order) => order.status.value == 'delivered')
        .toList();

    return GridView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      children: [
        _buildStatCard(
          title: 'الطلبات النشطة',
          value: activeOrders.length.toString(),
          icon: Icons.local_shipping,
          color: AppColors.primary,
        ),
        _buildStatCard(
          title: 'الطلبات المكتملة',
          value: completedOrders.length.toString(),
          icon: Icons.check_circle,
          color: AppColors.success,
        ),
        _buildStatCard(
          title: 'إجمالي الأرباح',
          value: _calculateTotalEarnings(completedOrders).toStringAsFixed(2),
          icon: Icons.attach_money,
          color: AppColors.info,
        ),
        _buildStatCard(
          title: 'التقييم',
          value: '4.8/5',
          icon: Icons.star,
          color: AppColors.warning,
        ),
      ],
    );
  }

  double _calculateTotalEarnings(List<OrderModel> orders) {
    return orders.fold(
      0.0,
      (sum, order) => sum + (order.totalAmount * 0.1), // 10% عمولة للكابتن
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders(OrderProvider orderProvider) {
    final activeOrders = orderProvider.currentOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الطلبات النشطة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        activeOrders.isEmpty
            ? _buildEmptyOrders()
            : Column(
                children: activeOrders
                    .map((order) => _buildOrderCard(order))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات نشطة حالياً', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'سيتم إعلامك عند وجود طلبات جديدة',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    // Convert OrderModel.OrderStatus to OrderEnums.OrderStatus
    final orderStatus = _parseOrderStatus(order.status.value);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
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
            SizedBox(height: 12),
            Text('العنوان: ${order.deliveryAddress}'),
            SizedBox(height: 8),
            Text('الملاحظات: ${order.notes ?? 'لا توجد'}'),
            SizedBox(height: 8),
            Text('إجمالي الطلب: ${order.totalAmount.toStringAsFixed(2)} ر.س'),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _updateOrderStatus(order, _getNextStatus(orderStatus)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_getActionText(orderStatus)),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.phone),
                  onPressed: () => _callCustomer(''),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'خريطة التوصيل',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text('خريطة التوصيل التفاعلية'),
                Text(
                  '(ستظهر هنا عند وجود طلبات نشطة)',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  OrderStatus _parseOrderStatus(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_preparation':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'on_the_way':
        return OrderStatus.inTransit;
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
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.ready:
        return Colors.purple;
      case OrderStatus.pickedUp:
        return Colors.cyan;
      case OrderStatus.inTransit:
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
      case OrderStatus.preparing:
        return 'يتم التحضير';
      case OrderStatus.ready:
        return 'جاهز للاستلام';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.inTransit:
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
      case OrderStatus.preparing:
        return 'جاهز للاستلام';
      case OrderStatus.ready:
        return 'بدء التوصيل';
      case OrderStatus.pickedUp:
        return 'تم الاستلام والاستلام';
      case OrderStatus.inTransit:
        return 'تم التسليم';
      case OrderStatus.delivered:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  OrderStatus _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.inTransit;
      case OrderStatus.inTransit:
        return OrderStatus.delivered;
      default:
        return currentStatus;
    }
  }

  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    try {
      // await Provider.of<OrderProvider>(context, listen: false)
      //     .updateOrderStatus(order.id, newStatus.dbValue);
      AppLogger.info('تحديث حالة الطلب: ${order.id} إلى ${newStatus.dbValue}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.error('فشل تحديث حالة الطلب', e);
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
    AppLogger.info('اتصال بالعميل: $phoneNumber');
  }
}
