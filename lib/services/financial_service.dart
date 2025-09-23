import 'package:ell_tall_market/models/financial_transaction_model.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:ell_tall_market/services/admin_notification_service.dart';
import 'package:flutter/foundation.dart';

class FinancialService {
  final _supabase = SupabaseConfig.client;
  final _adminNotificationService = AdminNotificationService();

  // الحصول على الرصيد الحالي للكابتن
  Future<double> getCaptainBalance(String captainId) async {
    try {
      final response = await _supabase
          .from('financial_transactions')
          .select('amount, type')
          .eq('captain_id', captainId)
          .eq('status', 'completed');

      double balance = 0;
      for (var transaction in response) {
        if (transaction['type'] == 'collection') {
          balance += (transaction['amount'] ?? 0.0);
        }
      }
      return balance;
    } catch (e) {
      debugPrint('خطأ في جلب رصيد الكابتن: $e');
      return 0;
    }
  }

  // الحصول على الرصيد الحالي للمتجر
  Future<double> getStoreBalance(String storeId) async {
    try {
      final response = await _supabase
          .from('financial_transactions')
          .select('amount, type')
          .eq('store_id', storeId)
          .eq('status', 'completed');

      double balance = 0;
      for (var transaction in response) {
        if (transaction['type'] == 'transfer_to_store') {
          balance += (transaction['amount'] ?? 0.0);
        } else if (transaction['type'] == 'refund') {
          balance -= (transaction['amount'] ?? 0.0);
        }
      }
      return balance;
    } catch (e) {
      debugPrint('خطأ في جلب رصيد المتجر: $e');
      return 0;
    }
  }

  // الحصول على معاملات الكابتن
  Future<List<FinancialTransactionModel>> getCaptainTransactions(
    String captainId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final List<String> filters = [];
      if (startDate != null) {
        filters.add('and(created_at.gte.${startDate.toUtc().toIso8601String()})');
      }
      if (endDate != null) {
        final endDateTime = endDate.add(const Duration(days: 1));
        filters.add('and(created_at.lt.${endDateTime.toUtc().toIso8601String()})');
      }

      final query = _supabase
          .from('financial_transactions')
          .select()
          .eq('captain_id', captainId);

      final response = await (filters.isNotEmpty
          ? query.or(filters.join(','))
          : query);

      return (response as List)
          .map((data) => FinancialTransactionModel.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب معاملات الكابتن: $e');
      return [];
    }
  }

  // الحصول على معاملات المتجر
  Future<List<FinancialTransactionModel>> getStoreTransactions(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final List<String> filters = [];
      if (startDate != null) {
        filters.add('and(created_at.gte.${startDate.toUtc().toIso8601String()})');
      }
      if (endDate != null) {
        final endDateTime = endDate.add(const Duration(days: 1));
        filters.add('and(created_at.lt.${endDateTime.toUtc().toIso8601String()})');
      }

      final query = _supabase
          .from('financial_transactions')
          .select()
          .eq('store_id', storeId);

      final response = await (filters.isNotEmpty
          ? query.or(filters.join(','))
          : query);

      return (response as List)
          .map((data) => FinancialTransactionModel.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب معاملات المتجر: $e');
      return [];
    }
  }

