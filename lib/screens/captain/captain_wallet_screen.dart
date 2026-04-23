import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';

class CaptainWalletScreen extends StatefulWidget {
  const CaptainWalletScreen({super.key});

  @override
  State<CaptainWalletScreen> createState() => _CaptainWalletScreenState();
}

class _CaptainWalletScreenState extends State<CaptainWalletScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  double _currentBalance = 0;
  List<OrderModel> _completedOrders = [];
  late AppSettingsProvider _settingsProvider;

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final captainId = authProvider.currentUserProfile!.id;

      // جلب طلبات الكابتن
      await orderProvider.fetchCaptainOrders(captainId);

      // فلترة الطلبات المكتملة
      final completedOrders = orderProvider.captainOrders
          .where((order) => order.status == OrderStatus.delivered)
          .toList();

      // حساب الرصيد
      double balance = 0;
      for (var order in completedOrders) {
        balance += CaptainOrderHelpers.calculateCommission(order.totalAmount);
      }

      setState(() {
        _currentBalance = balance;
        _completedOrders = completedOrders;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('حدث خطأ في تحميل البيانات', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ في تحميل البيانات')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المحفظة'),
        centerTitle: true,
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: _isLoading
            ? AppShimmer.centeredLines(context)
            : RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    _buildFilters(),
                    Expanded(child: _buildOrdersList()),
                  ],
                ),
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
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'من ${_completedOrders.length} طلب مكتمل',
              style: TextStyle(color: Colors.grey),
            ),
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
    // فلترة حسب التاريخ إذا تم اختياره
    var filteredOrders = _completedOrders;
    if (_startDate != null || _endDate != null) {
      filteredOrders = _completedOrders.where((order) {
        if (_startDate != null && order.createdAt.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && order.createdAt.isAfter(_endDate!)) {
          return false;
        }
        return true;
      }).toList();
    }

    if (filteredOrders.isEmpty) {
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
      itemCount: filteredOrders.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
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

  void _showOrderDetails(OrderModel order) {
    final commission = CaptainOrderHelpers.calculateCommission(
      order.totalAmount,
    );

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
            _buildDetailRow(
              'قيمة الطلب:',
              _settingsProvider.formatCurrency(order.totalAmount),
            ),
            _buildDetailRow(
              'عمولتك (${(CaptainOrderHelpers.commissionRate * 100).toStringAsFixed(0)}%):',
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
      });
    }
  }
}
