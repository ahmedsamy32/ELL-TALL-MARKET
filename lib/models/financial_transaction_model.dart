enum TransactionType {
  collection,        // تحصيل من العميل
  transferToStore,   // تحويل للمتجر
  refund,           // استرجاع للعميل
}

enum TransactionStatus {
  pending,    // قيد الانتظار
  completed,  // مكتمل
  failed,     // فشل
}

class FinancialTransactionModel {
  final String? id;
  final String orderId;
  final String? userId;
  final String? storeId;
  final String? captainId;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? notes;

  // معلومات إضافية
  final String? collectedBy;
  final DateTime? collectedAt;
  final DateTime? transferredAt;
  final DateTime? refundedAt;

  FinancialTransactionModel({
    this.id,
    required this.orderId,
    this.userId,
    this.storeId,
    this.captainId,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.notes,
    this.collectedBy,
    this.collectedAt,
    this.transferredAt,
    this.refundedAt,
  });

  factory FinancialTransactionModel.fromMap(Map<String, dynamic> map) {
    // Helper function to convert numeric value to double
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FinancialTransactionModel(
      id: map['id'],
      orderId: map['order_id'],
      userId: map['user_id'],
      storeId: map['store_id'],
      captainId: map['captain_id'],
      type: _parseTransactionType(map['type']),
      amount: parseAmount(map['amount']),
      status: _parseTransactionStatus(map['status']),
      createdAt: DateTime.parse(map['created_at']),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      notes: map['notes'],
      collectedBy: map['collected_by'],
      collectedAt: map['collected_at'] != null ? DateTime.parse(map['collected_at']) : null,
      transferredAt: map['transferred_at'] != null ? DateTime.parse(map['transferred_at']) : null,
      refundedAt: map['refunded_at'] != null ? DateTime.parse(map['refunded_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'store_id': storeId,
      'captain_id': captainId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'collected_by': collectedBy,
      'collected_at': collectedAt?.toIso8601String(),
      'transferred_at': transferredAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
    };
  }

  static TransactionType _parseTransactionType(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.toString().split('.').last == type,
      orElse: () => TransactionType.collection,
    );
  }

  static TransactionStatus _parseTransactionStatus(String status) {
    return TransactionStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => TransactionStatus.pending,
    );
  }
}
