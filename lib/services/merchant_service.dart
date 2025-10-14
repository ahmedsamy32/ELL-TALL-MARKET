import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/merchant_model.dart';
import '../core/logger.dart';

/// خدمة إدارة التجار
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
class MerchantService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  // ================================
  // 🏪 Merchant CRUD Operations
  // ================================

  /// تسجيل تاجر جديد
  static Future<MerchantModel?> registerMerchant({
    required String profileId,
    required String storeName,
    String? storeDescription,
    String? address,
    double? latitude,
    double? longitude,
    bool isVerified = false,
  }) async {
    try {
      // التحقق من عدم وجود تاجر بنفس البروفايل
      final existingMerchant = await getMerchantByProfileId(profileId);
      if (existingMerchant != null) {
        AppLogger.error('التاجر مسجل مسبقاً لهذا البروفايل', null);
        throw Exception('التاجر مسجل مسبقاً لهذا البروفايل');
      }

      // حسب Schema الجديد: merchants.id = profiles.id
      final merchantData = {
        'id': profileId, // في Schema الجديد id هو نفسه profile_id
        'store_name': storeName,
        'store_description': storeDescription,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'is_verified': isVerified,
      };

      final response = await _supabase
          .from('merchants')
          .insert(merchantData)
          .select()
          .single();

      AppLogger.info('تم تسجيل تاجر جديد: $storeName');
      return MerchantModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تسجيل التاجر: ${e.message}', e);
      throw Exception('فشل تسجيل التاجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تسجيل التاجر', e);
      throw Exception('فشل تسجيل التاجر: ${e.toString()}');
    }
  }

  /// جلب تاجر محدد بالمعرف
  static Future<MerchantModel?> getMerchantById(String merchantId) async {
    try {
      final response = await _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .eq('id', merchantId)
          .single();

      return MerchantModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب التاجر: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب التاجر', e);
      return null;
    }
  }

  /// جلب تاجر بواسطة معرف البروفايل
  static Future<MerchantModel?> getMerchantByProfileId(String profileId) async {
    try {
      // في Schema الجديد: merchants.id = profiles.id
      final response = await _supabase
          .from('merchants')
          .select()
          .eq('id', profileId)
          .maybeSingle();

      if (response == null) return null;
      return MerchantModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب التاجر بالبروفايل: ${e.message}',
        e,
      );
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب التاجر بالبروفايل', e);
      return null;
    }
  }

  /// جلب جميع التجار مع دعم Pagination والفلترة
  static Future<List<MerchantModel>> getMerchants({
    int page = 1,
    String? searchTerm,
    bool? isVerified,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase.from('merchants').select();

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.or(
          'store_name.ilike.%$searchTerm%,address.ilike.%$searchTerm%',
        );
      }

      if (isVerified != null) {
        query = query.eq('is_verified', isVerified);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(startIndex, startIndex + _pageSize - 1);

      final merchants = (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();

      return merchants;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب التجار: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب التجار', e);
      return [];
    }
  }

  /// جلب التجار النشطين فقط
  static Future<List<MerchantModel>> getActiveMerchants({
    String orderBy = 'business_name',
    bool ascending = true,
  }) async {
    try {
      final response = await _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .eq('is_active', true)
          .order(orderBy, ascending: ascending);

      return (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب التجار النشطين: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب التجار النشطين', e);
      return [];
    }
  }

  /// جلب التجار المؤهلين (معتمدين)
  static Future<List<MerchantModel>> getVerifiedMerchants({
    int limit = 20,
    String orderBy = 'rating',
    bool ascending = false,
  }) async {
    try {
      final response = await _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .eq('is_active', true)
          .eq('verification_status', 'verified')
          .order(orderBy, ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب التجار المؤهلين: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب التجار المؤهلين', e);
      return [];
    }
  }

  /// تحديث معلومات التاجر
  static Future<MerchantModel?> updateMerchant({
    required String merchantId,
    String? businessName,
    String? businessType,
    String? businessAddress,
    String? contactPhone,
    String? logoUrl,
    bool? isActive,
    Map<String, dynamic>? businessHours,
    List<String>? businessCategories,
    String? taxId,
    String? licenseNumber,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? socialMedia,
    String? verificationStatus,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (businessName != null) data['business_name'] = businessName;
      if (businessType != null) data['business_type'] = businessType;
      if (businessAddress != null) data['business_address'] = businessAddress;
      if (contactPhone != null) data['contact_phone'] = contactPhone;
      if (logoUrl != null) data['logo_url'] = logoUrl;
      if (isActive != null) data['is_active'] = isActive;
      if (businessHours != null) data['business_hours'] = businessHours;
      if (businessCategories != null) {
        data['business_categories'] = businessCategories;
      }
      if (taxId != null) data['tax_id'] = taxId;
      if (licenseNumber != null) data['license_number'] = licenseNumber;
      if (bankDetails != null) data['bank_details'] = bankDetails;
      if (socialMedia != null) data['social_media'] = socialMedia;
      if (verificationStatus != null) {
        data['verification_status'] = verificationStatus;
      }
      if (metadata != null) data['metadata'] = metadata;

      final response = await _supabase
          .from('merchants')
          .update(data)
          .eq('id', merchantId)
          .select('*, profiles(*)')
          .single();

      AppLogger.info('تم تحديث التاجر: ${response['business_name']}');
      return MerchantModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث التاجر: ${e.message}', e);
      throw Exception('فشل تحديث التاجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث التاجر', e);
      throw Exception('فشل تحديث التاجر: ${e.toString()}');
    }
  }

  /// حذف تاجر
  static Future<bool> deleteMerchant(String merchantId) async {
    try {
      // التحقق من عدم وجود منتجات أو طلبات نشطة
      final products = await _supabase
          .from('products')
          .select('id')
          .eq('merchant_id', merchantId);

      if (products.isNotEmpty) {
        AppLogger.error('لا يمكن حذف التاجر لأنه يحتوي على منتجات', null);
        throw Exception('لا يمكن حذف التاجر لأنه يحتوي على منتجات');
      }

      await _supabase.from('merchants').delete().eq('id', merchantId);

      AppLogger.info('تم حذف التاجر بنجاح');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف التاجر: ${e.message}', e);
      throw Exception('فشل حذف التاجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف التاجر', e);
      throw Exception('فشل حذف التاجر: ${e.toString()}');
    }
  }

  // ================================
  // 📊 Merchant Statistics
  // ================================

  /// إحصائيات التاجر
  static Future<Map<String, dynamic>> getMerchantStatistics(
    String merchantId,
  ) async {
    try {
      // جلب عدد المنتجات
      final products = await _supabase
          .from('products')
          .select('id')
          .eq('merchant_id', merchantId);

      // جلب الطلبات
      final orders = await _supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', merchantId);

      // حساب الإحصائيات
      final totalProducts = products.length;
      final totalOrders = orders.length;
      final totalSales = orders
          .where((o) => o['status'] == 'delivered')
          .fold<double>(
            0.0,
            (sum, o) => sum + (o['total_amount'] as num).toDouble(),
          );

      // جلب التقييمات
      final reviews = await _supabase
          .from('merchant_reviews')
          .select('rating')
          .eq('merchant_id', merchantId);

      final averageRating = reviews.isNotEmpty
          ? reviews.fold<double>(
                  0.0,
                  (sum, r) => sum + (r['rating'] as num).toDouble(),
                ) /
                reviews.length
          : 0.0;

      // إحصائيات الطلبات حسب الحالة
      final pendingOrders = orders
          .where((o) => o['status'] == 'pending')
          .length;
      final processingOrders = orders
          .where((o) => o['status'] == 'processing')
          .length;
      final deliveredOrders = orders
          .where((o) => o['status'] == 'delivered')
          .length;
      final cancelledOrders = orders
          .where((o) => o['status'] == 'cancelled')
          .length;

      return {
        'total_products': totalProducts,
        'total_orders': totalOrders,
        'total_sales': totalSales,
        'average_rating': averageRating,
        'review_count': reviews.length,
        'pending_orders': pendingOrders,
        'processing_orders': processingOrders,
        'delivered_orders': deliveredOrders,
        'cancelled_orders': cancelledOrders,
        'completion_rate': totalOrders > 0
            ? (deliveredOrders / totalOrders) * 100
            : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب إحصائيات التاجر: ${e.message}', e);
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات التاجر', e);
      return {};
    }
  }

  /// أفضل التجار (حسب التقييم والمبيعات)
  static Future<List<Map<String, dynamic>>> getTopMerchants({
    int limit = 10,
    String criteria = 'rating', // rating, sales, orders
  }) async {
    try {
      String orderBy;
      switch (criteria) {
        case 'sales':
          orderBy = 'total_sales';
          break;
        case 'orders':
          orderBy = 'total_orders';
          break;
        default:
          orderBy = 'rating';
      }

      final response = await _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .eq('is_active', true)
          .eq('verification_status', 'verified')
          .order(orderBy, ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب أفضل التجار: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب أفضل التجار', e);
      return [];
    }
  }

  /// إحصائيات عامة للتجار
  static Future<Map<String, dynamic>> getMerchantsStatistics() async {
    try {
      final allMerchants = await _supabase.from('merchants').select('*');

      final total = allMerchants.length;
      final active = allMerchants.where((m) => m['is_active'] == true).length;
      final verified = allMerchants
          .where((m) => m['verification_status'] == 'verified')
          .length;
      final pending = allMerchants
          .where((m) => m['verification_status'] == 'pending')
          .length;

      // حساب إجمالي المبيعات
      final totalSales = allMerchants.fold<double>(
        0.0,
        (sum, m) => sum + ((m['total_sales'] as num?)?.toDouble() ?? 0.0),
      );

      // حساب إجمالي الطلبات
      final totalOrders = allMerchants.fold<int>(
        0,
        (sum, m) => sum + (m['total_orders'] as int? ?? 0),
      );

      return {
        'total_merchants': total,
        'active_merchants': active,
        'verified_merchants': verified,
        'pending_merchants': pending,
        'total_sales': totalSales,
        'total_orders': totalOrders,
        'average_sales_per_merchant': total > 0 ? totalSales / total : 0.0,
        'verification_rate': total > 0 ? (verified / total) * 100 : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب إحصائيات التجار: ${e.message}', e);
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات التجار', e);
      return {};
    }
  }

  // ================================
  // ✅ Verification Management
  // ================================

  /// تحديث حالة التحقق
  static Future<bool> updateVerificationStatus({
    required String merchantId,
    required String status, // pending, verified, rejected
    String? notes,
    String? verifiedBy,
  }) async {
    try {
      final data = {
        'verification_status': status,
        'verification_notes': notes,
        'verified_by': verifiedBy,
        'verified_at': status == 'verified'
            ? DateTime.now().toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('merchants').update(data).eq('id', merchantId);

      AppLogger.info('تم تحديث حالة التحقق للتاجر $merchantId إلى $status');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث حالة التحقق: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة التحقق', e);
      return false;
    }
  }

  /// جلب التجار المنتظرين للتحقق
  static Future<List<MerchantModel>> getPendingVerificationMerchants() async {
    try {
      final response = await _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .eq('verification_status', 'pending')
          .order('created_at', ascending: true);

      return (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب التجار المنتظرين: ${e.message}',
        e,
      );
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب التجار المنتظرين', e);
      return [];
    }
  }

  /// طلب إعادة التحقق
  static Future<bool> requestReVerification(String merchantId) async {
    try {
      await updateVerificationStatus(
        merchantId: merchantId,
        status: 'pending',
        notes: 'طلب إعادة تحقق من التاجر',
      );

      AppLogger.info('تم طلب إعادة التحقق للتاجر $merchantId');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في طلب إعادة التحقق', e);
      return false;
    }
  }

  // ================================
  // 🎯 Status Management
  // ================================

  /// تغيير حالة النشاط
  static Future<bool> toggleMerchantStatus(String merchantId) async {
    try {
      final merchant = await getMerchantById(merchantId);
      if (merchant == null) return false;

      final newStatus = !merchant.isActive;

      await updateMerchant(merchantId: merchantId, isActive: newStatus);

      AppLogger.info(
        'تم تغيير حالة التاجر $merchantId إلى ${newStatus ? "نشط" : "غير نشط"}',
      );
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة التاجر', e);
      return false;
    }
  }

  /// تحديث التقييم
  static Future<bool> updateMerchantRating({
    required String merchantId,
    required double newRating,
  }) async {
    try {
      // حساب التقييم الجديد
      final merchant = await getMerchantById(merchantId);
      if (merchant == null) return false;

      // جلب البيانات الحالية من قاعدة البيانات
      final response = await _supabase
          .from('merchants')
          .select('rating, rating_count')
          .eq('id', merchantId)
          .single();

      final currentRating = (response['rating'] as num?)?.toDouble() ?? 0.0;
      final currentCount = response['rating_count'] as int? ?? 0;

      final totalRating = (currentRating * currentCount) + newRating;
      final newCount = currentCount + 1;
      final averageRating = totalRating / newCount;

      await _supabase
          .from('merchants')
          .update({
            'rating': averageRating,
            'rating_count': newCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', merchantId);

      AppLogger.info('تم تحديث تقييم التاجر $merchantId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث تقييم التاجر: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث تقييم التاجر', e);
      return false;
    }
  }

  /// تحديث إحصائيات المبيعات
  static Future<bool> updateSalesStats({
    required String merchantId,
    required double saleAmount,
  }) async {
    try {
      // جلب البيانات الحالية
      final response = await _supabase
          .from('merchants')
          .select('total_sales, total_orders')
          .eq('id', merchantId)
          .single();

      final currentSales = (response['total_sales'] as num?)?.toDouble() ?? 0.0;
      final currentOrders = response['total_orders'] as int? ?? 0;

      await _supabase
          .from('merchants')
          .update({
            'total_sales': currentSales + saleAmount,
            'total_orders': currentOrders + 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', merchantId);

      AppLogger.info('تم تحديث إحصائيات المبيعات للتاجر $merchantId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في تحديث إحصائيات المبيعات: ${e.message}',
        e,
      );
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث إحصائيات المبيعات', e);
      return false;
    }
  }

  // ================================
  // 🖼️ Image Management
  // ================================

  /// رفع شعار التاجر
  static Future<String?> uploadMerchantLogo({
    required String merchantId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath = 'merchants/$merchantId/logo.$fileExt';

      // رفع الصورة
      await _supabase.storage
          .from('merchant-images')
          .uploadBinary(filePath, imageBytes);

      // الحصول على الرابط العام
      final imageUrl = _supabase.storage
          .from('merchant-images')
          .getPublicUrl(filePath);

      // تحديث التاجر بالشعار الجديد
      await updateMerchant(merchantId: merchantId, logoUrl: imageUrl);

      AppLogger.info('تم رفع شعار التاجر');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع شعار التاجر: ${e.message}', e);
      throw Exception('فشل رفع شعار التاجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع شعار التاجر', e);
      throw Exception('فشل رفع شعار التاجر: ${e.toString()}');
    }
  }

  /// حذف شعار التاجر
  static Future<bool> deleteMerchantLogo(String merchantId) async {
    try {
      final merchant = await getMerchantById(merchantId);
      if (merchant == null ||
          merchant.logoUrl == null ||
          merchant.logoUrl!.isEmpty)
        return false;

      // استخراج مسار الملف من الرابط
      final uri = Uri.parse(merchant.logoUrl!);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('merchant-images');

      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

        // حذف الصورة من التخزين
        await _supabase.storage.from('merchant-images').remove([filePath]);
      }

      // إزالة رابط الشعار من التاجر
      await updateMerchant(merchantId: merchantId, logoUrl: null);

      AppLogger.info('تم حذف شعار التاجر');
      return true;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في حذف شعار التاجر: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في حذف شعار التاجر', e);
      return false;
    }
  }

  // ================================
  // 🔍 Search & Filter
  // ================================

  /// البحث في التجار
  static Future<List<MerchantModel>> searchMerchants({
    required String searchTerm,
    bool activeOnly = true,
    bool verifiedOnly = false,
    int limit = 20,
  }) async {
    try {
      var query = _supabase
          .from('merchants')
          .select('*, profiles(*)')
          .or(
            'business_name.ilike.%$searchTerm%,business_address.ilike.%$searchTerm%,business_type.ilike.%$searchTerm%',
          );

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (verifiedOnly) {
        query = query.eq('verification_status', 'verified');
      }

      final response = await query
          .order('business_name', ascending: true)
          .limit(limit);

      return (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث في التجار: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في البحث في التجار', e);
      return [];
    }
  }

  /// البحث المتقدم في التجار
  static Future<List<MerchantModel>> advancedSearchMerchants({
    String? businessName,
    String? businessType,
    String? businessAddress,
    bool? isActive,
    String? verificationStatus,
    double? minRating,
    int? minOrders,
    double? minSales,
    String orderBy = 'business_name',
    bool ascending = true,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('merchants').select('*, profiles(*)');

      if (businessName != null && businessName.isNotEmpty) {
        query = query.ilike('business_name', '%$businessName%');
      }

      if (businessType != null && businessType.isNotEmpty) {
        query = query.eq('business_type', businessType);
      }

      if (businessAddress != null && businessAddress.isNotEmpty) {
        query = query.ilike('business_address', '%$businessAddress%');
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (verificationStatus != null) {
        query = query.eq('verification_status', verificationStatus);
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      if (minOrders != null) {
        query = query.gte('total_orders', minOrders);
      }

      if (minSales != null) {
        query = query.gte('total_sales', minSales);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((data) => MerchantModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث المتقدم: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في البحث المتقدم', e);
      return [];
    }
  }

  // ================================
  // 🔄 Real-time Operations
  // ================================

  /// مراقبة تحديثات التجار فورياً
  static Stream<List<Map<String, dynamic>>> watchMerchants({
    bool? isActive,
    String? verificationStatus,
  }) {
    var stream = _supabase.from('merchants').stream(primaryKey: ['id']);

    return stream.order('updated_at');
  }

  /// مراقبة تاجر محدد
  static Stream<Map<String, dynamic>?> watchMerchant(String merchantId) {
    return _supabase
        .from('merchants')
        .stream(primaryKey: ['id'])
        .eq('id', merchantId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ================================
  // 📊 Bulk Operations
  // ================================

  /// عمليات مجمعة على التجار
  static Future<bool> bulkUpdateMerchants({
    required List<String> merchantIds,
    bool? isActive,
    String? verificationStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isActive != null) data['is_active'] = isActive;
      if (verificationStatus != null) {
        data['verification_status'] = verificationStatus;
      }

      await _supabase
          .from('merchants')
          .update(data)
          .inFilter('id', merchantIds);

      AppLogger.info('تم التحديث المجمع لـ ${merchantIds.length} تاجر');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في التحديث المجمع: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في التحديث المجمع', e);
      return false;
    }
  }

  /// تحديث جميع إحصائيات التجار
  static Future<bool> updateAllMerchantStats() async {
    try {
      final merchants = await getMerchants(page: 1);

      for (final merchant in merchants) {
        await getMerchantStatistics(merchant.id);
      }

      AppLogger.info('تم تحديث إحصائيات جميع التجار');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث إحصائيات التجار', e);
      return false;
    }
  }

  // ================================
  // 🛠️ Helper Functions
  // ================================

  /// التحقق من صحة بيانات التاجر
  static bool validateMerchantData({
    required String businessName,
    String? businessAddress,
    String? contactPhone,
    String? taxId,
    String? licenseNumber,
  }) {
    if (businessName.trim().isEmpty) return false;
    if (businessName.length < 2 || businessName.length > 100) return false;

    if (contactPhone != null && contactPhone.isNotEmpty) {
      if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(contactPhone)) return false;
    }

    if (taxId != null && taxId.isNotEmpty) {
      if (taxId.length < 5) return false;
    }

    return true;
  }

  /// تنظيف اسم العمل
  static String sanitizeBusinessName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// إنشاء slug للعمل
  static String generateBusinessSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// التحقق من صحة ساعات العمل
  static bool validateBusinessHours(Map<String, dynamic> businessHours) {
    const validDays = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];

    for (final day in validDays) {
      final dayHours = businessHours[day];
      if (dayHours != null && dayHours is Map) {
        if (dayHours['closed'] != true) {
          final openTime = dayHours['open'] as String?;
          final closeTime = dayHours['close'] as String?;

          if (openTime == null || closeTime == null) return false;

          // التحقق من صيغة الوقت
          if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(openTime) ||
              !RegExp(r'^\d{2}:\d{2}$').hasMatch(closeTime)) {
            return false;
          }
        }
      }
    }

    return true;
  }

  /// التحقق من صحة معلومات البنك
  static bool validateBankDetails(Map<String, dynamic> bankDetails) {
    final accountNumber = bankDetails['account_number'] as String?;
    final bankName = bankDetails['bank_name'] as String?;
    final iban = bankDetails['iban'] as String?;

    if (accountNumber != null && accountNumber.isNotEmpty) {
      if (accountNumber.length < 8) return false;
    }

    if (bankName != null && bankName.isNotEmpty) {
      if (bankName.length < 2) return false;
    }

    if (iban != null && iban.isNotEmpty) {
      if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(iban)) return false;
    }

    return true;
  }
}
