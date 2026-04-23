import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ell_tall_market/utils/location_ui_text.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/cart_helper.dart';

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
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);

      final allowedStoreIds = storeProvider.nearbyStores
          .map((s) => s.id)
          .toList(growable: false);

      // تفعيل نطاق الفئات المتاحة (إخفاء الفئات بدون منتجات/متاجر داخل النطاق)
      categoryProvider.applyAvailabilityScope(allowedStoreIds: allowedStoreIds);

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
        productProvider.filterByCategory(
          widget.categoryId!,
          allowedStoreIds: allowedStoreIds,
        );
      } else {
        if (categoryProvider.categories.isEmpty) {
          categoryProvider.fetchCategories();
        }
        productProvider.fetchProducts(allowedStoreIds: allowedStoreIds);
      }
    });
  }

  Future<void> _requestLocationAndReload() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    final got = await locationProvider.getCurrentLocation();
    if (!mounted) return;

    if (!got || !locationProvider.hasLocation) {
      await categoryProvider.applyAvailabilityScope(allowedStoreIds: const []);
      return;
    }

    await storeProvider.fetchNearbyStores(
      latitude: locationProvider.latitude!,
      longitude: locationProvider.longitude!,
      maxDistanceKm: 15,
    );

    final allowedStoreIds = storeProvider.nearbyStores
        .map((s) => s.id)
        .toList(growable: false);

    await categoryProvider.applyAvailabilityScope(
      allowedStoreIds: allowedStoreIds,
    );

    if (_selectedCategory != null) {
      await productProvider.filterByCategory(
        _selectedCategory!.id,
        allowedStoreIds: allowedStoreIds,
      );
    } else {
      await productProvider.fetchProducts(allowedStoreIds: allowedStoreIds);
    }
  }

  Future<void> _refreshData() async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final allowedStoreIds = storeProvider.nearbyStores
        .map((s) => s.id)
        .toList(growable: false);

    if (_selectedCategory != null) {
      await productProvider.filterByCategory(
        _selectedCategory!.id,
        allowedStoreIds: allowedStoreIds,
      );
    } else {
      await Future.wait([
        productProvider.refresh(allowedStoreIds: allowedStoreIds),
        categoryProvider.fetchCategories(refresh: true),
      ]);
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
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final allowedStoreIds = storeProvider.nearbyStores
        .map((s) => s.id)
        .toList(growable: false);
    productProvider.filterByCategory(
      category.id,
      allowedStoreIds: allowedStoreIds,
    );
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

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 3,
      centerTitle: true,
      leading: _selectedCategory != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() => _selectedCategory = null);
                final storeProvider = Provider.of<StoreProvider>(
                  context,
                  listen: false,
                );
                final allowedStoreIds = storeProvider.nearbyStores
                    .map((s) => s.id)
                    .toList(growable: false);

                Provider.of<ProductProvider>(
                  context,
                  listen: false,
                ).fetchProducts(allowedStoreIds: allowedStoreIds);
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
    final locationProvider = Provider.of<LocationProvider>(context);

    if (provider.isLoading) {
      return _buildCategoriesShimmer(colorScheme);
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

    final categories = provider.availableCategories;

    if (provider.availabilityScopeActive && categories.isEmpty) {
      if (!locationProvider.hasLocation) {
        final isDeniedForever = LocationUiText.isDeniedForever(
          locationProvider,
        );
        final isServiceOff = LocationUiText.isServiceOff(locationProvider);
        final message = LocationUiText.message(locationProvider);

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off_rounded,
                  size: 72,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  LocationUiText.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: isDeniedForever
                          ? () => Geolocator.openAppSettings()
                          : _requestLocationAndReload,
                      icon: Icon(
                        isDeniedForever
                            ? Icons.settings_rounded
                            : Icons.my_location_rounded,
                      ),
                      label: Text(
                        LocationUiText.primaryButtonLabel(locationProvider),
                      ),
                    ),
                    if (isServiceOff)
                      OutlinedButton.icon(
                        onPressed: () => Geolocator.openLocationSettings(),
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text(LocationUiText.secondaryButtonLabel),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('لا توجد تصنيفات متاحة في منطقتك حالياً'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => provider.fetchCategories(refresh: true),
              child: const Text('تحديث'),
            ),
          ],
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
              crossAxisCount: context.responsiveCrossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCategoryCard(categories[index], index),
              childCount: categories.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesShimmer(ColorScheme colorScheme) {
    Widget box({
      required double width,
      required double height,
      BorderRadiusGeometry? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: radius ?? BorderRadius.circular(16),
        ),
      );
    }

    return AppShimmer.wrap(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.responsiveCrossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  box(width: 80, height: 80, radius: BorderRadius.circular(16)),
                  const SizedBox(height: 12),
                  box(width: 120, height: 12, radius: BorderRadius.circular(8)),
                ],
              ),
            );
          },
        ),
      ),
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
                              child: AppShimmer.wrap(
                                context,
                                child: AppShimmer.circle(context, size: 28),
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

    if (productProvider.isLoading) {
      return _buildProductsShimmer(colorScheme);
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
                textAlign: TextAlign.center,
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
                crossAxisCount: context.responsiveCrossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.68,
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
                  child:
                      Consumer3<
                        FavoritesProvider,
                        SupabaseProvider,
                        CartProvider
                      >(
                        builder:
                            (
                              context,
                              favoritesProvider,
                              authProvider,
                              cartProvider,
                              _,
                            ) {
                              return ProductCard(
                                product: product,
                                onTap: () => _navigateToProductDetail(product),
                                onBuyPressed: () {
                                  CartHelper.addToCart(context, product);
                                },
                                onFavoritePressed: () =>
                                    _checkLoginForFavoriteAction(() async {
                                      final wasFavorite = favoritesProvider
                                          .isFavoriteProduct(product.id);
                                      await favoritesProvider
                                          .toggleFavoriteProduct(product);
                                      if (mounted && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              wasFavorite
                                                  ? 'تمت الإزالة من المفضلة'
                                                  : 'تمت الإضافة للمفضلة',
                                            ),
                                            backgroundColor: wasFavorite
                                                ? Colors.red
                                                : Colors.green,
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    }),
                                isFavorite: favoritesProvider.isFavoriteProduct(
                                  product.id,
                                ),
                                compact: true,
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

  Widget _buildProductsShimmer(ColorScheme colorScheme) {
    Widget box({
      required double width,
      required double height,
      BorderRadiusGeometry? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: radius ?? BorderRadius.circular(16),
        ),
      );
    }

    return AppShimmer.wrap(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.responsiveCrossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: box(
                    width: double.infinity,
                    height: double.infinity,
                    radius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 10),
                box(
                  width: double.infinity,
                  height: 12,
                  radius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                box(width: 120, height: 10, radius: BorderRadius.circular(8)),
              ],
            );
          },
        ),
      ),
    );
  }
}
