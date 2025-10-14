import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

/// Financial report types
enum FinancialReportType { daily, weekly, monthly, quarterly, yearly, custom }

/// Financial transaction categories
enum FinancialCategory {
  revenue,
  expense,
  commission,
  fee,
  tax,
  refund,
  settlement,
  bonus,
  penalty,
  adjustment,
}

/// Currency types for multi-currency support
enum CurrencyType { egp, usd, eur, sar, aed }

/// Financial metrics for analytics
enum FinancialMetric {
  totalRevenue,
  netProfit,
  grossMargin,
  commission,
  averageOrderValue,
  customerLifetimeValue,
  churnRate,
  conversionRate,
}

/// Enhanced FinancialService with comprehensive financial management
class FinancialServiceEnhanced {
  static const String _logTag = '🏦 FinancialService';

  // ===== Singleton Pattern =====
  static FinancialServiceEnhanced? _instance;
  static FinancialServiceEnhanced get instance =>
      _instance ??= FinancialServiceEnhanced._internal();

  FinancialServiceEnhanced._internal();

  // ===== Core Dependencies =====
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ===== Configuration =====
  final Map<CurrencyType, Map<String, dynamic>> _currencyConfig = {
    CurrencyType.egp: {'symbol': 'ج.م', 'code': 'EGP', 'rate': 1.0},
    CurrencyType.usd: {'symbol': '\$', 'code': 'USD', 'rate': 0.032},
    CurrencyType.eur: {'symbol': '€', 'code': 'EUR', 'rate': 0.029},
    CurrencyType.sar: {'symbol': 'ر.س', 'code': 'SAR', 'rate': 0.12},
    CurrencyType.aed: {'symbol': 'د.إ', 'code': 'AED', 'rate': 0.118},
  };

  // ===== Balance Management =====

  /// Get comprehensive captain balance with detailed breakdown
  Future<Map<String, dynamic>> getCaptainBalanceDetails(
    String captainId,
  ) async {
    try {
      if (kDebugMode) {
        print('$_logTag Getting captain balance details for: $captainId');
      }

      // Get all captain transactions
      final transactions = await _supabase
          .from('financial_transactions')
          .select('*')
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      final transactionsList = transactions as List;

      // Calculate balance breakdown
      double totalCollected = 0;
      double totalSettled = 0;
      double totalCommission = 0;
      double totalBonus = 0;
      double totalPenalty = 0;
      double pendingAmount = 0;

      final recentTransactions = <Map<String, dynamic>>[];

      for (final transaction in transactionsList) {
        final amount = (transaction['amount'] as double?) ?? 0.0;
        final status = transaction['status'] as String?;
        final type = transaction['type'] as String?;

        // Add to recent transactions (limit to 10)
        if (recentTransactions.length < 10) {
          recentTransactions.add(transaction);
        }

        if (status == 'completed') {
          switch (type) {
            case 'collection':
              totalCollected += amount;
              break;
            case 'settlement':
              totalSettled += amount;
              break;
            case 'commission':
              totalCommission += amount;
              break;
            case 'bonus':
              totalBonus += amount;
              break;
            case 'penalty':
              totalPenalty += amount;
              break;
          }
        } else if (status == 'pending') {
          pendingAmount += amount;
        }
      }

      final currentBalance =
          totalCollected -
          totalSettled +
          totalCommission +
          totalBonus -
          totalPenalty;

      // Get performance metrics
      final performanceMetrics = await _calculateCaptainPerformanceMetrics(
        captainId,
      );

      return {
        'captain_id': captainId,
        'current_balance': currentBalance,
        'total_collected': totalCollected,
        'total_settled': totalSettled,
        'total_commission': totalCommission,
        'total_bonus': totalBonus,
        'total_penalty': totalPenalty,
        'pending_amount': pendingAmount,
        'available_balance': currentBalance - pendingAmount,
        'recent_transactions': recentTransactions,
        'performance_metrics': performanceMetrics,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('$_logTag ❌ Failed to get captain balance details: $e');
      }
      return _getEmptyBalanceDetails(captainId);
    }
  }

