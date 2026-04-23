// ignore_for_file: depend_on_referenced_packages

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/review_model.dart';
import 'package:ell_tall_market/core/logger.dart';

class RatingService {
  final SupabaseClient _supabase;

  RatingService(this._supabase);

  // ─────────────────────────────────────────────
  // 🔄 إعادة حساب تقييم المنتج وتحديثه في قاعدة البيانات
  // ─────────────────────────────────────────────
  Future<void> recalculateProductRating(String productId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);

      final reviews = response as List;
      final reviewCount = reviews.length;
      final avgRating = reviewCount > 0
          ? reviews.fold<double>(
                  0,
                  (sum, r) => sum + (r['rating'] as num).toDouble(),
                ) /
                reviewCount
          : 0.0;

      // تقريب لرقم عشري واحد
      final roundedRating = double.parse(avgRating.toStringAsFixed(1));

      await _supabase
          .from('products')
          .update({
            'rating': roundedRating,
            'review_count': reviewCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      AppLogger.info(
        '⭐ تم تحديث تقييم المنتج $productId: $roundedRating ($reviewCount تقييم)',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث تقييم المنتج $productId', e);
    }
  }

  // ─────────────────────────────────────────────
  // 🔄 إعادة حساب تقييم المتجر من تقييمات منتجاته
  // ─────────────────────────────────────────────
  Future<void> recalculateStoreRating(String storeId) async {
    try {
      // جلب كل المنتجات الخاصة بالمتجر
      final productsResponse = await _supabase
          .from('products')
          .select('id')
          .eq('store_id', storeId);

      final productIds = (productsResponse as List)
          .map((p) => p['id'] as String)
          .toList();

      if (productIds.isEmpty) return;

      // جلب كل التقييمات على منتجات المتجر
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('rating')
          .inFilter('product_id', productIds);

      final reviews = reviewsResponse as List;
      final reviewCount = reviews.length;
      final avgRating = reviewCount > 0
          ? reviews.fold<double>(
                  0,
                  (sum, r) => sum + (r['rating'] as num).toDouble(),
                ) /
                reviewCount
          : 0.0;

      final roundedRating = double.parse(avgRating.toStringAsFixed(1));

      await _supabase
          .from('stores')
          .update({
            'rating': roundedRating,
            'review_count': reviewCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', storeId);

      AppLogger.info(
        '🏪 تم تحديث تقييم المتجر $storeId: $roundedRating ($reviewCount تقييم)',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث تقييم المتجر $storeId', e);
    }
  }

  // ─────────────────────────────────────────────
  // 🔄 إعادة حساب تقييم المنتج + المتجر معاً
  // ─────────────────────────────────────────────
  Future<void> recalculateRatingsForProduct(String productId) async {
    await recalculateProductRating(productId);

    // جلب store_id من المنتج لتحديث تقييم المتجر
    try {
      final product = await _supabase
          .from('products')
          .select('store_id')
          .eq('id', productId)
          .maybeSingle();

      if (product != null && product['store_id'] != null) {
        await recalculateStoreRating(product['store_id'] as String);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب store_id للمنتج $productId', e);
    }
  }

  Future<String?> _findExistingReviewId(ReviewModel review) async {
    final query = _supabase
        .from(ReviewModel.tableName)
        .select('id')
        .eq('user_id', review.userId)
        .eq('order_id', review.orderId);

    if (review.productId != null) {
      final response = await query
          .eq('product_id', review.productId!)
          .order('created_at', ascending: false)
          .limit(1);
      return (response as List).isNotEmpty
          ? (response.first['id'] as String)
          : null;
    }

    if (review.storeId != null) {
      final response = await query
          .eq('store_id', review.storeId!)
          .order('created_at', ascending: false)
          .limit(1);
      return (response as List).isNotEmpty
          ? (response.first['id'] as String)
          : null;
    }

    return null;
  }

  Future<void> _removeDuplicateReviews(
    ReviewModel review,
    String keepId,
  ) async {
    final query = _supabase
        .from(ReviewModel.tableName)
        .delete()
        .neq('id', keepId)
        .eq('user_id', review.userId)
        .eq('order_id', review.orderId);

    if (review.productId != null) {
      await query.eq('product_id', review.productId!);
      return;
    }

    if (review.storeId != null) {
      await query.eq('store_id', review.storeId!);
    }
  }

  /// Submit a single review for a product or store
  Future<ReviewModel?> submitReview(ReviewModel review) async {
    try {
      final existingId = await _findExistingReviewId(review);

      final Map<String, dynamic> payload = {
        'rating': review.rating,
        if (review.comment != null && review.comment!.isNotEmpty)
          'comment': review.comment,
      };

      final response = existingId == null
          ? await _supabase
                .from(ReviewModel.tableName)
                .insert(review.toDatabaseMap())
                .select()
                .single()
          : await _supabase
                .from(ReviewModel.tableName)
                .update(payload)
                .eq('id', existingId)
                .select()
                .single();

      if (existingId != null) {
        await _removeDuplicateReviews(review, existingId);
      }

      final submittedReview = ReviewModel.fromMap(response);

      // ⭐ تحديث تقييم المنتج والمتجر بعد إرسال التقييم
      if (review.productId != null) {
        await recalculateRatingsForProduct(review.productId!);
      }

      return submittedReview;
    } catch (e, stack) {
      AppLogger.error('Error submitting review', e, stack);
      rethrow;
    }
  }

  /// Submit multiple reviews at once (e.g. for an entire order)
  Future<List<ReviewModel>> submitBatchReviews(
    List<ReviewModel> reviews,
  ) async {
    try {
      final List<ReviewModel> results = [];
      final Set<String> updatedProductIds = {};

      for (final review in reviews) {
        final existingId = await _findExistingReviewId(review);
        final Map<String, dynamic> payload = {
          'rating': review.rating,
          if (review.comment != null && review.comment!.isNotEmpty)
            'comment': review.comment,
        };

        final response = existingId == null
            ? await _supabase
                  .from(ReviewModel.tableName)
                  .insert(review.toDatabaseMap())
                  .select()
                  .single()
            : await _supabase
                  .from(ReviewModel.tableName)
                  .update(payload)
                  .eq('id', existingId)
                  .select()
                  .single();

        if (existingId != null) {
          await _removeDuplicateReviews(review, existingId);
        }

        results.add(ReviewModel.fromMap(response));

        // تجميع المنتجات اللي اتعمل لها تقييم
        if (review.productId != null) {
          updatedProductIds.add(review.productId!);
        }
      }

      // ⭐ إعادة حساب تقييمات كل المنتجات والمتاجر المتأثرة
      final Set<String> updatedStoreIds = {};
      for (final productId in updatedProductIds) {
        await recalculateProductRating(productId);

        // جلب store_id لكل منتج
        try {
          final product = await _supabase
              .from('products')
              .select('store_id')
              .eq('id', productId)
              .maybeSingle();
          if (product != null && product['store_id'] != null) {
            updatedStoreIds.add(product['store_id'] as String);
          }
        } catch (_) {}
      }

      // تحديث تقييمات المتاجر (مرة واحدة لكل متجر)
      for (final storeId in updatedStoreIds) {
        await recalculateStoreRating(storeId);
      }

      AppLogger.info(
        '✅ تم إرسال ${results.length} تقييم وتحديث ${updatedProductIds.length} منتج و ${updatedStoreIds.length} متجر',
      );

      return results;
    } catch (e, stack) {
      AppLogger.error('Error submitting batch reviews', e, stack);
      rethrow;
    }
  }

  /// Fetch reviews for a specific product
  Future<List<ReviewModel>> getProductReviews(
    String productId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from(ReviewModel.tableName)
          .select('*, profiles(full_name, avatar_url)')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((e) => ReviewModel.fromMap(e)).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching product reviews', e, stack);
      return [];
    }
  }

  /// Fetch reviews for a specific store
  Future<List<ReviewModel>> getStoreReviews(
    String storeId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from(ReviewModel.tableName)
          .select(
            '*, profiles(full_name, avatar_url), products!inner(name, store_id)',
          )
          .eq('products.store_id', storeId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((e) => ReviewModel.fromMap(e)).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching store reviews', e, stack);
      return [];
    }
  }

  /// Fetch user's product reviews for specific orders
  Future<List<ReviewModel>> getUserProductReviewsForOrders(
    List<String> orderIds,
    String userId,
  ) async {
    if (orderIds.isEmpty) return [];
    try {
      final response = await _supabase
          .from(ReviewModel.tableName)
          .select()
          .eq('user_id', userId)
          .inFilter('order_id', orderIds)
          .not('product_id', 'is', null);

      return (response as List).map((e) => ReviewModel.fromMap(e)).toList();
    } catch (e, stack) {
      AppLogger.error(
        'Error fetching user product reviews for orders',
        e,
        stack,
      );
      return [];
    }
  }

  /// Get user's review for a specific order (to check if already rated)
  Future<List<ReviewModel>> getOrderReviews(String orderId) async {
    try {
      final response = await _supabase
          .from(ReviewModel.tableName)
          .select()
          .eq('order_id', orderId);

      return (response as List).map((e) => ReviewModel.fromMap(e)).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching order reviews', e, stack);
      return [];
    }
  }
}
