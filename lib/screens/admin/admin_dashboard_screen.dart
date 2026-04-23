import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/user_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

// الصفحات
import 'app_settings_screen.dart';
import 'manage_users_screen.dart';
import 'manage_products_screen.dart';
import 'manage_orders_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_coupons_screen.dart';
import 'captain_reports_screen.dart';
import '../captain/delivery_company_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'dynamic_ui_builder_screen.dart';
import 'manage_banners_screen.dart';

/// Admin Dashboard with responsive design for mobile, tablet, and web
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const DashboardHome(),
    const ManageUsersScreen(),
    const ManageProductsScreen(),
    const ManageOrdersScreen(),
    const ManageCategoriesScreen(),
    const ManageCouponsScreen(),
    const CaptainReportsScreen(),
    const DeliveryCompanyDashboardScreen(),
    const AnalyticsScreen(),
    const AppSettingsScreen(),
    const DynamicUIBuilderScreen(),
    const ManageBannersScreen(),
  ];

  static const List<(IconData, String)> _navItems = [
    (Icons.dashboard_rounded, 'لوحة التحكم'),
    (Icons.people_rounded, 'المستخدمين'),
    (Icons.shopping_bag_rounded, 'المنتجات'),
    (Icons.shopping_cart_rounded, 'الطلبات'),
    (Icons.category_rounded, 'الفئات'),
    (Icons.local_offer_rounded, 'الكوبونات'),
    (Icons.assessment_rounded, 'تقارير الكباتن'),
    (Icons.local_shipping_rounded, 'شركة التوصيل'),
    (Icons.analytics_rounded, 'الإحصائيات'),
    (Icons.settings_rounded, 'الإعدادات'),
    (Icons.design_services_rounded, 'منشئ الواجهات'),
    (Icons.image_rounded, 'البانرات'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      if (authProvider.currentUser?.id != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).loadUserNotifications(
          authProvider.currentUser!.id,
          targetRole: 'admin',
        );
        NotificationServiceEnhanced.instance.saveDeviceTokenForRole('admin');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SupabaseProvider>(context);
    final screenSize = MediaQuery.sizeOf(context);
    final isWide = screenSize.width >= 1200;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(authProvider, context, isWide),
      drawer: !isWide ? _buildMobileDrawer(context, authProvider) : null,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout()
            : (isTablet ? _buildTabletLayout() : _buildMobileLayout()),
      ),
      bottomNavigationBar: !isWide ? _buildBottomNavigationBar() : null,
    );
  }

  // ======================== AppBar ========================
  PreferredSizeWidget _buildAppBar(
    SupabaseProvider authProvider,
    BuildContext context,
    bool isWide,
  ) {
    return AppBar(
      elevation: 1,
      automaticallyImplyLeading: !isWide,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      actions: [
        _buildNotificationButton(context),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'بحث',
          onPressed: () => _showSearchSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.home_rounded),
          tooltip: 'الصفحة الرئيسية',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.home),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.getUnreadCountForRole('admin');
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded),
              onPressed: () => _showNotificationsBottomSheet(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Consumer<NotificationProvider>(
                        builder: (context, provider, _) {
                          if (provider.getUnreadCountForRole('admin') > 0) {
                            return TextButton.icon(
                              onPressed: () {
                                final uid = Provider.of<SupabaseProvider>(
                                  context,
                                  listen: false,
                                ).currentUser?.id;
                                if (uid != null) {
                                  provider.markAllAsRead(uid);
                                }
                              },
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('قراءة الكل'),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _NotificationsBottomSheetContent(
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final query = controller.text.trim().toLowerCase();
          final filteredOrders = query.isEmpty
              ? <dynamic>[]
              : orderProvider.orders
                    .where(
                      (o) =>
                          (o.orderNumber?.toLowerCase().contains(query) ??
                              false) ||
                          (o.clientName?.toLowerCase().contains(query) ??
                              false),
                    )
                    .take(5)
                    .toList();
          final filteredUsers = query.isEmpty
              ? <dynamic>[]
              : userProvider.users
                    .where(
                      (u) => u.fullName?.toLowerCase().contains(query) ?? false,
                    )
                    .take(5)
                    .toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'ابحث في الطلبات والمستخدمين...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setSt(() {}),
                    ),
                  ),
                ),
                Expanded(
                  child: query.isEmpty
                      ? Center(
                          child: Text(
                            'اكتب للبحث...',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : Directionality(
                          textDirection: TextDirection.rtl,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (filteredOrders.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'الطلبات',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                ...filteredOrders.map(
                                  (o) => ListTile(
                                    leading: const Icon(
                                      Icons.shopping_cart_rounded,
                                      color: AppColors.accent,
                                    ),
                                    title: Text(
                                      'طلب #${(o.orderNumber ?? o.id?.substring(0, 8) ?? '').toUpperCase()}',
                                    ),
                                    subtitle: Text(o.clientName ?? ''),
                                    trailing: Text(
                                      '${o.totalAmount?.toStringAsFixed(2)} ر.ي',
                                    ),
                                  ),
                                ),
                              ],
                              if (filteredUsers.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: const Text(
                                    'المستخدمين',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                ...filteredUsers.map(
                                  (u) => ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        (u.fullName?.isNotEmpty ?? false)
                                            ? u.fullName![0]
                                            : '؟',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    title: Text(u.fullName ?? 'بدون اسم'),
                                    subtitle: Text(u.role.value),
                                  ),
                                ),
                              ],
                              if (filteredOrders.isEmpty &&
                                  filteredUsers.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      'لا توجد نتائج',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => controller.dispose());
  }

  // ======================== Layouts ========================
  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: _pages[_selectedIndex],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: _pages[_selectedIndex],
      ),
    );
  }

  // ======================== Sidebar (Wide) ========================
  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'لوحة التحكم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'الإدارة',
                          style: TextStyle(fontSize: 12, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) => _buildSidebarItem(
                    icon: _navItems[index].$1,
                    label: _navItems[index].$2,
                    index: index,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.grey,
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : null,
              fontSize: 14,
            ),
          ),
          selected: isSelected,
          selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          onTap: () => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }

  // ======================== Mobile Drawer ========================
  Widget _buildMobileDrawer(
    BuildContext context,
    SupabaseProvider authProvider,
  ) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'لوحة التحكم',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          authProvider.currentUserProfile?.fullName ??
                              'المسؤول',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: ListTile(
                        leading: Icon(
                          _navItems[index].$1,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.grey,
                        ),
                        title: Text(
                          _navItems[index].$2,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? AppColors.primary : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== Bottom Navigation Bar ========================
  Widget _buildBottomNavigationBar() {
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 600;

    // Mobile: 4 main items + "المزيد" opens drawer
    if (isMobile) {
      final firstFour = _navItems.take(4).toList();
      final displayIndex = _selectedIndex < 4 ? _selectedIndex : 4;
      return Theme(
        data: Theme.of(
          context,
        ).copyWith(splashColor: AppColors.primary.withValues(alpha: 0.1)),
        child: BottomNavigationBar(
          items: [
            ...firstFour.map(
              (item) =>
                  BottomNavigationBarItem(icon: Icon(item.$1), label: item.$2),
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded),
              label: 'المزيد',
            ),
          ],
          currentIndex: displayIndex,
          onTap: (i) {
            if (i == 4) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => _selectedIndex = i);
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          showUnselectedLabels: true,
          selectedFontSize: 11,
          unselectedFontSize: 10,
        ),
      );
    }

    // Tablet: show all items
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(splashColor: AppColors.primary.withValues(alpha: 0.1)),
      child: BottomNavigationBar(
        items: _navItems
            .map(
              (item) =>
                  BottomNavigationBarItem(icon: Icon(item.$1), label: item.$2),
            )
            .toList(),
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 10,
      ),
    );
  }
}

