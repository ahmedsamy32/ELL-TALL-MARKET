import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility to verify Supabase required schema exists and is reachable from the app.
class SupabaseSchemaChecker {
  final SupabaseClient _client;
  SupabaseSchemaChecker(this._client);

  // Core tables the app references across services/providers.
  static const List<String> requiredTables = [
    'profiles',
    'stores',
    'device_tokens',
    'user_providers',
    // Frequently referenced in codebase
    'users',
    'products',
    'categories',
    'orders',
    'order_items',
    'coupons',
    'coupon_usages',
    'reviews',
    'notifications',
    'cart_items',
    'returns',
  ];

  // RPCs used by the app. We'll call with safe dummy params where needed.
  static const List<String> requiredRpcs = [
    'calculate_distance',
    'calculate_delivery_cost',
    'get_nearby_stores',
    'get_nearby_captains',
    'increment_coupon_usage',
    'get_product_rating',
    'update_product_rating',
  ];

  Future<Map<String, dynamic>> runAllChecks() async {
    final results = <String, dynamic>{};

    // Connectivity check
    try {
      await _client.from('profiles').select('id').limit(1).maybeSingle();
      results['connectivity'] = true;
    } catch (e) {
      results['connectivity'] = false;
      results['error'] = 'Connectivity check failed: $e';
      return results; // Can't proceed further
    }

    // Tables
    final missingTables = <String>[];
    for (final table in requiredTables) {
      try {
        await _client.from(table).select('count').limit(1);
      } catch (e) {
        missingTables.add(table);
        if (kDebugMode) debugPrint('❌ Missing table: $table -> $e');
      }
    }
    results['missingTables'] = missingTables;

    // RPCs
    final missingRpcs = <String>[];
    for (final rpc in requiredRpcs) {
      try {
        switch (rpc) {
          case 'calculate_distance':
            await _client.rpc('calculate_distance', params: {
              'lat1': 0.0,
              'lng1': 0.0,
              'lat2': 0.0,
              'lng2': 0.0,
            });
            break;
          case 'calculate_delivery_cost':
            await _client.rpc('calculate_delivery_cost', params: {
              'pickup_lat': 0.0,
              'pickup_lng': 0.0,
              'delivery_lat': 0.0,
              'delivery_lng': 0.0,
              'base_cost': 1.0,
              'cost_per_km': 1.0,
              'min_cost': 1.0,
            });
            break;
          case 'get_nearby_stores':
            await _client.rpc('get_nearby_stores', params: {
              'lat': 0.0,
              'lng': 0.0,
              'radius_km': 1.0,
            });
            break;
          case 'get_nearby_captains':
            await _client.rpc('get_nearby_captains', params: {
              'lat': 0.0,
              'lng': 0.0,
              'radius_km': 1.0,
            });
            break;
          case 'increment_coupon_usage':
            await _client.rpc('increment_coupon_usage', params: {
              'coupon_id': '00000000-0000-0000-0000-000000000000',
            });
            break;
          case 'get_product_rating':
            await _client.rpc('get_product_rating', params: {
              'product_id': '00000000-0000-0000-0000-000000000000',
            });
            break;
          case 'update_product_rating':
            await _client.rpc('update_product_rating', params: {
              'product_id': '00000000-0000-0000-0000-000000000000',
            });
            break;
          default:
            await _client.rpc(rpc);
        }
      } catch (e) {
        missingRpcs.add(rpc);
        if (kDebugMode) debugPrint('❌ Missing RPC: $rpc -> $e');
      }
    }
    results['missingRpcs'] = missingRpcs;

    // Storage bucket check (avatars)
    bool avatarsOk = true;
    try {
      await _client.storage.from('avatars').list(path: '');
    } catch (e) {
      avatarsOk = false;
      if (kDebugMode) debugPrint('❌ Missing storage bucket: avatars -> $e');
    }
    results['storage'] = {'avatars': avatarsOk};

    if (kDebugMode) {
      debugPrint('===== Supabase Schema Check =====');
      debugPrint('Connectivity: ${results['connectivity']}');
      debugPrint('Missing tables (${missingTables.length}): $missingTables');
      debugPrint('Missing RPCs (${missingRpcs.length}): $missingRpcs');
      debugPrint('Storage buckets: ${results['storage']}');
      debugPrint('=================================');
    }

    return results;
  }
}