  // تسجيل تسوية مالية مع الكابتن
  Future<bool> settleCaptainBalance(
    String captainId,
    double amount,
    String notes,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _supabase.from('financial_transactions').insert({
        'captain_id': captainId,
        'type': 'settlement',
        'amount': amount,
        'status': 'completed',
        'notes': notes,
        'created_at': now,
        'completed_at': now,
      });

      return true;
    } catch (e) {
      debugPrint('����طأ في تسجيل التسوية مع ��لكابتن: $e');
      return false;
    }
  }

  // تسجيل تسوية مالية مع المتجر
  Future<bool> settleStoreBalance(
    String storeId,
    double amount,
    String notes,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _supabase.from('financial_transactions').insert({
        'store_id': storeId,
        'type': 'settlement',
        'amount': amount,
        'status': 'completed',
        'notes': notes,
        'created_at': now,
        'completed_at': now,
      });

      return true;
    } catch (e) {
      debugPrint('خطأ في تسجيل التسوية مع المتجر: $e');
      return false;
    }
  }

  // تسجيل عملية تحصيل جديدة
  Future<bool> recordCollection({
    required String orderId,
    required String captainId,
    required String storeId,
    required double amount,
  }) async {
    try {
      final transaction = FinancialTransactionModel(
        id: null,
        orderId: orderId,
        captainId: captainId,
        storeId: storeId,
        type: TransactionType.collection,
        amount: amount,
        status: TransactionStatus.completed,
        createdAt: DateTime.now(),
      );

      final response = await _supabase
          .from('financial_transactions')
          .insert(transaction.toMap())
          .select()
          .single();

      await _adminNotificationService.notifyAdminOfTransaction(
        storeId: storeId,
        transactionId: response['id'],
        transactionType: 'تحصيل',
        amount: amount,
      );

      return true;
    } catch (e) {
      debugPrint('خطأ في تسجيل عملية التحصيل: $e');
      return false;
    }
  }

  // تسجيل عملية تحويل للمتجر
  Future<bool> recordTransferToStore({
    required String storeId,
    required double amount,
    String? notes,
  }) async {
    try {
      final transaction = FinancialTransactionModel(
        id: null,
        orderId: '',
        storeId: storeId,
        type: TransactionType.transferToStore,
        amount: amount,
        status: TransactionStatus.completed,
        createdAt: DateTime.now(),
        notes: notes,
      );

      final response = await _supabase
          .from('financial_transactions')
          .insert(transaction.toMap())
          .select()
          .single();

      await _adminNotificationService.notifyAdminOfTransaction(
        storeId: storeId,
        transactionId: response['id'],
        transactionType: 'تحويل للمتجر',
        amount: amount,
      );

      return true;
    } catch (e) {
      debugPrint('خطأ في تسجيل عملية التحويل: $e');
      return false;
    }
  }

  // تسجيل عملية استرداد
  Future<bool> recordRefund({
    required String orderId,
    required String storeId,
    required double amount,
    String? reason,
  }) async {
    try {
      final transaction = FinancialTransactionModel(
        id: null,
        orderId: orderId,
        storeId: storeId,
        type: TransactionType.refund,
        amount: amount,
        status: TransactionStatus.completed,
        createdAt: DateTime.now(),
        notes: reason,
      );

      final response = await _supabase
          .from('financial_transactions')
          .insert(transaction.toMap())
          .select()
          .single();

      await _adminNotificationService.notifyAdminOfTransaction(
        storeId: storeId,
        transactionId: response['id'],
        transactionType: 'استرداد',
        amount: amount,
      );

      return true;
    } catch (e) {
      debugPrint('خطأ في تسجيل عملية الاسترداد: $e');
      return false;
    }
  }

  // الحصول على ملخص المعاملات
  Future<Map<String, double>> getTransactionsSummary({
    required String storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('financial_transactions')
          .select()
          .eq('store_id', storeId)
          .eq('status', 'completed');

      // Apply date filters
      if (startDate != null) {
        query = query.gte('created_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        final endDateTime = endDate.add(const Duration(days: 1));
        query = query.lt('created_at', endDateTime.toUtc().toIso8601String());
      }

      final response = await query;
      final transactions = (response as List)
          .map((data) => FinancialTransactionModel.fromMap(data))
          .toList();

      double totalCollected = 0;
      double totalTransferred = 0;
      double totalRefunded = 0;

      for (var transaction in transactions) {
        switch (transaction.type) {
          case TransactionType.collection:
            totalCollected += transaction.amount;
            break;
          case TransactionType.transferToStore:
            totalTransferred += transaction.amount;
            break;
          case TransactionType.refund:
            totalRefunded += transaction.amount;
            break;
        }
      }

      return {
        'total_collected': totalCollected,
        'total_transferred': totalTransferred,
        'total_refunded': totalRefunded,
        'net_amount': totalTransferred - totalRefunded,
      };
    } catch (e) {
      debugPrint('خطأ في جلب ملخص المعاملات: $e');
      return {
        'total_collected': 0,
        'total_transferred': 0,
        'total_refunded': 0,
        'net_amount': 0,
      };
    }
  }
}
