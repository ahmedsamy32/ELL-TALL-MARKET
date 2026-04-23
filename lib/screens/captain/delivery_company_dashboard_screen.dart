import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/screens/captain/captain_wallet_screen.dart';

class DeliveryCompanyDashboardScreen extends StatefulWidget {
  const DeliveryCompanyDashboardScreen({super.key});

  @override
  State<DeliveryCompanyDashboardScreen> createState() =>
      _DeliveryCompanyDashboardScreenState();
}

class _DeliveryCompanyDashboardScreenState
    extends State<DeliveryCompanyDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _captainsChannel;

  bool _isCaptainsLoading = true;
  List<CaptainModel> _captains = [];
  int _selectedBottomIndex = 0;
  int _selectedOrdersTabIndex = 0;
  bool _isRefreshing = false;

  static const Duration _autoAssignDelay = Duration(seconds: 60);
  final Map<String, Timer> _autoAssignTimers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _captainsChannel?.unsubscribe();
    for (final timer in _autoAssignTimers.values) {
      timer.cancel();
    }
    _autoAssignTimers.clear();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final orderProvider = context.read<OrderProvider>();
    await orderProvider.fetchAllOrders();
    await orderProvider.subscribeToDeliveryDashboardOrders();
    await _loadCaptains();
    await _subscribeCaptainsRealtime();
    await _activateNotifications();
  }

  Future<void> _refreshAll() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }
    final orderProvider = context.read<OrderProvider>();
    try {
      await Future.wait([
        orderProvider.fetchAllOrders(),
        _loadCaptains(),
        _reloadNotificationsOnly(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String get _notificationTargetRole {
    final role = context.read<SupabaseProvider>().currentProfile?.role.value;
    if (role == null) return 'captain';
    // حالياً التنبيهات التشغيلية لهذه الشاشة تُرسل غالباً على دور captain
    if (role == 'delivery_company_admin') return 'captain';
    return role;
  }

  Future<void> _activateNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await NotificationServiceEnhanced.instance.initialize();
      await NotificationServiceEnhanced.instance.saveDeviceTokenForRole(
        _notificationTargetRole,
      );
      if (!mounted) return;
      await context.read<NotificationProvider>().loadUserNotifications(
        userId,
        targetRole: _notificationTargetRole,
      );
    } catch (e) {
      AppLogger.error('Failed to activate notifications', e);
    }
  }

  Future<void> _reloadNotificationsOnly() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await context.read<NotificationProvider>().loadUserNotifications(
      userId,
      targetRole: _notificationTargetRole,
    );
  }

  Future<void> _loadCaptains() async {
    if (!mounted) return;
    setState(() => _isCaptainsLoading = true);

    try {
      final captains = await CaptainService.getCaptains(
        orderBy: 'updated_at',
        ascending: false,
      );
      if (!mounted) return;
      setState(() {
        _captains = captains;
        _isCaptainsLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load captains for delivery dashboard', e);
      if (!mounted) return;
      setState(() => _isCaptainsLoading = false);
    }
  }

  Future<void> _subscribeCaptainsRealtime() async {
    await _captainsChannel?.unsubscribe();
    _captainsChannel = _supabase
        .channel('delivery-company-captains')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'captains',
          callback: (payload) {
            AppLogger.info('🔄 Captain dashboard event: ${payload.eventType}');
            _loadCaptains();
          },
        )
        .subscribe();
  }

  void _syncAutoAssignTimers(List<OrderModel> readyOrders) {
    final readyOrderIds = readyOrders.map((order) => order.id).toSet();

    // Cancel timers for orders that are no longer ready/unassigned.
    final toCancel = _autoAssignTimers.keys
        .where((id) => !readyOrderIds.contains(id))
        .toList();
    for (final orderId in toCancel) {
      _autoAssignTimers[orderId]?.cancel();
      _autoAssignTimers.remove(orderId);
    }

    // Start timers for newly ready orders.
    for (final order in readyOrders) {
      if (_autoAssignTimers.containsKey(order.id)) continue;
      _autoAssignTimers[order.id] = Timer(_autoAssignDelay, () {
        _handleAutoAssignTimeout(order.id);
      });
    }
  }

  Future<void> _handleAutoAssignTimeout(String orderId) async {
    _autoAssignTimers.remove(orderId);
    if (!mounted) return;

    final orderProvider = context.read<OrderProvider>();

    OrderModel? targetOrder;
    for (final order in orderProvider.orders) {
      if (order.id == orderId) {
        targetOrder = order;
        break;
      }
    }

    // Already assigned or no longer ready -> no auto assignment needed.
    if (targetOrder == null ||
        targetOrder.status != OrderStatus.ready ||
        targetOrder.captainId != null) {
      return;
    }

    // Refresh captains list before selecting the first eligible one.
    await _loadCaptains();

    CaptainModel? firstEligibleCaptain;
    for (final captain in _captains) {
      final isEligible =
          captain.isOnline && captain.isAvailable && captain.status != 'busy';
      if (isEligible) {
        firstEligibleCaptain = captain;
        break;
      }
    }

    if (firstEligibleCaptain == null) {
      AppLogger.warning(
        '⏱️ انتهت 60ث للطلب $orderId ولا يوجد كابتن متصل ومتاح حالياً',
      );
      return;
    }

    final success = await orderProvider.assignCaptainToOrder(
      orderId: orderId,
      captainId: firstEligibleCaptain.id,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم التعيين التلقائي للطلب #${orderId.substring(0, 8).toUpperCase()} إلى ${_captainDisplayName(firstEligibleCaptain)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _companyNameOrAccount {
    final profile = context.read<SupabaseProvider>().currentProfile;
    final fullName = profile?.fullName?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final email = profile?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return 'حسابك';
  }

  String get _companyDashboardTitle => 'لوحة تحكم شركة $_companyNameOrAccount';

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final isCompact = MediaQuery.sizeOf(context).width < 700;
        final orders = orderProvider.orders;
        final readyOrders = _filterOrders(
          orders,
          (order) =>
              order.status == OrderStatus.ready && order.captainId == null,
        );
        _syncAutoAssignTimers(readyOrders);
        final assignedOrders = _filterOrders(
          orders,
          (order) =>
              order.captainId != null && order.status == OrderStatus.ready,
        );
        final inDeliveryOrders = _filterOrders(
          orders,
          (order) =>
              order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.preparing ||
              order.status == OrderStatus.pickedUp ||
              order.status == OrderStatus.inTransit,
        );
        final completedOrders = _filterOrders(
          orders,
          (order) => order.status == OrderStatus.delivered,
        );

        final tabOrders = [
          readyOrders,
          assignedOrders,
          inDeliveryOrders,
          completedOrders,
        ];
        final tabTitles = [
          'طلبات جاهزة للتوصيل',
          'طلبات مُسندة',
          'طلبات قيد التوصيل',
          'طلبات مكتملة',
        ];
        final tabSubtitles = [
          'طلبات بانتظار إسناد كابتن',
          'طلبات تم إسنادها للكباتن ولم يتم استلامها بعد',
          'تم الاستلام وهي في الطريق',
          'أرشيف الطلبات التي تم توصيلها',
        ];
        final tabEmptyMessages = [
          'لا توجد طلبات جاهزة حالياً',
          'لا توجد طلبات مُسندة بعد',
          'لا توجد عمليات توصيل نشطة',
          'لا توجد طلبات مكتملة بعد',
        ];
        final tabEmptyIcons = [
          Icons.local_shipping_outlined,
          Icons.person_pin_circle_outlined,
          Icons.delivery_dining_outlined,
          Icons.check_circle_outline,
        ];

        final selectedTab = _selectedOrdersTabIndex.clamp(0, 3);
        final showFullPageShimmer =
            _isRefreshing ||
            (orderProvider.isLoading && orders.isEmpty) ||
            (_isCaptainsLoading && _captains.isEmpty);

        final dashboardBody = SafeArea(
          child: ColoredBox(
            color: Colors.white,
            child: ResponsiveCenter(
              maxWidth: 1200,
              child: DefaultTabController(
                length: 4,
                initialIndex: selectedTab,
                child: showFullPageShimmer
                    ? _buildDashboardFullPageShimmer()
                    : RefreshIndicator(
                        onRefresh: _refreshAll,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          children: [
                            _buildTopBlueHeader(),
                            const SizedBox(height: 12),
                            _buildHeader(
                              orderProvider,
                              readyOrders.length,
                              assignedOrders.length,
                              inDeliveryOrders.length,
                              completedOrders.length,
                              isCompact: isCompact,
                            ),
                            const SizedBox(height: 16),
                            _buildCaptainSummaryRow(isCompact: isCompact),
                            const SizedBox(height: 16),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: TabBar(
                                isScrollable: isCompact,
                                tabAlignment: isCompact
                                    ? TabAlignment.start
                                    : null,
                                onTap: (index) {
                                  setState(
                                    () => _selectedOrdersTabIndex = index,
                                  );
                                },
                                labelColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                unselectedLabelColor: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                unselectedLabelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: 'جاهزة'),
                                  Tab(text: 'مُسندة'),
                                  Tab(text: 'قيد التوصيل'),
                                  Tab(text: 'مكتملة'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildOrdersTab(
                              title: tabTitles[selectedTab],
                              subtitle: tabSubtitles[selectedTab],
                              orders: tabOrders[selectedTab],
                              emptyMessage: tabEmptyMessages[selectedTab],
                              emptyIcon: tabEmptyIcons[selectedTab],
                              canAssign: selectedTab == 0,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );

        return Scaffold(
          backgroundColor: Colors.white,
          body: _selectedBottomIndex == 0
              ? dashboardBody
              : const CaptainWalletScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedBottomIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedBottomIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'اللوحة',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'المحفظة',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardFullPageShimmer() {
    return AppShimmer.wrap(
      context,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          AppShimmer.box(
            context,
            width: double.infinity,
            height: kToolbarHeight,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 12),
          AppShimmer.box(
            context,
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppShimmer.box(
                  context,
                  width: double.infinity,
                  height: 76,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppShimmer.box(
                  context,
                  width: double.infinity,
                  height: 76,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppShimmer.box(
                  context,
                  width: double.infinity,
                  height: 76,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppShimmer.box(
            context,
            width: double.infinity,
            height: 52,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(height: 12),
          AppShimmer.list(context, itemCount: 5, itemHeight: 112),
        ],
      ),
    );
  }

  Widget _buildTopBlueHeader() {
    final theme = Theme.of(context);
    final headerForeground =
        ThemeData.estimateBrightnessForColor(AppColors.primary) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Container(
      height: 84,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Center(
                child: Text(
                  _companyDashboardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: headerForeground,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.main,
                    (route) => false,
                  );
                },
                tooltip: 'الرئيسية',
                icon: const Icon(Icons.home_rounded),
                color: headerForeground,
              ),
              const Spacer(),
              _buildNotificationIcon(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final targetRole = _notificationTargetRole;
    final headerForeground =
        ThemeData.estimateBrightnessForColor(AppColors.primary) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.getUnreadCountForRole(
          targetRole,
        );

        return Stack(
          children: [
            IconButton(
              tooltip: 'الإشعارات',
              icon: const Icon(Icons.notifications_outlined),
              color: headerForeground,
              onPressed: () => _showNotificationsSheet(
                context,
                notificationProvider,
                unreadCount,
                targetRole,
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

  void _showNotificationsSheet(
    BuildContext context,
    NotificationProvider notificationProvider,
    int unreadCount,
    String targetRole,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                    child: _DeliveryNotificationsBottomSheetContent(
                      targetRole: targetRole,
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

  Widget _buildHeader(
    OrderProvider orderProvider,
    int readyCount,
    int assignedCount,
    int inDeliveryCount,
    int completedCount, {
    required bool isCompact,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return Container(
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
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً بك',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _companyNameOrAccount,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'إدارة الطلبات الجاهزة، إسناد الكباتن، ومتابعة عمليات التوصيل النشطة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isCompact)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricChip(
                      'كل الطلبات',
                      orderProvider.orders.length,
                      Icons.receipt_long_rounded,
                      colorScheme.primary,
                      width: 94,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricChip(
                      'جاهزة',
                      readyCount,
                      Icons.hourglass_empty_rounded,
                      Colors.orange,
                      width: 94,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricChip(
                      'مُسندة',
                      assignedCount,
                      Icons.person_pin_circle_rounded,
                      Colors.blue,
                      width: 94,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricChip(
                      'قيد التوصيل',
                      inDeliveryCount,
                      Icons.delivery_dining_rounded,
                      Colors.purple,
                      width: 94,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricChip(
                      'مكتملة',
                      completedCount,
                      Icons.check_circle_rounded,
                      Colors.green,
                      width: 94,
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricChip(
                    'كل الطلبات',
                    orderProvider.orders.length,
                    Icons.receipt_long_rounded,
                    colorScheme.primary,
                    width: 94,
                  ),
                  _buildMetricChip(
                    'جاهزة',
                    readyCount,
                    Icons.hourglass_empty_rounded,
                    Colors.orange,
                    width: 94,
                  ),
                  _buildMetricChip(
                    'مُسندة',
                    assignedCount,
                    Icons.person_pin_circle_rounded,
                    Colors.blue,
                    width: 94,
                  ),
                  _buildMetricChip(
                    'قيد التوصيل',
                    inDeliveryCount,
                    Icons.delivery_dining_rounded,
                    Colors.purple,
                    width: 94,
                  ),
                  _buildMetricChip(
                    'مكتملة',
                    completedCount,
                    Icons.check_circle_rounded,
                    Colors.green,
                    width: 94,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    String label,
    int value,
    IconData icon,
    Color color, {
    double width = 190,
    bool dense = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 14,
        vertical: dense ? 10 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.86), color],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(dense ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: dense ? 12 : 16,
            offset: Offset(0, dense ? 6 : 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: dense ? -10 : -16,
            top: dense ? -8 : -12,
            child: Icon(
              icon,
              size: dense ? 56 : 74,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(dense ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(dense ? 8 : 10),
                ),
                child: Icon(icon, size: dense ? 16 : 18, color: Colors.white),
              ),
              SizedBox(height: dense ? 6 : 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: dense ? 22 : 28,
                  ),
                ),
              ),
              SizedBox(height: dense ? 1 : 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: dense ? 10 : 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainSummaryRow({required bool isCompact}) {
    final onlineCaptains = _captains
        .where((captain) => captain.status == 'online' && captain.isAvailable)
        .toList(growable: false);
    final busyCaptains = _captains
        .where((captain) => captain.status == 'busy')
        .toList(growable: false);
    final offlineCaptains = _captains
        .where(
          (captain) =>
              captain.status != 'busy' &&
              !(captain.status == 'online' && captain.isAvailable),
        )
        .toList(growable: false);

    final online = onlineCaptains.length;
    final busy = busyCaptains.length;
    final offline = offlineCaptains.length;

    if (isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCaptainStateCard(
              'متصل',
              online,
              Colors.green,
              width: 100,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن المتصلون',
                captains: onlineCaptains,
                accentColor: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            _buildCaptainStateCard(
              'مشغول',
              busy,
              Colors.orange,
              width: 100,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن المشغولون',
                captains: busyCaptains,
                accentColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            _buildCaptainStateCard(
              'غير متصل',
              offline,
              Colors.grey,
              width: 100,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن غير المتصلين',
                captains: offlineCaptains,
                accentColor: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildCaptainStateCard(
          'متصل',
          online,
          Colors.green,
          onTap: () => _showCaptainsByStateSheet(
            title: 'الكباتن المتصلون',
            captains: onlineCaptains,
            accentColor: Colors.green,
          ),
        ),
        _buildCaptainStateCard(
          'مشغول',
          busy,
          Colors.orange,
          onTap: () => _showCaptainsByStateSheet(
            title: 'الكباتن المشغولون',
            captains: busyCaptains,
            accentColor: Colors.orange,
          ),
        ),
        _buildCaptainStateCard(
          'غير متصل',
          offline,
          Colors.grey,
          onTap: () => _showCaptainsByStateSheet(
            title: 'الكباتن غير المتصلين',
            captains: offlineCaptains,
            accentColor: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptainStateCard(
    String label,
    int count,
    Color color, {
    double width = 110,
    VoidCallback? onTap,
  }) {
    final isNarrow = width <= 120;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: width,
          padding: EdgeInsets.all(isNarrow ? 10 : 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.zero,
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person, color: color, size: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person, color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$count',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCaptainsByStateSheet({
    required String title,
    required List<CaptainModel> captains,
    required Color accentColor,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('عدد الكباتن: ${captains.length}'),
                const SizedBox(height: 16),
                if (captains.isEmpty)
                  _buildEmptyState(
                    'لا يوجد كباتن في هذا القسم حالياً',
                    Icons.group_off,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: captains.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final captain = captains[index];
                        final phone =
                            captain.contactPhone ??
                            captain.profilePhone ??
                            'بدون هاتف';
                        final hasPhone =
                            (captain.contactPhone ?? captain.profilePhone)
                                ?.trim()
                                .isNotEmpty ??
                            false;
                        final status = _captainStatusText(captain);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(Icons.person, color: accentColor),
                          ),
                          title: Text(
                            _captainDisplayName(captain),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '$phone\n${captain.vehicleTypeDisplayName} • ⭐ ${captain.rating.toStringAsFixed(1)} • $status',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: hasPhone
                                ? 'اتصال مباشر'
                                : 'لا يوجد رقم هاتف',
                            onPressed: hasPhone
                                ? () => _launchPhoneCall(
                                    captain.contactPhone ??
                                        captain.profilePhone ??
                                        '',
                                  )
                                : null,
                            icon: const Icon(Icons.phone_rounded),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchPhoneCall(String rawPhone) async {
    final phone = rawPhone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير متوفر')));
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
    }
  }

  Widget _buildOrdersTab({
    required String title,
    required String subtitle,
    required List<OrderModel> orders,
    required String emptyMessage,
    required IconData emptyIcon,
    bool canAssign = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            _buildEmptyState(emptyMessage, emptyIcon)
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOrderCard(order, canAssign: canAssign),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color: theme.colorScheme.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, {bool canAssign = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(order.status);
    final captain = order.captainId == null
        ? null
        : _captainById(order.captainId!);

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${order.id.substring(0, 8).toUpperCase()}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.storeName ?? 'المتجر',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.storeAddress?.trim().isNotEmpty == true
                          ? order.storeAddress!
                          : 'عنوان المتجر غير متوفر',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('${order.totalAmount.toStringAsFixed(2)} EGP'),
                  const Spacer(),
                  Text(
                    captain == null
                        ? 'لا يوجد كابتن مُسند'
                        : 'الكابتن: ${_captainDisplayName(captain)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'رسوم التوصيل: ${order.deliveryFee.toStringAsFixed(2)} EGP',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (canAssign &&
                      order.status == OrderStatus.ready &&
                      order.captainId == null)
                    FilledButton.icon(
                      onPressed: _captainsLoadingFallback
                          ? null
                          : () => _showAssignCaptainSheet(order),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('إسناد كابتن'),
                    ),
                  if (!canAssign ||
                      order.captainId != null ||
                      order.status != OrderStatus.ready)
                    Expanded(
                      child: Text(
                        _orderActionHint(order),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _captainsLoadingFallback => _isCaptainsLoading || _captains.isEmpty;

  String _orderActionHint(OrderModel order) {
    if (order.status == OrderStatus.delivered) return 'تم التوصيل';
    if (order.status == OrderStatus.inTransit ||
        order.status == OrderStatus.pickedUp) {
      return 'توصيل نشط';
    }
    if (order.captainId != null) return 'بانتظار إجراء الكابتن';
    return 'بانتظار موافقة التاجر أو جاهز للإسناد';
  }

  Future<void> _showAssignCaptainSheet(OrderModel order) async {
    if (_isCaptainsLoading) {
      return;
    }

    final availableCaptains =
        _captains
            .where(
              (captain) =>
                  captain.isOnline &&
                  captain.isAvailable &&
                  captain.status != 'busy',
            )
            .toList()
          ..sort(
            (a, b) =>
                b.lastAvailableAt?.compareTo(
                  a.lastAvailableAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ) ??
                0,
          );

    String? selectedCaptainId = availableCaptains.isNotEmpty
        ? availableCaptains.first.id
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'إسناد كابتن',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر كابتن متاح للطلب #${order.id.substring(0, 8).toUpperCase()}',
                    ),
                    const SizedBox(height: 16),
                    if (availableCaptains.isEmpty)
                      _buildEmptyState(
                        'لا يوجد كباتن متاحون حالياً',
                        Icons.person_off_outlined,
                      )
                    else
                      RadioGroup<String>(
                        groupValue: selectedCaptainId,
                        onChanged: (value) {
                          setSheetState(() => selectedCaptainId = value);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _captains.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final captain = _captains[index];
                              final isAssignable =
                                  captain.isOnline &&
                                  captain.isAvailable &&
                                  captain.status != 'busy';
                              final status = _captainStatusText(captain);
                              final statusColor = _captainStatusColor(captain);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: isAssignable
                                    ? () => setSheetState(
                                        () => selectedCaptainId = captain.id,
                                      )
                                    : null,
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Icon(Icons.person, color: statusColor),
                                ),
                                title: Text(
                                  _captainDisplayName(captain),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isAssignable
                                        ? null
                                        : Theme.of(context).disabledColor,
                                  ),
                                ),
                                subtitle: Text(
                                  '${captain.contactPhone ?? captain.profilePhone ?? 'بدون هاتف'} • '
                                  '${captain.vehicleTypeDisplayName} • '
                                  '⭐ ${captain.rating.toStringAsFixed(1)} • $status',
                                  style: TextStyle(color: statusColor),
                                ),
                                trailing: isAssignable
                                    ? Radio<String>(value: captain.id)
                                    : const Icon(Icons.lock_outline_rounded),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedCaptainId == null
                            ? null
                            : () async {
                                final orderProvider = context
                                    .read<OrderProvider>();
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(sheetContext);
                                final success = await orderProvider
                                    .assignCaptainToOrder(
                                      orderId: order.id,
                                      captainId: selectedCaptainId!,
                                    );
                                if (!mounted) return;
                                if (success) {
                                  navigator.pop();
                                  await _refreshAll();
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إسناد الكابتن بنجاح'),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        orderProvider.error ??
                                            'فشل في إسناد الكابتن',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: const Text('إسناد كابتن'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<OrderModel> _filterOrders(
    List<OrderModel> orders,
    bool Function(OrderModel order) predicate,
  ) {
    final filtered = orders.where(predicate).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  CaptainModel? _captainById(String captainId) {
    for (final captain in _captains) {
      if (captain.id == captainId) return captain;
    }
    return null;
  }

  String _captainDisplayName(CaptainModel captain) {
    final fullName = captain.fullName?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final email = captain.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return 'كابتن ${captain.id.substring(0, 6).toUpperCase()}';
  }

  String _captainStatusText(CaptainModel captain) {
    if (captain.status == 'busy') return 'مشغول';
    if (captain.isOnline && captain.isAvailable) return 'متصل';
    return 'غير متصل';
  }

  Color _captainStatusColor(CaptainModel captain) {
    if (captain.status == 'busy') return Colors.orange;
    if (captain.isOnline && captain.isAvailable) return Colors.green;
    return Colors.grey;
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.deepOrange;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.purple;
      case OrderStatus.inTransit:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}

class _DeliveryNotificationsBottomSheetContent extends StatelessWidget {
  final String? targetRole;
  final ScrollController scrollController;

  const _DeliveryNotificationsBottomSheetContent({
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
              onPressed: () => provider.loadUserNotifications(
                userId,
                targetRole: targetRole ?? 'captain',
              ),
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