  /// Get comprehensive store balance with detailed financial analysis
  Future<Map<String, dynamic>> getStoreBalanceDetails(String storeId) async {
    try {
      if (kDebugMode) {
        print('$_logTag Getting store balance details for: $storeId');
      }

      // Get all store transactions
      final transactions = await _supabase
          .from('financial_transactions')
          .select('*')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      final transactionsList = transactions as List;

      // Calculate comprehensive balance breakdown
      double totalRevenue = 0;
      double totalRefunded = 0;
      double totalCommissionPaid = 0;
      double totalFeesDeducted = 0;
      double totalSettled = 0;
      double pendingTransfers = 0;

      final recentTransactions = <Map<String, dynamic>>[];
      final monthlyBreakdown = <String, double>{};

      for (final transaction in transactionsList) {
        final amount = (transaction['amount'] as double?) ?? 0.0;
        final status = transaction['status'] as String?;
        final type = transaction['type'] as String?;
        final createdAt = DateTime.parse(transaction['created_at']);
        final monthKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';

        // Add to recent transactions (limit to 15)
        if (recentTransactions.length < 15) {
          recentTransactions.add(transaction);
        }

        // Monthly breakdown
        monthlyBreakdown[monthKey] =
            (monthlyBreakdown[monthKey] ?? 0.0) + amount;

        if (status == 'completed') {
          switch (type) {
            case 'transfer_to_store':
            case 'revenue':
              totalRevenue += amount;
              break;
            case 'refund':
              totalRefunded += amount;
              break;
            case 'commission':
              totalCommissionPaid += amount;
              break;
            case 'fee':
              totalFeesDeducted += amount;
              break;
            case 'settlement':
              totalSettled += amount;
              break;
          }
        } else if (status == 'pending' && type == 'transfer_to_store') {
          pendingTransfers += amount;
        }
      }

      final netRevenue = totalRevenue - totalRefunded;
      final currentBalance =
          netRevenue - totalCommissionPaid - totalFeesDeducted - totalSettled;

      // Get business analytics
      final businessAnalytics = await _calculateStoreBusinessAnalytics(storeId);

      // Get financial health score
      final healthScore = _calculateFinancialHealthScore({
        'revenue': totalRevenue,
        'refunds': totalRefunded,
        'commission': totalCommissionPaid,
        'balance': currentBalance,
      });

      return {
        'store_id': storeId,
        'current_balance': currentBalance,
        'total_revenue': totalRevenue,
        'total_refunded': totalRefunded,
        'total_commission_paid': totalCommissionPaid,
        'total_fees_deducted': totalFeesDeducted,
        'total_settled': totalSettled,
        'net_revenue': netRevenue,
        'pending_transfers': pendingTransfers,
        'available_balance': currentBalance - pendingTransfers,
        'recent_transactions': recentTransactions,
        'monthly_breakdown': monthlyBreakdown,
        'business_analytics': businessAnalytics,
        'financial_health_score': healthScore,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('$_logTag ❌ Failed to get store balance details: $e');
      }
      return _getEmptyStoreBalanceDetails(storeId);
    }
  }

  // ===== Advanced Transaction Management =====

