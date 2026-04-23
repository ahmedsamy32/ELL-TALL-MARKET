import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';
import 'package:ell_tall_market/utils/captain_contact_utils.dart';

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
      appBar: AppBar(
        title: const Text('سجل الطلبات المكتملة'),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: () => Provider.of<OrderProvider>(
            context,
            listen: false,
          ).fetchCaptainOrders(widget.captainId),
          child: _buildOrdersList(orderProvider),
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return AppShimmer.list(context);
    }

    // شاشة الأرشيف: عرض الطلبات المكتملة فقط
    final filteredOrders =
        provider.captainOrders
            .where(
              (order) =>
                  OrderStatus.fromString(order.status.value) ==
                  OrderStatus.delivered,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Center(
            child: Text(
              'لا توجد طلبات مكتملة حتى الآن',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'سيظهر هنا سجل الطلبات بعد التسليم',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
    final status = order.status;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'طلب #${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          CaptainOrderHelpers.getStatusText(status),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 🏪 اسم المتجر
                  if (order.storeName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.store_rounded,
                          color: Colors.teal[600],
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.storeName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.teal[700],
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي المبلغ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${order.totalAmount.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'طريقة الدفع',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            order.paymentMethod.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final orderStatus = OrderStatus.fromString(order.status.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _OrderDetailsSheet(
          order: order,
          orderStatus: orderStatus,
          captainId: widget.captainId,
          onAccept: () {
            Navigator.pop(ctx);
            if (orderStatus == OrderStatus.ready) {
              _acceptPendingOrder(order);
            } else {
              final nextStatus = CaptainOrderHelpers.getNextStatus(orderStatus);
              if (CaptainOrderHelpers.requiresConfirmation(nextStatus)) {
                _confirmAndUpdateStatus(order, nextStatus);
              } else {
                _updateOrderStatus(order, nextStatus);
              }
            }
          },
          onReject: () {
            Navigator.pop(ctx);
            _rejectOrder(order);
          },
          getActionText: CaptainOrderHelpers.getOrdersActionText,
          getStatusText: CaptainOrderHelpers.getStatusText,
        );
      },
    );
  }

  Color _getStatusColor(OrderStatus status) =>
      CaptainOrderHelpers.getStatusColor(status);

  Future<void> _acceptPendingOrder(OrderModel order) async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.acceptOrder(
        order.id,
        widget.captainId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم قبول الطلب بنجاح' : 'فشل قبول الطلب'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      AppLogger.error('فشل قبول الطلب', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل قبول الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmAndUpdateStatus(
    OrderModel order,
    OrderStatus newStatus,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: Text(CaptainOrderHelpers.getConfirmationMessage(newStatus)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('نعم، تم التسليم'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _updateOrderStatus(order, newStatus);
    }
  }

  void _rejectOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: const Text(
          'هل أنت متأكد من رفض هذا الطلب؟\nسيتم إرسال الطلب لكابتن آخر متاح.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.rejectOrder(
        order.id,
        widget.captainId,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب — سيتم إرساله لكابتن آخر'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('فشل رفض الطلب', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفض الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    if (!mounted) return;

    final currentStatus = OrderStatus.fromString(order.status.value);
    if (!CaptainOrderHelpers.canTransition(currentStatus, newStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن الانتقال من ${CaptainOrderHelpers.getStatusText(currentStatus)} إلى ${CaptainOrderHelpers.getStatusText(newStatus)}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final success = await orderProvider.updateOrderStatus(
        order.id,
        newStatus.dbValue,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('فشل تحديث حالة الطلب', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ===== Bottom Sheet مع عداد تنازلي =====
class _OrderDetailsSheet extends StatefulWidget {
  final OrderModel order;
  final OrderStatus orderStatus;
  final String captainId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String Function(OrderStatus) getActionText;
  final String Function(OrderStatus) getStatusText;

  const _OrderDetailsSheet({
    required this.order,
    required this.orderStatus,
    required this.captainId,
    required this.onAccept,
    required this.onReject,
    required this.getActionText,
    required this.getStatusText,
  });

  @override
  State<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<_OrderDetailsSheet> {
  /// المهلة الكاملة بالثواني (نفس القيمة في OrderProvider)
  static const int _timeoutSeconds = CaptainOrderHelpers.slaAcceptSeconds;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late final Future<List<OrderItemModel>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _timeoutSeconds;
    _itemsFuture = OrderService.getOrderItems(widget.order.id);

    // بدء العداد التنازلي فقط إذا الطلب في حالة ready (بانتظار قبول الكابتن)
    if (widget.orderStatus == OrderStatus.ready) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
            // المهلة انتهت — الرفض التلقائي يتم من OrderProvider
            Navigator.pop(context);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remainingSeconds <= 20;
    final showCountdown = widget.orderStatus == OrderStatus.ready;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ⏱️ عداد تنازلي
          if (showCountdown) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUrgent
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isUrgent
                        ? Icons.warning_amber_rounded
                        : Icons.timer_outlined,
                    color: isUrgent ? Colors.red : Colors.orange.shade800,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUrgent
                              ? 'أسرع! المهلة تنتهي قريباً'
                              : 'مهلة قبول الطلب',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isUrgent
                                ? Colors.red.shade800
                                : Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'سيتم تحويل الطلب لكابتن آخر بعد انتهاء المهلة',
                          style: TextStyle(
                            fontSize: 11,
                            color: isUrgent
                                ? Colors.red.shade600
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isUrgent ? Colors.red : Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(_remainingSeconds ~/ 60).toString().padLeft(1, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // شريط التقدم
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _remainingSeconds / _timeoutSeconds,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUrgent ? Colors.red : Colors.orange,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'تفاصيل الطلب #${widget.order.id.substring(0, 8)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('رقم الطلب:', widget.order.id.substring(0, 8)),
          _buildDetailRow('الحالة:', widget.getStatusText(widget.orderStatus)),
          // 🏪 معلومات المتجر
          if (widget.order.storeName != null)
            _buildDetailRow('المتجر:', widget.order.storeName!),
          if (widget.order.storeAddress != null)
            _buildDetailRow('عنوان المتجر:', widget.order.storeAddress!),
          if (widget.order.storePhone != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'هاتف المتجر:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.order.storePhone!),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      CaptainContactUtils.callPhone(
                        context,
                        widget.order.storePhone,
                        unavailableMessage: 'رقم هاتف المتجر غير متوفر',
                      );
                    },
                    child: Icon(
                      Icons.phone,
                      size: 18,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          _buildDetailRow('العنوان:', widget.order.deliveryAddress),
          _buildDetailRow('الملاحظات:', widget.order.notes ?? 'لا توجد'),
          _buildDetailRow(
            'المجموع:',
            '${widget.order.totalAmount.toStringAsFixed(2)} ج.م',
          ),
          _buildDetailRow(
            'طريقة الدفع:',
            widget.order.paymentMethod.displayName,
          ),
          _buildDetailRow('التاريخ:', widget.order.createdAtFormatted),
          const SizedBox(height: 16),
          const Text(
            'المنتجات:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<OrderItemModel>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('تعذر تحميل المنتجات');
              }
              final items = snapshot.data!;
              return Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.quantity}x '),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.selectedOptions != null &&
                                  item.selectedOptions!.isNotEmpty)
                                Text(
                                  item.selectedOptions!.entries
                                      .map((e) => '${e.key}: ${e.value}')
                                      .join(' | '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                  ),
                                ),
                              if (item.specialInstructions != null &&
                                  item.specialInstructions!.isNotEmpty)
                                Text(
                                  'ملاحظات: ${item.specialInstructions}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          if (widget.orderStatus != OrderStatus.delivered &&
              widget.orderStatus != OrderStatus.cancelled) ...[
            ElevatedButton(
              onPressed: widget.onAccept,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: showCountdown ? Colors.green : null,
                foregroundColor: showCountdown ? Colors.white : null,
              ),
              child: Text(
                showCountdown
                    ? '✅ قبول الطلب'
                    : widget.getActionText(widget.orderStatus),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.orderStatus == OrderStatus.ready)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: widget.onReject,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'رفض الطلب',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
