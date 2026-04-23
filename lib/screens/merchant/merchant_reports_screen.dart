import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/review_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/widgets/rating_star.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantReportsScreen extends StatefulWidget {
  const MerchantReportsScreen({super.key});

  @override
  State<MerchantReportsScreen> createState() => _MerchantReportsScreenState();
}

class _MerchantReportsScreenState extends State<MerchantReportsScreen> {
  String _timeFilter = 'month'; // 'today', 'week', 'month', 'all'
  Future<List<ReviewModel>>? _storeReviewsFuture;
  String? _storeId;

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredOrders = _filterOrdersByTime(orderProvider.orders);
    final stats = _calculateStats(filteredOrders);

    return ResponsiveCenter(
      maxWidth: 900,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TabBar(
                labelColor: colorScheme.primary,
                indicatorColor: colorScheme.primary,
                tabs: const [
                  Tab(text: 'التقارير'),
                  Tab(text: 'التقييمات'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSalesTab(filteredOrders, stats, colorScheme, textTheme),
                  _buildReviewsTab(colorScheme, textTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshReviews();
    });
  }

  Future<void> _refreshReviews() async {
    setState(() {
      _storeReviewsFuture = _fetchStoreReviews();
    });
    await _storeReviewsFuture;
  }

  Future<String?> _getStoreId() async {
    if (_storeId != null) return _storeId;

    final merchantProvider = Provider.of<MerchantProvider>(
      context,
      listen: false,
    );
    final merchant = merchantProvider.selectedMerchant;
    if (merchant == null) return null;

    final storeResponse = await Supabase.instance.client
        .from('stores')
        .select('id')
        .eq('merchant_id', merchant.id)
        .maybeSingle();

    _storeId = storeResponse?['id'] as String?;
    return _storeId;
  }

  Future<List<ReviewModel>> _fetchStoreReviews() async {
    final storeId = await _getStoreId();
    if (storeId == null) return [];

    try {
      // Fetch all product reviews for products belonging to this store
      final response = await Supabase.instance.client
          .from('reviews')
          .select('''
            *,
            profiles(full_name, avatar_url),
            products!inner(name, store_id)
          ''')
          .eq('products.store_id', storeId)
          .not('product_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List)
          .map((reviewData) => ReviewModel.fromMap(reviewData))
          .toList();
    } catch (e) {
      debugPrint('Error fetching store reviews: $e');
      return [];
    }
  }

  Widget _buildSalesTab(
    List<OrderModel> filteredOrders,
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeFilter(colorScheme),
          const SizedBox(height: 24),
          _buildSummaryCards(stats, colorScheme, textTheme),
          const SizedBox(height: 32),
          _buildSalesChart(filteredOrders, colorScheme, textTheme),
          const SizedBox(height: 32),
          _buildTopProducts(filteredOrders, colorScheme, textTheme),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _refreshReviews,
      child: FutureBuilder<List<ReviewModel>>(
        future: _storeReviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'حدث خطأ أثناء تحميل التقييمات',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            );
          }

          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('لا توجد تقييمات بعد')),
              ],
            );
          }

          final averageRating =
              reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
          final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
          for (final r in reviews) {
            distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RatingSummary(
                averageRating: averageRating.toDouble(),
                totalReviews: reviews.length,
                ratingDistribution: distribution,
              ),
              const SizedBox(height: 16),
              ...reviews.map(_buildReviewCard),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final date = intl.DateFormat('yyyy/MM/dd').format(review.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: review.userAvatar != null
                      ? NetworkImage(review.userAvatar!)
                      : null,
                  child: review.userAvatar == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'مستخدم',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (review.productName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          review.productName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                RatingStars(rating: review.rating.toDouble(), starSize: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment?.trim().isNotEmpty == true
                  ? review.comment!
                  : 'بدون تعليق',
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilter(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('اليوم', 'today'),
          const SizedBox(width: 8),
          _filterChip('هذا الأسبوع', 'week'),
          const SizedBox(width: 8),
          _filterChip('هذا الشهر', 'month'),
          const SizedBox(width: 8),
          _filterChip('الكل', 'all'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _timeFilter = value);
      },
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummaryCards(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي المبيعات',
                '${stats['revenue'].toStringAsFixed(2)} ج.م',
                Icons.account_balance_wallet_outlined,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'إجمالي الطلبات',
                stats['totalOrders'].toString(),
                Icons.shopping_bag_outlined,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'متوسط الطلب',
                '${stats['avgOrder'].toStringAsFixed(2)} ج.م',
                Icons.analytics_outlined,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'طلبات ملغاة',
                stats['cancelledOrders'].toString(),
                Icons.cancel_outlined,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(
    List<OrderModel> orders,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dailyData = _processChartData(orders);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مبيعات الفترة', style: textTheme.titleMedium),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: dailyData.length > 7
                          ? (dailyData.length / 4).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < dailyData.length) {
                          return Text(
                            dailyData[value.toInt()].label,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: dailyData
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                        .toList(),
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(
    List<OrderModel> orders,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final topProducts = _calculateTopProducts(orders);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأكثر مبيعاً', style: textTheme.titleMedium),
          const SizedBox(height: 16),
          if (topProducts.isEmpty)
            const Center(child: Text('لا توجد بيانات متاحة'))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topProducts.length > 5 ? 5 : topProducts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final product = topProducts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    product['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('${product['count']} طلب'),
                  trailing: Text(
                    '${product['revenue'].toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<OrderModel> _filterOrdersByTime(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((order) {
      final date = order.createdAt;
      switch (_timeFilter) {
        case 'today':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'week':
          return date.isAfter(now.subtract(const Duration(days: 7)));
        case 'month':
          return date.isAfter(now.subtract(const Duration(days: 30)));
        default:
          return true;
      }
    }).toList();
  }

  Map<String, dynamic> _calculateStats(List<OrderModel> orders) {
    double revenue = 0;
    int cancelled = 0;
    int delivered = 0;

    for (var order in orders) {
      if (order.status == OrderStatus.delivered) {
        revenue += order.totalAmount;
        delivered++;
      } else if (order.status == OrderStatus.cancelled) {
        cancelled++;
      }
    }

    return {
      'revenue': revenue,
      'totalOrders': orders.length,
      'avgOrder': delivered > 0 ? revenue / delivered : 0,
      'cancelledOrders': cancelled,
    };
  }

  List<Map<String, dynamic>> _calculateTopProducts(List<OrderModel> orders) {
    final productMap = <String, Map<String, dynamic>>{};

    for (var order in orders) {
      if (order.status == OrderStatus.delivered && order.items.isNotEmpty) {
        for (var item in order.items) {
          if (productMap.containsKey(item.productName)) {
            productMap[item.productName]!['count'] += item.quantity;
            productMap[item.productName]!['revenue'] += item.totalPrice;
          } else {
            productMap[item.productName] = {
              'name': item.productName,
              'count': item.quantity,
              'revenue': item.totalPrice,
            };
          }
        }
      }
    }

    final sortedItems = productMap.values.toList()
      ..sort((a, b) => b['count'].compareTo(a['count']));

    return sortedItems;
  }

  List<_ChartData> _processChartData(List<OrderModel> orders) {
    final Map<String, double> grouped = {};
    final dateFormat = intl.DateFormat('MM/dd');

    // Initialize with last 7 days to ensure chart is not empty
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      grouped[dateFormat.format(date)] = 0;
    }

    for (var order in orders) {
      if (order.status == OrderStatus.delivered) {
        final key = dateFormat.format(order.createdAt);
        grouped[key] = (grouped[key] ?? 0) + order.totalAmount;
      }
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys.map((k) => _ChartData(k, grouped[k]!)).toList();
  }
}

class _ChartData {
  final String label;
  final double value;
  _ChartData(this.label, this.value);
}
