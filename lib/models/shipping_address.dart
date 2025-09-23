class ShippingAddress {
  final String formattedAddress;
  final String phone;
  final Map<String, double>? coordinates;
  final String? street;
  final String? city;
  final String? area;
  final String? buildingNo;
  final String? floorNo;
  final String? apartmentNo;
  final String? additionalDirections;

  // Getters for coordinates with default values
  double get lat => coordinates?['lat'] ?? 0.0;
  double get lng => coordinates?['lng'] ?? 0.0;

  const ShippingAddress({
    required this.formattedAddress,
    required this.phone,
    this.coordinates,
    this.street,
    this.city,
    this.area,
    this.buildingNo,
    this.floorNo,
    this.apartmentNo,
    this.additionalDirections,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      formattedAddress: json['formatted_address'] ?? '',
      phone: json['phone'] ?? '',
      coordinates: json['coordinates'] != null
          ? {
              'lat': (json['coordinates']['lat'] ?? 0.0).toDouble(),
              'lng': (json['coordinates']['lng'] ?? 0.0).toDouble(),
            }
          : null,
      street: json['street'],
      city: json['city'],
      area: json['area'],
      buildingNo: json['building_no'],
      floorNo: json['floor_no'],
      apartmentNo: json['apartment_no'],
      additionalDirections: json['additional_directions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatted_address': formattedAddress,
      'phone': phone,
      'coordinates': coordinates,
      'street': street,
      'city': city,
      'area': area,
      'building_no': buildingNo,
      'floor_no': floorNo,
      'apartment_no': apartmentNo,
      'additional_directions': additionalDirections,
    };
  }
}
