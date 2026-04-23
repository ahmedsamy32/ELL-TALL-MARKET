import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    // التحقق من حالة التثبيت والبيانات
    if (!mounted) return;

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

    if (authProvider.isLoggedIn && authProvider.currentUser != null) {
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );

      try {
        if (mounted) setState(() => _isRefreshing = true);

        // جلب الفئات والمنتجات معاً لضمان ظهور الأسماء الصحيحة
        final categoryProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );
        final storeProvider = Provider.of<StoreProvider>(
          context,
          listen: false,
        );

        await Future.wait([
          favoritesProvider.loadUserFavorites(authProvider.currentUser!.id),
          if (categoryProvider.categories.isEmpty)
            categoryProvider.fetchCategories(),
        ]);

        // تحديث خريطة الفئات في StoreProvider
        if (categoryProvider.categories.isNotEmpty) {
          final mapping = <String, String>{};
          for (final cat in categoryProvider.categories) {
            mapping[cat.id] = cat.name;
          }
          storeProvider.updateCategoryMapping(mapping);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ فشل تحميل المفضلة: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isRefreshing = false);
      }
    }
  }

  Widget _buildShimmerGrid(BuildContext context) {
    return AppShimmer.wrap(
      context,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.responsiveCrossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _navigateToProductDetail(BuildContext context, ProductModel product) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
  }

  void _navigateToStoreDetail(BuildContext context, StoreModel store) {
    Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
  }

  void _checkLoginForAction(
    BuildContext context,
    VoidCallback action, {
    String? loginMessage,
  }) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginMessage ?? 'يرجى تسجيل الدخول أولاً'),
          action: SnackBarAction(
            label: 'تسجيل الدخول',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Consumer<SupabaseProvider>(
        builder: (context, authProvider, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 24),
                  SizedBox(width: 12),
                  Text('المفضلة'),
                ],
              ),
              centerTitle: true,
              actions: const [],
              bottom: authProvider.isLoggedIn
                  ? const TabBar(
                      tabs: [
                        Tab(text: 'المنتجات', icon: Icon(Icons.shopping_bag)),
                        Tab(text: 'المتاجر', icon: Icon(Icons.storefront)),
                      ],
                    )
                  : null,
            ),
            body: authProvider.isLoggedIn
                ? Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      if (favoritesProvider.isLoading || _isRefreshing) {
                        return _buildShimmerGrid(context);
                      }

                      if (favoritesProvider.error != null) {
                        return _buildErrorState(
                          favoritesProvider.error!,
                          colorScheme,
                        );
                      }

                      return TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: _loadFavorites,
                            child: _buildProductsGrid(
                              context,
                              favoritesProvider,
                              colorScheme,
                            ),
                          ),
                          RefreshIndicator(
                            onRefresh: _loadFavorites,
                            child: _buildStoresGrid(
                              context,
                              favoritesProvider,
                              colorScheme,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : _buildLoginPrompt(context, colorScheme),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadFavorites,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 100,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'سجل دخولك لعرض مفضلتك',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'احفظ منتجاتك ومتاجرك المفضلة واستعرضها في أي وقت',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              icon: const Icon(Icons.login),
              label: const Text('تسجيل الدخول'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid(
    BuildContext context,
    FavoritesProvider favoritesProvider,
    ColorScheme colorScheme,
  ) {
    final favorites = favoritesProvider.favoriteProducts;

    if (favorites.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'لا توجد منتجات في المفضلة',
        'ابدأ بإضافة منتجاتك المفضلة لتظهر هنا',
        Icons.favorite_border,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsiveCrossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.68,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final product = favorites[index];
        return Consumer<CartProvider>(
          builder: (context, cartProvider, _) {
            return Consumer<FavoritesProvider>(
              builder: (context, favProvider, _) {
                return ProductCard(
                  product: product,
                  onTap: () => _navigateToProductDetail(context, product),
                  onBuyPressed: () => _checkLoginForAction(
                    context,
                    () async {
                      final messenger = ScaffoldMessenger.of(context);

                      // عرض مؤشر تحميل
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('جاري الإضافة...'),
                              ],
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }

                      // التحقق من تعارض نظام التوصيل
                      final locationProvider = Provider.of<LocationProvider>(
                        context,
                        listen: false,
                      );
                      final conflict = await cartProvider
                          .checkDeliveryModeConflictByStoreId(
                            productStoreId: product.storeId,
                            userLat: locationProvider.latitude,
                            userLng: locationProvider.longitude,
                          );

                      if (!mounted) return;

                      if (conflict != null) {
                        messenger.clearSnackBars();

                        if (!context.mounted) return;
                        final shouldClear = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 12),
                                Text('بدء سلة جديدة؟'),
                              ],
                            ),
                            content: Text(conflict.message),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text('نعم، ابدأ طلب جديد'),
                              ),
                            ],
                          ),
                        );

                        if (shouldClear != true) return;
                        await cartProvider.clearCart();
                      }

                      // إضافة المنتج للسلة
                      final success = await cartProvider.addToCart(
                        productId: product.id,
                      );

                      if (mounted) {
                        messenger.clearSnackBars();
                        if (success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('تمت إضافة ${product.name} إلى السلة'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('فشل إضافة المنتج إلى السلة'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    loginMessage: 'يرجى تسجيل الدخول لإضافة المنتجات إلى السلة',
                  ),
                  onFavoritePressed: () =>
                      _checkLoginForAction(context, () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await favProvider.removeFromFavorites(
                          product.id,
                        );
                        if (!mounted) return;
                        if (success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إزالة ${product.name} من المفضلة',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }, loginMessage: 'يرجى تسجيل الدخول للتعامل مع المفضلة'),
                  isFavorite: true,
                  compact: true,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStoresGrid(
    BuildContext context,
    FavoritesProvider favoritesProvider,
    ColorScheme colorScheme,
  ) {
    final favoriteStores = favoritesProvider.favoriteStores;
    final storeProvider = Provider.of<StoreProvider>(context);

    if (favoriteStores.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'لا توجد متاجر في المفضلة',
        'ابدأ بإضافة متاجرك المفضلة لتظهر هنا',
        Icons.storefront,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsiveCrossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: favoriteStores.length,
      itemBuilder: (context, index) {
        final store = favoriteStores[index];
        return _buildFavoriteStoreCard(
          context,
          store,
          favoritesProvider,
          storeProvider,
          colorScheme,
        );
      },
    );
  }

  Widget _buildFavoriteStoreCard(
    BuildContext context,
    StoreModel store,
    FavoritesProvider favoritesProvider,
    StoreProvider storeProvider,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToStoreDetail(context, store),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: store.imageUrl != null
                        ? Image.network(
                            store.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildStoreIcon(colorScheme),
                          )
                        : _buildStoreIcon(colorScheme),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _checkLoginForAction(context, () async {
                        await favoritesProvider.toggleFavoriteStore(store);
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('تمت الإزالة من المفضلة'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    storeProvider.getCategoryName(store.category),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreIcon(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      width: double.infinity,
      child: Icon(Icons.store, size: 40, color: colorScheme.primary),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('ابدأ التسوق'),
            ),
          ],
        ),
      ),
    );
  }
}
