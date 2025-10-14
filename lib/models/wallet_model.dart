/// Wallet models that match the Supabase wallets and wallet_transactions tables
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

/// Transaction type enum that matches Supabase transaction_type_enum
enum TransactionType { deposit, withdraw, purchase }

/// Extension for TransactionType enum with Supabase integration
extension TransactionTypeExtension on TransactionType {
  /// Get the database value for Supabase
  String get dbValue {
    switch (this) {
      case TransactionType.deposit:
        return 'deposit';
      case TransactionType.withdraw:
        return 'withdraw';
      case TransactionType.purchase:
        return 'purchase';
    }
  }

  /// Get the display name in Arabic
  String get displayName {
    switch (this) {
      case TransactionType.deposit:
        return 'إيداع';
      case TransactionType.withdraw:
        return 'سحب';
      case TransactionType.purchase:
        return 'شراء';
    }
  }

  /// Create TransactionType from database value
  static TransactionType fromDbValue(String dbValue) {
    switch (dbValue) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdraw':
        return TransactionType.withdraw;
      case 'purchase':
        return TransactionType.purchase;
      default:
        return TransactionType.deposit;
    }
  }

  /// Check if transaction is positive (adds to balance)
  bool get isPositive => this == TransactionType.deposit;

  /// Check if transaction is negative (subtracts from balance)
  bool get isNegative =>
      this == TransactionType.withdraw || this == TransactionType.purchase;
}

/// Wallet model that matches the Supabase wallets table
class WalletModel with BaseModelMixin {
  static const String tableName = 'wallets';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String clientId; // UUID REFERENCES clients(id) ON DELETE CASCADE
  final double balance; // DECIMAL(10,2) DEFAULT 0
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const WalletModel({
    required this.id,
    required this.clientId,
    this.balance = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      balance: double.parse(map['balance'].toString()),
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory WalletModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return WalletModel.fromMap(data);
  }

  factory WalletModel.empty() {
    return WalletModel(
      id: '',
      clientId: '',
      balance: 0.0,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {'client_id': clientId, 'balance': balance};
  }

  WalletModel copyWith({
    String? id,
    String? clientId,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update balance (usually done through transactions)
  WalletModel updateBalance(double newBalance) {
    return copyWith(balance: newBalance, updatedAt: DateTime.now());
  }

  /// Add amount to balance
  WalletModel addBalance(double amount) {
    return updateBalance(balance + amount);
  }

  /// Subtract amount from balance (if sufficient)
  WalletModel? subtractBalance(double amount) {
    if (balance >= amount) {
      return updateBalance(balance - amount);
    }
    return null; // Insufficient balance
  }

  bool get hasBalance => balance > 0;
  bool get canWithdraw => balance > 0;
  bool get isEmpty => balance == 0;

  /// Check if can purchase with given amount
  bool canPurchase(double amount) => balance >= amount;

  /// Get formatted balance
  String get balanceFormatted => '${balance.toStringAsFixed(2)} ج.م';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WalletModel(id: $id, clientId: $clientId, balance: $balance)';
  }
}

/// Wallet transaction model that matches the Supabase wallet_transactions table
class WalletTransactionModel with BaseModelMixin {
  static const String tableName = 'wallet_transactions';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String walletId; // UUID REFERENCES wallets(id) ON DELETE CASCADE
  final double amount; // DECIMAL(10,2) NOT NULL
  final TransactionType type; // transaction_type_enum
  final String? description;
  final String?
  orderId; // UUID REFERENCES orders(id) ON DELETE SET NULL (for purchase transactions)
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    this.description,
    this.orderId,
    required this.createdAt,
    this.updatedAt,
  });

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: map['id'] as String,
      walletId: map['wallet_id'] as String,
      amount: double.parse(map['amount'].toString()),
      type: TransactionTypeExtension.fromDbValue(map['type'] as String),
      description: map['description'] as String?,
      orderId: map['order_id'] as String?,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory WalletTransactionModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return WalletTransactionModel.fromMap(data);
  }

  factory WalletTransactionModel.empty() {
    return WalletTransactionModel(
      id: '',
      walletId: '',
      amount: 0.0,
      type: TransactionType.deposit,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'amount': amount,
      'type': type.dbValue,
      'description': description,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'wallet_id': walletId,
      'amount': amount,
      'type': type.dbValue,
      'description': description,
      'order_id': orderId,
    };
  }

  WalletTransactionModel copyWith({
    String? id,
    String? walletId,
    double? amount,
    TransactionType? type,
    String? description,
    String? orderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      orderId: orderId ?? this.orderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDeposit => type == TransactionType.deposit;
  bool get isWithdraw => type == TransactionType.withdraw;
  bool get isPurchase => type == TransactionType.purchase;

  /// Returns positive amount for deposits, negative for withdraws/purchases
  double get signedAmount {
    return type.isPositive ? amount : -amount;
  }

  /// Check if transaction is related to an order
  bool get hasOrder => orderId != null;

  /// Check if transaction has description
  bool get hasDescription => description != null && description!.isNotEmpty;

  /// Get formatted amount with sign
  String get amountFormatted {
    final sign = type.isPositive ? '+' : '-';
    return '$sign${amount.toStringAsFixed(2)} ج.م';
  }

  /// Get amount with color indication (green for positive, red for negative)
  String get amountDisplay => amountFormatted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WalletTransactionModel(id: $id, amount: $amount, type: $type)';
  }
}
