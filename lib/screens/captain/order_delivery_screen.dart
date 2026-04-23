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

      setState(() {
        _order = orderProvider.selectedOrder;
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
      body: ResponsiveCenter(
        maxWidth: 800,
        child: _isLoading
            ? AppShimmer.centeredLines(context)
            : (_order == null
                  ? const Center(child: Text('فشل تحميل تفاصيل الطلب'))
                  : _buildDeliveryInterface()),
      ),
      bottomNavigationBar: _order != null && !_isLoading
          ? _buildStickyActionBar()
          : null,
    );
  }

  Widget _buildDeliveryInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
      child: Column(
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildMapSection(),
          const SizedBox(height: 24),
          _buildOrderInfoCard(),
          const SizedBox(height: 16),
          _buildAddressCard(),
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

  Future<void> _openLocationInMaps(double lat, double lng, String label) async {
    await CaptainContactUtils.openMapByCoordinates(context, lat, lng);
  }

  Widget _buildOrderInfoCard() {
    final order = _order!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text(
                'ملخص الطلب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '#${order.id.substring(0, 8).toUpperCase()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _buildInfoRow('طريقة الدفع', order.paymentMethod.displayName),
          // 🏪 معلومات المتجر
          if (order.storeName != null)
            _buildInfoRow('المتجر', order.storeName!),
          if (order.storeAddress != null)
            _buildInfoRow('عنوان المتجر', order.storeAddress!),
          if (order.storePhone != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'هاتف المتجر',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Row(
                    children: [
                      Text(
                        order.storePhone!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            CaptainContactUtils.callPhone(
                              context,
                              order.storePhone,
                              unavailableMessage: 'رقم هاتف المتجر غير متوفر',
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.phone_callback_rounded,
                              size: 18,
                              color: Colors.teal[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          if (order.clientName != null)
            _buildInfoRow('العميل', order.clientName!),
          if (order.clientPhone != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم الهاتف',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Row(
                    children: [
                      Text(
                        order.clientPhone!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _callCustomer,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.phone_callback_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          _buildInfoRow(
            'تكلفة التوصيل',
            '${order.deliveryFee.toStringAsFixed(2)} ج.م',
          ),
          _buildInfoRow(
            'المبلغ الإجمالي',
            '${order.totalAmount.toStringAsFixed(2)} ج.م',
            isBold: true,
          ),
          if (order.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ملاحظات: ${order.notes}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'عنوان التوصيل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _order!.deliveryAddress,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map),
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

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
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
