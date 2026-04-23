import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/address_model.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/services/location_service.dart';

class AddressService {
  static Map<String, String> extractComponentsFromDetails(
    MapLocationDetails details,
  ) {
    final rawAddress = details.address.trim();

    String governorate = (details.governorate ?? '').trim();
    String city = (details.city ?? '').trim();
    String area = (details.district ?? '').trim();
    String street = (details.street ?? '').trim();
    String landmark = (details.landmark ?? '').trim();

    final parts = rawAddress
        .split(RegExp(r'[،,]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (city.isEmpty && parts.isNotEmpty) {
      city = parts.first;
    }
    if (street.isEmpty && parts.length > 1) {
      street = parts[1];
    }
    if (street.isEmpty && parts.isNotEmpty) {
      street = parts.first;
    }

    if (city.isEmpty) city = 'غير محدد';
    if (street.isEmpty) street = 'غير محدد';

    return {
      'governorate': governorate,
      'city': city,
      'area': area,
      'street': street,
      'landmark': landmark,
      'rawAddress': rawAddress,
    };
  }

  static Map<String, dynamic> buildAddressDataFromDetails({
    required String userId,
    required MapLocationDetails details,
    required String label,
    required bool isDefault,
  }) {
    final components = extractComponentsFromDetails(details);

    return {
      'client_id': userId,
      'label': label,
      'governorate': components['governorate']!.isEmpty
          ? null
          : components['governorate'],
      'city': components['city'],
      'area': components['area']!.isEmpty ? null : components['area'],
      'street': components['street'],
      'latitude': details.position.latitude,
      'longitude': details.position.longitude,
      'landmark': components['landmark']!.isEmpty
          ? null
          : components['landmark'],
      'is_default': isDefault,
    };
  }

  static Future<AddressModel> upsertAddress({
    required SupabaseClient client,
    required String userId,
    required Map<String, dynamic> addressData,
    String? addressId,
    bool unsetOtherDefaults = false,
  }) async {
    if (unsetOtherDefaults) {
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('client_id', userId);
    }

    final response = addressId == null
        ? await client.from('addresses').insert(addressData).select().single()
        : await client
              .from('addresses')
              .update(addressData)
              .eq('id', addressId)
              .select()
              .single();

    final address = AddressModel.fromMap(response);

    if (address.latitude != null && address.longitude != null) {
      await LocationService.updateAddressLocation(
        addressId: address.id,
        latitude: address.latitude!,
        longitude: address.longitude!,
      );
    }

    return address;
  }
}
