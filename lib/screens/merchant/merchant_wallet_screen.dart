import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  static const String _instapayNumber = '';
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

  Widget _buildTopupCard() {
    final instapayText = _instapayNumber.isEmpty
        ? 'رقم إنستا باي غير مضبوط بعد'
        : _instapayNumber;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'شحن المحفظة عبر إنستا باي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('أرسل التحويل إلى: $instapayText'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingTopup ? null : _showTopupDialog,
                icon: const Icon(Icons.upload_file),
                label: const Text('طلب شحن جديد'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTopupDialog() async {
    if (_currentStoreId == null) return;

    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    _ReceiptImage? receiptImage;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('طلب شحن المحفظة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
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
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
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
              ],
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
          _buildBalanceCard(),
          _buildTopupCard(),
          _buildStatusFilter(),
          if (_filteredTransactions.isEmpty)
            Container(
              height: 400,
              alignment: Alignment.center,
              child: const Text('لا توجد معاملات حديثة'),
            )
          else
            ..._filteredTransactions.map((t) => _buildTransactionCard(t)),
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
            if (_selectedStore != null) ...[
              const SizedBox(height: 4),
              Text(
                _selectedStore!.name,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            SizedBox(height: 8),
            Text(
              _settingsProvider.formatCurrency(_currentBalance),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _currentBalance < 0
                    ? Colors.red
                    : Theme.of(context).primaryColor,
              ),
            ),
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

  Widget _buildTransactionCard(FinancialTransactionModel transaction) {
    final rawAmount = transaction.amount;
    final isNegativeAmount = rawAmount < 0;
    final amountPrefix = isNegativeAmount
        ? '-'
        : (transaction.type.isIncoming ? '+' : '-');
    final amountText =
        '$amountPrefix${_settingsProvider.formatCurrency(rawAmount.abs())}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: _getTransactionIcon(transaction),
        title: Text(_getTransactionTitle(transaction)),
        subtitle: Text('$amountText - ${_formatDate(transaction.createdAt)}'),
        trailing: _buildStatusChip(transaction.status),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transaction.orderId.isNotEmpty)
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

  Icon _getTransactionIcon(FinancialTransactionModel transaction) {
    final typeCode = _getTransactionTypeCode(transaction);
    switch (typeCode) {
      case 'deposit':
        return const Icon(Icons.account_balance_wallet, color: Colors.green);
      case 'adjustment':
        return const Icon(Icons.tune, color: Colors.orange);
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

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy/MM/dd').format(date);
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
