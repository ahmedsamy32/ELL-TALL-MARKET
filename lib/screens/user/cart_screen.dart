import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/widgets/product_options_bottom_sheet.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

/// شاشة عرض سلة التسوق
///
/// تعرض المنتجات المضافة للسلة مع إمكانية:
/// - عرض تفاصيل كل منتج
/// - تعديل الكمية
/// - حذف المنتجات
/// - إتمام عملية الشراء
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // المنتجات المقترحة - تُحمّل مرة واحدة فقط
  List<ProductModel>? _suggestedProducts;
  bool _isSuggestionsLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  /// تحميل المنتجات المقترحة مرة واحدة فقط
  Future<void> _loadSuggestedProducts(CartProvider cartProvider) async {
    if (_suggestedProducts != null || _isSuggestionsLoading) return;

    setState(() => _isSuggestionsLoading = true);

    try {
      final products = await _getSuggestedProducts(cartProvider);
      if (mounted) {
        setState(() {
          _suggestedProducts = products;
          _isSuggestionsLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل المنتجات المقترحة', e);
      if (mounted) {
        setState(() => _isSuggestionsLoading = false);
      }
    }
  }

  /// التحقق من تسجيل الدخول قبل الانتقال
  void _checkLoginAndNavigate(BuildContext context, VoidCallback action) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  /// الحصول على التسمية الصحيحة لعدد المنتجات (مفرد/مثنى/جمع)
  String _getProductCountLabel(int count) {
    if (count == 0) {
      return 'منتجات'; // صفر منتجات
    } else if (count == 1) {
      return 'منتج'; // منتج واحد
    } else if (count == 2) {
      return 'منتجان'; // منتجان
    } else if (count >= 3 && count <= 10) {
      return 'منتجات'; // 3-10 منتجات
    } else {
      return 'منتجاً'; // 11+ منتجاً
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة التسوق'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (!cartProvider.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearCartDialog(context, cartProvider),
              tooltip: 'إفراغ السلة',
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              AppLogger.info('🔄 جاري تحديث السلة...');
              await cartProvider.loadCart();

              // إعادة تحميل المنتجات المقترحة
              setState(() {
                _suggestedProducts = null;
                _isSuggestionsLoading = false;
              });

              AppLogger.info('✅ تم تحديث السلة بنجاح');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('تم تحديث السلة'),
                      ],
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            child: cartProvider.isEmpty
                ? _buildEmptyCart(context)
                : _buildCartWithItems(cartProvider, context),
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cartProvider) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('تأكيد الإفراغ'),
          ],
        ),
        content: const Text('هل أنت متأكد من إفراغ سلة التسوق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              cartProvider.clearCart();
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('تم إفراغ السلة بنجاح'),
                    ],
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );
  }

  /// بناء واجهة السلة الفارغة
  Widget _buildEmptyCart(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة السلة الفارغة
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 100,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),

            // العنوان
            Text(
              'سلة التسوق فارغة',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // الوصف
            Text(
              'أضف بعض المنتجات الرائعة إلى سلة التسوق',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            // زر التسوق
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('تسوق الآن'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء واجهة السلة التي تحتوي على منتجات
  Widget _buildCartWithItems(CartProvider cartProvider, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deliveryFee = cartProvider.deliveryFee;
    final discount = cartProvider.discount;

    // تحميل المنتجات المقترحة مرة واحدة فقط
    if (_suggestedProducts == null && !_isSuggestionsLoading) {
      _loadSuggestedProducts(cartProvider);
    }

    return Column(
      children: [
        // عدد العناصر
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${cartProvider.cartItems.length} ${_getProductCountLabel(cartProvider.cartItems.length)} في السلة',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // قائمة المنتجات مع الأقسام الإضافية
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // قائمة المنتجات
                ...List.generate(cartProvider.cartItems.length, (index) {
                  final item = cartProvider.cartItems[index];

                  // التحقق من وجود المنتج
                  if (item['product'] == null) {
                    return const SizedBox.shrink();
                  }

                  final product = item['product'] as Map<String, dynamic>;
                  final quantity = item['quantity'] as int;
                  final price = (product['price'] as num?)?.toDouble() ?? 0.0;
                  final itemTotal = price * quantity;
                  final stockQuantity =
                      (product['stock_quantity'] as int?) ?? 0;

                  return _buildCartItem(
                    context,
                    cartProvider,
                    item,
                    product,
                    quantity,
                    price,
                    itemTotal,
                    stockQuantity,
                    index,
                  );
                }),

                const SizedBox(height: 24),

                // قسم "قد يعجبك أيضاً"
                _buildSuggestionsSection(context),

                const SizedBox(height: 24),

                // ملخص الطلب
                _buildOrderSummary(
                  context,
                  cartProvider,
                  deliveryFee,
                  discount,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// بناء بطاقة عنصر في السلة
  Widget _buildCartItem(
    BuildContext context,
    CartProvider cartProvider,
    Map<String, dynamic> item,
    Map<String, dynamic> product,
    int quantity,
    double price,
    double itemTotal,
    int stockQuantity,
    int index,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // الحصول على معلومات التوصيل للمتجر
    final store = product['stores'] as Map<String, dynamic>?;
    final deliveryMode = store?['delivery_mode'] as String? ?? 'store';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10), // 0.04 * 255 = 10
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // تحويل بيانات المنتج من Map إلى ProductModel
            try {
              AppLogger.info('🔍 محاولة فتح تفاصيل المنتج: ${product['name']}');
              AppLogger.info('📦 Product ID: ${product['id']}');

              // التأكد من وجود جميع الحقول المطلوبة
              if (product['store_id'] == null) {
                throw Exception('store_id مفقود من بيانات المنتج');
              }

              // إضافة الحقول المفقودة للتأكد من توافق البيانات
              final completeProduct = {
                ...product,
                'in_stock': product['in_stock'] ?? true,
                'is_active': product['is_active'] ?? true,
                'stock_quantity': product['stock_quantity'] ?? 0,
                'created_at':
                    product['created_at'] ?? DateTime.now().toIso8601String(),
              };
              final productModel = ProductModel.fromMap(completeProduct);
              AppLogger.info('✅ تم تحويل المنتج بنجاح');

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProductDetailScreen(product: productModel),
                ),
              );
              AppLogger.info('✅ تم الانتقال لصفحة التفاصيل');
            } catch (e, stackTrace) {
              AppLogger.error('❌ خطأ في تحويل المنتج', e);
              AppLogger.info('📋 Stack trace: $stackTrace');
              AppLogger.info('📦 بيانات المنتج الكاملة: $product');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ في فتح تفاصيل المنتج: ${e.toString()}'),
                  backgroundColor: Colors.red[700],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة المنتج
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    child: product['image_url'] != null
                        ? Image.network(
                            product['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: colorScheme.outline,
                              );
                            },
                          )
                        : Icon(
                            Icons.image,
                            size: 40,
                            color: colorScheme.outline,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // تفاصيل المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اسم المنتج مع badge المتجر
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? 'منتج',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // عرض الخصائص المختارة
                      if (item['selected_options'] != null &&
                          (item['selected_options'] as Map).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            children:
                                (item['selected_options']
                                        as Map<String, dynamic>)
                                    .entries
                                    .map((entry) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '${entry.key}: ${entry.value}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                          ),
                        ),
                      const SizedBox(height: 6),

                      // badge نظام التوصيل فقط
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: deliveryMode == 'store'
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: deliveryMode == 'store'
                                ? Colors.blue.shade200
                                : Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              deliveryMode == 'store'
                                  ? Icons.local_shipping
                                  : Icons.rocket_launch,
                              size: 12,
                              color: deliveryMode == 'store'
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deliveryMode == 'store'
                                  ? 'توصيل المتجر'
                                  : 'توصيل السوق',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: deliveryMode == 'store'
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        '${price.toStringAsFixed(2)} ج.م',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // أزرار التحكم في الكمية
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IntrinsicWidth(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildQuantityButton(
                                        icon: Icons.remove,
                                        onPressed: quantity > 1
                                            ? () async {
                                                final success =
                                                    await cartProvider
                                                        .updateQuantity(
                                                          cartItemId:
                                                              item['id'],
                                                          newQuantity:
                                                              quantity - 1,
                                                        );

                                                if (!success &&
                                                    context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        cartProvider.error ??
                                                            'فشل تحديث الكمية',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red[700],
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      duration: const Duration(
                                                        seconds: 3,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        colorScheme: colorScheme,
                                      ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            '$quantity',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                      ),
                                      _buildQuantityButton(
                                        icon: Icons.add,
                                        onPressed: quantity >= stockQuantity
                                            ? null // تعطيل الزر عند الوصول للمخزون المتاح
                                            : () async {
                                                final success =
                                                    await cartProvider
                                                        .updateQuantity(
                                                          cartItemId:
                                                              item['id'],
                                                          newQuantity:
                                                              quantity + 1,
                                                        );

                                                if (!success &&
                                                    context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        cartProvider.error ??
                                                            'فشل تحديث الكمية',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red[700],
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      duration: const Duration(
                                                        seconds: 3,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        colorScheme: colorScheme,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // عرض المخزون المتاح
                              if (quantity >= stockQuantity ||
                                  stockQuantity <= 5)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    right: 8,
                                  ),
                                  child: Text(
                                    quantity >= stockQuantity
                                        ? 'أقصى كمية متاحة'
                                        : 'متبقي $stockQuantity فقط',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: quantity >= stockQuantity
                                          ? Colors.orange[700]
                                          : colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _showRemoveItemDialog(
                              context,
                              cartProvider,
                              item['id'],
                              product['name'] ?? 'المنتج',
                            ),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red[400],
                            ),
                            tooltip: 'حذف',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // السعر الإجمالي
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      itemTotal.toStringAsFixed(2),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ج.م',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء زر التحكم في الكمية (زيادة أو نقصان)
  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// عرض نافذة تأكيد حذف منتج من السلة
  void _showRemoveItemDialog(
    BuildContext context,
    CartProvider cartProvider,
    String itemId,
    String productName,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            const Text('حذف المنتج'),
          ],
        ),
        content: Text('هل تريد حذف "$productName" من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              cartProvider.removeItem(itemId);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: colorScheme.onPrimary),
                      const SizedBox(width: 12),
                      Expanded(child: Text('تم حذف $productName من السلة')),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  /// جلب منتجات مقترحة من نفس المتاجر الموجودة في السلة فقط
  Future<List<ProductModel>> _getSuggestedProducts(
    CartProvider cartProvider,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // جلب الـ store_ids من المنتجات في السلة
      final storeIds = cartProvider.cartItems
          .map((item) {
            final product = item['product'] as Map<String, dynamic>?;
            return product?['store_id'] as String?;
          })
          .whereType<String>()
          .toSet()
          .toList();

      if (storeIds.isEmpty) return [];

      // جلب المنتجات الموجودة في السلة لاستبعادها
      final productIdsInCart = cartProvider.cartItems
          .map((item) {
            final product = item['product'] as Map<String, dynamic>?;
            return product?['id'] as String?;
          })
          .whereType<String>()
          .toList();

      if (productIdsInCart.isEmpty) return [];

      // جلب منتجات من **نفس المتاجر فقط** (لتجنب تعارض التوصيل)
      final response = await supabase
          .from('products')
          .select('*, stores!inner(id, name, merchant_id, delivery_mode)')
          .inFilter('store_id', storeIds)
          .not('id', 'in', '(${productIdsInCart.join(',')})')
          .eq('is_active', true)
          .eq('in_stock', true)
          .limit(10);

      final products = (response as List)
          .where((item) {
            final isActive = item['is_active'] == true;
            final inStock = item['in_stock'] == true;
            final stockQuantity = (item['stock_quantity'] as int?) ?? 0;
            return isActive && inStock && stockQuantity > 0;
          })
          .map((item) => ProductModel.fromMap(item))
          .toList();

      AppLogger.info(
        '✅ تم جلب ${products.length} منتجات مقترحة من نفس المتاجر',
      );
      return products.take(5).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتجات المقترحة', e);
      return [];
    }
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.recommend_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'أكمل طلبك من نفس المتجر',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260, // تم زيادة الارتفاع ليتناسب مع الكارت الجديد
          child: Builder(
            builder: (context) {
              // عرض مؤشر التحميل
              if (_isSuggestionsLoading) {
                return AppShimmer.wrap(
                  context,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 180, // تم زيادة العرض ليتناسب مع الكارت الجديد
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      );
                    },
                  ),
                );
              }

              // عرض حالة فارغة
              if (_suggestedProducts == null || _suggestedProducts!.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد منتجات مقترحة',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }

              final products = _suggestedProducts!;

              return Consumer<FavoritesProvider>(
                builder: (context, favoritesProvider, _) {
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isFavorite = favoritesProvider.isFavorite(
                        product.id,
                      );

                      return SizedBox(
                        width: 180, // تم زيادة العرض لیتناسب مع الكارت الجديد
                        child: ProductCard(
                          product: product,
                          isFavorite: isFavorite,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          onFavoritePressed: () async {
                            final wasFavorite = favoritesProvider
                                .isFavoriteProduct(product.id);
                            await favoritesProvider.toggleFavoriteProduct(
                              product,
                            );
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    wasFavorite
                                        ? 'تمت الإزالة من المفضلة'
                                        : 'تمت الإضافة للمفضلة',
                                  ),
                                  backgroundColor: wasFavorite
                                      ? Colors.red
                                      : Colors.green,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          onBuyPressed: () async {
                            // فحص إذا المنتج عنده خيارات ديناميكية
                            final hasDynamicFields =
                                product.variantGroups != null &&
                                product.variantGroups!.isNotEmpty;

                            if (hasDynamicFields) {
                              // المنتج عنده خيارات → افتح البوتوم شيت
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => ProductOptionsBottomSheet(
                                  product: product,
                                  onAddToCart:
                                      (
                                        quantity,
                                        selectedOptions,
                                        variant,
                                      ) async {
                                        Navigator.pop(context);

                                        final cartProvider =
                                            Provider.of<CartProvider>(
                                              context,
                                              listen: false,
                                            );

                                        final success = await cartProvider
                                            .addToCart(
                                              productId: product.id,
                                              quantity: quantity,
                                              selectedOptions: selectedOptions,
                                            );

                                        if (context.mounted) {
                                          if (success) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'تمت إضافة ${product.name} للسلة',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  cartProvider.error ??
                                                      'فشلت إضافة المنتج',
                                                ),
                                                backgroundColor:
                                                    Colors.red[700],
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                ),
                              );
                            } else {
                              // المنتج بدون خيارات → أضفه للسلة مباشرة
                              final cartProvider = Provider.of<CartProvider>(
                                context,
                                listen: false,
                              );

                              final success = await cartProvider.addToCart(
                                productId: product.id,
                                quantity: 1,
                              );

                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'تمت إضافة ${product.name} للسلة',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        cartProvider.error ??
                                            'فشلت إضافة المنتج',
                                      ),
                                      backgroundColor: Colors.red[700],
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// بناء ملخص الطلب في أسفل الشاشة
  Widget _buildOrderSummary(
    BuildContext context,
    CartProvider cartProvider,
    double deliveryFee,
    double discount,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unmetMinimums = cartProvider.unmetMinimumStores;
    final canCheckout = unmetMinimums.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ملخص السعر - ثابت مع إمكانية السكرول إذا كان طويل
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 300, // أقصى ارتفاع قبل ما يصير scrollable
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان ملخص الطلب
                      Text(
                        'ملخص الطلب',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // قائمة المنتجات
                      ...cartProvider.cartItems.map((item) {
                        final product =
                            item['product'] as Map<String, dynamic>?;
                        if (product == null) return const SizedBox.shrink();

                        final name = product['name'] as String? ?? 'منتج';
                        final quantity = item['quantity'] as int;
                        final price =
                            (product['price'] as num?)?.toDouble() ?? 0.0;
                        final total = price * quantity;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // اسم المنتج والكمية
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الكمية: $quantity × ${price.toStringAsFixed(2)} ج.م',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // السعر الإجمالي للمنتج
                              Text(
                                '${total.toStringAsFixed(2)} ج.م',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      Divider(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        thickness: 1,
                      ),
                      const SizedBox(height: 8),

                      // الإجمالي النهائي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الإجمالي',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${cartProvider.subtotal.toStringAsFixed(2)} ج.م',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (unmetMinimums.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildMinOrderWarning(context, unmetMinimums),
            ],
            const SizedBox(height: 20),

            // أزرار الإجراء
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // العودة للصفحة الرئيسية لإضافة المزيد
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    child: const Text(
                      'أضف المزيد',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: canCheckout
                        ? () => _checkLoginAndNavigate(context, () {
                            Navigator.pushNamed(context, AppRoutes.checkout);
                          })
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'تابع الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinOrderWarning(
    BuildContext context,
    List<StoreMinimumStatus> unmetMinimums,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'يجب الوصول للحد الأدنى للطلب قبل الإكمال',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...unmetMinimums.map(
            (status) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'متجر ${status.storeName}: أضف ${status.remaining.toStringAsFixed(2)} ج.م للوصول إلى ${status.minimum.toStringAsFixed(2)} ج.م',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
