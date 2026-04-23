import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';
import '../core/logger.dart';

/// خدمة إدارة الفئات
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
class CategoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20;

  // ================================
  // 📂 Category CRUD Operations
  // ================================

  /// إنشاء فئة جديدة
  static Future<CategoryModel?> createCategory({
    required String name,
    String? description,
    String? imageUrl,
    int order = 0,
    bool isActive = true,
    bool isFeatured = false,
    String? iconName,
    String? colorCode,
    String? parentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // التحقق من عدم تكرار الاسم
      final existing = await getCategoryByName(name);
      if (existing != null) {
        AppLogger.error('فئة بنفس الاسم موجودة مسبقاً: $name', null);
        throw Exception('فئة بنفس الاسم موجودة مسبقاً');
      }

      // ملاحظة مهمة:
      // جدول categories الفعلي يحتوي حقولاً محددة (name, description, icon,
      // image_url, display_order, is_active ...). إرسال حقول غير موجودة يسبب
      // PostgrestException أثناء الإضافة.
      final categoryData = <String, dynamic>{
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'display_order': order,
        'is_active': isActive,
      };

      // بعض البيئات تحتوي عمود icon بدل icon_name.
      if (iconName != null && iconName.trim().isNotEmpty) {
        categoryData['icon'] = iconName.trim();
      }

      final response = await _supabase
          .from('categories')
          .insert(categoryData)
          .select()
          .single();

      AppLogger.info('تم إنشاء فئة جديدة: $name');
      return CategoryModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء الفئة: ${e.message}', e);
      throw Exception('فشل إنشاء الفئة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الفئة', e);
      throw Exception('فشل إنشاء الفئة: ${e.toString()}');
    }
  }

  /// جلب فئة محددة
  static Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('id', categoryId)
          .single();

      return CategoryModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئة: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئة', e);
      return null;
    }
  }

  /// جلب فئة بالاسم
  static Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .ilike('name', name)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return CategoryModel.fromMap(response);
      }
      return null;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئة بالاسم: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئة بالاسم', e);
      return null;
    }
  }

  /// جلب جميع الفئات مع دعم Pagination والفلترة
  static Future<List<CategoryModel>> getCategories({
    int page = 1,
    String? searchTerm,
    bool? isActive,
    bool? isFeatured,
    String? parentId,
    String orderBy = 'order',
    bool ascending = true,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase.from('categories').select();

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%',
        );
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (isFeatured != null) {
        query = query.eq('is_featured', isFeatured);
      }

      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات', e);
      return [];
    }
  }

  /// جلب الفئات النشطة فقط
  static Future<List<CategoryModel>> getActiveCategories({
    String orderBy = 'order',
    bool ascending = true,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order(orderBy, ascending: ascending);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات النشطة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات النشطة', e);
      return [];
    }
  }

  /// جلب الفئات المميزة
  static Future<List<CategoryModel>> getFeaturedCategories({
    int limit = 10,
    String orderBy = 'order',
    bool ascending = true,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .eq('is_featured', true)
          .order(orderBy, ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات المميزة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات المميزة', e);
      return [];
    }
  }

  /// جلب الفئات الرئيسية (بدون parent)
  static Future<List<CategoryModel>> getMainCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .isFilter('parent_id', null)
          .eq('is_active', true)
          .order('order', ascending: true);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات الرئيسية: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات الرئيسية', e);
      return [];
    }
  }

  /// جلب الفئات الفرعية
  static Future<List<CategoryModel>> getSubCategories(String parentId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('parent_id', parentId)
          .eq('is_active', true)
          .order('order', ascending: true);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات الفرعية: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات الفرعية', e);
      return [];
    }
  }

  /// تحديث فئة
  static Future<CategoryModel?> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? imageUrl,
    int? order,
    bool? isActive,
    bool? isFeatured,
    String? iconName,
    String? colorCode,
    String? parentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (name != null) {
        // التحقق من عدم تكرار الاسم
        final existing = await getCategoryByName(name);
        if (existing != null && existing.id != categoryId) {
          throw Exception('فئة بنفس الاسم موجودة مسبقاً');
        }
        data['name'] = name;
      }

      if (description != null) data['description'] = description;
      if (imageUrl != null) data['image_url'] = imageUrl;
      if (order != null) data['display_order'] = order;
      if (isActive != null) data['is_active'] = isActive;
      if (iconName != null) data['icon'] = iconName;
      // الحقول التالية غير موجودة في جدول categories - تم تجاهلها
      // isFeatured, colorCode, parentId, metadata

      final response = await _supabase
          .from('categories')
          .update(data)
          .eq('id', categoryId)
          .select()
          .single();

      AppLogger.info('تم تحديث الفئة: ${response['name']}');
      return CategoryModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث الفئة: ${e.message}', e);
      throw Exception('فشل تحديث الفئة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث الفئة', e);
      throw Exception('فشل تحديث الفئة: ${e.toString()}');
    }
  }

  /// حذف فئة
  static Future<bool> deleteCategory(String categoryId) async {
    try {
      // التحقق من عدم وجود منتجات في الفئة
      final productsCount = await getProductsCountByCategory(categoryId);
      if (productsCount > 0) {
        AppLogger.error('لا يمكن حذف الفئة لأنها تحتوي على منتجات', null);
        throw Exception(
          'لا يمكن حذف الفئة لأنها تحتوي على $productsCount منتج',
        );
      }

      // التحقق من عدم وجود فئات فرعية
      final subCategories = await getSubCategories(categoryId);
      if (subCategories.isNotEmpty) {
        AppLogger.error('لا يمكن حذف الفئة لأنها تحتوي على فئات فرعية', null);
        throw Exception(
          'لا يمكن حذف الفئة لأنها تحتوي على ${subCategories.length} فئة فرعية',
        );
      }

      await _supabase.from('categories').delete().eq('id', categoryId);

      AppLogger.info('تم حذف الفئة بنجاح');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف الفئة: ${e.message}', e);
      throw Exception('فشل حذف الفئة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف الفئة', e);
      throw Exception('فشل حذف الفئة: ${e.toString()}');
    }
  }

  // ================================
  // 📊 Category Statistics
  // ================================

  /// جلب عدد المنتجات في فئة
  static Future<int> getProductsCountByCategory(String categoryId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id')
          .eq('category_id', categoryId);

      return (response as List).length;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب عدد المنتجات: ${e.message}', e);
      return 0;
    } catch (e) {
      AppLogger.error('خطأ في جلب عدد المنتجات', e);
      return 0;
    }
  }

  /// تحديث عداد المنتجات في الفئة
  static Future<bool> updateProductCount(String categoryId) async {
    try {
      final count = await getProductsCountByCategory(categoryId);

      await _supabase
          .from('categories')
          .update({
            'product_count': count,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', categoryId);

      AppLogger.info('تم تحديث عداد المنتجات للفئة $categoryId: $count');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث عداد المنتجات: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تحديث عداد المنتجات', e);
      return false;
    }
  }

  /// إحصائيات الفئات
  static Future<Map<String, dynamic>> getCategoriesStatistics() async {
    try {
      final allCategories = await _supabase.from('categories').select('*');

      final total = allCategories.length;
      final active = allCategories.where((c) => c['is_active'] == true).length;
      final featured = allCategories
          .where((c) => c['is_featured'] == true)
          .length;
      final mainCategories = allCategories
          .where((c) => c['parent_id'] == null)
          .length;
      final subCategories = allCategories
          .where((c) => c['parent_id'] != null)
          .length;

      // حساب إجمالي المنتجات
      final productsResponse = await _supabase.from('products').select('id');
      final totalProducts = (productsResponse as List).length;

      return {
        'total_categories': total,
        'active_categories': active,
        'featured_categories': featured,
        'main_categories': mainCategories,
        'sub_categories': subCategories,
        'total_products': totalProducts,
        'average_products_per_category': total > 0
            ? (totalProducts / total).round()
            : 0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب إحصائيات الفئات: ${e.message}', e);
      return {};
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات الفئات', e);
      return {};
    }
  }

  /// أكثر الفئات شعبية (حسب عدد المنتجات)
  static Future<List<Map<String, dynamic>>> getPopularCategories({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*, product_count')
          .eq('is_active', true)
          .order('product_count', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب الفئات الشائعة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات الشائعة', e);
      return [];
    }
  }

  // ================================
  // 🎯 Category Management
  // ================================

  /// تغيير حالة النشاط
  static Future<bool> toggleCategoryStatus(String categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      if (category == null) return false;

      // استخدام البيانات الحالية من قاعدة البيانات
      final response = await _supabase
          .from('categories')
          .select('is_active')
          .eq('id', categoryId)
          .single();

      final currentStatus = response['is_active'] ?? true;
      final newStatus = !currentStatus;

      await updateCategory(categoryId: categoryId, isActive: newStatus);

      AppLogger.info(
        'تم تغيير حالة الفئة $categoryId إلى ${newStatus ? "نشط" : "غير نشط"}',
      );
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة الفئة', e);
      return false;
    }
  }

  /// تغيير حالة التميز
  static Future<bool> toggleFeaturedStatus(String categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      if (category == null) return false;

      // استخدام البيانات الحالية من قاعدة البيانات
      final response = await _supabase
          .from('categories')
          .select('is_featured')
          .eq('id', categoryId)
          .single();

      final currentStatus = response['is_featured'] ?? false;
      final newStatus = !currentStatus;

      await updateCategory(categoryId: categoryId, isFeatured: newStatus);

      AppLogger.info(
        'تم تغيير حالة التميز للفئة $categoryId إلى ${newStatus ? "مميز" : "عادي"}',
      );
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تغيير حالة التميز', e);
      return false;
    }
  }

  /// تحديث ترتيب الفئات
  static Future<bool> updateCategoryOrder(
    String categoryId,
    int newOrder,
  ) async {
    try {
      await updateCategory(categoryId: categoryId, order: newOrder);

      AppLogger.info('تم تحديث ترتيب الفئة $categoryId إلى $newOrder');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث ترتيب الفئة', e);
      return false;
    }
  }

  /// إعادة ترتيب الفئات
  static Future<bool> reorderCategories(
    List<Map<String, dynamic>> categoriesOrder,
  ) async {
    try {
      for (final categoryOrder in categoriesOrder) {
        final categoryId = categoryOrder['id'] as String;
        final order = categoryOrder['order'] as int;

        await updateCategoryOrder(categoryId, order);
      }

      AppLogger.info('تم إعادة ترتيب ${categoriesOrder.length} فئة');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في إعادة ترتيب الفئات', e);
      return false;
    }
  }

  /// نسخ فئة (مع الإعدادات فقط، بدون المنتجات)
  static Future<CategoryModel?> duplicateCategory({
    required String categoryId,
    required String newName,
    String? newDescription,
  }) async {
    try {
      final originalCategory = await getCategoryById(categoryId);
      if (originalCategory == null) {
        throw Exception('الفئة الأصلية غير موجودة');
      }

      return await createCategory(
        name: newName,
        description: newDescription ?? originalCategory.description,
        imageUrl: originalCategory.imageUrl,
        order: 999, // ترتيب في النهاية
        isActive: false, // غير نشطة افتراضياً
        isFeatured: false,
        // إضافة خصائص أخرى إذا كانت متوفرة في النموذج
      );
    } catch (e) {
      AppLogger.error('خطأ في نسخ الفئة', e);
      throw Exception('فشل نسخ الفئة: ${e.toString()}');
    }
  }

  // ================================
  // 🖼️ Image Management
  // ================================

  /// رفع صورة فئة
  static Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath =
          'categories/$categoryId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // رفع الصورة (upsert لتجنب خطأ التكرار)
      await _supabase.storage
          .from('categories')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // الحصول على الرابط العام
      final imageUrl = _supabase.storage
          .from('categories')
          .getPublicUrl(filePath);

      // تحديث الفئة بالصورة الجديدة
      await updateCategory(categoryId: categoryId, imageUrl: imageUrl);

      AppLogger.info('تم رفع صورة الفئة');
      return imageUrl;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع صورة الفئة: ${e.message}', e);
      throw Exception('فشل رفع صورة الفئة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة الفئة', e);
      throw Exception('فشل رفع صورة الفئة: ${e.toString()}');
    }
  }

  /// حذف صورة فئة
  static Future<bool> deleteCategoryImage(String categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      if (category == null || category.imageUrl == null) return false;

      // استخراج مسار الملف من الرابط
      final uri = Uri.parse(category.imageUrl!);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('categories');

      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

        // حذف الصورة من التخزين
        await _supabase.storage.from('categories').remove([filePath]);
      }

      // إزالة رابط الصورة من الفئة
      await updateCategory(categoryId: categoryId, imageUrl: null);

      AppLogger.info('تم حذف صورة الفئة');
      return true;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في حذف صورة الفئة: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في حذف صورة الفئة', e);
      return false;
    }
  }

  // ================================
  // 🔍 Search & Filter
  // ================================

  /// البحث في الفئات
  static Future<List<CategoryModel>> searchCategories({
    required String searchTerm,
    bool activeOnly = true,
    int limit = 20,
  }) async {
    try {
      var query = _supabase
          .from('categories')
          .select()
          .or('name.ilike.%$searchTerm%,description.ilike.%$searchTerm%');

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name', ascending: true).limit(limit);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث في الفئات: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في البحث في الفئات', e);
      return [];
    }
  }

  /// البحث المتقدم في الفئات
  static Future<List<CategoryModel>> advancedSearchCategories({
    String? name,
    String? description,
    bool? isActive,
    bool? isFeatured,
    String? parentId,
    int? minProductCount,
    int? maxProductCount,
    String orderBy = 'name',
    bool ascending = true,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('categories').select();

      if (name != null && name.isNotEmpty) {
        query = query.ilike('name', '%$name%');
      }

      if (description != null && description.isNotEmpty) {
        query = query.ilike('description', '%$description%');
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (isFeatured != null) {
        query = query.eq('is_featured', isFeatured);
      }

      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      }

      if (minProductCount != null) {
        query = query.gte('product_count', minProductCount);
      }

      if (maxProductCount != null) {
        query = query.lte('product_count', maxProductCount);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((data) => CategoryModel.fromMap(data))
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

  /// مراقبة تحديثات الفئات فورياً
  static Stream<List<Map<String, dynamic>>> watchCategories({
    bool? isActive,
    bool? isFeatured,
    String? parentId,
  }) {
    var stream = _supabase.from('categories').stream(primaryKey: ['id']);

    return stream.order('order');
  }

  /// مراقبة فئة محددة
  static Stream<Map<String, dynamic>?> watchCategory(String categoryId) {
    return _supabase
        .from('categories')
        .stream(primaryKey: ['id'])
        .eq('id', categoryId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ================================
  // 📊 Bulk Operations
  // ================================

  /// عمليات مجمعة على الفئات
  static Future<bool> bulkUpdateCategories({
    required List<String> categoryIds,
    bool? isActive,
    bool? isFeatured,
    String? parentId,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isActive != null) data['is_active'] = isActive;
      if (isFeatured != null) data['is_featured'] = isFeatured;
      if (parentId != null) data['parent_id'] = parentId;

      await _supabase
          .from('categories')
          .update(data)
          .inFilter('id', categoryIds);

      AppLogger.info('تم تحديث ${categoryIds.length} فئة');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في التحديث المجمع: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في التحديث المجمع', e);
      return false;
    }
  }

  /// تحديث عدادات المنتجات لجميع الفئات
  static Future<bool> updateAllProductCounts() async {
    try {
      final categories = await getCategories(page: 1);

      for (final category in categories) {
        await updateProductCount(category.id);
      }

      AppLogger.info('تم تحديث عدادات المنتجات لجميع الفئات');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث عدادات المنتجات', e);
      return false;
    }
  }

  // ================================
  // 🛠️ Helper Functions
  // ================================

  /// التحقق من صحة بيانات الفئة
  static bool validateCategoryData({
    required String name,
    String? description,
    String? parentId,
  }) {
    if (name.trim().isEmpty) return false;
    if (name.length < 2 || name.length > 100) return false;
    if (description != null && description.length > 500) return false;

    return true;
  }

  /// تنظيف اسم الفئة
  static String sanitizeCategoryName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// إنشاء slug للفئة
  static String generateCategorySlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// التحقق من وجود صورة
  static bool hasValidImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(imageUrl);
      return uri.isAbsolute && uri.hasScheme;
    } catch (e) {
      return false;
    }
  }

  /// حساب عمق التداخل للفئة
  static Future<int> getCategoryDepth(
    String categoryId, [
    int currentDepth = 0,
  ]) async {
    if (currentDepth > 10) return currentDepth; // حماية من التداخل اللانهائي

    final category = await getCategoryById(categoryId);
    if (category == null) return currentDepth;

    // إذا كانت الفئة لها parent، احسب عمقها
    // (يحتاج إلى تنفيذ parentId في النموذج)
    return currentDepth;
  }
}
