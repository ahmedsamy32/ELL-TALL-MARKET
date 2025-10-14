import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Convert OrderModel.OrderStatus to order_enums.OrderStatus
    final status = OrderStatusExtension.fromDbValue(order.status.value);
    final deliveryAddress = order.deliveryAddress;
    final hasAddress = deliveryAddress.isNotEmpty;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس البطاقة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${order.id.substring(0, 8)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              SizedBox(height: 12),

              // تاريخ الطلب
              Text(
                'التاريخ: ${_formatDate(order.createdAt)}',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),

              if (hasAddress)
                Text(
                  'العنوان: $deliveryAddress',
                  style: TextStyle(fontSize: 14),
                ),

              if (order.notes?.isNotEmpty == true) ...[
                SizedBox(height: 8),
                Text('ملاحظات: ${order.notes}', style: TextStyle(fontSize: 14)),
              ],

              SizedBox(height: 12),
              Divider(),

              // المجموع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المجموع',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.totalAmountFormatted,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    // Map status to colors
    final backgroundColor = _getStatusColor(status);
    final statusText = status.displayName;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: backgroundColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: backgroundColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.inPreparation:
        return Colors.blue;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