  /// Record comprehensive financial transaction with full audit trail
  Future<Map<String, dynamic>> recordAdvancedTransaction({
    required String transactionType,
    required double amount,
    required CurrencyType currency,
    String? orderId,
    String? captainId,
    String? storeId,
    String? clientId,
    String? description,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? referenceId,
    DateTime? scheduledDate,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logTag Recording advanced transaction: $transactionType');
      }

      // Generate transaction ID
      final transactionId = _generateTransactionId();

      // Convert currency if needed
      final amountInBaseCurrency = _convertToBaseCurrency(amount, currency);

      // Create transaction record
      final transactionData = {
        'transaction_id': transactionId,
        'type': transactionType,
        'amount': amount,
        'amount_base_currency': amountInBaseCurrency,
        'currency': currency.toString(),
        'order_id': orderId,
        'captain_id': captainId,
        'store_id': storeId,
        'client_id': clientId,
        'description': description ?? 'Financial transaction',
        'metadata': metadata != null ? jsonEncode(metadata) : null,
        'tags': tags != null ? jsonEncode(tags) : null,
        'reference_id': referenceId,
        'scheduled_date': scheduledDate?.toIso8601String(),
        'status': scheduledDate != null ? 'scheduled' : 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'completed_at': scheduledDate == null
            ? DateTime.now().toIso8601String()
            : null,
      };

      // Insert transaction
      await _supabase.from('financial_transactions').insert(transactionData);

      // Create audit trail
      await _createAuditTrail(
        transactionId,
        'transaction_created',
        transactionData,
      );

      // Update balances
      await _updateBalances(transactionType, amount, captainId, storeId);

      // Send notifications
      await _sendTransactionNotifications(transactionData);

      // Trigger business rules
      await _applyBusinessRules(transactionData);

      return {
        'success': true,
        'transaction_id': transactionId,
        'amount': amount,
        'currency': currency.toString(),
        'status': transactionData['status'],
        'created_at': transactionData['created_at'],
      };
    } catch (e) {
      if (kDebugMode) print('$_logTag ❌ Failed to record transaction: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get comprehensive financial transactions with advanced filtering
  Future<Map<String, dynamic>> getAdvancedTransactions({
    String? captainId,
    String? storeId,
    String? clientId,
    List<String>? transactionTypes,
    List<String>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    CurrencyType? currency,
    double? minAmount,
    double? maxAmount,
    List<String>? tags,
    int limit = 100,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logTag Getting advanced transactions with filters...');
      }

      // Build dynamic query
      var query = _supabase.from('financial_transactions').select('*');

      // Apply filters
      if (captainId != null) query = query.eq('captain_id', captainId);
      if (storeId != null) query = query.eq('store_id', storeId);
      if (clientId != null) query = query.eq('client_id', clientId);
      if (currency != null) query = query.eq('currency', currency.toString());

      if (transactionTypes != null && transactionTypes.isNotEmpty) {
        query = query.inFilter('type', transactionTypes);
      }

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      if (minAmount != null) {
        query = query.gte('amount', minAmount);
      }

      if (maxAmount != null) {
        query = query.lte('amount', maxAmount);
      }

      // Apply ordering and pagination
      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);
      final transactions = (response as List).cast<Map<String, dynamic>>();

      // Calculate summary statistics
      final summary = _calculateTransactionsSummary(transactions);

      // Apply tag filtering (post-query due to JSON field)
      List<Map<String, dynamic>> filteredTransactions = transactions;
      if (tags != null && tags.isNotEmpty) {
        filteredTransactions = transactions.where((transaction) {
          final transactionTags = transaction['tags'] != null
              ? List<String>.from(jsonDecode(transaction['tags']))
              : <String>[];
          return tags.any((tag) => transactionTags.contains(tag));
        }).toList();
      }

      // Enrich transactions with calculated fields
      final enrichedTransactions = await _enrichTransactions(
        filteredTransactions,
      );

      return {
        'transactions': enrichedTransactions,
        'total_count': filteredTransactions.length,
        'summary': summary,
        'filters_applied': {
          'captain_id': captainId,
          'store_id': storeId,
          'client_id': clientId,
          'transaction_types': transactionTypes,
          'statuses': statuses,
          'date_range': {
            'start': startDate?.toIso8601String(),
            'end': endDate?.toIso8601String(),
          },
          'amount_range': {'min': minAmount, 'max': maxAmount},
          'currency': currency?.toString(),
          'tags': tags,
        },
        'pagination': {
          'limit': limit,
          'offset': offset,
          'order_by': orderBy,
          'ascending': ascending,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('$_logTag ❌ Failed to get advanced transactions: $e');
      }
      return {
        'transactions': [],
        'total_count': 0,
        'summary': {},
        'error': e.toString(),
      };
    }
  }

  // ===== Financial Analytics & Reporting =====

  /// Generate comprehensive financial report
  Future<Map<String, dynamic>> generateFinancialReport({
    required FinancialReportType reportType,
    DateTime? startDate,
    DateTime? endDate,
    String? storeId,
    String? captainId,
    List<CurrencyType>? currencies,
    bool includeProjections = false,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logTag Generating financial report: $reportType');
      }

      // Calculate date range based on report type
      final dateRange = _calculateDateRange(reportType, startDate, endDate);
      final reportStartDate = dateRange['start'] as DateTime;
      final reportEndDate = dateRange['end'] as DateTime;

      // Get base transaction data
      final transactionsData = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        startDate: reportStartDate,
        endDate: reportEndDate,
        limit: 10000,
      );

      final transactions = transactionsData['transactions'] as List;

      // Generate comprehensive analytics
      final analytics = await _generateFinancialAnalytics(
        transactions,
        currencies,
      );

      // Generate charts data
      final chartsData = _generateChartsData(transactions, reportType);

      // Generate KPI metrics
      final kpiMetrics = _calculateKPIMetrics(transactions);

      // Generate trend analysis
      final trendAnalysis = _analyzeTrends(transactions, reportType);

      // Generate projections if requested
      Map<String, dynamic>? projections;
      if (includeProjections) {
        projections = await _generateFinancialProjections(
          transactions,
          reportType,
        );
      }

      // Generate insights and recommendations
      final insights = _generateFinancialInsights(analytics, trendAnalysis);

      return {
        'report_info': {
          'type': reportType.toString(),
          'period': {
            'start': reportStartDate.toIso8601String(),
            'end': reportEndDate.toIso8601String(),
          },
          'generated_at': DateTime.now().toIso8601String(),
          'store_id': storeId,
          'captain_id': captainId,
          'currencies': currencies?.map((c) => c.toString()).toList(),
        },
        'analytics': analytics,
        'kpi_metrics': kpiMetrics,
        'charts_data': chartsData,
        'trend_analysis': trendAnalysis,
        'projections': projections,
        'insights': insights,
        'raw_data': {
          'total_transactions': transactions.length,
          'transactions_summary': transactionsData['summary'],
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('$_logTag ❌ Failed to generate financial report: $e');
      }
      return {
        'error': 'Failed to generate financial report: ${e.toString()}',
        'generated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get real-time financial dashboard data
  Future<Map<String, dynamic>> getFinancialDashboard({
    String? storeId,
    String? captainId,
    List<CurrencyType>? currencies,
  }) async {
    try {
      if (kDebugMode) print('$_logTag Getting financial dashboard data...');

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Get data for different periods
      final todayData = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        startDate: todayStart,
        endDate: now,
      );

      final weekData = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        startDate: weekStart,
        endDate: now,
      );

      final monthData = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        startDate: monthStart,
        endDate: now,
      );

      // Calculate key metrics
      final todayMetrics = _calculatePeriodMetrics(
        todayData['transactions'] as List,
      );
      final weekMetrics = _calculatePeriodMetrics(
        weekData['transactions'] as List,
      );
      final monthMetrics = _calculatePeriodMetrics(
        monthData['transactions'] as List,
      );

      // Get pending transactions
      final pendingTransactions = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        statuses: ['pending', 'scheduled'],
        limit: 50,
      );

      // Get recent activity
      final recentActivity = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        limit: 20,
        orderBy: 'created_at',
        ascending: false,
      );

