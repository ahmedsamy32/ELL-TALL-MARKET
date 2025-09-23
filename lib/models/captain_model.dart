class CaptainModel {
  final String id;
  final String name;
  final String phone;
  final String imageUrl;
  final double rating;
  final int totalRatings;
  final bool isAvailable;
  final Location? currentLocation;

  CaptainModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.rating,
    required this.totalRatings,
    required this.isAvailable,
    this.currentLocation,
  });

  factory CaptainModel.fromMap(Map<String, dynamic> data) {
    return CaptainModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      isAvailable: data['isAvailable'] ?? false,
      currentLocation: data['currentLocation'] != null
          ? Location.fromMap(data['currentLocation'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'imageUrl': imageUrl,
      'rating': rating,
      'totalRatings': totalRatings,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation?.toMap(),
    };
  }

  CaptainModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? imageUrl,
    double? rating,
    int? totalRatings,
    bool? isAvailable,
    Location? currentLocation,
  }) {
    return CaptainModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory Location.fromMap(Map<String, dynamic> data) {
    return Location(
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
