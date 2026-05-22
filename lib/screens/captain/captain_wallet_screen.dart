import 'dart:typed_data';

import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/services/delivery_company_service.dart';
import 'package:ell_tall_market/services/delivery_company_wallet_service.dart';
import 'package:ell_tall_market/services/permission_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptainWalletScreen extends StatefulWidget {
  const CaptainWalletScreen({super.key});

  @override
  State<CaptainWalletScreen> createState() => _CaptainWalletScreenState();
}

class _CaptainWalletScreenState extends State<CaptainWalletScreen>
    with SingleTickerProviderStateMixin {
  static const String _officeInstapayNumber = '';
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  bool _isLoadingData = false;
  String? _errorMessage;
  double _currentBalance = 0;
  double _walletBalance = 0;
  int _totalOrders = 0;
  double _totalSales = 0;
  double _averageOrder = 0;
  bool _isOfficeView = false;
  String? _officeName;
  String? _officeCompanyId;
  int _captainsCount = 0;
  bool _isSubmittingTopup = false;
  List<OrderModel> _completedOrders = [];
  List<OrderModel> _filteredOrders = [];
  List<Map<String, dynamic>> _officeTopups = [];
  final List<FlSpot> _transactionTrend = [];
  List<String> _trendLabels = [];
  late AppSettingsProvider _settingsProvider;

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
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final currentProfile = authProvider.currentUserProfile;
      if (currentProfile == null) {
        throw Exception('لم يتم العثور على بيانات المستخدم');
      }

      final isOffice = authProvider.isDeliveryCompanyAdmin;
      List<OrderModel> completedOrders = [];
      String? officeName;
      int captainsCount = 0;

      if (isOffice) {
        final company = await DeliveryCompanyService.getCompanyByAdminId(
          currentProfile.id,
        );
        if (company == null) {
          throw Exception('لا يوجد مكتب توصيل مرتبط بهذا الحساب');
        }

        officeName = company.companyName;
        final companyId = company.id;
        _officeCompanyId = companyId;
        final captains = await CaptainService.getCaptains(
          deliveryCompanyId: companyId,
        );
        captainsCount = captains.length;
        final captainIds = captains.map((c) => c.id).toList();

        if (captainIds.isNotEmpty) {
          final response = await Supabase.instance.client
              .from('orders')
              .select(
                '*, client:profiles!client_id(full_name, phone), store:stores!store_id(name, address, phone, latitude, longitude)',
              )
              .inFilter('captain_id', captainIds)
              .eq('status', OrderStatus.delivered.value)
              .order('created_at', ascending: false);

          completedOrders = (response as List)
              .map((o) => OrderModel.fromMap(o))
              .toList();
        }

        final wallet = await DeliveryCompanyWalletService.getOrCreateWallet(
          companyId,
        );
        final officeBalance =
            (wallet?['balance'] as num?)?.toDouble() ?? 0.0;
        final topups = await DeliveryCompanyWalletService.getTopups(
          companyId: companyId,
        );
        _walletBalance = officeBalance;
        _officeTopups = topups;
      } else {
        final captainId = currentProfile.id;
        await orderProvider.fetchCaptainOrders(captainId);
        completedOrders = orderProvider.captainOrders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();
        _walletBalance = 0;
        _officeTopups = [];
        _officeCompanyId = null;
      }

      completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // حساب الرصيد
      double balance = 0;
      double totalSales = 0;
      for (var order in completedOrders) {
        balance += CaptainOrderHelpers.calculateCommission(order.totalAmount);
        totalSales += order.totalAmount;
      }

      final totalOrders = completedOrders.length;
      final avgOrder = totalOrders > 0 ? totalSales / totalOrders : 0.0;
      final trendData = _calculateTrendData(completedOrders);
      final filteredOrders = _applyDateFilter(completedOrders);
      if (!mounted) return;
      setState(() {
        _currentBalance = balance;
        _totalOrders = totalOrders;
        _totalSales = totalSales;
        _averageOrder = avgOrder;
        _isOfficeView = isOffice;
        _officeName = officeName;
        _captainsCount = captainsCount;
        _completedOrders = completedOrders;
        _filteredOrders = filteredOrders;
        _transactionTrend
          ..clear()
          ..addAll(trendData.spots);
        _trendLabels = trendData.labels;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('حدث خطأ في تحميل البيانات', e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حدث خطأ في تحميل البيانات')));
      setState(() {
        _errorMessage = 'تعذر تحميل بيانات المحفظة حالياً';
        _isLoading = false;
      });
    } finally {
      _isLoadingData = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = _isOfficeView ? 'محفظة مكتب التوصيل' : 'المحفظة';
    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
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
      body: ResponsiveCenter(
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

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildBalanceCard(),
          if (_isOfficeView) _buildOfficeTopupCard(),
          if (_isOfficeView) _buildOfficeTopupRequestsSection(),
          _buildFilters(),
          Expanded(child: _buildOrdersList()),
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
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildSummaryCards(),
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
            _buildCommissionTrendChart(),
            const SizedBox(height: 24),
            _buildMonthlyOrdersChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final subtitle = _isOfficeView
        ? (_officeName?.trim().isNotEmpty == true
              ? _officeName!
              : 'مكتب التوصيل')
        : null;
    final ordersLabel =
        _isOfficeView ? 'من $_totalOrders طلب مكتمل' : 'من $_totalOrders طلب مكتمل';
    final balanceValue =
        _isOfficeView ? _walletBalance : _currentBalance;
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _isOfficeView ? 'رصيد محفظة المكتب' : 'الرصيد الحالي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
            SizedBox(height: 8),
            Text(
              _settingsProvider.formatCurrency(balanceValue),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              ordersLabel,
              style: TextStyle(color: Colors.grey),
            ),
            if (_isOfficeView && _captainsCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'عدد الكباتن: $_captainsCount',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: Icon(Icons.date_range),
              label: Text(
                _startDate == null ? 'من تاريخ' : _formatDate(_startDate!),
              ),
              onPressed: () => _selectDate(true),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextButton.icon(
              icon: Icon(Icons.date_range),
              label: Text(
                _endDate == null ? 'إلى تاريخ' : _formatDate(_endDate!),
              ),
              onPressed: () => _selectDate(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات مكتملة'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredOrders.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        final commission = CaptainOrderHelpers.calculateCommission(
          order.totalAmount,
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.attach_money, color: Colors.white),
            ),
            title: Text('طلب #${order.id.substring(0, 8)}'),
            subtitle: Text(
              _formatDate(order.createdAt),
              style: TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${_settingsProvider.formatCurrency(commission)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'من ${_settingsProvider.formatCurrency(order.totalAmount)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _showOrderDetails(order),
          ),
        );
      },
    );
  }

  Widget _buildOfficeTopupCard() {
    final instapayText = _officeInstapayNumber.isEmpty
        ? 'رقم إنستا باي غير مضبوط بعد'
        : _officeInstapayNumber;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'شحن محفظة المكتب عبر إنستا باي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('أرسل التحويل إلى: $instapayText'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingTopup ? null : _showOfficeTopupDialog,
                icon: const Icon(Icons.upload_file),
                label: const Text('طلب شحن جديد'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeTopupRequestsSection() {
    if (_officeTopups.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleRequests = _officeTopups.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'طلبات شحن المكتب الأخيرة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            ...visibleRequests.map((request) {
              final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
              final status = (request['status'] as String?) ?? 'pending';
              final createdAt = BaseModelMixin.parseDateTime(
                request['created_at'],
              );
              final receiptPath = request['receipt_path'] as String?;
              return ListTile(
                title: Text(_settingsProvider.formatCurrency(amount)),
                subtitle: Text(_formatDate(createdAt)),
                trailing: Chip(
                  label: Text(
                    _formatTopupStatus(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _topupStatusColor(status),
                ),
                onTap: receiptPath == null
                    ? null
                    : () => _showOfficeReceiptImage(receiptPath),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showOfficeTopupDialog() async {
    if (_officeCompanyId == null) return;

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
              title: const Text('طلب شحن محفظة المكتب'),
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
                        final picked = await _pickOfficeReceiptImage();
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
                                await DeliveryCompanyWalletService
                                    .uploadTopupReceipt(
                              companyId: _officeCompanyId!,
                              bytes: receiptImage!.bytes,
                              fileName: receiptImage!.fileName,
                            );

                            if (receiptPath == null) {
                              throw Exception('فشل رفع الإيصال');
                            }

                            final submitted =
                                await DeliveryCompanyWalletService
                                    .submitTopupRequest(
                              companyId: _officeCompanyId!,
                              amount: amount,
                              receiptPath: receiptPath,
                              instapayReference: referenceController.text
                                      .trim()
                                      .isEmpty
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

  Future<_ReceiptImage?> _pickOfficeReceiptImage() async {
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

  Future<void> _showOfficeReceiptImage(String receiptPath) async {
    final signedUrl =
        await DeliveryCompanyWalletService.createSignedReceiptUrl(receiptPath);
    if (!mounted) return;

    if (signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر عرض الإيصال حالياً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(signedUrl),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTopupStatus(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _topupStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showOrderDetails(OrderModel order) {
    final commission = CaptainOrderHelpers.calculateCommission(
      order.totalAmount,
    );
    final commissionLabel = _isOfficeView ? 'عمولة المكتب' : 'عمولتك';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('رقم الطلب:', order.id.substring(0, 8)),
            _buildDetailRow('التاريخ:', _formatDate(order.createdAt)),
            if (order.storeName != null)
              _buildDetailRow('المتجر:', order.storeName!),
            _buildDetailRow(
              'قيمة الطلب:',
              _settingsProvider.formatCurrency(order.totalAmount),
            ),
            _buildDetailRow(
              '$commissionLabel (${(CaptainOrderHelpers.commissionRate * 100).toStringAsFixed(0)}%):',
              _settingsProvider.formatCurrency(commission),
            ),
            _buildDetailRow('الحالة:', 'تم التوصيل'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
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
        _filteredOrders = _applyDateFilter(_completedOrders);
      });
    }
  }

  Widget _buildSummaryCards() {
    final totalSalesLabel = _isOfficeView ? 'إجمالي المبيعات' : 'إجمالي المبيعات';
    final avgOrderLabel = _isOfficeView ? 'متوسط الطلب' : 'متوسط الطلب';
    final totalOrdersLabel = _isOfficeView ? 'عدد الطلبات' : 'عدد الطلبات';
    final totalCommissionLabel =
        _isOfficeView ? 'عمولات المكتب' : 'إجمالي العمولة';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                totalSalesLabel,
                _settingsProvider.formatCurrency(_totalSales),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildSummaryCard(
                totalCommissionLabel,
                _settingsProvider.formatCurrency(_currentBalance),
                Icons.percent,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                totalOrdersLabel,
                _totalOrders.toString(),
                Icons.receipt_long,
                Colors.orange,
              ),
            ),
            Expanded(
              child: _buildSummaryCard(
                avgOrderLabel,
                _settingsProvider.formatCurrency(_averageOrder),
                Icons.stacked_line_chart,
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
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
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

  Widget _buildCommissionTrendChart() {
    return SizedBox(
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اتجاه العمولات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _trendLabels.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _trendLabels[index],
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
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

  Widget _buildMonthlyOrdersChart() {
    return SizedBox(
      height: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'عدد الطلبات شهرياً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxMonthlyOrders(),
                    barGroups: _getMonthlyOrderGroups(),
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _trendLabels.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _trendLabels[index],
                              style: const TextStyle(fontSize: 10),
                            );
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

  List<BarChartGroupData> _getMonthlyOrderGroups() {
    final totals = _calculateMonthlyOrderCounts(_completedOrders);
    return List.generate(totals.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: totals[index].toDouble(),
            color: Theme.of(context).primaryColor,
            width: 16,
          ),
        ],
      );
    });
  }

  double _getMaxMonthlyOrders() {
    final totals = _calculateMonthlyOrderCounts(_completedOrders);
    if (totals.isEmpty) return 10;
    final maxValue = totals.reduce((a, b) => a > b ? a : b).toDouble();
    return maxValue == 0 ? 10 : maxValue * 1.2;
  }

  List<int> _calculateMonthlyOrderCounts(List<OrderModel> orders) {
    final months = _buildTrendMonths();
    final totals = List<int>.filled(months.length, 0);
    for (final order in orders) {
      final idx = months.indexWhere(
        (m) => m.year == order.createdAt.year && m.month == order.createdAt.month,
      );
      if (idx != -1) {
        totals[idx] += 1;
      }
    }
    return totals;
  }

  _TrendData _calculateTrendData(List<OrderModel> orders) {
    final months = _buildTrendMonths();
    final totals = List<double>.filled(months.length, 0);
    for (final order in orders) {
      final idx = months.indexWhere(
        (m) => m.year == order.createdAt.year && m.month == order.createdAt.month,
      );
      if (idx != -1) {
        totals[idx] += CaptainOrderHelpers.calculateCommission(order.totalAmount);
      }
    }

    final labels = months
        .map((m) => intl.DateFormat('MM/yyyy').format(m))
        .toList();
    final spots = List.generate(
      totals.length,
      (index) => FlSpot(index.toDouble(), totals[index]),
    );
    return _TrendData(spots: spots, labels: labels);
  }

  List<DateTime> _buildTrendMonths() {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index), 1);
      return month;
    });
  }

  List<OrderModel> _applyDateFilter(List<OrderModel> orders) {
    if (_startDate == null && _endDate == null) return orders;
    return orders.where((order) {
      if (_startDate != null && order.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && order.createdAt.isAfter(_endDate!)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _TrendData {
  final List<FlSpot> spots;
  final List<String> labels;

  const _TrendData({required this.spots, required this.labels});
}

class _ReceiptImage {
  final Uint8List bytes;
  final String fileName;

  const _ReceiptImage(this.bytes, this.fileName);
}
