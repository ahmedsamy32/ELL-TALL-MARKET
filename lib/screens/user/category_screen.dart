import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;

  const CategoryScreen({super.key, this.categoryId, this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      if (widget.categoryId != null) {
        final category = categoryProvider.categories.firstWhere(
          (cat) => cat.id == widget.categoryId,
          orElse: () => CategoryModel(
            id: widget.categoryId!,
            name: widget.categoryName ?? '',
            imageUrl: '',
            createdAt: DateTime.now(),
          ),
        );

        _selectedCategory = category;
        productProvider.filterByCategory(widget.categoryId!);
      } else {
        if (categoryProvider.categories.isEmpty) {
          categoryProvider.fetchCategories();
        }
        productProvider.fetchProducts();
      }
    });
  }

  Future<void> _refreshData() async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    if (_selectedCategory != null) {
      await productProvider.filterByCategory(_selectedCategory!.id);
    } else {
      await productProvider.refresh();
    }
  }

  void _navigateToProductDetail(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _selectCategory(CategoryModel category) {
    setState(() {
      _selectedCategory = category;
    });

    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    productProvider.filterByCategory(category.id);
  }

  void _checkLoginForFavoriteAction(VoidCallback action) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      _showLoginPrompt();
    }
  }

  void _showLoginPrompt() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'تسجيل الدخول مطلوب',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'سجل دخولك لحفظ منتجاتك المفضلة والوصول إليها في أي وقت',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.login);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('تسجيل الدخول'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: colorScheme.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: _buildMaterialAppBar(context),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.surface, colorScheme.surfaceContainerLowest],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _refreshData();
              },
              child: _selectedCategory == null
                  ? _buildCategoriesList(categoryProvider)
                  : _buildProductsSection(productProvider),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMaterialAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 3,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: _selectedCategory != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() => _selectedCategory = null);
                Provider.of<ProductProvider>(
                  context,
                  listen: false,
                ).fetchProducts();
              },
              tooltip: 'رجوع',
            )
          : null,
      title: Text(
        _selectedCategory?.name.isNotEmpty == true
            ? _selectedCategory!.name
            : 'الفئات',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
      actions: _selectedCategory == null
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: () => _showFilterOptions(context),
                tooltip: 'تصفية',
              ),
            ],
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ترتيب حسب',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha_rounded),
              title: const Text('الاسم'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money_rounded),
              title: const Text('السعر'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.star_rounded),
              title: const Text('التقييم'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(CategoryProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (provider.isLoading && provider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل الفئات...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.error != null && provider.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'حدث خطأ',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => provider.fetchCategories(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildCategoryCard(provider.categories[index], index),
              childCount: provider.categories.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryModel category, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Map<String, Map<String, dynamic>> categoryStyles = {
      'supermarket': {
        'icon': Icons.shopping_cart_rounded,
        'color': const Color(0xFF1976D2),
        'lightColor': const Color(0xFFE3F2FD),
      },
      'pharmacy': {
        'icon': Icons.local_pharmacy_rounded,
        'color': const Color(0xFF388E3C),
        'lightColor': const Color(0xFFE8F5E9),
      },
      'restaurants': {
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFFF57C00),
        'lightColor': const Color(0xFFFFF3E0),
      },
      'bakery': {
        'icon': Icons.bakery_dining_rounded,
        'color': const Color(0xFF5D4037),
        'lightColor': const Color(0xFFEFEBE9),
      },
      'butcher': {
        'icon': Icons.rice_bowl_rounded,
        'color': const Color(0xFFD32F2F),
        'lightColor': const Color(0xFFFFEBEE),
      },
      'vegetables': {
        'icon': Icons.local_florist_rounded,
        'color': const Color(0xFF689F38),
        'lightColor': const Color(0xFFF1F8E9),
      },
    };

    final key = category.name.toLowerCase();
    final style =
        categoryStyles[key] ??
        {
          'icon': Icons.store_rounded,
          'color': colorScheme.primary,
          'lightColor': colorScheme.primaryContainer,
        };

    return Hero(
      tag: 'category_${category.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectCategory(category),
          borderRadius: BorderRadius.circular(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Card(
              elevation: 2,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainerLow,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if ((category.imageUrl ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: style['lightColor'] as Color?,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: style['color'] as Color?,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildIconContainer(style),
                        ),
                      )
                    else
                      _buildIconContainer(style),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        category.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(Map<String, dynamic> style) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: style['lightColor'] as Color?,
      ),
      child: Icon(
        style['icon'] as IconData,
        size: 40,
        color: style['color'] as Color?,
      ),
    );
  }

  Widget _buildProductsSection(ProductProvider productProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (productProvider.isLoading && productProvider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل المنتجات...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (productProvider.error != null && productProvider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'حدث خطأ',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                productProvider.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (productProvider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'لا توجد منتجات',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedCategory != null
                    ? 'لا توجد منتجات في فئة ${_selectedCategory!.name}'
                    : 'لا توجد منتجات متاحة حالياً',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة تحميل'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final product = productProvider.products[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 200 + (index * 30)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: Consumer2<FavoritesProvider, SupabaseProvider>(
                    builder: (context, favoritesProvider, authProvider, _) {
                      return ProductCard(
                        product: product,
                        onTap: () => _navigateToProductDetail(product),
                        onFavoritePressed: () =>
                            _checkLoginForFavoriteAction(() {
                              favoritesProvider.toggleFavoriteProduct(product);
                            }),
                        isFavorite: favoritesProvider.isFavoriteProduct(
                          product.id,
                        ),
                      );
                    },
                  ),
                );
              }, childCount: productProvider.products.length),
            ),
          ),
        ],
      ),
    );
  }
}
