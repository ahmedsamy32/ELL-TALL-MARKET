import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model.dart';
import '../core/logger.dart';

/// خدمة البانرات الإعلانية المحسنة
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
/// تدعم العمليات الفورية والتحليلات المتقدمة
///
/// ⚠️ ملاحظة مهمة: التحكم في البانرات (إضافة، تعديل، حذف) للـ Admin فقط
/// - المستخدمون العاديون: يمكنهم فقط مشاهدة البانرات النشطة
/// - الـ Admin: له صلاحية كاملة على جميع البانرات
class BannerService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ================================
  // 📢 Banner Retrieval Operations
  // ================================

  /// جلب جميع البانرات
  static Future<List<BannerModel>> getAllBanners({
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase.from('banners').select();

      if (activeOnly) {
        query = query
            .eq('is_active', true)
            .lte('start_date', DateTime.now().toIso8601String());
      }

      final response = await query
          .order('priority', ascending: false)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      final banners = (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();

      AppLogger.info('تم جلب ${banners.length} بانر');
      return banners;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب البانرات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب البانرات', e);
      return [];
    }
  }

  /// جلب البانرات النشطة فقط
  static Future<List<BannerModel>> getActiveBanners({
    BannerPosition? position,
    BannerType? type,
  }) async {
    try {
      var query = _supabase
          .from('banners')
          .select()
          .eq('is_active', true)
          .lte('start_date', DateTime.now().toIso8601String());

      // فلترة حسب الموضع
      if (position != null) {
        query = query.eq('position', position.value);
      }

      // فلترة حسب النوع
      if (type != null) {
        query = query.eq('target_type', type.value);
      }

      final response = await query
          .order('priority', ascending: false)
          .order('display_order', ascending: true);

      final banners = (response as List)
          .map((data) => BannerModel.fromMap(data))
          .where((banner) {
            // فلترة البانرات المنتهية
            if (banner.endDate != null &&
                banner.endDate!.isBefore(DateTime.now())) {
              return false;
            }
            return true;
          })
          .toList();

      AppLogger.info('تم جلب ${banners.length} بانر نشط');
      return banners;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب البانرات النشطة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب البانرات النشطة', e);
      return [];
    }
  }

  /// جلب بانر واحد حسب المعرف
  static Future<BannerModel?> getBannerById(String bannerId) async {
    try {
      final response = await _supabase
          .from('banners')
          .select()
          .eq('id', bannerId)
          .single();

      return BannerModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب البانر: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب البانر', e);
      return null;
    }
  }

  /// جلب بانرات التاجر (للعرض فقط - التحكم للـ Admin)
  /// ملاحظة: البانرات يمكن أن تكون مرتبطة بتاجر معين لكن التحكم للـ Admin فقط
  static Future<List<BannerModel>> getBannersByMerchant(
    String merchantId,
  ) async {
    try {
      final response = await _supabase
          .from('banners')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final banners = (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();

      AppLogger.info(
        'تم جلب ${banners.length} بانر مرتبط بالتاجر: $merchantId',
      );
      return banners;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب بانرات التاجر: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب بانرات التاجر', e);
      return [];
    }
  }

  // ================================
  // 📝 Banner Management Operations
  // ⚠️ للـ Admin فقط - يتطلب role = 'admin'
  // ================================

  /// إضافة بانر جديد (Admin فقط)
  /// يتطلب: auth.jwt() ->> 'role' = 'admin'
  static Future<BannerModel?> createBanner(BannerModel banner) async {
    try {
      final response = await _supabase
          .from('banners')
          .insert(banner.toJson())
          .select()
          .single();

      final newBanner = BannerModel.fromMap(response);
      AppLogger.info('تم إنشاء بانر جديد: ${newBanner.id}');
      return newBanner;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء البانر: ${e.message}', e);
      throw Exception('فشل إنشاء البانر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء البانر', e);
      throw Exception('فشل إنشاء البانر: ${e.toString()}');
    }
  }

  /// تحديث بانر موجود (Admin فقط)
  /// يتطلب: auth.jwt() ->> 'role' = 'admin'
  static Future<BannerModel?> updateBanner(
    String bannerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // إضافة updated_at تلقائياً
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('banners')
          .update(updates)
          .eq('id', bannerId)
          .select()
          .single();

      final updatedBanner = BannerModel.fromMap(response);
      AppLogger.info('تم تحديث البانر: $bannerId');
      return updatedBanner;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث البانر: ${e.message}', e);
      throw Exception('فشل تحديث البانر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث البانر', e);
      throw Exception('فشل تحديث البانر: ${e.toString()}');
    }
  }

  /// تبديل حالة تفعيل البانر (Admin فقط)
  /// يتطلب: auth.jwt() ->> 'role' = 'admin'
  static Future<bool> toggleBannerStatus(String bannerId, bool isActive) async {
    try {
      await _supabase
          .from('banners')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bannerId);

      AppLogger.info(
        'تم ${isActive ? "تفعيل" : "إلغاء تفعيل"} البانر: $bannerId',
      );
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تغيير حالة البانر: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة البانر', e);
      return false;
    }
  }

  /// حذف بانر (Admin فقط)
  /// يتطلب: auth.jwt() ->> 'role' = 'admin'
  static Future<bool> deleteBanner(String bannerId) async {
    try {
      await _supabase.from('banners').delete().eq('id', bannerId);

      AppLogger.info('تم حذف البانر: $bannerId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف البانر: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في حذف البانر', e);
      return false;
    }
  }

  /// حذف عدة بانرات (Admin فقط)
  /// يتطلب: auth.jwt() ->> 'role' = 'admin'
  static Future<int> deleteBanners(List<String> bannerIds) async {
    int deletedCount = 0;

    try {
      for (final id in bannerIds) {
        final success = await deleteBanner(id);
        if (success) deletedCount++;
      }

      AppLogger.info('تم حذف $deletedCount من ${bannerIds.length} بانر');
      return deletedCount;
    } catch (e) {
      AppLogger.error('خطأ في حذف البانرات', e);
      return deletedCount;
    }
  }

  // ================================
  // 📊 Banner Analytics Operations
  // ================================

  /// زيادة عداد المشاهدات
  static Future<bool> incrementViewCount(String bannerId) async {
    try {
      await _supabase.rpc(
        'increment_banner_view',
        params: {'banner_uuid': bannerId},
      );

      AppLogger.info('تم زيادة عداد المشاهدات للبانر: $bannerId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في زيادة عداد المشاهدات: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في زيادة عداد المشاهدات', e);
      return false;
    }
  }

  /// زيادة عداد النقرات
  static Future<bool> incrementClickCount(String bannerId) async {
    try {
      await _supabase.rpc(
        'increment_banner_click',
        params: {'banner_uuid': bannerId},
      );

      AppLogger.info('تم زيادة عداد النقرات للبانر: $bannerId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في زيادة عداد النقرات: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في زيادة عداد النقرات', e);
      return false;
    }
  }

  /// الحصول على إحصائيات البانر
  static Future<Map<String, dynamic>> getBannerStats(String bannerId) async {
    try {
      final banner = await getBannerById(bannerId);
      if (banner == null) {
        throw Exception('البانر غير موجود');
      }

      // ملاحظة: viewCount و clickCount غير موجودة في Schema الحالي
      // يمكن إضافتها لاحقاً إذا لزم الأمر

      return {
        'banner_id': bannerId,
        'views': 0, // سيتم تنفيذها لاحقاً
        'clicks': 0, // سيتم تنفيذها لاحقاً
        'ctr': '0.00%', // Click-Through Rate
        'is_active': banner.isActive,
        'created_at': banner.createdAt,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات البانر', e);
      return {};
    }
  }

  /// الحصول على أفضل البانرات أداءً
  static Future<List<BannerModel>> getTopPerformingBanners({
    int limit = 10,
    String sortBy = 'clicks', // 'clicks', 'views', 'ctr'
  }) async {
    try {
      String orderColumn;
      switch (sortBy) {
        case 'views':
          orderColumn = 'view_count';
          break;
        case 'clicks':
          orderColumn = 'click_count';
          break;
        default:
          orderColumn = 'click_count';
      }

      final response = await _supabase
          .from('banners')
          .select()
          .order(orderColumn, ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب أفضل البانرات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب أفضل البانرات', e);
      return [];
    }
  }

  // ================================
  // 🔍 Search and Filter Operations
  // ================================

  /// البحث في البانرات
  static Future<List<BannerModel>> searchBanners(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllBanners();
      }

      final response = await _supabase
          .from('banners')
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في البحث عن البانرات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في البحث عن البانرات', e);
      return [];
    }
  }

  /// فلترة البانرات حسب معايير متعددة
  static Future<List<BannerModel>> filterBanners({
    BannerType? type,
    BannerPosition? position,
    bool? isActive,
    String? merchantId,
    DateTime? startDateFrom,
    DateTime? startDateTo,
  }) async {
    try {
      var query = _supabase.from('banners').select();

      if (type != null) {
        query = query.eq('target_type', type.value);
      }

      // position غير موجود في Schema الحالي
      // if (position != null) {
      //   query = query.eq('position', position.value);
      // }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (merchantId != null) {
        query = query.eq('merchant_id', merchantId);
      }

      if (startDateFrom != null) {
        query = query.gte('start_date', startDateFrom.toIso8601String());
      }

      if (startDateTo != null) {
        query = query.lte('start_date', startDateTo.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في فلترة البانرات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في فلترة البانرات', e);
      return [];
    }
  }

  // ================================
  // 📅 Banner Scheduling Operations
  // ================================

  /// جلب البانرات المجدولة
  static Future<List<BannerModel>> getScheduledBanners() async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('banners')
          .select()
          .gt('start_date', now)
          .order('start_date', ascending: true);

      return (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب البانرات المجدولة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب البانرات المجدولة', e);
      return [];
    }
  }

  /// جلب البانرات المنتهية
  static Future<List<BannerModel>> getExpiredBanners() async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('banners')
          .select()
          .not('end_date', 'is', null)
          .lt('end_date', now)
          .order('end_date', ascending: false);

      return (response as List)
          .map((data) => BannerModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب البانرات المنتهية: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب البانرات المنتهية', e);
      return [];
    }
  }

  // ================================
  // 🔄 Real-time Operations
  // ================================

  /// الاشتراك في تحديثات البانرات الفورية
  static RealtimeChannel subscribeToActiveBanners(
    Function(List<BannerModel>) onBannersChanged,
  ) {
    final channel = _supabase
        .channel('active_banners')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'banners',
          callback: (payload) async {
            AppLogger.info('تحديث في البانرات: ${payload.eventType}');
            final banners = await getActiveBanners();
            onBannersChanged(banners);
          },
        )
        .subscribe();

    AppLogger.info('تم الاشتراك في تحديثات البانرات الفورية');
    return channel;
  }

  /// إلغاء الاشتراك في التحديثات الفورية
  static Future<void> unsubscribeFromBanners(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
    AppLogger.info('تم إلغاء الاشتراك في تحديثات البانرات');
  }
}
