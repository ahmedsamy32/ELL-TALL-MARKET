import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';

class DeliveryZonePricingService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'delivery_zone_pricing';

  static Future<List<DeliveryZonePricingModel>> getActiveZones() async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('governorate')
          .order('city', nullsFirst: true)
          .order('area', nullsFirst: true);

      return (response as List)
          .map(
            (e) => DeliveryZonePricingModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Failed to load active delivery zones', e);
      return [];
    }
  }

  static Future<List<DeliveryZonePricingModel>> getAllZonesForAdmin() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order('governorate')
        .order('city', nullsFirst: true)
        .order('area', nullsFirst: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (e) => DeliveryZonePricingModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static Future<void> upsertZone({
    String? zoneId,
    required String governorate,
    String? city,
    String? area,
    required double fee,
    int? estimatedMinutes,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'governorate': governorate.trim(),
      'city': city?.trim().isEmpty ?? true ? null : city?.trim(),
      'area': area?.trim().isEmpty ?? true ? null : area?.trim(),
      'fee': fee,
      'estimated_minutes': estimatedMinutes,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (zoneId == null || zoneId.trim().isEmpty) {
      await _supabase.from(_table).insert(payload);
      return;
    }

    await _supabase.from(_table).update(payload).eq('id', zoneId);
  }

  static Future<void> deleteZone(String zoneId) async {
    await _supabase.from(_table).delete().eq('id', zoneId);
  }
}
