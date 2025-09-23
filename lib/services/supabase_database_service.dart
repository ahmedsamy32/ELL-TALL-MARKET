import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/models/coupon_model.dart';

class SupabaseDatabaseService {
  final _client = Supabase.instance.client;

  // ==================== Products ====================
  Future<List<ProductModel>> getProducts({
    String? category,
    String? storeId,
    bool onlyAvailable = true,
  }) async {
    try {
      var query = _client.from('products').select('''
        *,
        store:store_id (*),
        category:category_id (*)
      ''');

      if (category != null) {
        query = query.eq('category', category);
      }
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      if (onlyAvailable) {
        query = query.eq('is_available', true);
      }

      final List<dynamic> response = await query;
      return response.map((data) => ProductModel.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب المنتجات: $e');
      return [];
    }
  }

  Future<ProductModel?> getProductById(String id) async {
    try {
      final Map<String, dynamic> response = await _client
          .from('products')
          .select('''
            *,
            store:store_id (*),
            category:category_id (*)
          ''')
          .eq('id', id)
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب المنتج: $e');
      return null;
    }
  }

  Future<String?> addProduct(ProductModel product) async {
    try {
      final response = await _client
          .from('products')
          .insert(product.toJson())
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في إضافة المنتج: $e');
      return null;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    try {
      await _client
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في تحديث المنتج: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _client
          .from('products')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في حذف المنتج: $e');
      return false;
    }
  }

  // ==================== Orders ====================
  Future<List<OrderModel>> getOrders({
    String? userId,
    String? storeId,
    String? captainId,
    String? status,
  }) async {
    try {
      var query = _client.from('orders').select('''
        *,
        items:order_items (*),
        user:user_id (*),
        store:store_id (*),
        captain:captain_id (*)
      ''');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      if (captainId != null) {
        query = query.eq('captain_id', captainId);
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      final List<dynamic> response = await query;
      return response.map((data) => OrderModel.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب الطلبات: $e');
      return [];
    }
  }

  Future<String?> createOrder(OrderModel order) async {
    try {
      final response = await _client
          .from('orders')
          .insert(order.toJson())
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في إنشاء الطلب: $e');
      return null;
    }
  }

  Future<bool> updateOrder(OrderModel order) async {
    try {
      await _client
          .from('orders')
          .update(order.toJson())
          .eq('id', order.id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في تحديث الطلب: $e');
      return false;
    }
  }

  // ==================== Categories ====================
  Future<List<CategoryModel>> getCategories({bool? isActive}) async {
    try {
      var query = _client.from('categories').select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final List<dynamic> response = await query;
      return response.map((data) => CategoryModel.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب الفئات: $e');
      return [];
    }
  }

  Future<String?> addCategory(CategoryModel category) async {
    try {
      final response = await _client
          .from('categories')
          .insert(category.toJson())
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في إضافة الفئة: $e');
      return null;
    }
  }

  // ==================== Coupons ====================
  Future<List<CouponModel>> getCoupons({
    String? storeId,
    bool? isActive,
  }) async {
    try {
      var query = _client.from('coupons').select('''
        *,
        store:store_id (*)
      ''');

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final List<dynamic> response = await query;
      return response.map((data) => CouponModel.fromJson(data as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب الكوبونات: $e');
      return [];
    }
  }

  Future<CouponModel?> getCouponByCode(String code) async {
    try {
      final Map<String, dynamic> response = await _client
          .from('coupons')
          .select('''
            *,
            store:store_id (*)
          ''')
          .eq('code', code)
          .single();

      return CouponModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب الكوبون: $e');
      return null;
    }
  }

  Future<bool> useCoupon(String couponId, String userId, String orderId, double discountAmount) async {
    try {
      // إضافة استخدام الكوبون
      await _client.from('coupon_usages').insert({
        'coupon_id': couponId,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });

      // تحديث عدد مرات استخدام الكوبون
      await _client.rpc('increment_coupon_usage', params: {
        'coupon_id': couponId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في استخدام الكوبون: $e');
      return false;
    }
  }

  // ==================== Reviews ====================
  Future<double> getProductRating(String productId) async {
    try {
      final response = await _client.rpc(
        'get_product_rating',
        params: {'product_id': productId},
      );
      return response as double? ?? 0.0;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في جلب تقييم المنتج: $e');
      return 0.0;
    }
  }

  Future<bool> addReview({
    required String productId,
    required String userId,
    required int rating,
    String? comment,
    List<String>? images,
  }) async {
    try {
      await _client.from('reviews').insert({
        'product_id': productId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'images': images,
      });

      // تحديث متوسط التقييم وعدد التقييمات للمنتج
      await _client.rpc('update_product_rating', params: {
        'product_id': productId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseDatabaseService] خطأ في إضافة التقييم: $e');
      return false;
    }
  }
}
