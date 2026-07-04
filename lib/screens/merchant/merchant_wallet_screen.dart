import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/models/financial_model.dart';
import 'package:ell_tall_market/models/store_model.dart' hide BaseModelMixin;
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/services/store_wallet_service.dart';
import 'package:ell_tall_market/services/permission_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantWalletScreen extends StatefulWidget {
  const MerchantWalletScreen({super.key});

  @override
  State<MerchantWalletScreen> createState() => _MerchantWalletScreenState();
}

class _MerchantWalletScreenState extends State<MerchantWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isLoadingData = false;
  String? _errorMessage;
  double _currentBalance = 0;
  List<FinancialTransactionModel> _transactions = [];
  List<FinancialTransactionModel> _filteredTransactions = [];
  final Map<String, String> _transactionTypeCodes = {};
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';
  final List<FlSpot> _transactionTrend = [];
  late AppSettingsProvider _settingsProvider;
  Map<String, double> _summary = {
    'total_deposited': 0,
    'total_commission': 0,
    'total_adjustments': 0,
    'net_amount': 0,
  };
  String? _currentStoreId;
  List<StoreModel> _merchantStores = [];
  StoreModel? _selectedStore;
  bool _isSubmittingTopup = false;

  // Subscription state variables
  String _currentPackageName = 'بدون باقة نشطة';
  int _remainingOrders = 0;
  String _packageExpiryDate = '';
  bool _isSubmittingSubscription = false;
  int? _currentTierId;
  int _includedOrders = 0;
  int _remainingDays = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _settingsProvider = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoadingData) return;
    _isLoadingData = true;
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

      final stores = await StoreService.getMerchantStores(merchant.id);
      if (stores.isEmpty) {
        throw Exception('لا توجد متاجر مرتبطة بهذا التاجر');
      }

      final selectedStore = _selectedStore == null
          ? stores.first
          : stores.firstWhere(
              (store) => store.id == _selectedStore!.id,
              orElse: () => stores.first,
            );

      _currentStoreId = selectedStore.id;

      final wallet = await StoreWalletService.getOrCreateWallet(
        _currentStoreId!,
      );

      final currentBalance = (wallet?['balance'] as num?)?.toDouble() ?? 0.0;

      // Fetch merchant subscription details
      String packageName = 'بدون باقة نشطة';
      int remainingOrders = 0;
      String expiryDateStr = '';
      int? currentTierId;
      int includedOrders = 0;
      int remainingDays = 0;

      try {
        final merchantSubData = await Supabase.instance.client
            .from('merchants')
            .select('current_tier_id, remaining_orders, package_expiry_date, subscription_tiers(name, included_orders)')
            .eq('id', merchant.id)
            .maybeSingle();

        if (merchantSubData != null) {
          currentTierId = merchantSubData['current_tier_id'] as int?;
          remainingOrders = merchantSubData['remaining_orders'] as int? ?? 0;
          final expiryDateRaw = merchantSubData['package_expiry_date'];
          if (expiryDateRaw != null) {
            final parsedDate = DateTime.tryParse(expiryDateRaw.toString());
            if (parsedDate != null) {
              expiryDateStr = intl.DateFormat('yyyy/MM/dd').format(parsedDate);
              remainingDays = parsedDate.difference(DateTime.now()).inDays;
              if (remainingDays < 0) remainingDays = 0;
            }
          }
          final dynamic tierData = merchantSubData['subscription_tiers'];
          if (tierData is Map) {
            packageName = tierData['name']?.toString() ?? 'بدون باقة نشطة';
            includedOrders = tierData['included_orders'] as int? ?? 0;
          } else if (tierData is List && tierData.isNotEmpty) {
            final first = tierData.first;
            if (first is Map) {
              packageName = first['name']?.toString() ?? 'بدون باقة نشطة';
              includedOrders = first['included_orders'] as int? ?? 0;
            }
          }
        }
      } catch (e) {
        // Log error silently
      }

      final transactionRows = await StoreWalletService.getTransactions(
        _currentStoreId!,
      );

      _transactionTypeCodes.clear();
      final transactions = <FinancialTransactionModel>[];

      for (final row in transactionRows) {
        final typeCode = (row['type'] as String?)?.trim() ?? 'commission';
        if (typeCode == 'commission') {
          continue;
        }

        final id = (row['id'] ?? '').toString();
        final createdAt = BaseModelMixin.parseDateTime(row['created_at']);
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final balanceBefore = (row['balance_before'] as num?)?.toDouble();
        final balanceAfter = (row['balance_after'] as num?)?.toDouble();
        final isAdjustment = typeCode == 'adjustment';
        final isDebitAdjustment =
            isAdjustment &&
            balanceBefore != null &&
            balanceAfter != null &&
            balanceAfter < balanceBefore;
        final type = isAdjustment
            ? (isDebitAdjustment
                  ? TransactionType.withdrawal
                  : TransactionType.deposit)
            : TransactionTypeExtension.fromCode(typeCode);

        _transactionTypeCodes[id] = typeCode;

        transactions.add(
          FinancialTransactionModel(
            id: id,
            orderId: (row['order_id'] ?? '').toString(),
            storeId: _currentStoreId!,
            type: type,
            amount: amount,
            notes: row['notes'] as String?,
            status: TransactionStatus.completed,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
      }

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latestTransactions = transactions.take(15).toList();

      if (_selectedTypeFilter == 'commission') {
        _selectedTypeFilter = 'all';
      }

      double totalDeposited = 0;
      double totalAdjustments = 0;

      for (final transaction in latestTransactions) {
        final typeCode = _getTransactionTypeCode(transaction);
        if (typeCode == 'deposit') {
          totalDeposited += transaction.amount.abs();
        } else if (typeCode == 'adjustment') {
          totalAdjustments += transaction.amount.abs();
        }
      }

      final summary = <String, double>{
        'total_deposited': totalDeposited,
        'total_commission': 0.0,
        'total_adjustments': totalAdjustments,
        'net_amount': currentBalance,
      };

      final filteredTransactions = _filterByStatus(latestTransactions);

      if (!mounted) return;
      setState(() {
        _currentBalance = currentBalance;
        _currentPackageName = packageName;
        _remainingOrders = remainingOrders;
        _packageExpiryDate = expiryDateStr;
        _currentTierId = currentTierId;
        _includedOrders = includedOrders;
        _remainingDays = remainingDays;
        _transactions = latestTransactions;
        _summary = summary;
        _filteredTransactions = filteredTransactions;
        _merchantStores = stores;
        _selectedStore = selectedStore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _errorMessage = 'حدث خطأ أثناء تحميل بيانات المحفظة. حاول لاحقاً.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ في تحميل البيانات')));
      setState(() => _isLoading = false);
    } finally {
      _isLoadingData = false;
    }
  }

  List<FinancialTransactionModel> _filterByStatus(
    List<FinancialTransactionModel> transactions,
  ) {
    var visibleTransactions = List<FinancialTransactionModel>.from(
      transactions,
    );

    if (_selectedTypeFilter != 'all') {
      visibleTransactions = visibleTransactions
          .where(
            (transaction) =>
                _getTransactionTypeCode(transaction) == _selectedTypeFilter,
          )
          .toList();
    }

    if (_selectedStatusFilter == 'all') {
      return visibleTransactions;
    }

    return visibleTransactions
        .where(
          (transaction) => transaction.status.code == _selectedStatusFilter,
        )
        .toList();
  }

  String _getTransactionTypeCode(FinancialTransactionModel transaction) {
    return _transactionTypeCodes[transaction.id] ?? transaction.type.code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المعاملات'),
            Tab(text: 'التحليلات'),
            Tab(text: 'الرسوم البيانية'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 800,
          child: _isLoading
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
        ),
      ),
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
    return AppShimmer.wrap(
      context,
      child: AppShimmer.box(
        context,
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildStoreSelector() {
    if (_merchantStores.length <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DropdownButtonFormField<StoreModel>(
        key: ValueKey(_selectedStore?.id ?? 'none'),
        initialValue: _selectedStore,
        decoration: const InputDecoration(
          labelText: 'اختر المتجر',
          border: OutlineInputBorder(),
        ),
        items: _merchantStores
            .map(
              (store) =>
                  DropdownMenuItem(value: store, child: Text(store.name)),
            )
            .toList(),
        onChanged: (store) {
          if (store == null || store.id == _selectedStore?.id) return;
          setState(() {
            _selectedStore = store;
            _currentStoreId = store.id;
          });
          _loadData();
        },
      ),
    );
  }

  Widget _buildRedesignedMainCard() {
    // Determine package name label in Arabic
    String packageLabel = _currentPackageName;
    if (_currentPackageName == 'Basic') {
      packageLabel = 'الباقة الأساسية';
    } else if (_currentPackageName == 'Pro') {
      packageLabel = 'باقة النمو (Pro)';
    } else if (_currentPackageName == 'Unlimited') {
      packageLabel = 'الباقة غير المحدودة (Unlimited)';
    }

    final isUnlimited = _includedOrders == -1 || 
                       _currentPackageName.toLowerCase().contains('unlimited') || 
                       _currentPackageName.contains('غير محدود');

    // Calculate consumption progress
    double progress = 0.0;
    int spentOrders = 0;
    if (!isUnlimited && _includedOrders > 0) {
      spentOrders = _includedOrders - _remainingOrders;
      if (spentOrders < 0) spentOrders = 0;
      progress = spentOrders / _includedOrders;
      if (progress > 1.0) progress = 1.0;
    }

    // Textual progress bar representation [████████░░░░]
    String textProgressBar = '';
    if (!isUnlimited && _includedOrders > 0) {
      final int totalBlocks = 12;
      final int filledBlocks = (progress * totalBlocks).round();
      final int emptyBlocks = totalBlocks - filledBlocks;
      textProgressBar = '[${'█' * filledBlocks}${'░' * emptyBlocks}]';
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & logo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedStore != null ? '${_selectedStore!.name} - سوق التل' : 'محفظة متجرك - سوق التل',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.account_balance_wallet, color: Colors.white),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            
            // Balance
            const Text(
              'الرصيد المتاح:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentBalance.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Subscription details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$packageLabel - نشطة ⚡',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isUnlimited) ...[
                    const Text(
                      'استهلاك الأوردرات: غير محدود ⚡',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ] else if (_includedOrders > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'استهلاك الأوردرات:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '$spentOrders / $_includedOrders أوردر',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Graphical progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Text progress bar [████████░░░░]
                    Text(
                      textProgressBar,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'لا يوجد باقة نشطة حالياً',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  if (_packageExpiryDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ينتهي الاشتراك في: $_packageExpiryDate (باقي $_remainingDays يوم)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أزرار التحكم السريع (Quick Actions)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmittingTopup ? null : _showTopupDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('➕ شحن بإنستا باي', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingSubscription ? null : _showSubscriptionSelectionDialog,
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('🔄 ترقية/تجديد الباقة', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsights() {
    String insightText = '💡 اشترك في إحدى باقات سوق التل الذكية للحصول على عدد طلبات مجاني وتوفير رسوم التشغيل.';
    
    if (_currentTierId == 1) {
      insightText = '💡 مبيعاتك ممتازة! لو رقيت لباقة النمو (Pro) هتوفر في رسوم الأوردرات الإضافية بناءً على معدل مبيعاتك الحالي.';
    } else if (_currentTierId == 2) {
      insightText = '💡 مبيعاتك ممتازة! لو رقيت للباقة غير المحدودة (Unlimited) هتوفر حوالي 45 جنيه بناءً على معدل أوردراتك الحالي.';
    } else if (_currentTierId == 3) {
      insightText = '💡 أنت مشترك في الباقة غير المحدودة! مبيعاتك في نمو مستمر وتوفر 100% من رسوم الأوردرات الإضافية.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              const Text(
                'قسم التنبيهات الذكية (Smart Insights)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insightText,
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '🕒 أحدث الحركات:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        _buildStatusFilter(),
        if (_filteredTransactions.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text('لا توجد معاملات حديثة'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredTransactions.length,
            itemBuilder: (context, index) {
              final t = _filteredTransactions[index];
              return _buildRedesignedTransactionCard(t);
            },
          ),
      ],
    );
  }

  Widget _buildRedesignedTransactionCard(FinancialTransactionModel transaction) {
    final rawAmount = transaction.amount;
    final isNegativeAmount = rawAmount < 0;
    
    // Determine sign and direction icon
    String directionIcon = '⬆️';
    String amountPrefix = '+';
    Color amountColor = Colors.green;
    
    final typeCode = _getTransactionTypeCode(transaction);
    if (typeCode == 'deposit') {
      directionIcon = '⬆️';
      amountPrefix = '+';
      amountColor = Colors.green;
    } else {
      directionIcon = '⬇️';
      amountPrefix = '-';
      amountColor = Colors.red;
    }
    
    if (isNegativeAmount) {
      amountPrefix = '-';
      amountColor = Colors.red;
    }

    final dateText = intl.DateFormat('MM/dd').format(transaction.createdAt);
    
    // Clean up description based on transaction title and orderId
    String titleText = _getTransactionTitle(transaction);
    if (transaction.orderId.isNotEmpty) {
      titleText = 'رسوم أوردر إضافي (#${transaction.orderId})';
    } else if (transaction.notes != null && transaction.notes!.contains('تجديد')) {
      titleText = transaction.notes!;
    } else if (typeCode == 'deposit') {
      titleText = 'شحن محفظة (إنستا باي)';
    }

    final amountText = '$amountPrefix${_settingsProvider.formatCurrency(rawAmount.abs())}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Text(directionIcon, style: const TextStyle(fontSize: 18)),
        title: Text(
          titleText,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($dateText)',
              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubscriptionSelectionDialog() async {
    final merchantProvider = Provider.of<MerchantProvider>(context, listen: false);
    final merchant = merchantProvider.selectedMerchant;
    if (merchant == null) return;

    final List<Map<String, dynamic>> tiers = [
      {
        'id': 1,
        'name': 'الباقة الأساسية',
        'price': '150 جنيه',
        'details': '30 طلب / شهر',
      },
      {
        'id': 2,
        'name': 'الباقة الاحترافية',
        'price': '450 جنيه',
        'details': '100 طلب / شهر',
      },
      {
        'id': 3,
        'name': 'الباقة غير المحدودة',
        'price': '900 جنيه',
        'details': 'طلبات غير محدودة / شهر',
      },
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetStateContext, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull handler
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'اختر الباقة المناسبة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tiers.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (itemContext, index) {
                        final tier = tiers[index];
                        final tierId = tier['id'] as int;
                        final tierName = tier['name'] as String;
                        final tierPrice = tier['price'] as String;
                        final tierDetails = tier['details'] as String;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tierName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$tierDetails - السعر: $tierPrice',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(itemContext).hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isSubmittingSubscription
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          _isSubmittingSubscription = true;
                                        });
                                        setState(() {
                                          _isSubmittingSubscription = true;
                                        });

                                        try {
                                          await Supabase.instance.client.rpc(
                                            'activate_merchant_subscription',
                                            params: {
                                              'p_merchant_id': merchant.id,
                                              'p_tier_id': tierId,
                                            },
                                          );

                                          if (!mounted) return;
                                          if (sheetContext.mounted) {
                                            Navigator.pop(sheetContext);
                                          }

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('تم تفعيل $tierName بنجاح'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );

                                          _loadData();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('فشل تفعيل الباقة: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isSubmittingSubscription = false;
                                            });
                                          }
                                        }
                                      },
                                child: const Text('تفعيل'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('إلغاء'),
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

  Future<void> _showTopupDialog() async {
    if (_currentStoreId == null) return;

    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    _ReceiptImage? receiptImage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetStateContext, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  MediaQuery.of(sheetStateContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pull handler
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'طلب شحن المحفظة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'مبلغ الشحن',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'مرجع إنستا باي (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickReceiptImage();
                          if (picked == null) return;
                          setDialogState(() {
                            receiptImage = picked;
                          });
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('إرفاق صورة الإيصال'),
                      ),
                      if (receiptImage != null) ...[
                        const SizedBox(height: 8),
                        Text('تم اختيار: ${receiptImage!.fileName}'),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmittingTopup
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final amount = double.tryParse(
                                        amountController.text.trim(),
                                      );
                                      if (amount == null || amount <= 0) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('يرجى إدخال مبلغ صحيح'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      if (receiptImage == null) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('يرجى إرفاق صورة الإيصال'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => _isSubmittingTopup = true);

                                      try {
                                        final receiptPath =
                                            await StoreWalletService.uploadTopupReceipt(
                                              storeId: _currentStoreId!,
                                              bytes: receiptImage!.bytes,
                                              fileName: receiptImage!.fileName,
                                            );

                                        if (receiptPath == null) {
                                          throw Exception('فشل رفع الإيصال');
                                        }

                                        final submitted =
                                            await StoreWalletService.submitTopupRequest(
                                              storeId: _currentStoreId!,
                                              amount: amount,
                                              receiptPath: receiptPath,
                                              instapayReference:
                                                  referenceController.text.trim().isEmpty
                                                  ? null
                                                  : referenceController.text.trim(),
                                              notes: notesController.text.trim().isEmpty
                                                  ? null
                                                  : notesController.text.trim(),
                                            );

                                        if (!submitted) {
                                          throw Exception('فشل إرسال طلب الشحن');
                                        }

                                        if (!mounted) return;
                                        if (!sheetContext.mounted) return;
                                        Navigator.pop(sheetContext);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('تم إرسال طلب الشحن بنجاح'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadData();
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('خطأ أثناء إرسال الطلب: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmittingTopup = false);
                                        }
                                      }
                                    },
                              child: const Text('إرسال'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
  }

  Future<_ReceiptImage?> _pickReceiptImage() async {
    final permissionService = PermissionService();
    final permissionResult = await permissionService.requestGalleryPermission();

    if (!permissionResult.granted) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(permissionResult.message ?? 'تم رفض إذن الوصول للصور'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final fileName = file.path.replaceAll('\\', '/').split('/').last;
    return _ReceiptImage(bytes, fileName);
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildStoreSelector(),
          _buildBalanceWarning(),
          _buildRedesignedMainCard(),
          _buildQuickActions(),
          _buildSmartInsights(),
          _buildTransactionsSection(),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatusFilter,
              decoration: const InputDecoration(
                labelText: 'حالة المعاملة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل')),
                DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                DropdownMenuItem(value: 'pending', child: Text('قيد التنفيذ')),
                DropdownMenuItem(value: 'failed', child: Text('فشل')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedStatusFilter = value;
                  _filteredTransactions = _filterByStatus(_transactions);
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTypeFilter,
              decoration: const InputDecoration(
                labelText: 'نوع المعاملة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل')),
                DropdownMenuItem(value: 'deposit', child: Text('إضافة رصيد')),
                DropdownMenuItem(value: 'adjustment', child: Text('خصم رصيد')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedTypeFilter = value;
                  _filteredTransactions = _filterByStatus(_transactions);
                });
              },
            ),
          ),
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
            _buildStoreSelector(),
            _buildBalanceWarning(),
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
            _buildStoreSelector(),
            _buildBalanceWarning(),
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



  Widget _buildBalanceWarning() {
    if (_currentBalance >= 0) {
      return const SizedBox.shrink();
    }

    final isCritical = _currentBalance <= -8;
    final warningColor = isCritical ? Colors.red : Colors.orange;
    final bgColor = warningColor.withValues(alpha: 0.12);
    final title = isCritical ? 'تحذير هام' : 'تنبيه رصيد';
    final message = isCritical
        ? 'رصيد المحفظة يقترب من -10. إذا وصل إلى -10 سيتم إغلاق المتجر تلقائياً ولن يفتح إلا بعد شحن الرصيد.'
        : 'رصيد المحفظة سالب الآن. يرجى الشحن لتجنب إغلاق المتجر تلقائياً عند -10.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warningColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_rounded, color: warningColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الرصيد الحالي: ${_settingsProvider.formatCurrency(_currentBalance)}',
                  style: TextStyle(
                    color: warningColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                'إجمالي الشحن',
                _summary['total_deposited']!,
                Icons.arrow_upward,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildSummaryCard(
                'التسويات',
                _summary['total_adjustments']!,
                Icons.tune,
                Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _buildSummaryCard(
            'الرصيد المتاح',
            _summary['net_amount']!,
            Icons.account_balance_wallet,
            Theme.of(context).primaryColor,
          ),
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
      ChartData('شحن', _summary['total_deposited']!, Colors.green),
      ChartData('تسويات', _summary['total_adjustments']!, Colors.orange),
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
    final Map<String, double> distribution = {'deposit': 0, 'adjustment': 0};
    double total = 0;

    for (var transaction in _transactions) {
      final typeCode = _getTransactionTypeCode(transaction);
      if (typeCode != 'deposit' && typeCode != 'adjustment') {
        continue;
      }
      final amount = transaction.amount.abs();
      distribution[typeCode] = (distribution[typeCode] ?? 0) + amount;
      total += amount;
    }

    // Convert to sections
    return distribution.entries.map((entry) {
      final percentage = total > 0
          ? (entry.value / total * 100).toDouble()
          : 0.0;
      Color color;

      switch (entry.key) {
        case 'deposit':
          color = Colors.green;
          break;
        case 'adjustment':
          color = Colors.orange;
          break;
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
        _buildLegendItem('شحن', Colors.green),
        _buildLegendItem('تسويات', Colors.orange),
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
      final typeCode = _getTransactionTypeCode(transaction);
      if (typeCode != 'deposit' && typeCode != 'adjustment') {
        continue;
      }
      final month = transaction.createdAt.month - 1; // 0-based index
      monthlyTotals[month] =
          (monthlyTotals[month] ?? 0) + transaction.amount.abs();
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
      final typeCode = _getTransactionTypeCode(transaction);
      if (typeCode != 'deposit' && typeCode != 'adjustment') {
        continue;
      }
      final month = transaction.createdAt.month - 1;
      monthlyTotals[month] =
          (monthlyTotals[month] ?? 0) + transaction.amount.abs();
    }

    return (monthlyTotals.values.fold<double>(
              0,
              (max, value) => value > max ? value : max,
            ) *
            1.2)
        .toDouble();
  }

  String _getTransactionTitle(FinancialTransactionModel transaction) {
    final typeCode = _getTransactionTypeCode(transaction);
    switch (typeCode) {
      case 'deposit':
        return 'شحن المحفظة';
      case 'adjustment':
        return 'خصم رصيد';
      default:
        return 'معاملة مالية';
    }
  }
}

class ChartData {
  final String category;
  final double amount;
  final Color color;

  ChartData(this.category, this.amount, this.color);
}

class _ReceiptImage {
  final Uint8List bytes;
  final String fileName;

  const _ReceiptImage(this.bytes, this.fileName);
}
