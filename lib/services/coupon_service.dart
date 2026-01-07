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
  });

  Map<String, dynamic> toMap() {
    return {
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
}
