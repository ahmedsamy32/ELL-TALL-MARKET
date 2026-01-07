import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/user_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

// الصفحات
import 'app_settings_screen.dart';
import 'manage_users_screen.dart';
import 'manage_products_screen.dart';
import 'manage_orders_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_coupons_screen.dart';
import 'manage_captains_screen.dart';
import 'analytics_screen.dart';
import 'dynamic_ui_builder_screen.dart';
import 'manage_banners_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const DashboardHome(),
    const ManageUsersScreen(),
    const ManageProductsScreen(),
    const ManageOrdersScreen(),
    const ManageCategoriesScreen(),
    const ManageCouponsScreen(),
    const ManageCaptainsScreen(),
    const AnalyticsScreen(),
    const AppSettingsScreen(),
    const DynamicUIBuilderScreen(),
    const ManageBannersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SupabaseProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            const SizedBox(width: 10),
            const Text('لوحة تحكم المسؤول'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ميزة الإشعارات قريباً')),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    authProvider.currentUserProfile?.fullName ?? 'المسؤول',
                  ),
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('تسجيل الخروج'),
                  onTap: () async {
                    // Get all providers to clear their data on sign out
                    final merchantProvider = Provider.of<MerchantProvider>(
                      context,
                      listen: false,
                    );
                    final productProvider = Provider.of<ProductProvider>(
                      context,
                      listen: false,
                    );
                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );

                    await authProvider.signOut(
                      merchantProvider: merchantProvider,
                      productProvider: productProvider,
                      orderProvider: orderProvider,
                    );
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة التحكم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'مرحباً بك في لوحة إدارة التطبيق',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard, 'لوحة التحكم', 0),
          _buildDrawerItem(Icons.people, 'إدارة المستخدمين', 1),
          _buildDrawerItem(Icons.shopping_bag, 'إدارة المنتجات', 2),
          _buildDrawerItem(Icons.shopping_cart, 'إدارة الطلبات', 3),
          _buildDrawerItem(Icons.category, 'إدارة الفئات', 4),
          _buildDrawerItem(Icons.local_offer, 'إدارة الكوبونات', 5),
          _buildDrawerItem(Icons.delivery_dining, 'إدارة الكباتن', 6),
          _buildDrawerItem(Icons.analytics, 'الإحصائيات', 7),
          _buildDrawerItem(Icons.settings, 'إعدادات التطبيق', 8),
          _buildDrawerItem(Icons.design_services, 'منشئ الواجهات', 9),
          _buildDrawerItem(Icons.image, 'إدارة البانرات', 10),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _selectedIndex == index,
      selectedTileColor: Colors.grey[200],
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'لوحة التحكم',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'المستخدمين'),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag),
          label: 'المنتجات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'الطلبات',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.category), label: 'الفئات'),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_offer),
          label: 'الكوبونات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.delivery_dining),
          label: 'الكباتن',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'الإحصائيات',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        BottomNavigationBarItem(
          icon: Icon(Icons.design_services),
          label: 'الواجهات',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.image), label: 'البانرات'),
      ],
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
    );
  }
}

