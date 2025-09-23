import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<FirebaseAuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'لوحة تحكم المتجر'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardHome(),
          _buildProductsPage(),
          _buildOrdersPage(),
          _buildAnalyticsPage(),
          _buildSettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'المنتجات'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'التقارير'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = Provider.of<FirebaseAuthProvider>(context).user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.name ?? 'المتجر'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.storeLogoUrl != null
                ? NetworkImage(user!.storeLogoUrl!)
                : null,
              child: user?.storeLogoUrl == null
                ? const Icon(Icons.store)
                : null,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),
          _buildDrawerItem(0, 'الرئيسية', Icons.dashboard),
          _buildDrawerItem(1, 'المنتجات', Icons.inventory),
          _buildDrawerItem(2, 'الطلبات', Icons.shopping_cart),
          _buildDrawerItem(3, 'التقارير', Icons.bar_chart),
          _buildDrawerItem(4, 'الإعدادات', Icons.settings),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('المساعدة'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    return ListTile(
      selected: _selectedIndex == index,
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildDashboardHome() {
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('المنتجات', '${productProvider.products.length}', Colors.blue),
              _buildStatCard('الطلبات', '${orderProvider.orders.length}', Colors.green),
              _buildStatCard('المبيعات', '${_calculateTotalSales()} ر.س', Colors.orange),
              _buildStatCard('التقييم', '4.5', Colors.purple),
              _buildStatCard('المحفظة', 'إدارة المعاملات المالية', Colors.green),
            ],
          ),
          const SizedBox(height: 24),
          const Text('الطلبات الأخيرة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 16),
          _buildRecentOrders(),
          const SizedBox(height: 24),
          const Text('إجراءات سريعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 16),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildProductsPage() {
    return const Center(child: Text('صفحة المنتجات'));
  }

  Widget _buildOrdersPage() {
    return const Center(child: Text('صفحة الطلبات'));
  }

  Widget _buildAnalyticsPage() {
    return const Center(child: Text('صفحة التقارير'));
  }

  Widget _buildSettingsPage() {
    return const Center(child: Text('صفحة الإعدادات'));
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
              child: Text('#${index + 1}'),
            ),
            title: Text('طلب رقم #${1001 + index}'),
            subtitle: Text('${50 + (index * 10)} ر.س'),
            trailing: _buildOrderStatusChip(index),
          );
        },
      ),
    );
  }

  Widget _buildOrderStatusChip(int index) {
    final statuses = ['جديد', 'قيد التحضير', 'جاهز للتسليم', 'تم التسليم', 'ملغي'];
    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.red];

    return Chip(
      label: Text(
        statuses[index % statuses.length],
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: colors[index % colors.length],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton('إضافة منتج', Icons.add_shopping_cart, Colors.green, () {
          Navigator.pushNamed(context, '/merchant/products/add');
        }),
        _buildActionButton('المحفظة', Icons.account_balance_wallet, Colors.blue, () {
          Navigator.pushNamed(context, '/merchant/wallet');
        }),
        _buildActionButton('تحديث المخزون', Icons.update, Colors.orange, () {
          // TODO: Implement update inventory
        }),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: color,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _calculateTotalSales() {
    final orderProvider = Provider.of<OrderProvider>(context);
    return orderProvider.orders.fold<double>(
      0.0,
      (total, order) => total + order.total,
    );
  }
}
