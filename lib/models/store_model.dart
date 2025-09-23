class StoreModel {
  final String id;
  final String name;
  final String category;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int deliveryTime;
  final double deliveryFee;
  final double minOrder;
  final bool isOpen;
  final String description;
  final String address;
  final String phone;
  final List<String> openingHours;

  StoreModel({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.deliveryTime = 30,
    this.deliveryFee = 0,
    this.minOrder = 0,
    this.isOpen = true,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.openingHours = const [],
  });

  // Copy with method
  StoreModel copyWith({
    String? id,
    String? name,
    String? category,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    int? deliveryTime,
    double? deliveryFee,
    double? minOrder,
    bool? isOpen,
    String? description,
    String? address,
    String? phone,
    List<String>? openingHours,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minOrder: minOrder ?? this.minOrder,
      isOpen: isOpen ?? this.isOpen,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
    );
  }

  // From map method
  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0).toInt(),
      deliveryTime: (map['deliveryTime'] ?? 30).toInt(),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      minOrder: (map['minOrder'] ?? 0.0).toDouble(),
      isOpen: map['isOpen'] ?? true,
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      openingHours: List<String>.from(map['openingHours'] ?? []),
    );
  }

  // To map method
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'minOrder': minOrder,
      'isOpen': isOpen,
      'description': description,
      'address': address,
      'phone': phone,
      'openingHours': openingHours,
    };
  }

  @override
  String toString() {
    return 'StoreModel(id: $id, name: $name, category: $category, rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
