import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/core/logger.dart';

class CouponInput {
  final String name;
  final String code;
  final CouponType couponType;
  final double discountValue;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;
  final int? usageLimit;
  final int usageLimitPerUser;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final String? description;

  // ── الحقول الجديدة ──
  final List<String> productIds;
  final List<QuantityTier> quantityTiers;
  final int? activeHoursStart;
  final int? activeHoursEnd;

  const CouponInput({
    required this.name,
    required this.code,
    required this.couponType,
    required this.discountValue,
    this.minimumOrderAmount = 0,
    this.maximumDiscountAmount,
    this.usageLimit,
    this.usageLimitPerUser = 1,
    required this.validFrom,
    this.validUntil,
    this.isActive = true,
    this.description,
    this.productIds = const [],
    this.quantityTiers = const [],
    this.activeHoursStart,
    this.activeHoursEnd,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'description': description,
      'coupon_type': couponType.value,
      'discount_value': discountValue,
      'minimum_order_amount': minimumOrderAmount,
      'maximum_discount_amount': maximumDiscountAmount,
      'usage_limit': usageLimit,
      'usage_limit_per_user': usageLimitPerUser,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'is_active': isActive,
    };

    // أضف الحقول الجديدة فقط عند الحاجة
    if (productIds.isNotEmpty) {
      map['product_ids'] = jsonEncode(productIds);
    }
    if (quantityTiers.isNotEmpty) {
      map['quantity_tiers'] = jsonEncode(
        quantityTiers.map((t) => t.toMap()).toList(),
      );
    }
    if (activeHoursStart != null) {
      map['active_hours_start'] = activeHoursStart;
    }
    if (activeHoursEnd != null) {
      map['active_hours_end'] = activeHoursEnd;
    }

    return map;
  }
}

