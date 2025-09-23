import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  _buildStatusBadge(order.status),
                ],
              ),
              SizedBox(height: 12),

              // تاريخ الطلب
              Text(
                'التاريخ: ${_formatDate(order.createdAt)}',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),

              // المنتجات
              ...order.items
                  .take(2)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        '${item.productName} (×${item.quantity})',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

              if (order.items.length > 2)
                Text(
                  'و ${order.items.length - 2} منتجات أخرى...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),

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
                    '${order.total.toStringAsFixed(2)} ج.م',
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
    Color backgroundColor;
    String statusText;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange;
        statusText = 'قيد الانتظار';
        break;
      case OrderStatus.confirmed:
        backgroundColor = Colors.blue;
        statusText = 'تم التأكيد';
        break;
      case OrderStatus.processing:
        backgroundColor = Colors.blue;
        statusText = 'جاري التجهيز';
        break;
      case OrderStatus.readyForDelivery:
        backgroundColor = Colors.purple;
        statusText = 'جاهز للتوصيل';
        break;
      case OrderStatus.assignedToCaptain:
        backgroundColor = Colors.purple;
        statusText = 'تم التعيين';
        break;
      case OrderStatus.pickedUp:
        backgroundColor = Colors.indigo;
        statusText = 'تم الاستلام';
        break;
      case OrderStatus.onTheWay:
        backgroundColor = Colors.indigo;
        statusText = 'في الطريق';
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green;
        statusText = 'تم التوصيل';
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red;
        statusText = 'ملغي';
        break;
      case OrderStatus.refunded:
        backgroundColor = Colors.grey;
        statusText = 'تم الاسترداد';
        break;
      case OrderStatus.completed:
        backgroundColor = Colors.green;
        statusText = 'مكتمل';
        break;
    }

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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
