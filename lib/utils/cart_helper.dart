import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/widgets/product_options_bottom_sheet.dart';

class CartHelper {
  static void addToCart(BuildContext context, ProductModel product) {
    if (product.variantGroups != null && product.variantGroups!.isNotEmpty) {
      _showProductOptionsSheet(context, product);
    } else {
      _processAddToCart(context, product, 1, null, null);
    }
  }

  static void _showProductOptionsSheet(
    BuildContext context,
    ProductModel product,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductOptionsBottomSheet(
        product: product,
        onAddToCart: (quantity, options, variant) {
          Navigator.pop(ctx);
          // Pass the original context to process add to cart
          _processAddToCart(context, product, quantity, options, variant);
        },
      ),
    );
  }

  static void _checkLoginAndNavigate(BuildContext context, Function action) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  static void _processAddToCart(
    BuildContext context,
    ProductModel product,
    int quantity,
    Map<String, dynamic>? options,
    ProductVariant? variant,
  ) async {
    _checkLoginAndNavigate(context, () async {
      // Ensure context is still valid
      if (!context.mounted) return;

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);

      // Show Loading
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: AppShimmer.wrap(
                    context,
                    child: AppShimmer.circle(context, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('جاري الإضافة...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Check Delivery Conflict (يستعلم delivery_mode للمتجر الجديد لو مختلف)
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );
      final conflict = await cartProvider.checkDeliveryModeConflictByStoreId(
        productStoreId: product.storeId,
        userLat: locationProvider.latitude,
        userLng: locationProvider.longitude,
      );

      if (!context.mounted) return;

      if (conflict != null) {
        // Clear Loading
        messenger.clearSnackBars();

        // Check again if mounted before showing dialog
        if (!context.mounted) return;

        // Show Confirmation Dialog
        final shouldClear = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                const Text('بدء سلة جديدة؟'),
              ],
            ),
            content: Text(conflict.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('نعم، ابدأ طلب جديد'),
              ),
            ],
          ),
        );

        if (shouldClear != true) return;

        // Show Clearing Cart Loading
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: AppShimmer.wrap(
                      context,
                      child: AppShimmer.circle(context, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('جاري مسح السلة...'),
                ],
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Clear Cart
        await cartProvider.clearCart();

        // Update Message
        if (context.mounted) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: AppShimmer.wrap(
                      context,
                      child: AppShimmer.circle(context, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('جاري إضافة المنتج...'),
                ],
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Add To Cart
      final success = await cartProvider.addToCart(
        productId: product.id,
        quantity: quantity,
        selectedOptions: options,
      );

      if (context.mounted) {
        messenger.clearSnackBars();

        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('تمت إضافة ${product.name} إلى السلة'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('فشل إضافة المنتج إلى السلة'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }
}
