/// Address model that matches the Supabase addresses table
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

/// Address model that matches the Supabase addresses table
class AddressModel with BaseModelMixin {
  static const String tableName = 'addresses';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String clientId; // UUID REFERENCES clients(id) ON DELETE CASCADE
  final String label; // e.g., "المنزل", "العمل", "أخرى"
  final String governorate; // المحافظة
  final String street;
  final String city;
  final String? area;
  final String? buildingNumber;
  final String? floorNumber;
  final String? apartmentNumber;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? notes;
  final bool isDefault; // BOOLEAN DEFAULT FALSE
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const AddressModel({
    required this.id,
    required this.clientId,
    required this.label,
    required this.governorate,
    required this.street,
    required this.city,
    this.area,
    this.buildingNumber,
    this.floorNumber,
    this.apartmentNumber,
    this.latitude,
    this.longitude,
    this.phone,
    this.notes,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      label: map['label'] as String,
      governorate: map['governorate'] as String? ?? '',
      street: map['street'] as String,
      city: map['city'] as String,
      area: map['area'] as String?,
      buildingNumber: map['building_number'] as String?,
      floorNumber: map['floor_number'] as String?,
      apartmentNumber: map['apartment_number'] as String?,
      latitude: map['latitude'] != null
          ? double.parse(map['latitude'].toString())
          : null,
      longitude: map['longitude'] != null
          ? double.parse(map['longitude'].toString())
          : null,
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
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
      label: '',
      governorate: '',
      street: '',
      city: '',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'label': label,
      'governorate': governorate,
      'street': street,
      'city': city,
      'area': area,
      'building_number': buildingNumber,
      'floor_number': floorNumber,
      'apartment_number': apartmentNumber,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'notes': notes,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'client_id': clientId,
      'label': label,
      'street': street,
      'city': city,
      'area': area,
      'building_number': buildingNumber,
      'floor_number': floorNumber,
      'apartment_number': apartmentNumber,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'notes': notes,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? clientId,
    String? label,
    String? governorate,
    String? street,
    String? city,
    String? area,
    String? buildingNumber,
    String? floorNumber,
    String? apartmentNumber,
    double? latitude,
    double? longitude,
    String? phone,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      label: label ?? this.label,
      governorate: governorate ?? this.governorate,
      street: street ?? this.street,
      city: city ?? this.city,
      area: area ?? this.area,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      floorNumber: floorNumber ?? this.floorNumber,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted full address
  String get formattedAddress {
    final List<String> parts = [];

    if (buildingNumber != null && buildingNumber!.isNotEmpty) {
      parts.add('عمارة $buildingNumber');
    }

    if (floorNumber != null && floorNumber!.isNotEmpty) {
      parts.add('الطابق $floorNumber');
    }

    if (apartmentNumber != null && apartmentNumber!.isNotEmpty) {
      parts.add('شقة $apartmentNumber');
    }

    parts.add(street);

    if (area != null && area!.isNotEmpty) {
      parts.add(area!);
    }

    parts.add(city);

    return parts.join(', ');
  }

  /// Get short address (street and area)
  String get shortAddress {
    final List<String> parts = [street];
    if (area != null && area!.isNotEmpty) {
      parts.add(area!);
    }
    return parts.join(', ');
  }

  /// Check if address has coordinates
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Check if address has complete details
  bool get isComplete => street.isNotEmpty && city.isNotEmpty && hasCoordinates;

  /// Check if address has building details
  bool get hasBuildingDetails =>
      buildingNumber != null || floorNumber != null || apartmentNumber != null;

  /// Check if address has contact info
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Check if address has notes
  bool get hasNotes => notes != null && notes!.isNotEmpty;

  /// Get coordinates as Map (for backwards compatibility)
  Map<String, double>? get coordinates {
    if (!hasCoordinates) return null;
    return {'lat': latitude!, 'lng': longitude!};
  }

  /// Get latitude (for backwards compatibility)
  double get lat => latitude ?? 0.0;

  /// Get longitude (for backwards compatibility)
  double get lng => longitude ?? 0.0;

  /// Mark as default address
  AddressModel setAsDefault() {
    return copyWith(isDefault: true, updatedAt: DateTime.now());
  }

  /// Remove default status
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
    return 'AddressModel(id: $id, label: $label, shortAddress: $shortAddress)';
  }
}
