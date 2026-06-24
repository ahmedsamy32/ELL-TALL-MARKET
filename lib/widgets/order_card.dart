import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'dart:async';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final bool showAutoAcceptCountdown;
  final Duration autoAcceptDuration;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showAutoAcceptCountdown = false,
    this.autoAcceptDuration = const Duration(seconds: 90),
  });

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusExtension.fromDbValue(order.status.value);
    final colorScheme = Theme.of(context).colorScheme;
    final showCountdown =
        showAutoAcceptCountdown && status == OrderStatus.pending;

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
                if (showCountdown) ...[
                  const SizedBox(height: 8),
                  _AutoAcceptCountdown(
                    createdAt: order.createdAt,
                    duration: autoAcceptDuration,
                  ),
                ],
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

class _AutoAcceptCountdown extends StatefulWidget {
  final DateTime createdAt;
  final Duration duration;

  const _AutoAcceptCountdown({
    required this.createdAt,
    required this.duration,
  });

  @override
  State<_AutoAcceptCountdown> createState() => _AutoAcceptCountdownState();
}

class _AutoAcceptCountdownState extends State<_AutoAcceptCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant _AutoAcceptCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createdAt != widget.createdAt ||
        oldWidget.duration != widget.duration) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final elapsed = DateTime.now().difference(widget.createdAt);
    final remaining = widget.duration - elapsed;
    final clamped = remaining.isNegative ? Duration.zero : remaining;

    if (!mounted) return;
    setState(() => _remaining = clamped);

    if (clamped == Duration.zero) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.duration.inSeconds == 0 ? 1 : widget.duration.inSeconds;
    final progress = (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.orange.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'قبول تلقائي خلال ${_formatRemaining(_remaining)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.orange[700],
          ),
        ),
      ],
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
  List<OrderItemModel>? _orderItems;
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.items.isNotEmpty) {
      _orderItems = widget.order.items;
    } else {
      _loadOrderItems();
    }
  }

  Future<void> _loadOrderItems() async {
    if (_isLoadingItems) return;

    setState(() => _isLoadingItems = true);

    try {
      final items = await OrderService.getOrderItems(widget.order.id);
      AppLogger.info('Order ${widget.order.id}: loaded ${items.length} items');
      if (mounted) {
        setState(() {
          _orderItems = items.isNotEmpty ? items : null;
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
    if (_orderItems != null && _orderItems!.isNotEmpty) {
      return _CompactOrderItemsList(
        items: _orderItems!,
        order: widget.order,
        status: widget.status,
        colorScheme: widget.colorScheme,
      );
    } else if (_isLoadingItems) {
      return _OrderItemRowShimmer(colorScheme: widget.colorScheme);
    }

    // Fallback: always show a summary row even if items are not accessible.
    return _OrderSummaryRow(order: widget.order, status: widget.status);
  }
}

class _CompactOrderItemsList extends StatelessWidget {
  final List<OrderItemModel> items;
  final OrderModel order;
  final OrderStatus status;
  final ColorScheme colorScheme;

  const _CompactOrderItemsList({
    required this.items,
    required this.order,
    required this.status,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image or Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child:
                      item.productImage != null && item.productImage!.isNotEmpty
                      ? Image.network(
                          item.productImage!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.local_mall,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.local_mall,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity}× ${item.productPrice.toStringAsFixed(2)} ج.م',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (item.selectedOptions != null &&
                          item.selectedOptions!.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final Map<String, dynamic> selectedOpts = Map<String, dynamic>.from(item.selectedOptions ?? {});
                            final attributes = selectedOpts.entries
                                .where((e) => e.key != 'addons')
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' | ');
                            final addonsList = selectedOpts['addons'] as List<dynamic>?;
                            final addonsText = addonsList != null && addonsList.isNotEmpty
                                ? 'إضافات: ${addonsList.map((a) => a['name']).join(', ')}'
                                : '';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (attributes.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    attributes,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                if (addonsText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    addonsText,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${item.totalPrice.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _OrderItemRowShimmer extends StatelessWidget {
  final ColorScheme colorScheme;

  const _OrderItemRowShimmer({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    Widget box({required double width, required double height}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return AppShimmer.wrap(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: double.infinity, height: 14),
                  const SizedBox(height: 8),
                  box(width: 140, height: 12),
                  const SizedBox(height: 10),
                  box(width: 110, height: 22),
                  const SizedBox(height: 8),
                  box(width: 120, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryRow extends StatelessWidget {
  final OrderModel order;
  final OrderStatus status;

  const _OrderSummaryRow({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final title =
        firstItem?.productName ??
        (order.productNames.isNotEmpty ? order.productNames.first : 'طلب جديد');

    final address = order.deliveryAddress.trim();
    final addressLine = address.isNotEmpty ? address : 'عنوان غير متاح';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Icon(
              Icons.receipt_long,
              color: colorScheme.outline,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                addressLine,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    final hasDeliveryFee = order.deliveryFee > 0;
    final hasDiscount = order.discountAmount > 0;
    
    // إجمالي المنتجات قبل خصم الكوبون
    final productsOnlyTotal =
        (order.totalAmount - order.deliveryFee - order.taxAmount + order.discountAmount).clamp(
          0.0,
          double.infinity,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 17,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                'إجمالي المنتجات:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${productsOnlyTotal.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 17,
                  color: Colors.red[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'خصم الكوبون ${order.couponCode != null ? "(${order.couponCode})" : ""}:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${order.discountAmount.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          if (hasDeliveryFee) ...[
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 17,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'رسوم التوصيل:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.deliveryFee.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Icon(
                Icons.attach_money_rounded,
                size: 18,
                color: Colors.grey[700],
              ),
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
    final groupedStatus = _getGroupedStatus(status);
    final statusColor = _getStatusColor(groupedStatus);
    final statusLabel = _getStatusLabel(groupedStatus);
    final statusIcon = _getStatusIcon(groupedStatus);

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
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusLabel,
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

  /// تحويل الحالة الفعلية إلى مجموعة مبسطة
  String _getGroupedStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return 'new';
      case OrderStatus.preparing:
        return 'inProgress';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
      case OrderStatus.inTransit:
        return 'delivery';
      case OrderStatus.delivered:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String _getStatusLabel(String groupedStatus) {
    switch (groupedStatus) {
      case 'new':
        return 'جديدة';
      case 'inProgress':
        return 'قيد التجهيز';
      case 'ready':
        return 'جاهز للتوصيل';
      case 'delivery':
        return 'في التوصيل';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return 'غير معروف';
    }
  }

  Color _getStatusColor(String groupedStatus) {
    switch (groupedStatus) {
      case 'new':
        return const Color(0xFFFF9800); // orange
      case 'inProgress':
        return const Color(0xFF2196F3); // blue
      case 'ready':
        return const Color(0xFF4CAF50); // green
      case 'delivery':
        return const Color(0xFF9C27B0); // purple
      case 'completed':
        return const Color(0xFF4CAF50); // green
      case 'cancelled':
        return const Color(0xFFF44336); // red
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String groupedStatus) {
    switch (groupedStatus) {
      case 'new':
        return Icons.notification_important_rounded;
      case 'inProgress':
        return Icons.inventory_2_rounded;
      case 'ready':
        return Icons.check_circle_outline_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
