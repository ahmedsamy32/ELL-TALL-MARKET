import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_model.dart';
import '../core/logger.dart';

/// خدمة سلة التسوق المحسنة
/// متوافقة مع الوثائق الرسمية لـ Supabase v2.10.2
/// تدعم العمليات الفورية والتحليلات المتقدمة
class CartService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ================================
  // 🛒 Cart Management Operations
  // ================================

  /// الحصول على سلة المستخدم أو إنشاؤها إذا لم تكن موجودة
  static Future<CartModel?> getUserCart(String userId) async {
    try {
      // البحث عن سلة موجودة
      final response = await _supabase
          .from('carts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return CartModel.fromMap(response);
      }

      // إنشاء سلة جديدة إذا لم تكن موجودة
      return await createNewCart(userId);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب السلة: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب السلة', e);
      return null;
    }
  }

  /// إنشاء سلة جديدة للمستخدم
  static Future<CartModel?> createNewCart(String userId) async {
    try {
      final cartData = {'user_id': userId};

      final response = await _supabase
          .from('carts')
          .insert(cartData)
          .select()
          .single();

      AppLogger.info('تم إنشاء سلة جديدة للمستخدم: $userId');
      return CartModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إنشاء السلة: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء السلة', e);
      return null;
    }
  }

  /// جلب عناصر السلة مع تفاصيل المنتجات
  static Future<List<Map<String, dynamic>>> getCartItemsWithDetails(
    String cartId,
  ) async {
    try {
      final response = await _supabase
          .from('cart_items')
          .select('''
            *,
            products (
              id,
              store_id,
              name,
              description,
              price,
              image_url,
              stock_quantity,
              in_stock,
              is_active,
              created_at,
              stores!inner (
                id,
                name,
                merchant_id,
                min_order,
                delivery_mode,
                delivery_fee
              )
            )
          ''')
          .eq('cart_id', cartId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في جلب عناصر السلة: ${e.message}', e);
      return [];
    } catch (e) {
      AppLogger.error('خطأ في جلب عناصر السلة', e);
      return [];
    }
  }

  // ================================
  // 🛍️ Cart Items Management
  // ================================

  /// إضافة منتج للسلة أو تحديث الكمية إذا كان موجوداً
  static Future<CartItemModel?> addToCart({
    required String userId,
    required String productId,
    int quantity = 1,
  }) async {
    try {
      // التحقق من وجود المنتج وتوفره
      final product = await _checkProductAvailability(productId, quantity);
      if (product == null) {
        throw Exception('المنتج غير متوفر أو الكمية المطلوبة غير كافية');
      }

      // الحصول على السلة أو إنشاؤها
      final cart = await getUserCart(userId);
      if (cart == null) {
        throw Exception('فشل في الحصول على السلة');
      }

      // التحقق من وجود المنتج في السلة
      final existingItem = await _supabase
          .from('cart_items')
          .select()
          .eq('cart_id', cart.id)
          .eq('product_id', productId)
          .maybeSingle();

      if (existingItem != null) {
        // تحديث الكمية للمنتج الموجود
        final newQuantity = (existingItem['quantity'] as int) + quantity;

        // التحقق من توفر الكمية الجديدة
        if (newQuantity > (product['stock_quantity'] as int)) {
          throw Exception('الكمية المطلوبة تتجاوز المخزون المتاح');
        }

        final response = await _supabase
            .from('cart_items')
            .update({
              'quantity': newQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingItem['id'])
            .select()
            .single();

        AppLogger.info('تم تحديث كمية المنتج في السلة');
        return CartItemModel.fromMap(response);
      } else {
        // إضافة منتج جديد للسلة
        final itemData = {
          'cart_id': cart.id,
          'product_id': productId,
          'store_id': product['store_id'],
          'product_name': product['name'],
          'product_price': product['price'],
          'product_image': product['image_url'],
          'quantity': quantity,
          'total_price': (product['price'] as num) * quantity,
        };

        final response = await _supabase
            .from('cart_items')
            .insert(itemData)
            .select()
            .single();

        AppLogger.info('تم إضافة منتج جديد للسلة');
        return CartItemModel.fromMap(response);
      }
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في إضافة المنتج للسلة: ${e.message}', e);
      throw Exception('فشل إضافة المنتج للسلة: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إضافة المنتج للسلة', e);
      throw Exception('فشل إضافة المنتج للسلة: ${e.toString()}');
    }
  }

  /// تحديث كمية منتج في السلة
  static Future<CartItemModel?> updateItemQuantity({
    required String userId,
    required String cartItemId,
    required int newQuantity,
  }) async {
    try {
      if (newQuantity <= 0) {
        throw Exception('الكمية يجب أن تكون أكبر من صفر');
      }

      // التحقق من ملكية العنصر للمستخدم
      final cartItem = await _supabase
          .from('cart_items')
          .select('*, carts!inner(user_id), products(stock_quantity)')
          .eq('id', cartItemId)
          .eq('carts.user_id', userId)
          .single();

      // التحقق من توفر الكمية
      final productStock = cartItem['products']['stock_quantity'] as int;
      if (newQuantity > productStock) {
        throw Exception(
          'الكمية المطلوبة تتجاوز المخزون المتاح ($productStock)',
        );
      }

      final response = await _supabase
          .from('cart_items')
          .update({
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cartItemId)
          .select()
          .single();

      AppLogger.info('تم تحديث كمية المنتج في السلة');
      return CartItemModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث كمية المنتج: ${e.message}', e);
      throw Exception('فشل تحديث كمية المنتج: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث كمية المنتج', e);
      throw Exception('فشل تحديث كمية المنتج: ${e.toString()}');
    }
  }

  /// حذف منتج من السلة
  static Future<bool> removeFromCart({
    required String userId,
    required String cartItemId,
  }) async {
    try {
      // التحقق من ملكية العنصر للمستخدم
      final cartId = await _getCartIdForClient(userId);
      if (cartId == null) {
        throw Exception('لا يمكن العثور على السلة');
      }

      await _supabase
          .from('cart_items')
          .delete()
          .eq('id', cartItemId)
          .eq('cart_id', cartId);

      AppLogger.info('تم حذف المنتج من السلة');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف المنتج: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في حذف المنتج من السلة', e);
      return false;
    }
  }

  /// تفريغ السلة بالكامل
  static Future<bool> clearCart(String userId) async {
    try {
      final cartId = await _getCartIdForClient(userId);
      if (cartId == null) return true;

      await _supabase.from('cart_items').delete().eq('cart_id', cartId);

      AppLogger.info('تم تفريغ السلة بالكامل');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تفريغ السلة: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('خطأ في تفريغ السلة', e);
      return false;
    }
  }

  // ================================
  // 📊 Cart Analytics & Calculations
  // ================================

  /// حساب إجمالي السلة مع التفاصيل
  static Future<Map<String, dynamic>> calculateCartTotal(String userId) async {
    try {
      final cart = await getUserCart(userId);
      if (cart == null) return _getEmptyCartTotal();

      final items = await getCartItemsWithDetails(cart.id);

      double subtotal = 0.0;
      int totalItems = 0;
      int uniqueProducts = 0;
      final Map<String, int> storeItemCounts = {};

      for (final item in items) {
        final product = item['products'];
        final quantity = item['quantity'] as int;
        final price = (product['price'] as num).toDouble();

        subtotal += price * quantity;
        totalItems += quantity;
        uniqueProducts++;

        // تجميع العناصر حسب المتجر
        final storeId = product['stores']['id'] as String;
        storeItemCounts[storeId] = (storeItemCounts[storeId] ?? 0) + quantity;
      }

      // حساب رسوم التوصيل (افتراضية)
      final deliveryFee = _calculateDeliveryFees(storeItemCounts);

      // حساب الضرائب (افتراضية 5%)
      final tax = subtotal * 0.05;

      final total = subtotal + deliveryFee + tax;

      return {
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'tax': tax,
        'total': total,
        'total_items': totalItems,
        'unique_products': uniqueProducts,
        'stores_count': storeItemCounts.length,
        'breakdown': {
          'items': items
              .map(
                (item) => {
                  'product_name': item['products']['name'],
                  'quantity': item['quantity'],
                  'unit_price': item['products']['price'],
                  'line_total':
                      (item['products']['price'] as num) *
                      (item['quantity'] as int),
                },
              )
              .toList(),
        },
      };
    } catch (e) {
      AppLogger.error('خطأ في حساب إجمالي السلة', e);
      return _getEmptyCartTotal();
    }
  }

  /// التحقق من توفر جميع المنتجات في السلة
  static Future<Map<String, dynamic>> validateCartStock(String userId) async {
    try {
      final cart = await getUserCart(userId);
      if (cart == null) return {'valid': true, 'issues': []};

      final items = await getCartItemsWithDetails(cart.id);
      final issues = <Map<String, dynamic>>[];

      for (final item in items) {
        final product = item['products'];
        final requestedQty = item['quantity'] as int;
        final availableStock = product['stock_quantity'] as int;
        final isActive = product['is_active'] as bool;

        if (!isActive) {
          issues.add({
            'type': 'inactive_product',
            'product_name': product['name'],
            'message': 'المنتج غير متاح حالياً',
            'cart_item_id': item['id'],
          });
        } else if (requestedQty > availableStock) {
          issues.add({
            'type': 'insufficient_stock',
            'product_name': product['name'],
            'requested': requestedQty,
            'available': availableStock,
            'message': 'الكمية المطلوبة تتجاوز المخزون المتاح',
            'cart_item_id': item['id'],
          });
        }
      }

      return {
        'valid': issues.isEmpty,
        'issues': issues,
        'total_issues': issues.length,
      };
    } catch (e) {
      AppLogger.error('خطأ في التحقق من توفر المنتجات', e);
      return {'valid': false, 'error': e.toString()};
    }
  }

  // ================================
  // 🔄 Real-time Operations
  // ================================

  /// مراقبة تحديثات السلة فورياً
  static Stream<List<Map<String, dynamic>>> watchCartItems(String userId) {
    return _supabase
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .asyncMap((cartItems) async {
          // فلترة العناصر حسب المستخدم
          final cart = await getUserCart(userId);
          if (cart == null) return <Map<String, dynamic>>[];

          final userCartItems = cartItems
              .where((item) => item['cart_id'] == cart.id)
              .toList();

          // إضافة تفاصيل المنتجات
          final enrichedItems = <Map<String, dynamic>>[];
          for (final item in userCartItems) {
            final productDetails = await _supabase
                .from('products')
                .select('name, price, image_url, stock_quantity')
                .eq('id', item['product_id'])
                .single();

            enrichedItems.add({...item, 'product_details': productDetails});
          }

          return enrichedItems;
        });
  }

  /// مراقبة إجمالي السلة فورياً
  static Stream<Map<String, dynamic>> watchCartTotal(String userId) {
    return watchCartItems(userId).asyncMap((_) async {
      return await calculateCartTotal(userId);
    });
  }

  // ================================
  // 💡 Smart Features
  // ================================

  /// اقتراحات ذكية بناءً على محتوى السلة
  static Future<List<Map<String, dynamic>>> getSmartRecommendations(
    String userId,
  ) async {
    try {
      final cart = await getUserCart(userId);
      if (cart == null) return [];

      final items = await getCartItemsWithDetails(cart.id);
      if (items.isEmpty) return [];

      // جمع معرفات الفئات والمتاجر من السلة الحالية
      final categories = <String>{};
      final stores = <String>{};

      for (final item in items) {
        final product = item['products'];
        if (product['category_id'] != null) {
          categories.add(product['category_id']);
        }
        stores.add(product['stores']['id']);
      }

      // البحث عن منتجات مشابهة
      var recommendationsQuery = _supabase
          .from('products')
          .select('*, stores!inner(name)')
          .eq('is_active', true)
          .limit(10);

      // تجاهل فلترة الفئات مؤقتاً - يمكن إضافتها لاحقاً
      // البحث عن منتجات شائعة بدلاً من ذلك

      final recommendations = await recommendationsQuery;

      // فلترة المنتجات الموجودة في السلة
      final currentProductIds = items.map((item) => item['product_id']).toSet();
      final filteredRecommendations = recommendations
          .where((product) => !currentProductIds.contains(product['id']))
          .toList();

      return List<Map<String, dynamic>>.from(filteredRecommendations);
    } catch (e) {
      AppLogger.error('خطأ في جلب الاقتراحات الذكية', e);
      return [];
    }
  }

  /// تحليل نمط التسوق للمستخدم
  static Future<Map<String, dynamic>> analyzeShoppingPattern(
    String userId,
  ) async {
    try {
      // جلب السلة الحالية
      final currentItems = await getUserCart(userId);
      if (currentItems == null) return {};

      final items = await getCartItemsWithDetails(currentItems.id);

      // جلب الطلبات السابقة (من جدول orders)
      final previousOrders = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('client_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      // تحليل الأنماط
      final storeFrequency = <String, int>{};
      final avgOrderValue = <double>[];

      // تحليل الطلبات السابقة
      for (final order in previousOrders) {
        avgOrderValue.add((order['total_price'] as num).toDouble());
      }

      // تحليل السلة الحالية
      for (final item in items) {
        final product = item['products'];
        final storeId = product['stores']['id'];
        storeFrequency[storeId] = (storeFrequency[storeId] ?? 0) + 1;
      }

      return {
        'total_orders': previousOrders.length,
        'average_order_value': avgOrderValue.isNotEmpty
            ? avgOrderValue.reduce((a, b) => a + b) / avgOrderValue.length
            : 0.0,
        'favorite_stores':
            storeFrequency.entries
                .map((e) => {'store_id': e.key, 'frequency': e.value})
                .toList()
              ..sort(
                (a, b) =>
                    (b['frequency'] as int).compareTo(a['frequency'] as int),
              ),
        'current_cart_value': (await calculateCartTotal(userId))['total'],
        'shopping_frequency': _calculateShoppingFrequency(previousOrders),
      };
    } catch (e) {
      AppLogger.error('خطأ في تحليل نمط التسوق', e);
      return {};
    }
  }

  // ================================
  // 🛠️ Helper Functions
  // ================================

  /// التحقق من توفر المنتج
  static Future<Map<String, dynamic>?> _checkProductAvailability(
    String productId,
    int requestedQuantity,
  ) async {
    try {
      final product = await _supabase
          .from('products')
          .select(
            'id, store_id, stock_quantity, in_stock, is_active, price, name, image_url',
          )
          .eq('id', productId)
          .single();

      if (!(product['is_active'] as bool)) return null;
      if (!(product['in_stock'] as bool)) return null;
      if ((product['stock_quantity'] as int) < requestedQuantity) return null;

      return product;
    } catch (e) {
      return null;
    }
  }

  /// الحصول على معرف السلة للمستخدم
  static Future<String?> _getCartIdForClient(String userId) async {
    try {
      final cart = await getUserCart(userId);
      return cart?.id;
    } catch (e) {
      return null;
    }
  }

  /// حساب رسوم التوصيل
  static double _calculateDeliveryFees(Map<String, int> storeItemCounts) {
    // رسوم أساسية لكل متجر
    return storeItemCounts.length * 10.0; // 10 جنيه لكل متجر
  }

  /// إرجاع إجمالي سلة فارغة
  static Map<String, dynamic> _getEmptyCartTotal() {
    return {
      'subtotal': 0.0,
      'delivery_fee': 0.0,
      'tax': 0.0,
      'total': 0.0,
      'total_items': 0,
      'unique_products': 0,
      'stores_count': 0,
      'breakdown': {'items': []},
    };
  }

  /// حساب معدل التسوق
  static String _calculateShoppingFrequency(List<dynamic> orders) {
    if (orders.length < 2) return 'جديد';

    final firstOrder = DateTime.parse(orders.last['created_at']);
    final lastOrder = DateTime.parse(orders.first['created_at']);
    final daysDiff = lastOrder.difference(firstOrder).inDays;

    if (daysDiff == 0) return 'يومي';

    final avgDaysBetweenOrders = daysDiff / (orders.length - 1);

    if (avgDaysBetweenOrders <= 7) return 'أسبوعي';
    if (avgDaysBetweenOrders <= 30) return 'شهري';
    return 'متقطع';
  }

  // ================================
  // 🧹 Cleanup Operations
  // ================================

  /// جلب معلومات المنتج مع بيانات المتجر (للتحقق من نظام التوصيل)
  static Future<Map<String, dynamic>?> getProductWithStore(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            id,
            store_id,
            name,
            stores!inner (
              id,
              name,
              delivery_mode
            )
          ''')
          .eq('id', productId)
          .maybeSingle();

      if (response == null) return null;

      // تحويل البيانات لتكون سهلة الاستخدام
      final store = response['stores'] as Map<String, dynamic>?;
      return {
        'product_id': response['id'],
        'product_name': response['name'],
        'store_id': response['store_id'],
        'store_name': store?['name'],
        'delivery_mode': store?['delivery_mode'],
      };
    } on PostgrestException catch (e) {
      AppLogger.error('خطأ في جلب معلومات المنتج: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('خطأ في جلب معلومات المنتج', e);
      return null;
    }
  }

  /// تنظيف السلال القديمة المهجورة
  static Future<int> cleanupAbandonedCarts({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      // حذف العناصر من السلال القديمة
      await _supabase
          .from('cart_items')
          .delete()
          .lte('updated_at', cutoffDate.toIso8601String());

      // حذف السلال الفارغة القديمة
      final result = await _supabase
          .from('carts')
          .delete()
          .lte('updated_at', cutoffDate.toIso8601String())
          .select('id');

      AppLogger.info('تم تنظيف ${result.length} سلة مهجورة');
      return result.length;
    } catch (e) {
      AppLogger.error('خطأ في تنظيف السلال المهجورة', e);
      return 0;
    }
  }
}
