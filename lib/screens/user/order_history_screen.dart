import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/order_card.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/user/order_tracking_screen.dart';
import 'package:ell_tall_market/models/order_enums.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    // Use addPostFrameCallback to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // التحقق من تسجيل الدخول ووجود الملف الشخصي
      if (authProvider.isLoggedIn && authProvider.currentProfile != null) {
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );

        try {
          await orderProvider.fetchUserOrders(authProvider.currentProfile!.id);
        } catch (e) {
          // تجاهل الأخطاء الصامتة - ستظهر في الشاشة عبر provider.error
          // هذا أفضل من إظهار SnackBar مزعج
        }
      }
    });
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
            actions: [
              if (authProvider.isLoggedIn)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                  onPressed: _loadOrders,
                ),
              const SizedBox(width: 8),
            ],
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
          body: SafeArea(
            child: authProvider.isLoggedIn
                ? Consumer<OrderProvider>(
                    builder: (context, orderProvider, child) {
                      return RefreshIndicator(
                        onRefresh: _loadOrders,
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
        );
      },
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
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الطلبات...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
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
      );
    }

    // جمع الطلبات النشطة (قيد التوصيل + تم التوصيل)
    final activeOrders = [...provider.currentOrders, ...provider.pastOrders]
        .where((order) {
          final status = OrderStatusExtension.fromDbValue(order.status.value);
          return status != OrderStatus.cancelled;
        })
        .toList();

    if (activeOrders.isEmpty) {
      return Center(
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
      );
    }

    // عرض الطلبات النشطة
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeOrders.length,
      itemBuilder: (context, index) {
        final order = activeOrders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: OrderCard(
            order: order,
            onTap: () => _checkLoginForAction(() {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(orderId: order.id),
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
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الطلبات...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
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
      );
    }

    // جمع الطلبات الملغاة فقط
    final cancelledOrders = [...provider.currentOrders, ...provider.pastOrders]
        .where((order) {
          final status = OrderStatusExtension.fromDbValue(order.status.value);
          return status == OrderStatus.cancelled;
        })
        .toList();

    if (cancelledOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green.withValues(alpha: 0.3),
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
      );
    }

    // عرض الطلبات الملغاة
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cancelledOrders.length,
      itemBuilder: (context, index) {
        final order = cancelledOrders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: OrderCard(
            order: order,
            onTap: () => _checkLoginForAction(() {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(orderId: order.id),
                ),
              );
            }, loginMessage: 'يرجى تسجيل الدخول لعرض تفاصيل الطلب'),
          ),
        );
      },
    );
  }
}
