import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/widgets/order_card.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

/// فلتر مجمّع يدمج الحالات المتشابهة لتبسيط الواجهة
enum MerchantOrderFilter {
  newOrders, // pending + confirmed
  inProgress, // preparing + ready
  delivery, // pickedUp + inTransit
  completed, // delivered
  cancelled; // cancelled

  String get label {
    switch (this) {
      case MerchantOrderFilter.newOrders:
        return 'جديد';
      case MerchantOrderFilter.inProgress:
        return 'قيد التحضير';
      case MerchantOrderFilter.delivery:
        return 'في التوصيل';
      case MerchantOrderFilter.completed:
        return 'مكتملة';
      case MerchantOrderFilter.cancelled:
        return 'ملغية';
    }
  }

  IconData get icon {
    switch (this) {
      case MerchantOrderFilter.newOrders:
        return Icons.notification_important_rounded;
      case MerchantOrderFilter.inProgress:
        return Icons.inventory_2_rounded;
      case MerchantOrderFilter.delivery:
        return Icons.local_shipping_rounded;
      case MerchantOrderFilter.completed:
        return Icons.check_circle_rounded;
      case MerchantOrderFilter.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MerchantOrderFilter.newOrders:
        return const Color(0xFFFF9800); // orange
      case MerchantOrderFilter.inProgress:
        return const Color(0xFF2196F3); // blue
      case MerchantOrderFilter.delivery:
        return const Color(0xFF9C27B0); // purple
      case MerchantOrderFilter.completed:
        return const Color(0xFF4CAF50); // green
      case MerchantOrderFilter.cancelled:
        return const Color(0xFFF44336); // red
    }
  }

  /// الحالات الفعلية التي ينتمي لها هذا الفلتر
  List<OrderStatus> get statuses {
    switch (this) {
      case MerchantOrderFilter.newOrders:
        return [OrderStatus.pending, OrderStatus.confirmed];
      case MerchantOrderFilter.inProgress:
        return [OrderStatus.preparing, OrderStatus.ready];
      case MerchantOrderFilter.delivery:
        return [OrderStatus.pickedUp, OrderStatus.inTransit];
      case MerchantOrderFilter.completed:
        return [OrderStatus.delivered];
      case MerchantOrderFilter.cancelled:
        return [OrderStatus.cancelled];
    }
  }

  bool matches(OrderStatus status) => statuses.contains(status);
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  MerchantOrderFilter _selectedFilter = MerchantOrderFilter.newOrders;
  bool _isInitialized = false; // لمنع التحديث المستمر
  StoreModel? _store; // بيانات المتجر لتحديد وضع التوصيل

  /// هل التوصيل عبر التطبيق (كابتن) أم المتجر نفسه؟
  bool get _isAppDelivery => _store?.deliveryMode == 'app';

  final Map<String, Future<Map<String, dynamic>?>> _clientProfileFutures = {};

