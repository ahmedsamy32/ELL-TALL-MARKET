/// Financial models that match the Supabase financial_transactions table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base mixin for common model functionality (if not imported from user_model.dart)
mixin BaseModelMixin {
  String get id;
  DateTime get createdAt;
  DateTime? get updatedAt;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get updatedAtFormatted => updatedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(updatedAt!)
      : 'لم يتم التحديث';

  static DateTime parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }
}

/// Transaction type enum for financial operations
enum TransactionType {
  collection, // تحصيل من العميل
  transferToStore, // تحويل للمتجر
  refund, // استرجاع للعميل
  commission, // عمولة التطبيق
  captainFee, // رسوم الكابتن
  withdrawal, // سحب الأموال
  deposit, // إيداع الأموال
}

/// Extension for TransactionType enum
extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.collection:
        return 'تحصيل من العميل';
      case TransactionType.transferToStore:
        return 'تحويل للمتجر';
      case TransactionType.refund:
        return 'استرجاع للعميل';
      case TransactionType.commission:
        return 'عمولة التطبيق';
      case TransactionType.captainFee:
        return 'رسوم الكابتن';
      case TransactionType.withdrawal:
        return 'سحب الأموال';
      case TransactionType.deposit:
        return 'إيداع الأموال';
    }
  }

  String get code {
    switch (this) {
      case TransactionType.collection:
        return 'collection';
      case TransactionType.transferToStore:
        return 'transfer_to_store';
      case TransactionType.refund:
        return 'refund';
      case TransactionType.commission:
        return 'commission';
      case TransactionType.captainFee:
        return 'captain_fee';
      case TransactionType.withdrawal:
        return 'withdrawal';
      case TransactionType.deposit:
        return 'deposit';
    }
  }

  bool get isIncoming {
    switch (this) {
      case TransactionType.collection:
      case TransactionType.deposit:
        return true;
      case TransactionType.transferToStore:
      case TransactionType.refund:
      case TransactionType.commission:
      case TransactionType.captainFee:
      case TransactionType.withdrawal:
        return false;
    }
  }

  static TransactionType fromCode(String code) {
    switch (code) {
      case 'collection':
        return TransactionType.collection;
      case 'transfer_to_store':
        return TransactionType.transferToStore;
      case 'refund':
        return TransactionType.refund;
      case 'commission':
        return TransactionType.commission;
      case 'captain_fee':
        return TransactionType.captainFee;
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'deposit':
        return TransactionType.deposit;
      default:
        return TransactionType.collection;
    }
  }
}

/// Transaction status enum
enum TransactionStatus {
  pending, // قيد الانتظار
  processing, // قيد المعالجة
  completed, // مكتمل
  failed, // فشل
  cancelled, // ملغي
}

/// Extension for TransactionStatus enum
extension TransactionStatusExtension on TransactionStatus {
  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'قيد الانتظار';
      case TransactionStatus.processing:
        return 'قيد المعالجة';
      case TransactionStatus.completed:
        return 'مكتمل';
      case TransactionStatus.failed:
        return 'فشل';
      case TransactionStatus.cancelled:
        return 'ملغي';
    }
  }

  String get code {
    switch (this) {
      case TransactionStatus.pending:
        return 'pending';
      case TransactionStatus.processing:
        return 'processing';
      case TransactionStatus.completed:
        return 'completed';
      case TransactionStatus.failed:
        return 'failed';
      case TransactionStatus.cancelled:
        return 'cancelled';
    }
  }

  bool get isActive {
    return this == TransactionStatus.pending ||
        this == TransactionStatus.processing;
  }

  bool get isCompleted {
    return this == TransactionStatus.completed;
  }

  bool get isFailed {
    return this == TransactionStatus.failed ||
        this == TransactionStatus.cancelled;
  }

  static TransactionStatus fromCode(String code) {
    switch (code) {
      case 'pending':
        return TransactionStatus.pending;
      case 'processing':
        return TransactionStatus.processing;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }
}

