import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final _supabase = Supabase.instance.client;

  // ================= Products =================
  Future<List<Map<String, dynamic>>> _buildProductQuery(
    PostgrestFilterBuilder query, {
    String? category,
    String? search,
    String? storeId,
    int? limit,
    int? offset,
  }) async {
    // Apply filters
    if (category?.isNotEmpty ?? false) {
      query.eq('category', category as Object);
    }
    if (search?.isNotEmpty ?? false) {
      query.ilike('name', '%${search.toString()}%');
    }
    if (storeId?.isNotEmpty ?? false) {
      query.eq('store_id', storeId as Object);
    }

    // Add pagination and ordering
    query.order('created_at', ascending: false);
    query.limit(limit ?? 50);

    if (offset != null) {
      query.range(offset, offset + (limit ?? 50) - 1);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getProducts({
    int? limit,
    int? offset,
    String? category,
    String? search,
    String? storeId,
  }) async {
    try {
      // Start with base query
      final query = _supabase.from('products').select();

      // Apply filters and get results
      return await _buildProductQuery(
        query,
        category: category,
        search: search,
        storeId: storeId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching products: $e');
      rethrow;
    }
  }

  // ================= Categories =================
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _supabase.from('categories').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching categories: $e');
      rethrow;
    }
  }

  // ================= Orders =================
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();
      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error creating order: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, products(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user orders: $e');
      rethrow;
    }
  }

  // ================= Reviews =================
  Future<void> addReview(Map<String, dynamic> reviewData) async {
    try {
      await _supabase.from('reviews').insert(reviewData);
    } catch (e) {
      if (kDebugMode) print('❌ Error adding review: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, profiles(name, avatar_url)')
          .eq('product_id', productId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching product reviews: $e');
      rethrow;
    }
  }

  // ================= Cart & Favorites =================
  Future<void> updateUserCart(String userId, List<Map<String, dynamic>> cartItems) async {
    try {
      await _supabase
          .from('profiles')
          .update({'cart': cartItems})
          .eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error updating cart: $e');
      rethrow;
    }
  }

  Future<void> updateUserFavorites(String userId, List<String> favoriteProductIds) async {
    try {
      await _supabase
          .from('profiles')
          .update({'favorite_products': favoriteProductIds})
          .eq('id', userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error updating favorites: $e');
      rethrow;
    }
  }

  // ================= Stores =================
  Future<List<Map<String, dynamic>>> getStores({
    String? category,
    String? search,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      var query = _supabase.from('stores').select();

      if (category != null) {
        query = query.eq('category', category);
      }

      if (search != null) {
        query = query.ilike('name', '%$search%');
      }

      final response = await query;
      var stores = List<Map<String, dynamic>>.from(response);

      if (latitude != null && longitude != null && radius != null) {
        stores = stores.where((store) {
          final storeLat = store['latitude'] as double;
          final storeLng = store['longitude'] as double;
          final distance = _calculateDistance(latitude, longitude, storeLat, storeLng);
          return distance <= radius;
        }).toList();
      }

      return stores;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching stores: $e');
      rethrow;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0; // Earth radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}
