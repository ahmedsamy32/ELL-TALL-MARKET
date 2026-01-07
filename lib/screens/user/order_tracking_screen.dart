import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({required this.orderId, super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  List<OrderItemModel>? _orderItems;
  bool _isLoadingItems = false;
  String? _clientPhone;
  String? _clientName;

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

  Future<void> _loadOrderDetails(String clientId, String orderId) async {
    if (_isLoadingItems) return;

    setState(() => _isLoadingItems = true);

    try {
      // تحميل المنتجات
      final items = await OrderService.getOrderItems(orderId);

      // تحميل بيانات العميل
      final clientData = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', clientId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _orderItems = items;
          _clientPhone = clientData?['phone'] as String?;
          _clientName = clientData?['full_name'] as String?;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final order = provider.selectedOrder;
        final isLoading = provider.isLoading;

        // تحميل تفاصيل الطلب عند توفره
        if (order != null && _orderItems == null && !_isLoadingItems) {
          Future.microtask(() => _loadOrderDetails(order.clientId, order.id));
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timeline_rounded, size: 24),
                const SizedBox(width: 12),
                Text('تتبع الطلب #${widget.orderId.substring(0, 8)}'),
              ],
            ),
            centerTitle: true,
            actions: [
              if (order != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                  onPressed: () {
                    Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    ).getOrderById(widget.orderId);
                    _loadOrderDetails(order.clientId, order.id);
                  },
                ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : order == null
              ? _buildEmptyState(colorScheme)
              : _buildTrackingContent(order, colorScheme),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 72, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'لم يتم العثور على بيانات الطلب',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingContent(OrderModel order, ColorScheme colorScheme) {
    final status = OrderStatusExtension.fromDbValue(order.status.value);

    return RefreshIndicator(
      onRefresh: () async {
        await Provider.of<OrderProvider>(
          context,
          listen: false,
        ).getOrderById(widget.orderId);
        await _loadOrderDetails(order.clientId, order.id);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // حالة الطلب
              _buildStatusSection(status, colorScheme),
              const SizedBox(height: 16),

              // زر إلغاء الطلب - يظهر فقط قبل جاري التحضير
              if (status == OrderStatus.pending ||
                  status == OrderStatus.confirmed) ...[
                _buildCancelOrderButton(order, colorScheme),
                const SizedBox(height: 16),
              ],

              // زر عرض الملخص - يظهر فقط بعد تأكيد الطلب (ليس في حالة pending أو cancelled)
              if (status != OrderStatus.pending &&
                  status != OrderStatus.cancelled) ...[
                _buildSummaryButton(order, colorScheme),
                const SizedBox(height: 24),
              ],

              // رقم الطلب
              _buildOrderNumberSection(order, colorScheme),
              const SizedBox(height: 24),

              // تتبع الطلب
              _buildTrackingSection(order, colorScheme),
              const SizedBox(height: 24),

              // المنتجات
              if (_isLoadingItems)
                const Center(child: CircularProgressIndicator())
              else if (_orderItems != null && _orderItems!.isNotEmpty) ...[
                _buildProductsSection(colorScheme),
                const SizedBox(height: 24),
              ],

              // معلومات العميل
              if (!_isLoadingItems) ...[
                _buildClientSection(colorScheme),
                const SizedBox(height: 24),
              ],

              // عنوان التوصيل
              _buildAddressSection(order, colorScheme),
              const SizedBox(height: 24),

              // طريقة الدفع
              _buildPaymentSection(order, colorScheme),
              const SizedBox(height: 24),

              // تعليمات التوصيل
              if (order.deliveryNotes?.isNotEmpty == true) ...[
                _buildDeliveryNotesSection(order, colorScheme),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // زر إلغاء الطلب
  Widget _buildCancelOrderButton(OrderModel order, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCancelOrderDialog(order),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('إلغاء الطلب'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[700],
          side: BorderSide(color: Colors.red[700]!, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // حوار تأكيد إلغاء الطلب
  Future<void> _showCancelOrderDialog(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange[700],
          size: 48,
        ),
        title: const Text('تأكيد إلغاء الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'رقم الطلب: ${order.orderNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('الرجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cancelOrder(order.id);
    }
  }

  // تنفيذ إلغاء الطلب
  Future<void> _cancelOrder(String orderId) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.cancelOrder(orderId);

      if (mounted) {
        Navigator.pop(context); // إغلاق مؤشر التحميل

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('تم إلغاء الطلب بنجاح')),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(orderProvider.error ?? 'فشل إلغاء الطلب'),
                  ),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // إغلاق مؤشر التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // زر عرض الملخص - يفتح Bottom Sheet
  Widget _buildSummaryButton(OrderModel order, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showSummaryBottomSheet(order, colorScheme),
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('عرض ملخص الطلب والفاتورة'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // رقم الطلب - قابل للنسخ
  Widget _buildOrderNumberSection(OrderModel order, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم الطلب',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${order.orderNumber ?? order.id.substring(0, 13).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // نسخ رقم الطلب
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ رقم الطلب'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'نسخ',
          ),
        ],
      ),
    );
  }

  // طريقة الدفع
  Widget _buildPaymentSection(OrderModel order, ColorScheme colorScheme) {
    // تحديد نوع طريقة الدفع
    String paymentMethodText;
    IconData paymentIcon;
    Color paymentColor;

    final paymentMethodValue = order.paymentMethod.value.toLowerCase();

    switch (paymentMethodValue) {
      case 'cash':
        paymentMethodText = 'الدفع نقداً عند الاستلام';
        paymentIcon = Icons.money_rounded;
        paymentColor = Colors.green;
        break;
      case 'visa':
      case 'card':
        paymentMethodText = 'الدفع بالفيزا';
        paymentIcon = Icons.credit_card_rounded;
        paymentColor = Colors.blue;
        break;
      case 'mastercard':
        paymentMethodText = 'الدفع بالماستركارد';
        paymentIcon = Icons.credit_card_rounded;
        paymentColor = Colors.orange;
        break;
      case 'online':
      case 'electronic':
        paymentMethodText = 'الدفع الإلكتروني';
        paymentIcon = Icons.payment_rounded;
        paymentColor = Colors.purple;
        break;
      default:
        paymentMethodText = 'طريقة دفع أخرى';
        paymentIcon = Icons.payments_rounded;
        paymentColor = Colors.grey;
    }

    // تحديد حالة الدفع
    final isPaid = order.paymentStatus.value.toLowerCase() == 'paid';

    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.payment_rounded,
      title: 'طريقة الدفع',
      children: [
        // طريقة الدفع مع badge ملون
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: paymentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paymentColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: paymentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(paymentIcon, color: paymentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طريقة الدفع',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paymentMethodText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: paymentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // حالة الدفع
        _buildInfoRow(
          icon: isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
          label: 'حالة الدفع',
          value: isPaid ? 'مدفوع ✓' : 'غير مدفوع',
        ),
      ],
    );
  }

  // تعليمات التوصيل
  Widget _buildDeliveryNotesSection(OrderModel order, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'تعليمات التوصيل',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.deliveryNotes!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // Bottom Sheet للملخص والفاتورة
  void _showSummaryBottomSheet(OrderModel order, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ملخص الطلب والفاتورة',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'طلب #${order.orderNumber ?? order.id.substring(0, 8)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // زرار تنزيل ومشاركة PDF - يظهر فقط بعد تأكيد الطلب
                        if (OrderStatusExtension.fromDbValue(
                                  order.status.value,
                                ) !=
                                OrderStatus.pending &&
                            OrderStatusExtension.fromDbValue(
                                  order.status.value,
                                ) !=
                                OrderStatus.cancelled) ...[
                          IconButton(
                            onPressed: () => _shareInvoicePDF(order),
                            icon: const Icon(Icons.share_rounded),
                            tooltip: 'مشاركة الفاتورة',
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.secondaryContainer,
                              foregroundColor: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _generateInvoicePDF(order),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            tooltip: 'تنزيل الفاتورة PDF',
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Content
                  Expanded(
                    child: _isLoadingItems
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              // المنتجات
                              if (_orderItems != null &&
                                  _orderItems!.isNotEmpty) ...[
                                _buildBottomSheetProductsSection(colorScheme),
                                const SizedBox(height: 24),
                              ],

                              // الفاتورة
                              _buildInvoiceSection(order, colorScheme),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomSheetProductsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'تفاصيل الطلب',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _orderItems!
                .map((item) => _buildProductItem(item, colorScheme))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSection(OrderModel order, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'الفاتورة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            'المجموع الفرعي',
            order.totalAmount - order.deliveryFee - order.taxAmount,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('رسوم التوصيل', order.deliveryFee),
          const SizedBox(height: 8),
          _buildSummaryRow('الضرائب', order.taxAmount),
          const Divider(height: 24),
          _buildSummaryRow('الإجمالي', order.totalAmount, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildStatusSection(OrderStatus status, ColorScheme colorScheme) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(status), color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الطلب',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection(OrderModel order, ColorScheme colorScheme) {
    final events = _buildTrackingEvents(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'تتبع الطلب',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;

          return _buildTrackingStep(
            title: event['title'],
            time: event['time'],
            icon: event['icon'],
            color: event['color'],
            isCompleted: event['isCompleted'],
            isLast: isLast,
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _buildTrackingEvents(OrderModel order) {
    final status = OrderStatusExtension.fromDbValue(order.status.value);

    // تحديد الحالات المكتملة بناءً على الحالة الحالية
    final isConfirmed =
        status != OrderStatus.pending && status != OrderStatus.cancelled;
    final isPreparing = isConfirmed && status != OrderStatus.confirmed;
    final isReady = isPreparing && status != OrderStatus.preparing;
    final isPickedUp = isReady && status != OrderStatus.ready;
    final isInTransit = isPickedUp && status != OrderStatus.pickedUp;
    final isDelivered = status == OrderStatus.delivered;

    return [
      {
        'title': 'تم إنشاء الطلب',
        'time': order.createdAt,
        'icon': Icons.shopping_cart_rounded,
        'color': Colors.blue,
        'isCompleted': true,
      },
      {
        'title': 'تم قبول الطلب',
        'time': isConfirmed ? (order.acceptedAt ?? order.createdAt) : null,
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
        'isCompleted': isConfirmed,
      },
      {
        'title': 'جاري التحضير',
        'time': isPreparing
            ? (order.preparedAt ?? order.acceptedAt ?? order.createdAt)
            : null,
        'icon': Icons.restaurant_rounded,
        'color': Colors.orange,
        'isCompleted': isPreparing,
      },
      {
        'title': 'جاهز للتوصيل',
        'time': isReady ? (order.preparedAt ?? order.acceptedAt) : null,
        'icon': Icons.shopping_bag_rounded,
        'color': Colors.purple,
        'isCompleted': isReady,
      },
      {
        'title': 'تم استلامه من المتجر',
        'time': isPickedUp ? (order.pickedUpAt ?? order.preparedAt) : null,
        'icon': Icons.handshake_rounded,
        'color': Colors.cyan,
        'isCompleted': isPickedUp,
      },
      {
        'title': 'في الطريق',
        'time': isInTransit
            ? (order.pickedUpAt ?? order.preparedAt ?? order.acceptedAt)
            : null,
        'icon': Icons.delivery_dining_rounded,
        'color': Colors.indigo,
        'isCompleted': isInTransit,
      },
      {
        'title': 'تم التوصيل',
        'time': isDelivered ? (order.deliveredAt ?? DateTime.now()) : null,
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.green,
        'isCompleted': isDelivered,
      },
    ];
  }

  Widget _buildTrackingStep({
    required String title,
    required DateTime? time,
    required IconData icon,
    required Color color,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? color.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? color : Colors.grey,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isCompleted ? color : Colors.grey,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isCompleted
                    ? color.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Event details
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCompleted
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isCompleted ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(time),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ] else if (!isCompleted) ...[
                  const SizedBox(height: 4),
                  Text(
                    'في انتظار التنفيذ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection(ColorScheme colorScheme) {
    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.person_rounded,
      title: 'معلومات العميل',
      children: [
        if (_clientName != null)
          _buildInfoRow(
            icon: Icons.badge_rounded,
            label: 'الاسم',
            value: _clientName!,
          ),
        if (_clientPhone != null)
          _buildInfoRow(
            icon: Icons.phone_rounded,
            label: 'رقم الهاتف',
            value: _clientPhone!,
          ),
      ],
    );
  }

  Widget _buildAddressSection(OrderModel order, ColorScheme colorScheme) {
    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.location_on_rounded,
      title: 'عنوان التوصيل',
      children: [
        _buildInfoRow(
          icon: Icons.place_rounded,
          label: 'العنوان',
          value: order.deliveryAddress,
        ),
        if (order.deliveryNotes?.isNotEmpty == true)
          _buildInfoRow(
            icon: Icons.notes_rounded,
            label: 'ملاحظات',
            value: order.deliveryNotes!,
          ),
      ],
    );
  }

  Widget _buildProductsSection(ColorScheme colorScheme) {
    if (_orderItems == null || _orderItems!.isEmpty) {
      return const SizedBox.shrink();
    }

    // عرض المنتج الأول فقط
    final product = _orderItems!.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'المنتج',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildProductItem(product, colorScheme),
        ),
      ],
    );
  }

  Widget _buildProductItem(OrderItemModel item, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${item.productPrice.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.specialInstructions?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ملاحظات: ${item.specialInstructions}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${item.totalPrice.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.blue;
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

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      case OrderStatus.ready:
        return Icons.shopping_bag_rounded;
      case OrderStatus.pickedUp:
        return Icons.handshake_rounded;
      case OrderStatus.inTransit:
        return Icons.delivery_dining_rounded;
      case OrderStatus.delivered:
        return Icons.verified_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '${date.day}/${date.month}/${date.year} - $hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  // توليد PDF للفاتورة
  Future<void> _generateInvoicePDF(OrderModel order) async {
    try {
      // عرض مؤشر التحميل
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري إنشاء الفاتورة...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final pdf = pw.Document();

      // تحميل الخط العربي من Google Fonts
      final ttf = await PdfGoogleFonts.cairoRegular();
      final ttfBold = await PdfGoogleFonts.cairoBold();

      // إضافة صفحة الفاتورة
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1976D2'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ell Tall Market',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'فاتورة الطلب',
                            style: const pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'رقم الطلب',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            '#${order.orderNumber ?? order.id.substring(0, 8)}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // تاريخ الطلب
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F5F5'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'تاريخ الطلب:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatDateTime(order.createdAt),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // معلومات العميل
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'معلومات العميل',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الاسم:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            _clientName ?? 'غير محدد',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رقم الهاتف:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            _clientPhone ?? 'غير محدد',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // جدول المنتجات
                pw.Text(
                  'تفاصيل الطلب',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#E0E0E0'),
                  ),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F5F5F5'),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'المجموع',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'السعر',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'الكمية',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'المنتج',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Products
                    ...(_orderItems ?? []).map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${(item.productPrice * item.quantity).toStringAsFixed(2)} ج.م',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.productPrice.toStringAsFixed(2)} ج.م',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.quantity}',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.productName,
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // الإجماليات
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F5F5'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'المجموع الفرعي:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${(order.totalAmount - order.deliveryFee - order.taxAmount).toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رسوم التوصيل:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${order.deliveryFee.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الضرائب:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${order.taxAmount.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الإجمالي:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${order.totalAmount.toStringAsFixed(2)} ج.م',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'شكراً لتعاملكم معنا',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1976D2'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // عرض/تنزيل الـ PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'فاتورة_طلب_${order.orderNumber ?? order.id.substring(0, 8)}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الفاتورة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // مشاركة PDF للفاتورة
  Future<void> _shareInvoicePDF(OrderModel order) async {
    try {
      // عرض مؤشر التحميل
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري إنشاء الفاتورة للمشاركة...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final pdf = pw.Document();

      // تحميل الخط العربي من Google Fonts
      final ttf = await PdfGoogleFonts.cairoRegular();
      final ttfBold = await PdfGoogleFonts.cairoBold();

      // إضافة صفحة الفاتورة (نفس الكود من _generateInvoicePDF)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1976D2'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ell Tall Market',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'فاتورة الطلب',
                            style: const pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'رقم الطلب',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            '#${order.orderNumber ?? order.id.substring(0, 8)}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // تاريخ الطلب
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F5F5'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'تاريخ الطلب:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatDateTime(order.createdAt),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // معلومات العميل
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'معلومات العميل',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الاسم:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            _clientName ?? 'غير محدد',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رقم الهاتف:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            _clientPhone ?? 'غير محدد',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // جدول المنتجات
                pw.Text(
                  'تفاصيل الطلب',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#E0E0E0'),
                  ),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F5F5F5'),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'المجموع',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'السعر',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'الكمية',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'المنتج',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Products
                    ...(_orderItems ?? []).map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${(item.productPrice * item.quantity).toStringAsFixed(2)} ج.م',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.productPrice.toStringAsFixed(2)} ج.م',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.quantity}',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.productName,
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // الإجماليات
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F5F5'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'المجموع الفرعي:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${(order.totalAmount - order.deliveryFee - order.taxAmount).toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رسوم التوصيل:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${order.deliveryFee.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الضرائب:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${order.taxAmount.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الإجمالي:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${order.totalAmount.toStringAsFixed(2)} ج.م',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'شكراً لتعاملكم معنا',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1976D2'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // مشاركة PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'فاتورة_طلب_${order.orderNumber ?? order.id.substring(0, 8)}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تجهيز الفاتورة للمشاركة'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
