import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/widgets/order_card.dart';
import 'package:shimmer/shimmer.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  OrderStatus _selectedFilter = OrderStatus.pending;
  bool _isInitialized = false; // لمنع التحديث المستمر

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
      _loadMerchantOrders();
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
    final merchantProvider = Provider.of<MerchantProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(merchantProvider.selectedMerchant?.storeName ?? 'الطلبات'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMerchantOrders(forceRefresh: true),
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(child: _buildOrdersList(orderProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: OrderStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(status.displayName),
                selected: _selectedFilter == status,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = status;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return _buildShimmerList();
    }

    if (provider.error != null && provider.error!.isNotEmpty) {
      return _buildErrorState(provider.error!);
    }

    final filteredOrders = provider.orders.where((order) {
      final status = OrderStatusExtension.fromDbValue(order.status.value);
      return status == _selectedFilter;
    }).toList();

    if (filteredOrders.isEmpty) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
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
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
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
      builder: (context) {
        final orderStatus = OrderStatusExtension.fromDbValue(
          order.status.value,
        );
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إجراءات الطلب #${order.id.substring(0, 8)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              if (orderStatus == OrderStatus.pending) ...[
                _buildActionButton(
                  'قبول الطلب',
                  Icons.check,
                  Colors.green,
                  () => _updateOrderStatus(order, OrderStatus.confirmed),
                ),
                _buildActionButton(
                  'رفض الطلب',
                  Icons.close,
                  Colors.red,
                  () => _updateOrderStatus(order, OrderStatus.cancelled),
                ),
              ],
              if (orderStatus == OrderStatus.confirmed)
                _buildActionButton(
                  'قيد التحضير',
                  Icons.inventory,
                  Colors.blue,
                  () => _updateOrderStatus(order, OrderStatus.preparing),
                ),
              if (orderStatus == OrderStatus.preparing)
                _buildActionButton(
                  'تم التجهيز',
                  Icons.local_shipping,
                  Colors.purple,
                  () => _updateOrderStatus(order, OrderStatus.ready),
                ),
              if (orderStatus == OrderStatus.ready)
                _buildActionButton(
                  'إرسال مع الكابتن',
                  Icons.delivery_dining,
                  Colors.orange,
                  () => _updateOrderStatus(order, OrderStatus.inTransit),
                ),
              if (orderStatus == OrderStatus.inTransit)
                _buildActionButton(
                  'تم التسليم للعميل',
                  Icons.check_circle,
                  Colors.green,
                  () => _updateOrderStatus(order, OrderStatus.delivered),
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      onTap: onPressed,
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
}
