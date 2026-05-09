import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/delivery_company_model.dart';

class DeliveryCompanyService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// جلب جميع مكاتب التوصيل
  static Future<List<DeliveryCompanyModel>> getAllCompanies() async {
    try {
      final response = await _supabase
          .from('delivery_companies')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => DeliveryCompanyModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب مكاتب التوصيل: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب مكاتب التوصيل', e);
      return [];
    }
  }

  /// جلب مكتب توصيل محدد بالمعرّف
  static Future<DeliveryCompanyModel?> getCompanyById(String companyId) async {
    try {
      final response = await _supabase
          .from('delivery_companies')
          .select()
          .eq('id', companyId)
          .single();

      return DeliveryCompanyModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب المكتب: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب المكتب', e);
      return null;
    }
  }

  /// جلب مكتب التوصيل الخاص بـ admin معين
  static Future<DeliveryCompanyModel?> getCompanyByAdminId(
    String adminId,
  ) async {
    try {
      final response = await _supabase
          .from('delivery_companies')
          .select()
          .eq('admin_id', adminId)
          .maybeSingle();

      if (response == null) return null;
      return DeliveryCompanyModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب مكتب الأدمن: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب مكتب الأدمن', e);
      return null;
    }
  }

  /// إضافة مكتب توصيل جديد
  static Future<DeliveryCompanyModel?> createCompany({
    required String companyName,
    String? ownerEmail,
    String? ownerName,
    String? ownerPhone,
    String? ownerImagePath,
    required String city,
    String? governorate,
    String? address,
    double? latitude,
    double? longitude,
    String? adminId,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'company_name': companyName,
        'owner_email': ownerEmail,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'owner_image_path': ownerImagePath,
        'city': city,
        'governorate': governorate,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'admin_id': adminId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('delivery_companies')
          .insert(data)
          .select()
          .single();

      AppLogger.info('✅ تم إنشاء مكتب توصيل جديد: $companyName');
      return DeliveryCompanyModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء مكتب: ${e.message}', e);
      throw Exception('فشل إنشاء مكتب التوصيل: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء مكتب التوصيل', e);
      throw Exception('فشل إنشاء مكتب التوصيل: $e');
    }
  }

  /// تحديث مكتب توصيل
  static Future<DeliveryCompanyModel?> updateCompany({
    required String companyId,
    String? companyName,
    String? ownerEmail,
    String? ownerName,
    String? ownerPhone,
    String? ownerImagePath,
    String? city,
    String? governorate,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (companyName != null) updateData['company_name'] = companyName;
      if (ownerEmail != null) updateData['owner_email'] = ownerEmail;
      if (ownerName != null) updateData['owner_name'] = ownerName;
      if (ownerPhone != null) updateData['owner_phone'] = ownerPhone;
      if (ownerImagePath != null) {
        updateData['owner_image_path'] = ownerImagePath;
      }
      if (city != null) updateData['city'] = city;
      if (governorate != null) updateData['governorate'] = governorate;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;

      final response = await _supabase
          .from('delivery_companies')
          .update(updateData)
          .eq('id', companyId)
          .select()
          .single();

      AppLogger.info('✅ تم تحديث مكتب التوصيل: $companyId');
      return DeliveryCompanyModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث المكتب: ${e.message}', e);
      throw Exception('فشل تحديث مكتب التوصيل: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث مكتب التوصيل', e);
      throw Exception('فشل تحديث مكتب التوصيل: $e');
    }
  }

  /// حذف مكتب توصيل
  static Future<bool> deleteCompany(String companyId) async {
    try {
      await _supabase.from('delivery_companies').delete().eq('id', companyId);

      AppLogger.info('✅ تم حذف مكتب التوصيل: $companyId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف المكتب: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في حذف مكتب التوصيل', e);
      return false;
    }
  }

  /// قائمة المدن المتاحة (للاختيار)
  static const List<String> availableCities = [
    'Cairo',
    'Giza',
    'Helwan',
    'Qalyubia',
    'Monufia',
    'Dakahlia',
    'Port Said',
    'Ismailia',
    'Suez',
    'Sharqia',
    'Kafr el-Sheikh',
    'Beheira',
    'Alexandria',
    'Faiyum',
    'Beni Suef',
    'Al Minya',
    'Assiut',
    'Sohag',
    'Qena',
    'Luxor',
    'Aswan',
    'Matrouh',
    'New Valley',
    'Red Sea',
  ];

  /// قائمة المحافظات
  static const List<String> availableGovernorates = [
    'Cairo',
    'Giza',
    'Qalyubia',
    'Monufia',
    'Dakahlia',
    'Port Said',
    'Ismailia',
    'Suez',
    'Sharqia',
    'Kafr el-Sheikh',
    'Beheira',
    'Alexandria',
    'Faiyum',
    'Beni Suef',
    'Al Minya',
    'Assiut',
    'Sohag',
    'Qena',
    'Luxor',
    'Aswan',
    'Matrouh',
    'New Valley',
    'Red Sea',
  ];
}
