import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/rating_star.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onBuyPressed;
  final VoidCallback? onFavoritePressed; // ✅ إضافة دالة المفضلة
  final bool isFavorite; // ✅ إضافة حالة المفضلة
  final bool compact; // ✅ إضافة الوضع المضغوط
  final int nameMaxLines;
  final TextOverflow nameOverflow;
  final int priceMaxLines;
  final TextOverflow priceOverflow;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onBuyPressed,
    this.onFavoritePressed, // ✅ إضافة المعامل
    this.isFavorite = false, // ✅ القيمة الافتراضية
    this.compact = false, // القيمة الافتراضية
    this.nameMaxLines = 2,
    this.nameOverflow = TextOverflow.ellipsis,
    this.priceMaxLines = 1,
    this.priceOverflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    // Always use the compact/grid style as per user request
    return _buildCompactCard(context);
  }

  // _buildDefaultCard deleted as we unified the design to _buildCompactCard

  /// البطاقة المضغوطة (للشبكات) - Material Design 3
  Widget _buildCompactCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج مع أيقونة المفضلة
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage(null, colorScheme);
                            },
                          )
                        : _buildPlaceholderImage(null, colorScheme),
                  ),
                  // غطاء رمادي عند نفاد المخزون
                  if (!product.inStock || product.stockQuantity <= 0)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'غير متوفر',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // أيقونة المفضلة - يسار
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onFavoritePressed?.call();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // تنبيه آخر قطع - يمين (فقط عند وجود مخزون قليل)
                  if (product.inStock &&
                      product.stockQuantity > 0 &&
                      product.stockQuantity < 10)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'آخر ${product.stockQuantity}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // معلومات المنتج - ارتفاع محدد لمنع overflow
            SizedBox(
              height: 96, // زيادة الارتفاع
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${product.price.toStringAsFixed(0)} ج.م',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (product.comparePrice != null &&
                                  product.comparePrice! > product.price)
                                Text(
                                  '${product.comparePrice!.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 10,
                                    color: colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          RatingBar(
                            rating: product.rating,
                            totalReviews: product.reviewCount,
                            showReviewsCount: product.reviewCount > 0,
                          ),
                          const Spacer(),
                          if (onBuyPressed != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap:
                                    (product.inStock &&
                                        product.stockQuantity > 0)
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        onBuyPressed?.call();
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        (product.inStock &&
                                            product.stockQuantity > 0)
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color:
                                        (product.inStock &&
                                            product.stockQuantity > 0)
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// صورة مؤقتة بسيطة عند عدم وجود صورة للمنتج
  Widget _buildPlaceholderImage(double? height, [ColorScheme? colorScheme]) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme?.surfaceContainerHighest ?? Colors.grey[200]!,
            colorScheme?.surfaceContainer ?? Colors.grey[100]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: height != null ? height * 0.35 : 56,
          color: (colorScheme?.onSurfaceVariant ?? Colors.grey[400])
              ?.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