class CouponService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<String?> findStoreIdForMerchant(String merchantId) async {
    try {
      final response = await _client
          .from('stores')
          .select('id')
          .eq('merchant_id', merchantId)
          .limit(1)
          .maybeSingle();

      return response == null ? null : response['id'] as String;
    } catch (e) {
      AppLogger.error('فشل في جلب معرف المتجر للتاجر $merchantId', e);
      return null;
    }
  }

  /// جلب جميع الكوبونات (للأدمن)
  static Future<List<CouponModel>> fetchAllCoupons() async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .select('*')
          .order('created_at', ascending: false);
      return (response as List)
          .map((row) => CouponModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('فشل في جلب جميع الكوبونات', e);
      rethrow;
    }
  }

  /// جلب أسماء المتاجر من قائمة معرفات (للأدمن)
  static Future<Map<String, String>> fetchStoreNames(
    List<String> storeIds,
  ) async {
    if (storeIds.isEmpty) return {};
    try {
      final response = await _client
          .from('stores')
          .select('id, name')
          .inFilter('id', storeIds);
      final map = <String, String>{};
      for (final row in response as List) {
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id != null && name != null) map[id] = name;
      }
      return map;
    } catch (e) {
      AppLogger.error('فشل في جلب أسماء المتاجر', e);
      return {};
    }
  }

  /// إنشاء كوبون عام بواسطة الأدمن (بدون متجر محدد)
  static Future<CouponModel> createAdminCoupon({
    required CouponInput input,
    required String createdBy,
  }) async {
    try {
      final payload = input.toMap()..addAll({'created_by': createdBy});
      final response = await _client
          .from(CouponModel.tableName)
          .insert(payload)
          .select()
          .single();
      return CouponModel.fromMap(response);
    } catch (e) {
      AppLogger.error('فشل في إنشاء كوبون الأدمن ${input.code}', e);
      rethrow;
    }
  }

  static Future<List<CouponModel>> fetchCouponsByStore(String storeId) async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .select('*')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => CouponModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('فشل في جلب الكوبونات للمتجر $storeId', e);
      rethrow;
    }
  }

  static Future<CouponModel> createCoupon({
    required CouponInput input,
    required String storeId,
    required String merchantId,
    required String createdBy,
  }) async {
    try {
      final payload = input.toMap()
        ..addAll({
          'store_id': storeId,
          'merchant_id': merchantId,
          'created_by': createdBy,
        });

      final response = await _client
          .from(CouponModel.tableName)
          .insert(payload)
          .select()
          .single();

      return CouponModel.fromMap(response);
    } catch (e) {
      AppLogger.error('فشل في إنشاء الكوبون ${input.code}', e);
      rethrow;
    }
  }

  static Future<CouponModel> updateCoupon({
    required String couponId,
    required CouponInput input,
  }) async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .update(input.toMap())
          .eq('id', couponId)
          .select()
          .single();

      return CouponModel.fromMap(response);
    } catch (e) {
      AppLogger.error('فشل في تحديث الكوبون $couponId', e);
      rethrow;
    }
  }

  static Future<bool> toggleCouponStatus({
    required String couponId,
    required bool isActive,
  }) async {
    try {
      await _client
          .from(CouponModel.tableName)
          .update({'is_active': isActive})
          .eq('id', couponId);
      return true;
    } catch (e) {
      AppLogger.error('فشل في تغيير حالة الكوبون $couponId', e);
      return false;
    }
  }

  static Future<bool> deleteCoupon(String couponId) async {
    try {
      await _client.from(CouponModel.tableName).delete().eq('id', couponId);
      return true;
    } catch (e) {
      AppLogger.error('فشل في حذف الكوبون $couponId', e);
      return false;
    }
  }

  static Future<CouponModel?> validateCoupon(String code) async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .select()
          .eq('code', code.trim().toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      final coupon = CouponModel.fromMap(response);
      return coupon.canBeUsed ? coupon : null;
    } catch (e) {
      AppLogger.error('Error validating coupon code $code', e);
      return null;
    }
  }

  /// جلب معرّفات المتاجر التي لديها كوبونات فعّالة حالياً
  static Future<Set<String>> fetchStoreIdsWithActiveCoupons() async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .select('store_id')
          .eq('is_active', true)
          .not('store_id', 'is', null);

      final storeIds = <String>{};

      for (final row in (response as List)) {
        final storeId = row['store_id'] as String?;
        if (storeId != null && storeId.isNotEmpty) {
          storeIds.add(storeId);
        }
      }

      return storeIds;
    } catch (e) {
      AppLogger.error('فشل في جلب معرّفات المتاجر ذات الكوبونات الفعّالة', e);
      return {};
    }
  }

  /// جلب الكوبونات الفعّالة مجمّعة حسب المتجر (store_id → أفضل كوبون)
  static Future<Map<String, CouponModel>> fetchBestCouponPerStore() async {
    try {
      final coupons = await fetchActiveCoupons();
      final bestPerStore = <String, CouponModel>{};

      for (final coupon in coupons) {
        if (coupon.storeId == null) continue;
        final existing = bestPerStore[coupon.storeId!];
        if (existing == null || coupon.discountValue > existing.discountValue) {
          bestPerStore[coupon.storeId!] = coupon;
        }
      }

      return bestPerStore;
    } catch (e) {
      AppLogger.error('فشل في جلب أفضل كوبون لكل متجر', e);
      return {};
    }
  }

  /// جلب جميع القسائم النشطة المتاحة للمستخدم
  static Future<List<CouponModel>> fetchActiveCoupons() async {
    try {
      final response = await _client
          .from(CouponModel.tableName)
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      return (response as List)
          .map((row) => CouponModel.fromMap(row as Map<String, dynamic>))
          .where(
            (coupon) =>
                now.isAfter(coupon.validFrom) &&
                (coupon.validUntil == null ||
                    now.isBefore(coupon.validUntil!)) &&
                (coupon.usageLimit == null ||
                    coupon.usedCount < coupon.usageLimit!),
          )
          .toList();
    } catch (e) {
      AppLogger.error('فشل في جلب القسائم النشطة', e);
      rethrow;
    }
  }

  /// جلب القسائم المستخدمة من قبل المستخدم الحالي
  static Future<List<Map<String, dynamic>>> fetchUserCouponUsage(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('coupon_usage')
          .select('*, coupons(*)')
          .eq('user_id', userId)
          .order('used_at', ascending: false);

      return (response as List)
          .map((row) => row as Map<String, dynamic>)
          .toList();
    } catch (e) {
      AppLogger.error('فشل في جلب سجل استخدام القسائم للمستخدم $userId', e);
      rethrow;
    }
  }

  /// جلب كل المنتجات مع أسماء متاجرها (للاستخدام في فورم الكوبون الإداري)
  static Future<List<Map<String, dynamic>>> fetchAllProductsWithStore() async {
    try {
      final response = await _client
          .from('products')
          .select('id, name, price, store_id, stores(name)')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((row) => row as Map<String, dynamic>)
          .toList();
    } catch (e) {
      AppLogger.error('فشل في جلب المنتجات مع أسماء المتاجر', e);
      rethrow;
    }
  }

  /// تسجيل استخدام كوبون
  static Future<bool> recordCouponUsage({
    required String couponId,
    required String userId,
    required String orderId,
    required double discountAmount,
  }) async {
    try {
      await _client.from('coupon_usage').insert({
        'coupon_id': couponId,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });

      // تحديث عداد الاستخدام
      await _client.rpc(
        'increment_coupon_used_count',
        params: {'coupon_id_param': couponId},
      );

      return true;
    } catch (e) {
      AppLogger.error('فشل في تسجيل استخدام الكوبون $couponId', e);
      return false;
    }
  }
}
