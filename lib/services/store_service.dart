import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/order_model.dart';
import '../models/store_model.dart';

/// خدمة إدارة المتاجر - نسخة مبسطة متوافقة مع schema قاعدة البيانات
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
class StoreService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  // ================================
  // 🏪 Store CRUD Operations
  // ================================

  /// إنشاء متجر جديد
  static Future<StoreModel?> createStore({
    required String merchantId,
    required String name,
    String? description,
    String? location,
    String? logoUrl,
    bool isActive = true,
  }) async {
    try {
      final storeData = {
        'merchant_id': merchantId,
        'name': name,
        'description': description,
        'location': location,
        'logo_url': logoUrl,
        'is_active': isActive,
        'delivery_mode': 'store',
      };

      final response = await _supabase
          .from('stores')
          .insert(storeData)
          .select()
          .single();

      AppLogger.info('تم إنشاء متجر جديد: ${response['name']}');
      return StoreModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء المتجر: ${e.message}', e);
      throw Exception('فشل إنشاء المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء المتجر', e);
      throw Exception('فشل إنشاء المتجر: ${e.toString()}');
    }
  }

  /// جلب متجر محدد بالتفصيل
  static Future<StoreModel?> getStoreById(String storeId) async {
    try {
      final response = await _supabase
          .from('stores')
          .select()
          .eq('id', storeId)
          .single();

      return StoreModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب المتجر: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب المتجر', e);
      return null;
    }
  }

  /// جلب جميع المتاجر مع دعم Pagination والفلترة
  static Future<List<StoreModel>> getStores({
    int page = 1,
    String? searchTerm,
    bool activeOnly = true,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase.from('stores').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%,location.ilike.%$searchTerm%',
        );
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب المتاجر: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب المتاجر', e);
      return [];
    }
  }

  /// جلب متاجر المالك/التاجر
  static Future<List<StoreModel>> getMerchantStores(String merchantId) async {
    try {
      AppLogger.info('Fetching stores for merchant: $merchantId');

      final response = await _supabase
          .from('stores')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final stores = (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();

      AppLogger.info('Found ${stores.length} stores');
      if (stores.isNotEmpty) {
        AppLogger.info('   First store ID: ${stores.first.id}');
      }

      return stores;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب متاجر التاجر: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب متاجر التاجر', e);
      return [];
    }
  }

  /// تحديث معلومات المتجر
  static Future<StoreModel?> updateStore({
    required String storeId,
    String? name,
    String? description,
    String? location,
    String? logoUrl,
    bool? isActive,
    String? deliveryMode,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (location != null) data['location'] = location;
      if (logoUrl != null) data['logo_url'] = logoUrl;
      if (isActive != null) data['is_active'] = isActive;
      if (deliveryMode != null) data['delivery_mode'] = deliveryMode;

      if (data.isEmpty) return await getStoreById(storeId);

      final response = await _supabase
          .from('stores')
          .update(data)
          .eq('id', storeId)
          .select()
          .single();

      AppLogger.info('تم تحديث المتجر: ${response['name']}');
      return StoreModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث المتجر: ${e.message}', e);
      throw Exception('فشل تحديث المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث المتجر', e);
      throw Exception('فشل تحديث المتجر: ${e.toString()}');
    }
  }

  /// حذف متجر
  static Future<bool> deleteStore(String storeId) async {
    try {
      // التحقق من عدم وجود منتجات نشطة
      final products = await _supabase
          .from('products')
          .select('id')
          .eq('store_id', storeId);

      if (products.isNotEmpty) {
        AppLogger.error('لا يمكن حذف المتجر لأنه يحتوي على منتجات', null);
        throw Exception('لا يمكن حذف المتجر لأنه يحتوي على منتجات');
      }

      await _supabase.from('stores').delete().eq('id', storeId);

      AppLogger.info('تم حذف المتجر بنجاح');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف المتجر: ${e.message}', e);
      throw Exception('فشل حذف المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف المتجر', e);
      throw Exception('فشل حذف المتجر: ${e.toString()}');
    }
  }

  // ================================
  // 📊 Store Statistics
  // ================================

  /// إحصائيات أساسية للمتجر
  static Future<Map<String, dynamic>> getStoreStatistics(String storeId) async {
    try {
      // جلب عدد المنتجات
      final products = await _supabase
          .from('products')
          .select('id, is_active')
          .eq('store_id', storeId);

      // جلب الطلبات من جدول orders حسب merchant_id
      final store = await getStoreById(storeId);
      if (store == null) return {};

      final orders = await _supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', store.merchantId);

      // حساب الإحصائيات
      final totalProducts = products.length;
      final activeProducts = products
          .where((p) => p['is_active'] == true)
          .length;
      final totalOrders = orders.length;

      final completedOrders = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .toList();

      final pendingOrders = orders
          .where((o) => o['status'] == OrderStatus.pending.value)
          .length;

      final totalRevenue = completedOrders.fold<double>(
        0.0,
        (sum, o) => sum + ((o['total_price'] as num?)?.toDouble() ?? 0.0),
      );

      return {
        'store_name': store.name,
        'total_products': totalProducts,
        'active_products': activeProducts,
        'inactive_products': totalProducts - activeProducts,
        'total_orders': totalOrders,
        'completed_orders': completedOrders.length,
        'pending_orders': pendingOrders,
        'total_revenue': totalRevenue,
        'average_order_value': totalOrders > 0
            ? totalRevenue / totalOrders
            : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب إحصائيات المتجر: ${e.message}', e);
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات المتجر', e);
      return {};
    }
  }

  /// البحث في المتاجر
  static Future<List<StoreModel>> searchStores({
    required String query,
    bool activeOnly = true,
    int limit = 20,
  }) async {
    try {
      var dbQuery = _supabase.from('stores').select();

      if (activeOnly) {
        dbQuery = dbQuery.eq('is_active', true);
      }

      if (query.isNotEmpty) {
        dbQuery = dbQuery.or(
          'name.ilike.%$query%,description.ilike.%$query%,location.ilike.%$query%',
        );
      }

      final response = await dbQuery.limit(limit);

      return (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في البحث في المتاجر', e);
      return [];
    }
  }

  // ================================
  // 🖼️ Image Management
  // ================================

  /// رفع شعار المتجر
  static Future<String?> uploadStoreLogo({
    required String storeId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول قبل رفع الصور');
      }
      final fileExt = fileName.split('.').last;
      // التوافق مع سياسات bucket "stores": أول مجلد يجب أن يكون userId
      final filePath = '$userId/stores/$storeId/logo.$fileExt';

      // رفع الصورة
      await _supabase.storage
          .from('stores')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // الحصول على الرابط العام
      final imageUrl = _supabase.storage.from('stores').getPublicUrl(filePath);

      // تحديث المتجر بالشعار الجديد
      await updateStore(storeId: storeId, logoUrl: imageUrl);

      AppLogger.info('تم رفع شعار المتجر');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع شعار المتجر: ${e.message}', e);
      throw Exception('فشل رفع شعار المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع شعار المتجر', e);
      throw Exception('فشل رفع شعار المتجر: ${e.toString()}');
    }
  }

  // ================================
  // 🔄 Real-time Operations
  // ================================

  /// مراقبة تحديثات المتاجر فورياً
  static Stream<List<Map<String, dynamic>>> watchStores({String? merchantId}) {
    var query = _supabase.from('stores').stream(primaryKey: ['id']);

    if (merchantId != null) {
      return query.eq('merchant_id', merchantId).order('created_at');
    }

    return query.order('created_at');
  }

  /// مراقبة متجر محدد
  static Stream<Map<String, dynamic>?> watchStore(String storeId) {
    return _supabase
        .from('stores')
        .stream(primaryKey: ['id'])
        .eq('id', storeId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ================================
  // 📈 Advanced Features (للمستقبل)
  // ================================

  /// تفعيل/إيقاف المتجر
  static Future<bool> toggleStoreStatus(String storeId, bool isActive) async {
    try {
      await updateStore(storeId: storeId, isActive: isActive);
      AppLogger.info('تم تغيير حالة المتجر: ${isActive ? 'مفعل' : 'معطل'}');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة المتجر', e);
      return false;
    }
  }

  /// جلب المتاجر النشطة فقط
  static Future<List<StoreModel>> getActiveStores({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المتاجر النشطة', e);
      return [];
    }
  }

  /// تحليل بسيط للأداء
  static Future<Map<String, dynamic>> getSimpleAnalytics(String storeId) async {
    try {
      final stats = await getStoreStatistics(storeId);
      final store = await getStoreById(storeId);

      if (store == null || stats.isEmpty) return {};

      // تحليل بسيط للأداء
      final score = _calculatePerformanceScore(stats);

      return {
        'store_name': store.name,
        'performance_score': score,
        'status': _getStatusFromScore(score),
        'basic_stats': stats,
        'recommendations': _getBasicRecommendations(stats),
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('خطأ في تحليل الأداء', e);
      return {};
    }
  }

  // ================================
  // 🛠️ Helper Functions
  // ================================

  /// حساب نقاط الأداء البسيط
  static double _calculatePerformanceScore(Map<String, dynamic> stats) {
    double score = 0.0;

    // النقاط حسب عدد المنتجات
    final activeProducts = stats['active_products'] as int? ?? 0;
    if (activeProducts >= 10) {
      score += 30;
    } else if (activeProducts >= 5) {
      score += 20;
    } else if (activeProducts >= 1) {
      score += 10;
    }

    // النقاط حسب الطلبات
    final totalOrders = stats['total_orders'] as int? ?? 0;
    if (totalOrders >= 50) {
      score += 40;
    } else if (totalOrders >= 20) {
      score += 30;
    } else if (totalOrders >= 5) {
      score += 20;
    } else if (totalOrders >= 1) {
      score += 10;
    }

    // النقاط حسب الإيرادات
    final revenue = stats['total_revenue'] as double? ?? 0.0;
    if (revenue >= 10000) {
      score += 30;
    } else if (revenue >= 5000) {
      score += 20;
    } else if (revenue >= 1000) {
      score += 15;
    } else if (revenue >= 100) {
      score += 10;
    }

    return score > 100 ? 100 : score;
  }

  /// تحديد الحالة من النقاط
  static String _getStatusFromScore(double score) {
    if (score >= 80) return 'ممتاز';
    if (score >= 60) return 'جيد';
    if (score >= 40) return 'متوسط';
    if (score >= 20) return 'ضعيف';
    return 'جديد';
  }

  /// توصيات أساسية
  static List<String> _getBasicRecommendations(Map<String, dynamic> stats) {
    final recommendations = <String>[];
    final activeProducts = stats['active_products'] as int? ?? 0;
    final totalOrders = stats['total_orders'] as int? ?? 0;

    if (activeProducts == 0) {
      recommendations.add('أضف منتجات لمتجرك لبدء البيع');
    } else if (activeProducts < 5) {
      recommendations.add('أضف المزيد من المنتجات لزيادة المبيعات');
    }

    if (totalOrders == 0) {
      recommendations.add('روج لمتجرك لجذب العملاء الأوائل');
    } else if (totalOrders < 10) {
      recommendations.add('حسن من جودة الخدمة لزيادة الطلبات');
    }

    if (recommendations.isEmpty) {
      recommendations.add('متجرك يسير بشكل جيد، استمر في المحافظة على الجودة');
    }

    return recommendations;
  }

  // ================================
  // 🔧 V2 helpers aligned with current StoreModel
  // ================================

  /// جلب متجر واحد بواسطة merchant_id (قد يكون لكل تاجر متجر واحد)
  static Future<StoreModel?> getStoreByMerchantIdV2(String merchantId) async {
    try {
      final response = await _supabase
          .from('stores')
          .select('*')
          .eq('merchant_id', merchantId)
          .maybeSingle();

      if (response == null) return null;
      return StoreModel.fromSupabaseMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المتجر بواسطة التاجر: ${e.message}',
        e,
      );
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب المتجر بواسطة التاجر', e);
      return null;
    }
  }

  /// تحديث حقول المتجر المتوافقة مع StoreModel الحالي
  static Future<StoreModel?> updateStoreFieldsV2({
    required String storeId,
    String? name,
    String? description,
    String? phone,
    String? governorate,
    String? city,
    String? area,
    String? street,
    String? landmark,
    String? address,
    double? latitude,
    double? longitude,
    int? deliveryTime,
    bool? isOpen,
    double? deliveryFee,
    double? minOrder,
    double? deliveryRadiusKm,
    String? category,
    Map<String, dynamic>? openingHours,
    String? imageUrl,
    String? coverUrl,
    String? deliveryMode,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (phone != null) data['phone'] = phone;
      if (governorate != null) data['governorate'] = governorate;
      if (city != null) data['city'] = city;
      if (area != null) data['area'] = area;
      if (street != null) data['street'] = street;
      if (landmark != null) data['landmark'] = landmark;
      if (address != null) data['address'] = address;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (deliveryTime != null) data['delivery_time'] = deliveryTime;
      if (isOpen != null) data['is_open'] = isOpen;
      if (deliveryFee != null) data['delivery_fee'] = deliveryFee;
      if (minOrder != null) data['min_order'] = minOrder;
      if (deliveryRadiusKm != null) {
        data['delivery_radius_km'] = deliveryRadiusKm;
      }
      if (category != null) data['category'] = category;
      if (openingHours != null) data['opening_hours'] = openingHours;
      if (imageUrl != null) data['image_url'] = imageUrl;
      if (coverUrl != null) data['cover_url'] = coverUrl;
      if (deliveryMode != null) data['delivery_mode'] = deliveryMode;

      final response = await _supabase
          .from('stores')
          .update(data)
          .eq('id', storeId)
          .select('*')
          .single();

      // تحديث حقل location (PostGIS) إذا تم تحديث الإحداثيات
      if (latitude != null && longitude != null) {
        try {
          await _supabase.rpc(
            'sync_store_location',
            params: {
              'store_id_param': storeId,
              'lat': latitude,
              'lng': longitude,
            },
          );
          AppLogger.info('✅ تم تحديث موقع PostGIS للمتجر');
        } catch (e) {
          AppLogger.warning('⚠️ فشل تحديث موقع PostGIS: $e');
        }
      }

      AppLogger.info('✅ تم تحديث المتجر (V2): ${response['name']}');
      return StoreModel.fromSupabaseMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث المتجر (V2): ${e.message}', e);
      throw Exception('فشل تحديث المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث المتجر (V2)', e);
      throw Exception('فشل تحديث المتجر: ${e.toString()}');
    }
  }

  /// رفع صورة (شعار/غلاف) وإرجاع الرابط العام فقط
  /// ملاحظة: لا يقوم هذا التابع بتحديث سجل المتجر تلقائياً
  static Future<String?> uploadStoreImageV2({
    required String storeId,
    required Uint8List bytes,
    required String fileName,
    String type = 'logo',
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول قبل رفع الصور');
      }
      // تحقّق من ملكية المتجر قبل الرفع لتفادي أخطاء RLS 403
      try {
        final owner = await _supabase
            .from('stores')
            .select('merchant_id')
            .eq('id', storeId)
            .single();
        final ownerId = owner['merchant_id'] as String?;
        if (ownerId == null || ownerId != userId) {
          throw Exception(
            'لا يوجد إذن لرفع صور لهذا المتجر (مالك المتجر مختلف)\nuserId=$userId\nstoreId=$storeId\nmerchantId(owner)=$ownerId',
          );
        }
      } catch (e) {
        // في حالة الفشل نُظهر رسالة واضحة بدل رمي خطأ داخلي من RLS
        rethrow;
      }
      final ext = fileName.split('.').last;
      final safeType = (type == 'cover') ? 'cover' : 'logo';
      // السياسات الحالية في bucket 'stores' تتطلب أول مجلد = userId
      // والمسار يحتوي '/stores/{storeId}/'
      final filePath = '$userId/stores/$storeId/$safeType.$ext';

      AppLogger.info(
        'محاولة رفع صورة: type=$type, filePath=$filePath, userId=$userId, storeId=$storeId',
      );

      // استخدم upsert لتحديث الملف إذا كان موجوداً
      await _supabase.storage
          .from('stores')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      AppLogger.info('تم رفع الصورة بنجاح: $filePath');

      final url = _supabase.storage.from('stores').getPublicUrl(filePath);
      // تنظيف أي نسخ قديمة بامتدادات مختلفة لضمان مشاهدة أحدث صورة دائماً
      await _cleanupOldStoreImages(
        userId: userId,
        storeId: storeId,
        type: safeType,
        keepFileName: '$safeType.$ext',
      );
      return url;
    } on StorageException catch (e) {
      // حسّن الرسالة بحالة الخطأ ومسار الملف للمساعدة في تشخيص RLS
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final safeType = (type == 'cover') ? 'cover' : 'logo';
      final ext = fileName.split('.').last;
      final debugPath = (userId != null)
          ? '$userId/stores/$storeId/$safeType.$ext'
          : '(unknown-user)/stores/$storeId/$safeType.$ext';

      final statusRaw = e.statusCode;
      final int? statusCode = statusRaw == null
          ? null
          : int.tryParse(statusRaw.toString());
      final messageLower = e.message.toLowerCase();
      final isRlsBlock =
          (statusCode == 403) || messageLower.contains('row-level');
      final hint = isRlsBlock
          ? '\nتلميح: يبدو أن سياسة RLS للتخزين تمنع العملية.\n- تأكد أن المسار يبدأ بـ userId الصحيح.\n- النمط المطلوب: {userId}/stores/{storeId}/(logo|cover).ext\n- جرّب تطبيق سياسات التخزين في Supabase_schema.sql (قسم STORAGE BUCKETS).'
          : '';

      final detailed =
          'فشل رفع الصورة (code=${statusCode ?? 'unknown'}): ${e.message}\npath=$debugPath';
      AppLogger.error('Storage خطأ في رفع صورة المتجر (V2): $detailed', e);
      throw Exception('$detailed$hint');
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة المتجر (V2)', e);
      rethrow;
    }
  }

  static Future<void> _cleanupOldStoreImages({
    required String userId,
    required String storeId,
    required String type,
    required String keepFileName,
  }) async {
    final folderPath = '$userId/stores/$storeId';
    try {
      final files = await _supabase.storage
          .from('stores')
          .list(path: folderPath);
      for (final file in files) {
        final name = (file as dynamic).name as String?;
        if (name == null) continue;
        if (!name.toLowerCase().startsWith('$type.')) continue;
        if (name == keepFileName) continue;
        final fullPath = '$folderPath/$name';
        await _supabase.storage.from('stores').remove([fullPath]);
        AppLogger.info('🧹 تم حذف النسخة القديمة للصورة: $fullPath');
      }
    } catch (e) {
      AppLogger.error('⚠️ تعذر حذف النسخ القديمة لصور $type: $e', e);
    }
  }

  /// محاولة الحصول على رابط صورة الغلاف المخزنة في التخزين
  /// تعتمد على نمط الحفظ: `{userId}/stores/{storeId}/cover.{ext}` في bucket 'stores'
  static Future<String?> getStoreCoverUrl(String storeId) async {
    try {
      // استخدم مالك المتجر الفعلي بدلاً من المستخدم الحالي لضمان إيجاد الغلاف لأي عارض
      final storeRow = await _supabase
          .from('stores')
          .select('merchant_id, cover_url')
          .eq('id', storeId)
          .single();

      final existingCover = storeRow['cover_url'] as String?;
      if (existingCover != null && existingCover.isNotEmpty) {
        return existingCover;
      }

      final ownerId = storeRow['merchant_id'] as String?;
      if (ownerId == null) return null;
      final basePath = '$ownerId/stores/$storeId';
      final files = await _supabase.storage.from('stores').list(path: basePath);

      String? coverName;
      for (final f in files) {
        try {
          final name = (f as dynamic).name as String?;
          if (name != null && name.toLowerCase().startsWith('cover.')) {
            coverName = name;
            break;
          }
        } catch (_) {
          // تجاهل أخطاء التحويل
        }
      }

      if (coverName == null) return null;
      final url = _supabase.storage
          .from('stores')
          .getPublicUrl('$basePath/$coverName');
      return url;
    } on StorageException catch (e) {
      AppLogger.error(
        'Storage خطأ في قراءة قائمة ملفات الغلاف: ${e.message}',
        e,
      );
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب رابط الغلاف', e);
      return null;
    }
  }

  // ================================
  // 🧩 Settings entities: branches, delivery areas, payment methods, order windows
  // ================================

  // ---- Branches ----
  static Future<List<Map<String, dynamic>>> getStoreBranches(
    String storeId,
  ) async {
    try {
      final res = await _supabase
          .from('store_branches')
          .select('*')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب الفروع: ${e.message}', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addStoreBranch({
    required String storeId,
    required String name,
    required String address,
    String? phone,
    double? latitude,
    double? longitude,
    bool isActive = true,
  }) async {
    try {
      final payload = {
        'store_id': storeId,
        'name': name,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'is_active': isActive,
      }..removeWhere((k, v) => v == null);

      final res = await _supabase
          .from('store_branches')
          .insert(payload)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في إضافة الفرع: ${e.message}', e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateStoreBranch(
    String id,
    Map<String, dynamic> changes,
  ) async {
    try {
      final payload = {
        ...changes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final res = await _supabase
          .from('store_branches')
          .update(payload)
          .eq('id', id)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في تعديل الفرع: ${e.message}', e);
      rethrow;
    }
  }

  static Future<void> deleteStoreBranch(String id) async {
    await _supabase.from('store_branches').delete().eq('id', id);
  }

  // ---- Payment Methods ----
  static Future<List<Map<String, dynamic>>> getStorePaymentMethods(
    String storeId,
  ) async {
    try {
      final res = await _supabase
          .from('store_payment_methods')
          .select('*')
          .eq('store_id', storeId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب وسائل الدفع: ${e.message}', e);
      return [];
    }
  }

  /// method: 'cash' | 'card' | 'wallet'
  static Future<void> setStorePaymentMethod({
    required String storeId,
    required String method,
    required bool isActive,
  }) async {
    final payload = {
      'store_id': storeId,
      'method': method,
      'is_active': isActive,
    };
    await _supabase
        .from('store_payment_methods')
        .upsert(payload, onConflict: 'store_id,method');
  }

  static Future<void> deleteStorePaymentMethod(
    String storeId,
    String method,
  ) async {
    await _supabase.from('store_payment_methods').delete().match({
      'store_id': storeId,
      'method': method,
    });
  }

  // ---- Order Windows ----
  static Future<List<Map<String, dynamic>>> getStoreOrderWindows(
    String storeId,
  ) async {
    try {
      final res = await _supabase
          .from('store_order_windows')
          .select('*')
          .eq('store_id', storeId)
          .order('day_of_week', ascending: true)
          .order('open_time', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب فترات الاستلام: ${e.message}', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addStoreOrderWindow({
    required String storeId,
    required int dayOfWeek, // 0..6
    required String openTime, // HH:MM:SS
    required String closeTime, // HH:MM:SS
    bool isActive = true,
  }) async {
    try {
      final payload = {
        'store_id': storeId,
        'day_of_week': dayOfWeek,
        'open_time': openTime,
        'close_time': closeTime,
        'is_active': isActive,
      };
      final res = await _supabase
          .from('store_order_windows')
          .insert(payload)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في إضافة فترة الاستلام: ${e.message}', e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateStoreOrderWindow(
    String id,
    Map<String, dynamic> changes,
  ) async {
    try {
      final res = await _supabase
          .from('store_order_windows')
          .update(changes)
          .eq('id', id)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في تعديل فترة الاستلام: ${e.message}', e);
      rethrow;
    }
  }

  static Future<void> deleteStoreOrderWindow(String id) async {
    await _supabase.from('store_order_windows').delete().eq('id', id);
  }

  // ---- Store Sections ----
  static Future<List<Map<String, dynamic>>> getStoreSections(
    String storeId,
  ) async {
    try {
      final res = await _supabase
          .from('store_sections')
          .select('*')
          .eq('store_id', storeId)
          .order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب الأقسام: ${e.message}', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addStoreSection({
    required String storeId,
    required String name,
    String? description,
    String? imageUrl,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    try {
      final payload = {
        'store_id': storeId,
        'name': name,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive,
      };
      final res = await _supabase
          .from('store_sections')
          .insert(payload)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في إضافة القسم: ${e.message}', e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateStoreSection(
    String id,
    Map<String, dynamic> changes,
  ) async {
    try {
      final payload = {
        ...changes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final res = await _supabase
          .from('store_sections')
          .update(payload)
          .eq('id', id)
          .select('*')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في تعديل القسم: ${e.message}', e);
      rethrow;
    }
  }

  static Future<void> deleteStoreSection(String id) async {
    await _supabase.from('store_sections').delete().eq('id', id);
  }

  /// Reorder store sections by updating display_order for each section
  static Future<void> reorderStoreSections(
    String storeId,
    List<String> orderedSectionIds,
  ) async {
    try {
      // Update display_order for each section
      for (int i = 0; i < orderedSectionIds.length; i++) {
        await _supabase
            .from('store_sections')
            .update({
              'display_order': i,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderedSectionIds[i])
            .eq('store_id', storeId);
      }
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في إعادة ترتيب الأقسام: ${e.message}', e);
      rethrow;
    }
  }
}