/// Financial transaction model that matches the Supabase financial_transactions table
class FinancialTransactionModel with BaseModelMixin {
  static const String tableName = 'financial_transactions';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String orderId; // UUID REFERENCES orders(id) ON DELETE CASCADE
  final String? clientId; // UUID REFERENCES clients(id) ON DELETE SET NULL
  final String? merchantId; // UUID REFERENCES merchants(id) ON DELETE SET NULL
  final String? storeId; // UUID REFERENCES stores(id) ON DELETE SET NULL
  final String? captainId; // UUID REFERENCES captains(id) ON DELETE SET NULL
  final TransactionType type; // TEXT NOT NULL
  final double amount; // DECIMAL(10,2) NOT NULL
  final TransactionStatus status; // TEXT DEFAULT 'pending'
  final String? notes; // TEXT
  final String? paymentMethod; // TEXT (cash, card, wallet, etc.)
  final String? paymentReference; // TEXT (payment gateway reference)
  final String? collectedBy; // UUID REFERENCES profiles(id)
  final DateTime? completedAt; // TIMESTAMP
  final DateTime? collectedAt; // TIMESTAMP
  final DateTime? transferredAt; // TIMESTAMP
  final DateTime? refundedAt; // TIMESTAMP
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const FinancialTransactionModel({
    required this.id,
    required this.orderId,
    this.clientId,
    this.merchantId,
    this.storeId,
    this.captainId,
    required this.type,
    required this.amount,
    this.status = TransactionStatus.pending,
    this.notes,
    this.paymentMethod,
    this.paymentReference,
    this.collectedBy,
    this.completedAt,
    this.collectedAt,
    this.transferredAt,
    this.refundedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory FinancialTransactionModel.fromMap(Map<String, dynamic> map) {
    return FinancialTransactionModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      clientId: map['client_id'] as String?,
      merchantId: map['merchant_id'] as String?,
      storeId: map['store_id'] as String?,
      captainId: map['captain_id'] as String?,
      type: TransactionTypeExtension.fromCode(
        map['type'] as String? ?? 'collection',
      ),
      amount: _parseAmount(map['amount']),
      status: TransactionStatusExtension.fromCode(
        map['status'] as String? ?? 'pending',
      ),
      notes: map['notes'] as String?,
      paymentMethod: map['payment_method'] as String?,
      paymentReference: map['payment_reference'] as String?,
      collectedBy: map['collected_by'] as String?,
      completedAt: map['completed_at'] != null
          ? BaseModelMixin.parseDateTime(map['completed_at'])
          : null,
      collectedAt: map['collected_at'] != null
          ? BaseModelMixin.parseDateTime(map['collected_at'])
          : null,
      transferredAt: map['transferred_at'] != null
          ? BaseModelMixin.parseDateTime(map['transferred_at'])
          : null,
      refundedAt: map['refunded_at'] != null
          ? BaseModelMixin.parseDateTime(map['refunded_at'])
          : null,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory FinancialTransactionModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return FinancialTransactionModel.fromMap(data);
  }

  factory FinancialTransactionModel.empty() {
    return FinancialTransactionModel(
      id: '',
      orderId: '',
      type: TransactionType.collection,
      amount: 0.0,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'client_id': clientId,
      'merchant_id': merchantId,
      'store_id': storeId,
      'captain_id': captainId,
      'type': type.code,
      'amount': amount,
      'status': status.code,
      'notes': notes,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'collected_by': collectedBy,
      'completed_at': completedAt?.toIso8601String(),
      'collected_at': collectedAt?.toIso8601String(),
      'transferred_at': transferredAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'order_id': orderId,
      'client_id': clientId,
      'merchant_id': merchantId,
      'store_id': storeId,
      'captain_id': captainId,
      'type': type.code,
      'amount': amount,
      'status': status.code,
      'notes': notes,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'collected_by': collectedBy,
      'completed_at': completedAt?.toIso8601String(),
      'collected_at': collectedAt?.toIso8601String(),
      'transferred_at': transferredAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
    };
  }

  FinancialTransactionModel copyWith({
    String? id,
    String? orderId,
    String? clientId,
    String? merchantId,
    String? storeId,
    String? captainId,
    TransactionType? type,
    double? amount,
    TransactionStatus? status,
    String? notes,
    String? paymentMethod,
    String? paymentReference,
    String? collectedBy,
    DateTime? completedAt,
    DateTime? collectedAt,
    DateTime? transferredAt,
    DateTime? refundedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialTransactionModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      clientId: clientId ?? this.clientId,
      merchantId: merchantId ?? this.merchantId,
      storeId: storeId ?? this.storeId,
      captainId: captainId ?? this.captainId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      collectedBy: collectedBy ?? this.collectedBy,
      completedAt: completedAt ?? this.completedAt,
      collectedAt: collectedAt ?? this.collectedAt,
      transferredAt: transferredAt ?? this.transferredAt,
      refundedAt: refundedAt ?? this.refundedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Mark transaction as completed
  FinancialTransactionModel markAsCompleted({
    String? collectedBy,
    String? paymentReference,
  }) {
    final now = DateTime.now();
    return copyWith(
      status: TransactionStatus.completed,
      completedAt: now,
      collectedBy: collectedBy ?? this.collectedBy,
      paymentReference: paymentReference ?? this.paymentReference,
      updatedAt: now,
    );
  }

  /// Mark transaction as failed
  FinancialTransactionModel markAsFailed({String? notes}) {
    return copyWith(
      status: TransactionStatus.failed,
      notes: notes ?? this.notes,
      updatedAt: DateTime.now(),
    );
  }

  /// Mark transaction as processing
  FinancialTransactionModel markAsProcessing() {
    return copyWith(
      status: TransactionStatus.processing,
      updatedAt: DateTime.now(),
    );
  }

  /// Add collection information
  FinancialTransactionModel addCollectionInfo({
    required String collectedBy,
    String? paymentMethod,
    String? paymentReference,
  }) {
    final now = DateTime.now();
    return copyWith(
      collectedBy: collectedBy,
      collectedAt: now,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      updatedAt: now,
    );
  }

  /// Mark as transferred to store
  FinancialTransactionModel markAsTransferred() {
    return copyWith(transferredAt: DateTime.now(), updatedAt: DateTime.now());
  }

  /// Mark as refunded
  FinancialTransactionModel markAsRefunded({String? notes}) {
    return copyWith(
      refundedAt: DateTime.now(),
      status: TransactionStatus.completed,
      notes: notes ?? this.notes,
      updatedAt: DateTime.now(),
    );
  }

  /// Get formatted amount with currency
  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'ar_EG',
      symbol: 'ج.م',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Get signed amount (negative for outgoing transactions)
  double get signedAmount {
    return type.isIncoming ? amount : -amount;
  }

  /// Get formatted signed amount
  String get formattedSignedAmount {
    final formatter = NumberFormat.currency(
      locale: 'ar_EG',
      symbol: 'ج.م',
      decimalDigits: 2,
    );
    return formatter.format(signedAmount);
  }

  /// Check if transaction can be cancelled
  bool get canBeCancelled {
    return status == TransactionStatus.pending;
  }

  /// Check if transaction can be refunded
  bool get canBeRefunded {
    return status == TransactionStatus.completed &&
        type != TransactionType.refund;
  }

  /// Get transaction duration
  Duration? get transactionDuration {
    if (completedAt != null) {
      return completedAt!.difference(createdAt);
    }
    return null;
  }

  /// Get transaction duration in Arabic text
  String get transactionDurationText {
    final duration = transactionDuration;
    if (duration == null) return 'غير مكتمل';

    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} دقيقة';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} ساعة';
    } else {
      return '${duration.inDays} يوم';
    }
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FinancialTransactionModel(id: $id, type: ${type.code}, amount: $amount, status: ${status.code})';
  }
}
