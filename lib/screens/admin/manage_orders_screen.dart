import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_contact_utils.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: Column(
          children: [
            _buildStatsRow(orderProvider),
            _buildSearchAndFilterBar(),
            Expanded(child: _buildOrdersList(orderProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(OrderProvider provider) {
    final stats = [
      _StatInfo("الكل", provider.orders.length, Icons.receipt_long_rounded, [
        const Color(0xFF667eea),
        const Color(0xFF764ba2),
      ]),
      _StatInfo(
        "قيد التنفيذ",
        provider.orders.where((o) => o.status == OrderStatus.pending).length,
        Icons.schedule_rounded,
        [const Color(0xFFfa709a), const Color(0xFFfee140)],
      ),
      _StatInfo(
        "مكتمل",
        provider.orders.where((o) => o.status == OrderStatus.delivered).length,
        Icons.check_circle_rounded,
        [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      ),
      _StatInfo(
        "ملغي",
        provider.orders.where((o) => o.status == OrderStatus.cancelled).length,
        Icons.cancel_rounded,
        [const Color(0xFFf5576c), const Color(0xFFf093fb)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: stats.map((stat) {
          return Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + stats.indexOf(stat) * 100),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: stat.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: stat.colors[0].withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stat.icon,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stat.value.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return AdminSearchBar(
      controller: _searchController,
      hintText: 'ابحث برقم الطلب',
      onChanged: (_) => setState(() {}),
      filterChips: [
        _buildFilterChip('الكل', 'all'),
        _buildFilterChip('قيد التنفيذ', OrderStatus.pending.value),
        _buildFilterChip('مكتمل', OrderStatus.delivered.value),
        _buildFilterChip('ملغي', OrderStatus.cancelled.value),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF667eea),
        backgroundColor: Colors.grey.shade100,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        elevation: isSelected ? 2 : 0,
        shadowColor: const Color(0xFF667eea).withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return AppShimmer.list(context);
    }

    if (provider.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد طلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'ستظهر الطلبات هنا عند إنشائها',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final filteredOrders = _filterOrders(provider.orders);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        if (_searchController.text.isNotEmpty &&
            !order.id.contains(_searchController.text)) {
          return const SizedBox.shrink();
        }
        return _buildOrderCard(order, index);
      },
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'pending':
        return orders.where((o) => o.status == OrderStatus.pending).toList();
      case 'delivered':
        return orders.where((o) => o.status == OrderStatus.delivered).toList();
      case 'cancelled':
        return orders.where((o) => o.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFfa709a);
      case OrderStatus.confirmed:
        return const Color(0xFF4facfe);
      case OrderStatus.preparing:
        return const Color(0xFFfee140);
      case OrderStatus.ready:
        return const Color(0xFF43e97b);
      case OrderStatus.pickedUp:
        return const Color(0xFF30cfd0);
      case OrderStatus.inTransit:
        return const Color(0xFF667eea);
      case OrderStatus.delivered:
        return const Color(0xFF43e97b);
      case OrderStatus.cancelled:
        return const Color(0xFFf5576c);
    }
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.preparing:
        return 'قيد التحضير';
      case OrderStatus.ready:
        return 'جاهز';
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

  Widget _buildOrderCard(OrderModel order, int index) {
    final statusClr = _statusColor(order.status);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: statusClr.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _viewOrderDetails(order),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusClr,
                              statusClr.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: statusClr.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "طلب #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "العميل: ${(order.clientName != null && order.clientName!.trim().isNotEmpty) ? order.clientName! : (order.clientPhone != null && order.clientPhone!.isNotEmpty ? order.clientPhone! : 'عميل بدون اسم')}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusClr.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(order.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusClr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "الإجمالي",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          "${order.totalAmount} ج.م",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildSmallAction(
                        Icons.visibility_rounded,
                        const Color(0xFF4facfe),
                        () => _viewOrderDetails(order),
                      ),
                      const SizedBox(width: 6),
                      _buildSmallAction(
                        Icons.edit_rounded,
                        const Color(0xFF43e97b),
                        () => _changeOrderStatus(order),
                      ),
                      const SizedBox(width: 6),
                      _buildSmallAction(
                        Icons.delete_rounded,
                        Colors.red.shade400,
                        () => _deleteOrder(order),
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

  Widget _buildSmallAction(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  /// 🔹 عرض تفاصيل الطلب
  void _viewOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          child: SingleChildScrollView(
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'تفاصيل الطلب',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "رقم الطلب: #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text("الحالة: ${_statusLabel(order.status)}"),
              const SizedBox(height: 4),
              Text("طريقة الدفع: ${order.paymentMethod.displayName}"),
              const SizedBox(height: 4),
              Text("تاريخ الطلب: ${order.createdAtFormatted}"),
              const Divider(height: 24),
              const Text("بيانات العميل:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("الاسم: ${(order.clientName != null && order.clientName!.trim().isNotEmpty) ? order.clientName! : 'عميل بدون اسم'}"),
              if (order.clientPhone != null && order.clientPhone!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text("الهاتف: ${order.clientPhone}"),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => CaptainContactUtils.callPhone(
                        context,
                        order.clientPhone,
                        unavailableMessage: 'رقم هاتف العميل غير متوفر',
                      ),
                      child: const Icon(Icons.phone, color: Colors.green, size: 16),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (order.storeName != null || order.storePhone != null) ...[
                const Text("بيانات المتجر:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (order.storeName != null) Text("المتجر: ${order.storeName}"),
                if (order.storePhone != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("الهاتف: ${order.storePhone}"),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => CaptainContactUtils.callPhone(
                          context,
                          order.storePhone,
                          unavailableMessage: 'رقم هاتف المتجر غير متوفر',
                        ),
                        child: const Icon(Icons.phone, color: Colors.green, size: 16),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              const Divider(height: 24),
              const Text(
                "المنتجات:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<OrderItemModel>>(
                future: OrderService.getOrderItems(order.id),
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
                    return const Text("تعذر تحميل المنتجات");
                  }
                  final items = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item.quantity}x ${item.productName}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
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
                                        Text(
                                          attributes,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      if (addonsText.isNotEmpty)
                                        Text(
                                          addonsText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            if (item.specialInstructions != null &&
                                item.specialInstructions!.isNotEmpty)
                              Text(
                                "ملاحظات: ${item.specialInstructions}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("قيمة المنتجات:"),
                  Text("${((order.totalAmount - order.deliveryFee - order.taxAmount + order.discountAmount).clamp(0.0, double.infinity)).toStringAsFixed(2)} ج.م"),
                ],
              ),
              const SizedBox(height: 6),
              if (order.discountAmount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("خصم الكوبون ${order.couponCode != null ? "(${order.couponCode})" : ""}:", style: TextStyle(color: Colors.red[700])),
                    Text("-${order.discountAmount.toStringAsFixed(2)} ج.م", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("رسوم التوصيل:"),
                  Text("${order.deliveryFee.toStringAsFixed(2)} ج.م"),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("الإجمالي الكلي:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${order.totalAmount.toStringAsFixed(2)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF667eea))),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// 🔹 تغيير حالة الطلب
  void _changeOrderStatus(OrderModel order) {
    String selectedStatus = order.status.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'تغيير حالة الطلب',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              items: [
                DropdownMenuItem(
                  value: OrderStatus.pending.value,
                  child: const Text("في الانتظار"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.confirmed.value,
                  child: const Text("مؤكد"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.preparing.value,
                  child: const Text("قيد التحضير"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.ready.value,
                  child: const Text("جاهز"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.pickedUp.value,
                  child: const Text("تم الاستلام"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.inTransit.value,
                  child: const Text("في الطريق"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.delivered.value,
                  child: const Text("تم التوصيل"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.cancelled.value,
                  child: const Text("ملغي"),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() {
                    selectedStatus = value;
                  });
                }
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              Navigator.pop(context);
              final success = await orderProvider.updateOrderStatus(order.id, selectedStatus);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? 'تم تحديث حالة الطلب بنجاح' : 'فشل تحديث حالة الطلب'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// 🔹 حذف الطلب
  void _deleteOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'حذف الطلب',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الطلب #${order.id}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade300],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                Navigator.pop(context);
                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('orders').delete().eq('id', order.id);
                  orderProvider.fetchAllOrders();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الطلب بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('فشل حذف الطلب: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatInfo {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;
  const _StatInfo(this.title, this.value, this.icon, this.colors);
}
