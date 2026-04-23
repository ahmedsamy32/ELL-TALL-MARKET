import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';

import 'captain_orders_screen.dart';
import 'captain_wallet_screen.dart';
import 'order_delivery_screen.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/services/supabase_service.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';
import 'package:ell_tall_market/utils/captain_contact_utils.dart';

class CaptainDashboard extends StatefulWidget {
  const CaptainDashboard({super.key});

  @override
  State<CaptainDashboard> createState() => _CaptainDashboardState();
}

class _CaptainDashboardState extends State<CaptainDashboard>
    with WidgetsBindingObserver {
  bool _isOnline = false;
  bool _isStatusLoading = true;
  bool _isDataLoaded = false;
  bool _hasError = false;
  String? _errorMessage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// إعادة الاتصال عند العودة من الخلفية
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureCaptainSubscription();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoadData();
  }

  /// التأكد من أن اشتراك الكابتن نشط (يُستدعى عند العودة)
  void _ensureCaptainSubscription() {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final captain = authProvider.currentProfile;
    if (captain == null) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.subscribeToCaptainOrders(captain.id);
    orderProvider.fetchCaptainOrders(captain.id);
    _loadCaptainData(captain.id);
  }

  void _checkAndLoadData() {
    if (_isDataLoaded) return;

    final authProvider = Provider.of<SupabaseProvider>(context);
    final captain = authProvider.currentProfile;

    if (captain != null && !_isDataLoaded) {
      _isDataLoaded = true;
      final captainId = captain.id;

      Future.microtask(() async {
        if (!mounted) return;

        try {
          await _loadCaptainData(captainId);

          if (!mounted) return;
          final orderProvider = Provider.of<OrderProvider>(
            context,
            listen: false,
          );
          await orderProvider.fetchCaptainOrders(captainId);
          orderProvider.subscribeToCaptainOrders(captainId);

          // التحقق من وجود خطأ بعد التحميل
          if (orderProvider.error != null && mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = orderProvider.error;
            });
          }

          // تحميل الإشعارات
          if (!mounted) return;
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).loadUserNotifications(captainId, targetRole: 'captain');

          NotificationServiceEnhanced.instance.saveDeviceTokenForRole(
            'captain',
          );
        } catch (e) {
          AppLogger.error('❌ فشل تحميل بيانات الكابتن', e);
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'فشل تحميل البيانات، تحقق من الاتصال';
            });
          }
        }
      });
    }
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final captain = authProvider.currentUserProfile;
    if (captain == null) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // إعادة تعيين الخطأ في provider أولاً
      orderProvider.clearError();

      await Future.wait([
        orderProvider.fetchCaptainOrders(captain.id),
        _loadCaptainData(captain.id),
      ]);

      // التحقق من نجاح التحميل
      if (orderProvider.error != null) {
        throw Exception(orderProvider.error);
      }
    } catch (e) {
      AppLogger.error('❌ فشل تحديث البيانات', e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              orderProvider.error ??
              'فشل تحديث البيانات، تحقق من الاتصال بالإنترنت';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final completedOrdersCount = orderProvider.captainOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final authProvider = Provider.of<SupabaseProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final captain = authProvider.currentUserProfile;
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    final captainBody = ResponsiveCenter(
      maxWidth: 1000,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          // 0: لوحة التحكم الرئيسية
          _buildDashboardTab(orderProvider, authProvider, theme, colorScheme),
          // 1: الطلبات
          captain != null
              ? CaptainOrdersScreen(
                  captainId: captain.id,
                  captainName: captain.fullName ?? '',
                )
              : const SizedBox.shrink(),
          // 2: المحفظة
          const CaptainWalletScreen(),
        ],
      ),
    );

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: _buildAppBar(theme, colorScheme, captain),
        body: isWide
            ? Row(
                children: [
                  _buildCaptainSidebar(colorScheme, orderProvider),
                  const VerticalDivider(width: 1),
                  Expanded(child: captainBody),
                ],
              )
            : captainBody,
        bottomNavigationBar: !isWide
            ? NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                animationDuration: const Duration(milliseconds: 400),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: completedOrdersCount > 0,
                      label: Text(completedOrdersCount.toString()),
                      child: const Icon(Icons.receipt_long_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: completedOrdersCount > 0,
                      label: Text(completedOrdersCount.toString()),
                      child: const Icon(Icons.receipt_long_rounded),
                    ),
                    label: 'السجل',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                    label: 'المحفظة',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildCaptainSidebar(
    ColorScheme colorScheme,
    OrderProvider orderProvider,
  ) {
    final items = [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, 'الرئيسية'),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'سجل المكتمل'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        'المحفظة',
      ),
    ];
    return Container(
      width: 240,
      color: colorScheme.surface,
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
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة الكابتن',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'مرحباً بك',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
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
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: ListTile(
                        leading:
                            index == 1 &&
                                orderProvider.captainCurrentOrders.isNotEmpty
                            ? Badge(
                                label: Text(
                                  orderProvider.captainCurrentOrders.length
                                      .toString(),
                                ),
                                child: Icon(
                                  isSelected
                                      ? items[index].$2
                                      : items[index].$1,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  size: 22,
                                ),
                              )
                            : Icon(
                                isSelected ? items[index].$2 : items[index].$1,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                        title: Text(
                          items[index].$3,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? colorScheme.primary : null,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () => setState(() => _selectedIndex = index),
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

  // ===== AppBar =====
  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic captain,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.home_rounded),
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.main,
            (route) => false,
          );
        },
        tooltip: 'الرئيسية',
      ),
      title: Column(
        children: [
          Text(
            'لوحة الكابتن',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isStatusLoading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'جاري التحقق...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? AppColors.success : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'متصل الآن' : 'غير متصل',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _isOnline ? AppColors.success : Colors.grey,
                  ),
                ),
              ],
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        // زر تبديل الحالة مع تأكيد
        if (_isStatusLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Switch(
            value: _isOnline,
            onChanged: (value) => _showToggleStatusDialog(value, captain),
            activeThumbColor: AppColors.success,
          ),
        // زر الإشعارات
        _buildNotificationIcon(),
        const SizedBox(width: 4),
      ],
    );
  }

  // ===== Notification Icon =====
  Widget _buildNotificationIcon() {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.getUnreadCountForRole(
          'captain',
        );
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _showNotificationsSheet(
                context,
                notificationProvider,
                unreadCount,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ===== Dashboard Tab =====
  Widget _buildDashboardTab(
    OrderProvider orderProvider,
    SupabaseProvider authProvider,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // حالة التحميل - Shimmer
    if (orderProvider.isLoading && orderProvider.captainCurrentOrders.isEmpty) {
      return _buildShimmerDashboard();
    }

    // حالة الخطأ
    if (_hasError || orderProvider.error != null) {
      return _buildErrorState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس الترحيب
            _buildWelcomeHeader(authProvider, theme),
            const SizedBox(height: 24),

            _buildModernStats(orderProvider, authProvider),
            const SizedBox(height: 28),

            // عنوان الطلبات النشطة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الطلب الحالي',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('سجل المكتمل'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // قائمة الطلبات
            _buildActiveOrders(orderProvider, theme),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ===== Shimmer Loading =====
  Widget _buildShimmerDashboard() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad + 24),
      children: [
        // Welcome header shimmer
        _shimmerBox(width: double.infinity, height: 80, radius: 20),
        const SizedBox(height: 24),
        // Stats grid shimmer
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: context.responsive(mobile: 2, tablet: 3, wide: 4),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: List.generate(
            4,
            (_) => _shimmerBox(radius: 28, height: 140),
          ),
        ),
        const SizedBox(height: 28),
        // Section title shimmer
        _shimmerBox(width: 140, height: 20, radius: 8),
        const SizedBox(height: 16),
        // Order cards shimmer
        for (int i = 0; i < 2; i++) ...[
          _shimmerBox(radius: 24, height: 200),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return AppShimmer.wrap(
      context,
      child: AppShimmer.box(
        context,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ===== Error State =====
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: AppColors.danger.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'مشكلة في تحميل البيانات',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  _orderProviderError ??
                  'تحقق من اتصالك بالإنترنت وأعد المحاولة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _orderProviderError {
    try {
      return Provider.of<OrderProvider>(context, listen: false).error;
    } catch (_) {
      return null;
    }
  }

  // ===== Welcome Header =====
  Widget _buildWelcomeHeader(SupabaseProvider authProvider, ThemeData theme) {
    final captain = authProvider.currentUserProfile;
    final fullName = captain?.fullName ?? 'كابتن';
    final name = fullName.split(' ').first;
    final greeting = _getGreeting();
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير 🌅';
    if (hour < 17) return 'مساء الخير ☀️';
    if (hour < 21) return 'مساء النور 🌆';
    return 'مساء الخير 🌙';
  }

  // ===== Stats Grid =====
  Widget _buildModernStats(
    OrderProvider orderProvider,
    SupabaseProvider authProvider,
  ) {
    final activeOrders = orderProvider.captainCurrentOrders;
    final completedOrders = orderProvider.pastOrders
        .where((order) => order.status.value == 'delivered')
        .toList();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: context.responsive(mobile: 2, tablet: 3, wide: 4),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildStatCard(
          title: 'الطلبات النشطة',
          value: activeOrders.length.toString(),
          icon: Icons.local_shipping_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        _buildStatCard(
          title: 'المكتملة اليوم',
          value: completedOrders.length.toString(),
          icon: Icons.verified_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        _buildStatCard(
          title: 'أرباح اليوم',
          value: _calculateTotalEarnings(completedOrders).toStringAsFixed(0),
          icon: Icons.account_balance_wallet_rounded,
          symbol: 'ج.م',
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => setState(() => _selectedIndex = 2),
        ),
        _buildStatCard(
          title: 'طلبات جديدة',
          value: orderProvider.captainCurrentOrders
              .where((o) => o.status == OrderStatus.pending)
              .length
              .toString(),
          icon: Icons.notifications_active_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => setState(() => _selectedIndex = 0),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    String? symbol,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (gradient as LinearGradient).colors.first.withValues(
                  alpha: 0.3,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (symbol != null)
                          Text(
                            ' $symbol',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ===== Active Orders =====
  Widget _buildActiveOrders(OrderProvider orderProvider, ThemeData theme) {
    final activeOrders = orderProvider.captainCurrentOrders.where((order) {
      return order.status == OrderStatus.pending ||
          order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.preparing ||
          order.status == OrderStatus.ready ||
          order.status == OrderStatus.pickedUp ||
          order.status == OrderStatus.inTransit;
    }).toList();

    if (activeOrders.isEmpty) {
      return _buildEmptyOrders(theme);
    }

    final currentOrder = _pickSingleDashboardOrder(activeOrders);
    if (currentOrder == null) {
      return _buildEmptyOrders(theme);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildOrderCard(currentOrder, theme),
    );
  }

  OrderModel? _pickSingleDashboardOrder(List<OrderModel> orders) {
    if (orders.isEmpty) return null;

    final priority = <OrderStatus>[
      OrderStatus.inTransit,
      OrderStatus.pickedUp,
      OrderStatus.ready,
      OrderStatus.preparing,
      OrderStatus.confirmed,
      OrderStatus.pending,
    ];

    for (final status in priority) {
      final candidates = orders.where((o) => o.status == status).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (candidates.isNotEmpty) return candidates.first;
    }

    return orders.first;
  }

  Widget _buildEmptyOrders(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'في انتظار طلبات جديدة',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابقَ متصلاً لاستقبال الطلبات الجديدة الموجّهة لك',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, ThemeData theme) {
    final statusColor = _getStatusColor(order.status);
    final timeAgo = _getTimeAgo(order.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDeliveryScreen(orderId: order.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: رقم الطلب + الحالة + الوقت
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طلب #${order.id.substring(0, 8).toUpperCase()}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeAgo,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${order.paymentMethod.displayName}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(order.status, statusColor),
                      ],
                    ),
                    // 🏪 اسم المتجر
                    if (order.storeName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.store_rounded,
                            size: 16,
                            color: Colors.teal[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.storeName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.teal[700],
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    // العنوان
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            order.deliveryAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // المبلغ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المبلغ الإجمالي',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(2)} ج.م',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Footer: أزرار الإجراءات
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _updateOrderStatus(
                          order,
                          _getNextStatus(order.status),
                        ),
                        icon: Icon(_getActionIcon(order.status), size: 18),
                        label: Text(
                          _getActionText(order.status),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: _isDeliveryToCustomerStage(order.status)
                          ? 'فتح موقع العميل على Google Maps'
                          : 'فتح موقع المتجر على Google Maps',
                      button: true,
                      child: Tooltip(
                        message: _isDeliveryToCustomerStage(order.status)
                            ? 'افتح موقع العميل'
                            : 'افتح موقع المتجر',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openGpsForOrder(order),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.gps_fixed_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'اتصال بالعميل',
                      button: true,
                      child: Tooltip(
                        message: 'اتصال بالعميل',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (order.clientPhone != null &&
                                  order.clientPhone!.isNotEmpty) {
                                _callCustomer(order.clientPhone!);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('رقم هاتف العميل غير متوفر'),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.phone_rounded,
                                color: AppColors.success,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildStatusChip(OrderStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ===== Helper Methods =====

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }

  double _calculateTotalEarnings(List<OrderModel> orders) {
    return orders.fold(
      0.0,
      (sum, order) =>
          sum + CaptainOrderHelpers.calculateCommission(order.totalAmount),
    );
  }

  Future<void> _loadCaptainData(String captainId) async {
    try {
      AppLogger.info('🔄 Loading captain data for: $captainId');
      final model = await SupabaseService.getCaptain(captainId);

      if (model == null) {
        AppLogger.warning('⚠️ No captain record found for ID: $captainId');
      } else {
        AppLogger.info(
          '✅ Captain data loaded. Status: ${model.status}, isOnline: ${model.isOnline}',
        );
      }

      if (mounted) {
        setState(() {
          _isOnline =
              model != null &&
              (model.isOnline ||
                  model.status == 'online' ||
                  model.status == 'active');
          _isStatusLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('❌ Error loading captain data', e);
      if (mounted) {
        setState(() => _isStatusLoading = false);
      }
    }
  }

  Color _getStatusColor(OrderStatus status) =>
      CaptainOrderHelpers.getStatusColor(status);

  String _getActionText(OrderStatus status) =>
      CaptainOrderHelpers.getDashboardActionText(status);

  IconData _getActionIcon(OrderStatus status) =>
      CaptainOrderHelpers.getActionIcon(status);

  OrderStatus _getNextStatus(OrderStatus currentStatus) =>
      CaptainOrderHelpers.getNextStatus(currentStatus);

  // ===== Toggle Status Dialog =====
  void _showToggleStatusDialog(bool newValue, dynamic captain) {
    if (captain == null) return;

    final isGoingOffline = !newValue;

    if (isGoingOffline) {
      // 🛡️ حماية: منع الذهاب أوفلاين أثناء طلب توصيل نشط
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.hasCaptainActiveOrders) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ لديك طلب نشط — أكمل التوصيل أولاً قبل الذهاب أوفلاين',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.warning,
          ),
          title: const Text('تأكيد تغيير الحالة'),
          content: const Text(
            'هل أنت متأكد من تغيير حالتك إلى "غير متصل"؟\n\nلن تتلقى طلبات جديدة أثناء عدم الاتصال.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _toggleOnlineStatus(newValue, captain);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
    } else {
      _toggleOnlineStatus(newValue, captain);
    }
  }

  Future<void> _toggleOnlineStatus(bool value, dynamic captain) async {
    setState(() => _isStatusLoading = true);
    final status = value ? 'online' : 'offline';
    final success = await SupabaseService.updateCaptainStatus(
      captain.id,
      status,
    );
    if (!mounted) return;

    if (success) {
      setState(() {
        _isOnline = value;
        _isStatusLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(value ? 'أنت الآن متصل' : 'تم قطع الاتصال'),
            ],
          ),
          backgroundColor: value ? AppColors.success : Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isStatusLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل تحديث الحالة'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ===== Update Order Status =====
  void _updateOrderStatus(OrderModel order, OrderStatus newStatus) async {
    if (!CaptainOrderHelpers.canTransition(order.status, newStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن الانتقال من ${CaptainOrderHelpers.getStatusText(order.status)} إلى ${CaptainOrderHelpers.getStatusText(newStatus)}',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // تأكيد قبل تحديث الحالة إلى "تم التوصيل" (إجراء لا يمكن التراجع عنه)
    if (newStatus == OrderStatus.delivered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.green,
          ),
          title: const Text('تأكيد التسليم'),
          content: Text(CaptainOrderHelpers.getConfirmationMessage(newStatus)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا، تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، تم التسليم'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final success = await orderProvider.updateOrderStatus(
        order.id,
        newStatus.dbValue,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('تم تحديث الحالة إلى: ${newStatus.displayName}'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('فشل تحديث حالة الطلب', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التحديث: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _callCustomer(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    await CaptainContactUtils.callPhone(
      context,
      phoneNumber,
      unavailableMessage: 'رقم هاتف العميل غير متوفر',
    );
  }

  bool _isDeliveryToCustomerStage(OrderStatus status) {
    return status == OrderStatus.pickedUp ||
        status == OrderStatus.inTransit ||
        status == OrderStatus.delivered;
  }

  Future<void> _openGpsForOrder(OrderModel order) async {
    final toCustomer = _isDeliveryToCustomerStage(order.status);

    if (toCustomer) {
      final lat = order.deliveryLatitude;
      final lng = order.deliveryLongitude;

      if (lat != null && lng != null) {
        await CaptainContactUtils.openMapByCoordinates(context, lat, lng);
        return;
      }

      final address = order.deliveryAddress.trim();
      if (address.isNotEmpty) {
        await CaptainContactUtils.openMapByAddress(context, address);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('موقع العميل غير متوفر')));
      return;
    }

    final storeLat = order.storeLatitude;
    final storeLng = order.storeLongitude;
    if (storeLat != null && storeLng != null) {
      await CaptainContactUtils.openMapByCoordinates(
        context,
        storeLat,
        storeLng,
      );
      return;
    }

    final storeAddress = order.storeAddress?.trim() ?? '';
    if (storeAddress.isNotEmpty) {
      await CaptainContactUtils.openMapByAddress(context, storeAddress);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('موقع المتجر غير متوفر')));
  }

  // ===== Notifications Bottom Sheet =====
  void _showNotificationsSheet(
    BuildContext context,
    NotificationProvider notificationProvider,
    int unreadCount,
  ) {
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
            child: SafeArea(
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
                        const Icon(Icons.notifications_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'الإشعارات',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (unreadCount > 0) ...[
                          TextButton.icon(
                            onPressed: () {
                              final userId = Provider.of<SupabaseProvider>(
                                context,
                                listen: false,
                              ).currentUser?.id;
                              if (userId != null) {
                                notificationProvider.markAllAsRead(userId);
                              }
                            },
                            icon: const Icon(Icons.mark_email_read, size: 18),
                            label: const Text('قراءة الكل'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showDeleteAllNotificationsDialog(
                              context,
                              notificationProvider,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'مسح الكل',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _NotificationsBottomSheetContent(
                      targetRole: 'captain',
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAllNotificationsDialog(
    BuildContext context,
    NotificationProvider notificationProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
        title: const Text('حذف جميع الإشعارات'),
        content: const Text('هل أنت متأكد من حذف جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final userId = Provider.of<SupabaseProvider>(
                context,
                listen: false,
              ).currentUser?.id;
              if (userId != null) {
                notificationProvider.deleteUserNotifications(userId);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف جميع الإشعارات'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
  }
}

// ===== Bottom Sheet Content Widget =====
class _NotificationsBottomSheetContent extends StatelessWidget {
  final String? targetRole;
  final ScrollController scrollController;

  const _NotificationsBottomSheetContent({
    this.targetRole,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<SupabaseProvider>(context);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return _buildLoginRequired(context);
    }

    if (notificationProvider.isLoading) {
      return AppShimmer.list(context);
    }

    final notifications = notificationProvider.getNotificationsForRole(
      targetRole,
    );

    if (notificationProvider.error != null) {
      return _buildError(context, notificationProvider, userId);
    }

    if (notifications.isEmpty) {
      return _buildEmpty(context);
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

  Widget _buildLoginRequired(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'يرجى تسجيل الدخول',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتسجيل الدخول لعرض الإشعارات',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    NotificationProvider provider,
    String userId,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'مشكلة في الاتصال',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  provider.loadUserNotifications(userId, targetRole: 'captain'),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم إعلامك عند وجود إشعارات جديدة',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
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
    final theme = Theme.of(context);
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
          const SnackBar(
            content: Text('تم حذف الإشعار'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: notification.isRead
            ? theme.colorScheme.surface
            : AppColors.primary.withAlpha(25),
        elevation: notification.isRead ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
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
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                notification.createdAtRelative,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () {
            if (!notification.isRead) provider.markAsRead(notification.id);
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}
