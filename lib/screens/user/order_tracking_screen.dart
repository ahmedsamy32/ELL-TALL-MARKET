import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderId;
  final String? orderGroupId;
  final String? orderNumber;

  const OrderTrackingScreen({
    super.key,
    this.orderId,
    this.orderGroupId,
    this.orderNumber,
  }) : assert(orderId != null || orderGroupId != null || orderNumber != null);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  List<OrderModel>? _groupOrders;
  List<OrderItemModel>? _orderItems;
  RealtimeChannel? _groupRealtimeChannel;

  bool _isLoadingItems = false;
  bool _isRefreshingOrder = false;
  String? _clientPhone;
  String? _clientName;
  String? _effectiveOrderId;
  bool _isResolvingInitialOrder = false;
  String? _initialLoadError;

  @override
  void dispose() {
    _groupRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  OrderStatus _getGroupStatus(List<OrderModel> orders) {
    if (orders.isEmpty) return OrderStatus.pending;
    if (orders.every((o) => o.status == OrderStatus.delivered)) {
      return OrderStatus.delivered;
    }
    if (orders.every((o) => o.status == OrderStatus.cancelled)) {
      return OrderStatus.cancelled;
    }
    if (orders.any((o) => o.status == OrderStatus.inTransit || o.status == OrderStatus.pickedUp)) {
      return OrderStatus.inTransit;
    }
    if (orders.any((o) => o.status == OrderStatus.preparing || o.status == OrderStatus.confirmed || o.status == OrderStatus.pending)) {
      if (orders.any((o) => o.status == OrderStatus.preparing)) return OrderStatus.preparing;
      if (orders.any((o) => o.status == OrderStatus.confirmed)) return OrderStatus.confirmed;
      return OrderStatus.pending;
    }
    return OrderStatus.ready;
  }

  OrderStatus _simplifyStatusForClient(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return OrderStatus.pending;
      case OrderStatus.confirmed:
        return OrderStatus.confirmed;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return OrderStatus.preparing;
      case OrderStatus.inTransit:
      case OrderStatus.pickedUp:
        return OrderStatus.inTransit;
      case OrderStatus.delivered:
        return OrderStatus.delivered;
      case OrderStatus.cancelled:
        return OrderStatus.cancelled;
    }
  }

  String _clientStatusLabel(OrderStatus status) {
    final simplified = _simplifyStatusForClient(status);
    if (simplified == OrderStatus.pending) {
      return 'في انتظار قبول المتجر';
    }
    if (simplified == OrderStatus.confirmed) {
      return 'تم قبول الطلب';
    }
    if (simplified == OrderStatus.preparing) {
      return 'جاري تجهيز الطلب';
    }
    if (simplified == OrderStatus.inTransit) {
      return 'جارٍ التوصيل';
    }
    if (simplified == OrderStatus.delivered) {
      return 'تم الاستلام';
    }
    return 'ملغي';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.orderGroupId != null) {
        _loadGroupOrders(widget.orderGroupId!);
        return;
      }

      _resolveInitialOrder();
    });
  }

  Future<void> _resolveInitialOrder() async {
    if (_isResolvingInitialOrder) return;

    setState(() {
      _isResolvingInitialOrder = true;
      _initialLoadError = null;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (widget.orderNumber != null) {
        await orderProvider.getOrderByNumber(widget.orderNumber!);
      } else if (widget.orderId != null) {
        await orderProvider.getOrderById(widget.orderId!);
      }

      final order = orderProvider.selectedOrder;
      if (order == null) {
        setState(() {
          _initialLoadError = 'لم يتم العثور على بيانات الطلب';
          _isResolvingInitialOrder = false;
        });
        return;
      }

      if (order.orderGroupId != null && order.orderGroupId!.isNotEmpty) {
        _isResolvingInitialOrder = false;
        _loadGroupOrders(order.orderGroupId!);
      } else {
        setState(() {
          _groupOrders = [order];
          _isResolvingInitialOrder = false;
        });
        _loadOrderDetails(order.clientId, order.id);
      }
    } catch (e) {
      setState(() {
        _initialLoadError = 'حدث خطأ أثناء تحميل الطلب';
        _isResolvingInitialOrder = false;
      });
    }
  }

  Future<void> _loadGroupOrders(String orderGroupId) async {
    if (_isLoadingItems) return;

    setState(() {
      _isLoadingItems = true;
      _initialLoadError = null;
    });

    try {
      final orders = await OrderService.getOrdersByGroupId(orderGroupId);
      if (orders.isEmpty) {
        if (mounted) {
          setState(() {
            _initialLoadError = 'لم يتم العثور على بيانات الطلب';
            _isLoadingItems = false;
          });
        }
        return;
      }

      final List<OrderItemModel> allItems = [];
      for (final order in orders) {
        final items = await OrderService.getOrderItems(order.id);
        allItems.addAll(items);
      }

      if (orders.isNotEmpty) {
        await _loadClientInfo(orders.first.clientId);
      }

      if (mounted) {
        setState(() {
          _groupOrders = orders;
          _orderItems = allItems;
          _isLoadingItems = false;
          _isRefreshingOrder = false;
          _isResolvingInitialOrder = false;
        });
      }

      // Subscribe to group updates in real-time
      _groupRealtimeChannel ??= Supabase.instance.client
          .channel('order-group-tracking-$orderGroupId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_group_id',
              value: orderGroupId,
            ),
            callback: (payload) {
              AppLogger.info('Group order updated in realtime!');
              _loadGroupOrders(orderGroupId);
            },
          )
          .subscribe();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialLoadError = 'حدث خطأ أثناء تحميل الطلب';
          _isLoadingItems = false;
          _isRefreshingOrder = false;
          _isResolvingInitialOrder = false;
        });
      }
    }
  }

  Future<void> _loadClientInfo(String clientId) async {
    final clientData = await Supabase.instance.client
        .from('profiles')
        .select('full_name, phone')
        .eq('id', clientId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _clientPhone = clientData?['phone'] as String?;
        _clientName = clientData?['full_name'] as String?;
      });
    }
  }

  Future<void> _loadOrderDetails(String clientId, String orderId) async {
    if (_isLoadingItems) return;

    setState(() => _isLoadingItems = true);

    try {
      final items = await OrderService.getOrderItems(orderId);

      await _loadClientInfo(clientId);

      if (mounted) {
        setState(() {
          _orderItems = items;
          _isLoadingItems = false;
          _isRefreshingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
          _isRefreshingOrder = false;
        });
      }
    }
  }

  Future<void> _ensureOrderItemsLoaded(OrderModel order) async {
    if (_orderItems != null) return;

    if (_isLoadingItems) {
      final startedAt = DateTime.now();
      while (mounted &&
          _isLoadingItems &&
          DateTime.now().difference(startedAt) < const Duration(seconds: 10)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    await _loadOrderDetails(order.clientId, order.id);
  }

  Future<void> _refreshSingleOrder() async {
    if (mounted) {
      setState(() => _isRefreshingOrder = true);
    }

    final provider = Provider.of<OrderProvider>(context, listen: false);

    String? gId = widget.orderGroupId;
    if (gId == null && _groupOrders != null && _groupOrders!.isNotEmpty) {
      gId = _groupOrders!.first.orderGroupId;
    }

    if (gId != null && gId.isNotEmpty) {
      await _loadGroupOrders(gId);
      if (mounted) {
        setState(() => _isRefreshingOrder = false);
      }
      return;
    }

    final activeOrderId = _effectiveOrderId ?? widget.orderId;
    if (activeOrderId != null) {
      await provider.getOrderById(activeOrderId);
      final order = provider.selectedOrder;
      if (order != null) {
        await _loadOrderDetails(order.clientId, order.id);
      }
    } else if (widget.orderNumber != null) {
      await provider.getOrderByNumber(widget.orderNumber!);
      final order = provider.selectedOrder;
      if (order != null) {
        await _loadOrderDetails(order.clientId, order.id);
      }
    }

    if (mounted) {
      setState(() => _isRefreshingOrder = false);
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isResolvingInitialOrder) {
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_rounded, size: 24),
              SizedBox(width: 12),
              Text('تتبع الطلب'),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(child: AppShimmer.centeredLines(context)),
      );
    }

    if (_initialLoadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_rounded, size: 24),
              SizedBox(width: 12),
              Text('تتبع الطلب'),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshSingleOrder,
            child: _buildRefreshablePlaceholder(_buildEmptyState(colorScheme)),
          ),
        ),
      );
    }

    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final order = provider.selectedOrder;
        final isLoading = provider.isLoading;

        final displayOrder = order ?? (_groupOrders != null && _groupOrders!.isNotEmpty ? _groupOrders!.first : null);
        final activeOrderId = _effectiveOrderId ?? widget.orderId;
        final displayOrderNumber = displayOrder?.orderNumber ?? widget.orderNumber;
        final titleId = displayOrderNumber ?? activeOrderId?.substring(0, 8);
        final titleText = titleId == null
            ? 'تتبع الطلب'
            : 'تتبع الطلب #$titleId';

        // تحميل تفاصيل الطلب عند توفره
        if (displayOrder != null && _orderItems == null && !_isLoadingItems) {
          Future.microtask(() => _loadOrderDetails(displayOrder.clientId, displayOrder.id));
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timeline_rounded, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(titleText, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: ResponsiveCenter(
            maxWidth: 800,
            child: (isLoading || _isRefreshingOrder)
                ? AppShimmer.centeredLines(context)
                : displayOrder == null
                ? SafeArea(
                    child: RefreshIndicator(
                      onRefresh: _refreshSingleOrder,
                      child: _buildRefreshablePlaceholder(
                        _buildEmptyState(colorScheme),
                      ),
                    ),
                  )
                : _buildTrackingContent(_groupOrders ?? [displayOrder], colorScheme),
          ),
        );
      },
    );
  }

  Widget _buildRefreshablePlaceholder(Widget child) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 96,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات للطلب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اسحب لأسفل للتحديث',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingContent(List<OrderModel> orders, ColorScheme colorScheme) {
    final representativeOrder = orders.first;
    final status = _getGroupStatus(orders);

    return RefreshIndicator(
      onRefresh: _refreshSingleOrder,
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

              // زر إلغاء الطلب - يظهر فقط قبل جاري التحضير وإذا لم يتم إسناد كابتن بعد
              if ((status == OrderStatus.pending ||
                      status == OrderStatus.confirmed) &&
                  !orders.any((o) => o.captainId != null && o.captainId!.isNotEmpty)) ...[
                _buildCancelOrderButton(representativeOrder, colorScheme),
                const SizedBox(height: 16),
              ],

              // زر إعادة إرسال الروشتة لصيدلية أخرى - يظهر فقط إذا كان الطلب ملغياً وهو طلب روشتة
              if (status == OrderStatus.cancelled && _isPrescriptionOrder(representativeOrder)) ...[
                _buildResendPrescriptionButton(representativeOrder, colorScheme),
                const SizedBox(height: 16),
              ],

              // زر عرض الملخص - يظهر فقط بعد تأكيد الطلب (ليس في حالة pending أو cancelled)
              if (status != OrderStatus.pending &&
                  status != OrderStatus.cancelled) ...[
                _buildSummaryButton(representativeOrder, colorScheme),
                const SizedBox(height: 24),
              ],

              // رقم الطلب
              _buildOrderNumberSection(orders, colorScheme),
              const SizedBox(height: 24),

              // تتبع الطلب
              _buildTrackingSection(representativeOrder, status, colorScheme),
              const SizedBox(height: 24),

              // المنتجات والمتاجر
              if (_isLoadingItems)
                AppShimmer.centeredLines(context)
              else if (_orderItems != null && _orderItems!.isNotEmpty) ...[
                _buildProductsSection(colorScheme),
                const SizedBox(height: 24),
                _buildInvoiceSection(orders, colorScheme),
                const SizedBox(height: 24),
              ],

              // معلومات العميل
              if (!_isLoadingItems) ...[
                _buildClientSection(colorScheme),
                const SizedBox(height: 24),
              ],

              // عنوان التوصيل
              _buildAddressSection(representativeOrder, colorScheme),
              const SizedBox(height: 24),

              // طريقة الدفع
              _buildPaymentSection(representativeOrder, colorScheme),
              const SizedBox(height: 24),


            ],
          ),
        ),
      ),
    );
  }

  bool _isPrescriptionOrder(OrderModel order) {
    return order.prescriptionUrl != null && order.prescriptionUrl!.isNotEmpty;
  }

  String? _getPrescriptionUrl(OrderModel order) {
    return order.prescriptionUrl;
  }

  String _cleanNotes(OrderModel order) {
    return order.deliveryNotes ?? '';
  }

  void _showZoomableImageDialog(String url) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResendPrescriptionButton(OrderModel order, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          final url = _getPrescriptionUrl(order);
          final notes = _cleanNotes(order);
          Navigator.pushNamed(
            context,
            AppRoutes.uploadPrescription,
            arguments: {
              'prescriptionUrl': url,
              'initialNotes': notes,
            },
          );
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('طلب من صيدلية أخرى 🔄'),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
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
              'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ سيتم إلغاء جميع الطلبات في هذه المجموعة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'رقم الطلب: ${order.orderNumber ?? order.id.substring(0, 8)}',
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
      builder: (ctx) => AppShimmer.centeredLines(ctx),
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
          _refreshSingleOrder();
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
  Widget _buildOrderNumberSection(List<OrderModel> orders, ColorScheme colorScheme) {
    final displayNumbers = orders
        .map((o) => '#${o.orderNumber ?? o.id.substring(0, 8).toUpperCase()}')
        .join(' | ');

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
                  orders.length > 1 ? 'أرقام الطلبات' : 'رقم الطلب',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayNumbers,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ أرقام الطلبات'),
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


  // Bottom Sheet للملخص والفاتورة
  Future<void> _showSummaryBottomSheet(
    OrderModel order,
    ColorScheme colorScheme,
  ) async {
    final shouldLoad = _orderItems == null;
    if (shouldLoad) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppShimmer.centeredLines(ctx),
      );
      try {
        await _ensureOrderItemsLoaded(order);
      } finally {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                        ? AppShimmer.centeredLines(context)
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
                              if (_groupOrders != null)
                                _buildInvoiceSection(_groupOrders!, colorScheme),
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
    if (_groupOrders == null || _groupOrders!.isEmpty) {
      return const SizedBox.shrink();
    }

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
        ..._groupOrders!.map((order) {
          final storeItems = _orderItems
                  ?.where((item) => item.orderId == order.id)
                  .toList() ??
              [];
          if (storeItems.isEmpty) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    order.storeName ?? 'المتجر',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Divider(height: 1),
                ...storeItems.map((item) => _buildProductItem(item, colorScheme)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInvoiceSection(List<OrderModel> orders, ColorScheme colorScheme) {
    double subtotal = 0.0;
    double deliveryFee = 0.0;
    double taxAmount = 0.0;
    double discountAmount = 0.0;
    final couponCodes = <String>{};

    for (final o in orders) {
      deliveryFee += o.deliveryFee;
      taxAmount += o.taxAmount;
      discountAmount += o.discountAmount;
      if (o.couponCode != null && o.couponCode!.isNotEmpty) {
        couponCodes.add(o.couponCode!);
      }
    }

    if (_orderItems != null && _orderItems!.isNotEmpty) {
      subtotal = _orderItems!.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      );
    } else {
      for (final o in orders) {
        subtotal += (o.totalAmount + o.discountAmount - o.deliveryFee - o.taxAmount);
      }
    }

    final totalAmount = orders.fold<double>(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    final discountLabel = couponCodes.isNotEmpty
        ? 'الخصم (${couponCodes.join(', ')})'
        : 'الخصم';

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
          _buildSummaryRow('المجموع الفرعي', subtotal),
          if (discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(discountLabel, discountAmount, isDiscount: true),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow('رسوم التوصيل', deliveryFee),
          const SizedBox(height: 8),
          _buildSummaryRow('الضرائب', taxAmount),
          const Divider(height: 24),
          _buildSummaryRow('الإجمالي', totalAmount, isTotal: true),
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
                  _clientStatusLabel(status),
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

  Widget _buildTrackingSection(OrderModel order, OrderStatus groupStatus, ColorScheme colorScheme) {
    final events = _buildTrackingEvents(order, groupStatus);

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

  List<Map<String, dynamic>> _buildTrackingEvents(OrderModel order, OrderStatus groupStatus) {
    final status = _simplifyStatusForClient(groupStatus);

    int rankOf(OrderStatus s) {
      const flow = <OrderStatus>[
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.inTransit,
        OrderStatus.delivered,
      ];
      return flow.indexOf(s);
    }

    if (status == OrderStatus.cancelled) {
      return [
        {
          'title': 'تم إنشاء الطلب',
          'time': order.createdAt,
          'icon': Icons.shopping_cart_rounded,
          'color': Colors.blue,
          'isCompleted': true,
        },
        {
          'title': 'تم إلغاء الطلب',
          'time': order.updatedAt ?? order.createdAt,
          'icon': Icons.cancel_rounded,
          'color': Colors.red,
          'isCompleted': true,
        },
      ];
    }

    final currentRank = rankOf(status);
    bool done(OrderStatus stepStatus) =>
        currentRank >= 0 && currentRank >= rankOf(stepStatus);

    final isConfirmed = done(OrderStatus.confirmed);
    final isPreparing = done(OrderStatus.preparing);
    final isInTransit = done(OrderStatus.inTransit);
    final isDelivered = done(OrderStatus.delivered);

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
        'title': 'جاري تجهيز الطلب',
        'time': isPreparing
            ? (order.preparedAt ?? order.acceptedAt ?? order.createdAt)
            : null,
        'icon': Icons.restaurant_rounded,
        'color': Colors.orange,
        'isCompleted': isPreparing,
      },
      {
        'title': 'جارٍ التوصيل',
        'time': isInTransit
            ? (order.pickedUpAt ?? order.preparedAt ?? order.acceptedAt)
            : null,
        'icon': Icons.delivery_dining_rounded,
        'color': Colors.indigo,
        'isCompleted': isInTransit,
      },
      {
        'title': 'تم الاستلام',
        'time': isDelivered
            ? (order.deliveredAt ?? order.updatedAt ?? order.createdAt)
            : null,
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
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryNotes!,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductsSection(ColorScheme colorScheme) {
    if (_groupOrders == null || _groupOrders!.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasPrescription = _groupOrders!.any((o) => _isPrescriptionOrder(o));
    final hasExternalItems = _orderItems?.any((item) =>
        item.selectedOptions != null && item.selectedOptions!['source'] == 'external') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.storefront_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'تفاصيل المتاجر والمنتجات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasPrescription)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب أدوية بروشتة 📄',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasExternalItems
                            ? 'لقد قام الدليفري بتوفير الأدوية الناقصة من صيدليات خارجية وتحديث الفاتورة أدناه بالكامل.'
                            : 'في حال وجود نواقص في الصيدلية، سيتولى الدليفري البحث عنها في صيدليات خارجية وإضافتها للفاتورة تلقائياً.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final prescriptionOrder = _groupOrders!.firstWhere(
                            (o) => _isPrescriptionOrder(o),
                            orElse: () => _groupOrders!.first,
                          );
                          final url = _getPrescriptionUrl(prescriptionOrder);
                          if (url == null || url.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'صورة الروشتة المرفقة:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showZoomableImageDialog(url),
                                child: Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                    color: Colors.white,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      url,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.broken_image_rounded,
                                        size: 40,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ..._groupOrders!.map((order) {
          final storeItems = _orderItems
                  ?.where((item) => item.orderId == order.id)
                  .toList() ??
              [];
          final storeStatus = OrderStatusExtension.fromDbValue(order.status.value);
          final statusColor = _getStatusColor(storeStatus);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.storeName ?? 'المتجر',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                            ),
                            if (order.storeCategory != null && order.storeCategory!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                order.storeCategory!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                            if (order.storePhone?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () => _launchPhoneCall(order.storePhone!),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.phone_rounded,
                                      size: 12,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.storePhone!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Store Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.statusDisplayName,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Store Items
                  if (storeItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'لا توجد منتجات محملة',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ...storeItems.map(
                      (item) => _buildProductItem(item, colorScheme),
                    ),
                ],
              ),
            ),
          );
        }),
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
            child: item.productImage != null && item.productImage!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.shopping_bag_outlined,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
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
                if (item.selectedOptions != null && item.selectedOptions!['source'] == 'external') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_shipping_rounded, color: Colors.orange.shade800, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'شراء خارجي بواسطة الدليفري 🛵',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.selectedOptions != null &&
                    item.selectedOptions!.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final Map<String, dynamic> selectedOpts = Map<String, dynamic>.from(item.selectedOptions ?? {});
                      final attributes = selectedOpts.entries
                          .where((e) => e.key != 'addons' && e.key != 'source')
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
                            const SizedBox(height: 4),
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
                            const SizedBox(height: 4),
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
                    },
                  ),
                ],
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

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
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
          isDiscount ? '-${amount.toStringAsFixed(2)} ج.م' : '${amount.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal 
                ? AppColors.primary 
                : (isDiscount ? Colors.red[700] : Colors.black87),
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
      await _ensureOrderItemsLoaded(order);

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

      final List<OrderModel> pdfOrders = _groupOrders ?? [order];
      double subtotal = 0.0;
      double deliveryFee = 0.0;
      double taxAmount = 0.0;
      double discountAmount = 0.0;
      double totalAmount = 0.0;
      final couponCodes = <String>{};

      for (final o in pdfOrders) {
        subtotal += (o.totalAmount + o.discountAmount - o.deliveryFee - o.taxAmount);
        deliveryFee += o.deliveryFee;
        taxAmount += o.taxAmount;
        discountAmount += o.discountAmount;
        totalAmount += o.totalAmount;
        if (o.couponCode != null && o.couponCode!.isNotEmpty) {
          couponCodes.add(o.couponCode!);
        }
      }

      final displayOrderNumber = pdfOrders
          .map((o) => o.orderNumber ?? o.id.substring(0, 8).toUpperCase())
          .join(' - ');

      // إضافة صفحة الفاتورة
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            final List<pw.TableRow> tableRows = [];
            // Header Row
            tableRows.add(
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
            );

            // Populate rows grouped by store
            for (final ord in pdfOrders) {
              final storeItems = _orderItems?.where((item) => item.orderId == ord.id).toList() ?? [];
              if (storeItems.isEmpty) continue;

              if (pdfOrders.length > 1) {
                // Add store header row
                tableRows.add(
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#EEEEEE'),
                    ),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          ord.storeName ?? 'المتجر',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }

              for (final item in storeItems) {
                tableRows.add(
                  pw.TableRow(
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
                );
              }
            }

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
                            '#$displayOrderNumber',
                            style: pw.TextStyle(
                              fontSize: 15,
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
                  children: tableRows,
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
                            '${subtotal.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      if (discountAmount > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              couponCodes.isNotEmpty
                                  ? 'الخصم (${couponCodes.join(', ')}):'
                                  : 'الخصم:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#D32F2F'),
                              ),
                            ),
                            pw.Text(
                              '-${discountAmount.toStringAsFixed(2)} ج.م',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#D32F2F'),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رسوم التوصيل:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${deliveryFee.toStringAsFixed(2)} ج.م',
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
                            '${taxAmount.toStringAsFixed(2)} ج.م',
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
                            '${totalAmount.toStringAsFixed(2)} ج.م',
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
        name: 'فاتورة_طلب_${pdfOrders.map((o) => o.orderNumber ?? o.id.substring(0, 8)).join('_')}.pdf',
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
      await _ensureOrderItemsLoaded(order);

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

      final List<OrderModel> pdfOrders = _groupOrders ?? [order];
      double subtotal = 0.0;
      double deliveryFee = 0.0;
      double taxAmount = 0.0;
      double discountAmount = 0.0;
      double totalAmount = 0.0;
      final couponCodes = <String>{};

      for (final o in pdfOrders) {
        subtotal += (o.totalAmount + o.discountAmount - o.deliveryFee - o.taxAmount);
        deliveryFee += o.deliveryFee;
        taxAmount += o.taxAmount;
        discountAmount += o.discountAmount;
        totalAmount += o.totalAmount;
        if (o.couponCode != null && o.couponCode!.isNotEmpty) {
          couponCodes.add(o.couponCode!);
        }
      }

      final displayOrderNumber = pdfOrders
          .map((o) => o.orderNumber ?? o.id.substring(0, 8).toUpperCase())
          .join(' - ');

      // إضافة صفحة الفاتورة (نفس الكود من _generateInvoicePDF)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            final List<pw.TableRow> tableRows = [];
            // Header Row
            tableRows.add(
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
            );

            // Populate rows grouped by store
            for (final ord in pdfOrders) {
              final storeItems = _orderItems?.where((item) => item.orderId == ord.id).toList() ?? [];
              if (storeItems.isEmpty) continue;

              if (pdfOrders.length > 1) {
                // Add store header row
                tableRows.add(
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#EEEEEE'),
                    ),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          ord.storeName ?? 'المتجر',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }

              for (final item in storeItems) {
                tableRows.add(
                  pw.TableRow(
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
                );
              }
            }

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
                            '#$displayOrderNumber',
                            style: pw.TextStyle(
                              fontSize: 15,
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
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'الاسم: ',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              _clientName ?? 'غير محدد',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'رقم الهاتف: ',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              _clientPhone ?? 'غير محدد',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
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
                  children: tableRows,
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
                            '${subtotal.toStringAsFixed(2)} ج.م',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      if (discountAmount > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              couponCodes.isNotEmpty
                                  ? 'الخصم (${couponCodes.join(', ')}):'
                                  : 'الخصم:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#D32F2F'),
                              ),
                            ),
                            pw.Text(
                              '-${discountAmount.toStringAsFixed(2)} ج.م',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#D32F2F'),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'رسوم التوصيل:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            '${deliveryFee.toStringAsFixed(2)} ج.م',
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
                            '${taxAmount.toStringAsFixed(2)} ج.م',
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
                            '${totalAmount.toStringAsFixed(2)} ج.م',
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
            'فاتورة_طلب_${pdfOrders.map((o) => o.orderNumber ?? o.id.substring(0, 8)).join('_')}.pdf',
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