      // Generate alerts
      final alerts = await _generateFinancialAlerts(
        monthData['transactions'] as List,
      );

      return {
        'dashboard_data': {
          'today': {
            'metrics': todayMetrics,
            'transactions_count': (todayData['transactions'] as List).length,
          },
          'this_week': {
            'metrics': weekMetrics,
            'transactions_count': (weekData['transactions'] as List).length,
          },
          'this_month': {
            'metrics': monthMetrics,
            'transactions_count': (monthData['transactions'] as List).length,
          },
        },
        'pending_transactions': {
          'count': (pendingTransactions['transactions'] as List).length,
          'total_amount': _calculateTotalAmount(
            pendingTransactions['transactions'] as List,
          ),
          'transactions': pendingTransactions['transactions'],
        },
        'recent_activity': recentActivity['transactions'],
        'alerts': alerts,
        'currency_rates': _getCurrencyRates(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) print('$_logTag ❌ Failed to get dashboard data: $e');
      return {
        'error': e.toString(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    }
  }

  // ===== Settlement & Reconciliation =====

  /// Perform advanced settlement with comprehensive tracking
  Future<Map<String, dynamic>> performAdvancedSettlement({
    required String entityId,
    required String entityType, // 'captain' or 'store'
    required double amount,
    required String settlementMethod,
    String? notes,
    Map<String, dynamic>? settlementData,
    List<String>? transactionIds,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '$_logTag Performing advanced settlement for $entityType: $entityId',
        );
      }

      // Validate settlement
      final validation = await _validateSettlement(
        entityId,
        entityType,
        amount,
      );
      if (!validation['valid']) {
        return {'success': false, 'error': validation['error']};
      }

      final settlementId = _generateSettlementId();

      // Create settlement record
      final settlementRecord = {
        'settlement_id': settlementId,
        'entity_id': entityId,
        'entity_type': entityType,
        'amount': amount,
        'settlement_method': settlementMethod,
        'status': 'completed',
        'notes': notes,
        'settlement_data': settlementData != null
            ? jsonEncode(settlementData)
            : null,
        'related_transactions': transactionIds != null
            ? jsonEncode(transactionIds)
            : null,
        'created_at': DateTime.now().toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
      };

      // Insert settlement record
      await _supabase.from('financial_settlements').insert(settlementRecord);

      // Record settlement transaction
      await recordAdvancedTransaction(
        transactionType: 'settlement',
        amount: -amount, // Negative for settlement (outgoing)
        currency: CurrencyType.egp,
        captainId: entityType == 'captain' ? entityId : null,
        storeId: entityType == 'store' ? entityId : null,
        description: 'Settlement - $settlementMethod',
        referenceId: settlementId,
        metadata: {
          'settlement_id': settlementId,
          'settlement_method': settlementMethod,
          'entity_type': entityType,
        },
      );

      // Update entity balances
      await _updateEntityBalance(entityId, entityType, -amount);

      // Create audit trail
      await _createAuditTrail(
        settlementId,
        'settlement_completed',
        settlementRecord,
      );

      // Send notifications
      await _sendSettlementNotifications(settlementRecord);

      // Generate settlement receipt
      final receipt = await _generateSettlementReceipt(settlementRecord);

      return {
        'success': true,
        'settlement_id': settlementId,
        'amount_settled': amount,
        'settlement_method': settlementMethod,
        'entity_id': entityId,
        'entity_type': entityType,
        'receipt': receipt,
        'completed_at': settlementRecord['completed_at'],
      };
    } catch (e) {
      if (kDebugMode) print('$_logTag ❌ Settlement failed: $e');
      return {'success': false, 'error': 'Settlement failed: ${e.toString()}'};
    }
  }

  /// Perform financial reconciliation
  Future<Map<String, dynamic>> performReconciliation({
    required DateTime startDate,
    required DateTime endDate,
    String? storeId,
    String? captainId,
    bool autoResolveDiscrepancies = false,
  }) async {
    try {
      if (kDebugMode) {
        print('$_logTag Performing reconciliation from $startDate to $endDate');
      }

      // Get all transactions for the period
      final transactionsData = await getAdvancedTransactions(
        storeId: storeId,
        captainId: captainId,
        startDate: startDate,
        endDate: endDate,
        limit: 100000,
      );

      final transactions = transactionsData['transactions'] as List;

      // Calculate expected balances
      final expectedBalances = _calculateExpectedBalances(transactions);

      // Get actual balances
      final actualBalances = <String, dynamic>{};
      if (storeId != null) {
        actualBalances['store'] = await getStoreBalanceDetails(storeId);
      }
      if (captainId != null) {
        actualBalances['captain'] = await getCaptainBalanceDetails(captainId);
      }

      // Identify discrepancies
      final discrepancies = _identifyDiscrepancies(
        expectedBalances,
        actualBalances,
      );

      // Auto-resolve if enabled and discrepancies are minor
      final resolutions = <Map<String, dynamic>>[];
      if (autoResolveDiscrepancies) {
        for (final discrepancy in discrepancies) {
          final resolution = await _attemptAutoResolution(discrepancy);
          if (resolution['resolved']) {
            resolutions.add(resolution);
          }
        }
      }

      // Generate reconciliation report
      final reconciliationId = _generateReconciliationId();
      final reconciliationReport = {
        'reconciliation_id': reconciliationId,
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'store_id': storeId,
        'captain_id': captainId,
        'transactions_count': transactions.length,
        'expected_balances': expectedBalances,
        'actual_balances': actualBalances,
        'discrepancies': discrepancies,
        'auto_resolutions': resolutions,
        'status': discrepancies.isEmpty ? 'reconciled' : 'discrepancies_found',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save reconciliation record
      await _supabase
          .from('financial_reconciliations')
          .insert(reconciliationReport);

      // Create audit trail
      await _createAuditTrail(
        reconciliationId,
        'reconciliation_performed',
        reconciliationReport,
      );

      return {
        'success': true,
        'reconciliation_id': reconciliationId,
        'status': reconciliationReport['status'],
        'discrepancies_count': discrepancies.length,
        'auto_resolutions_count': resolutions.length,
        'report': reconciliationReport,
      };
    } catch (e) {
      if (kDebugMode) print('$_logTag ❌ Reconciliation failed: $e');
      return {
        'success': false,
        'error': 'Reconciliation failed: ${e.toString()}',
      };
    }
  }

  // ===== Tax & Compliance =====

  /// Calculate tax obligations
  Future<Map<String, dynamic>> calculateTaxObligations({
    required DateTime startDate,
    required DateTime endDate,
    String? storeId,
    Map<String, double>? taxRates,
  }) async {
    try {
      if (kDebugMode) print('$_logTag Calculating tax obligations...');

      // Default tax rates (Egyptian tax system)
      final defaultTaxRates =
          taxRates ??
          {
            'vat': 0.14, // 14% VAT
            'income_tax': 0.25, // 25% corporate income tax
            'withholding_tax': 0.05, // 5% withholding tax
          };

      // Get revenue transactions
      final revenueTransactions = await getAdvancedTransactions(
        storeId: storeId,
        transactionTypes: ['transfer_to_store', 'revenue'],
        statuses: ['completed'],
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = revenueTransactions['transactions'] as List;

      // Calculate tax base
      double totalRevenue = 0;
      double taxableRevenue = 0;
      double exemptRevenue = 0;

      for (final transaction in transactions) {
        final amount = (transaction['amount'] as double?) ?? 0.0;
        final isExempt = _isTransactionTaxExempt(transaction);

        totalRevenue += amount;
        if (isExempt) {
          exemptRevenue += amount;
        } else {
          taxableRevenue += amount;
        }
      }

      // Calculate taxes
      final vatAmount = taxableRevenue * defaultTaxRates['vat']!;
      final incomeTaxAmount =
          (totalRevenue - exemptRevenue) * defaultTaxRates['income_tax']!;
      final withholdingTaxAmount =
          totalRevenue * defaultTaxRates['withholding_tax']!;

      final totalTaxLiability =
          vatAmount + incomeTaxAmount + withholdingTaxAmount;

      // Get paid taxes
      final paidTaxes = await _getPaidTaxes(storeId, startDate, endDate);
      final outstandingTax = totalTaxLiability - paidTaxes['total'];

      return {
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'store_id': storeId,
        'revenue_breakdown': {
          'total_revenue': totalRevenue,
          'taxable_revenue': taxableRevenue,
          'exempt_revenue': exemptRevenue,
        },
        'tax_calculations': {
          'vat': {
            'rate': defaultTaxRates['vat'],
            'base': taxableRevenue,
            'amount': vatAmount,
          },
          'income_tax': {
            'rate': defaultTaxRates['income_tax'],
            'base': totalRevenue - exemptRevenue,
            'amount': incomeTaxAmount,
          },
          'withholding_tax': {
            'rate': defaultTaxRates['withholding_tax'],
            'base': totalRevenue,
            'amount': withholdingTaxAmount,
          },
        },
        'total_tax_liability': totalTaxLiability,
        'paid_taxes': paidTaxes,
        'outstanding_tax': outstandingTax,
        'compliance_status': outstandingTax <= 0
            ? 'compliant'
            : 'outstanding_payment_required',
        'calculated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) print('$_logTag ❌ Tax calculation failed: $e');
      return {
        'error': 'Tax calculation failed: ${e.toString()}',
        'calculated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  // ===== Helper Methods =====

  /// Generate unique transaction ID
  String _generateTransactionId() {
    return 'ft_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Generate unique settlement ID
  String _generateSettlementId() {
    return 'sett_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Generate unique reconciliation ID
  String _generateReconciliationId() {
    return 'recon_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Convert amount to base currency (EGP)
  double _convertToBaseCurrency(double amount, CurrencyType currency) {
    final rate = _currencyConfig[currency]?['rate'] ?? 1.0;
    return amount / rate;
  }

  /// Get empty balance details for error cases
  Map<String, dynamic> _getEmptyBalanceDetails(String entityId) {
    return {
      'entity_id': entityId,
      'current_balance': 0.0,
      'total_collected': 0.0,
      'total_settled': 0.0,
      'available_balance': 0.0,
      'recent_transactions': [],
      'performance_metrics': {},
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Get empty store balance details
  Map<String, dynamic> _getEmptyStoreBalanceDetails(String storeId) {
    return {
      'store_id': storeId,
      'current_balance': 0.0,
      'total_revenue': 0.0,
      'total_refunded': 0.0,
      'net_revenue': 0.0,
      'available_balance': 0.0,
      'recent_transactions': [],
      'business_analytics': {},
      'financial_health_score': 0,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate financial health score
  int _calculateFinancialHealthScore(Map<String, dynamic> metrics) {
    double score = 50; // Base score

    final revenue = metrics['revenue'] as double? ?? 0.0;
    final refunds = metrics['refunds'] as double? ?? 0.0;
    final balance = metrics['balance'] as double? ?? 0.0;

    // Positive indicators
    if (revenue > 0) score += 20;
    if (balance > 0) score += 20;
    if (revenue > 0 && (refunds / revenue) < 0.1) {
      score += 10; // Low refund rate
    }

    // Negative indicators
    if (balance < 0) score -= 30;
    if (revenue > 0 && (refunds / revenue) > 0.2) {
      score -= 20; // High refund rate
    }

    return score.clamp(0, 100).round();
  }

  /// Calculate date range for report types
  Map<String, dynamic> _calculateDateRange(
    FinancialReportType reportType,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final now = DateTime.now();

    switch (reportType) {
      case FinancialReportType.daily:
        final start = startDate ?? DateTime(now.year, now.month, now.day);
        final end = endDate ?? start.add(const Duration(days: 1));
        return {'start': start, 'end': end};

      case FinancialReportType.weekly:
        final start =
            startDate ?? now.subtract(Duration(days: now.weekday - 1));
        final end = endDate ?? start.add(const Duration(days: 7));
        return {'start': start, 'end': end};

      case FinancialReportType.monthly:
        final start = startDate ?? DateTime(now.year, now.month, 1);
        final end = endDate ?? DateTime(now.year, now.month + 1, 1);
        return {'start': start, 'end': end};

      case FinancialReportType.quarterly:
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        final start = startDate ?? DateTime(now.year, quarterStart, 1);
        final end = endDate ?? DateTime(now.year, quarterStart + 3, 1);
        return {'start': start, 'end': end};

      case FinancialReportType.yearly:
        final start = startDate ?? DateTime(now.year, 1, 1);
        final end = endDate ?? DateTime(now.year + 1, 1, 1);
        return {'start': start, 'end': end};

      default:
        return {
          'start': startDate ?? now.subtract(const Duration(days: 30)),
          'end': endDate ?? now,
        };
    }
  }

  // Placeholder implementations for complex methods
  Future<Map<String, dynamic>> _calculateCaptainPerformanceMetrics(
    String captainId,
  ) async => {};
  Future<Map<String, dynamic>> _calculateStoreBusinessAnalytics(
    String storeId,
  ) async => {};
  Future<void> _createAuditTrail(
    String entityId,
    String action,
    Map<String, dynamic> data,
  ) async {}
  Future<void> _updateBalances(
    String transactionType,
    double amount,
    String? captainId,
    String? storeId,
  ) async {}
  Future<void> _sendTransactionNotifications(
    Map<String, dynamic> transactionData,
  ) async {}
  Future<void> _applyBusinessRules(
    Map<String, dynamic> transactionData,
  ) async {}
  Map<String, dynamic> _calculateTransactionsSummary(List transactions) => {};
  Future<List<Map<String, dynamic>>> _enrichTransactions(
    List<Map<String, dynamic>> transactions,
  ) async => transactions;
  Future<Map<String, dynamic>> _generateFinancialAnalytics(
    List transactions,
    List<CurrencyType>? currencies,
  ) async => {};
  Map<String, dynamic> _generateChartsData(
    List transactions,
    FinancialReportType reportType,
  ) => {};
  Map<String, dynamic> _calculateKPIMetrics(List transactions) => {};
  Map<String, dynamic> _analyzeTrends(
    List transactions,
    FinancialReportType reportType,
  ) => {};
  Future<Map<String, dynamic>> _generateFinancialProjections(
    List transactions,
    FinancialReportType reportType,
  ) async => {};
  Map<String, dynamic> _generateFinancialInsights(
    Map<String, dynamic> analytics,
    Map<String, dynamic> trendAnalysis,
  ) => {};
  Map<String, dynamic> _calculatePeriodMetrics(List transactions) => {};
  Future<List<Map<String, dynamic>>> _generateFinancialAlerts(
    List transactions,
  ) async => [];
  double _calculateTotalAmount(List transactions) => 0.0;
  Map<String, double> _getCurrencyRates() => _currencyConfig.map(
    (key, value) => MapEntry(key.toString(), value['rate']),
  );
  Future<Map<String, dynamic>> _validateSettlement(
    String entityId,
    String entityType,
    double amount,
  ) async => {'valid': true};
  Future<void> _updateEntityBalance(
    String entityId,
    String entityType,
    double amount,
  ) async {}
  Future<void> _sendSettlementNotifications(
    Map<String, dynamic> settlementRecord,
  ) async {}
  Future<Map<String, dynamic>> _generateSettlementReceipt(
    Map<String, dynamic> settlementRecord,
  ) async => {};
  Map<String, dynamic> _calculateExpectedBalances(List transactions) => {};
  List<Map<String, dynamic>> _identifyDiscrepancies(
    Map<String, dynamic> expected,
    Map<String, dynamic> actual,
  ) => [];
  Future<Map<String, dynamic>> _attemptAutoResolution(
    Map<String, dynamic> discrepancy,
  ) async => {'resolved': false};
  bool _isTransactionTaxExempt(Map<String, dynamic> transaction) => false;
  Future<Map<String, dynamic>> _getPaidTaxes(
    String? storeId,
    DateTime startDate,
    DateTime endDate,
  ) async => {'total': 0.0};

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      if (kDebugMode) print('$_logTag ♻️ Financial service disposed');
    } catch (e) {
      if (kDebugMode) print('$_logTag ⚠️ Error during disposal: $e');
    }
  }
}
