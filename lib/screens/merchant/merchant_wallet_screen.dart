import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Subscription state variables
  String _currentPackageName = 'بدون باقة نشطة';
  int _remainingOrders = 0;
  String _packageExpiryDate = '';
  bool _isSubmittingSubscription = false;
  int? _currentTierId;
  int _includedOrders = 0;
  int _remainingDays = 0;
  List<Map<String, dynamic>> _subscriptionHistory = [];

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

      List<Map<String, dynamic>> subHistory = [];
      try {
        final merchantSubData = await Supabase.instance.client
            .from('merchants')
            .select(
              'current_tier_id, remaining_orders, package_expiry_date, subscription_tiers(name, included_orders)',
            )
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
          if (currentTierId == null &&
              expiryDateRaw != null &&
              remainingDays > 0) {
            packageName = 'الفترة التجريبية المجانية';
            includedOrders = -1;
            remainingOrders = -1;
          } else {
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
        }

        // Fetch subscription history
        final historyRows = await Supabase.instance.client
            .from('subscription_history')
            .select('*')
            .eq('merchant_id', merchant.id)
            .order('created_at', ascending: false);
        subHistory = List<Map<String, dynamic>>.from(historyRows);
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
        _subscriptionHistory = subHistory;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _errorMessage = 'حدث خطأ أثناء تحميل بيانات المحفظة. حاول لاحقاً.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في تحميل البيانات'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            Tab(text: 'الاشتراكات'),
            Tab(text: 'التحليلات'),
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
                          _buildSubscriptionsTab(),
                          _buildAnalyticsTab(),
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

    final isUnlimited =
        _includedOrders == -1 ||
        _currentPackageName.toLowerCase().contains('unlimited') ||
        _currentPackageName.contains('غير محدود') ||
        _currentPackageName.contains('مجانية');

    final totalLimit =
        _includedOrders + _currentRolledOverOrders + _currentCompensatedOrders;

    // Calculate consumption progress
    double progress = 0.0;
    int spentOrders = 0;
    if (!isUnlimited && totalLimit > 0) {
      spentOrders = totalLimit - _remainingOrders;
      if (spentOrders < 0) spentOrders = 0;
      progress = spentOrders / totalLimit;
      if (progress > 1.0) progress = 1.0;
    }

    // Textual progress bar representation [████████░░░░]
    String textProgressBar = '';
    if (!isUnlimited && totalLimit > 0) {
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
                  _selectedStore != null
                      ? '${_selectedStore!.name} - سوق التل'
                      : 'محفظة متجرك - سوق التل',
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
                        _currentPackageName == 'الفترة التجريبية المجانية'
                            ? 'الفترة التجريبية المجانية 🎁'
                            : '$packageLabel - نشطة ⚡',
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
                          '$spentOrders / $totalLimit أوردر',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
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
                    if (_currentRolledOverOrders > 0 ||
                        _currentCompensatedOrders > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تفصيل باقة الأوردرات النشطة:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildBreakdownItem(
                                  'الأساسية',
                                  _includedOrders,
                                ),
                                if (_currentRolledOverOrders > 0)
                                  _buildBreakdownItem(
                                    'مرحّل 🎁',
                                    _currentRolledOverOrders,
                                  ),
                                if (_currentCompensatedOrders > 0)
                                  _buildBreakdownItem(
                                    'تعويض أيام ⏳',
                                    _currentCompensatedOrders,
                                  ),
                                _buildBreakdownItem('الإجمالي', totalLimit),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Text(
                      'لا يوجد باقة نشطة حالياً',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  if (_packageExpiryDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentPackageName == 'الفترة التجريبية المجانية'
                          ? 'تنتهي الفترة المجانية في: $_packageExpiryDate (باقي $_remainingDays يوم)'
                          : 'ينتهي الاشتراك في: $_packageExpiryDate (باقي $_remainingDays يوم)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                  onPressed: _showTopupDialog,
                  icon: const InstapayIcon(size: 42),
                  label: const Text(
                    'شحن بإنستا باي',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingSubscription
                      ? null
                      : _showSubscriptionSelectionDialog,
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text(
                    '🔄 ترقية/تجديد الباقة',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
    final isUnlimited =
        _includedOrders == -1 ||
        _currentPackageName.toLowerCase().contains('unlimited') ||
        _currentPackageName.contains('غير محدود') ||
        _currentPackageName.contains('مجانية');

    final totalLimit =
        _includedOrders + _currentRolledOverOrders + _currentCompensatedOrders;

    // لا يظهر القسم للباقات غير المحدودة أو إذا لم تكن هناك باقة نشطة
    if (isUnlimited || totalLimit <= 0) {
      return const SizedBox.shrink();
    }

    // حساب نسبة استهلاك الأوردرات
    final spentOrders = totalLimit - _remainingOrders;
    final progress = totalLimit > 0 ? (spentOrders / totalLimit) : 0.0;

    // لا يظهر التنبيه إلا بعد استهلاك 50% أو أكثر من الأوردرات المتاحة
    if (progress < 0.5) {
      return const SizedBox.shrink();
    }

    String insightText =
        '💡 اشترك في إحدى باقات سوق التل الذكية للحصول على عدد طلبات مجاني وتوفير رسوم التشغيل.';

    if (_currentTierId == 1) {
      insightText =
          '💡 مبيعاتك ممتازة! لو رقيت لباقة النمو (Pro) هتوفر في رسوم الأوردرات الإضافية بناءً على معدل مبيعاتك الحالي.';
    } else if (_currentTierId == 2) {
      insightText =
          '💡 مبيعاتك ممتازة! لو رقيت للباقة غير المحدودة (Unlimited) هتوفر حوالي 45 جنيه بناءً على معدل أوردراتك الحالي.';
    } else if (_currentTierId == 3) {
      insightText =
          '💡 أنت مشترك في الباقة غير المحدودة! مبيعاتك في نمو مستمر وتوفر 100% من رسوم الأوردرات الإضافية.';
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insightText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.4,
            ),
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

  Widget _buildRedesignedTransactionCard(
    FinancialTransactionModel transaction,
  ) {
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
    } else if (transaction.notes != null &&
        transaction.notes!.contains('تجديد')) {
      titleText = transaction.notes!;
    } else if (typeCode == 'deposit') {
      titleText = 'شحن محفظة (إنستا باي)';
    }

    final amountText =
        '$amountPrefix${_settingsProvider.formatCurrency(rawAmount.abs())}';

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
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubscriptionSelectionDialog() async {
    final merchantProvider = Provider.of<MerchantProvider>(
      context,
      listen: false,
    );
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

    String? sheetMessage;
    Color alertBgColor = Colors.red.shade900;
    IconData alertIcon = Icons.error_outline;
    int currentAlertId = 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetStateContext, setDialogState) {
            void showAlert(String message, {bool isSuccess = false}) {
              currentAlertId++;
              final myAlertId = currentAlertId;
              setDialogState(() {
                sheetMessage = message;
                if (isSuccess) {
                  alertBgColor = Colors.green.shade800;
                  alertIcon = Icons.check_circle_outline;
                } else {
                  alertBgColor = Colors.red.shade900;
                  alertIcon = Icons.error_outline;
                }
              });

              Future.delayed(const Duration(seconds: 4), () {
                if (sheetContext.mounted && currentAlertId == myAlertId) {
                  setDialogState(() {
                    sheetMessage = null;
                  });
                }
              });
            }

            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SafeArea(
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            color: Theme.of(
                                              itemContext,
                                            ).hintColor,
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

                                              showAlert(
                                                'تم تفعيل الباقة بنجاح',
                                                isSuccess: true,
                                              );
                                              _loadData();
                                              Future.delayed(
                                                const Duration(
                                                  milliseconds: 1500,
                                                ),
                                                () {
                                                  if (sheetContext.mounted) {
                                                    Navigator.pop(sheetContext);
                                                  }
                                                },
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              final errorMsg =
                                                  e is PostgrestException
                                                  ? e.message
                                                  : e.toString();
                                              showAlert(
                                                'فشل تفعيل الباقة: $errorMsg',
                                              );
                                            } finally {
                                              if (sheetContext.mounted) {
                                                setDialogState(() {
                                                  _isSubmittingSubscription =
                                                      false;
                                                });
                                              }
                                              if (mounted) {
                                                setState(() {
                                                  _isSubmittingSubscription =
                                                      false;
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
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    top: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: sheetMessage == null
                          ? const SizedBox.shrink()
                          : Container(
                              key: ValueKey(sheetMessage),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: alertBgColor.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    alertIcon,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      sheetMessage!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setDialogState(() {
                                        sheetMessage = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTopupDialog() async {
    if (_currentStoreId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _TopupBottomSheet(
          storeId: _currentStoreId!,
          onPickImage: _pickReceiptImage,
          onLoadData: _loadData,
          settingsProvider: _settingsProvider,
        );
      },
    );
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
          behavior: SnackBarBehavior.floating,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStoreSelector(),
            _buildBalanceWarning(),
            _buildSubscriptionAnalytics(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildTransactionsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionAnalytics() {
    final isUnlimited = _includedOrders == -1 ||
        _currentPackageName.toLowerCase().contains('unlimited') ||
        _currentPackageName.contains('غير محدود') ||
        _currentPackageName.contains('مجانية');

    final totalLimit =
        _includedOrders + _currentRolledOverOrders + _currentCompensatedOrders;

    int spentOrders = 0;
    int remainingOrders = _remainingOrders;
    double consumptionPercent = 0.0;

    if (!isUnlimited && totalLimit > 0) {
      spentOrders = totalLimit - _remainingOrders;
      if (spentOrders < 0) spentOrders = 0;
      consumptionPercent = (spentOrders / totalLimit) * 100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.blueAccent,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'تحليلات استهلاك باقة الأوردرات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            // Package Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الباقة الحالية:',
                  style: TextStyle(color: Colors.black54),
                ),
                Text(
                  _currentPackageName == 'Basic'
                      ? 'الباقة الأساسية'
                      : _currentPackageName == 'Pro'
                      ? 'باقة النمو (Pro)'
                      : _currentPackageName == 'Unlimited'
                      ? 'الباقة غير المحدودة'
                      : _currentPackageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (!isUnlimited) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إجمالي الأوردرات المتاحة:',
                    style: TextStyle(color: Colors.black54),
                  ),
                  Text(
                    '$totalLimit أوردر',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الأوردرات المستهلكة:',
                    style: TextStyle(color: Colors.black54),
                  ),
                  Text(
                    '$spentOrders أوردر (${consumptionPercent.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الأوردرات المتبقية:',
                    style: TextStyle(color: Colors.black54),
                  ),
                  Text(
                    '$remainingOrders أوردر',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Linear progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: totalLimit > 0 ? (spentOrders / totalLimit) : 0.0,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    consumptionPercent >= 90
                        ? Colors.red
                        : (consumptionPercent >= 75
                            ? Colors.orange
                            : Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Doughnut Chart of Consumption (Spent vs Remaining)
              SizedBox(
                height: 200,
                child: SfCircularChart(
                  title: const ChartTitle(
                    text: 'نسبة الاستهلاك مقارنة بالمتبقي',
                    textStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                  ),
                  series: <CircularSeries>[
                    DoughnutSeries<ChartData, String>(
                      dataSource: [
                        ChartData(
                          'الأوردرات المستهلكة',
                          spentOrders.toDouble(),
                          Colors.redAccent,
                        ),
                        ChartData(
                          'الأوردرات المتبقية',
                          remainingOrders.toDouble(),
                          Colors.green,
                        ),
                      ],
                      xValueMapper: (ChartData data, _) => data.category,
                      yValueMapper: (ChartData data, _) => data.amount,
                      pointColorMapper: (ChartData data, _) => data.color,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                      ),
                    ),
                  ],
                ),
              ),

              // Breakdown composition chart (Included, Rollover, Compensated) if any exist
              if (_currentRolledOverOrders > 0 ||
                  _currentCompensatedOrders > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: SfCircularChart(
                    title: const ChartTitle(
                      text: 'تفاصيل مكونات رصيد الباقة النشط',
                      textStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                    ),
                    series: <CircularSeries>[
                      DoughnutSeries<ChartData, String>(
                        dataSource: [
                          ChartData(
                            'أوردرات أساسية',
                            _includedOrders.toDouble(),
                            Colors.blueAccent,
                          ),
                          if (_currentRolledOverOrders > 0)
                            ChartData(
                              'أوردرات مرحلة 🎁',
                              _currentRolledOverOrders.toDouble(),
                              Colors.purpleAccent,
                            ),
                          if (_currentCompensatedOrders > 0)
                            ChartData(
                              'أوردرات تعويض أيام ⏳',
                              _currentCompensatedOrders.toDouble(),
                              Colors.amberAccent,
                            ),
                        ],
                        xValueMapper: (ChartData data, _) => data.category,
                        yValueMapper: (ChartData data, _) => data.amount,
                        pointColorMapper: (ChartData data, _) => data.color,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          labelPosition: ChartDataLabelPosition.outside,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 48,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'أنت مشترك في الباقة غير المحدودة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueAccent,
                        ),
                      ),
                      Text(
                        'لا توجد حدود لاستهلاك الأوردرات في حسابك حالياً.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                'المدفوعات والرسوم',
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
      ChartData(
        'المدفوعات والرسوم',
        _summary['total_adjustments']!,
        Colors.orange,
      ),
    ];

    return SizedBox(
      height: 300,
      child: SfCircularChart(
        title: const ChartTitle(
          text: 'توزيع المعاملات المالية',
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        series: <CircularSeries>[
          DoughnutSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.category,
            yValueMapper: (ChartData data, _) => data.amount,
            pointColorMapper: (ChartData data, _) => data.color,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
            ),
          ),
        ],
      ),
    );
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

  int get _currentRolledOverOrders {
    if (_subscriptionHistory.isEmpty) return 0;
    final latest = _subscriptionHistory.first;
    return latest['orders_rolled_over'] as int? ?? 0;
  }

  int get _currentCompensatedOrders {
    if (_subscriptionHistory.isEmpty) return 0;
    final latest = _subscriptionHistory.first;
    return latest['orders_compensated'] as int? ?? 0;
  }

  Widget _buildSubscriptionsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildStoreSelector(),
          _buildBalanceWarning(),
          const SizedBox(height: 16),
          const Text(
            'سجل الاشتراكات والباقات 💳',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_subscriptionHistory.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لا يوجد سجل اشتراكات سابق',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'عند تجديد أو ترقية باقتك، ستظهر جميع تفاصيل اشتراكاتك وتواريخها هنا.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subscriptionHistory.length,
              itemBuilder: (context, index) {
                final sub = _subscriptionHistory[index];
                final tierName = sub['tier_name']?.toString() ?? 'باقة';
                final price = (sub['price_paid'] as num?)?.toDouble() ?? 0.0;
                final start = BaseModelMixin.parseDateTime(sub['start_date']);
                final end = BaseModelMixin.parseDateTime(sub['end_date']);
                final included = sub['orders_included'] as int? ?? 0;
                final rolled = sub['orders_rolled_over'] as int? ?? 0;
                final comp = sub['orders_compensated'] as int? ?? 0;

                final now = DateTime.now();
                final isActive = now.isAfter(start) && now.isBefore(end);

                final dateStr =
                    '${intl.DateFormat('yyyy/MM/dd').format(start)} - ${intl.DateFormat('yyyy/MM/dd').format(end)}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive
                          ? Colors.green.shade300
                          : Colors.grey.shade200,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    tierName.contains('تجريبية')
                                        ? Icons.card_giftcard
                                        : Icons.subscriptions_outlined,
                                    color: isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'نشطة حالياً' : 'منتهية',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.green.shade800
                                      : Colors.grey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'السعر المدفوع',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  price == 0.0
                                      ? 'مجاني'
                                      : '${price.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'فترة الصلاحية',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _buildSubDetailItem(
                                'الأوردرات المضمنة:',
                                included == -1
                                    ? 'غير محدود'
                                    : '$included أوردر',
                              ),
                              if (rolled > 0)
                                _buildSubDetailItem(
                                  'مرحل من باقة سابقة:',
                                  '$rolled أوردر',
                                ),
                              if (comp > 0)
                                _buildSubDetailItem(
                                  'تعويض أيام متبقية:',
                                  '$comp أوردر',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSubDetailItem(String title, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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

class _TopupBottomSheet extends StatefulWidget {
  final String storeId;
  final Future<_ReceiptImage?> Function() onPickImage;
  final Future<void> Function() onLoadData;
  final AppSettingsProvider settingsProvider;

  const _TopupBottomSheet({
    required this.storeId,
    required this.onPickImage,
    required this.onLoadData,
    required this.settingsProvider,
  });

  @override
  State<_TopupBottomSheet> createState() => _TopupBottomSheetState();
}

class _TopupBottomSheetState extends State<_TopupBottomSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  _ReceiptImage? _receiptImage;
  bool _isSubmitting = false;
  String? _errorMessage;
  Color _alertBgColor = Colors.red.shade900;
  IconData _alertIcon = Icons.error_outline;
  int _currentErrorId = 0;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showAlert(
    String message, {
    bool isSuccess = false,
    bool isInfo = false,
  }) {
    if (!mounted) return;

    _currentErrorId++;
    final myErrorId = _currentErrorId;

    setState(() {
      _errorMessage = message;
      if (isSuccess) {
        _alertBgColor = Colors.green.shade800;
        _alertIcon = Icons.check_circle_outline;
      } else if (isInfo) {
        _alertBgColor = Colors.blue.shade800;
        _alertIcon = Icons.info_outline;
      } else {
        _alertBgColor = Colors.red.shade900;
        _alertIcon = Icons.error_outline;
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentErrorId == myErrorId) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
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
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: Supabase.instance.client
                        .from('settings')
                        .select()
                        .or(
                          'setting_key.eq.admin_instapay_address,setting_key.eq.admin_instapay_phone,setting_key.eq.merchant_topup_instructions',
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final list = snapshot.data!;
                        final instapayMap = list.firstWhere(
                          (row) =>
                              row['setting_key'] == 'admin_instapay_address',
                          orElse: () => <String, dynamic>{},
                        );
                        final phoneMap = list.firstWhere(
                          (row) => row['setting_key'] == 'admin_instapay_phone',
                          orElse: () => <String, dynamic>{},
                        );
                        final instructionsMap = list.firstWhere(
                          (row) =>
                              row['setting_key'] ==
                              'merchant_topup_instructions',
                          orElse: () => <String, dynamic>{},
                        );

                        final instapayVal =
                            instapayMap['setting_value'] as String? ?? '';
                        final phoneVal =
                            phoneMap['setting_value'] as String? ?? '';
                        final instructionsVal =
                            instructionsMap['setting_value'] as String? ?? '';

                        if (instapayVal.isNotEmpty ||
                            phoneVal.isNotEmpty ||
                            instructionsVal.isNotEmpty) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (instapayVal.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'يرجى إرسال التحويل عبر إنستا باي إلى:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              instapayVal,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: instapayVal),
                                          );
                                          _showAlert(
                                            'تم نسخ عنوان إنستا باي',
                                            isInfo: true,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                                if (phoneVal.isNotEmpty) ...[
                                  if (instapayVal.isNotEmpty)
                                    const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'أو عبر رقم الهاتف (إنستا باي أو محفظة):',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              phoneVal,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: phoneVal),
                                          );
                                          _showAlert(
                                            'تم نسخ رقم الهاتف',
                                            isInfo: true,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                                if ((instapayVal.isNotEmpty ||
                                        phoneVal.isNotEmpty) &&
                                    instructionsVal.isNotEmpty)
                                  const Divider(height: 20),
                                if (instructionsVal.isNotEmpty) ...[
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'طريقة الشحن والتعليمات:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    instructionsVal,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
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
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'مرجع إنستا باي (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await widget.onPickImage();
                      if (picked == null) return;
                      setState(() {
                        _receiptImage = picked;
                      });
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('إرفاق صورة الإيصال'),
                  ),
                  if (_receiptImage != null) ...[
                    const SizedBox(height: 8),
                    Text('تم اختيار: ${_receiptImage!.fileName}'),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  final amount = double.tryParse(
                                    _amountController.text.trim(),
                                  );
                                  if (amount == null || amount <= 0) {
                                    _showAlert('يرجى إدخال مبلغ صحيح');
                                    return;
                                  }

                                  if (_receiptImage == null) {
                                    _showAlert('يرجى إرفاق صورة الإيصال');
                                    return;
                                  }

                                  setState(() => _isSubmitting = true);

                                  try {
                                    final receiptPath =
                                        await StoreWalletService.uploadTopupReceipt(
                                          storeId: widget.storeId,
                                          bytes: _receiptImage!.bytes,
                                          fileName: _receiptImage!.fileName,
                                        );

                                    if (receiptPath == null) {
                                      throw Exception('فشل رفع الإيصال');
                                    }

                                    final submitted =
                                        await StoreWalletService.submitTopupRequest(
                                          storeId: widget.storeId,
                                          amount: amount,
                                          receiptPath: receiptPath,
                                          instapayReference:
                                              _referenceController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : _referenceController.text
                                                    .trim(),
                                          notes:
                                              _notesController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : _notesController.text.trim(),
                                        );

                                    if (!submitted) {
                                      throw Exception('فشل إرسال طلب الشحن');
                                    }

                                    if (!mounted) return;
                                    _showAlert(
                                      'تم إرسال طلب الشحن بنجاح',
                                      isSuccess: true,
                                    );
                                    widget.onLoadData();
                                    Future.delayed(
                                      const Duration(milliseconds: 1500),
                                      () {
                                        if (mounted) {
                                          navigator.pop();
                                        }
                                      },
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    final errorMsg = e is PostgrestException
                                        ? e.message
                                        : e.toString();
                                    _showAlert(
                                      'خطأ أثناء إرسال الطلب: $errorMsg',
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isSubmitting = false);
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
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _errorMessage == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_errorMessage),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _alertBgColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(_alertIcon, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class InstapayIcon extends StatelessWidget {
  final double size;

  const InstapayIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/instapay_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }
}
