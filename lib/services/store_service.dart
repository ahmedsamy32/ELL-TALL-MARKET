import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_model.dart';
import '../core/logger.dart';

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
      final response = await _supabase
          .from('stores')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => StoreModel.fromMap(data))
          .toList();
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
  }) async {
    try {
      final data = <String, dynamic>{};

      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (location != null) data['location'] = location;
      if (logoUrl != null) data['logo_url'] = logoUrl;
      if (isActive != null) data['is_active'] = isActive;

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
          .where((o) => o['status'] == 'delivered')
          .toList();

      final pendingOrders = orders
          .where((o) => o['status'] == 'pending')
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
      final fileExt = fileName.split('.').last;
      final filePath = 'stores/$storeId/logo.$fileExt';

      // رفع الصورة
      await _supabase.storage
          .from('store-images')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // الحصول على الرابط العام
      final imageUrl = _supabase.storage
          .from('store-images')
          .getPublicUrl(filePath);

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
    } else if (activeProducts >= 5)
      score += 20;
    else if (activeProducts >= 1)
      score += 10;

    // النقاط حسب الطلبات
    final totalOrders = stats['total_orders'] as int? ?? 0;
    if (totalOrders >= 50) {
      score += 40;
    } else if (totalOrders >= 20)
      score += 30;
    else if (totalOrders >= 5)
      score += 20;
    else if (totalOrders >= 1)
      score += 10;

    // النقاط حسب الإيرادات
    final revenue = stats['total_revenue'] as double? ?? 0.0;
    if (revenue >= 10000) {
      score += 30;
    } else if (revenue >= 5000)
      score += 20;
    else if (revenue >= 1000)
      score += 15;
    else if (revenue >= 100)
      score += 10;

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
}
