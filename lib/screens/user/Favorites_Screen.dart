import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        final favoritesProvider = Provider.of<FavoritesProvider>(
          context,
          listen: false,
        );

        try {
          await favoritesProvider.loadUserFavorites(
            authProvider.currentUser!.id,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ فشل تحميل المفضلة: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  void _navigateToProductDetail(BuildContext context, ProductModel product) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
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

    return Consumer<SupabaseProvider>(
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
            actions: [
              if (authProvider.isLoggedIn)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                  onPressed: _loadFavorites,
                ),
            ],
          ),
          body: authProvider.isLoggedIn
              ? Consumer<FavoritesProvider>(
                  builder: (context, favoritesProvider, child) {
                    return RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: _buildFavoritesList(
                        context,
                        favoritesProvider,
                        colorScheme,
                      ),
                    );
                  },
                )
              : _buildLoginPrompt(context, colorScheme),
        );
      },
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
              'احفظ منتجاتك المفضلة واستعرضها في أي وقت',
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

  Widget _buildFavoritesList(
    BuildContext context,
    FavoritesProvider favoritesProvider,
    ColorScheme colorScheme,
  ) {
    // Show loading state
    if (favoritesProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل المفضلة...'),
          ],
        ),
      );
    }

    // Show error state
    if (favoritesProvider.error != null) {
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
                favoritesProvider.error!,
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

    final favorites = favoritesProvider.favoriteProducts;

    // Show empty state
    if (favorites.isEmpty) {
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
                "لا توجد منتجات في المفضلة",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "ابدأ بإضافة منتجاتك المفضلة لتظهر هنا",
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

    // Show favorites grid
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final product = favorites[index];
        return ProductCard(
          product: product,
          onTap: () => _navigateToProductDetail(context, product),
          onFavoritePressed: () => _checkLoginForAction(context, () async {
            // Remove from favorites
            final success = await favoritesProvider.removeFromFavorites(
              product.id,
            );
            if (mounted && success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إزالة ${product.name} من المفضلة'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (mounted && !success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(favoritesProvider.error ?? 'فشلت الإزالة'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }, loginMessage: 'يرجى تسجيل الدخول للتعامل مع المفضلة'),
          isFavorite: true, // Always true since we're in favorites screen
        );
      },
    );
  }
}
