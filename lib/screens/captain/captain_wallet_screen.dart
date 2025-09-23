import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/services/financial_service.dart';
import 'package:ell_tall_market/models/financial_transaction_model.dart';
import 'package:intl/intl.dart' as intl;

class CaptainWalletScreen extends StatefulWidget {
  const CaptainWalletScreen({super.key});

  @override
  _CaptainWalletScreenState createState() => _CaptainWalletScreenState();
}

class _CaptainWalletScreenState extends State<CaptainWalletScreen> {
  final _financialService = FinancialService();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  double _currentBalance = 0;
  List<FinancialTransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final captainId = authProvider.user!.id;

      // جلب الرصيد الحالي
      final balance = await _financialService.getCaptainBalance(captainId);

      // جلب المعاملات
      final transactions = await _financialService.getCaptainTransactions(
        captainId,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _currentBalance = balance;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
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
        title: Text('المحفظة'),
        centerTitle: true,
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildBalanceCard(),
                  _buildFilters(),
                  Expanded(child: _buildTransactionsList()),
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
              '${_currentBalance.toStringAsFixed(2)} ريال',
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

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(child: Text('لا توجد معاملات'));
    }

    return ListView.builder(
      itemCount: _transactions.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return Card(
          child: ListTile(
            title: Text(_getTransactionTitle(transaction)),
            subtitle: Text(_formatDate(transaction.createdAt)),
            trailing: Text(
              '${transaction.amount.toStringAsFixed(2)} ريال',
              style: TextStyle(
                color: _getAmountColor(transaction),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTransactionTitle(FinancialTransactionModel transaction) {
    switch (transaction.type) {
      case TransactionType.collection:
        return 'تحصيل مبلغ من الطلب #${transaction.orderId}';
      case TransactionType.transferToStore:
        return 'تحويل للمتجر';
      case TransactionType.refund:
        return 'استرجاع مبلغ';
    }
  }

  Color _getAmountColor(FinancialTransactionModel transaction) {
    switch (transaction.type) {
      case TransactionType.collection:
        return Colors.green;
      case TransactionType.transferToStore:
      case TransactionType.refund:
        return Colors.red;
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
