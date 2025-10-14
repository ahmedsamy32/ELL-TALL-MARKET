import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/order_card.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ فشل تحميل الطلبات: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                  onPressed: _loadOrders,
                ),
            ],
          ),
          body: authProvider.isLoggedIn
              ? Consumer<OrderProvider>(
                  builder: (context, orderProvider, child) {
                    return RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: _buildOrderList(orderProvider, colorScheme),
                    );
                  },
                )
              : _buildLoginPrompt(colorScheme),
        );
      },
    );
  }

  Widget _buildLoginPrompt(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 100,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'سجل دخولك لعرض طلباتك',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'يمكنك عرض تاريخ طلباتك وتتبع حالة الطلبات الحالية',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              icon: const Icon(Icons.login),
              label: const Text('تسجيل الدخول'),
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

  Widget _buildOrderList(OrderProvider provider, ColorScheme colorScheme) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الطلبات...'),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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

    // Show all orders (both current and past)
    final allOrders = [...provider.currentOrders, ...provider.pastOrders];

    if (allOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 100,
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'لا توجد طلبات',
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
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allOrders.length,
      itemBuilder: (context, index) {
        final order = allOrders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: OrderCard(
            order: order,
            onTap: () => _checkLoginForAction(() {
              // Navigate to order details - this requires login
              // Navigator.pushNamed(context, AppRoutes.orderDetails, arguments: order);
            }, loginMessage: 'يرجى تسجيل الدخول لعرض تفاصيل الطلب'),
          ),
        );
      },
    );
  }
}
