import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseStorageHelper {
  static final _supabase = Supabase.instance.client;

  /// Upload a store image to Supabase storage
  static Future<String?> uploadStoreImage(File imageFile, String storeId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final filePath = 'merchant_logos/$storeId/$fileName';

      await _supabase.storage.from('store_images').upload(filePath, imageFile);

      return _supabase.storage.from('store_images').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('❌ Error uploading store image: $e');
      return null;
    }
  }

  /// Save merchant profile data to Supabase
  static Future<void> saveMerchantProfile({
    required String id,
    required String name,
    required String storeName,
    required String email,
    required String phone,
    required String category,
    required String address,
    String? imageUrl,
  }) async {
    try {
      final merchantData = {
        'id': id,
        'name': name,
        'store_name': storeName,
        'email': email,
        'phone': phone,
        'category': category,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': true,
        'store_image_url': imageUrl,
        'type': 'merchant',
        'location': {
          'address': address,
          'latitude': 0.0,
          'longitude': 0.0,
        },
        'working_hours': {
          'from': '09:00',
          'to': '23:00',
        },
        'settings': {
          'auto_accept_orders': false,
          'delivery_fee': 0,
          'min_order_amount': 0,
          'delivery_radius': 5000,
        },
        'statistics': {
          'total_orders': 0,
          'completed_orders': 0,
          'total_revenue': 0,
          'rating': 0,
          'total_ratings': 0,
        }
      };

      // Create merchant profile
      await _supabase.from('profiles').insert([merchantData]);

      // Create store
      final storeData = {
        'name': storeName,
        'description': '',
        'owner_id': id,
        'logo': imageUrl,
        'category': category,
        'address': address,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('stores').insert([storeData]);

      debugPrint('✅ Merchant profile saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving merchant profile: $e');
      throw Exception('Failed to save merchant profile: $e');
    }
  }

  /// Delete a store image from Supabase storage
  static Future<void> deleteStoreImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.indexOf('store_images') + 1).join('/');

      await _supabase.storage.from('store_images').remove([filePath]);
      debugPrint('✅ Store image deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting store image: $e');
      // Don't throw here, just log the error as image deletion is not critical
    }
  }
}
