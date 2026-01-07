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
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage(120);
                          },
                        )
                      : _buildPlaceholderImage(120),
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
                        product.priceFormatted,
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

            // معلومات المنتج - ارتفاع محدد لمنع overflow
            SizedBox(
              height: 68, // ارتفاع ثابت لمنع overflow
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${product.price.toStringAsFixed(0)} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                  Icons.add_rounded,
                                  size: 18,
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
