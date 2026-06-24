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
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/core/logger.dart';


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
  bool _isLoadingData = false;
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

  /// فلترة ديناميكية حسب وضع التوصيل:
  /// - store: كما هي من `MerchantOrderFilter.statuses`
  /// - app: الطلبات تذهب مباشرة للدليفري (ready) بدون قبول التاجر
  bool _matchesFilterForCurrentDeliveryMode(
    MerchantOrderFilter filter,
    OrderStatus status,
  ) {
    if (!_isAppDelivery) return filter.matches(status);

    switch (filter) {
      case MerchantOrderFilter.newOrders:
        return status == OrderStatus.pending ||
            status == OrderStatus.confirmed;
      case MerchantOrderFilter.inProgress:
        return status == OrderStatus.preparing;
      case MerchantOrderFilter.delivery:
        return status == OrderStatus.ready ||
            status == OrderStatus.pickedUp ||
            status == OrderStatus.inTransit;
      case MerchantOrderFilter.completed:
        return status == OrderStatus.delivered;
      case MerchantOrderFilter.cancelled:
        return status == OrderStatus.cancelled;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantOrders();
    });
  }

  @override
  void dispose() {
    super.dispose();
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
    if (_isLoadingData) return;
    if (_isInitialized && !forceRefresh) return;

    _isLoadingData = true;

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
        if (authProvider.currentUserProfile == null) {
          debugPrint('⏳ لم يتم تحميل بيانات المستخدم بعد');
          return;
        }

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
    } finally {
      _isLoadingData = false;
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
            return _matchesFilterForCurrentDeliveryMode(filter, s);
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
      return _matchesFilterForCurrentDeliveryMode(_selectedFilter, status);
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
      useSafeArea: true,
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
                  _buildPrescriptionPreviewSection(order, colorScheme),
                  if (order.discountAmount > 0) ...[
                    const SizedBox(height: 16),
                    _buildCouponInfoSection(order, colorScheme),
                  ],
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
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        color: colorScheme.surfaceContainerHighest,
                                        child: item.productImage != null && item.productImage!.isNotEmpty
                                            ? Image.network(
                                                item.productImage!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.image_not_supported,
                                                    size: 20,
                                                    color: colorScheme.outline,
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.image,
                                                size: 20,
                                                color: colorScheme.outline,
                                              ),
                                      ),
                                    ),
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
                                                        style: const TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 11,
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
    final isPrescription = _isPrescriptionOrder(order);
    if (isPrescription && orderStatus == OrderStatus.pending) {
      return [
        _buildActionButton(
          'تسعير وتأكيد منتجات الروشتة ✏️',
          Icons.edit_note_rounded,
          Colors.teal,
          () {
            Navigator.pop(context);
            _showPricingSheet(order);
          },
        ),
      ];
    }

    // الأزرار المشتركة لكل الطلبات
    if (orderStatus == OrderStatus.pending || orderStatus == OrderStatus.ready) {
      if (_isAppDelivery) {
        // الطلبات تذهب مباشرة لمكتب التوصيل — التاجر للاطلاع فقط
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تم تحويل الطلب لمكتب التوصيل تلقائياً وهو بانتظار تعيين كابتن',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      }

      // للمتجر الذي يوصل بنفسه: يبدأ التحضير مباشرة
      if (orderStatus == OrderStatus.pending) {
        return [
          _buildActionButton(
            'بدء التحضير',
            Icons.inventory,
            Colors.blue,
            () => _updateOrderStatus(order, OrderStatus.preparing),
          ),
        ];
      }
    }

    if (orderStatus == OrderStatus.confirmed) {
      if (_isAppDelivery) {
        return [
          _buildActionButton(
            'تحويل للدليفري 🚚',
            Icons.local_shipping_rounded,
            Colors.orange,
            () => _updateOrderStatus(order, OrderStatus.ready),
          ),
        ];
      }

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
            'تحويل للدليفري 🚚',
            Icons.local_shipping_rounded,
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
    final cleanNotesText = _cleanNotes(order);
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
        if (cleanNotesText.isNotEmpty)
          _buildInfoRow(
            icon: Icons.notes_rounded,
            label: 'ملاحظات',
            value: cleanNotesText,
          ),
      ],
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

  Widget _buildPrescriptionPreviewSection(OrderModel order, ColorScheme colorScheme) {
    final isPrescription = _isPrescriptionOrder(order);
    if (!isPrescription) return const SizedBox.shrink();

    final url = _getPrescriptionUrl(order);
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'روشتة العميل 📄',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showZoomableImageDialog(url),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
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
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 36),
                      SizedBox(height: 4),
                      Text(
                        'اضغط للمعاينة وتكبير الصورة 🔍',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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

  void _showPricingSheet(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _PricingSheetWidget(
          order: order,
          onSuccess: () {
            _loadMerchantOrders(forceRefresh: true);
          },
        );
      },
    );
  }

  Widget _buildCouponInfoSection(OrderModel order, ColorScheme colorScheme) {
    return _buildInfoCard(
      colorScheme: colorScheme,
      icon: Icons.card_giftcard_rounded,
      title: 'معلومات الكوبون والخصم',
      children: [
        _buildInfoRow(
          icon: Icons.qr_code_rounded,
          label: 'كود الكوبون',
          value: order.couponCode ?? 'خصم تلقائي / عرض',
        ),
        _buildInfoRow(
          icon: Icons.monetization_on_rounded,
          label: 'قيمة الخصم',
          value: '${order.discountAmount.toStringAsFixed(2)} ج.م',
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

class _PricingSheetWidget extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onSuccess;

  const _PricingSheetWidget({
    required this.order,
    required this.onSuccess,
  });

  @override
  State<_PricingSheetWidget> createState() => _PricingSheetWidgetState();
}

class _PricingSheetWidgetState extends State<_PricingSheetWidget> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  final List<Map<String, dynamic>> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item['nameController']?.dispose();
      item['priceController']?.dispose();
      item['quantityController']?.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _items.add({
        'nameController': TextEditingController(),
        'priceController': TextEditingController(),
        'quantityController': TextEditingController(text: '1'),
      });
    });
  }

  void _removeRow(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed['nameController']?.dispose();
      removed['priceController']?.dispose();
      removed['quantityController']?.dispose();
    });
  }

  double _calculateSubtotal() {
    double total = 0.0;
    for (final item in _items) {
      final price = double.tryParse(item['priceController']?.text ?? '0') ?? 0.0;
      final qty = int.tryParse(item['quantityController']?.text ?? '1') ?? 1;
      total += price * qty;
    }
    return total;
  }

  Future<void> _savePrice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final subtotal = _calculateSubtotal();
      final totalAmount = subtotal + widget.order.deliveryFee;

      await _supabase
          .from('order_items')
          .delete()
          .eq('order_id', widget.order.id);

      final List<Map<String, dynamic>> insertData = [];
      for (final item in _items) {
        final name = item['nameController']!.text.trim();
        final price = double.parse(item['priceController']!.text);
        final qty = int.parse(item['quantityController']!.text);
        final totalPrice = price * qty;

        insertData.add({
          'order_id': widget.order.id,
          'product_id': null,
          'product_name': name,
          'product_price': price,
          'quantity': qty,
          'total_price': totalPrice,
          'order_number': widget.order.orderNumber,
        });
      }

      await _supabase.from('order_items').insert(insertData);

      await _supabase.from('orders').update({
        'total_amount': totalAmount,
        'status': OrderStatus.confirmed.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسعير وتأكيد الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('Failed to price prescription order', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسعير: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final total = subtotal + widget.order.deliveryFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تسعير وتحديد منتجات الروشتة ✏️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                if (_items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _removeRow(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: item['nameController'],
                              decoration: const InputDecoration(
                                labelText: 'اسم الدواء / المنتج',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال اسم الدواء';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: item['priceController'],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'سعر الوحدة (ج.م)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'مطلوب';
                                      }
                                      final price = double.tryParse(value);
                                      if (price == null || price <= 0) {
                                        return 'غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: item['quantityController'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'الكمية',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'مطلوب';
                                      }
                                      final qty = int.tryParse(value);
                                      if (qty == null || qty <= 0) {
                                        return 'غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة دواء آخر'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي المنتجات:', style: TextStyle(color: Colors.grey)),
                      Text('${subtotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('رسوم التوصيل:', style: TextStyle(color: Colors.grey)),
                      Text('${widget.order.deliveryFee.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الكلي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'تأكيد وحفظ التسعيرة',
                    isLoading: _isSaving,
                    onPressed: _savePrice,
                    backgroundColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
