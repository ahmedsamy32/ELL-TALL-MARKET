import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/order_model.dart';
import '../models/order_enums.dart';
import '../models/captain_model.dart';

class CaptainService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  /// تسجيل كابتن جديد
  /// ملاحظة: captains.id = profiles.id (FK مباشر)
  static Future<CaptainModel?> createCaptain({
    required String profileId,
    required String vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    bool isActive = true,
    Map<String, dynamic>? additionalData,
    Map<String, dynamic>? workingHours,
    List<dynamic>? workingAreas,
    String? contactPhone,
    String? nationalId,
    String? profileImageUrl,
    String? licenseImageUrl,
    String? vehicleImageUrl,
  }) async {
    try {
      // التحقق من عدم وجود كابتن بنفس البروفايل
      final existingCaptain = await getCaptainById(profileId);
      if (existingCaptain != null) {
        AppLogger.error('الكابتن مسجل مسبقاً لهذا البروفايل', null);
        throw Exception('الكابتن مسجل مسبقاً لهذا البروفايل');
      }

      final captainData = {
        'id': profileId, // captains.id references profiles(id)
        'vehicle_type': vehicleType,
        'vehicle_number': vehicleNumber,
        'license_number': licenseNumber,
        'is_active': isActive,
        'is_available': true,
        'is_online': false,
        'working_hours': workingHours ?? {},
        'working_areas': workingAreas ?? [],
        'contact_phone': contactPhone,
        'national_id': nationalId,
        'profile_image_url': profileImageUrl,
        'license_image_url': licenseImageUrl,
        'vehicle_image_url': vehicleImageUrl,
        'additional_data': additionalData ?? {},
        'rating': 0.0,
        'rating_count': 0,
        'total_deliveries': 0,
        'total_earnings': 0.0,
        'verification_status': 'pending',
      };

      final response = await _supabase
          .from('captains')
          .insert(captainData)
          .select('*, profiles!captains_id_fkey(*)')
          .single();

      AppLogger.info('تم تسجيل كابتن جديد للبروفايل: $profileId');
      return CaptainModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تسجيل الكابتن: ${e.message}', e);
      throw Exception('فشل تسجيل الكابتن: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تسجيل الكابتن', e);
      throw Exception('فشل تسجيل الكابتن: ${e.toString()}');
    }
  }

  /// جلب كابتن محدد بالتفصيل
  static Future<CaptainModel?> getCaptainById(String captainId) async {
    try {
      final response = await _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .eq('id', captainId)
          .single();

      return CaptainModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الكابتن: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الكابتن', e);
      return null;
    }
  }

  /// جلب كابتن بواسطة معرف البروفايل
  /// captains.id = profiles.id (FK مباشر)
  static Future<CaptainModel?> getCaptainByProfileId(String profileId) async {
    try {
      final response = await _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .eq('id', profileId)
          .single();

      return CaptainModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب الكابتن بمعرف البروفايل: ${e.message}',
        e,
      );
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الكابتن بمعرف البروفايل', e);
      return null;
    }
  }

  /// جلب جميع الكباتن مع دعم Pagination والفلترة
  static Future<List<CaptainModel>> getCaptains({
    int page = 1,
    String? verificationStatus,
    String? vehicleType,
    bool? isActive,
    bool? isAvailable,
    bool? isOnline,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)');

      if (verificationStatus != null) {
        query = query.eq('verification_status', verificationStatus);
      }

      if (vehicleType != null) {
        query = query.eq('vehicle_type', vehicleType);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (isAvailable != null) {
        query = query.eq('is_available', isAvailable);
      }

      if (isOnline != null) {
        query = query.eq('is_online', isOnline);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => CaptainModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الكباتن: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الكباتن', e);
      return [];
    }
  }

  /// جلب الكباتن النشطين فقط
  static Future<List<CaptainModel>> getActiveCaptains({
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final response = await _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .eq('is_active', true)
          .order(orderBy, ascending: ascending);

      return (response as List)
          .map((data) => CaptainModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الكباتن النشطين: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الكباتن النشطين', e);
      return [];
    }
  }

  /// جلب الكباتن المؤهلين (معتمدين)
  static Future<List<CaptainModel>> getVerifiedCaptains({
    int limit = 20,
    String orderBy = 'rating',
    bool ascending = false,
  }) async {
    try {
      final response = await _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .eq('is_active', true)
          .eq('verification_status', 'approved')
          .order(orderBy, ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((data) => CaptainModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب الكباتن المؤهلين: ${e.message}',
        e,
      );
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الكباتن المؤهلين', e);
      return [];
    }
  }

  /// تحديث معلومات الكابتن
  static Future<CaptainModel?> updateCaptain({
    required String captainId,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    bool? isActive,
    bool? isAvailable,
    bool? isOnline,
    String? status,
    Map<String, dynamic>? workingHours,
    List<dynamic>? workingAreas,
    String? contactPhone,
    String? nationalId,
    String? profileImageUrl,
    String? licenseImageUrl,
    String? vehicleImageUrl,
    String? verificationStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (vehicleType != null) data['vehicle_type'] = vehicleType;
      if (vehicleNumber != null) data['vehicle_number'] = vehicleNumber;
      if (licenseNumber != null) data['license_number'] = licenseNumber;
      if (isActive != null) data['is_active'] = isActive;
      if (isAvailable != null) data['is_available'] = isAvailable;
      if (isOnline != null) data['is_online'] = isOnline;
      if (status != null) data['status'] = status;
      if (workingHours != null) data['working_hours'] = workingHours;
      if (workingAreas != null) data['working_areas'] = workingAreas;
      if (contactPhone != null) data['contact_phone'] = contactPhone;
      if (nationalId != null) data['national_id'] = nationalId;
      if (profileImageUrl != null) data['profile_image_url'] = profileImageUrl;
      if (licenseImageUrl != null) data['license_image_url'] = licenseImageUrl;
      if (vehicleImageUrl != null) data['vehicle_image_url'] = vehicleImageUrl;
      if (verificationStatus != null) {
        data['verification_status'] = verificationStatus;
      }
      if (additionalData != null) data['additional_data'] = additionalData;

      final response = await _supabase
          .from('captains')
          .update(data)
          .eq('id', captainId)
          .select('*, profiles!captains_id_fkey(*)')
          .single();

      AppLogger.info('تم تحديث الكابتن: $captainId');
      return CaptainModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث الكابتن: ${e.message}', e);
      throw Exception('فشل تحديث الكابتن: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث الكابتن', e);
      throw Exception('فشل تحديث الكابتن: ${e.toString()}');
    }
  }

  /// حذف كابتن
  static Future<bool> deleteCaptain(String captainId) async {
    try {
      // التحقق من عدم وجود طلبات نشطة
      final activeOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('captain_id', captainId)
          .not('status', 'in', [
            OrderStatus.delivered.value,
            OrderStatus.cancelled.value,
          ]);

      if (activeOrders.isNotEmpty) {
        AppLogger.error('لا يمكن حذف الكابتن لأنه يحتوي على طلبات نشطة', null);
        throw Exception('لا يمكن حذف الكابتن لأنه يحتوي على طلبات نشطة');
      }

      await _supabase.from('captains').delete().eq('id', captainId);

      AppLogger.info('تم حذف الكابتن بنجاح');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف الكابتن: ${e.message}', e);
      throw Exception('فشل حذف الكابتن: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف الكابتن', e);
      throw Exception('فشل حذف الكابتن: ${e.toString()}');
    }
  }

  // ================================
  // 🌍 Location Management
  // ================================

  /// تحديث موقع الكابتن باستخدام دالة RPC
  /// يحدّث جدولي captains و driver_locations معاً
  static Future<bool> updateCaptainLocation({
    required String captainId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      await _supabase.rpc(
        'update_captain_location',
        params: {
          'p_captain_id': captainId,
          'p_lat': latitude,
          'p_lng': longitude,
          'p_heading': heading ?? 0,
          'p_speed': speed ?? 0,
          'p_accuracy': accuracy ?? 0,
        },
      );

      AppLogger.info('تم تحديث موقع الكابتن $captainId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث موقع الكابتن: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث موقع الكابتن', e);
      return false;
    }
  }

  /// جلب موقع الكابتن الحالي من driver_locations
  static Future<Map<String, dynamic>?> getCaptainLocation(
    String captainId,
  ) async {
    try {
      final response = await _supabase
          .from('driver_locations')
          .select('*')
          .eq('driver_id', captainId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب موقع الكابتن: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب موقع الكابتن', e);
      return null;
    }
  }

  /// العثور على الكباتن القريبين باستخدام PostGIS
  static Future<List<CaptainModel>> findNearbyCaptains({
    required double latitude,
    required double longitude,
    double maxDistance = 10.0, // كيلومتر
    String? vehicleType,
    int limit = 10,
  }) async {
    try {
      // استخدام دالة PostGIS للبحث المكاني
      final response = await _supabase.rpc(
        'get_nearby_captains',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_km': maxDistance,
          'p_limit': limit,
        },
      );

      if (response == null || (response as List).isEmpty) {
        return [];
      }

      // جلب بيانات الكباتن الكاملة
      final captainIds = response
          .map((r) => r['captain_id'] as String)
          .toList();

      var query = _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .inFilter('id', captainIds);

      if (vehicleType != null) {
        query = query.eq('vehicle_type', vehicleType);
      }

      final captainsData = await query;

      return (captainsData as List)
          .map((data) => CaptainModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في العثور على الكباتن القريبين: ${e.message}',
        e,
      );
      return [];
    } catch (e) {
      AppLogger.error('خطأ في العثور على الكباتن القريبين', e);
      return [];
    }
  }

  // ================================
  // 📊 Captain Performance
  // ================================

  /// إحصائيات أداء الكابتن
  static Future<Map<String, dynamic>> getCaptainStatistics(
    String captainId,
  ) async {
    try {
      // جلب الطلبات
      final orders = await _supabase
          .from('orders')
          .select('*')
          .eq('captain_id', captainId);

      // حساب الإحصائيات
      final totalDeliveries = orders.length;
      final completedDeliveries = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .length;
      final totalEarnings = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .fold<double>(
            0.0,
            (sum, o) => sum + (o['delivery_fee'] as num).toDouble(),
          );

      // حساب متوسط وقت التوصيل
      final deliveredOrders = orders
          .where((o) => o['status'] == OrderStatus.delivered.value)
          .toList();
      double averageDeliveryTime = 0.0;

      if (deliveredOrders.isNotEmpty) {
        double totalTime = 0.0;
        for (final order in deliveredOrders) {
          final pickedUpAt = DateTime.tryParse(order['picked_up_at'] ?? '');
          final deliveredAt = DateTime.tryParse(order['delivered_at'] ?? '');

          if (pickedUpAt != null && deliveredAt != null) {
            totalTime += deliveredAt.difference(pickedUpAt).inMinutes;
          }
        }
        averageDeliveryTime = totalTime / deliveredOrders.length;
      }

      // جلب تقييم الكابتن من جدول captains مباشرة
      final captainData = await _supabase
          .from('captains')
          .select('rating, rating_count')
          .eq('id', captainId)
          .single();

      final averageRating = (captainData['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = captainData['rating_count'] as int? ?? 0;

      return {
        'total_deliveries': totalDeliveries,
        'completed_deliveries': completedDeliveries,
        'total_earnings': totalEarnings,
        'average_rating': averageRating,
        'rating_count': ratingCount,
        'average_delivery_time': averageDeliveryTime,
        'completion_rate': totalDeliveries > 0
            ? (completedDeliveries / totalDeliveries) * 100
            : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب إحصائيات الكابتن: ${e.message}',
        e,
      );
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات الكابتن', e);
      return {};
    }
  }

  /// تحديث تقييم الكابتن
  static Future<bool> updateCaptainRating({
    required String captainId,
    required double newRating,
  }) async {
    try {
      // جلب البيانات الحالية من قاعدة البيانات
      final response = await _supabase
          .from('captains')
          .select('rating, rating_count')
          .eq('id', captainId)
          .single();

      final currentRating = (response['rating'] as num?)?.toDouble() ?? 0.0;
      final currentCount = response['rating_count'] as int? ?? 0;

      final totalRating = (currentRating * currentCount) + newRating;
      final newCount = currentCount + 1;
      final averageRating = totalRating / newCount;

      // تحديث الكابتن
      await _supabase
          .from('captains')
          .update({
            'rating': averageRating,
            'rating_count': newCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

      AppLogger.info('تم تحديث تقييم الكابتن $captainId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث تقييم الكابتن: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث تقييم الكابتن', e);
      return false;
    }
  }

  /// تحديث عداد التوصيلات والأرباح
  static Future<bool> updateCaptainDeliveryStats({
    required String captainId,
    required double deliveryFee,
  }) async {
    try {
      // جلب البيانات الحالية من قاعدة البيانات مباشرة
      final response = await _supabase
          .from('captains')
          .select('total_deliveries, total_earnings')
          .eq('id', captainId)
          .single();

      final currentDeliveries = response['total_deliveries'] ?? 0;
      final currentEarnings = (response['total_earnings'] ?? 0.0).toDouble();

      await _supabase
          .from('captains')
          .update({
            'total_deliveries': currentDeliveries + 1,
            'total_earnings': currentEarnings + deliveryFee,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

      AppLogger.info('تم تحديث إحصائيات الكابتن $captainId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في تحديث إحصائيات الكابتن: ${e.message}',
        e,
      );
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث إحصائيات الكابتن', e);
      return false;
    }
  }

  // ================================
  // 🖼️ Image Management
  // ================================

  /// رفع صورة شخصية للكابتن
  static Future<String?> uploadCaptainProfile({
    required String captainId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath = 'captains/$captainId/profile.$fileExt';

      await _supabase.storage
          .from('captain-images')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage
          .from('captain-images')
          .getPublicUrl(filePath);

      await updateCaptain(captainId: captainId, profileImageUrl: imageUrl);

      AppLogger.info('تم رفع صورة الكابتن الشخصية');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع صورة الكابتن: ${e.message}', e);
      throw Exception('فشل رفع صورة الكابتن: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة الكابتن', e);
      throw Exception('فشل رفع صورة الكابتن: ${e.toString()}');
    }
  }

  /// رفع صورة رخصة القيادة
  static Future<String?> uploadLicenseImage({
    required String captainId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath = 'captains/$captainId/license.$fileExt';

      await _supabase.storage
          .from('captain-documents')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage
          .from('captain-documents')
          .getPublicUrl(filePath);

      await updateCaptain(captainId: captainId, licenseImageUrl: imageUrl);

      AppLogger.info('تم رفع صورة رخصة القيادة');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع صورة الرخصة: ${e.message}', e);
      throw Exception('فشل رفع صورة الرخصة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة الرخصة', e);
      throw Exception('فشل رفع صورة الرخصة: ${e.toString()}');
    }
  }

  /// رفع صورة المركبة
  static Future<String?> uploadVehicleImage({
    required String captainId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath = 'captains/$captainId/vehicle.$fileExt';

      await _supabase.storage
          .from('captain-images')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage
          .from('captain-images')
          .getPublicUrl(filePath);

      await updateCaptain(captainId: captainId, vehicleImageUrl: imageUrl);

      AppLogger.info('تم رفع صورة المركبة');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع صورة المركبة: ${e.message}', e);
      throw Exception('فشل رفع صورة المركبة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة المركبة', e);
      throw Exception('فشل رفع صورة المركبة: ${e.toString()}');
    }
  }

  // ================================
  // 🕐 Working Hours & Availability
  // ================================

  /// التحقق من أن الكابتن متاح للعمل حالياً
  static bool isCaptainAvailable(CaptainModel captain, {DateTime? dateTime}) {
    // التحقق من الحالة العامة
    if (!captain.isActive) {
      return false;
    }

    // يمكن إضافة منطق ساعات العمل هنا
    // إذا كان متوفراً في قاعدة البيانات

    return true;
  }

  /// تغيير حالة التوفر
  static Future<bool> toggleAvailability(String captainId) async {
    try {
      // جلب الحالة الحالية من قاعدة البيانات
      final response = await _supabase
          .from('captains')
          .select('is_available')
          .eq('id', captainId)
          .single();

      final currentAvailable = response['is_available'] as bool? ?? true;
      final newAvailable = !currentAvailable;

      await updateCaptain(captainId: captainId, isAvailable: newAvailable);

      AppLogger.info('تم تغيير حالة توفر الكابتن $captainId إلى $newAvailable');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة التوفر', e);
      return false;
    }
  }

  /// تغيير حالة الاتصال (أونلاين/أوفلاين)
  static Future<bool> toggleOnlineStatus(String captainId) async {
    try {
      // استخدام البيانات مباشرة من قاعدة البيانات
      final response = await _supabase
          .from('captains')
          .select('is_online')
          .eq('id', captainId)
          .single();

      final currentOnlineStatus = response['is_online'] ?? false;
      final newOnlineStatus = !currentOnlineStatus;

      await updateCaptain(
        captainId: captainId,
        isOnline: newOnlineStatus,
        status: newOnlineStatus ? 'online' : 'offline',
      );

      AppLogger.info(
        'تم تغيير حالة الاتصال للكابتن $captainId إلى $newOnlineStatus',
      );
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة الاتصال', e);
      return false;
    }
  }

  // ================================
  // 🔄 Real-time Operations
  // ================================

  /// مراقبة تحديثات الكباتن فورياً
  static Stream<List<Map<String, dynamic>>> watchCaptains({
    String? status,
    bool? isAvailable,
  }) {
    var query = _supabase.from('captains').stream(primaryKey: ['id']);

    if (status != null) {
      return query.eq('status', status).order('updated_at');
    }

    if (isAvailable != null) {
      return query.eq('is_available', isAvailable).order('updated_at');
    }

    return query.order('updated_at');
  }

  /// مراقبة كابتن محدد
  static Stream<Map<String, dynamic>?> watchCaptain(String captainId) {
    return _supabase
        .from('captains')
        .stream(primaryKey: ['id'])
        .eq('id', captainId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  /// مراقبة موقع الكابتن فورياً
  static Stream<Map<String, dynamic>?> watchCaptainLocation(String captainId) {
    return _supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', captainId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ================================
  // � Advanced Analytics & Management
  // ================================

  /// إضافة تقييم للكابتن
  /// يتم تخزين التقييم مباشرة في جدول captains (rating + rating_count)
  static Future<void> addRating({
    required String captainId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      // تحديث التقييم مباشرة باستخدام المتوسط التراكمي
      await updateCaptainRating(captainId: captainId, newRating: rating);

      // يمكن تخزين التقييم التفصيلي في ratings table إذا أردنا
      // حالياً نستخدم جدول ratings العام الموجود في المشروع
      try {
        await _supabase.from('ratings').insert({
          'user_id': userId,
          'rated_entity_type': 'captain',
          'rated_entity_id': captainId,
          'rating': rating,
          'comment': comment,
        });
      } catch (_) {
        // ratings table might not exist, that's ok
      }

      AppLogger.info('تم إضافة تقييم للكابتن: $captainId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إضافة تقييم: ${e.message}', e);
      throw Exception('فشل إضافة التقييم: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إضافة تقييم', e);
      throw Exception('فشل إضافة التقييم: ${e.toString()}');
    }
  }

  /// الحصول على الكباتن المتاحين في منطقة محددة باستخدام PostGIS RPC
  static Future<List<CaptainModel>> getAvailableCaptainsInArea({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
    String? vehicleType,
  }) async {
    try {
      // استخدام دالة get_nearby_captains الـ PostGIS للفلترة الدقيقة بالمسافة
      final response = await _supabase.rpc(
        'get_nearby_captains',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_km': radiusInKm,
          'p_limit': 50,
        },
      );

      if (response == null || (response as List).isEmpty) {
        AppLogger.info('لا يوجد كباتن متاحين في نطاق $radiusInKm كم');
        return [];
      }

      // جلب بيانات الكباتن الكاملة بناءً على الـ IDs المرجعة
      final captainIds = response
          .map((r) => r['captain_id'] as String)
          .toList();

      var query = _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)')
          .inFilter('id', captainIds);

      if (vehicleType != null) {
        query = query.eq('vehicle_type', vehicleType);
      }

      final captainsData = await query;

      final captains = captainsData
          .map((json) => CaptainModel.fromMap(json))
          .toList();

      AppLogger.info(
        'تم العثور على ${captains.length} كابتن متاح في نطاق $radiusInKm كم',
      );
      return captains;
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في البحث عن الكباتن المتاحين: ${e.message}',
        e,
      );
      throw Exception('فشل البحث عن الكباتن: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث عن الكباتن المتاحين', e);
      throw Exception('فشل البحث عن الكباتن: ${e.toString()}');
    }
  }

  /// تعيين طلب للكابتن باستخدام RPC
  static Future<bool> assignOrderToCaptain({
    required String captainId,
    required String orderId,
    double deliveryFee = 0.0,
  }) async {
    try {
      await _supabase.rpc(
        'assign_captain_to_order',
        params: {
          'p_order_id': orderId,
          'p_captain_id': captainId,
          'p_delivery_fee': deliveryFee,
        },
      );

      AppLogger.info('تم تعيين الطلب $orderId للكابتن $captainId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تعيين الطلب: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تعيين الطلب', e);
      return false;
    }
  }

  /// الحصول على تاريخ الطلبات للكابتن
  static Future<List<Map<String, dynamic>>> getCaptainOrderHistory({
    required String captainId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('orders')
          .select('''
            id,
            status,
            created_at,
            delivered_at,
            delivery_fee,
            total_amount,
            pickup_address,
            delivery_address,
            customer:profiles!orders_user_id_fkey(full_name, phone)
          ''')
          .eq('captain_id', captainId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      AppLogger.info('تم استرجاع ${response.length} طلب لتاريخ الكابتن');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في استرجاع تاريخ الطلبات: ${e.message}',
        e,
      );
      throw Exception('فشل استرجاع تاريخ الطلبات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع تاريخ الطلبات', e);
      throw Exception('فشل استرجاع تاريخ الطلبات: ${e.toString()}');
    }
  }

  /// البحث المتقدم في الكابتنز
  static Future<List<CaptainModel>> searchCaptains({
    String? query,
    String? vehicleType,
    String? verificationStatus,
    bool? isAvailable,
    bool? isActive,
    bool? isOnline,
    double? minRating,
    DateTime? registeredAfter,
    DateTime? registeredBefore,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var supabaseQuery = _supabase
          .from('captains')
          .select('*, profiles!captains_id_fkey(*)');

      if (query != null && query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or(
          'profiles.full_name.ilike.%$query%,'
          'vehicle_number.ilike.%$query%,'
          'contact_phone.ilike.%$query%',
        );
      }

      if (vehicleType != null) {
        supabaseQuery = supabaseQuery.eq('vehicle_type', vehicleType);
      }

      if (verificationStatus != null) {
        supabaseQuery = supabaseQuery.eq(
          'verification_status',
          verificationStatus,
        );
      }

      if (isAvailable != null) {
        supabaseQuery = supabaseQuery.eq('is_available', isAvailable);
      }

      if (isActive != null) {
        supabaseQuery = supabaseQuery.eq('is_active', isActive);
      }

      if (isOnline != null) {
        supabaseQuery = supabaseQuery.eq('is_online', isOnline);
      }

      if (minRating != null) {
        supabaseQuery = supabaseQuery.gte('rating', minRating);
      }

      if (registeredAfter != null) {
        supabaseQuery = supabaseQuery.gte(
          'created_at',
          registeredAfter.toIso8601String(),
        );
      }

      if (registeredBefore != null) {
        supabaseQuery = supabaseQuery.lte(
          'created_at',
          registeredBefore.toIso8601String(),
        );
      }

      final response = await supabaseQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final captains = response
          .map((json) => CaptainModel.fromMap(json))
          .toList();

      AppLogger.info('تم العثور على ${captains.length} كابتن في البحث');
      return captains;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث عن الكابتنز: ${e.message}', e);
      throw Exception('فشل البحث: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث عن الكابتنز', e);
      throw Exception('فشل البحث: ${e.toString()}');
    }
  }

  /// إدارة المناطق العمل للكابتن
  static Future<void> updateWorkingAreas({
    required String captainId,
    required List<String> areas,
  }) async {
    try {
      await _supabase
          .from('captains')
          .update({
            'working_areas': areas,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

      AppLogger.info('تم تحديث مناطق عمل الكابتن: $captainId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث مناطق العمل: ${e.message}', e);
      throw Exception('فشل تحديث مناطق العمل: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث مناطق العمل', e);
      throw Exception('فشل تحديث مناطق العمل: ${e.toString()}');
    }
  }

  /// إدارة ساعات العمل للكابتن
  static Future<void> updateWorkingHours({
    required String captainId,
    required Map<String, dynamic> workingHours,
  }) async {
    try {
      await _supabase
          .from('captains')
          .update({
            'working_hours': workingHours,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);

      AppLogger.info('تم تحديث ساعات عمل الكابتن: $captainId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث ساعات العمل: ${e.message}', e);
      throw Exception('فشل تحديث ساعات العمل: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث ساعات العمل', e);
      throw Exception('فشل تحديث ساعات العمل: ${e.toString()}');
    }
  }

  /// الحصول على إحصائيات عامة للكابتنز
  static Future<Map<String, dynamic>> getGeneralStats() async {
    try {
      // إجمالي الكابتنز
      final totalCaptainsResponse = await _supabase
          .from('captains')
          .select('id')
          .count(CountOption.exact);

      // الكابتنز النشطين
      final activeCaptainsResponse = await _supabase
          .from('captains')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      // الكابتنز المتاحين حالياً
      final availableCaptainsResponse = await _supabase
          .from('captains')
          .select('id')
          .eq('is_active', true)
          .eq('is_online', true)
          .eq('is_available', true)
          .count(CountOption.exact);

      // الكابتنز المعتمدين
      final verifiedCaptainsResponse = await _supabase
          .from('captains')
          .select('id')
          .eq('verification_status', 'approved')
          .count(CountOption.exact);

      // متوسط التقييمات من جدول captains مباشرة
      final ratingsResponse = await _supabase
          .from('captains')
          .select('rating, rating_count')
          .gt('rating_count', 0);

      double averageRating = 0.0;
      int totalRatings = 0;
      if (ratingsResponse.isNotEmpty) {
        double totalWeightedRating = 0;
        for (final r in ratingsResponse) {
          final rating = (r['rating'] as num).toDouble();
          final count = r['rating_count'] as int;
          totalWeightedRating += rating * count;
          totalRatings += count;
        }
        if (totalRatings > 0) {
          averageRating = totalWeightedRating / totalRatings;
        }
      }

      AppLogger.info('تم استرجاع الإحصائيات العامة للكابتنز');

      return {
        'totalCaptains': totalCaptainsResponse.count,
        'activeCaptains': activeCaptainsResponse.count,
        'availableCaptains': availableCaptainsResponse.count,
        'verifiedCaptains': verifiedCaptainsResponse.count,
        'averageRating': averageRating,
        'totalRatings': totalRatings,
        'verificationRate': totalCaptainsResponse.count > 0
            ? (verifiedCaptainsResponse.count / totalCaptainsResponse.count) *
                  100
            : 0.0,
        'activeRate': totalCaptainsResponse.count > 0
            ? (activeCaptainsResponse.count / totalCaptainsResponse.count) * 100
            : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في استرجاع الإحصائيات العامة: ${e.message}',
        e,
      );
      throw Exception('فشل استرجاع الإحصائيات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع الإحصائيات العامة', e);
      throw Exception('فشل استرجاع الإحصائيات: ${e.toString()}');
    }
  }

  // ================================
  // 🛠️ Helper Functions
  // ================================

  /// التحقق من صحة رقم الرخصة
  static bool validateLicenseNumber(String licenseNumber) {
    // تحقق بسيط - يمكن تخصيصه حسب معايير البلد
    return licenseNumber.isNotEmpty && licenseNumber.length >= 6;
  }

  /// التحقق من صحة رقم لوحة المركبة
  static bool validateVehiclePlate(String vehiclePlate) {
    // تحقق بسيط - يمكن تخصيصه حسب معايير البلد
    return vehiclePlate.isNotEmpty && vehiclePlate.length >= 4;
  }

  /// التحقق من صحة رقم الهوية الوطنية
  static bool validateNationalId(String nationalId) {
    // تحقق بسيط - يمكن تخصيصه حسب معايير البلد
    return nationalId.isNotEmpty && nationalId.length >= 10;
  }
}
