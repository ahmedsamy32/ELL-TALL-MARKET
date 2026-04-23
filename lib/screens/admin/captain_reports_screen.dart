import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ell_tall_market/services/captain_reports_service.dart';
import 'package:ell_tall_market/utils/ant_design_theme.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

/// صفحة تقارير الكباتن - تعرض إحصائيات وتحليلات شاملة عن أداء الكباتن
class CaptainReportsScreen extends StatefulWidget {
  const CaptainReportsScreen({super.key});

  @override
  State<CaptainReportsScreen> createState() => _CaptainReportsScreenState();
}

class _CaptainReportsScreenState extends State<CaptainReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // البيانات
  Map<String, dynamic> _overviewStats = {};
  Map<String, dynamic> _todayActivity = {};
  List<Map<String, dynamic>> _captainsPerformance = [];
  List<Map<String, dynamic>> _topPerformers = [];

  // ترتيب الأداء
  String _sortBy = 'deliveries';
  bool _sortAscending = false;
  String _performanceSortBy = 'totalDeliveries';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        CaptainReportsService.getOverviewStats(),
        CaptainReportsService.getTodayActivity(),
        CaptainReportsService.getCaptainsPerformance(),
        CaptainReportsService.getTopPerformers(limit: 10, sortBy: _sortBy),
      ]);

      if (mounted) {
        setState(() {
          _overviewStats = results[0] as Map<String, dynamic>;
          _todayActivity = results[1] as Map<String, dynamic>;
          _captainsPerformance = results[2] as List<Map<String, dynamic>>;
          _topPerformers = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(context),
              Expanded(
                child: _isLoading
                    ? AppShimmer.list(context)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTodayActivityTab(),
                          _buildPerformanceTab(),
                          _buildLeaderboardTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // AppBar Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AntColors.primary.withValues(alpha: 0.1),
                        AntColors.primary.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assessment,
                    color: AntColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تقارير الكباتن',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AntColors.text,
                        ),
                      ),
                      Text(
                        'إحصائيات وتحليلات شاملة',
                        style: TextStyle(
                          fontSize: 12,
                          color: AntColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AntColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: AntColors.primary),
                    tooltip: 'تحديث البيانات',
                    onPressed: _loadAllData,
                  ),
                ),
              ],
            ),
          ),

          // TabBar
          // TabBar
          Container(
            decoration: BoxDecoration(
              color: AntColors.fillSecondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: AntColors.textSecondary,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AntColors.primary,
                    AntColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AntColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_rounded, size: 18),
                  text: 'ملخص عام',
                  height: 60,
                ),
                Tab(
                  icon: Icon(Icons.today_rounded, size: 18),
                  text: 'نشاط اليوم',
                  height: 60,
                ),
                Tab(
                  icon: Icon(Icons.analytics_rounded, size: 18),
                  text: 'أداء الكباتن',
                  height: 60,
                ),
                Tab(
                  icon: Icon(Icons.emoji_events_rounded, size: 18),
                  text: 'الأفضل',
                  height: 60,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== تاب الملخص العام ====================
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الإحصائيات الرئيسية
            _buildSectionTitle('إحصائيات الكباتن', Icons.people),
            const SizedBox(height: 12),
            _buildStatsGrid([
              _StatItem(
                'إجمالي الكباتن',
                '${_overviewStats['totalCaptains'] ?? 0}',
                Icons.people,
                AntColors.primary,
              ),
              _StatItem(
                'نشط',
                '${_overviewStats['activeCaptains'] ?? 0}',
                Icons.check_circle,
                AntColors.success,
              ),
              _StatItem(
                'متصل الآن',
                '${_overviewStats['onlineCaptains'] ?? 0}',
                Icons.wifi,
                const Color(0xFF13C2C2),
              ),
              _StatItem(
                'مشغول',
                '${_overviewStats['busyCaptains'] ?? 0}',
                Icons.delivery_dining,
                AntColors.warning,
              ),
              _StatItem(
                'معتمد',
                '${_overviewStats['verifiedCaptains'] ?? 0}',
                Icons.verified,
                AntColors.success,
              ),
              _StatItem(
                'قيد المراجعة',
                '${_overviewStats['pendingCaptains'] ?? 0}',
                Icons.hourglass_empty,
                AntColors.warning,
              ),
            ]),

            const SizedBox(height: 24),
            _buildSectionTitle('إحصائيات التوصيل', Icons.local_shipping),
            const SizedBox(height: 12),
            _buildStatsGrid([
              _StatItem(
                'طلبات مسلمة',
                '${_overviewStats['totalDelivered'] ?? 0}',
                Icons.check_circle_outline,
                AntColors.success,
              ),
              _StatItem(
                'طلبات ملغاة',
                '${_overviewStats['totalCancelled'] ?? 0}',
                Icons.cancel_outlined,
                AntColors.error,
              ),
              _StatItem(
                'إجمالي الأرباح',
                _formatCurrency(_overviewStats['totalEarnings'] ?? 0),
                Icons.attach_money,
                const Color(0xFF722ED1),
              ),
              _StatItem(
                'متوسط التقييم',
                '${(_overviewStats['avgRating'] ?? 0.0).toStringAsFixed(1)} ⭐',
                Icons.star,
                AntColors.warning,
              ),
            ]),

            const SizedBox(height: 24),
            _buildSectionTitle('التوزيع حسب الحالة', Icons.pie_chart),
            const SizedBox(height: 12),
            _buildStatusDistribution(),
          ],
        ),
      ),
    );
  }

  // ==================== تاب نشاط اليوم ====================
  Widget _buildTodayActivityTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // تاريخ اليوم
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AntColors.primary,
                    AntColors.primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AntColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE، d MMMM yyyy',
                            'ar',
                          ).format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تقرير نشاط اليوم',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 8,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'مباشر',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _buildStatsGrid([
              _StatItem(
                'توصيلات اليوم',
                '${_todayActivity['todayDelivered'] ?? 0}',
                Icons.local_shipping,
                AntColors.success,
              ),
              _StatItem(
                'أرباح اليوم',
                _formatCurrency(_todayActivity['todayEarnings'] ?? 0),
                Icons.payments,
                const Color(0xFF722ED1),
              ),
              _StatItem(
                'إلغاءات اليوم',
                '${_todayActivity['todayCancelled'] ?? 0}',
                Icons.cancel,
                AntColors.error,
              ),
              _StatItem(
                'متصلين الآن',
                '${_todayActivity['onlineNow'] ?? 0}',
                Icons.wifi,
                const Color(0xFF13C2C2),
              ),
            ]),

            const SizedBox(height: 24),
            _buildSectionTitle('حالة الكباتن الآن', Icons.people_alt),
            const SizedBox(height: 12),
            _buildLiveCaptainsList(),
          ],
        ),
      ),
    );
  }

  // ==================== تاب أداء الكباتن ====================
  Widget _buildPerformanceTab() {
    // ترتيب القائمة
    final sorted = List<Map<String, dynamic>>.from(_captainsPerformance);
    sorted.sort((a, b) {
      final aVal = a[_performanceSortBy] ?? 0;
      final bVal = b[_performanceSortBy] ?? 0;
      if (aVal is num && bVal is num) {
        return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      }
      return 0;
    });

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: Column(
        children: [
          // أزرار الترتيب
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'ترتيب حسب:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AntColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip('التوصيلات', 'totalDeliveries'),
                  _buildSortChip('التقييم', 'rating'),
                  _buildSortChip('الأرباح', 'totalEarnings'),
                  _buildSortChip('نسبة الإكمال', 'completionRate'),
                  _buildSortChip('سرعة التوصيل', 'avgDeliveryTime'),
                ],
              ),
            ),
          ),

          // القائمة
          Expanded(
            child: sorted.isEmpty
                ? _buildEmptyState('لا توجد بيانات أداء')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      return _buildPerformanceCard(sorted[index], index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== تاب الأفضل ====================
  Widget _buildLeaderboardTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: Column(
        children: [
          // أزرار التصنيف
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  'الترتيب حسب:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AntColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _buildLeaderboardChip('التوصيلات', 'deliveries'),
                _buildLeaderboardChip('التقييم', 'rating'),
                _buildLeaderboardChip('الأرباح', 'earnings'),
              ],
            ),
          ),

          // القائمة
          Expanded(
            child: _topPerformers.isEmpty
                ? _buildEmptyState('لا توجد بيانات')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _topPerformers.length,
                    itemBuilder: (context, index) {
                      return _buildLeaderboardCard(
                        _topPerformers[index],
                        index + 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== Widgets المساعدة ====================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AntColors.primary.withValues(alpha: 0.15),
                  AntColors.primary.withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(AntBorderRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AntColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AntColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AntColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AntColors.primary,
                        AntColors.primary.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsive(mobile: 2, tablet: 3, wide: 4),
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        item.color.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        item.color.withValues(alpha: 0.15),
                                        item.color.withValues(alpha: 0.25),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AntBorderRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: item.color,
                                    size: 20,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.trending_up_rounded,
                                    color: item.color,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: item.color,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AntColors.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusDistribution() {
    final total = (_overviewStats['totalCaptains'] as int?) ?? 0;
    if (total == 0) return _buildEmptyState('لا توجد بيانات');

    final active = (_overviewStats['activeCaptains'] as int?) ?? 0;
    final online = (_overviewStats['onlineCaptains'] as int?) ?? 0;
    final verified = (_overviewStats['verifiedCaptains'] as int?) ?? 0;
    final pending = (_overviewStats['pendingCaptains'] as int?) ?? 0;
    final inactive = total - active;

    final items = [
      _DistributionItem('نشط', active, AntColors.success),
      _DistributionItem('غير نشط', inactive, AntColors.error),
      _DistributionItem('متصل', online, const Color(0xFF13C2C2)),
      _DistributionItem('معتمد', verified, AntColors.primary),
      _DistributionItem('قيد المراجعة', pending, AntColors.warning),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        border: Border.all(color: AntColors.border),
      ),
      child: Column(
        children: [
          // شريط التوزيع
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Row(
                children: items
                    .where((item) => item.count > 0)
                    .map(
                      (item) => Expanded(
                        flex: item.count,
                        child: Container(
                          color: item.color,
                          alignment: Alignment.center,
                          child: item.count > 0
                              ? Text(
                                  '${item.count}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // التفاصيل
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: items.map((item) {
              final percentage = total > 0
                  ? (item.count / total * 100).toStringAsFixed(0)
                  : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.label}: ${item.count} ($percentage%)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AntColors.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCaptainsList() {
    // عرض حالة كل كابتن من بيانات الأداء
    if (_captainsPerformance.isEmpty) {
      return _buildEmptyState('لا يوجد كباتن');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        border: Border.all(color: AntColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _captainsPerformance.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AntColors.border),
        itemBuilder: (context, index) {
          final captain = _captainsPerformance[index];
          final isOnline = captain['isOnline'] ?? false;
          final status = captain['status'] ?? 'offline';

          Color statusColor;
          String statusText;
          IconData statusIcon;

          switch (status) {
            case 'online':
              statusColor = AntColors.success;
              statusText = 'متصل';
              statusIcon = Icons.wifi;
              break;
            case 'busy':
              statusColor = AntColors.warning;
              statusText = 'مشغول';
              statusIcon = Icons.delivery_dining;
              break;
            default:
              statusColor = AntColors.textTertiary;
              statusText = 'غير متصل';
              statusIcon = Icons.wifi_off;
          }

          if (!isOnline && status != 'busy') {
            statusColor = AntColors.textTertiary;
            statusText = 'غير متصل';
            statusIcon = Icons.wifi_off;
          }

          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AntColors.fillTertiary,
                  backgroundImage: captain['avatarUrl'] != null
                      ? NetworkImage(captain['avatarUrl'])
                      : null,
                  child: captain['avatarUrl'] == null
                      ? const Icon(Icons.person, color: AntColors.textTertiary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              captain['name'] ?? 'بدون اسم',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${_getVehicleTypeAr(captain['vehicleType'])} • ${captain['totalDeliveries']} توصيلة',
              style: const TextStyle(
                fontSize: 12,
                color: AntColors.textTertiary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _showCaptainDetails(captain),
          );
        },
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _performanceSortBy == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AntColors.primaryOutline,
        backgroundColor: AntColors.fill,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected ? AntColors.primary : AntColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected ? AntColors.primary : AntColors.border,
        ),
        onSelected: (selected) {
          setState(() {
            if (_performanceSortBy == value) {
              _sortAscending = !_sortAscending;
            } else {
              _performanceSortBy = value;
              _sortAscending = false;
            }
          });
        },
      ),
    );
  }

  Widget _buildLeaderboardChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AntColors.primaryOutline,
        backgroundColor: AntColors.fill,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected ? AntColors.primary : AntColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected ? AntColors.primary : AntColors.border,
        ),
        onSelected: (selected) async {
          setState(() => _sortBy = value);
          final top = await CaptainReportsService.getTopPerformers(
            limit: 10,
            sortBy: value,
          );
          if (mounted) {
            setState(() => _topPerformers = top);
          }
        },
      ),
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> captain, int rank) {
    final rating = (captain['rating'] as num?)?.toDouble() ?? 0.0;
    final deliveries = captain['totalDeliveries'] ?? 0;
    final cancelled = captain['cancelledOrders'] ?? 0;
    final earnings = (captain['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final avgTime = (captain['avgDeliveryTime'] as num?)?.toDouble() ?? 0.0;
    final completionRate =
        (captain['completionRate'] as num?)?.toDouble() ?? 0.0;
    final isActive = captain['isActive'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        border: Border.all(color: AntColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // الترتيب
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? _getRankColor(rank).withValues(alpha: 0.1)
                        : AntColors.fill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rank <= 3 ? _getRankColor(rank) : AntColors.border,
                    ),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: rank <= 3
                          ? _getRankColor(rank)
                          : AntColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // صورة وبيانات
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AntColors.fillTertiary,
                  backgroundImage: captain['avatarUrl'] != null
                      ? NetworkImage(captain['avatarUrl'])
                      : null,
                  child: captain['avatarUrl'] == null
                      ? const Icon(
                          Icons.person,
                          color: AntColors.textTertiary,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              captain['name'] ?? 'بدون اسم',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AntColors.success.withValues(alpha: 0.1)
                                  : AntColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isActive ? 'نشط' : 'معطل',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AntColors.success
                                    : AntColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_getVehicleTypeAr(captain['vehicleType'])} • ${_getVerificationStatusAr(captain['verificationStatus'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AntColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // إحصائيات الأداء
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildMiniStat(
                  Icons.local_shipping,
                  '$deliveries',
                  'توصيلة',
                  AntColors.primary,
                ),
                _buildMiniStatDivider(),
                _buildMiniStat(
                  Icons.cancel_outlined,
                  '$cancelled',
                  'ملغاة',
                  AntColors.error,
                ),
                _buildMiniStatDivider(),
                _buildMiniStat(
                  Icons.star,
                  rating.toStringAsFixed(1),
                  'تقييم',
                  AntColors.warning,
                ),
                _buildMiniStatDivider(),
                _buildMiniStat(
                  Icons.attach_money,
                  _formatCurrency(earnings),
                  'أرباح',
                  const Color(0xFF722ED1),
                ),
              ],
            ),
          ),

          // شريط نسبة الإكمال ووقت التوصيل
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'نسبة الإكمال',
                            style: TextStyle(
                              fontSize: 11,
                              color: AntColors.textTertiary,
                            ),
                          ),
                          Text(
                            '${completionRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: completionRate >= 80
                                  ? AntColors.success
                                  : completionRate >= 50
                                  ? AntColors.warning
                                  : AntColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completionRate / 100,
                          backgroundColor: AntColors.fill,
                          valueColor: AlwaysStoppedAnimation(
                            completionRate >= 80
                                ? AntColors.success
                                : completionRate >= 50
                                ? AntColors.warning
                                : AntColors.error,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AntColors.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 14,
                        color: AntColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        avgTime > 0
                            ? '${avgTime.toStringAsFixed(0)} دقيقة'
                            : 'لا بيانات',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AntColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(Map<String, dynamic> captain, int rank) {
    final profile = captain['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'بدون اسم';
    final avatarUrl = profile?['avatar_url'];
    final deliveries = captain['total_deliveries'] ?? 0;
    final rating = (captain['rating'] as num?)?.toDouble() ?? 0.0;
    final earnings = (captain['total_earnings'] as num?)?.toDouble() ?? 0.0;

    final isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        border: Border.all(
          color: isTopThree
              ? _getRankColor(rank).withValues(alpha: 0.3)
              : AntColors.border,
          width: isTopThree ? 2 : 1,
        ),
        boxShadow: isTopThree
            ? [
                BoxShadow(
                  color: _getRankColor(rank).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // ميدالية الترتيب
          SizedBox(
            width: 40,
            child: isTopThree
                ? Icon(Icons.emoji_events, color: _getRankColor(rank), size: 28)
                : Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AntColors.fill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AntColors.textSecondary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // الصورة
          CircleAvatar(
            radius: 22,
            backgroundColor: AntColors.fillTertiary,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(
                    Icons.person,
                    color: AntColors.textTertiary,
                    size: 22,
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // الاسم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isTopThree ? _getRankColor(rank) : AntColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getVehicleTypeAr(captain['vehicle_type']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AntColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // الإحصائيات
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$deliveries',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AntColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.local_shipping,
                    size: 14,
                    color: AntColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AntColors.warning,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.star, size: 14, color: AntColors.warning),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(earnings),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF722ED1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AntColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatDivider() {
    return Container(width: 1, height: 36, color: AntColors.border);
  }

  void _showCaptainDetails(Map<String, dynamic> captain) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CaptainDetailSheet(captain: captain),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: AntColors.textQuaternary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AntColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Helper Methods ====================

  String _formatCurrency(dynamic amount) {
    final value = (amount is num) ? amount.toDouble() : 0.0;
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // ذهبي
      case 2:
        return const Color(0xFFC0C0C0); // فضي
      case 3:
        return const Color(0xFFCD7F32); // برونزي
      default:
        return AntColors.textSecondary;
    }
  }

  String _getVehicleTypeAr(String? type) {
    switch (type?.toLowerCase()) {
      case 'motorcycle':
        return 'دراجة نارية 🏍️';
      case 'car':
        return 'سيارة 🚗';
      case 'bicycle':
        return 'دراجة هوائية 🚲';
      case 'truck':
        return 'شاحنة 🚛';
      default:
        return type ?? 'غير محدد';
    }
  }

  String _getVerificationStatusAr(String? status) {
    switch (status) {
      case 'approved':
        return 'معتمد ✅';
      case 'pending':
        return 'قيد المراجعة ⏳';
      case 'rejected':
        return 'مرفوض ❌';
      default:
        return 'غير محدد';
    }
  }
}

// ==================== بطاقة تفاصيل الكابتن ====================
class _CaptainDetailSheet extends StatelessWidget {
  final Map<String, dynamic> captain;

  const _CaptainDetailSheet({required this.captain});

  @override
  Widget build(BuildContext context) {
    final rating = (captain['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = captain['ratingCount'] ?? 0;
    final deliveries = captain['totalDeliveries'] ?? 0;
    final cancelled = captain['cancelledOrders'] ?? 0;
    final earnings = (captain['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final avgTime = (captain['avgDeliveryTime'] as num?)?.toDouble() ?? 0.0;
    final completionRate =
        (captain['completionRate'] as num?)?.toDouble() ?? 0.0;
    final isActive = captain['isActive'] ?? false;
    final isOnline = captain['isOnline'] ?? false;
    final status = captain['status'] ?? 'offline';
    final createdAt = DateTime.tryParse(captain['createdAt'] ?? '');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط السحب
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AntColors.textQuaternary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // رأس البطاقة
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AntColors.fillTertiary,
                  backgroundImage: captain['avatarUrl'] != null
                      ? NetworkImage(captain['avatarUrl'])
                      : null,
                  child: captain['avatarUrl'] == null
                      ? const Icon(
                          Icons.person,
                          color: AntColors.textTertiary,
                          size: 32,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        captain['name'] ?? 'بدون اسم',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusBadge(
                            isActive ? 'نشط' : 'معطل',
                            isActive ? AntColors.success : AntColors.error,
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(
                            isOnline
                                ? (status == 'busy' ? 'مشغول' : 'متصل')
                                : 'غير متصل',
                            isOnline
                                ? (status == 'busy'
                                      ? AntColors.warning
                                      : AntColors.success)
                                : AntColors.textTertiary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            if (captain['email'] != null && captain['email'].isNotEmpty)
              _buildInfoRow(Icons.email, captain['email']),
            if (captain['phone'] != null && captain['phone'].isNotEmpty)
              _buildInfoRow(Icons.phone, captain['phone']),
            if (createdAt != null)
              _buildInfoRow(
                Icons.calendar_today,
                'انضم في ${DateFormat('d MMM yyyy', 'ar').format(createdAt)}',
              ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // الإحصائيات التفصيلية
            const Text(
              'إحصائيات الأداء',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            _buildDetailRow(
              'إجمالي التوصيلات',
              '$deliveries',
              AntColors.primary,
            ),
            _buildDetailRow('الطلبات الملغاة', '$cancelled', AntColors.error),
            _buildDetailRow(
              'نسبة الإكمال',
              '${completionRate.toStringAsFixed(1)}%',
              completionRate >= 80
                  ? AntColors.success
                  : completionRate >= 50
                  ? AntColors.warning
                  : AntColors.error,
            ),
            _buildDetailRow(
              'متوسط وقت التوصيل',
              avgTime > 0 ? '${avgTime.toStringAsFixed(0)} دقيقة' : 'لا بيانات',
              AntColors.textSecondary,
            ),
            _buildDetailRow(
              'التقييم',
              '${rating.toStringAsFixed(1)} ⭐ ($ratingCount تقييم)',
              AntColors.warning,
            ),
            _buildDetailRow(
              'إجمالي الأرباح',
              '${earnings.toStringAsFixed(2)} ر.س',
              const Color(0xFF722ED1),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AntColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AntColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AntColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Data Classes ====================
class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _DistributionItem {
  final String label;
  final int count;
  final Color color;

  const _DistributionItem(this.label, this.count, this.color);
}