  Future<Map<String, dynamic>?> _fetchClientProfile(String clientId) {
    return _clientProfileFutures.putIfAbsent(
      clientId,
      () => Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', clientId)
          .maybeSingle(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantOrders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // تأجيل التحميل حتى ينتهي الـ build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMerchantOrders();
      });
    }
  }

  Future<void> _loadMerchantOrders({bool forceRefresh = false}) async {
    // منع التحديث إذا كانت البيانات محملة بالفعل إلا لو كان Refresh
    if (_isInitialized && !forceRefresh) return;

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final merchantProvider = Provider.of<MerchantProvider>(
        context,
        listen: false,
      );
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      debugPrint('🔍 بدء تحميل طلبات التاجر...');

      // تحميل بيانات التاجر أولاً إذا لم تكن محملة
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        if (merchantProvider.selectedMerchant == null &&
            !merchantProvider.isLoading) {
          debugPrint('📥 جلب بيانات التاجر...');
          await merchantProvider.fetchMerchantByProfileId(
            authProvider.currentUserProfile!.id,
          );
        }

        // جلب الطلبات الخاصة بالتاجر
        if (merchantProvider.selectedMerchant != null) {
          debugPrint('✅ معرف التاجر: ${merchantProvider.selectedMerchant!.id}');
          debugPrint('📦 جلب الطلبات...');
          await orderProvider.fetchMerchantOrders(
            merchantProvider.selectedMerchant!.id,
          );
          debugPrint('✅ تم جلب ${orderProvider.orders.length} طلب');

          // جلب بيانات المتجر لتحديد وضع التوصيل (store/app)
          if (_store == null) {
            final store = await StoreService.getStoreByMerchantIdV2(
              merchantProvider.selectedMerchant!.id,
            );
            if (store != null && mounted) {
              setState(() => _store = store);
              debugPrint('🚚 وضع التوصيل: ${store.deliveryMode}');
            }
          }

          if (mounted) {
            setState(() {
              _isInitialized = true; // تم التحميل بنجاح
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب طلبات التاجر: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('الطلبات'), centerTitle: true),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: () => _loadMerchantOrders(forceRefresh: true),
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildOrdersList(orderProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 2.05,
        children: MerchantOrderFilter.values.map((filter) {
          final count = orders.where((o) {
            final s = OrderStatusExtension.fromDbValue(o.status.value);
            return filter.matches(s);
          }).length;
          final isSelected = _selectedFilter == filter;

          return _buildFilterChip(
            filter: filter,
            count: count,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedFilter = filter),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip({
    required MerchantOrderFilter filter,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = filter.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 13,
                color: isSelected ? color : Colors.grey[500],
              ),
              const SizedBox(height: 0.5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? color : Colors.grey[700],
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 0.5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return _buildShimmerList();
    }

    if (provider.error != null &&
        provider.error!.isNotEmpty &&
        provider.orders.isEmpty) {
      return _buildErrorState(provider.error!);
    }

    final filteredOrders = provider.orders.where((order) {
      final status = OrderStatusExtension.fromDbValue(order.status.value);
      return _selectedFilter.matches(status);
    }).toList();

    if (filteredOrders.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedFilter.icon,
                  size: 72,
                  color: _selectedFilter.color.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات ${_selectedFilter.label}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اسحب للأسفل للتحديث',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return OrderCard(
          order: order,
          onTap: () {
            _showOrderActions(order);
          },
        );
      },
    );
  }

  Widget _buildShimmerList() {
    final cs = Theme.of(context).colorScheme;
    return AppShimmer.wrap(
      context,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 72, color: Colors.red),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadMerchantOrders(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderActions(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final orderStatus = OrderStatusExtension.fromDbValue(
          order.status.value,
        );
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إجراءات الطلب #${order.id.substring(0, 8)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildClientInfoSection(order, colorScheme),
                  const SizedBox(height: 16),
                  _buildAddressSection(order, colorScheme),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'منتجات الطلب',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<OrderItemModel>>(
                    future: OrderService.getOrderItems(order.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'تعذر تحميل المنتجات',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final items = snapshot.data ?? const <OrderItemModel>[];
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('لا توجد منتجات في هذا الطلب'),
                        );
                      }

                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: items
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    title: Text(
                                      item.productName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الكمية: ${item.quantity} • ${item.productPrice.toStringAsFixed(2)} ج.م',
                                        ),
                                        if (item.selectedOptions != null &&
                                            item.selectedOptions!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              item.selectedOptions!.entries
                                                  .map(
                                                    (e) =>
                                                        '${e.key}: ${e.value}',
                                                  )
                                                  .join(' | '),
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (item.specialInstructions != null &&
                                            item
                                                .specialInstructions!
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'ملاحظات: ${item.specialInstructions}',
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '${item.totalPrice.toStringAsFixed(2)} ج.م',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // التحقق من وجود كابتن لتحديد صلاحيات التاجر
                  ..._buildMerchantActions(order, orderStatus),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء أزرار الإجراءات حسب وضع التوصيل (store = المتجر يوصل / app = كابتن يوصل)
  List<Widget> _buildMerchantActions(
    OrderModel order,
    OrderStatus orderStatus,
  ) {
    // الأزرار المشتركة لكل الطلبات
    if (orderStatus == OrderStatus.pending) {
      return [
        _buildActionButton(
          'قبول وبدء التحضير',
          Icons.check,
          Colors.green,
          () => _updateOrderStatus(order, OrderStatus.preparing),
        ),
        _buildActionButton(
          'رفض الطلب',
          Icons.close,
          Colors.red,
          () => _updateOrderStatus(order, OrderStatus.cancelled),
        ),
      ];
    }

    if (orderStatus == OrderStatus.confirmed) {
      return [
        _buildActionButton(
          'بدء التحضير',
          Icons.inventory,
          Colors.blue,
          () => _updateOrderStatus(order, OrderStatus.preparing),
        ),
      ];
    }

    if (orderStatus == OrderStatus.preparing) {
      if (_isAppDelivery) {
        return [
          _buildActionButton(
            'جاهز - تسليم للكابتن 🚚',
            Icons.delivery_dining,
            Colors.orange,
            () => _updateOrderStatus(order, OrderStatus.ready),
          ),
        ];
      } else {
        return [
          _buildActionButton(
            'جاهز - خروج للتوصيل 🚗',
            Icons.local_shipping,
            Colors.orange,
            () => _updateOrderStatus(order, OrderStatus.inTransit),
          ),
        ];
      }
    }

    // إذا كان الطلب جاهز
    if (orderStatus == OrderStatus.ready) {
      if (_isAppDelivery) {
        return [
          _buildActionButton(
            'تسليم للكابتن 🚚',
            Icons.delivery_dining,
            Colors.orange,
            () => _updateOrderStatus(order, OrderStatus.ready),
          ),
        ];
      } else {
        return [
          _buildActionButton(
            'خروج للتوصيل 🚗',
            Icons.local_shipping,
            Colors.orange,
            () => _updateOrderStatus(order, OrderStatus.inTransit),
          ),
        ];
      }
    }

    // إذا كان الطلب في الطريق
    if (orderStatus == OrderStatus.inTransit ||
        orderStatus == OrderStatus.pickedUp) {
      if (_isAppDelivery) {
        // إذا كان هناك كابتن: لا يمكن للتاجر التحكم (الكابتن يتحكم)
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الطلب الآن مع الكابتن 🚚\nالكابتن هو المسؤول عن التسليم',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      } else {
        // إذا لم يكن هناك كابتن: المتجر يمكنه تأكيد التسليم مباشرة
        return [
          _buildActionButton(
            'تم التسليم للعميل ✅',
            Icons.check_circle,
            Colors.green,
            () => _updateOrderStatus(order, OrderStatus.delivered),
          ),
        ];
      }
    }

    // إذا كان الطلب مكتمل أو ملغي
    if (orderStatus == OrderStatus.delivered ||
        orderStatus == OrderStatus.cancelled) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: orderStatus == OrderStatus.delivered
                ? Colors.green[50]
                : Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    orderStatus == OrderStatus.delivered
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: orderStatus == OrderStatus.delivered
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    orderStatus == OrderStatus.delivered
                        ? 'تم التسليم بنجاح'
                        : 'تم الإلغاء',
                    style: TextStyle(
                      color: orderStatus == OrderStatus.delivered
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [];
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    Navigator.pop(context);

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final ok = await orderProvider.updateOrderStatus(
        order.id,
        newStatus.dbValue,
      );

      if (!mounted) return;

      final message = ok
          ? 'تم تحديث حالة الطلب بنجاح'
          : (orderProvider.error?.isNotEmpty == true
                ? orderProvider.error!
                : 'تعذر تحديث حالة الطلب');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildClientInfoSection(OrderModel order, ColorScheme colorScheme) {
    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.person_rounded,
      title: 'معلومات العميل',
      children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchClientProfile(order.clientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: AppShimmer.centeredLines(context),
              );
            }

            final data = snapshot.data;
            final fullName = (data?['full_name'] as String?)?.trim();
            final phone = (data?['phone'] as String?)?.trim();

            return Column(
              children: [
                _buildInfoRow(
                  icon: Icons.badge_rounded,
                  label: 'الاسم',
                  value: (fullName == null || fullName.isEmpty)
                      ? 'غير متاح'
                      : fullName,
                ),
                _buildInfoRow(
                  icon: Icons.phone_rounded,
                  label: 'رقم الهاتف',
                  value: (phone == null || phone.isEmpty) ? 'غير متاح' : phone,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddressSection(OrderModel order, ColorScheme colorScheme) {
    final address = order.deliveryAddress.trim();
    final notes = (order.deliveryNotes ?? '').trim();
    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.location_on_rounded,
      title: 'عنوان التوصيل',
      children: [
        _buildInfoRow(
          icon: Icons.place_rounded,
          label: 'العنوان',
          value: address.isEmpty ? 'غير متاح' : address,
        ),
        if (notes.isNotEmpty)
          _buildInfoRow(
            icon: Icons.notes_rounded,
            label: 'ملاحظات',
            value: notes,
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
}
