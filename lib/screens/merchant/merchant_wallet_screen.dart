import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';
import 'package:ell_tall_market/models/financial_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

class MerchantWalletScreen extends StatefulWidget {
  const MerchantWalletScreen({super.key});

  @override
  State<MerchantWalletScreen> createState() => _MerchantWalletScreenState();
}

class _MerchantWalletScreenState extends State<MerchantWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  String? _errorMessage;
  double _currentBalance = 0;
  List<FinancialTransactionModel> _transactions = [];
  List<FinancialTransactionModel> _filteredTransactions = [];
  String _selectedTransactionType = 'all';
  String _selectedStatusFilter = 'all';
  final List<FlSpot> _transactionTrend = [];
  late SettingsProvider _settingsProvider;
  Map<String, double> _summary = {
    'total_collected': 0,
    'total_transferred': 0,
    'total_refunded': 0,
    'net_amount': 0,
  };
  String? _currentStoreId;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // Get current user profile
      final currentProfile = authProvider.currentUserProfile;
      if (currentProfile == null) {
        throw Exception('لم يتم العثور على بيانات المستخدم');
      }

      // Get merchant provider and fetch merchant data
      final merchantProvider = Provider.of<MerchantProvider>(
        context,
        listen: false,
      );

      // Fetch merchant by profile ID
      await merchantProvider.fetchMerchantByProfileId(currentProfile.id);
      final merchant = merchantProvider.selectedMerchant;

      if (merchant == null) {
        throw Exception('لم يتم العثور على بيانات التاجر');
      }

      // For now, we'll use the merchant ID as store identifier
      // In a complete implementation, you'd fetch the actual store
      _currentStoreId = merchant.id;

      // Calculate balance from orders instead of non-existent financial_transactions
      final ordersResponse = await _supabase
          .from('orders')
          .select('total_amount, delivery_fee, status, created_at')
          .eq('store_id', _currentStoreId!)
          .order('created_at', ascending: false);

      final ordersList = ordersResponse as List;

      // Calculate balance breakdown from orders
      double totalRevenue = 0;
      double totalDeliveryFees = 0;
      double pendingAmount = 0;
      double completedAmount = 0;

      final recentOrders = <Map<String, dynamic>>[];

      for (final order in ordersList) {
        final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
        final status = order['status'] as String?;

        // Add to recent orders (limit to 15)
        if (recentOrders.length < 15) {
          recentOrders.add({
            ...order,
            'type': 'order',
            'amount': totalAmount,
            'notes': 'طلب رقم ${order['id']?.substring(0, 8) ?? 'غير محدد'}',
          });
        }

        totalRevenue += totalAmount;
        totalDeliveryFees += deliveryFee;

        if (status == 'delivered') {
          completedAmount += totalAmount;
        } else if (status != 'cancelled') {
          pendingAmount += totalAmount;
        }
      }

      final balanceData = {
        'current_balance': completedAmount * 0.9, // Assuming 10% commission
        'total_revenue': totalRevenue,
        'total_delivery_fees': totalDeliveryFees,
        'pending_amount': pendingAmount,
        'completed_amount': completedAmount,
        'commission_rate': 0.1,
        'recent_transactions': recentOrders,
      };

      // Create mock transactions list for compatibility
      final transactions = recentOrders.map((order) {
        return FinancialTransactionModel(
          id: order['id'] ?? '',
          orderId: order['id'] ?? '',
          storeId: _currentStoreId!,
          type: TransactionType.collection,
          amount: (order['amount'] as num?)?.toDouble() ?? 0.0,
          notes: order['notes'] ?? '',
          status: TransactionStatus.completed,
          createdAt: DateTime.parse(order['created_at']),
          updatedAt: DateTime.parse(order['created_at']),
        );
      }).toList();

      // Calculate summary from balance data
      final summary = <String, double>{
        'total_collected':
            (balanceData['total_revenue'] as num?)?.toDouble() ?? 0.0,
        'total_transferred':
            (balanceData['completed_amount'] as num?)?.toDouble() ?? 0.0,
        'total_refunded': 0.0, // No refunds in current schema
        'net_amount':
            ((balanceData['total_revenue'] as num?)?.toDouble() ?? 0.0) * 0.9,
      };

      if (!mounted) return;
      setState(() {
        _currentBalance =
            (balanceData['current_balance'] as num?)?.toDouble() ?? 0.0;
        _transactions = transactions;
        _summary = summary;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _errorMessage = 'حدث خطأ أثناء تحميل بيانات المحفظة. حاول لاحقاً.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ في تحميل البيانات')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المعاملات'),
            Tab(text: 'التحليلات'),
            Tab(text: 'الرسوم البيانية'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildShimmerBody()
          : (_errorMessage != null
                ? _buildErrorState(_errorMessage!)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionsTab(),
                      _buildAnalyticsTab(),
                      _buildChartsTab(),
                    ],
                  )),
    );
  }

  Widget _buildShimmerBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildShimmerCard(height: 120),
          const SizedBox(height: 16),
          _buildShimmerCard(height: 60),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _buildShimmerCard(height: 80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard({double height = 120}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildBalanceCard(),
          _buildTransactionFilters(),
          Expanded(child: _buildFilteredTransactionsList()),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryCards(),
            SizedBox(height: 24),
            _buildTransactionsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTransactionTrendChart(),
            const SizedBox(height: 24),
            _buildTransactionDistributionPieChart(),
            const SizedBox(height: 24),
            _buildMonthlyComparisonChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الرصيد الحالي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _settingsProvider.formatCurrency(_currentBalance),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'إجمالي المحصل',
                _summary['total_collected']!,
                Icons.arrow_upward,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildSummaryCard(
                'إجمالي المحول',
                _summary['total_transferred']!,
                Icons.arrow_downward,
                Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'المبالغ المستردة',
                _summary['total_refunded']!,
                Icons.refresh,
                Colors.orange,
              ),
            ),
            Expanded(
              child: _buildSummaryCard(
                'صافي الرصيد',
                _summary['net_amount']!,
                Icons.account_balance_wallet,
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              _settingsProvider.formatCurrency(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsChart() {
    final data = [
      ChartData('محصل', _summary['total_collected']!, Colors.green),
      ChartData('محول', _summary['total_transferred']!, Colors.blue),
      ChartData('مسترد', _summary['total_refunded']!, Colors.orange),
    ];

    return SizedBox(
      height: 300,
      child: SfCircularChart(
        title: ChartTitle(text: 'توزيع المعاملات المالية'),
        legend: Legend(isVisible: true, position: LegendPosition.bottom),
        series: <CircularSeries>[
          DoughnutSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.category,
            yValueMapper: (ChartData data, _) => data.amount,
            pointColorMapper: (ChartData data, _) => data.color,
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTrendChart() {
    return SizedBox(
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اتجاه المعاملات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(show: true),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _transactionTrend,
                        isCurved: true,
                        color: Theme.of(context).primaryColor,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyComparisonChart() {
    return SizedBox(
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مقارنة شهرية للمعاملات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxMonthlyAmount(),
                    barGroups: _getMonthlyBarGroups(),
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = [
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
                            if (value >= 0 && value < months.length) {
                              return Text(
                                months[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDistributionPieChart() {
    return SizedBox(
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'توزيع أنواع المعاملات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: _getTransactionDistributionSections(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTransactionDistributionLegend(),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _getTransactionDistributionSections() {
    final Map<TransactionType, double> distribution = {};
    double total = 0;

    // Calculate distribution
    for (var transaction in _transactions) {
      distribution[transaction.type] =
          (distribution[transaction.type] ?? 0) + transaction.amount;
      total += transaction.amount;
    }

    // Convert to sections
    return distribution.entries.map((entry) {
      final percentage = total > 0
          ? (entry.value / total * 100).toDouble()
          : 0.0;
      Color color;

      switch (entry.key) {
        case TransactionType.collection:
          color = Colors.green;
          break;
        case TransactionType.transferToStore:
          color = Colors.blue;
          break;
        case TransactionType.refund:
          color = Colors.orange;
        default:
          color = Colors.grey;
          break;
      }

      return PieChartSectionData(
        color: color,
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildTransactionDistributionLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('تحصيل', Colors.green),
        _buildLegendItem('تحويل', Colors.blue),
        _buildLegendItem('استرداد', Colors.orange),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<BarChartGroupData> _getMonthlyBarGroups() {
    final Map<int, double> monthlyTotals = {};

    // Calculate monthly totals
    for (var transaction in _transactions) {
      final month = transaction.createdAt.month - 1; // 0-based index
      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + transaction.amount;
    }

    // Create bar groups
    return List.generate(12, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: monthlyTotals[index] ?? 0,
            color: Theme.of(context).primaryColor,
            width: 16,
          ),
        ],
      );
    });
  }

  double _getMaxMonthlyAmount() {
    if (_transactions.isEmpty) return 1000.0;

    final Map<int, double> monthlyTotals = {};
    for (var transaction in _transactions) {
      final month = transaction.createdAt.month - 1;
      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + transaction.amount;
    }

    return (monthlyTotals.values.fold<double>(
              0,
              (max, value) => value > max ? value : max,
            ) *
            1.2)
        .toDouble();
  }

  Widget _buildTransactionFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTransactionType,
                  decoration: const InputDecoration(
                    labelText: 'نوع المعاملة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'collection', child: Text('تحصيل')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                    DropdownMenuItem(value: 'refund', child: Text('استرداد')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTransactionType = value!;
                      _filterTransactions();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('قيد التنفيذ'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('فشل')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value!;
                      _filterTransactions();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate == null ? 'من تاريخ' : _formatDate(_startDate!),
                  ),
                  onPressed: () => _selectDate(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _endDate == null ? 'إلى تاريخ' : _formatDate(_endDate!),
                  ),
                  onPressed: () => _selectDate(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        bool matchesType =
            _selectedTransactionType == 'all' ||
            transaction.type.code == _selectedTransactionType ||
            (_selectedTransactionType == 'transfer' &&
                transaction.type == TransactionType.transferToStore);

        bool matchesStatus =
            _selectedStatusFilter == 'all' ||
            transaction.status.code == _selectedStatusFilter;

        bool matchesDateRange = true;
        if (_startDate != null && _endDate != null) {
          matchesDateRange =
              transaction.createdAt.isAfter(_startDate!) &&
              transaction.createdAt.isBefore(
                _endDate!.add(const Duration(days: 1)),
              );
        }
        return matchesType && matchesStatus && matchesDateRange;
      }).toList();
    });
  }

  Widget _buildFilteredTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: const Text('لا توجد معاملات تطابق المعايير المحددة'),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredTransactions.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(FinancialTransactionModel transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: _getTransactionIcon(transaction.type),
        title: Text(_getTransactionTitle(transaction)),
        subtitle: Text(
          '${_settingsProvider.formatCurrency(transaction.amount)} - ${_formatDate(transaction.createdAt)}',
        ),
        trailing: _buildStatusChip(transaction.status),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رقم الطلب: ${transaction.orderId}'),
                if (transaction.notes != null)
                  Text('ملاحظات: ${transaction.notes}'),
                Text('تاريخ المعاملة: ${_formatDate(transaction.createdAt)}'),
                Text('حالة المعاملة: ${_getStatusText(transaction.status)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TransactionStatus status) {
    final colors = {
      TransactionStatus.completed: Colors.green,
      TransactionStatus.pending: Colors.orange,
      TransactionStatus.failed: Colors.red,
    };

    return Chip(
      label: Text(
        _getStatusText(status),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: colors[status] ?? Colors.grey,
    );
  }

  Icon _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.collection:
        return const Icon(Icons.attach_money, color: Colors.green);
      case TransactionType.transferToStore:
        return const Icon(Icons.arrow_forward, color: Colors.blue);
      case TransactionType.refund:
        return const Icon(Icons.reply, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'مكتمل';
      case TransactionStatus.pending:
        return 'قيد التنفيذ';
      case TransactionStatus.failed:
        return 'فشل';
      default:
        return 'غير محدد';
    }
  }

  String _getTransactionTitle(FinancialTransactionModel transaction) {
    switch (transaction.type) {
      case TransactionType.collection:
        return 'تحصيل مبلغ من الطلب #${transaction.orderId}';
      case TransactionType.transferToStore:
        return 'تحويل للمتجر';
      case TransactionType.refund:
        return 'استرجاع مبلغ';
      default:
        return 'معاملة مالية';
    }
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy/MM/dd').format(date);
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _loadData();
    }
  }
}

class ChartData {
  final String category;
  final double amount;
  final Color color;

  ChartData(this.category, this.amount, this.color);
}
