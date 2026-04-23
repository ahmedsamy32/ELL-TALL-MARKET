import 'package:ell_tall_market/models/store_model.dart'; // For BaseModelMixin

class ReviewModel with BaseModelMixin {
  static const String tableName = 'reviews';
  static const String schema = 'public';

  @override
  final String id;
  final String userId;
  final String orderId;
  final String? productId; // Null if it's a store review
  final String? storeId; // Null if it's a product review
  final int rating; // Changed from double to int (1-5)
  final String? comment;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  // Optional expanded fields for UI display (joined from DB)
  final String? userName;
  final String? userAvatar;
  final String? productName;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.orderId,
    this.productId,
    this.storeId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userAvatar,
    this.productName,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String?,
      storeId: map['store_id'] as String?,
      rating: (map['rating'] is int)
          ? map['rating']
          : int.tryParse(map['rating'].toString()) ?? 0,
      comment: map['comment'] as String?,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
      userName: map['profiles'] != null
          ? map['profiles']['full_name'] as String?
          : null,
      userAvatar: map['profiles'] != null
          ? map['profiles']['avatar_url'] as String?
          : null,
      productName: map['products'] != null
          ? map['products']['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'user_id': userId,
      'order_id': orderId,
      if (productId != null) 'product_id': productId,
      if (storeId != null) 'store_id': storeId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
    };
  }

  ReviewModel copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? productId,
    String? storeId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatar,
    String? productName,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      productName: productName ?? this.productName,
    );
  }
}