// ==================== Dashboard Home ====================
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  @override
  void initState() {
    super.initState();
    // تحميل البيانات عند بدء الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      userProvider.fetchUsers();
      productProvider.fetchProducts();
      orderProvider.fetchAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    // عرض مؤشر التحميل إذا كانت البيانات تُحمل
    if (userProvider.isLoading ||
        productProvider.isLoading ||
        orderProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الإحصائيات
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              children: [
                _buildStatCard(
                  '👥 المستخدمين',
                  userProvider.users.length.toString(),
                  Colors.blue,
                ),
                _buildStatCard(
                  '🛍️ المنتجات',
                  productProvider.products.length.toString(),
                  Colors.green,
                ),
                _buildStatCard(
                  '📦 الطلبات',
                  orderProvider.orders.length.toString(),
                  Colors.orange,
                ),
                _buildStatCard(
                  '💰 الإيرادات',
                  '${_calculateTotalRevenue(orderProvider.orders)} ر.س',
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // الرسومات البيانية (Placeholder)
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الطلبات اليومية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 200,
                            color: Colors.grey[100],
                            child: const Center(
                              child: Text('Line Chart - الطلبات اليومية'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'توزيع المستخدمين',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 200,
                            color: Colors.grey[100],
                            child: const Center(
                              child: Text('Pie Chart - توزيع المستخدمين'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // النشاط الحديث
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'آخر الطلبات',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildRecentOrdersTable(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'آخر المستخدمين',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildRecentUsersTable(userProvider.users),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalRevenue(List<dynamic> orders) {
    return orders.fold(0.0, (sum, order) => sum + (order.totalAmount ?? 0));
  }

  Widget _buildRecentOrdersTable() {
    return const Column(
      children: [
        ListTile(
          title: Text('طلب #1001'),
          subtitle: Text('عميل: أحمد - الحالة: قيد التوصيل'),
          trailing: Text('120 ر.س'),
        ),
        ListTile(
          title: Text('طلب #1002'),
          subtitle: Text('عميل: محمد - الحالة: مكتمل'),
          trailing: Text('85 ر.س'),
        ),
        ListTile(
          title: Text('طلب #1003'),
          subtitle: Text('عميل: فاطمة - الحالة: معلق'),
          trailing: Text('200 ر.س'),
        ),
      ],
    );
  }

  Widget _buildRecentUsersTable(List<dynamic> users) {
    final recentUsers = users.take(3).toList();

    return Column(
      children: recentUsers
          .map(
            (user) => ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.fullName?.isNotEmpty == true
                            ? user.fullName![0]
                            : 'U',
                      )
                    : null,
              ),
              title: Text(user.fullName ?? 'بدون اسم'),
              subtitle: Text(user.email ?? 'بدون بريد'),
              trailing: Text(_getUserTypeText(user.role)),
            ),
          )
          .toList(),
    );
  }

  String _getUserTypeText(dynamic role) {
    if (role == null) return 'عميل';
    final roleStr = role.toString().toLowerCase();
    if (roleStr.contains('client')) return 'عميل';
    if (roleStr.contains('merchant')) return 'تاجر';
    if (roleStr.contains('captain')) return 'كابتن';
    if (roleStr.contains('admin')) return 'مسؤول';
    return 'عميل';
  }
}

// ==================== Admin Dashboard Screen ====================
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'لوحة تحكم المشرف',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              },
              tooltip: 'العودة للرئيسية',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLowest,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: GridView.count(
            padding: const EdgeInsets.all(20),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildDashboardCard(
                context,
                title: 'المستخدمين',
                icon: Icons.people,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageUsers),
              ),
              _buildDashboardCard(
                context,
                title: 'المنتجات',
                icon: Icons.shopping_bag,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageProducts),
              ),
              _buildDashboardCard(
                context,
                title: 'الطلبات',
                icon: Icons.shopping_cart,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageOrders),
              ),
              _buildDashboardCard(
                context,
                title: 'الفئات',
                icon: Icons.category,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageCategories),
              ),
              _buildDashboardCard(
                context,
                title: 'الكوبونات',
                icon: Icons.local_offer,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageCoupons),
              ),
              _buildDashboardCard(
                context,
                title: 'الكباتن',
                icon: Icons.delivery_dining,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageCaptains),
              ),
              _buildDashboardCard(
                context,
                title: 'الإحصائيات',
                icon: Icons.analytics,
                onTap: () => Navigator.pushNamed(context, AppRoutes.analytics),
              ),
              _buildDashboardCard(
                context,
                title: 'الإعدادات',
                icon: Icons.settings,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.appSettings),
              ),
              _buildDashboardCard(
                context,
                title: 'منشئ الواجهات',
                icon: Icons.design_services,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.dynamicUIBuilder),
              ),
              _buildDashboardCard(
                context,
                title: 'إدارة البانرات',
                icon: Icons.image,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.manageBanners),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
