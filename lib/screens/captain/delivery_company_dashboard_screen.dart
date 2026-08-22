import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/services/supabase_service.dart';
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
  String? _companyId;
  String? _companyName;
  String? _companyNameEn;
  String? _companyGovernorate;
  String? _companyCity;
  List<CaptainModel> _captains = [];
  int _selectedBottomIndex = 0;
  int _selectedOrdersTabIndex = 0;
  bool _isRefreshing = false;

  final Map<String, Timer> _autoAssignTimers = {};
  final Set<String> _autoAssignQueue = <String>{};

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
    await _loadCompanyId();
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
        _reloadNotificationsOnly(),
      ]);
      await _loadCompanyId();
      await _loadCaptains();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  bool get _canManageCaptains {
    final role = context.read<SupabaseProvider>().currentProfile?.role.value;
    return role == 'delivery_company_admin';
  }

  Future<void> _loadCompanyId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('delivery_companies')
          .select('id, company_name, company_name_en, governorate, city')
          .eq('admin_id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _companyId = response?['id'] as String?;
        _companyName = response?['company_name'] as String?;
        _companyNameEn = response?['company_name_en'] as String?;
        _companyGovernorate = response?['governorate'] as String?;
        _companyCity = response?['city'] as String?;
      });
    } catch (e) {
      AppLogger.error('Failed to load delivery company id', e);
    }
  }

  String get _notificationTargetRole => 'delivery_company_admin';

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
      if (_canManageCaptains && (_companyId == null || _companyId!.isEmpty)) {
        await _loadCompanyId();
      }

      final deliveryCompanyId = _canManageCaptains ? _companyId : null;
      if (_canManageCaptains &&
          (deliveryCompanyId == null || deliveryCompanyId.isEmpty)) {
        if (!mounted) return;
        setState(() {
          _captains = [];
          _isCaptainsLoading = false;
        });
        return;
      }

      final captains = await CaptainService.getCaptains(
        orderBy: 'updated_at',
        ascending: false,
        deliveryCompanyId: deliveryCompanyId,
      );

      // فحص وتصحيح الكباتن المعلقين بحالة مشغول بدون وجود طلبات نشطة لهم
      final updatedCaptains = <CaptainModel>[];
      for (final cap in captains) {
        if (cap.status == 'busy') {
          try {
            final activeOrders = await _supabase
                .from('orders')
                .select('id')
                .eq('captain_id', cap.id)
                .or(
                  'status.eq.pending,status.eq.confirmed,status.eq.preparing,status.eq.ready,status.eq.picked_up,status.eq.in_transit',
                )
                .limit(1);
            if ((activeOrders as List).isEmpty) {
              AppLogger.info('🔄 تصحيح حالة الكابتن ${cap.id} من مشغول إلى متصل لعدم وجود طلبات نشطة');
              await SupabaseService.updateCaptainStatus(cap.id, 'online');
              updatedCaptains.add(cap.copyWith(
                status: 'online',
                isOnline: true,
                isAvailable: true,
              ));
              continue;
            }
          } catch (_) {}
        }
        updatedCaptains.add(cap);
      }

      if (!mounted) return;
      setState(() {
        _captains = updatedCaptains;
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

  List<OrderGroupRepresentation> _groupOrders(List<OrderModel> ordersList) {
    final Map<String, List<OrderModel>> groups = {};
    for (final order in ordersList) {
      final key = (order.orderGroupId != null && order.orderGroupId!.isNotEmpty)
          ? order.orderGroupId!
          : order.id;
      groups.putIfAbsent(key, () => []).add(order);
    }
    return groups.values.map((list) => OrderGroupRepresentation(list)).toList();
  }

  void _syncAutoAssignTimers(List<OrderGroupRepresentation> readyGroups) {
    // تم إيقاف الإسناد التلقائي للكابتن بناءً على الطلب
    for (final timer in _autoAssignTimers.values) {
      timer.cancel();
    }
    _autoAssignTimers.clear();
    _autoAssignQueue.clear();
    return;
  }



  String get _companyNameOrAccount {
    final companyName = _companyName?.trim();
    if (companyName != null && companyName.isNotEmpty) return companyName;

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
        final groups = _groupOrders(orders);

        final readyOrders = _filterGroups(
          groups,
          (group) =>
              (group.status == OrderStatus.ready || group.status == OrderStatus.pending) &&
              group.captainId == null &&
              _matchesCompanyLocation(group),
        );
        _syncAutoAssignTimers(readyOrders);
        final assignedOrders = _filterGroups(
          groups,
          (group) =>
              group.captainId != null &&
              (group.status == OrderStatus.ready || group.status == OrderStatus.pending) &&
              _isCaptainFromCompany(group.captainId),
        );
        final inDeliveryOrders = _filterGroups(
          groups,
          (group) =>
              (group.status == OrderStatus.confirmed ||
                  group.status == OrderStatus.preparing ||
                  group.status == OrderStatus.pickedUp ||
                  group.status == OrderStatus.inTransit) &&
              (group.captainId == null
                  ? _matchesCompanyLocation(group)
                  : _isCaptainFromCompany(group.captainId)),
        );
        final completedOrders = _filterGroups(
          groups,
          (group) =>
              group.status == OrderStatus.delivered &&
              (group.captainId == null
                  ? _matchesCompanyLocation(group)
                  : _isCaptainFromCompany(group.captainId)),
        );
        final cancelledOrders = _filterGroups(
          groups,
          (group) =>
              group.status == OrderStatus.cancelled &&
              (group.captainId == null
                  ? _matchesCompanyLocation(group)
                  : _isCaptainFromCompany(group.captainId)),
        );

        final tabOrders = [
          readyOrders,
          assignedOrders,
          inDeliveryOrders,
          completedOrders,
          cancelledOrders,
        ];
        final tabTitles = [
          'طلبات جاهزة للتوصيل',
          'طلبات مُسندة',
          'طلبات قيد التوصيل',
          'طلبات مكتملة',
          'طلبات ملغاة',
        ];
        final tabSubtitles = [
          'طلبات بانتظار إسناد كابتن',
          'طلبات تم إسنادها للكباتن ولم يتم استلامها بعد',
          'تم الاستلام وهي في الطريق',
          'أرشيف الطلبات التي تم توصيلها',
          'أرشيف الطلبات الملغاة',
        ];
        final tabEmptyMessages = [
          'لا توجد طلبات جاهزة حالياً',
          'لا توجد طلبات مُسندة بعد',
          'لا توجد عمليات توصيل نشطة',
          'لا توجد طلبات مكتملة بعد',
          'لا توجد طلبات ملغاة بعد',
        ];
        final tabEmptyIcons = [
          Icons.local_shipping_outlined,
          Icons.person_pin_circle_outlined,
          Icons.delivery_dining_outlined,
          Icons.check_circle_outline,
          Icons.cancel_outlined,
        ];

        final selectedTab = _selectedOrdersTabIndex.clamp(0, 4);
        final showFullPageShimmer =
            _isRefreshing ||
            (orderProvider.isLoading && orders.isEmpty) ||
            (_isCaptainsLoading && _captains.isEmpty);

        if (context.isWide) {
          return _buildWebDashboard(
            theme: Theme.of(context),
            orderProvider: orderProvider,
            orders: orders,
            groups: groups,
            readyOrders: readyOrders,
            assignedOrders: assignedOrders,
            inDeliveryOrders: inDeliveryOrders,
            completedOrders: completedOrders,
            cancelledOrders: cancelledOrders,
            tabOrders: tabOrders,
            tabTitles: tabTitles,
            tabSubtitles: tabSubtitles,
            tabEmptyMessages: tabEmptyMessages,
            tabEmptyIcons: tabEmptyIcons,
            selectedTab: selectedTab,
            showFullPageShimmer: showFullPageShimmer,
          );
        }

        final dashboardBody = SafeArea(
          child: ColoredBox(
            color: Colors.white,
            child: ResponsiveCenter(
              maxWidth: 1200,
              child: DefaultTabController(
                length: 5,
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
                              cancelledOrders.length,
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
                                  Tab(text: 'ملغاة'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildOrdersTab(
                              title: tabTitles[selectedTab],
                              subtitle: tabSubtitles[selectedTab],
                              groups: tabOrders[selectedTab],
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

        final captainsBody = _buildCaptainsBody(isCompact: isCompact);

        return Scaffold(
          backgroundColor: Colors.white,
          body: _selectedBottomIndex == 0
              ? dashboardBody
              : _selectedBottomIndex == 1
              ? captainsBody
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
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'الكباتن',
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

  Widget _buildWebDashboard({
    required ThemeData theme,
    required OrderProvider orderProvider,
    required List<OrderModel> orders,
    required List<OrderGroupRepresentation> groups,
    required List<OrderGroupRepresentation> readyOrders,
    required List<OrderGroupRepresentation> assignedOrders,
    required List<OrderGroupRepresentation> inDeliveryOrders,
    required List<OrderGroupRepresentation> completedOrders,
    required List<OrderGroupRepresentation> cancelledOrders,
    required List<List<OrderGroupRepresentation>> tabOrders,
    required List<String> tabTitles,
    required List<String> tabSubtitles,
    required List<String> tabEmptyMessages,
    required List<IconData> tabEmptyIcons,
    required int selectedTab,
    required bool showFullPageShimmer,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          _buildWebSidebar(theme),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: Column(
              children: [
                _buildWebHeader(theme),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: showFullPageShimmer
                      ? _buildDashboardFullPageShimmer()
                      : _selectedBottomIndex == 0
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildWebMetricsRow(
                                          readyOrders.length,
                                          assignedOrders.length,
                                          inDeliveryOrders.length,
                                          completedOrders.length,
                                          cancelledOrders.length,
                                        ),
                                        const SizedBox(height: 24),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            children: List.generate(5, (index) {
                                              final isSelected = selectedTab == index;
                                              final labels = ['جاهزة', 'مُسندة', 'قيد التوصيل', 'مكتملة', 'ملغاة'];
                                              return Expanded(
                                                child: InkWell(
                                                  onTap: () => setState(() => _selectedOrdersTabIndex = index),
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      labels[index],
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? theme.colorScheme.primary
                                                            : theme.colorScheme.onSurfaceVariant,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w800
                                                            : FontWeight.w600,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildOrdersTab(
                                          title: tabTitles[selectedTab],
                                          subtitle: tabSubtitles[selectedTab],
                                          groups: tabOrders[selectedTab],
                                          emptyMessage: tabEmptyMessages[selectedTab],
                                          emptyIcon: tabEmptyIcons[selectedTab],
                                          canAssign: selectedTab == 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                                SizedBox(
                                  width: 320,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'حالة الكباتن (Live)',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildCaptainSummaryRow(isCompact: true),
                                        const SizedBox(height: 20),
                                        const Divider(),
                                        const SizedBox(height: 16),
                                        Text(
                                          'قائمة الكباتن',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (_captains.isEmpty)
                                          _buildEmptyState(
                                            'لا يوجد كباتن متاحين',
                                            Icons.group_off_outlined,
                                          )
                                        else
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _captains.length,
                                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              return _buildCaptainCard(_captains[index]);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _selectedBottomIndex == 1
                              ? _buildWebCaptainsBody()
                              : const CaptainWalletScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar(ThemeData theme) {
    return Container(
      width: 260,
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'سوق التل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildWebSidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'اللوحة الرئيسية',
            isSelected: _selectedBottomIndex == 0,
            onTap: () => setState(() => _selectedBottomIndex = 0),
          ),
          _buildWebSidebarItem(
            icon: Icons.people_rounded,
            label: 'إدارة الكباتن',
            isSelected: _selectedBottomIndex == 1,
            onTap: () => setState(() => _selectedBottomIndex = 1),
          ),
          _buildWebSidebarItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'المحفظة والمالية',
            isSelected: _selectedBottomIndex == 2,
            onTap: () => setState(() => _selectedBottomIndex = 2),
          ),
          const Spacer(),
          _buildWebSidebarItem(
            icon: Icons.home_rounded,
            label: 'الرئيسية للمتجر',
            isSelected: false,
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.main,
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isSelected ? Colors.orange.shade700 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade400,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade300,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'Cairo',
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeader(ThemeData theme) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _companyDashboardTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _refreshAll,
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 16),
          _buildWebNotificationIcon(),
        ],
      ),
    );
  }

  Widget _buildWebNotificationIcon() {
    final targetRole = _notificationTargetRole;
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
              color: Colors.grey.shade700,
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

  Widget _buildWebMetricsRow(
    int readyCount,
    int assignedCount,
    int inDeliveryCount,
    int completedCount,
    int cancelledCount,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetricChip(
          'جاهزة للتوصيل',
          readyCount,
          Icons.hourglass_empty_rounded,
          Colors.orange,
          width: 135,
          dense: true,
        ),
        _buildMetricChip(
          'طلبات مُسندة',
          assignedCount,
          Icons.person_pin_circle_rounded,
          Colors.blue,
          width: 135,
          dense: true,
        ),
        _buildMetricChip(
          'قيد التوصيل',
          inDeliveryCount,
          Icons.delivery_dining_rounded,
          Colors.purple,
          width: 135,
          dense: true,
        ),
        _buildMetricChip(
          'طلبات مكتملة',
          completedCount,
          Icons.check_circle_rounded,
          Colors.green,
          width: 135,
          dense: true,
        ),
        _buildMetricChip(
          'طلبات ملغاة',
          cancelledCount,
          Icons.cancel_rounded,
          Colors.red,
          width: 135,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildWebCaptainsBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'إدارة الكباتن',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
              ),
              const Spacer(),
              if (_canManageCaptains)
                FilledButton.icon(
                  onPressed: _showAddCaptainSheet,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة كابتن جديد'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCaptainSummaryRow(isCompact: false),
          const SizedBox(height: 24),
          if (_captains.isEmpty)
            _buildEmptyState(
              'لا يوجد كباتن مرتبطون بهذه الشركة حالياً',
              Icons.group_off_outlined,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _captains.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 110,
              ),
              itemBuilder: (context, index) {
                return _buildCaptainCard(_captains[index]);
              },
            ),
        ],
      ),
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
    int completedCount,
    int cancelledCount, {
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
                    const SizedBox(width: 10),
                    _buildMetricChip(
                      'ملغاة',
                      cancelledCount,
                      Icons.cancel_rounded,
                      Colors.red,
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
                  _buildMetricChip(
                    'ملغاة',
                    cancelledCount,
                    Icons.cancel_rounded,
                    Colors.red,
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
      return Row(
        children: [
          Expanded(
            child: _buildCaptainStateCard(
              'متصل',
              online,
              Colors.green,
              width: null,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن المتصلون',
                captains: onlineCaptains,
                accentColor: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCaptainStateCard(
              'مشغول',
              busy,
              Colors.orange,
              width: null,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن المشغولون',
                captains: busyCaptains,
                accentColor: Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCaptainStateCard(
              'غير متصل',
              offline,
              Colors.grey,
              width: null,
              onTap: () => _showCaptainsByStateSheet(
                title: 'الكباتن غير المتصلين',
                captains: offlineCaptains,
                accentColor: Colors.grey,
              ),
            ),
          ),
        ],
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

  Widget _buildCaptainsBody({required bool isCompact}) {
    final showFullPageShimmer =
        _isRefreshing || (_isCaptainsLoading && _captains.isEmpty);

    return SafeArea(
      child: ColoredBox(
        color: Colors.white,
        child: ResponsiveCenter(
          maxWidth: 1200,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'الكباتن',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_canManageCaptains)
                            FilledButton.icon(
                              onPressed: _showAddCaptainSheet,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('إضافة كابتن'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCaptainSummaryRow(isCompact: isCompact),
                      const SizedBox(height: 16),
                      if (_captains.isEmpty)
                        _buildEmptyState(
                          'لا يوجد كباتن مرتبطون بهذه الشركة حالياً',
                          Icons.group_off_outlined,
                        )
                      else
                        ..._captains.map(
                          (captain) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCaptainCard(captain),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCaptainCard(CaptainModel captain) {
    final status = _captainStatusText(captain);
    final statusColor = _captainStatusColor(captain);
    final phone = captain.contactPhone ?? captain.profilePhone ?? 'بدون هاتف';

    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          backgroundImage: captain.profileImageUrl != null && captain.profileImageUrl!.isNotEmpty
              ? NetworkImage(captain.profileImageUrl!)
              : null,
          child: captain.profileImageUrl == null || captain.profileImageUrl!.isEmpty
              ? Icon(Icons.person, color: statusColor)
              : null,
        ),
        title: Text(
          _captainDisplayName(captain),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$phone\n${captain.vehicleTypeDisplayName} • ⭐ ${captain.rating.toStringAsFixed(1)} • $status',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: phone == 'بدون هاتف' ? 'لا يوجد رقم هاتف' : 'اتصال مباشر',
              onPressed: phone == 'بدون هاتف'
                  ? null
                  : () => _launchPhoneCall(phone),
              icon: const Icon(Icons.phone_rounded),
            ),
            if (_canManageCaptains)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'خيارات الكابتن',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _showEditCaptainSheet(captain);
                      break;
                    case 'delete':
                      _confirmDeleteCaptain(captain);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('تعديل الكابتن'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف الكابتن', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainStateCard(
    String label,
    int count,
    Color color, {
    double? width = 110,
    VoidCallback? onTap,
  }) {
    final isNarrow = (width ?? 100) <= 120;

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
                            backgroundImage: captain.profileImageUrl != null && captain.profileImageUrl!.isNotEmpty
                                ? NetworkImage(captain.profileImageUrl!)
                                : null,
                            child: captain.profileImageUrl == null || captain.profileImageUrl!.isEmpty
                                ? Icon(Icons.person, color: accentColor)
                                : null,
                          ),
                          title: Text(
                            _captainDisplayName(captain),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '$phone\n${captain.vehicleTypeDisplayName} • ⭐ ${captain.rating.toStringAsFixed(1)} • $status',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
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
                              if (_canManageCaptains)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  tooltip: 'خيارات الكابتن',
                                  onSelected: (action) {
                                    Navigator.pop(sheetContext);
                                    switch (action) {
                                      case 'edit':
                                        _showEditCaptainSheet(captain);
                                        break;
                                      case 'delete':
                                        _confirmDeleteCaptain(captain);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('تعديل الكابتن'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('حذف الكابتن', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
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

  void _showPrescriptionImageDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab({
    required String title,
    required String subtitle,
    required List<OrderGroupRepresentation> groups,
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
          if (groups.isEmpty)
            _buildEmptyState(emptyMessage, emptyIcon)
          else
            ...groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOrderCard(group, canAssign: canAssign),
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

  Widget _buildOrderCard(OrderGroupRepresentation group, {bool canAssign = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(group.status);
    final captain = group.captainId == null
        ? null
        : _captainById(group.captainId!);
    final storeAddressText = group.storeAddresses.isNotEmpty
        ? group.storeAddresses
        : 'عنوان المتجر غير متوفر';

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showOrderDetailsSheet(context, group, canAssign: canAssign),
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
                          group.orders.length > 1
                              ? 'مجموعة طلبات #${group.id.substring(0, 8).toUpperCase()}'
                              : 'طلب #${group.orders.first.id.substring(0, 8).toUpperCase()}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (group.orders.length > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.displayOrderNumbers,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          group.storeNames,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (group.storeCategories.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    group.storeCategories,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                      group.status.displayName,
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
              _buildAddressInfoRow(
                label: 'عنوان العميل',
                address: group.deliveryAddress,
                icon: Icons.location_on_outlined,
                iconColor: Colors.green,
              ),
              const SizedBox(height: 8),
              _buildAddressInfoRow(
                label: group.orders.length > 1 ? 'عناوين المتاجر' : 'عنوان المتجر',
                address: storeAddressText,
                icon: Icons.storefront_outlined,
                iconColor: Colors.orange,
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
                  Text('${group.totalAmount.toStringAsFixed(2)} EGP'),
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
                    'رسوم التوصيل: ${group.deliveryFee.toStringAsFixed(2)} EGP',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (canAssign &&
                      (group.status == OrderStatus.ready || group.status == OrderStatus.pending) &&
                      group.captainId == null)
                    FilledButton.icon(
                      onPressed: _captainsLoadingFallback
                          ? null
                          : () => _showAssignCaptainSheet(group),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('إسناد كابتن'),
                    ),
                  if (!canAssign ||
                      group.captainId != null ||
                      (group.status != OrderStatus.ready && group.status != OrderStatus.pending))
                    Expanded(
                      child: Text(
                        _orderActionHint(group),
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

  Widget _buildAddressInfoRow({
    required String label,
    required String address,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showOrderDetailsSheet(
    BuildContext context,
    OrderGroupRepresentation group, {
    required bool canAssign,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.orders.length > 1
                                      ? 'تفاصيل مجموعة طلبات'
                                      : 'تفاصيل الطلب',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.orders.length > 1
                                      ? '#${group.id.substring(0, 8).toUpperCase()}'
                                      : '#${group.orders.first.id.substring(0, 8).toUpperCase()}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(group.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              group.status.displayName,
                              style: TextStyle(
                                color: _statusColor(group.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    // Body
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [
                          // 👤 Client Details Section
                          _buildDetailsSectionHeader(
                            icon: Icons.person_outline_rounded,
                            title: 'بيانات العميل',
                            color: Colors.green,
                          ),
                          const SizedBox(height: 10),
                          _buildClientDetailsCard(group),
                          const SizedBox(height: 20),

                          // 🏬 Stores & Items Section
                          _buildDetailsSectionHeader(
                            icon: Icons.storefront_rounded,
                            title: group.orders.length > 1 ? 'المتاجر والطلبات' : 'بيانات المتجر والمنتجات',
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          ...group.orders.map((order) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildStoreSubOrderCard(order),
                            );
                          }),
                          
                          // 💰 Financial Details Summary
                          _buildDetailsSectionHeader(
                            icon: Icons.receipt_long_outlined,
                            title: 'الملخص المالي',
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          _buildFinancialSummaryCard(group),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Action Buttons at the Bottom
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('إغلاق'),
                            ),
                          ),
                          if (canAssign &&
                              (group.status == OrderStatus.ready || group.status == OrderStatus.pending) &&
                              group.captainId == null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _captainsLoadingFallback
                                    ? null
                                    : () {
                                        Navigator.pop(sheetContext);
                                        _showAssignCaptainSheet(group);
                                      },
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text('إسناد كابتن'),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildDetailsSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildClientDetailsCard(OrderGroupRepresentation group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstOrder = group.orders.first;
    final clientName = firstOrder.clientName ?? 'عميل غير معروف';
    final clientPhone = firstOrder.clientPhone ?? 'بدون هاتف';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'العميل',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (firstOrder.clientPhone != null && firstOrder.clientPhone!.trim().isNotEmpty)
                IconButton.filledTonal(
                  onPressed: () => _launchPhoneCall(clientPhone),
                  icon: const Icon(Icons.phone_rounded),
                  tooltip: 'اتصال بالعميل',
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عنوان التوصيل',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.deliveryAddress,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (group.deliveryNotes != null && group.deliveryNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_alt_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات التوصيل',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.deliveryNotes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreSubOrderCard(OrderModel order) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storeName = order.storeName ?? 'متجر غير معروف';
    final storeAddress = order.storeAddress ?? 'عنوان المتجر غير متوفر';
    final storePhone = order.storePhone ?? 'بدون هاتف';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (order.storeCategory != null && order.storeCategory!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          order.storeCategory!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        storeAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.storePhone != null && order.storePhone!.trim().isNotEmpty)
                  IconButton.filledTonal(
                    onPressed: () => _launchPhoneCall(storePhone),
                    icon: const Icon(Icons.phone_rounded),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'اتصال بالمتجر',
                  ),
              ],
            ),
          ),
          
          if (order.prescriptionUrl != null && order.prescriptionUrl!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'روشتة العميل المرفقة 📄',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showPrescriptionImageDialog(order.prescriptionUrl!),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          order.prescriptionUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image, size: 40)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          
          // Items List — use pre-loaded items first, fallback to async fetch
          _buildOrderItemsList(order, colorScheme, theme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// يبني قائمة منتجات الطلب. يستخدم الـ items المحملة مسبقاً في order.items
  /// وإذا كانت فارغة (حالات قديمة أو Realtime update) يعمل fetch منفصل.
  Widget _buildOrderItemsList(
    OrderModel order,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    // إذا كانت الـ items محملة مسبقاً — اعرضها فوراً بدون انتظار
    if (order.items.isNotEmpty) {
      return _buildItemsListView(order.items, colorScheme, theme);
    }

    // Fallback: جلب المنتجات من الـ database (في حال عدم تحميلها مع الطلب)
    return FutureBuilder<List<OrderItemModel>>(
      future: OrderService.getOrderItems(order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppShimmer.list(context, itemCount: 2, itemHeight: 48),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'خطأ في تحميل المنتجات',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'لا توجد منتجات في هذا الطلب',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          );
        }
        return _buildItemsListView(items, colorScheme, theme);
      },
    );
  }

  Widget _buildItemsListView(
    List<OrderItemModel> items,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              image: item.productImage != null
                  ? DecorationImage(
                      image: NetworkImage(item.productImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.productImage == null
                ? Icon(Icons.shopping_bag_outlined, color: colorScheme.primary, size: 20)
                : null,
          ),
          title: Text(
            item.productName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity} × ${item.productPrice.toStringAsFixed(2)} EGP',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
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
              if (item.hasSpecialInstructions)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Notes: ${item.specialInstructions}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          trailing: Text(
            '${item.totalPrice.toStringAsFixed(2)} EGP',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  Future<List<OrderItemModel>> _loadGroupItems(OrderGroupRepresentation group) async {
    final allItems = <OrderItemModel>[];
    for (final o in group.orders) {
      if (o.items.isNotEmpty) {
        allItems.addAll(o.items);
      } else {
        final items = await OrderService.getOrderItems(o.id);
        allItems.addAll(items);
      }
    }
    return allItems;
  }

  Widget _buildFinancialSummaryCard(OrderGroupRepresentation group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstOrder = group.orders.first;

    // إجمالي قيمة الخصم المطبق
    final totalDiscount = group.orders.fold(0.0, (sum, o) => sum + o.discountAmount);

    // أكواد الكوبونات المستخدمة
    final couponCodes = group.orders
        .map((o) => o.couponCode)
        .where((code) => code != null && code.trim().isNotEmpty)
        .toSet()
        .cast<String>();
    final couponText = couponCodes.isNotEmpty ? ' (${couponCodes.join(', ')})' : '';

    return FutureBuilder<List<OrderItemModel>>(
      future: _loadGroupItems(group),
      builder: (context, snapshot) {
        double productsOnlyTotal = 0.0;
        if (snapshot.hasData) {
          productsOnlyTotal = snapshot.data!.fold<double>(
            0.0,
            (sum, item) => sum + item.totalPrice,
          );
        } else {
          // Fallback during loading
          productsOnlyTotal = group.orders.fold(
            0.0,
            (sum, o) => sum + (o.totalAmount - o.deliveryFee - o.taxAmount + o.discountAmount).clamp(0.0, double.infinity),
          );
        }

        final grandTotal = group.orders.fold<double>(
          0.0,
          (sum, o) => sum + o.totalAmount,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                label: 'طريقة الدفع',
                value: firstOrder.paymentMethod.displayName,
                valueColor: colorScheme.primary,
                isBoldValue: true,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                label: 'حالة الدفع',
                value: firstOrder.paymentStatus.displayName,
                valueColor: firstOrder.paymentStatus == PaymentStatus.paid ? Colors.green : Colors.orange,
                isBoldValue: true,
              ),
              const SizedBox(height: 8),
              const Divider(height: 16),
              _buildSummaryRow(
                label: 'قيمة المنتجات',
                value: '${productsOnlyTotal.toStringAsFixed(2)} EGP',
              ),
              if (totalDiscount > 0) ...[
                const SizedBox(height: 8),
                _buildSummaryRow(
                  label: 'خصم الكوبون$couponText',
                  value: '-${totalDiscount.toStringAsFixed(2)} EGP',
                  valueColor: Colors.red[700],
                  isBoldValue: true,
                ),
              ],
              const SizedBox(height: 8),
              _buildSummaryRow(
                label: 'رسوم التوصيل',
                value: '${group.deliveryFee.toStringAsFixed(2)} EGP',
              ),
              const SizedBox(height: 8),
              const Divider(height: 16),
              _buildSummaryRow(
                label: 'الإجمالي الكلي',
                value: '${grandTotal.toStringAsFixed(2)} EGP',
                isBoldLabel: true,
                isBoldValue: true,
                fontSize: 16,
                valueColor: colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBoldLabel = false,
    bool isBoldValue = false,
    double fontSize = 14,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBoldLabel ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  bool get _captainsLoadingFallback => _isCaptainsLoading || _captains.isEmpty;

  String _orderActionHint(OrderGroupRepresentation group) {
    if (group.status == OrderStatus.delivered) return 'تم التوصيل';
    if (group.status == OrderStatus.inTransit ||
        group.status == OrderStatus.pickedUp) {
      return 'توصيل نشط';
    }
    if (group.captainId != null) return 'بانتظار إجراء الكابتن';
    return 'بانتظار موافقة التاجر أو جاهز للإسناد';
  }

  Future<void> _showAssignCaptainSheet(OrderGroupRepresentation group) async {
    if (_isCaptainsLoading) {
      return;
    }

    final orderProvider = context.read<OrderProvider>();
    final blockedCaptainIds = orderProvider.orders
        .where(
          (existingOrder) =>
              existingOrder.captainId != null &&
              (existingOrder.status == OrderStatus.ready ||
                  existingOrder.status == OrderStatus.confirmed ||
                  existingOrder.status == OrderStatus.preparing ||
                  existingOrder.status == OrderStatus.pickedUp ||
                  existingOrder.status == OrderStatus.inTransit),
        )
        .map((existingOrder) => existingOrder.captainId!)
        .toSet();

    final availableCaptains =
        _captains
            .where(
              (captain) =>
                  captain.isOnline &&
                  captain.isAvailable &&
                  captain.status != 'busy' &&
                  !blockedCaptainIds.contains(captain.id),
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
                      'اختر كابتن متاح للطلب #${group.id.substring(0, 8).toUpperCase()}',
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
                            itemCount: availableCaptains.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final captain = availableCaptains[index];
                              final status = _captainStatusText(captain);
                              final statusColor = _captainStatusColor(captain);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () => setSheetState(
                                  () => selectedCaptainId = captain.id,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  backgroundImage: captain.profileImageUrl != null && captain.profileImageUrl!.isNotEmpty
                                      ? NetworkImage(captain.profileImageUrl!)
                                      : null,
                                  child: captain.profileImageUrl == null || captain.profileImageUrl!.isEmpty
                                      ? Icon(Icons.person, color: statusColor)
                                      : null,
                                ),
                                title: Text(
                                  _captainDisplayName(captain),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${captain.contactPhone ?? captain.profilePhone ?? 'بدون هاتف'} • '
                                  '${captain.vehicleTypeDisplayName} • '
                                  '⭐ ${captain.rating.toStringAsFixed(1)} • $status',
                                  style: TextStyle(color: statusColor),
                                ),
                                trailing: Radio<String>(value: captain.id),
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
                                      orderId: group.orders.first.id,
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

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isCaptainFromCompany(String? captainId) {
    if (captainId == null) return false;
    return _captains.any((c) => c.id == captainId);
  }

  bool _matchesCompanyLocation(OrderGroupRepresentation group) {
    if (_companyCity == null || _companyCity!.isEmpty) {
      return false;
    }

    final normCompanyCity = _normalizeArabic(_companyCity!.toLowerCase());
    final normCompanyGov = _companyGovernorate != null
        ? _normalizeArabic(_companyGovernorate!.toLowerCase())
        : null;

    for (final order in group.orders) {
      final orderStoreCity = _normalizeArabic(order.storeCity?.toLowerCase() ?? '');
      final cleanAddress = _normalizeArabic(order.deliveryAddress.toLowerCase());

      final matchesStoreCity = orderStoreCity == normCompanyCity;
      final matchesClientCity = cleanAddress.contains(normCompanyCity);

      if (!matchesStoreCity || !matchesClientCity) {
        return false;
      }

      if (normCompanyGov != null) {
        final orderStoreGov = _normalizeArabic(order.storeGovernorate?.toLowerCase() ?? '');
        final matchesStoreGov = orderStoreGov == normCompanyGov;
        final matchesClientGov = cleanAddress.contains(normCompanyGov);
        if (!matchesStoreGov || !matchesClientGov) {
          return false;
        }
      }
    }
    return true;
  }

  List<OrderGroupRepresentation> _filterGroups(
    List<OrderGroupRepresentation> groups,
    bool Function(OrderGroupRepresentation group) predicate,
  ) {
    final filtered = groups.where(predicate).toList();
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

  Future<void> _showAddCaptainSheet() async {
    if (!_canManageCaptains || !mounted) return;
    final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
    if (rootOverlay == null) return;

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final imagePicker = ImagePicker();
    XFile? pickedImage;
    Uint8List? pickedImageBytes;
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool showValidationErrors = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          OverlayEntry? overlayEntry;

          void showAboveSheetSnackBar(
            String message, {
            Color? backgroundColor,
          }) {
            if (!mounted || !rootOverlay.mounted) return;

            overlayEntry?.remove();
            overlayEntry = OverlayEntry(
              builder: (overlayContext) => Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(overlayContext).bottom + 24,
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            rootOverlay.insert(overlayEntry!);
            Timer(const Duration(seconds: 3), () {
              overlayEntry?.remove();
              overlayEntry = null;
            });
          }

          Future<void> pickAvatarImage() async {
            try {
              final file = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1024,
              );

              if (file == null) return;

              final bytes = await file.readAsBytes();
              if (!context.mounted) return;
              setSheetState(() {
                pickedImage = file;
                pickedImageBytes = bytes;
                showValidationErrors = false;
              });
            } catch (e) {
              AppLogger.error('Pick captain avatar error', e);
              if (!context.mounted) return;
              showAboveSheetSnackBar('فشل اختيار الصورة، حاول مرة أخرى');
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                      'إضافة كابتن جديد',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              showValidationErrors && pickedImageBytes == null
                              ? Theme.of(context).colorScheme.error
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            backgroundImage: pickedImageBytes == null
                                ? null
                                : MemoryImage(pickedImageBytes!),
                            child: pickedImageBytes == null
                                ? const Icon(Icons.person_outline, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting ? null : pickAvatarImage,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                pickedImage == null
                                    ? 'اختيار صورة الكابتن'
                                    : 'تغيير الصورة',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showValidationErrors && pickedImageBytes == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 12),
                        child: Text(
                          'الصورة الشخصية مطلوبة',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      onChanged: (_) {
                        if (showValidationErrors) {
                          setSheetState(() => showValidationErrors = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        errorText:
                            showValidationErrors &&
                                nameController.text.trim().isEmpty
                            ? 'الاسم الكامل مطلوب'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        var domainSource = (_companyNameEn != null && _companyNameEn!.trim().isNotEmpty)
                            ? _companyNameEn!
                            : (_companyName ?? 'company');
                        var domain = domainSource
                            .trim()
                            .toLowerCase()
                            .replaceAll(RegExp(r'\s+'), '')
                            .replaceAll(RegExp(r'[^a-z0-9]'), '');
                        if (domain.isEmpty) domain = 'eltal';
                        return TextField(
                          controller: emailController,
                          onChanged: (_) {
                            if (showValidationErrors) {
                              setSheetState(() => showValidationErrors = false);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم *',
                            prefixIcon: const Icon(Icons.person_pin_outlined),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              child: Text(
                                '@$domain.com',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            border: const OutlineInputBorder(),
                            hintText: 'مثال: ahmed',
                            errorText:
                                showValidationErrors &&
                                    emailController.text.trim().isEmpty
                                ? 'اسم المستخدم مطلوب'
                                : null,
                          ),
                          keyboardType: TextInputType.text,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      onChanged: (_) {
                        if (showValidationErrors) {
                          setSheetState(() => showValidationErrors = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                        errorText:
                            showValidationErrors &&
                                phoneController.text.trim().isEmpty
                            ? 'رقم الهاتف مطلوب'
                            : null,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onChanged: (_) {
                        if (showValidationErrors) {
                          setSheetState(() => showValidationErrors = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور *',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        errorText:
                            showValidationErrors &&
                                passwordController.text.trim().isEmpty
                            ? 'كلمة المرور مطلوبة'
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setSheetState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    emailController.text.trim().isEmpty ||
                                    phoneController.text.trim().isEmpty ||
                                    passwordController.text.trim().isEmpty ||
                                    pickedImageBytes == null) {
                                  setSheetState(() {
                                    showValidationErrors = true;
                                  });
                                  showAboveSheetSnackBar(
                                    'يرجى ملء جميع الحقول المطلوبة وإرفاق صورة شخصية',
                                    backgroundColor: Colors.red,
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                final authProvider = context
                                    .read<SupabaseProvider>();
                                final navigator = Navigator.of(sheetContext);

                                var domainSource = (_companyNameEn != null && _companyNameEn!.trim().isNotEmpty)
                                    ? _companyNameEn!
                                    : (_companyName ?? 'company');
                                var domain = domainSource
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'\s+'), '')
                                    .replaceAll(RegExp(r'[^a-z0-9]'), '');
                                if (domain.isEmpty) domain = 'eltal';
                                final username = emailController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
                                final fullEmail = '$username@$domain.com';

                                final newUserId = await authProvider.addUser(
                                  fullName: nameController.text.trim(),
                                  email: fullEmail,
                                  phone: phoneController.text.trim(),
                                  password: passwordController.text.trim(),
                                  role: UserRole.captain,
                                );

                                if (!mounted) return;

                                if (newUserId != null) {
                                  if (pickedImageBytes != null) {
                                    try {
                                      final uploadedUrl =
                                          await SupabaseService.uploadAvatarBytes(
                                            imageBytes: pickedImageBytes!,
                                            fileName:
                                                pickedImage?.name ??
                                                'avatar.jpg',
                                            userId: newUserId,
                                          );

                                      if (uploadedUrl != null) {
                                        await _supabase
                                            .from('profiles')
                                            .update({'avatar_url': uploadedUrl})
                                            .eq('id', newUserId);
                                        await _supabase
                                            .from('captains')
                                            .update({
                                              'profile_image_url': uploadedUrl,
                                            })
                                            .eq('id', newUserId);
                                      }
                                    } catch (e) {
                                      AppLogger.error(
                                        'Update captain avatar error',
                                        e,
                                      );
                                      showAboveSheetSnackBar(
                                        'تم إضافة الكابتن، لكن فشل رفع الصورة',
                                      );
                                    }
                                  }

                                  navigator.pop();
                                  await _refreshAll();
                                  if (!mounted) return;
                                  showAboveSheetSnackBar(
                                    'تم إضافة الكابتن بنجاح',
                                  );
                                } else {
                                  setSheetState(() => isSubmitting = false);
                                  showAboveSheetSnackBar(
                                    authProvider.error ??
                                        'فشل في إضافة الكابتن',
                                  );
                                }
                              },
                        child: const Text('إضافة كابتن'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCaptain(CaptainModel captain) async {
    if (!_canManageCaptains || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد حذف الكابتن'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الكابتن "${_captainDisplayName(captain)}" نهائياً؟\nلن يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<SupabaseProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // التحقق من وجود طلبات نشطة للكابتن قبل الحذف
    try {
      final activeOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('captain_id', captain.id)
          .not('status', 'in', [
            OrderStatus.delivered.value,
            OrderStatus.cancelled.value,
          ]);

      if (activeOrders.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف الكابتن لوجود طلبات نشطة مسندة إليه حالياً'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      AppLogger.error('Error checking active orders before deleting captain', e);
    }

    try {
      final deleteResult = await authProvider.deleteUser(captain.id);
      if (!mounted) return;

      if (deleteResult.success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف الكابتن بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshAll();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(deleteResult.message ?? 'فشل في حذف الكابتن'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Delete captain error', e);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الحذف: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditCaptainSheet(CaptainModel captain) async {
    if (!_canManageCaptains || !mounted) return;
    final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
    if (rootOverlay == null) return;

    final initialEmail = captain.email ?? '';
    String initialUsername = initialEmail;
    if (initialEmail.contains('@')) {
      initialUsername = initialEmail.split('@').first;
    }

    final nameController = TextEditingController(
      text: captain.fullName ?? _captainDisplayName(captain),
    );
    final emailController = TextEditingController(text: initialUsername);
    final phoneController = TextEditingController(
      text: captain.contactPhone ?? captain.profilePhone ?? '',
    );
    final passwordController = TextEditingController();
    final vehicleNumberController = TextEditingController(
      text: captain.vehicleNumber ?? '',
    );
    String selectedVehicleType = captain.vehicleType.isNotEmpty
        ? captain.vehicleType
        : 'motorcycle';
    String selectedStatus = ['online', 'busy', 'offline'].contains(captain.status)
        ? captain.status
        : (captain.isOnline ? 'online' : 'offline');
    bool isActive = captain.isActive;

    final rootMessenger = ScaffoldMessenger.of(context);
    final imagePicker = ImagePicker();
    XFile? pickedImage;
    Uint8List? pickedImageBytes;
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool showValidationErrors = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          OverlayEntry? overlayEntry;

          void showAboveSheetSnackBar(
            String message, {
            Color? backgroundColor,
          }) {
            if (!mounted || !rootOverlay.mounted) return;

            overlayEntry?.remove();
            overlayEntry = OverlayEntry(
              builder: (overlayContext) => Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(overlayContext).bottom + 24,
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            rootOverlay.insert(overlayEntry!);
            Timer(const Duration(seconds: 3), () {
              overlayEntry?.remove();
              overlayEntry = null;
            });
          }

          Future<void> pickAvatarImage() async {
            try {
              final file = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1024,
              );

              if (file == null) return;

              final bytes = await file.readAsBytes();
              if (!context.mounted) return;
              setSheetState(() {
                pickedImage = file;
                pickedImageBytes = bytes;
              });
            } catch (e) {
              AppLogger.error('Pick captain avatar error', e);
              if (!context.mounted) return;
              showAboveSheetSnackBar('فشل اختيار الصورة، حاول مرة أخرى');
            }
          }

          var domainSource = (_companyNameEn != null && _companyNameEn!.trim().isNotEmpty)
              ? _companyNameEn!
              : (_companyName ?? 'company');
          var domain = domainSource
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '')
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (domain.isEmpty) domain = 'eltal';

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل بيانات الكابتن',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            backgroundImage: pickedImageBytes != null
                                ? MemoryImage(pickedImageBytes!)
                                : (captain.profileImageUrl != null &&
                                        captain.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(captain.profileImageUrl!)
                                    : null) as ImageProvider?,
                            child: pickedImageBytes == null &&
                                    (captain.profileImageUrl == null ||
                                        captain.profileImageUrl!.isEmpty)
                                ? const Icon(Icons.person_outline, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting ? null : pickAvatarImage,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                pickedImage == null
                                    ? 'تغيير صورة الكابتن'
                                    : 'تم اختيار صورة جديدة',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        errorText: showValidationErrors &&
                                nameController.text.trim().isEmpty
                            ? 'الاسم الكامل مطلوب'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم *',
                        prefixIcon: const Icon(Icons.person_pin_outlined),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Text(
                            '@$domain.com',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        border: const OutlineInputBorder(),
                        errorText: showValidationErrors &&
                                emailController.text.trim().isEmpty
                            ? 'اسم المستخدم مطلوب'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                        errorText: showValidationErrors &&
                                phoneController.text.trim().isEmpty
                            ? 'رقم الهاتف مطلوب'
                            : null,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة (اختياري)',
                        hintText: 'اتركها فارغة إذا لم ترغب بالتغيير',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setSheetState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['motorcycle', 'car', 'bicycle', 'truck'].contains(selectedVehicleType)
                          ? selectedVehicleType
                          : 'motorcycle',
                      decoration: const InputDecoration(
                        labelText: 'نوع المركبة',
                        prefixIcon: Icon(Icons.two_wheeler_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'motorcycle',
                          child: Text('دراجة نارية (موتوسيكل)'),
                        ),
                        DropdownMenuItem(
                          value: 'car',
                          child: Text('سيارة'),
                        ),
                        DropdownMenuItem(
                          value: 'bicycle',
                          child: Text('دراجة هوائية (عجلة)'),
                        ),
                        DropdownMenuItem(
                          value: 'truck',
                          child: Text('شاحنة / تروسيكل'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedVehicleType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم اللوحة / المركبة (اختياري)',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'حالة التوفر والاتصال',
                        prefixIcon: Icon(Icons.sensors_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'online',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 12),
                              SizedBox(width: 8),
                              Text('متصل ومتاح للطلبات'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'busy',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.orange, size: 12),
                              SizedBox(width: 8),
                              Text('مشغول في توصيل طلب'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'offline',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.grey, size: 12),
                              SizedBox(width: 8),
                              Text('غير متصل'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('حساب الكابتن نشط'),
                      subtitle: Text(
                        isActive ? 'الكابتن متاح لاستقبال الطلبات' : 'الكابتن موقوف مؤقتاً',
                      ),
                      value: isActive,
                      onChanged: (val) => setSheetState(() => isActive = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    emailController.text.trim().isEmpty ||
                                    phoneController.text.trim().isEmpty) {
                                  setSheetState(() {
                                    showValidationErrors = true;
                                  });
                                  showAboveSheetSnackBar(
                                    'يرجى ملء جميع الحقول الإلزامية المطلوبة',
                                    backgroundColor: Colors.red,
                                  );
                                  return;
                                }

                                if (passwordController.text.trim().isNotEmpty &&
                                    passwordController.text.trim().length < 6) {
                                  showAboveSheetSnackBar(
                                    'كلمة المرور يجب أن لا تقل عن 6 أحرف',
                                    backgroundColor: Colors.red,
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                final authProvider = context.read<SupabaseProvider>();
                                final navigator = Navigator.of(sheetContext);

                                final username = emailController.text
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'\s+'), '');
                                final fullEmail = '$username@$domain.com';

                                final updateOk = await authProvider.updateUserByAdmin(
                                  userId: captain.id,
                                  fullName: nameController.text.trim(),
                                  email: fullEmail,
                                  phone: phoneController.text.trim(),
                                  role: UserRole.captain,
                                  password: passwordController.text.trim().isNotEmpty
                                      ? passwordController.text.trim()
                                      : null,
                                );

                                if (!updateOk) {
                                  setSheetState(() => isSubmitting = false);
                                  showAboveSheetSnackBar(
                                    authProvider.error ?? 'فشل في تحديث بيانات الكابتن',
                                    backgroundColor: Colors.red,
                                  );
                                  return;
                                }

                                String? newImageUrl;
                                if (pickedImageBytes != null) {
                                  try {
                                    newImageUrl = await SupabaseService.uploadAvatarBytes(
                                      imageBytes: pickedImageBytes!,
                                      fileName: pickedImage?.name ?? 'avatar.jpg',
                                      userId: captain.id,
                                    );

                                    if (newImageUrl != null) {
                                      await _supabase
                                          .from('profiles')
                                          .update({'avatar_url': newImageUrl})
                                          .eq('id', captain.id);
                                    }
                                  } catch (e) {
                                    AppLogger.error('Update avatar error', e);
                                  }
                                }

                                try {
                                  await CaptainService.updateCaptain(
                                    captainId: captain.id,
                                    vehicleType: selectedVehicleType,
                                    vehicleNumber: vehicleNumberController.text.trim().isNotEmpty
                                        ? vehicleNumberController.text.trim()
                                        : null,
                                    contactPhone: phoneController.text.trim(),
                                    isActive: isActive,
                                    profileImageUrl: newImageUrl ?? captain.profileImageUrl,
                                  );

                                  // تحديث حالة الاتصال والتوفر
                                  await SupabaseService.updateCaptainStatus(
                                    captain.id,
                                    selectedStatus,
                                  );
                                } catch (e) {
                                  AppLogger.error('Update captain details error', e);
                                }

                                navigator.pop();
                                await _refreshAll();
                                rootMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ تم تحديث بيانات الكابتن بنجاح'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                        child: const Text('حفظ التعديلات'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeliveryNotificationsBottomSheetContent extends StatefulWidget {
  final String? targetRole;
  final ScrollController scrollController;

  const _DeliveryNotificationsBottomSheetContent({
    this.targetRole,
    required this.scrollController,
  });

  @override
  State<_DeliveryNotificationsBottomSheetContent> createState() => _DeliveryNotificationsBottomSheetContentState();
}

class _DeliveryNotificationsBottomSheetContentState extends State<_DeliveryNotificationsBottomSheetContent> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _confirmDeleteSelected(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإشهارات المحددة'),
        content: Text('هل أنت متأكد من حذف ${_selectedIds.length} إشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = _selectedIds.toList();
              setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              });
              await provider.deleteNotifications(idsToDelete);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الإشعارات المحددة'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

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
      widget.targetRole,
    );

    if (notificationProvider.error != null) {
      return _buildError(context, notificationProvider, userId);
    }

    if (notifications.isEmpty) {
      return _buildEmpty(context);
    }

    return Column(
      children: [
        if (_isSelectionMode)
          Container(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'تم تحديد ${_selectedIds.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'تحديد الكل',
                  onPressed: () {
                    setState(() {
                      _selectedIds.addAll(notifications.map((n) => n.id));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.mark_email_read),
                  tooltip: 'تحديد كمقروء',
                  onPressed: () async {
                    for (final id in _selectedIds) {
                      await notificationProvider.markAsRead(id);
                    }
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديد الإشعارات كمقروءة'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'حذف المحدد',
                  onPressed: () {
                    _confirmDeleteSelected(context, notificationProvider);
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
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
          ),
        ),
      ],
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
                targetRole: widget.targetRole ?? 'captain',
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
      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
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
          leading: _isSelectionMode
              ? Checkbox(
                  value: _selectedIds.contains(notification.id),
                  onChanged: (val) {
                    _toggleSelection(notification.id);
                  },
                )
              : _getNotificationIcon(
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
            if (_isSelectionMode) {
              _toggleSelection(notification.id);
            } else {
              if (!notification.isRead) provider.markAsRead(notification.id);
              Navigator.pop(context);
              final data = Map<String, dynamic>.from(notification.data ?? {});
              data.putIfAbsent('target_role', () => notification.targetRole);
              if (!data.containsKey('type') && notification.type != null) {
                data['type'] = notification.type!.value;
              }
              NotificationServiceEnhanced.instance.handleNotificationAction(data);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(notification.id);
              });
            }
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

class OrderGroupRepresentation {
  final List<OrderModel> orders;

  OrderGroupRepresentation(this.orders);

  String get id => (orders.first.orderGroupId != null && orders.first.orderGroupId!.isNotEmpty)
      ? orders.first.orderGroupId!
      : orders.first.id;

  String? get orderGroupId => orders.first.orderGroupId;

  String? get captainId => orders.first.captainId;

  DateTime get createdAt => orders.first.createdAt;

  String get deliveryAddress => orders.first.deliveryAddress;

  String? get deliveryNotes => orders.first.deliveryNotes;

  OrderStatus get status {
    if (orders.isEmpty) return OrderStatus.pending;
    if (orders.every((o) => o.status == OrderStatus.delivered)) {
      return OrderStatus.delivered;
    }
    if (orders.every((o) => o.status == OrderStatus.cancelled)) {
      return OrderStatus.cancelled;
    }
    if (orders.any((o) => o.status == OrderStatus.inTransit || o.status == OrderStatus.pickedUp)) {
      return OrderStatus.inTransit;
    }
    if (orders.any((o) => o.status == OrderStatus.preparing || o.status == OrderStatus.confirmed || o.status == OrderStatus.pending)) {
      if (orders.any((o) => o.status == OrderStatus.preparing)) return OrderStatus.preparing;
      if (orders.any((o) => o.status == OrderStatus.confirmed)) return OrderStatus.confirmed;
      return OrderStatus.pending;
    }
    return OrderStatus.ready;
  }

  double get totalAmount {
    return orders.fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  double get deliveryFee {
    return orders.fold(0.0, (sum, o) => sum + o.deliveryFee);
  }

  String get storeNames {
    return orders.map((o) => o.storeName ?? 'المتجر').join(' ، ');
  }

  String get storeCategories {
    return orders
        .map((o) => o.storeCategory?.trim() ?? '')
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .join(' ، ');
  }

  String get storeAddresses {
    return orders
        .map((o) => o.storeAddress?.trim() ?? '')
        .where((addr) => addr.isNotEmpty)
        .join(' | ');
  }

  String get displayOrderNumbers {
    return orders
        .map((o) => '#${o.orderNumber ?? o.id.substring(0, 8).toUpperCase()}')
        .join(' | ');
  }
}
