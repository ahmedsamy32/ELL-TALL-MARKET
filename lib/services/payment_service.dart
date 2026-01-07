import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

/// Enhanced payment method enum with comprehensive options
enum PaymentMethodEnhanced {
  cashOnDelivery,
  creditCard,
  debitCard,
  digitalWallet,
  bankTransfer,
  applePay,
  googlePay,
  paypal,
  stripe,
  fawry,
  vodafoneCash,
  orangeMoney,
  etisalatMoney,
  instaPay,
  cryptocurrency,
}

/// Payment status with detailed tracking
enum PaymentStatusEnhanced {
  pending,
  processing,
  authorized,
  captured,
  paid,
  partiallyPaid,
  overpaid,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
  disputed,
  chargedBack,
  expired,
  voided,
}

/// Transaction types for comprehensive tracking
enum TransactionType {
  payment,
  refund,
  partialRefund,
  chargeback,
  fee,
  commission,
  cashCollection,
  storeTransfer,
  withdrawal,
  deposit,
  adjustment,
  penalty,
  bonus,
  discount,
}

/// Currency support
enum Currency { egp, usd, eur, sar, aed }

/// Enhanced PaymentService with comprehensive financial management
class PaymentServiceEnhanced {
  // ===== Singleton Pattern =====
  static PaymentServiceEnhanced? _instance;
  static PaymentServiceEnhanced get instance =>
      _instance ??= PaymentServiceEnhanced._internal();

  PaymentServiceEnhanced._internal();

  // ===== Core Dependencies =====
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ===== Configuration =====
  final Map<Currency, Map<String, dynamic>> _currencyConfig = {
    Currency.egp: {'symbol': 'ج.م', 'code': 'EGP', 'decimal_places': 2},
    Currency.usd: {'symbol': '\$', 'code': 'USD', 'decimal_places': 2},
    Currency.eur: {'symbol': '€', 'code': 'EUR', 'decimal_places': 2},
    Currency.sar: {'symbol': 'ر.س', 'code': 'SAR', 'decimal_places': 2},
    Currency.aed: {'symbol': 'د.إ', 'code': 'AED', 'decimal_places': 2},
  };

  // ===== Payment Processing =====

