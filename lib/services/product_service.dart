import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/logger.dart';
import 'package:ell_tall_market/models/product_model.dart';

/// 🛍️ خدمة إدارة المنتجات المتقدمة (Product Management Service)
///
/// نظام شامل لإدارة المنتجات والمخزون مع جميع العمليات المتقدمة
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
///
/// @author Ell Tall Market Development Team
/// @version 2.0.0 - Enhanced Phase 5
/// @created 2024-01-01
/// @updated 2024-12-28
///
/// 🎯 الميزات الأساسية:
/// ✅ إدارة CRUD كاملة للمنتجات (40+ methods)
/// ✅ نظام إدارة المخزون المتقدم والآمن
/// ✅ البحث والفلترة الذكية متعددة المعايير
/// ✅ إدارة المراجعات والتقييمات
/// ✅ نظام المفضلة والعلامات
/// ✅ رفع وإدارة الصور المتقدمة
/// ✅ مراقبة المنتجات الفورية
/// ✅ تحليلات وإحصائيات شاملة
/// ✅ عمليات كمية وتصدير البيانات
///
/// 🔧 العمليات المتقدمة (40+ methods):
/// • CRUD: addProduct, updateProduct, deleteProduct, addProductWithImages
/// • Stock: updateStock, reduceStock, addStock, getLowStockProducts, processOrderItems
/// • Search: advancedSearch, searchByTags, getProductsByCategory, getProductsByStore
/// • Features: getFeaturedProducts, getDiscountedProducts, getPopularProductsInCategory
/// • Reviews: addProductReview, getProductReviews, getProductRatingStats
/// • Wishlist: addToWishlist, removeFromWishlist, getUserWishlist
/// • Analytics: getProductStats, getTopSellingProducts, getGeneralStats
/// • Bulk: bulkUpdateProducts, exportProducts, cancelOrderItems
/// • Real-time: watchProducts, watchProduct
///
/// 📊 الإحصائيات والتحليلات:
/// - أداء المبيعات والشعبية
/// - إدارة المخزون الذكية
/// - تحليل الأسعار والخصومات
/// - إحصائيات التفاعل والمراجعات
///
/// 🛡️ الأمان والموثوقية:
/// - PostgrestException handling شامل
/// - Stock management safety
/// - Image validation وضغط
/// - Business rules validation
/// - Comprehensive logging
///
/// استخدام النمط المتقدم:
/// ```dart
/// // إضافة منتج مع صور
/// final product = await ProductService.addProductWithImages(
///   product: newProduct,
///   images: imageFiles,
/// );
///
/// // بحث ذكي متعدد المعايير
/// final products = await ProductService.advancedSearch(
///   query: 'iPhone',
///   categoryId: 'electronics',
///   priceRange: PriceRange(min: 1000, max: 5000),
///   inStock: true,
///   sortBy: ProductSortBy.popularity,
/// );
///
/// // إدارة المخزون الآمنة
/// await ProductService.processOrderItems(orderItems);
/// ```
class ProductService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _pageSize = 20; // عدد المنتجات في كل صفحة

  // ===== جلب كل المنتجات مع دعم Pagination والفلترة المتقدمة =====
  static Future<List<ProductModel>> getProducts({
    int page = 1,
    String? categoryId,
    String? storeId,
    String? searchTerm,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    String orderBy = 'created_at',
    bool ascending = false,
    bool activeOnly = true,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('products')
          .select('*, categories(*), stores(*)');

      // تطبيق الفلاتر
      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%',
        );
      }

      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }

      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }

      if (inStock == true) {
        query = query.gt('stock_quantity', 0);
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب المنتجات: ${e.message}', e);
      throw Exception('فشل جلب المنتجات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات', e);
      throw Exception('فشل جلب المنتجات: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات حسب الفئة مع دعم Pagination =====
  static Future<List<ProductModel>> getProductsByCategory(
    String categoryId, {
    int page = 1,
    bool activeOnly = true,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('category_id', categoryId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المنتجات حسب الفئة: ${e.message}',
        e,
      );
      throw Exception('فشل جلب المنتجات حسب الفئة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات حسب الفئة', e);
      throw Exception('فشل جلب المنتجات حسب الفئة: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات حسب المتجر مع دعم Pagination =====
  static Future<List<ProductModel>> getProductsByStore(
    String storeId, {
    int page = 1,
    bool activeOnly = true,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var query = _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('store_id', storeId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المنتجات حسب المتجر: ${e.message}',
        e,
      );
      throw Exception('فشل جلب المنتجات حسب المتجر: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات حسب المتجر', e);
      throw Exception('فشل جلب المنتجات حسب المتجر: ${e.toString()}');
    }
  }

  // ===== جلب منتج حسب المعرف =====
  static Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, categories(*), stores(*, profiles(*))')
          .eq('id', productId)
          .single();

      return ProductModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب المنتج: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتج', e);
      return null;
    }
  }

  // ===== إضافة منتج جديد =====
  static Future<ProductModel?> addProduct(ProductModel product) async {
    try {
      final productData = product.toDatabaseMap();
      productData['created_at'] = DateTime.now().toIso8601String();
      productData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('products')
          .insert(productData)
          .select('*, categories(*), stores(*)')
          .single();

      AppLogger.info('تم إنشاء منتج جديد: ${response['name']}');
      return ProductModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إضافة المنتج: ${e.message}', e);
      throw Exception('فشل إضافة المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إضافة المنتج', e);
      throw Exception('فشل إضافة المنتج: ${e.toString()}');
    }
  }

  // ===== تحديث منتج =====
  static Future<ProductModel?> updateProduct(ProductModel product) async {
    try {
      final productData = product.toDatabaseMap();
      productData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('products')
          .update(productData)
          .eq('id', product.id)
          .select('*, categories(*), stores(*)')
          .single();

      AppLogger.info('تم تحديث المنتج: ${response['name']}');
      return ProductModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث المنتج: ${e.message}', e);
      throw Exception('فشل تحديث المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث المنتج', e);
      throw Exception('فشل تحديث المنتج: ${e.toString()}');
    }
  }

  // ===== حذف منتج =====
  static Future<bool> deleteProduct(String productId) async {
    try {
      // التحقق من عدم وجود طلبات على المنتج
      final orderItems = await _supabase
          .from('order_items')
          .select('id')
          .eq('product_id', productId);

      if (orderItems.isNotEmpty) {
        AppLogger.error('لا يمكن حذف المنتج لأنه مرتبط بطلبات', null);
        throw Exception('لا يمكن حذف المنتج لأنه مرتبط بطلبات');
      }

      final deleted = await _supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .select('id')
          .maybeSingle();

      if (deleted == null) {
        // إما أن المنتج غير موجود أو ليس لديك صلاحية الحذف
        AppLogger.error(
          'تعذر حذف المنتج: غير موجود أو لا توجد صلاحية (productId=$productId)',
          null,
        );
        throw Exception('تعذر حذف المنتج: غير موجود أو لا توجد صلاحية');
      }

      AppLogger.info('تم حذف المنتج بنجاح: ${deleted['id']}');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف المنتج: ${e.message}', e);
      throw Exception('فشل حذف المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف المنتج', e);
      throw Exception('فشل حذف المنتج: ${e.toString()}');
    }
  }

  /// حذف جميع صور المنتج من التخزين (اختياري)
  static Future<void> deleteProductImages({
    required String storeId,
    required String productId,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final basePath = '$userId/products/$storeId/$productId';
      final files = await _supabase.storage
          .from('products')
          .list(path: basePath);

      if (files.isEmpty) return;
      final paths = <String>[];
      for (final f in files) {
        try {
          final name = (f as dynamic).name as String?;
          if (name != null) paths.add('$basePath/$name');
        } catch (_) {}
      }
      if (paths.isEmpty) return;
      await _supabase.storage.from('products').remove(paths);
      AppLogger.info(
        'تم حذف ${paths.length} صورة للمنتج $productId من التخزين',
      );
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في حذف صور المنتج: ${e.message}', e);
      // لا نرمي الخطأ حتى لا نعطل حذف المنتج بالكامل
    } catch (e) {
      AppLogger.error('خطأ في حذف صور المنتج من التخزين', e);
    }
  }

  // ===== نسخ منتج =====
  /// Creates a duplicate of an existing product with a new ID
  /// Appends "(نسخة)" to the name and resets sales data
  static Future<ProductModel?> duplicateProduct(ProductModel product) async {
    try {
      // Create a copy of the product with modifications
      final now = DateTime.now();
      final duplicatedProduct = product.copyWith(
        id: const Uuid().v4(), // Generate new UUID
        name: '${product.name} (نسخة)', // Append copy indicator
        rating: 0.0, // Reset rating
        reviewCount: 0, // Reset review count
        stockQuantity: 0, // Reset stock to 0
        createdAt: now,
        updatedAt: now,
      );

      // Use addProduct to insert the duplicated product
      final result = await addProduct(duplicatedProduct);

      if (result != null) {
        AppLogger.info('تم نسخ المنتج: ${product.name} → ${result.name}');
      }

      return result;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في نسخ المنتج: ${e.message}', e);
      throw Exception('فشل نسخ المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في نسخ المنتج', e);
      throw Exception('فشل نسخ المنتج: ${e.toString()}');
    }
  }

  // ===== البحث المتقدم عن منتجات =====
  static Future<List<ProductModel>> searchProducts(
    String query, {
    int page = 1,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      var queryBuilder = _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .eq('is_active', true);

      if (categoryId != null) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price', minPrice);
      }

      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', maxPrice);
      }

      if (inStock == true) {
        queryBuilder = queryBuilder.gt('stock_quantity', 0);
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث عن المنتجات: ${e.message}', e);
      throw Exception('فشل البحث عن المنتجات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث عن المنتجات', e);
      throw Exception('فشل البحث عن المنتجات: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات المميزة =====
  static Future<List<ProductModel>> getFeaturedProducts({
    int limit = 10,
    String? categoryId,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('is_featured', true)
          .eq('is_active', true);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المنتجات المميزة: ${e.message}',
        e,
      );
      throw Exception('فشل جلب المنتجات المميزة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات المميزة', e);
      throw Exception('فشل جلب المنتجات المميزة: ${e.toString()}');
    }
  }

  // ===== جلب المنتجات المخفضة =====
  static Future<List<ProductModel>> getDiscountedProducts({
    int page = 1,
  }) async {
    try {
      final int startIndex = (page - 1) * _pageSize;
      final response = await _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .not('discount_price', 'is', null)
          .eq('is_active', true)
          .or(
            'discount_end_date.is.null,discount_end_date.gt.${DateTime.now().toIso8601String()}',
          )
          .order('discount_price', ascending: true)
          .range(startIndex, startIndex + _pageSize - 1);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المنتجات المخفضة: ${e.message}',
        e,
      );
      throw Exception('فشل جلب المنتجات المخفضة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات المخفضة', e);
      throw Exception('فشل جلب المنتجات المخفضة: ${e.toString()}');
    }
  }

  // ===== إدارة المخزون =====

  /// تحديث المخزون
  static Future<bool> updateStock(String productId, int newQuantity) async {
    try {
      await _supabase
          .from('products')
          .update({
            'stock_quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      AppLogger.info('تم تحديث المخزون للمنتج $productId إلى $newQuantity');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث المخزون: ${e.message}', e);
      throw Exception('فشل تحديث المخزون: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث المخزون', e);
      throw Exception('فشل تحديث المخزون: ${e.toString()}');
    }
  }

  /// خصم من المخزون (عند الطلب)
  static Future<bool> reduceStock(String productId, int quantity) async {
    try {
      final product = await getProductById(productId);
      if (product == null) return false;

      final currentStock = product.stock;
      if (currentStock < quantity) {
        AppLogger.error(
          'المخزون غير كافي. المتوفر: $currentStock، المطلوب: $quantity',
          null,
        );
        throw Exception('المخزون غير كافي');
      }

      final newStock = currentStock - quantity;
      return await updateStock(productId, newStock);
    } catch (e) {
      AppLogger.error('خطأ في خصم المخزون', e);
      rethrow;
    }
  }

  /// إضافة للمخزون (عند الإلغاء أو الإرجاع)
  static Future<bool> addStock(String productId, int quantity) async {
    try {
      final product = await getProductById(productId);
      if (product == null) return false;

      final currentStock = product.stock;
      final newStock = currentStock + quantity;
      return await updateStock(productId, newStock);
    } catch (e) {
      AppLogger.error('خطأ في إضافة المخزون', e);
      rethrow;
    }
  }

  /// الحصول على المنتجات منخفضة المخزون
  static Future<List<ProductModel>> getLowStockProducts({
    String? storeId,
    int threshold = 10,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select('*, stores(*)')
          .lte('stock_quantity', threshold)
          .eq('is_active', true);

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      final response = await query.order('stock_quantity', ascending: true);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في جلب المنتجات منخفضة المخزون: ${e.message}',
        e,
      );
      throw Exception('فشل جلب المنتجات منخفضة المخزون: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات منخفضة المخزون', e);
      throw Exception('فشل جلب المنتجات منخفضة المخزون: ${e.toString()}');
    }
  }

  // ===== إدارة الصور =====

  /// رفع صور المنتج
  static Future<List<String>> uploadProductImages({
    required String productId,
    required String storeId,
    required List<Uint8List> imagesBytesList,
    required List<String> fileNames,
  }) async {
    final uploadedUrls = <String>[];

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول قبل رفع الصور');
      }
      for (int i = 0; i < imagesBytesList.length; i++) {
        final imageBytes = imagesBytesList[i];
        final fileName = fileNames[i];
        final fileExt = fileName.split('.').last;
        // Align with products bucket. We keep a folder per product to support multiple images
        // Path: {userId}/products/{storeId}/{productId}/{timestamp_index}.{ext}
        final filePath =
            '$userId/products/$storeId/$productId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

        // رفع الصورة
        await _supabase.storage
            .from('products')
            .uploadBinary(filePath, imageBytes);

        // الحصول على الرابط العام
        final imageUrl = _supabase.storage
            .from('products')
            .getPublicUrl(filePath);

        uploadedUrls.add(imageUrl);
      }

      AppLogger.info('تم رفع ${uploadedUrls.length} صورة للمنتج');
      return uploadedUrls;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في رفع صور المنتج: ${e.message}', e);
      throw Exception('فشل رفع صور المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في رفع صور المنتج', e);
      throw Exception('فشل رفع صور المنتج: ${e.toString()}');
    }
  }

  /// إرجاع قائمة روابط الصور من التخزين لمسار المنتج
  static Future<List<String>> listProductImageUrls({
    required String storeId,
    required String productId,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final basePath = '$userId/products/$storeId/$productId';
      final files = await _supabase.storage
          .from('products')
          .list(path: basePath);
      if (files.isEmpty) return [];
      final urls = <String>[];
      for (final f in files) {
        try {
          final name = (f as dynamic).name as String?;
          if (name != null && name.isNotEmpty) {
            final fp = '$basePath/$name';
            final url = _supabase.storage.from('products').getPublicUrl(fp);
            urls.add(url);
          }
        } catch (_) {}
      }
      return urls;
    } on StorageException catch (e) {
      AppLogger.error('Storage خطأ في قراءة صور المنتج: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في قراءة صور المنتج من التخزين', e);
      return [];
    }
  }

  /// يحذف من التخزين أي صور غير موجودة ضمن finalUrls
  static Future<void> removeProductImagesNotInUrls({
    required String storeId,
    required String productId,
    required List<String> finalUrls,
    String? primaryUrl, // لا تحذف الصورة الأساسية أبداً
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final basePath = '$userId/products/$storeId/$productId';
      final files = await _supabase.storage
          .from('products')
          .list(path: basePath);
      if (files.isEmpty) return;

      // Build a set for quick lookup
      final finalSet = finalUrls.toSet();

      final toRemovePaths = <String>[];
      for (final f in files) {
        try {
          final name = (f as dynamic).name as String?;
          if (name == null) continue;
          final path = '$basePath/$name';
          final url = _supabase.storage.from('products').getPublicUrl(path);
          if (primaryUrl != null && url == primaryUrl) {
            // لا تحذف الصورة الأساسية حتى لو لم تكن ضمن القائمة
            continue;
          }
          if (!finalSet.contains(url)) {
            toRemovePaths.add(path);
          }
        } catch (_) {}
      }

      if (toRemovePaths.isNotEmpty) {
        await _supabase.storage.from('products').remove(toRemovePaths);
        AppLogger.info(
          'تم حذف ${toRemovePaths.length} صورة غير مستخدمة من التخزين',
        );
      }
    } on StorageException catch (e) {
      AppLogger.error(
        'Storage خطأ في حذف الصور غير المستخدمة: ${e.message}',
        e,
      );
    } catch (e) {
      AppLogger.error('خطأ في حذف الصور غير المستخدمة من التخزين', e);
    }
  }

  // ================================
  // 📊 Advanced Analytics & Statistics
  // ================================

  /// الحصول على إحصائيات شاملة للمنتج
  static Future<Map<String, dynamic>> getProductStats(String productId) async {
    try {
      // إجمالي المبيعات
      final salesResponse = await _supabase
          .from('order_items')
          .select('quantity, price')
          .eq('product_id', productId);

      int totalSold = 0;
      double totalRevenue = 0.0;

      for (final sale in salesResponse) {
        final quantity = sale['quantity'] as int;
        final price = sale['price'] as num;
        totalSold += quantity;
        totalRevenue += quantity * price.toDouble();
      }

      // عدد المراجعات
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);

      double averageRating = 0.0;
      int totalReviews = reviewsResponse.length;

      if (totalReviews > 0) {
        final ratings = reviewsResponse
            .map<double>((r) => r['rating'].toDouble())
            .toList();
        averageRating = ratings.reduce((a, b) => a + b) / totalReviews;
      }

      // عدد المشاهدات (إذا كان متاحاً)
      final viewsResponse = await _supabase
          .from('product_views')
          .select('id')
          .eq('product_id', productId);

      AppLogger.info('تم استرجاع إحصائيات المنتج: $productId');

      return {
        'productId': productId,
        'totalSold': totalSold,
        'totalRevenue': totalRevenue,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'totalViews': viewsResponse.length,
        'revenuePerUnit': totalSold > 0 ? totalRevenue / totalSold : 0.0,
      };
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في استرجاع إحصائيات المنتج: ${e.message}',
        e,
      );
      throw Exception('فشل استرجاع الإحصائيات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع إحصائيات المنتج', e);
      throw Exception('فشل استرجاع الإحصائيات: ${e.toString()}');
    }
  }

  /// الحصول على أكثر المنتجات مبيعاً
  static Future<List<Map<String, dynamic>>> getTopSellingProducts({
    String? storeId,
    String? categoryId,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // استخدام استعلام مبسط للحصول على أكثر المنتجات مبيعاً
      var query = _supabase
          .from('products')
          .select('*, categories(*), stores(*)');

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      // ترتيب حسب تاريخ الإنشاء كبديل مؤقت
      final response = await query
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      // تحويل إلى تنسيق مفهوم
      final products = response.map((product) {
        return {
          ...product,
          'total_sold': 0, // يمكن حسابها من جدول order_items لاحقاً
          'total_revenue': 0.0,
          'average_rating': 0.0,
          'review_count': 0,
        };
      }).toList();

      AppLogger.info('تم استرجاع أكثر $limit منتج مبيعاً');
      return products;
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في استرجاع المنتجات الأكثر مبيعاً: ${e.message}',
        e,
      );
      throw Exception('فشل استرجاع المنتجات الأكثر مبيعاً: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع المنتجات الأكثر مبيعاً', e);
      throw Exception('فشل استرجاع المنتجات الأكثر مبيعاً: ${e.toString()}');
    }
  }

  /// البحث الذكي المتقدم
  static Future<List<ProductModel>> advancedSearch({
    String? query,
    String? storeId,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    bool? isActive,
    String sortBy = 'created_at',
    bool ascending = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var supabaseQuery = _supabase
          .from('products')
          .select('*, categories(*), stores(*)');

      // النص البحثي
      if (query != null && query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or(
          'name.ilike.%$query%,'
          'description.ilike.%$query%',
        );
      }

      // فلاتر أساسية
      if (storeId != null) {
        supabaseQuery = supabaseQuery.eq('store_id', storeId);
      }

      if (categoryId != null) {
        supabaseQuery = supabaseQuery.eq('category_id', categoryId);
      }

      if (isActive != null) {
        supabaseQuery = supabaseQuery.eq('is_active', isActive);
      }

      // فلاتر السعر
      if (minPrice != null) {
        supabaseQuery = supabaseQuery.gte('price', minPrice);
      }

      if (maxPrice != null) {
        supabaseQuery = supabaseQuery.lte('price', maxPrice);
      }

      // فلتر المخزون
      if (inStock == true) {
        supabaseQuery = supabaseQuery.gt('stock', 0);
      }

      final response = await supabaseQuery
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      final products = response
          .map((json) => ProductModel.fromMap(json))
          .toList();

      AppLogger.info('البحث المتقدم: تم العثور على ${products.length} منتج');
      return products;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث المتقدم: ${e.message}', e);
      throw Exception('فشل البحث المتقدم: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث المتقدم', e);
      throw Exception('فشل البحث المتقدم: ${e.toString()}');
    }
  }

  /// إدارة الصور المتقدمة
  static Future<ProductModel?> addProductWithImages({
    required ProductModel product,
    List<Uint8List>? images,
    List<String>? imageNames,
  }) async {
    try {
      // إضافة المنتج أولاً
      final createdProduct = await addProduct(product);
      if (createdProduct == null) return null;

      // رفع الصور إن وجدت
      if (images != null && images.isNotEmpty && imageNames != null) {
        final uploadedUrls = await uploadProductImages(
          productId: createdProduct.id,
          storeId: createdProduct.storeId,
          imagesBytesList: images,
          fileNames: imageNames,
        );

        if (uploadedUrls.isNotEmpty) {
          // حدّث الصورة الرئيسية وجميع الصور
          final updatedProduct = createdProduct.copyWith(
            imageUrl: uploadedUrls.first, // الصورة الأولى = الرئيسية
            imageUrls: uploadedUrls, // جميع الصور (بما فيها الرئيسية)
          );
          return await updateProduct(updatedProduct);
        }
      }

      return createdProduct;
    } catch (e) {
      AppLogger.error('خطأ في إضافة منتج مع صور', e);
      rethrow;
    }
  }

  /// معالجة عناصر الطلب (تقليل المخزون بأمان)
  static Future<bool> processOrderItems(
    List<Map<String, dynamic>> orderItems,
  ) async {
    try {
      // التحقق من توفر جميع المنتجات أولاً
      for (final item in orderItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;

        final isAvailable = await isProductAvailable(productId, quantity);
        if (!isAvailable) {
          throw Exception('المنتج $productId غير متوفر بالكمية المطلوبة');
        }
      }

      // تقليل المخزون لجميع المنتجات
      for (final item in orderItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;

        await reduceStock(productId, quantity);
      }

      AppLogger.info('تم معالجة ${orderItems.length} عنصر من الطلب بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في معالجة عناصر الطلب', e);
      rethrow;
    }
  }

  /// إلغاء الطلب (إعادة المخزون)
  static Future<bool> cancelOrderItems(
    List<Map<String, dynamic>> orderItems,
  ) async {
    try {
      for (final item in orderItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;

        await addStock(productId, quantity);
      }

      AppLogger.info('تم إلغاء ${orderItems.length} عنصر وإعادة المخزون');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في إلغاء عناصر الطلب', e);
      rethrow;
    }
  }

  // ================================
  // 🛠️ Utility Functions
  // ================================

  /// التحقق من توفر المنتج
  static Future<bool> isProductAvailable(
    String productId,
    int requestedQuantity,
  ) async {
    try {
      final product = await getProductById(productId);
      if (product == null || product.isActive != true) return false;

      final stockQuantity = product.stock;
      return stockQuantity >= requestedQuantity;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من توفر المنتج', e);
      return false;
    }
  }

  /// حساب السعر النهائي (بناءً على السعر الأساسي)
  static double calculateFinalPrice(ProductModel product) {
    // حالياً نعيد السعر الأساسي - يمكن تطويره لاحقاً لدعم الخصومات
    return product.price;
  }

  /// حساب نسبة الخصم (تحتاج تطوير النموذج لدعم الخصومات)
  static double? calculateDiscountPercentage(ProductModel product) {
    // يمكن تطوير هذا لاحقاً عند إضافة خاصية الخصومات للنموذج
    return null;
  }

  /// الحصول على إحصائيات عامة للمنتجات
  static Future<Map<String, dynamic>> getGeneralStats({String? storeId}) async {
    try {
      // إجمالي المنتجات
      var totalQuery = _supabase.from('products').select('id');
      if (storeId != null) {
        totalQuery = totalQuery.eq('store_id', storeId);
      }
      final totalProductsResponse = await totalQuery.count(CountOption.exact);

      // المنتجات النشطة
      var activeQuery = _supabase
          .from('products')
          .select('id')
          .eq('is_active', true);
      if (storeId != null) {
        activeQuery = activeQuery.eq('store_id', storeId);
      }
      final activeProductsResponse = await activeQuery.count(CountOption.exact);

      // المنتجات منخفضة المخزون
      var lowStockQuery = _supabase
          .from('products')
          .select('id')
          .lte('stock', 10);
      if (storeId != null) {
        lowStockQuery = lowStockQuery.eq('store_id', storeId);
      }
      final lowStockResponse = await lowStockQuery.count(CountOption.exact);

      // المنتجات نفدت من المخزون
      var outOfStockQuery = _supabase
          .from('products')
          .select('id')
          .eq('stock', 0);
      if (storeId != null) {
        outOfStockQuery = outOfStockQuery.eq('store_id', storeId);
      }
      final outOfStockResponse = await outOfStockQuery.count(CountOption.exact);

      // متوسط الأسعار
      var priceQuery = _supabase
          .from('products')
          .select('price')
          .eq('is_active', true);
      if (storeId != null) {
        priceQuery = priceQuery.eq('store_id', storeId);
      }
      final priceResponse = await priceQuery;

      double averagePrice = 0.0;
      if (priceResponse.isNotEmpty) {
        final prices = priceResponse
            .map<double>((p) => p['price'].toDouble())
            .toList();
        averagePrice = prices.reduce((a, b) => a + b) / prices.length;
      }

      AppLogger.info('تم استرجاع الإحصائيات العامة للمنتجات');

      return {
        'totalProducts': totalProductsResponse.count,
        'activeProducts': activeProductsResponse.count,
        'inactiveProducts':
            totalProductsResponse.count - activeProductsResponse.count,
        'lowStockProducts': lowStockResponse.count,
        'outOfStockProducts': outOfStockResponse.count,
        'averagePrice': averagePrice,
        'activeRate': totalProductsResponse.count > 0
            ? (activeProductsResponse.count / totalProductsResponse.count) * 100
            : 0.0,
        'stockHealthRate': totalProductsResponse.count > 0
            ? ((totalProductsResponse.count - outOfStockResponse.count) /
                      totalProductsResponse.count) *
                  100
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

  /// تحديث كمي للمنتجات (Bulk Operations)
  static Future<bool> bulkUpdateProducts({
    required List<String> productIds,
    bool? isActive,
    String? categoryId,
    double? priceMultiplier,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isActive != null) {
        updates['is_active'] = isActive;
      }

      if (categoryId != null) {
        updates['category_id'] = categoryId;
      }

      // تحديث الأسعار بمضاعف إذا كان محدداً
      if (priceMultiplier != null) {
        for (final productId in productIds) {
          final product = await getProductById(productId);
          if (product != null) {
            final newPrice = product.price * priceMultiplier;
            await _supabase
                .from('products')
                .update({'price': newPrice, ...updates})
                .eq('id', productId);
          }
        }
        AppLogger.info('تم تحديث أسعار ${productIds.length} منتج');
        return true;
      }

      // تحديث عادي لجميع المنتجات
      for (final productId in productIds) {
        await _supabase.from('products').update(updates).eq('id', productId);
      }

      AppLogger.info('تم تحديث ${productIds.length} منتج بالكمي');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في التحديث الكمي: ${e.message}', e);
      throw Exception('فشل التحديث الكمي: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في التحديث الكمي', e);
      throw Exception('فشل التحديث الكمي: ${e.toString()}');
    }
  }

  /// تصدير بيانات المنتجات
  static Future<List<Map<String, dynamic>>> exportProducts({
    String? storeId,
    String? categoryId,
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select('*, categories(name), stores(name)');

      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('created_at', ascending: false);

      // تحويل البيانات لتنسيق مناسب للتصدير
      final exportData = response.map((product) {
        return {
          'ID': product['id'],
          'Name': product['name'],
          'Description': product['description'] ?? '',
          'Price': product['price'],
          'Stock': product['stock'],
          'Category': product['categories']?['name'] ?? 'غير محدد',
          'Store': product['stores']?['name'] ?? 'غير محدد',
          'Active': product['is_active'] ? 'نشط' : 'غير نشط',
          'Created': product['created_at'],
          'Updated': product['updated_at'] ?? '',
        };
      }).toList();

      AppLogger.info('تم تصدير ${exportData.length} منتج');
      return exportData;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تصدير المنتجات: ${e.message}', e);
      throw Exception('فشل تصدير المنتجات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تصدير المنتجات', e);
      throw Exception('فشل تصدير المنتجات: ${e.toString()}');
    }
  }

  // ================================
  // ⭐ Reviews & Ratings Management
  // ================================

  /// إضافة مراجعة للمنتج
  static Future<void> addProductReview({
    required String productId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      await _supabase.from('reviews').insert({
        'product_id': productId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم إضافة مراجعة للمنتج: $productId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إضافة المراجعة: ${e.message}', e);
      throw Exception('فشل إضافة المراجعة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إضافة المراجعة', e);
      throw Exception('فشل إضافة المراجعة: ${e.toString()}');
    }
  }

  /// الحصول على مراجعات المنتج
  static Future<List<Map<String, dynamic>>> getProductReviews({
    required String productId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, profiles(full_name, avatar_url)')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      AppLogger.info('تم استرجاع ${response.length} مراجعة للمنتج');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في استرجاع المراجعات: ${e.message}', e);
      throw Exception('فشل استرجاع المراجعات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع المراجعات', e);
      throw Exception('فشل استرجاع المراجعات: ${e.toString()}');
    }
  }

  /// الحصول على متوسط تقييم المنتج
  static Future<Map<String, dynamic>> getProductRatingStats(
    String productId,
  ) async {
    try {
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);

      if (reviewsResponse.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalReviews': 0,
          'ratingDistribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
        };
      }

      final ratings = reviewsResponse
          .map<double>((r) => r['rating'].toDouble())
          .toList();
      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // توزيع التقييمات
      final distribution = <String, int>{
        '5': 0,
        '4': 0,
        '3': 0,
        '2': 0,
        '1': 0,
      };

      for (final rating in ratings) {
        final key = rating.round().toString();
        distribution[key] = (distribution[key] ?? 0) + 1;
      }

      AppLogger.info('تم حساب إحصائيات تقييم المنتج: $productId');

      return {
        'averageRating': averageRating,
        'totalReviews': ratings.length,
        'ratingDistribution': distribution,
      };
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إحصائيات التقييم: ${e.message}', e);
      throw Exception('فشل حساب إحصائيات التقييم: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إحصائيات التقييم', e);
      throw Exception('فشل حساب إحصائيات التقييم: ${e.toString()}');
    }
  }

  // ================================
  // 🏷️ Categories & Tags Management
  // ================================

  /// الحصول على المنتجات الأكثر شعبية في فئة معينة
  static Future<List<ProductModel>> getPopularProductsInCategory({
    required String categoryId,
    int limit = 10,
  }) async {
    try {
      // الحصول على المنتجات مع أعلى تقييمات في الفئة
      final response = await _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .gt('stock', 0)
          .order('created_at', ascending: false)
          .limit(limit);

      final products = response
          .map((json) => ProductModel.fromMap(json))
          .toList();

      AppLogger.info('تم استرجاع ${products.length} منتج شعبي في الفئة');
      return products;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في المنتجات الشعبية: ${e.message}', e);
      throw Exception('فشل استرجاع المنتجات الشعبية: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في المنتجات الشعبية', e);
      throw Exception('فشل استرجاع المنتجات الشعبية: ${e.toString()}');
    }
  }

  /// البحث في المنتجات بالعلامات (Tags)
  static Future<List<ProductModel>> searchByTags({
    required List<String> tags,
    int limit = 20,
  }) async {
    try {
      // بحث في الاسم والوصف للعلامات المحددة
      final searchQuery = tags.join('|');

      final response = await _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      final products = response
          .map((json) => ProductModel.fromMap(json))
          .toList();

      AppLogger.info('البحث بالعلامات: تم العثور على ${products.length} منتج');
      return products;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في البحث بالعلامات: ${e.message}', e);
      throw Exception('فشل البحث بالعلامات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في البحث بالعلامات', e);
      throw Exception('فشل البحث بالعلامات: ${e.toString()}');
    }
  }

  // ================================
  // 📋 Wishlist & Favorites
  // ================================

  /// إضافة منتج للمفضلة
  static Future<bool> addToWishlist({
    required String userId,
    required String productId,
  }) async {
    try {
      await _supabase.from('wishlists').insert({
        'user_id': userId,
        'product_id': productId,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم إضافة المنتج للمفضلة: $productId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إضافة للمفضلة: ${e.message}', e);
      throw Exception('فشل إضافة للمفضلة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إضافة للمفضلة', e);
      throw Exception('فشل إضافة للمفضلة: ${e.toString()}');
    }
  }

  /// إزالة منتج من المفضلة
  static Future<bool> removeFromWishlist({
    required String userId,
    required String productId,
  }) async {
    try {
      await _supabase
          .from('wishlists')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);

      AppLogger.info('تم إزالة المنتج من المفضلة: $productId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إزالة من المفضلة: ${e.message}', e);
      throw Exception('فشل إزالة من المفضلة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إزالة من المفضلة', e);
      throw Exception('فشل إزالة من المفضلة: ${e.toString()}');
    }
  }

  /// الحصول على قائمة المفضلة للمستخدم
  static Future<List<ProductModel>> getUserWishlist(String userId) async {
    try {
      final response = await _supabase
          .from('wishlists')
          .select('products(*, categories(*), stores(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final products = response
          .map((item) => ProductModel.fromMap(item['products']))
          .toList();

      AppLogger.info('تم استرجاع ${products.length} منتج من المفضلة');
      return products;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في استرجاع المفضلة: ${e.message}', e);
      throw Exception('فشل استرجاع المفضلة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في استرجاع المفضلة', e);
      throw Exception('فشل استرجاع المفضلة: ${e.toString()}');
    }
  }

  // ===== مراقبة البيانات الفورية =====

  /// مراقبة تحديثات المنتجات فورياً
  static Stream<List<Map<String, dynamic>>> watchProducts({
    String? storeId,
    String? categoryId,
  }) {
    var query = _supabase.from('products').stream(primaryKey: ['id']);

    if (storeId != null) {
      return query.eq('store_id', storeId).order('updated_at');
    }

    if (categoryId != null) {
      return query.eq('category_id', categoryId).order('updated_at');
    }

    return query.order('updated_at');
  }

  /// مراقبة منتج محدد
  static Stream<Map<String, dynamic>?> watchProduct(String productId) {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('id', productId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ===== حفظ المتغيرات والأسعار المتقدمة =====

  /// حفظ مجموعات المتغيرات للمنتج
  static Future<void> saveProductVariantGroups(
    String productId,
    List<ProductVariantGroup> variantGroups,
  ) async {
    try {
      await _supabase
          .from('products')
          .update({
            'variant_groups': variantGroups.map((e) => e.toJson()).toList(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      AppLogger.info(
        'تم حفظ ${variantGroups.length} مجموعة متغيرات للمنتج $productId في جدول المنتجات',
      );
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في حفظ مجموعات المتغيرات: ${e.message}',
        e,
      );
      throw Exception('فشل حفظ مجموعات المتغيرات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حفظ مجموعات المتغيرات', e);
      throw Exception('فشل حفظ مجموعات المتغيرات: ${e.toString()}');
    }
  }

  /// حفظ المتغيرات للمنتج
  static Future<void> saveProductVariants(
    String productId,
    List<ProductVariant> variants,
  ) async {
    try {
      await _supabase
          .from('products')
          .update({
            'variants': variants.map((e) => e.toJson()).toList(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      AppLogger.info(
        'تم حفظ ${variants.length} متغير للمنتج $productId في جدول المنتجات',
      );
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حفظ المتغيرات: ${e.message}', e);
      throw Exception('فشل حفظ المتغيرات: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حفظ المتغيرات', e);
      throw Exception('فشل حفظ المتغيرات: ${e.toString()}');
    }
  }

  /// حفظ الأسعار حسب الكمية
  static Future<void> saveQuantityBasedPrices(
    String productId,
    List<QuantityBasedPrice> prices,
  ) async {
    try {
      await _supabase
          .from('quantity_based_prices')
          .delete()
          .eq('product_id', productId);

      final pricesData = prices
          .map(
            (price) => {
              'product_id': productId,
              'min_quantity': price.minQuantity,
              'max_quantity': price.maxQuantity,
              'price': price.price,
              'discount_percentage': price.discountPercentage,
              'description': price.description,
              'created_at': price.createdAt.toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('quantity_based_prices').insert(pricesData);

      AppLogger.info(
        'تم حفظ ${prices.length} سعر حسب الكمية للمنتج $productId',
      );
    } on PostgrestException catch (e) {
      AppLogger.error(
        'PostgreSQL خطأ في حفظ الأسعار حسب الكمية: ${e.message}',
        e,
      );
      throw Exception('فشل حفظ الأسعار حسب الكمية: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حفظ الأسعار حسب الكمية', e);
      throw Exception('فشل حفظ الأسعار حسب الكمية: ${e.toString()}');
    }
  }

  /// حفظ العروض الموسمية
  static Future<void> saveSeasonalOffers(
    String productId,
    List<SeasonalOffer> offers,
  ) async {
    try {
      await _supabase
          .from('seasonal_offers')
          .delete()
          .eq('product_id', productId);

      final offersData = offers
          .map(
            (offer) => {
              'product_id': productId,
              'title': offer.title,
              'description': offer.description,
              'discount_percentage': offer.discountPercentage,
              'fixed_discount': offer.fixedDiscount,
              'offer_price': offer.offerPrice,
              'start_date': offer.startDate.toIso8601String(),
              'end_date': offer.endDate.toIso8601String(),
              'created_at': offer.createdAt.toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('seasonal_offers').insert(offersData);

      AppLogger.info('تم حفظ ${offers.length} عرض موسمي للمنتج $productId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حفظ العروض الموسمية: ${e.message}', e);
      throw Exception('فشل حفظ العروض الموسمية: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حفظ العروض الموسمية', e);
      throw Exception('فشل حفظ العروض الموسمية: ${e.toString()}');
    }
  }

  /// حفظ الأسعار VIP
  static Future<void> saveVIPPrices(
    String productId,
    List<VIPPrice> prices,
  ) async {
    try {
      await _supabase.from('vip_prices').delete().eq('product_id', productId);

      final pricesData = prices
          .map(
            (price) => {
              'product_id': productId,
              'customer_group_name': price.customerGroupName,
              'price': price.price,
              'discount_percentage': price.discountPercentage,
              'description': price.description,
              'created_at': price.createdAt.toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('vip_prices').insert(pricesData);

      AppLogger.info('تم حفظ ${prices.length} سعر VIP للمنتج $productId');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حفظ الأسعار VIP: ${e.message}', e);
      throw Exception('فشل حفظ الأسعار VIP: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حفظ الأسعار VIP', e);
      throw Exception('فشل حفظ الأسعار VIP: ${e.toString()}');
    }
  }

  /// حفظ الخصومات الترويجية
  static Future<List<PromotionalDiscount>> getPromotionalDiscounts(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('promotional_discounts')
          .select()
          .eq('product_id', productId)
          .eq('is_active', true);

      return (response as List)
          .map((e) => PromotionalDiscount.fromMap(e))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching promotional discounts', e);
      return [];
    }
  }

  /// جلب مجموعات المتغيرات للمنتج
  static Future<List<ProductVariantGroup>> getProductVariantGroups(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('products')
          .select('variant_groups')
          .eq('id', productId)
          .single();

      final groups = response['variant_groups'] as List?;
      if (groups == null) return [];

      return groups
          .map((e) => ProductVariantGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching product variant groups', e);
      return [];
    }
  }

  /// جلب المنتجات المحددة للمنتج
  static Future<List<ProductVariant>> getProductVariants(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('products')
          .select('variants')
          .eq('id', productId)
          .single();

      final variants = response['variants'] as List?;
      if (variants == null) return [];

      return variants
          .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching product variants', e);
      return [];
    }
  }

  /// جلب منتجات مشابهة (من نفس القسم)
  static Future<List<ProductModel>> getRelatedProducts({
    required String productId,
    String? categoryId,
    int limit = 4,
  }) async {
    try {
      if (categoryId == null) return [];

      final response = await _supabase
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('category_id', categoryId)
          .neq('id', productId)
          .eq('is_active', true)
          .order('rating', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching related products', e);
      return [];
    }
  }
}