// ======================== Dashboard Home ========================
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _selectedPeriod = 'all';

  List<dynamic> _filterByPeriod(List<dynamic> items) {
    if (_selectedPeriod == 'all') return items;
    final now = DateTime.now();
    late DateTime start;
    switch (_selectedPeriod) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      default: // year
        start = DateTime(now.year, 1, 1);
    }
    return items.where((item) {
      try {
        return (item.createdAt as DateTime).isAfter(start);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  double _computeTrend(List<dynamic> current, List<dynamic> all) {
    if (_selectedPeriod == 'all' || all.isEmpty) return 0;
    final now = DateTime.now();
    late DateTime prevStart, prevEnd;
    switch (_selectedPeriod) {
      case 'today':
        prevEnd = DateTime(now.year, now.month, now.day);
        prevStart = prevEnd.subtract(const Duration(days: 1));
        break;
      case 'week':
        prevEnd = now.subtract(const Duration(days: 7));
        prevStart = prevEnd.subtract(const Duration(days: 7));
        break;
      case 'month':
        prevEnd = DateTime(now.year, now.month, 1);
        prevStart = DateTime(now.year, now.month - 1, 1);
        break;
      default: // year
        prevEnd = DateTime(now.year, 1, 1);
        prevStart = DateTime(now.year - 1, 1, 1);
    }
    final prevCount = all.where((item) {
      try {
        final d = item.createdAt as DateTime;
        return d.isAfter(prevStart) && d.isBefore(prevEnd);
      } catch (_) {
        return false;
      }
    }).length;
    if (prevCount == 0) return current.isNotEmpty ? 100.0 : 0.0;
    return ((current.length - prevCount) / prevCount * 100);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchUsers();
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      Provider.of<OrderProvider>(context, listen: false).fetchAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;

    if (userProvider.isLoading ||
        productProvider.isLoading ||
        orderProvider.isLoading) {
      return AppShimmer.centeredLines(context);
    }

    final filteredOrders = _filterByPeriod(orderProvider.orders);
    final filteredUsers = _filterByPeriod(userProvider.users);

    final totalRevenue = filteredOrders.fold<double>(
      0,
      (sum, o) => sum + (o.totalAmount ?? 0.0),
    );
    final totalUsers = filteredUsers.length;
    final totalProducts = productProvider.products.length;
    final totalOrders = filteredOrders.length;

    final ordersTrend = _computeTrend(filteredOrders, orderProvider.orders);
    final usersTrend = _computeTrend(filteredUsers, userProvider.users);
    double prevRevenue = 0.0;
    if (_selectedPeriod != 'all') {
      final now2 = DateTime.now();
      late DateTime prevStart, prevEnd;
      switch (_selectedPeriod) {
        case 'today':
          prevEnd = DateTime(now2.year, now2.month, now2.day);
          prevStart = prevEnd.subtract(const Duration(days: 1));
          break;
        case 'week':
          prevEnd = now2.subtract(const Duration(days: 7));
          prevStart = prevEnd.subtract(const Duration(days: 7));
          break;
        case 'month':
          prevEnd = DateTime(now2.year, now2.month, 1);
          prevStart = DateTime(now2.year, now2.month - 1, 1);
          break;
        default:
          prevEnd = DateTime(now2.year, 1, 1);
          prevStart = DateTime(now2.year - 1, 1, 1);
      }
      prevRevenue = orderProvider.orders
          .where((o) {
            try {
              final d = o.createdAt;
              return d.isAfter(prevStart) && d.isBefore(prevEnd);
            } catch (_) {
              return false;
            }
          })
          .fold<double>(0, (s, o) => s + o.totalAmount);
    }
    final revenueTrend = prevRevenue == 0
        ? (totalRevenue > 0 ? 100.0 : 0.0)
        : ((totalRevenue - prevRevenue) / prevRevenue * 100);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ──────────────────────────────────
            // Period Filter Chips
            // ──────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in const [
                    ('all', 'الكل'),
                    ('today', 'اليوم'),
                    ('week', 'الأسبوع'),
                    ('month', 'الشهر'),
                    ('year', 'السنة'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(p.$2),
                        selected: _selectedPeriod == p.$1,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedPeriod == p.$1 ? Colors.white : null,
                          fontWeight: _selectedPeriod == p.$1
                              ? FontWeight.w600
                              : null,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedPeriod = p.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ──────────────────────────────────
            // Stats Grid - Responsive
            // ──────────────────────────────────
            GridView.count(
              crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: [
                _buildStatCard(
                  title: 'المستخدمين',
                  value: '$totalUsers',
                  icon: Icons.people_rounded,
                  color: AppColors.info,
                  trend: _selectedPeriod != 'all' ? usersTrend : null,
                ),
                _buildStatCard(
                  title: 'المنتجات',
                  value: '$totalProducts',
                  icon: Icons.shopping_bag_rounded,
                  color: AppColors.secondary,
                ),
                _buildStatCard(
                  title: 'الطلبات',
                  value: '$totalOrders',
                  icon: Icons.shopping_cart_rounded,
                  color: AppColors.accent,
                  trend: _selectedPeriod != 'all' ? ordersTrend : null,
                ),
                _buildStatCard(
                  title: 'الإيرادات',
                  value: '${totalRevenue.toStringAsFixed(0)} ر.ي',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.primary,
                  trend: _selectedPeriod != 'all' ? revenueTrend : null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ──────────────────────────────────
            // Charts Row
            // ──────────────────────────────────
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildChartCard(
                      title: 'حالة الطلبات',
                      icon: Icons.bar_chart_rounded,
                      child: _OrdersStatusChart(orders: filteredOrders),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChartCard(
                      title: 'توزيع المستخدمين',
                      icon: Icons.pie_chart_rounded,
                      child: _UsersBreakdownChart(users: filteredUsers),
                    ),
                  ),
                ],
              )
            else ...[
              _buildChartCard(
                title: 'حالة الطلبات',
                icon: Icons.bar_chart_rounded,
                child: _OrdersStatusChart(orders: filteredOrders),
              ),
              const SizedBox(height: 12),
              _buildChartCard(
                title: 'توزيع المستخدمين',
                icon: Icons.pie_chart_rounded,
                child: _UsersBreakdownChart(users: filteredUsers),
              ),
            ],

            const SizedBox(height: 20),

            // ──────────────────────────────────
            // Recent Activity
            // ──────────────────────────────────
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRecentCard(
                      title: 'آخر الطلبات',
                      icon: Icons.history_rounded,
                      items: orderProvider.orders.take(5).toList(),
                      itemBuilder: (item) => ListTile(
                        dense: true,
                        title: Text(
                          'طلب #${item.id?.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'المبلغ: ${item.totalAmount?.toStringAsFixed(2)} ر.ي',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              item.status,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(item.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(item.status),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRecentCard(
                      title: 'آخر المستخدمين',
                      icon: Icons.people_rounded,
                      items: userProvider.users.take(5).toList(),
                      itemBuilder: (item) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            (item.fullName?.isNotEmpty ?? false)
                                ? item.fullName!.substring(0, 1)
                                : '؟',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(
                          item.fullName ?? 'بدون اسم',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          item.role.value,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildRecentCard(
                    title: 'آخر الطلبات',
                    icon: Icons.history_rounded,
                    items: orderProvider.orders.take(5).toList(),
                    itemBuilder: (item) => ListTile(
                      dense: true,
                      title: Text(
                        'طلب #${item.id?.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'المبلغ: ${item.totalAmount?.toStringAsFixed(2)} ر.ي',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            item.status,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusText(item.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(item.status),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentCard(
                    title: 'آخر المستخدمين',
                    icon: Icons.people_rounded,
                    items: userProvider.users.take(5).toList(),
                    itemBuilder: (item) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          (item.fullName?.isNotEmpty ?? false)
                              ? item.fullName!.substring(0, 1)
                              : '؟',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(
                        item.fullName ?? 'بدون اسم',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        item.role.value,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? trend,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.05),
              color.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (trend >= 0 ? AppColors.accent : AppColors.danger)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 12,
                          color: trend >= 0
                              ? AppColors.accent
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${trend.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: trend >= 0
                                ? AppColors.accent
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (items.isEmpty)
              Center(
                child: Text(
                  'لا توجد بيانات',
                  style: TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              )
            else
              ...items.map((item) => itemBuilder(item)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status?.toString().toLowerCase() ?? '';
    if (statusStr.contains('pending')) return AppColors.warning;
    if (statusStr.contains('processing')) return AppColors.info;
    if (statusStr.contains('delivered')) return AppColors.accent;
    if (statusStr.contains('cancelled')) return AppColors.danger;
    return AppColors.grey;
  }

  String _getStatusText(dynamic status) {
    final statusStr = status?.toString().toLowerCase() ?? '';
    if (statusStr.contains('pending')) return 'معلق';
    if (statusStr.contains('processing')) return 'جاري';
    if (statusStr.contains('delivered')) return 'مكتمل';
    if (statusStr.contains('cancelled')) return 'ملغي';
    return 'غير معروف';
  }
}

// ======================== Charts ========================
class _OrdersStatusChart extends StatelessWidget {
  const _OrdersStatusChart({required this.orders});
  final List<dynamic> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.grey)),
      );
    }

    final counts = <String, int>{};
    for (final o in orders) {
      final s = (o.status?.toString() ?? 'unknown').replaceAll(
        'OrderStatus.',
        '',
      );
      counts[s] = (counts[s] ?? 0) + 1;
    }

    final entries = counts.entries.toList();
    final maxVal = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: (maxVal + 1).toDouble(),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _statusAr(entries[i].key),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: _statusColor(e.key),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _statusAr(String status) {
    final s = status.toLowerCase();
    if (s.contains('pending')) return 'معلق';
    if (s.contains('processing')) return 'جاري';
    if (s.contains('delivered')) return 'مكتمل';
    if (s.contains('cancelled')) return 'ملغي';
    return status.length > 5 ? '…' : status;
  }

  Color _statusColor(String status) {
    if (status.toLowerCase().contains('pending')) return AppColors.warning;
    if (status.toLowerCase().contains('processing')) return AppColors.info;
    if (status.toLowerCase().contains('delivered')) return AppColors.accent;
    if (status.toLowerCase().contains('cancelled')) return AppColors.danger;
    return AppColors.grey;
  }
}

class _UsersBreakdownChart extends StatelessWidget {
  const _UsersBreakdownChart({required this.users});
  final List<dynamic> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.grey)),
      );
    }

    final counts = <String, int>{'عميل': 0, 'تاجر': 0, 'كابتن': 0, 'مسؤول': 0};
    for (final u in users) {
      final r = (u.role?.toString() ?? '').toLowerCase();
      if (r.contains('merchant')) {
        counts['تاجر'] = counts['تاجر']! + 1;
      } else if (r.contains('captain')) {
        counts['كابتن'] = counts['كابتن']! + 1;
      } else if (r.contains('admin')) {
        counts['مسؤول'] = counts['مسؤول']! + 1;
      } else {
        counts['عميل'] = counts['عميل']! + 1;
      }
    }

    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
    ];
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList();

    final sections = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final pct = total > 0 ? (e.value / total * 100) : 0.0;
      return PieChartSectionData(
        value: e.value > 0 ? e.value.toDouble() : 0.001,
        color: colors[i],
        title: e.value > 0 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key} (${e.value})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ======================== Notifications Bottom Sheet ========================
class _NotificationsBottomSheetContent extends StatelessWidget {
  final ScrollController scrollController;

  const _NotificationsBottomSheetContent({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<SupabaseProvider>(context);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return _buildLoginRequired();
    }

    if (notificationProvider.isLoading) {
      return AppShimmer.list(context);
    }

    final notifications = notificationProvider.getNotificationsForRole('admin');

    if (notificationProvider.error != null) {
      return _buildError(notificationProvider, userId);
    }

    if (notifications.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(
          context,
          notification,
          notificationProvider,
        );
      },
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'يرجى تسجيل الدخول',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('لعرض الإشعارات', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildError(NotificationProvider provider, String userId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'حاول مرة أخرى',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                provider.loadUserNotifications(userId, targetRole: 'admin');
              },
              child: const Text('إعادة محاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الإشعارات هنا عند وجودها',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        provider.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف الإشعار'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: notification.isRead
            ? Colors.white
            : AppColors.primary.withValues(alpha: 0.05),
        elevation: notification.isRead ? 1 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: _getNotificationIcon(
            notification.type ?? NotificationType.system,
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                )
              : null,
          onTap: () {
            provider.markAsRead(notification.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    late IconData icon;
    late Color color;
    switch (type) {
      case NotificationType.order:
        icon = Icons.shopping_cart_rounded;
        color = AppColors.primary;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer_rounded;
        color = AppColors.secondary;
        break;
      case NotificationType.system:
        icon = Icons.info_rounded;
        color = AppColors.info;
        break;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}
