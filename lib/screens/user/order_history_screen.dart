import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/user/order_tracking_screen.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/screens/user/rate_order_screen.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  List<_OrderGroup> _groupOrders(List<OrderModel> orders) {
    final Map<String, List<OrderModel>> grouped = {};
    for (final order in orders) {
      final groupId = order.orderGroupId ?? order.id;
      grouped.putIfAbsent(groupId, () => []);
      grouped[groupId]!.add(order);
    }

    return grouped.entries
        .map((entry) => _OrderGroup(id: entry.key, orders: entry.value))
        .toList();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // التحقق من تسجيل الدخول ووجود الملف الشخصي
    if (authProvider.isLoggedIn && authProvider.currentProfile != null) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      try {
        await orderProvider.fetchUserOrders(authProvider.currentProfile!.id);
      } catch (e) {
        // تجاهل الأخطاء الصامتة - ستظهر في الشاشة عبر provider.error
      } finally {
        if (mounted) {
          setState(() => _isRefreshing = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _checkLoginForAction(VoidCallback action, {String? loginMessage}) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginMessage ?? 'يرجى تسجيل الدخول أولاً'),
          action: SnackBarAction(
            label: 'تسجيل الدخول',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<SupabaseProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 24),
                SizedBox(width: 12),
                Text('طلباتي'),
              ],
            ),
            centerTitle: true,
            bottom: authProvider.isLoggedIn
                ? TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.local_shipping_rounded),
                        text: 'الطلبات النشطة',
                      ),
                      Tab(
                        icon: Icon(Icons.cancel_outlined),
                        text: 'الطلبات الملغاة',
                      ),
                    ],
                  )
                : null,
          ),
          body: ResponsiveCenter(
            maxWidth: 900,
            child: SafeArea(
              child: authProvider.isLoggedIn
                  ? Consumer<OrderProvider>(
                      builder: (context, orderProvider, child) {
                        return RefreshIndicator(
                          onRefresh: _loadOrders,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.vertical,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildActiveOrdersTab(orderProvider, colorScheme),
                              _buildCancelledOrdersTab(
                                orderProvider,
                                colorScheme,
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : _buildLoginPrompt(colorScheme),
            ),
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

  Widget _buildLoginPrompt(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'سجل دخولك لعرض طلباتك',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'يمكنك عرض تاريخ طلباتك وتتبع حالة الطلبات الحالية بسهولة',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              icon: const Icon(Icons.login_rounded),
              label: const Text('تسجيل الدخول'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 18,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrdersTab(
    OrderProvider provider,
    ColorScheme colorScheme,
  ) {
    if (provider.isLoading || _isRefreshing) {
      return AppShimmer.list(context);
    }

    if (provider.error != null) {
      return _buildRefreshablePlaceholder(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 80, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allOrders = [...provider.currentOrders, ...provider.pastOrders];
    final activeGroups = _groupOrders(
      allOrders,
    ).where((group) => !group.isAllCancelled).toList();

    if (activeGroups.isEmpty) {
      return _buildRefreshablePlaceholder(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 100,
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'لا توجد طلبات نشطة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ابدأ بالتسوق واطلب منتجاتك المفضلة',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('ابدأ التسوق'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // عرض الطلبات النشطة
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: activeGroups.length,
      itemBuilder: (context, index) {
        final group = activeGroups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _OrderGroupCard(
            key: ValueKey(group.id),
            group: group,
            onTap: () => _checkLoginForAction(() {
              final firstOrder = group.orders.first;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(
                    orderId: firstOrder.id,
                    orderNumber: firstOrder.orderNumber,
                  ),
                ),
              );
            }, loginMessage: 'يرجى تسجيل الدخول لعرض تفاصيل الطلب'),
          ),
        );
      },
    );
  }

  Widget _buildCancelledOrdersTab(
    OrderProvider provider,
    ColorScheme colorScheme,
  ) {
    if (provider.isLoading || _isRefreshing) {
      return AppShimmer.list(context);
    }

    if (provider.error != null) {
      return _buildRefreshablePlaceholder(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 80, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allOrders = [...provider.currentOrders, ...provider.pastOrders];
    final cancelledGroups = _groupOrders(
      allOrders,
    ).where((group) => group.isAllCancelled).toList();

    if (cancelledGroups.isEmpty) {
      return _buildRefreshablePlaceholder(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'لا توجد طلبات ملغاة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'جميع طلباتك تم تنفيذها بنجاح! 🎉',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // عرض الطلبات الملغاة
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: cancelledGroups.length,
      itemBuilder: (context, index) {
        final group = cancelledGroups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _OrderGroupCard(
            key: ValueKey(group.id),
            group: group,
            onTap: () => _checkLoginForAction(() {
              final firstOrder = group.orders.first;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(
                    orderId: firstOrder.id,
                    orderNumber: firstOrder.orderNumber,
                  ),
                ),
              );
            }, loginMessage: 'يرجى تسجيل الدخول لعرض تفاصيل الطلب'),
          ),
        );
      },
    );
  }
}

class _OrderGroup {
  final String id;
  final List<OrderModel> orders;

  _OrderGroup({required this.id, required this.orders});

  double get totalAmount =>
      orders.fold<double>(0, (sum, order) => sum + order.totalAmount);

  List<String> get storeNames =>
      orders.map((order) => order.storeName ?? 'المتجر').toSet().toList();

  bool get isAllCancelled => orders.every(
    (order) =>
        OrderStatusExtension.fromDbValue(order.status.value) ==
        OrderStatus.cancelled,
  );

  int get storesCount => orders.length;

  int get itemsCount =>
      orders.fold<int>(0, (sum, order) => sum + order.items.length);

  OrderStatus get groupStatus {
    if (orders.isEmpty) return OrderStatus.pending;

    if (orders.every(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.cancelled,
    )) {
      return OrderStatus.cancelled;
    }

    if (orders.every(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.delivered,
    )) {
      return OrderStatus.delivered;
    }

    if (orders.any(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.pending,
    )) {
      return OrderStatus.pending;
    }

    if (orders.any(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.confirmed,
    )) {
      return OrderStatus.confirmed;
    }

    if (orders.any(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.preparing,
    )) {
      return OrderStatus.preparing;
    }

    if (orders.any(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.ready,
    )) {
      return OrderStatus.ready;
    }

    if (orders.any(
      (order) =>
          OrderStatusExtension.fromDbValue(order.status.value) ==
          OrderStatus.inTransit,
    )) {
      return OrderStatus.inTransit;
    }

    return OrderStatus.pending;
  }
}

class _OrderGroupCard extends StatefulWidget {
  final _OrderGroup group;
  final VoidCallback onTap;

  const _OrderGroupCard({super.key, required this.group, required this.onTap});

  @override
  State<_OrderGroupCard> createState() => _OrderGroupCardState();
}

class _OrderGroupCardState extends State<_OrderGroupCard> {
  late final Future<List<OrderItemModel>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadGroupItems();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = OrderStatusExtension.fromDbValue(
      widget.group.groupStatus.value,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${widget.group.orders.first.orderNumber ?? widget.group.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(widget.group.orders.first.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'المتاجر: ${widget.group.storeNames.join('، ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'عدد المتاجر: ${widget.group.storesCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.group.itemsCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'عدد المنتجات: ${widget.group.itemsCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'الإجمالي: ${widget.group.totalAmount.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status == OrderStatus.delivered) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final rated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RateOrderScreen(orders: widget.group.orders),
                        ),
                      );
                      // تحديث الشاشة بعد التقييم بنجاح
                      if (rated == true && context.mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('تقييم الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber[800]!),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FutureBuilder<List<OrderItemModel>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'تعذر تحميل المنتجات',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    );
                  }

                  final items = snapshot.data ?? const <OrderItemModel>[];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'لا توجد منتجات لعرضها',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return Column(
                    children: items
                        .map((item) => _GroupItemRow(item: item))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<OrderItemModel>> _loadGroupItems() async {
    final items = <OrderItemModel>[];
    for (final order in widget.group.orders) {
      if (order.items.isNotEmpty) {
        items.addAll(order.items);
      } else {
        final fetched = await OrderService.getOrderItems(order.id);
        items.addAll(fetched);
      }
    }
    return items;
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '${date.day}/${date.month}/${date.year} ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _GroupItemRow extends StatelessWidget {
  final OrderItemModel item;

  const _GroupItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumb(imageUrl: item.productImage),
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
                  'الكمية: ${item.quantity} • ${item.productPrice.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.selectedOptions != null &&
                    item.selectedOptions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.selectedOptions!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' | '),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'ملاحظات: ${item.specialInstructions}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.totalPrice.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;

  const _ProductThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          child: imageUrl == null || imageUrl!.isEmpty
              ? Icon(
                  Icons.shopping_bag_outlined,
                  color: colorScheme.onSurfaceVariant,
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.image_not_supported_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  memCacheWidth: 160,
                  memCacheHeight: 160,
                ),
        ),
      ),
    );
  }
}
