import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:ell_tall_market/services/order_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  // ── Stats ──
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;
  double _avgOrderValue = 0;

  // ── Charts ──
  List<_SalesData> _salesData = [];
  List<_CategoryData> _categoryData = [];

  // ── Recent activities ──
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  // ═══════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _loadStats(),
        _loadMonthlySales(),
        _loadCategoryDistribution(),
        _loadRecentActivities(),
      ]);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    // Order analytics
    final analytics = await OrderService.getAdvancedOrderAnalytics();

    // User count (profiles table)
    final usersResp = await _supabase.from('profiles').select('id');

    if (!mounted) return;
    setState(() {
      _totalRevenue = (analytics['totalRevenue'] as num?)?.toDouble() ?? 0;
      _totalOrders = (analytics['totalOrders'] as num?)?.toInt() ?? 0;
      _avgOrderValue =
          (analytics['averageOrderValue'] as num?)?.toDouble() ?? 0;
      _totalUsers = (usersResp as List).length;
    });
  }

  Future<void> _loadMonthlySales() async {
    final now = DateTime.now();
    final start = _subtractMonths(now, 11);

    final response = await _supabase
        .from('orders')
        .select('total_amount, created_at, status')
        .gte('created_at', start.toIso8601String());

    // Group by month
    final monthlyMap = <String, double>{};
    for (final row in response as List) {
      final status = row['status'] as String? ?? '';
      if (status != 'delivered') continue;
      final date = DateTime.parse(row['created_at'] as String);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyMap[key] =
          (monthlyMap[key] ?? 0) + (row['total_amount'] as num).toDouble();
    }

    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final data = <_SalesData>[];
    for (int i = 11; i >= 0; i--) {
      final d = _subtractMonths(now, i);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      data.add(_SalesData(monthNames[d.month - 1], monthlyMap[key] ?? 0));
    }

    if (mounted) setState(() => _salesData = data);
  }

  Future<void> _loadCategoryDistribution() async {
    // Count products per category
    final productsResp = await _supabase
        .from('products')
        .select('category_id')
        .not('category_id', 'is', null);

    final countMap = <String, int>{};
    for (final p in productsResp as List) {
      final catId = p['category_id'] as String?;
      if (catId != null) countMap[catId] = (countMap[catId] ?? 0) + 1;
    }

    if (countMap.isEmpty) return;

    // Top 5 by product count
    final sorted = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    // Fetch category names
    final catIds = top5.map((e) => e.key).toList();
    final catsResp = await _supabase
        .from('categories')
        .select('id, name')
        .inFilter('id', catIds);

    final nameMap = <String, String>{};
    for (final c in catsResp as List) {
      nameMap[c['id'] as String] = c['name'] as String;
    }

    const colors = [
      Color(0xFF667eea),
      Color(0xFF43e97b),
      Color(0xFFfa709a),
      Color(0xFF30cfd0),
      Color(0xFFfee140),
    ];

    final data = <_CategoryData>[];
    for (int i = 0; i < top5.length; i++) {
      final entry = top5[i];
      data.add(
        _CategoryData(
          nameMap[entry.key] ?? 'غير معروف',
          entry.value.toDouble(),
          colors[i % colors.length],
        ),
      );
    }

    if (mounted) setState(() => _categoryData = data);
  }

  Future<void> _loadRecentActivities() async {
    final response = await _supabase
        .from('orders')
        .select('id, order_number, status, total_amount, created_at')
        .order('created_at', ascending: false)
        .limit(5);

    if (mounted) {
      setState(() {
        _recentActivities = (response as List).cast<Map<String, dynamic>>();
      });
    }
  }

  // ═══════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════

  /// Safe month subtraction — handles negative month values
  DateTime _subtractMonths(DateTime from, int months) {
    int year = from.year;
    int month = from.month - months;
    while (month <= 0) {
      month += 12;
      year--;
    }
    return DateTime(year, month, 1);
  }

  String _formatCurrency(double amount) {
    return '${NumberFormat('#,##0', 'ar').format(amount)} ج.م';
  }

  String _formatTimeAgo(String createdAt) {
    final date = DateTime.parse(createdAt);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }

  (IconData, Color) _statusIconColor(String status) {
    switch (status) {
      case 'delivered':
        return (Icons.done_all_rounded, const Color(0xFF43e97b));
      case 'cancelled':
        return (Icons.cancel_rounded, Colors.redAccent);
      case 'in_transit':
        return (Icons.local_shipping_rounded, const Color(0xFF4facfe));
      case 'preparing':
        return (Icons.restaurant_rounded, const Color(0xFF30cfd0));
      case 'confirmed':
        return (Icons.check_circle_rounded, const Color(0xFF667eea));
      case 'ready':
        return (Icons.inventory_2_rounded, Colors.green);
      default:
        return (Icons.hourglass_top_rounded, Colors.orange);
    }
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'delivered':
        return 'تم التوصيل';
      case 'cancelled':
        return 'ملغي';
      case 'in_transit':
        return 'في الطريق';
      case 'preparing':
        return 'قيد التحضير';
      case 'confirmed':
        return 'تم التأكيد';
      case 'ready':
        return 'جاهز للاستلام';
      default:
        return 'في الانتظار';
    }
  }

  // ═══════════════════════════════════════════
  //  EXPORT
  // ═══════════════════════════════════════════

  void _exportCSV() {
    final fmt = NumberFormat('#,##0.##', 'ar');
    final buffer = StringBuffer();
    buffer.writeln(
      'التحليلات - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );
    buffer.writeln('');
    buffer.writeln('الإحصائيات العامة');
    buffer.writeln('إجمالي المبيعات,${fmt.format(_totalRevenue)}');
    buffer.writeln('عدد الطلبات,$_totalOrders');
    buffer.writeln('إجمالي المستخدمين,$_totalUsers');
    buffer.writeln('متوسط الطلب,${fmt.format(_avgOrderValue)}');
    buffer.writeln('');
    buffer.writeln('المبيعات الشهرية');
    buffer.writeln('الشهر,المبيعات');
    for (final d in _salesData) {
      buffer.writeln('${d.month},${fmt.format(d.sales)}');
    }
    buffer.writeln('');
    buffer.writeln('توزيع الفئات');
    buffer.writeln('الفئة,العدد');
    for (final d in _categoryData) {
      buffer.writeln('${d.category},${d.count.toStringAsFixed(0)}');
    }

    final lines = buffer.toString().split('\n').length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تجهيز التقرير: $lines سطر'),
        backgroundColor: const Color(0xFF43e97b),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'تم',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحليلات'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير CSV',
            onPressed: _isLoading ? null : _exportCSV,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1100,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.03),
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerLowest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return AppShimmer.list(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildSalesChart(),
            const SizedBox(height: 24),
            _buildCategoryChart(),
            const SizedBox(height: 24),
            _buildRecentActivities(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Stats grid
  // ─────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final fmt = NumberFormat('#,##0', 'ar');

    final stats = [
      _QuickStat(
        'إجمالي المبيعات',
        '${fmt.format(_totalRevenue)} ج.م',
        Icons.attach_money_rounded,
        [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      ),
      _QuickStat(
        'عدد الطلبات',
        fmt.format(_totalOrders),
        Icons.shopping_cart_rounded,
        [const Color(0xFF667eea), const Color(0xFF764ba2)],
      ),
      _QuickStat(
        'إجمالي المستخدمين',
        fmt.format(_totalUsers),
        Icons.people_rounded,
        [const Color(0xFFfa709a), const Color(0xFFfee140)],
      ),
      _QuickStat(
        'متوسط الطلب',
        '${fmt.format(_avgOrderValue)} ج.م',
        Icons.trending_up_rounded,
        [const Color(0xFF30cfd0), const Color(0xFF330867)],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsive(mobile: 2, tablet: 3, wide: 4),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(opacity: value, child: child),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: stat.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: stat.gradient[0].withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stat.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Monthly sales chart
  // ─────────────────────────────────────────────
  Widget _buildSalesChart() {
    return _buildChartCard(
      title: 'المبيعات الشهرية',
      icon: Icons.show_chart_rounded,
      gradient: [const Color(0xFF667eea), const Color(0xFF764ba2)],
      child: _salesData.isEmpty || _salesData.every((d) => d.sales == 0)
          ? _buildEmptyChartState('لا توجد بيانات مبيعات حتى الآن')
          : SizedBox(
              height: 300,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  labelIntersectAction: AxisLabelIntersectAction.rotate45,
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: MajorGridLines(
                    width: 0.5,
                    color: Colors.grey.shade200,
                    dashArray: const <double>[5, 5],
                  ),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  numberFormat: NumberFormat.compact(),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x\npoint.y ج.م',
                ),
                series: <CartesianSeries>[
                  SplineAreaSeries<_SalesData, String>(
                    dataSource: _salesData,
                    xValueMapper: (d, _) => d.month,
                    yValueMapper: (d, _) => d.sales,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withValues(alpha: 0.4),
                        const Color(0xFF667eea).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderColor: const Color(0xFF667eea),
                    borderWidth: 3,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 6,
                      width: 6,
                      borderColor: Color(0xFF667eea),
                      color: Colors.white,
                      borderWidth: 2,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────
  //  Category distribution chart
  // ─────────────────────────────────────────────
  Widget _buildCategoryChart() {
    return _buildChartCard(
      title: 'توزيع المنتجات حسب الفئة',
      icon: Icons.donut_large_rounded,
      gradient: [const Color(0xFFfa709a), const Color(0xFFfee140)],
      child: _categoryData.isEmpty
          ? _buildEmptyChartState('لا توجد بيانات فئات حتى الآن')
          : SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x : point.y منتج',
                ),
                series: <CircularSeries>[
                  DoughnutSeries<_CategoryData, String>(
                    dataSource: _categoryData,
                    xValueMapper: (d, _) => d.category,
                    yValueMapper: (d, _) => d.count,
                    pointColorMapper: (d, _) => d.color,
                    innerRadius: '55%',
                    radius: '85%',
                    cornerStyle: CornerStyle.bothCurve,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      connectorLineSettings: const ConnectorLineSettings(
                        type: ConnectorType.curve,
                        length: '15%',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────
  //  Recent activities (real orders)
  // ─────────────────────────────────────────────
  Widget _buildRecentActivities() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF43e97b).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر الطلبات',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'أحدث 5 طلبات في النظام',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_recentActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'لا توجد طلبات حتى الآن',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...List.generate(
              _recentActivities.length,
              (i) => _buildActivityItem(_recentActivities[i], i),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> order, int index) {
    final status = order['status'] as String? ?? 'pending';
    final (icon, color) = _statusIconColor(status);
    final rawOrderNumber = order['order_number'];
    final fallback = (order['id'] as String).substring(0, 8).toUpperCase();
    final orderNumber = rawOrderNumber != null
        ? rawOrderNumber.toString()
        : fallback;
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = order['created_at'] as String?;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(20 * (1 - value), 0),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            'طلب #$orderNumber',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${_statusArabic(status)}  •  ${_formatCurrency(totalAmount)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              createdAt != null ? _formatTimeAgo(createdAt) : '',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Shared widgets
  // ─────────────────────────────────────────────
  Widget _buildEmptyChartState(String message) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Data models (private to this file)
// ═══════════════════════════════════════════════════════

class _SalesData {
  final String month;
  final double sales;
  const _SalesData(this.month, this.sales);
}

class _CategoryData {
  final String category;
  final double count;
  final Color color;
  const _CategoryData(this.category, this.count, this.color);
}

class _QuickStat {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  const _QuickStat(this.title, this.value, this.icon, this.gradient);
}
