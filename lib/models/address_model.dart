/// Address model that matches the Supabase addresses table
/// نموذج مبسط: عنوان مدمج + إحداثيات فقط
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base mixin for common model functionality
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

/// نموذج العنوان المبسط
/// يحتوي على: اسم العنوان + العنوان الكامل + الإحداثيات
class AddressModel with BaseModelMixin {
  static const String tableName = 'addresses';
  static const String schema = 'public';

  @override
  final String id;
  final String clientId;
  final String label; // اسم العنوان (المنزل، العمل، إلخ)
  final String? governorate;
  final String city;
  final String? area;
  final String street;
  final String? buildingNumber;
  final String? floorNumber;
  final String? apartmentNumber;

  /// عنوان كامل مركّب للاستخدام في واجهة المستخدم.
  /// (قد لا يكون مخزنًا كعمود مستقل في القاعدة)
  final String address;
  final double? latitude;
  final double? longitude;
  final String? landmark; // علامة مميزة
  final bool isDefault;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const AddressModel({
    required this.id,
    required this.clientId,
    required this.label,
    this.governorate,
    required this.city,
    this.area,
    required this.street,
    this.buildingNumber,
    this.floorNumber,
    this.apartmentNumber,
    required this.address,
    this.latitude,
    this.longitude,
    this.landmark,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  static String _buildFullAddress({
    String? governorate,
    required String city,
    String? area,
    required String street,
    String? buildingNumber,
    String? floorNumber,
    String? apartmentNumber,
  }) {
    final parts = <String>[];
    final gov = (governorate ?? '').trim();
    final cityTrimmed = city.trim();
    final areaTrimmed = (area ?? '').trim();
    final streetTrimmed = street.trim();

    if (gov.isNotEmpty) parts.add(gov);
    if (cityTrimmed.isNotEmpty) parts.add(cityTrimmed);
    if (areaTrimmed.isNotEmpty) parts.add(areaTrimmed);
    if (streetTrimmed.isNotEmpty) parts.add(streetTrimmed);

    final buildingParts = <String>[];
    final b = (buildingNumber ?? '').trim();
    final f = (floorNumber ?? '').trim();
    final a = (apartmentNumber ?? '').trim();
    if (b.isNotEmpty) buildingParts.add('عمارة $b');
    if (f.isNotEmpty) buildingParts.add('الطابق $f');
    if (a.isNotEmpty) buildingParts.add('شقة $a');
    if (buildingParts.isNotEmpty) {
      parts.add(buildingParts.join(' - '));
    }

    return parts.join('، ');
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    final governorate = map['governorate'] as String?;
    final city = (map['city'] as String?) ?? '';
    final area = map['area'] as String?;
    final street = (map['street'] as String?) ?? '';
    final buildingNumber = map['building_number'] as String?;
    final floorNumber = map['floor_number'] as String?;
    final apartmentNumber = map['apartment_number'] as String?;

    // Backwards compatibility:
    // - Some DB versions may still have a single `address` column.
    // - Landmark used to be stored in `notes`.
    String fullAddress = (map['address'] as String?) ?? '';
    if (fullAddress.trim().isEmpty &&
        city.trim().isNotEmpty &&
        street.trim().isNotEmpty) {
      fullAddress = _buildFullAddress(
        governorate: governorate,
        city: city,
        area: area,
        street: street,
        buildingNumber: buildingNumber,
        floorNumber: floorNumber,
        apartmentNumber: apartmentNumber,
      );
    }

    return AddressModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      label: map['label'] as String? ?? 'المنزل',
      governorate: governorate,
      city: city,
      area: area,
      street: street,
      buildingNumber: buildingNumber,
      floorNumber: floorNumber,
      apartmentNumber: apartmentNumber,
      address: fullAddress,
      latitude: map['latitude'] != null
          ? double.parse(map['latitude'].toString())
          : null,
      longitude: map['longitude'] != null
          ? double.parse(map['longitude'].toString())
          : null,
      landmark: (map['landmark'] as String?) ?? (map['notes'] as String?),
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory AddressModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return AddressModel.fromMap(data);
  }

  factory AddressModel.empty() {
    return AddressModel(
      id: '',
      clientId: '',
      label: 'المنزل',
      governorate: null,
      city: '',
      area: null,
      street: '',
      buildingNumber: null,
      floorNumber: null,
      apartmentNumber: null,
      address: '',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'label': label,
      'governorate': governorate,
      'city': city,
      'area': area,
      'street': street,
      'building_number': buildingNumber,
      'floor_number': floorNumber,
      'apartment_number': apartmentNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'client_id': clientId,
      'label': label,
      'governorate': governorate,
      'city': city,
      'area': area,
      'street': street,
      'building_number': buildingNumber,
      'floor_number': floorNumber,
      'apartment_number': apartmentNumber,
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? clientId,
    String? label,
    String? governorate,
    String? city,
    String? area,
    String? street,
    String? buildingNumber,
    String? floorNumber,
    String? apartmentNumber,
    String? address,
    double? latitude,
    double? longitude,
    String? landmark,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      label: label ?? this.label,
      governorate: governorate ?? this.governorate,
      city: city ?? this.city,
      area: area ?? this.area,
      street: street ?? this.street,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      floorNumber: floorNumber ?? this.floorNumber,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      landmark: landmark ?? this.landmark,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// العنوان الكامل
  String get formattedAddress => address;

  /// العنوان المختصر (أول 50 حرف)
  String get shortAddress {
    if (address.length <= 50) return address;
    return '${address.substring(0, 47)}...';
  }

  /// هل يوجد إحداثيات؟
  bool get hasCoordinates => latitude != null && longitude != null;

  /// هل العنوان مكتمل؟
  bool get isComplete => address.isNotEmpty && hasCoordinates;

  /// هل يوجد علامة مميزة؟
  bool get hasLandmark => landmark != null && landmark!.isNotEmpty;

  /// الإحداثيات كـ Map
  Map<String, double>? get coordinates {
    if (!hasCoordinates) return null;
    return {'lat': latitude!, 'lng': longitude!};
  }

  /// تعيين كعنوان افتراضي
  AddressModel setAsDefault() {
    return copyWith(isDefault: true, updatedAt: DateTime.now());
  }

  /// إزالة الافتراضي
  AddressModel removeDefault() {
    return copyWith(isDefault: false, updatedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AddressModel(id: $id, label: $label, address: $shortAddress)';
  }
}
