import 'dart:async';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';
import 'package:ell_tall_market/utils/captain_contact_utils.dart';
import 'package:ell_tall_market/services/admin_notification_service.dart';

class OrderDeliveryScreen extends StatefulWidget {
  final String orderId;

  const OrderDeliveryScreen({required this.orderId, super.key});

  @override
  State<OrderDeliveryScreen> createState() => _OrderDeliveryScreenState();
}

class _OrderDeliveryScreenState extends State<OrderDeliveryScreen> {
  OrderModel? _order;
  List<OrderItemModel>? _orderItems;
  bool _isLoading = true;
  Timer? _slaTimer;

  @override
  void initState() {
    super.initState();
    // تحديث الوقت المنقضي كل دقيقة لعرض SLA
    _slaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
    });
  }

  @override
  void dispose() {
    _slaTimer?.cancel();
    super.dispose();
  }

  /// الوقت المنقضي منذ إنشاء الطلب
  String get _elapsedText {
    if (_order == null) return '';
    final diff = DateTime.now().difference(_order!.createdAt);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '$hس $mد';
    return '$mد';
  }

  /// هل تجاوز الطلب حد SLA؟
  bool get _isOverdue {
    if (_order == null) return false;
    return DateTime.now().difference(_order!.createdAt).inMinutes >
        CaptainOrderHelpers.slaDeliveryMinutes;
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.getOrderById(widget.orderId);

      if (!mounted) return;

      final items = await OrderService.getOrderItems(widget.orderId);

      setState(() {
        _order = orderProvider.selectedOrder;
        _orderItems = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      AppLogger.error('فشل تحميل تفاصيل الطلب', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحميل تفاصيل الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تفاصيل التوصيل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_order != null)
              Text(
                _isOverdue
                    ? '⚠️ تجاوز الوقت المحدد — $_elapsedText'
                    : 'مضى: $_elapsedText',
                style: TextStyle(
                  fontSize: 11,
                  color: _isOverdue ? Colors.red.shade300 : Colors.grey,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: _messageCustomer,
            tooltip: 'مراسلة العميل',
          ),
          IconButton(
            icon: const Icon(Icons.report_problem_outlined),
            onPressed: _reportProblem,
            tooltip: 'إبلاغ عن مشكلة',
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 800,
          child: _isLoading
              ? AppShimmer.centeredLines(context)
              : (_order == null
                    ? const Center(child: Text('فشل تحميل تفاصيل الطلب'))
                    : _buildDeliveryInterface()),
        ),
      ),
      bottomNavigationBar: _order != null && !_isLoading
          ? _buildStickyActionBar()
          : null,
    );
  }

  Widget _buildDeliveryInterface() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
      child: Column(
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildMapSection(),
          const SizedBox(height: 24),

          // 👤 Client Details Section
          _buildDetailsSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'بيانات العميل',
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _buildClientDetailsCard(),
          const SizedBox(height: 20),

          // 🏬 Stores & Items Section
          _buildDetailsSectionHeader(
            icon: Icons.storefront_rounded,
            title: 'بيانات المتجر والمنتجات',
            color: Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildStoreSubOrderCard(),
          const SizedBox(height: 20),

          // 💰 Financial Details Summary
          _buildDetailsSectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'الملخص المالي',
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          _buildFinancialSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final status = OrderStatus.fromString(_order!.status.value);
    final normalizedStatus = status == OrderStatus.ready
        ? OrderStatus.preparing
        : status;
    final stages = CaptainOrderHelpers.deliveryStages;
    final currentIdx = stages.indexOf(normalizedStatus);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: List.generate(stages.length, (index) {
          final isCompleted = index <= currentIdx;
          final isCurrent = index == currentIdx;
          final stageColor = isCompleted
              ? Colors.green
              : isCurrent
              ? theme.colorScheme.primary
              : Colors.grey[300]!;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: stageColor,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : CaptainOrderHelpers.getStageIcon(stages[index]),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CaptainOrderHelpers.getStageName(stages[index]),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (index < stages.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: index < currentIdx
                          ? Colors.green
                          : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMapSection() {
    final theme = Theme.of(context);
    final hasStoreLocation =
        _order?.storeLatitude != null && _order?.storeLongitude != null;
    final hasDeliveryLocation =
        _order?.deliveryLatitude != null && _order?.deliveryLongitude != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.map_rounded,
            size: 36,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'التنقل عبر الخرائط',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (hasStoreLocation)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLocationInMaps(
                      _order!.storeLatitude!,
                      _order!.storeLongitude!,
                      'المتجر',
                    ),
                    icon: const Icon(Icons.store_rounded, size: 18),
                    label: const Text('المتجر'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (hasStoreLocation && hasDeliveryLocation)
                const SizedBox(width: 12),
              if (hasDeliveryLocation)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openLocationInMaps(
                      _order!.deliveryLatitude!,
                      _order!.deliveryLongitude!,
                      'العميل',
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 18),
                    label: const Text('العميل'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!hasStoreLocation && !hasDeliveryLocation)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'لا تتوفر إحداثيات للعرض على الخريطة',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  bool _isPrescriptionOrder(OrderModel order) {
    return order.prescriptionUrl != null && order.prescriptionUrl!.isNotEmpty;
  }

  String? _getPrescriptionUrl(OrderModel order) {
    return order.prescriptionUrl;
  }


  void _showPrescriptionImageDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExternalItemBottomSheet() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'إضافة دواء من صيدلية خارجية 🛵',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الدواء / المنتج',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم الدواء';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'سعر العبوة/الوحدة (ج.م)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'مطلوب';
                                    }
                                    final p = double.tryParse(value);
                                    if (p == null || p <= 0) {
                                      return 'سعر غير صالح';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'مطلوب';
                                    }
                                    final q = int.tryParse(value);
                                    if (q == null || q <= 0) {
                                      return 'كمية غير صالحة';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    final messenger = ScaffoldMessenger.of(context);
                                    final nav = Navigator.of(context);
                                    
                                    setModalState(() => isSaving = true);
                                    try {
                                      final name = nameController.text.trim();
                                      final price = double.parse(priceController.text);
                                      final qty = int.parse(quantityController.text);
                                      final totalPrice = price * qty;
  
                                      final supabase = SupabaseConfig.client;
  
                                      // Insert into order_items
                                      await supabase.from('order_items').insert({
                                        'order_id': widget.orderId,
                                        'product_id': null,
                                        'product_name': name,
                                        'product_price': price,
                                        'quantity': qty,
                                        'total_price': totalPrice,
                                        'order_number': _order!.orderNumber,
                                        'selected_options': {'source': 'external'},
                                      });
  
                                      // Calculate new total amount for the order
                                      final updatedItems = await OrderService.getOrderItems(widget.orderId);
                                      
                                      double subtotal = 0.0;
                                      for (final item in updatedItems) {
                                        subtotal += item.totalPrice;
                                      }
  
                                      final newTotal = subtotal + _order!.deliveryFee + _order!.taxAmount - _order!.discountAmount;
  
                                      // Update orders table
                                      await supabase.from('orders').update({
                                        'total_amount': newTotal,
                                        'updated_at': DateTime.now().toIso8601String(),
                                      }).eq('id', widget.orderId);
  
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('تم إضافة الدواء وتحديث الفاتورة بنجاح'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        nav.pop();
                                        _loadOrderDetails();
                                      }
                                    } catch (e) {
                                      AppLogger.error('فشل إضافة دواء خارجي', e);
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('فشل الإضافة: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      setModalState(() => isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('حفظ وإدراج في الفاتورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildClientDetailsCard() {
    final order = _order!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clientName = order.clientName ?? 'عميل غير معروف';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'العميل',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.clientPhone != null && order.clientPhone!.trim().isNotEmpty)
                IconButton.filledTonal(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.phone_rounded),
                  tooltip: 'اتصال بالعميل',
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عنوان التوصيل',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.deliveryAddress,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_alt_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات التوصيل',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.notes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map_rounded),
              label: const Text('فتح في خرائط جوجل'),
              onPressed: _openInMaps,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSubOrderCard() {
    final order = _order!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storeName = order.storeName ?? 'متجر غير معروف';
    final storeAddress = order.storeAddress ?? 'عنوان المتجر غير متوفر';
    final storePhone = order.storePhone ?? 'بدون هاتف';
    final isPrescription = _isPrescriptionOrder(order);
    final status = OrderStatus.fromString(order.status.value);

    final storeItems = _orderItems?.where((item) =>
        item.selectedOptions == null || item.selectedOptions!['source'] != 'external').toList() ?? [];
    final externalItems = _orderItems?.where((item) =>
        item.selectedOptions != null && item.selectedOptions!['source'] == 'external').toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (order.storeCategory != null && order.storeCategory!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          order.storeCategory!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        storeAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.storePhone != null && order.storePhone!.trim().isNotEmpty)
                  IconButton.filledTonal(
                    onPressed: () {
                      CaptainContactUtils.callPhone(
                        context,
                        storePhone,
                        unavailableMessage: 'رقم هاتف المتجر غير متوفر',
                      );
                    },
                    icon: const Icon(Icons.phone_rounded),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'اتصال بالمتجر',
                  ),
              ],
            ),
          ),
          
          if (isPrescription && order.prescriptionUrl != null && order.prescriptionUrl!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'روشتة العميل المرفقة 📄',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      final url = _getPrescriptionUrl(order);
                      if (url != null) {
                        _showPrescriptionImageDialog(url);
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          order.prescriptionUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image, size: 40)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          
          // Items List
          if (_isLoading || _orderItems == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppShimmer.list(context, itemCount: 2, itemHeight: 48),
            )
          else ...[
            if (storeItems.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'أدوية من الصيدلية الأساسية:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                ),
              ),
              _buildItemsListView(storeItems, colorScheme, theme),
            ],
            if (externalItems.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'أدوية صيدليات خارجية (نواقص):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                ),
              ),
              _buildItemsListView(externalItems, colorScheme, theme),
            ],
            if (_orderItems!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا توجد منتجات في هذا الطلب',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],

          if (status != OrderStatus.delivered && status != OrderStatus.cancelled && isPrescription) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddExternalItemBottomSheet,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('إضافة دواء من صيدلية خارجية +'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildItemsListView(
    List<OrderItemModel> items,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              image: item.productImage != null
                  ? DecorationImage(
                      image: NetworkImage(item.productImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.productImage == null
                ? Icon(Icons.shopping_bag_outlined, color: colorScheme.primary, size: 20)
                : null,
          ),
          title: Text(
            item.productName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity} × ${item.productPrice.toStringAsFixed(2)} ج.م',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.selectedOptions != null &&
                  item.selectedOptions!.isNotEmpty)
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
                        if (attributes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              attributes,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (addonsText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              addonsText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (item.hasSpecialInstructions)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'ملاحظات: ${item.specialInstructions}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          trailing: Text(
            '${item.totalPrice.toStringAsFixed(2)} ج.م',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialSummaryCard() {
    final order = _order!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate subtotal of products (grandTotal - deliveryFee - taxAmount + discountAmount)
    final productsOnlyTotal = (order.totalAmount - order.deliveryFee - order.taxAmount + order.discountAmount).clamp(0.0, double.infinity);
    final couponText = order.couponCode != null && order.couponCode!.trim().isNotEmpty ? ' (${order.couponCode})' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: 'طريقة الدفع',
            value: order.paymentMethod.displayName,
            valueColor: colorScheme.primary,
            isBoldValue: true,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'حالة الدفع',
            value: order.paymentStatus.displayName,
            valueColor: order.paymentStatus == PaymentStatus.paid ? Colors.green : Colors.orange,
            isBoldValue: true,
          ),
          const SizedBox(height: 8),
          const Divider(height: 16),
          _buildSummaryRow(
            label: 'قيمة المنتجات',
            value: '${productsOnlyTotal.toStringAsFixed(2)} ج.م',
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              label: 'خصم الكوبون$couponText',
              value: '-${order.discountAmount.toStringAsFixed(2)} ج.م',
              valueColor: Colors.red[700],
              isBoldValue: true,
            ),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'رسوم التوصيل',
            value: '${order.deliveryFee.toStringAsFixed(2)} ج.م',
          ),
          const SizedBox(height: 8),
          const Divider(height: 16),
          _buildSummaryRow(
            label: 'الإجمالي الكلي',
            value: '${order.totalAmount.toStringAsFixed(2)} ج.م',
            isBoldLabel: true,
            isBoldValue: true,
            fontSize: 16,
            valueColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBoldLabel = false,
    bool isBoldValue = false,
    double fontSize = 14,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBoldLabel ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Future<void> _openLocationInMaps(double lat, double lng, String label) async {
    await CaptainContactUtils.openMapByCoordinates(context, lat, lng);
  }

  Widget _buildStickyActionBar() {
    final status = OrderStatus.fromString(_order!.status.value);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _callCustomer,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.phone_rounded, color: Colors.green),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    status == OrderStatus.delivered ||
                        status == OrderStatus.cancelled
                    ? null
                    : () {
                        final nextStatus = CaptainOrderHelpers.getNextStatus(
                          status,
                        );

                        if (!CaptainOrderHelpers.canTransition(
                          status,
                          nextStatus,
                        )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'لا يمكن الانتقال من ${CaptainOrderHelpers.getStatusText(status)} إلى ${CaptainOrderHelpers.getStatusText(nextStatus)}',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        if (CaptainOrderHelpers.requiresConfirmation(
                          nextStatus,
                        )) {
                          _confirmAndUpdate(nextStatus);
                        } else {
                          _updateOrderStatus(nextStatus);
                        }
                      },
                icon: Icon(CaptainOrderHelpers.getActionIcon(status), size: 20),
                label: Text(
                  _getActionText(status),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == OrderStatus.inTransit
                      ? Colors.green
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionText(OrderStatus status) =>
      CaptainOrderHelpers.getDeliveryActionText(status);

  /// تأكيد ثم تحديث الحالة (للإجراءات الحساسة كـ delivered)
  Future<void> _confirmAndUpdate(OrderStatus newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('تأكيد التسليم'),
        content: Text(CaptainOrderHelpers.getConfirmationMessage(newStatus)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('نعم، تم التسليم'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _updateOrderStatus(newStatus);
    }
  }


  void _updateOrderStatus(OrderStatus newStatus) async {
    if (_order == null) return;

    final currentStatus = OrderStatus.fromString(_order!.status.value);
    if (!CaptainOrderHelpers.canTransition(currentStatus, newStatus)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن الانتقال من ${CaptainOrderHelpers.getStatusText(currentStatus)} إلى ${CaptainOrderHelpers.getStatusText(newStatus)}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final success = await orderProvider.updateOrderStatus(
        _order!.id,
        newStatus.dbValue,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrderDetails();
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

  Future<void> _callCustomer() async {
    if (_order == null) return;
    await CaptainContactUtils.callPhone(
      context,
      _order!.clientPhone,
      unavailableMessage: 'رقم هاتف العميل غير متوفر',
    );
  }

  Future<void> _openInMaps() async {
    if (_order == null) return;

    final lat = _order!.deliveryLatitude;
    final lng = _order!.deliveryLongitude;
    if (lat != null && lng != null) {
      await CaptainContactUtils.openMapByCoordinates(context, lat, lng);
    } else {
      await CaptainContactUtils.openMapByAddress(
        context,
        _order!.deliveryAddress,
      );
    }
  }

  Future<void> _messageCustomer() async {
    if (_order == null) return;

    await CaptainContactUtils.sendSms(
      context,
      _order!.clientPhone,
      unavailableMessage: 'رقم هاتف العميل غير متوفر للمراسلة',
    );
  }

  void _reportProblem() {
    String? selectedProblem;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الإبلاغ عن مشكلة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر نوع المشكلة:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedProblem,
                items:
                    [
                          'عنوان غير صحيح',
                          'عميل غير متاح',
                          'مشكلة في الدفع',
                          'منتج ناقص',
                          'أخرى',
                        ]
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedProblem = value);
                },
                decoration: const InputDecoration(
                  labelText: 'نوع المشكلة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف المشكلة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selectedProblem == null
                  ? null
                  : () async {
                      final sent = await _submitProblemReport(
                        selectedProblem!,
                        descriptionController.text,
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'تم استلام بلاغك وسيتم مراجعته'
                                : 'تعذر إرسال البلاغ الآن، حاول مرة أخرى',
                          ),
                          backgroundColor: sent ? Colors.green : Colors.red,
                        ),
                      );
                    },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _submitProblemReport(
    String problemType,
    String description,
  ) async {
    if (_order == null) return false;
    try {
      final supabase = SupabaseConfig.client;
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final captain =
          authProvider.currentUserProfile ?? authProvider.currentProfile;

      if (captain == null) return false;

      await supabase.from('captain_problem_reports').insert({
        'captain_id': captain.id,
        'order_id': _order!.id,
        'problem_type': problemType,
        'description': description.trim().isEmpty ? null : description.trim(),
        'status': 'open',
        'priority': 'medium',
        'metadata': {
          'order_status': _order!.status.value,
          'store_name': _order!.storeName,
          'delivery_address': _order!.deliveryAddress,
          'reported_from': 'order_delivery_screen',
        },
      });

      await AdminNotificationService().notifyAdminOfSystemIssue(
        issueType: 'captain_delivery_problem',
        description: problemType,
        additionalData: {
          'order_id': _order!.id,
          'order_status': _order!.status.value,
          'captain_id': captain.id,
          'captain_name': captain.fullName,
          'problem_type': problemType,
          'details': description.trim(),
          'reported_at': DateTime.now().toIso8601String(),
        },
      );

      AppLogger.info('تم إرسال بلاغ مشكلة للكابتن على الطلب ${_order!.id}');
      return true;
    } catch (e) {
      AppLogger.error('فشل إرسال بلاغ المشكلة', e);
      return false;
    }
  }
}
