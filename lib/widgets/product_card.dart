import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

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
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildDefaultCard(context);
  }

  /// البطاقة الافتراضية (الكبيرة)
  Widget _buildDefaultCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج مع أيقونة المفضلة
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: Icon(Icons.image, color: Colors.grey[400]),
                            );
                          },
                        )
                      : Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            color: Colors.grey[400],
                            size: 48,
                          ),
                        ),
                ),
                // أيقونة المفضلة
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onFavoritePressed?.call();
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // معلومات المنتج
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: nameMaxLines,
                    overflow: nameOverflow,
                  ),

                  SizedBox(height: 4),

                  // السعر
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(2)} ر.س',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                        maxLines: priceMaxLines,
                        overflow: priceOverflow,
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  // المخزون
                  if (product.stock < 10 && product.stock > 0)
                    Text(
                      'آخر ${product.stock} قطع',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),

                  SizedBox(height: 8),

                  // ✅ زر الشراء
                  if (onBuyPressed != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onBuyPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('اشتري الآن'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              color: colorScheme.onSurfaceVariant,
                              size: 40,
                            ),
                          ),
                  ),
                  // أيقونة المفضلة
                  Positioned(
                    top: 6,
                    right: 6,
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
                ],
              ),
            ),

            // معلومات المنتج
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ر.س',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                      if (onBuyPressed != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onBuyPressed?.call();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 16,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
