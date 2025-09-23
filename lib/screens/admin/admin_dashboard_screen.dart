import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
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
  _AdminDashboardState createState() => _AdminDashboardState();
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
    final authProvider = Provider.of<FirebaseAuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 30),
            const SizedBox(width: 10),
            const Text('لوحة تحكم المسؤول'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(authProvider.user?.name ?? 'المسؤول'),
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('تسجيل الخروج'),
                  onTap: () {
                    authProvider.logout();
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
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
class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الإحصائيا��
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
    return orders.fold(0.0, (sum, order) => sum + (order.totalPrice ?? 0));
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
                backgroundImage: user.imageUrl != null
                    ? NetworkImage(user.imageUrl!)
                    : null,
                child: user.imageUrl == null ? Text(user.name[0]) : null,
              ),
              title: Text(user.name),
              subtitle: Text(user.email),
              trailing: Text(_getUserTypeText(user.type)),
            ),
          )
          .toList(),
    );
  }

  String _getUserTypeText(dynamic type) {
    if (type.toString().contains('customer')) return 'عميل';
    if (type.toString().contains('merchant')) return 'تاجر';
    if (type.toString().contains('captain')) return 'كابتن';
    if (type.toString().contains('admin')) return 'مسؤول';
    return 'عميل';
  }
}

// ==================== Admin Dashboard Screen ====================
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<FirebaseAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المشرف'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildDashboardCard(
            context,
            title: 'المستخدمين',
            icon: Icons.people,
            onTap: () => Navigator.pushNamed(context, '/admin/users'),
          ),
          _buildDashboardCard(
            context,
            title: 'المتاجر',
            icon: Icons.store,
            onTap: () => Navigator.pushNamed(context, '/admin/stores'),
          ),
          _buildDashboardCard(
            context,
            title: 'الطلبات',
            icon: Icons.shopping_cart,
            onTap: () => Navigator.pushNamed(context, '/admin/orders'),
          ),
          _buildDashboardCard(
            context,
            title: 'التقارير',
            icon: Icons.bar_chart,
            onTap: () => Navigator.pushNamed(context, '/admin/reports'),
          ),
          _buildDashboardCard(
            context,
            title: 'الإعدادات',
            icon: Icons.settings,
            onTap: () => Navigator.pushNamed(context, '/admin/settings'),
          ),
          _buildDashboardCard(
            context,
            title: 'المندوبين',
            icon: Icons.delivery_dining,
            onTap: () => Navigator.pushNamed(context, '/admin/drivers'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