  /// Process payment with comprehensive handling
  Future<Map<String, dynamic>> processPayment({
    required String orderId,
    required double amount,
    required PaymentMethodEnhanced method,
    required Currency currency,
    String? clientId,
    String? storeId,
    Map<String, dynamic>? paymentData,
    bool autoCapture = true,
  }) async {
    try {
      AppLogger.info('Processing payment for order: $orderId');

      // Validate payment data
      final validation = await _validatePaymentRequest(
        orderId,
        amount,
        method,
        currency,
      );
      if (!validation['valid']) {
        return _createErrorResponse(validation['error']);
      }

      // Generate transaction ID
      final transactionId = _generateTransactionId();

      // Create payment record
      final paymentRecord = await _createPaymentRecord(
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        method: method,
        currency: currency,
        clientId: clientId,
        storeId: storeId,
        paymentData: paymentData,
      );

      // Process based on payment method
      Map<String, dynamic> processingResult;

      switch (method) {
        case PaymentMethodEnhanced.cashOnDelivery:
          processingResult = await _processCashOnDelivery(paymentRecord);
          break;
        case PaymentMethodEnhanced.creditCard:
        case PaymentMethodEnhanced.debitCard:
          processingResult = await _processCardPayment(
            paymentRecord,
            paymentData,
          );
          break;
        case PaymentMethodEnhanced.digitalWallet:
        case PaymentMethodEnhanced.applePay:
        case PaymentMethodEnhanced.googlePay:
          processingResult = await _processDigitalWallet(
            paymentRecord,
            paymentData,
          );
          break;
        case PaymentMethodEnhanced.vodafoneCash:
        case PaymentMethodEnhanced.orangeMoney:
        case PaymentMethodEnhanced.etisalatMoney:
          processingResult = await _processMobileWallet(
            paymentRecord,
            paymentData,
          );
          break;
        case PaymentMethodEnhanced.bankTransfer:
          processingResult = await _processBankTransfer(
            paymentRecord,
            paymentData,
          );
          break;
        default:
          processingResult = await _processGenericPayment(
            paymentRecord,
            paymentData,
          );
      }

      // Update payment status
      await _updatePaymentStatus(
        transactionId,
        processingResult['status'],
        processingResult['gateway_response'],
      );

      // Handle auto-capture if enabled
      if (autoCapture &&
          processingResult['status'] == PaymentStatusEnhanced.authorized) {
        final captureResult = await capturePayment(transactionId);
        if (captureResult['success']) {
          processingResult['status'] = PaymentStatusEnhanced.captured;
        }
      }

      // Calculate and record fees
      await _calculateAndRecordFees(transactionId, amount, method, currency);

      // Update order payment status
      await _updateOrderPaymentStatus(orderId, processingResult['status']);

      // Trigger post-payment actions
      await _triggerPostPaymentActions(
        orderId,
        transactionId,
        processingResult,
      );

      // Send notifications
      await _sendPaymentNotifications(orderId, transactionId, processingResult);

      return {
        'success': true,
        'transaction_id': transactionId,
        'status': processingResult['status'].toString(),
        'message': 'Payment processed successfully',
        'amount': amount,
        'currency': currency.toString(),
        'method': method.toString(),
        'gateway_response': processingResult['gateway_response'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Payment processing failed', e);
      AppLogger.error('Payment processing failed for order $orderId: $e');

      return _createErrorResponse('Payment processing failed: ${e.toString()}');
    }
  }

  /// Capture authorized payment
  Future<Map<String, dynamic>> capturePayment(String transactionId) async {
    try {
      AppLogger.info('Capturing payment: $transactionId');

      // Get payment record
      final paymentRecord = await _getPaymentRecord(transactionId);
      if (paymentRecord == null) {
        return _createErrorResponse('Payment record not found');
      }

      // Validate capture eligibility
      if (paymentRecord['status'] !=
          PaymentStatusEnhanced.authorized.toString()) {
        return _createErrorResponse('Payment is not in authorized state');
      }

      // Process capture based on payment method
      final method = _parsePaymentMethod(paymentRecord['method']);
      Map<String, dynamic> captureResult;

      switch (method) {
        case PaymentMethodEnhanced.creditCard:
        case PaymentMethodEnhanced.debitCard:
          captureResult = await _captureCardPayment(paymentRecord);
          break;
        case PaymentMethodEnhanced.digitalWallet:
        case PaymentMethodEnhanced.applePay:
        case PaymentMethodEnhanced.googlePay:
          captureResult = await _captureDigitalWallet(paymentRecord);
          break;
        default:
          captureResult = {
            'success': true,
            'gateway_response': 'Auto-captured',
          };
      }

      // Update payment status
      final newStatus = captureResult['success']
          ? PaymentStatusEnhanced.captured
          : PaymentStatusEnhanced.failed;

      await _updatePaymentStatus(
        transactionId,
        newStatus,
        captureResult['gateway_response'],
      );

      // Record capture transaction
      await _recordTransaction(
        transactionId: _generateTransactionId(),
        parentTransactionId: transactionId,
        orderId: paymentRecord['order_id'],
        type: TransactionType.payment,
        amount: paymentRecord['amount'],
        currency: _parseCurrency(paymentRecord['currency']),
        status: newStatus,
        description: 'Payment capture',
      );

      return {
        'success': captureResult['success'],
        'transaction_id': transactionId,
        'status': newStatus.toString(),
        'message': captureResult['success']
            ? 'Payment captured successfully'
            : 'Payment capture failed',
        'gateway_response': captureResult['gateway_response'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('❌ Payment capture failed', e);
      return _createErrorResponse('Payment capture failed: ${e.toString()}');
    }
  }

  /// Refund payment with comprehensive handling
  Future<Map<String, dynamic>> refundPayment({
    required String transactionId,
    required double amount,
    String? reason,
    bool isPartial = false,
    String? refundedBy,
  }) async {
    try {
      AppLogger.info('Processing refund for transaction: $transactionId');

      // Get original payment record
      final paymentRecord = await _getPaymentRecord(transactionId);
      if (paymentRecord == null) {
        return _createErrorResponse('Original payment not found');
      }

      // Validate refund eligibility
      final validation = await _validateRefundRequest(paymentRecord, amount);
      if (!validation['valid']) {
        return _createErrorResponse(validation['error']);
      }

      // Generate refund transaction ID
      final refundTransactionId = _generateTransactionId();

      // Process refund based on payment method
      final method = _parsePaymentMethod(paymentRecord['method']);
      Map<String, dynamic> refundResult;

      switch (method) {
        case PaymentMethodEnhanced.cashOnDelivery:
          refundResult = await _processCashRefund(paymentRecord, amount);
          break;
        case PaymentMethodEnhanced.creditCard:
        case PaymentMethodEnhanced.debitCard:
          refundResult = await _processCardRefund(paymentRecord, amount);
          break;
        case PaymentMethodEnhanced.digitalWallet:
        case PaymentMethodEnhanced.applePay:
        case PaymentMethodEnhanced.googlePay:
          refundResult = await _processDigitalWalletRefund(
            paymentRecord,
            amount,
          );
          break;
        case PaymentMethodEnhanced.vodafoneCash:
        case PaymentMethodEnhanced.orangeMoney:
        case PaymentMethodEnhanced.etisalatMoney:
          refundResult = await _processMobileWalletRefund(
            paymentRecord,
            amount,
          );
          break;
        default:
          refundResult = await _processGenericRefund(paymentRecord, amount);
      }

      // Record refund transaction
      await _recordTransaction(
        transactionId: refundTransactionId,
        parentTransactionId: transactionId,
        orderId: paymentRecord['order_id'],
        type: isPartial
            ? TransactionType.partialRefund
            : TransactionType.refund,
        amount: -amount, // Negative amount for refund
        currency: _parseCurrency(paymentRecord['currency']),
        status: refundResult['success']
            ? PaymentStatusEnhanced.refunded
            : PaymentStatusEnhanced.failed,
        description: reason ?? 'Payment refund',
        processedBy: refundedBy,
      );

      // Update original payment status
      final originalAmount = paymentRecord['amount'] as double;
      PaymentStatusEnhanced newStatus;

      if (amount >= originalAmount) {
        newStatus = PaymentStatusEnhanced.refunded;
      } else {
        newStatus = PaymentStatusEnhanced.partiallyRefunded;
      }

      await _updatePaymentStatus(
        transactionId,
        newStatus,
        refundResult['gateway_response'],
      );

      // Update order status if fully refunded
      if (newStatus == PaymentStatusEnhanced.refunded) {
        await _updateOrderStatus(
          paymentRecord['order_id'],
          OrderStatus.cancelled,
        );
      }

      // Send notifications
      await _sendRefundNotifications(
        paymentRecord['order_id'],
        refundTransactionId,
        amount,
        reason,
      );

      return {
        'success': refundResult['success'],
        'refund_transaction_id': refundTransactionId,
        'original_transaction_id': transactionId,
        'refund_amount': amount,
        'status': newStatus.toString(),
        'message': refundResult['success']
            ? 'Refund processed successfully'
            : 'Refund processing failed',
        'gateway_response': refundResult['gateway_response'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('❌ Refund processing failed', e);
      return _createErrorResponse('Refund processing failed: ${e.toString()}');
    }
  }

  // ===== Payment Collection (Captain/Delivery) =====

  /// Collect payment by captain (Cash on Delivery)
  Future<Map<String, dynamic>> collectPaymentByCaptain({
    required String orderId,
    required String captainId,
    required double amount,
    Currency currency = Currency.egp,
    String? notes,
    Map<String, dynamic>? collectionData,
  }) async {
    try {
      AppLogger.info('Captain collecting payment for order: $orderId');

      // Validate collection
      final validation = await _validatePaymentCollection(
        orderId,
        captainId,
        amount,
      );
      if (!validation['valid']) {
        return _createErrorResponse(validation['error']);
      }

      final transactionId = _generateTransactionId();
      final now = DateTime.now();

      // Record collection transaction
      await _recordTransaction(
        transactionId: transactionId,
        orderId: orderId,
        type: TransactionType.cashCollection,
        amount: amount,
        currency: currency,
        status: PaymentStatusEnhanced.paid,
        description: 'Cash collection by captain',
        processedBy: captainId,
        notes: notes,
        additionalData: collectionData,
      );

      // Update order payment status
      await _updateOrderPaymentStatus(orderId, PaymentStatusEnhanced.paid);
      await _updateOrderStatus(orderId, OrderStatus.delivered);

      // Record captain collection
      await _supabase.from('captain_collections').insert({
        'transaction_id': transactionId,
        'captain_id': captainId,
        'order_id': orderId,
        'amount_collected': amount,
        'currency': currency.toString(),
        'collected_at': now.toIso8601String(),
        'notes': notes,
        'collection_data': collectionData != null
            ? jsonEncode(collectionData)
            : null,
      });

      // Update captain wallet balance
      await _updateCaptainBalance(captainId, amount, currency);

      // Send notifications
      await _sendCollectionNotifications(orderId, captainId, amount);

      return {
        'success': true,
        'transaction_id': transactionId,
        'collected_amount': amount,
        'currency': currency.toString(),
        'collected_by': captainId,
        'collected_at': now.toIso8601String(),
        'message': 'Payment collected successfully',
      };
    } catch (e) {
      AppLogger.error('❌ Payment collection failed', e);
      return _createErrorResponse('Payment collection failed: ${e.toString()}');
    }
  }

  /// Transfer collected amounts to store
  Future<Map<String, dynamic>> transferToStore({
    required String orderId,
    required String storeId,
    String? transferredBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('Transferring payment to store for order: $orderId');

      // Get order and payment details
      final orderDetails = await _getOrderPaymentDetails(orderId);
      if (orderDetails == null) {
        return _createErrorResponse('Order payment details not found');
      }

      // Calculate transfer amount (after deducting commissions and fees)
      final transferCalculation = await _calculateStoreTransferAmount(orderId);
      if (!transferCalculation['success']) {
        return _createErrorResponse(transferCalculation['error']);
      }

      final transferAmount = transferCalculation['transfer_amount'] as double;
      final commission = transferCalculation['commission'] as double;
      final fees = transferCalculation['fees'] as double;

      final transactionId = _generateTransactionId();
      final now = DateTime.now();

      // Record store transfer transaction
      await _recordTransaction(
        transactionId: transactionId,
        orderId: orderId,
        type: TransactionType.storeTransfer,
        amount: transferAmount,
        currency: _parseCurrency(orderDetails['currency']),
        status: PaymentStatusEnhanced.paid,
        description: 'Transfer to store',
        processedBy: transferredBy,
        notes: notes,
        additionalData: {
          'store_id': storeId,
          'original_amount': orderDetails['amount'],
          'commission_deducted': commission,
          'fees_deducted': fees,
        },
      );

      // Update store balance
      await _updateStoreBalance(
        storeId,
        transferAmount,
        _parseCurrency(orderDetails['currency']),
      );

      // Update order status
      await _updateOrderStatus(orderId, OrderStatus.delivered);

      // Record commission
      if (commission > 0) {
        await _recordTransaction(
          transactionId: _generateTransactionId(),
          orderId: orderId,
          type: TransactionType.commission,
          amount: commission,
          currency: _parseCurrency(orderDetails['currency']),
          status: PaymentStatusEnhanced.paid,
          description: 'Platform commission',
          additionalData: {
            'store_id': storeId,
            'original_transaction': transactionId,
          },
        );
      }

      // Record fees
      if (fees > 0) {
        await _recordTransaction(
          transactionId: _generateTransactionId(),
          orderId: orderId,
          type: TransactionType.fee,
          amount: fees,
          currency: _parseCurrency(orderDetails['currency']),
          status: PaymentStatusEnhanced.paid,
          description: 'Processing fees',
          additionalData: {
            'store_id': storeId,
            'original_transaction': transactionId,
          },
        );
      }

      // Send notifications
      await _sendTransferNotifications(orderId, storeId, transferAmount);

      return {
        'success': true,
        'transaction_id': transactionId,
        'transfer_amount': transferAmount,
        'commission_deducted': commission,
        'fees_deducted': fees,
        'store_id': storeId,
        'transferred_at': now.toIso8601String(),
        'message': 'Payment transferred to store successfully',
      };
    } catch (e) {
      AppLogger.error('❌ Store transfer failed', e);
      return _createErrorResponse('Store transfer failed: ${e.toString()}');
    }
  }

  // ===== Financial Analytics & Reporting =====

  /// Generate comprehensive financial report
  Future<Map<String, dynamic>> generateFinancialReport({
    DateTime? startDate,
    DateTime? endDate,
    String? storeId,
    String? captainId,
    Currency? currency,
    List<TransactionType>? transactionTypes,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      AppLogger.info('Generating financial report from $start to $end');

      // Build query
      var query = _supabase
          .from('financial_transactions')
          .select('*')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      if (captainId != null) {
        query = query.eq('processed_by', captainId);
      }

      if (currency != null) {
        query = query.eq('currency', currency.toString());
      }

      final transactions = await query.order('created_at', ascending: false);
      final transactionsList = transactions as List;

      // Calculate summary metrics
      final summary = await _calculateFinancialSummary(
        transactionsList,
        currency,
      );

      // Generate charts data
      final chartsData = await _generateFinancialCharts(
        transactionsList,
        start,
        end,
      );

      // Calculate trends
      final trends = await _calculateFinancialTrends(
        transactionsList,
        start,
        end,
      );

      // Generate insights
      final insights = await _generateFinancialInsights(
        transactionsList,
        summary,
      );

      return {
        'success': true,
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'summary': summary,
        'transactions': transactionsList,
        'charts': chartsData,
        'trends': trends,
        'insights': insights,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('❌ Financial report generation failed', e);
      return _createErrorResponse(
        'Financial report generation failed: ${e.toString()}',
      );
    }
  }

  /// Get payment analytics for dashboard
  Future<Map<String, dynamic>> getPaymentAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? storeId,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      AppLogger.info('Getting payment analytics');

      // Get transaction data
      var query = _supabase
          .from('financial_transactions')
          .select('*')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      final transactions = await query;
      final transactionsList = transactions as List;

      // Calculate metrics
      final totalRevenue = transactionsList
          .where(
            (t) => [
              TransactionType.payment.toString(),
              TransactionType.cashCollection.toString(),
            ].contains(t['type']),
          )
          .fold(0.0, (sum, t) => sum + (t['amount'] as double));

      final totalRefunds = transactionsList
          .where(
            (t) => [
              TransactionType.refund.toString(),
              TransactionType.partialRefund.toString(),
            ].contains(t['type']),
          )
          .fold(0.0, (sum, t) => sum + (t['amount'] as double).abs());

      final totalCommissions = transactionsList
          .where((t) => t['type'] == TransactionType.commission.toString())
          .fold(0.0, (sum, t) => sum + (t['amount'] as double));

      final totalFees = transactionsList
          .where((t) => t['type'] == TransactionType.fee.toString())
          .fold(0.0, (sum, t) => sum + (t['amount'] as double));

      // Calculate success rates
      final totalPayments = transactionsList
          .where((t) => t['type'] == TransactionType.payment.toString())
          .length;

      final successfulPayments = transactionsList
          .where(
            (t) =>
                t['type'] == TransactionType.payment.toString() &&
                t['status'] == PaymentStatusEnhanced.paid.toString(),
          )
          .length;

      final successRate = totalPayments > 0
          ? (successfulPayments / totalPayments * 100)
          : 0.0;

      // Payment method distribution
      final methodDistribution = <String, int>{};
      for (final transaction in transactionsList) {
        if (transaction['type'] == TransactionType.payment.toString()) {
          final method = transaction['method'] as String? ?? 'unknown';
          methodDistribution[method] = (methodDistribution[method] ?? 0) + 1;
        }
      }

      // Daily breakdown
      final dailyBreakdown = <String, Map<String, double>>{};
      for (final transaction in transactionsList) {
        final date = DateTime.parse(
          transaction['created_at'],
        ).toIso8601String().split('T')[0];
        if (!dailyBreakdown.containsKey(date)) {
          dailyBreakdown[date] = {
            'revenue': 0.0,
            'refunds': 0.0,
            'commissions': 0.0,
            'fees': 0.0,
          };
        }

        final amount = (transaction['amount'] as double).abs();
        switch (transaction['type']) {
          case 'payment':
          case 'cashCollection':
            dailyBreakdown[date]!['revenue'] =
                dailyBreakdown[date]!['revenue']! + amount;
            break;
          case 'refund':
          case 'partialRefund':
            dailyBreakdown[date]!['refunds'] =
                dailyBreakdown[date]!['refunds']! + amount;
            break;
          case 'commission':
            dailyBreakdown[date]!['commissions'] =
                dailyBreakdown[date]!['commissions']! + amount;
            break;
          case 'fee':
            dailyBreakdown[date]!['fees'] =
                dailyBreakdown[date]!['fees']! + amount;
            break;
        }
      }

      return {
        'success': true,
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'summary': {
          'total_revenue': double.parse(totalRevenue.toStringAsFixed(2)),
          'total_refunds': double.parse(totalRefunds.toStringAsFixed(2)),
          'total_commissions': double.parse(
            totalCommissions.toStringAsFixed(2),
          ),
          'total_fees': double.parse(totalFees.toStringAsFixed(2)),
          'net_revenue': double.parse(
            (totalRevenue - totalRefunds).toStringAsFixed(2),
          ),
          'success_rate': double.parse(successRate.toStringAsFixed(2)),
          'total_transactions': transactionsList.length,
        },
        'method_distribution': methodDistribution,
        'daily_breakdown': dailyBreakdown,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Payment analytics failed', e);
      return _createErrorResponse('Payment analytics failed: ${e.toString()}');
    }
  }

  // ===== Security & Fraud Detection =====

  /// Detect potentially fraudulent transactions
  Future<Map<String, dynamic>> detectFraud({
    required String transactionId,
    Map<String, dynamic>? riskFactors,
  }) async {
    try {
      AppLogger.info('Running fraud detection for transaction: $transactionId');

      final transaction = await _getPaymentRecord(transactionId);
      if (transaction == null) {
        return {
          'risk_score': 0,
          'risk_level': 'unknown',
          'reason': 'Transaction not found',
        };
      }

      double riskScore = 0.0;
      final riskReasons = <String>[];

      // Check amount-based risk
      final amount = transaction['amount'] as double;
      if (amount > 10000) {
        riskScore += 30;
        riskReasons.add('High transaction amount');
      } else if (amount > 5000) {
        riskScore += 15;
        riskReasons.add('Elevated transaction amount');
      }

      // Check payment method risk
      final method = _parsePaymentMethod(transaction['method']);
      switch (method) {
        case PaymentMethodEnhanced.cashOnDelivery:
          // Lower risk for COD
          break;
        case PaymentMethodEnhanced.creditCard:
        case PaymentMethodEnhanced.debitCard:
          riskScore += 10;
          riskReasons.add('Card payment requires verification');
          break;
        default:
          riskScore += 5;
          riskReasons.add('Alternative payment method');
      }

      // Check user behavior patterns
      final clientId = transaction['client_id'] as String?;
      if (clientId != null) {
        final behaviorRisk = await _analyzeUserBehaviorRisk(clientId);
        riskScore += behaviorRisk['score'];
        if (behaviorRisk['reasons'].isNotEmpty) {
          riskReasons.addAll(behaviorRisk['reasons']);
        }
      }

      // Check time-based patterns
      final hour = DateTime.parse(transaction['created_at']).hour;
      if (hour < 6 || hour > 23) {
        riskScore += 10;
        riskReasons.add('Unusual transaction time');
      }

      // Add external risk factors
      if (riskFactors != null) {
        if (riskFactors['ip_risk'] == true) {
          riskScore += 25;
          riskReasons.add('High-risk IP address');
        }
        if (riskFactors['device_risk'] == true) {
          riskScore += 20;
          riskReasons.add('Suspicious device fingerprint');
        }
        if (riskFactors['velocity_risk'] == true) {
          riskScore += 15;
          riskReasons.add('High transaction velocity');
        }
      }

      // Determine risk level
      String riskLevel;
      if (riskScore >= 70) {
        riskLevel = 'high';
      } else if (riskScore >= 40) {
        riskLevel = 'medium';
      } else if (riskScore >= 20) {
        riskLevel = 'low';
      } else {
        riskLevel = 'minimal';
      }

      // Record fraud check
      await _supabase.from('fraud_checks').insert({
        'transaction_id': transactionId,
        'risk_score': riskScore,
        'risk_level': riskLevel,
        'risk_reasons': jsonEncode(riskReasons),
        'checked_at': DateTime.now().toIso8601String(),
        'additional_data': riskFactors != null ? jsonEncode(riskFactors) : null,
      });

      return {
        'success': true,
        'transaction_id': transactionId,
        'risk_score': double.parse(riskScore.toStringAsFixed(2)),
        'risk_level': riskLevel,
        'risk_reasons': riskReasons,
        'requires_review': riskLevel == 'high',
        'checked_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Fraud detection failed', e);
      return {
        'success': false,
        'error': 'Fraud detection failed: ${e.toString()}',
        'risk_score': 0,
        'risk_level': 'unknown',
      };
    }
  }

  // ===== Helper Methods =====

  /// Generate unique transaction ID
  String _generateTransactionId() {
    return 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Create error response
  Map<String, dynamic> _createErrorResponse(String message) {
    return {
      'success': false,
      'error': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Validate payment request
  Future<Map<String, dynamic>> _validatePaymentRequest(
    String orderId,
    double amount,
    PaymentMethodEnhanced method,
    Currency currency,
  ) async {
    try {
      // Check if order exists
      final order = await _supabase
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .maybeSingle();

      if (order == null) {
        return {'valid': false, 'error': 'Order not found'};
      }

      // Check if amount matches order total
      final orderTotal = order['total_amount'] as double?;
      if (orderTotal != null && (amount - orderTotal).abs() > 0.01) {
        return {
          'valid': false,
          'error': 'Payment amount does not match order total',
        };
      }

      // Check if order is already paid
      final currentPaymentStatus = order['payment_status'] as String?;
      if (currentPaymentStatus == PaymentStatusEnhanced.paid.toString()) {
        return {'valid': false, 'error': 'Order is already paid'};
      }

      // Validate amount
      if (amount <= 0) {
        return {'valid': false, 'error': 'Invalid payment amount'};
      }

      return {'valid': true};
    } catch (e) {
      return {'valid': false, 'error': 'Validation failed: ${e.toString()}'};
    }
  }

  /// Parse payment method from string
  PaymentMethodEnhanced _parsePaymentMethod(String? method) {
    if (method == null) return PaymentMethodEnhanced.cashOnDelivery;

    try {
      return PaymentMethodEnhanced.values.firstWhere(
        (e) => e.toString() == method,
        orElse: () => PaymentMethodEnhanced.cashOnDelivery,
      );
    } catch (e) {
      return PaymentMethodEnhanced.cashOnDelivery;
    }
  }

  /// Parse currency from string
  Currency _parseCurrency(String? currency) {
    if (currency == null) return Currency.egp;

    try {
      return Currency.values.firstWhere(
        (e) => e.toString() == currency,
        orElse: () => Currency.egp,
      );
    } catch (e) {
      return Currency.egp;
    }
  }

  // ===== Payment Method Implementations =====
  // These methods would contain the actual implementation logic
  // for different payment methods, gateways, and processors

  Future<Map<String, dynamic>> _createPaymentRecord({
    required String transactionId,
    required String orderId,
    required double amount,
    required PaymentMethodEnhanced method,
    required Currency currency,
    String? clientId,
    String? storeId,
    Map<String, dynamic>? paymentData,
  }) async {
    final record = {
      'transaction_id': transactionId,
      'order_id': orderId,
      'client_id': clientId,
      'store_id': storeId,
      'amount': amount,
      'currency': currency.toString(),
      'method': method.toString(),
      'status': PaymentStatusEnhanced.pending.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'payment_data': paymentData != null ? jsonEncode(paymentData) : null,
    };

    await _supabase.from('payment_transactions').insert(record);
    return record;
  }

  Future<Map<String, dynamic>> _processCashOnDelivery(
    Map<String, dynamic> paymentRecord,
  ) async {
    return {
      'success': true,
      'status': PaymentStatusEnhanced.pending,
      'gateway_response': 'COD payment created - awaiting collection',
    };
  }

  Future<Map<String, dynamic>> _processCardPayment(
    Map<String, dynamic> paymentRecord,
    Map<String, dynamic>? paymentData,
  ) async {
    // Implementation for card payment processing
    // This would integrate with actual payment gateways like Stripe, PayPal, etc.
    return {
      'success': true,
      'status': PaymentStatusEnhanced.authorized,
      'gateway_response': 'Card payment authorized successfully',
    };
  }

  Future<Map<String, dynamic>> _processDigitalWallet(
    Map<String, dynamic> paymentRecord,
    Map<String, dynamic>? paymentData,
  ) async {
    // Implementation for digital wallet processing
    return {
      'success': true,
      'status': PaymentStatusEnhanced.paid,
      'gateway_response': 'Digital wallet payment completed',
    };
  }

  Future<Map<String, dynamic>> _processMobileWallet(
    Map<String, dynamic> paymentRecord,
    Map<String, dynamic>? paymentData,
  ) async {
    // Implementation for mobile wallet processing (Vodafone Cash, etc.)
    return {
      'success': true,
      'status': PaymentStatusEnhanced.paid,
      'gateway_response': 'Mobile wallet payment completed',
    };
  }

  Future<Map<String, dynamic>> _processBankTransfer(
    Map<String, dynamic> paymentRecord,
    Map<String, dynamic>? paymentData,
  ) async {
    // Implementation for bank transfer processing
    return {
      'success': true,
      'status': PaymentStatusEnhanced.pending,
      'gateway_response': 'Bank transfer initiated - awaiting confirmation',
    };
  }

  Future<Map<String, dynamic>> _processGenericPayment(
    Map<String, dynamic> paymentRecord,
    Map<String, dynamic>? paymentData,
  ) async {
    // Generic payment processing fallback
    return {
      'success': true,
      'status': PaymentStatusEnhanced.pending,
      'gateway_response': 'Payment initiated',
    };
  }

  // Additional helper methods would be implemented here
  // for database operations, notifications, analytics, etc.

  Future<Map<String, dynamic>?> _getPaymentRecord(String transactionId) async {
    try {
      final response = await _supabase
          .from('payment_transactions')
          .select('*')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updatePaymentStatus(
    String transactionId,
    PaymentStatusEnhanced status,
    String? gatewayResponse,
  ) async {
    await _supabase
        .from('payment_transactions')
        .update({
          'status': status.toString(),
          'gateway_response': gatewayResponse,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('transaction_id', transactionId);
  }

  Future<void> _updateOrderPaymentStatus(
    String orderId,
    PaymentStatusEnhanced status,
  ) async {
    await _supabase
        .from('orders')
        .update({
          'payment_status': status.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<void> _updateOrderStatus(String orderId, OrderStatus status) async {
    await _supabase
        .from('orders')
        .update({
          'status': status.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<void> _recordTransaction({
    required String transactionId,
    String? parentTransactionId,
    required String orderId,
    required TransactionType type,
    required double amount,
    required Currency currency,
    required PaymentStatusEnhanced status,
    String? description,
    String? processedBy,
    String? notes,
    Map<String, dynamic>? additionalData,
  }) async {
    await _supabase.from('financial_transactions').insert({
      'transaction_id': transactionId,
      'parent_transaction_id': parentTransactionId,
      'order_id': orderId,
      'type': type.toString(),
      'amount': amount,
      'currency': currency.toString(),
      'status': status.toString(),
      'description': description,
      'processed_by': processedBy,
      'notes': notes,
      'additional_data': additionalData != null
          ? jsonEncode(additionalData)
          : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Placeholder implementations for remaining methods
  Future<Map<String, dynamic>> _validateRefundRequest(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {'valid': true};
  Future<Map<String, dynamic>> _captureCardPayment(
    Map<String, dynamic> paymentRecord,
  ) async => {'success': true, 'gateway_response': 'Captured'};
  Future<Map<String, dynamic>> _captureDigitalWallet(
    Map<String, dynamic> paymentRecord,
  ) async => {'success': true, 'gateway_response': 'Captured'};
  Future<Map<String, dynamic>> _processCashRefund(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {'success': true, 'gateway_response': 'Cash refund processed'};
  Future<Map<String, dynamic>> _processCardRefund(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {'success': true, 'gateway_response': 'Card refund processed'};
  Future<Map<String, dynamic>> _processDigitalWalletRefund(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {
    'success': true,
    'gateway_response': 'Digital wallet refund processed',
  };
  Future<Map<String, dynamic>> _processMobileWalletRefund(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {
    'success': true,
    'gateway_response': 'Mobile wallet refund processed',
  };
  Future<Map<String, dynamic>> _processGenericRefund(
    Map<String, dynamic> paymentRecord,
    double amount,
  ) async => {'success': true, 'gateway_response': 'Refund processed'};
  Future<void> _calculateAndRecordFees(
    String transactionId,
    double amount,
    PaymentMethodEnhanced method,
    Currency currency,
  ) async {}
  Future<void> _triggerPostPaymentActions(
    String orderId,
    String transactionId,
    Map<String, dynamic> processingResult,
  ) async {}
  Future<void> _sendPaymentNotifications(
    String orderId,
    String transactionId,
    Map<String, dynamic> processingResult,
  ) async {}
  Future<void> _sendRefundNotifications(
    String orderId,
    String refundTransactionId,
    double amount,
    String? reason,
  ) async {}
  Future<Map<String, dynamic>> _validatePaymentCollection(
    String orderId,
    String captainId,
    double amount,
  ) async => {'valid': true};
  Future<void> _updateCaptainBalance(
    String captainId,
    double amount,
    Currency currency,
  ) async {}
  Future<void> _sendCollectionNotifications(
    String orderId,
    String captainId,
    double amount,
  ) async {}
  Future<Map<String, dynamic>?> _getOrderPaymentDetails(String orderId) async =>
      {'amount': 100.0, 'currency': 'Currency.egp'};
  Future<Map<String, dynamic>> _calculateStoreTransferAmount(
    String orderId,
  ) async => {
    'success': true,
    'transfer_amount': 85.0,
    'commission': 10.0,
    'fees': 5.0,
  };
  Future<void> _updateStoreBalance(
    String storeId,
    double amount,
    Currency currency,
  ) async {}
  Future<void> _sendTransferNotifications(
    String orderId,
    String storeId,
    double amount,
  ) async {}
  Future<Map<String, dynamic>> _calculateFinancialSummary(
    List transactions,
    Currency? currency,
  ) async => {};
  Future<Map<String, dynamic>> _generateFinancialCharts(
    List transactions,
    DateTime start,
    DateTime end,
  ) async => {};
  Future<Map<String, dynamic>> _calculateFinancialTrends(
    List transactions,
    DateTime start,
    DateTime end,
  ) async => {};
  Future<Map<String, dynamic>> _generateFinancialInsights(
    List transactions,
    Map<String, dynamic> summary,
  ) async => {};
  Future<Map<String, dynamic>> _analyzeUserBehaviorRisk(
    String clientId,
  ) async => {'score': 0.0, 'reasons': []};

  /// Get currency configuration
  Map<String, dynamic> getCurrencyConfig(Currency currency) {
    return _currencyConfig[currency] ?? _currencyConfig[Currency.egp]!;
  }

  /// Format amount with currency
  String formatAmount(double amount, Currency currency) {
    final config = getCurrencyConfig(currency);
    final symbol = config['symbol'] as String;
    final decimalPlaces = config['decimal_places'] as int;

    return '$symbol${amount.toStringAsFixed(decimalPlaces)}';
  }

  /// Get supported currencies
  List<Currency> getSupportedCurrencies() {
    return _currencyConfig.keys.toList();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      AppLogger.info('♻️ Payment service disposed');
    } catch (e) {
      AppLogger.warning('⚠️ Error during disposal', e);
    }
  }
}
