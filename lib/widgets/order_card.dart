import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusExtension.fromDbValue(order.status.value);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'طلب من ${order.storeName ?? "متجر"}, الحالة: ${status.displayName}, المبلغ: ${order.totalAmount.toStringAsFixed(2)} ج.م',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderHeader(order: order),
                const SizedBox(height: 12),
                _OrderContent(
                  order: order,
                  status: status,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                _OrderFooter(order: order, status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final OrderModel order;

  const _OrderHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.storeName != null) ...[
                Text(
                  order.storeName!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '#${order.orderNumber ?? order.id.substring(0, 8).toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_left_rounded, color: Colors.grey[400], size: 22),
      ],
    );
  }
}

class _OrderContent extends StatefulWidget {
  final OrderModel order;
  final OrderStatus status;
  final ColorScheme colorScheme;

  const _OrderContent({
    required this.order,
    required this.status,
    required this.colorScheme,
  });

  @override
  State<_OrderContent> createState() => _OrderContentState();
}

class _OrderContentState extends State<_OrderContent> {
  OrderItemModel? _orderItem;
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    _loadOrderItem();
  }

  Future<void> _loadOrderItem() async {
    if (_isLoadingItems) return;

    setState(() => _isLoadingItems = true);

    try {
      final items = await OrderService.getOrderItems(widget.order.id);
      AppLogger.info('Order ${widget.order.id}: loaded ${items.length} items');
      if (mounted && items.isNotEmpty) {
        setState(() {
          _orderItem = items.first;
          _isLoadingItems = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingItems = false);
        }
      }
    } catch (e) {
      AppLogger.error('Order ${widget.order.id}: error loading items', e);
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderItem != null) {
      return _CompactProductRow(
        item: _orderItem!,
        order: widget.order,
        status: widget.status,
        colorScheme: widget.colorScheme,
      );
    } else if (_isLoadingItems) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CompactProductRow extends StatelessWidget {
  final OrderItemModel item;
  final OrderModel order;
  final OrderStatus status;
  final ColorScheme colorScheme;

  const _CompactProductRow({
    required this.item,
    required this.order,
    required this.status,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductImage(productId: item.productId),
        const SizedBox(width: 12),
        Expanded(
          child: _ProductInfo(
            item: item,
            order: order,
            status: status,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? productId;

  const _ProductImage({required this.productId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: productId != null
              ? FutureBuilder<String?>(
                  future: _getProductImage(productId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey[400],
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasData && snapshot.data != null) {
                      return CachedNetworkImage(
                        imageUrl: snapshot.data!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                      );
                    }

                    return Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.grey[400],
                      size: 32,
                    );
                  },
                )
              : Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
        ),
      ),
    );
  }

  Future<String?> _getProductImage(String productId) async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('image_url')
          .eq('id', productId)
          .maybeSingle();

      if (response != null && response['image_url'] != null) {
        return response['image_url'] as String;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching product image', e);
      return null;
    }
  }
}

class _ProductInfo extends StatelessWidget {
  final OrderItemModel item;
  final OrderModel order;
  final OrderStatus status;
  final ColorScheme colorScheme;

  const _ProductInfo({
    required this.item,
    required this.order,
    required this.status,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${item.quantity}×',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.productPrice.toStringAsFixed(2)} ج.م',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatusLabel(status: status),
        const SizedBox(height: 6),
        Text(
          _formatDateArabic(order.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatDateArabic(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _OrderFooter extends StatelessWidget {
  final OrderModel order;
  final OrderStatus status;

  const _OrderFooter({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money_rounded, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            'المبلغ الإجمالي:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${order.totalAmount.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final OrderStatus status;

  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange.shade700;
      case OrderStatus.confirmed:
        return Colors.blue.shade700;
      case OrderStatus.preparing:
        return Colors.purple.shade700;
      case OrderStatus.ready:
        return Colors.teal.shade700;
      case OrderStatus.pickedUp:
        return Colors.cyan.shade700;
      case OrderStatus.inTransit:
        return Colors.indigo.shade700;
      case OrderStatus.delivered:
        return Colors.green.shade700;
      case OrderStatus.cancelled:
        return Colors.red.shade700;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      case OrderStatus.ready:
        return Icons.shopping_bag_rounded;
      case OrderStatus.pickedUp:
        return Icons.local_shipping_outlined;
      case OrderStatus.inTransit:
        return Icons.delivery_dining_rounded;
      case OrderStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }
}
