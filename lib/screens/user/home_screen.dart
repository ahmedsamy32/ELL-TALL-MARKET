import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  late AnimationController _animationController;

  // Sample data for demonstration - replace with actual data from providers
  final List<BannerItem> _banners = [
    BannerItem(
      title: 'خصومات هائلة على الإلكترونيات',
      subtitle: 'وفر حتى 50% على أحدث الأجهزة',
      imageUrl: 'assets/images/onboarding1.jpg',
      color: Color(0xFF4CAF50),
    ),
    BannerItem(
      title: 'أحدث صيحات الموضة',
      subtitle: 'مجموعة جديدة من الملابس العصرية',
      imageUrl: 'assets/images/onboarding2.jpg',
      color: Color(0xFF9C27B0),
    ),
    BannerItem(
      title: 'توصيل مجاني للطلبات',
      subtitle: 'اطلب الآن واحصل على توصيل مجاني',
      imageUrl: 'assets/images/onboarding3.jpg',
      color: Color(0xFFFF9800),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _startBannerAutoSlide();
    _loadData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      if (!productProvider.isLoading) {
        productProvider.fetchProducts();
      }
      if (!categoryProvider.isLoading) {
        categoryProvider.fetchCategories();
      }
      if (!storeProvider.isLoading) {
        storeProvider.fetchStores();
      }

      // تحميل المفضلة والسلة إذا كان المستخدم مسجل دخول
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        if (!favoritesProvider.isLoading) {
          favoritesProvider.loadUserFavorites(authProvider.currentUser!.id);
        }
        if (!cartProvider.isLoading) {
          cartProvider.loadCart();
        }
      }
    });
  }

  void _checkLoginForAction(VoidCallback action, {String? loginMessage}) {
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

    // Return the body content directly since this will be embedded in MainNavigationScreen
    return Material(
      child: Container(
        color: colorScheme.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar as a sliver
            SliverAppBar(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              floating: true,
              snap: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              title: Consumer<SupabaseProvider>(
                builder: (context, authProvider, child) {
                  final user = authProvider.currentUserProfile;
                  String deliveryAddress = 'التل الكبير، الإسماعيلية';

                  // Note: Address field removed from ProfileModel
                  // Users should select address from AddressesScreen
                  if (user != null) {
                    deliveryAddress =
                        'اختر عنوان التوصيل'; // "Choose delivery address"
                  }

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, AppRoutes.addresses);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'التوصيل إلى',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  deliveryAddress,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: colorScheme.onPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              actions: [
                // Shopping Cart
                Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final itemCount = cartProvider.cartItems.length;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_rounded),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _checkLoginForAction(
                              () =>
                                  Navigator.pushNamed(context, AppRoutes.cart),
                              loginMessage: 'يرجى تسجيل الدخول لعرض السلة',
                            );
                          },
                        ),
                        if (itemCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                itemCount > 99 ? '99+' : itemCount.toString(),
                                style: TextStyle(
                                  color: colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Notifications
                Consumer<NotificationProvider>(
                  builder: (context, notificationProvider, child) {
                    final unreadCount = notificationProvider.unreadCount;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_rounded),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Scaffold.of(context).openEndDrawer();
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: TextStyle(
                                  color: colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Search Bar
            SliverToBoxAdapter(child: _buildSearchBar()),

            // Banner Slider
            SliverToBoxAdapter(child: _buildBannerSlider()),

            // Featured Stores
            SliverToBoxAdapter(child: _buildFeaturedStores()),

            // Categories
            SliverToBoxAdapter(child: _buildCategories()),

            // New Products
            SliverToBoxAdapter(child: _buildNewProducts()),

            // Featured Products (Best Sellers)
            SliverToBoxAdapter(child: _buildFeaturedProducts()),

            // Bottom spacing for navigation bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Extra space for bottom nav
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      child: SearchBar(
        controller: _searchController,
        hintText: 'ابحث عن المنتجات أو المتاجر...',
        leading: Icon(
          Icons.search_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
        trailing: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                // Show filter options
              },
            ),
        ],
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        onChanged: (value) => setState(() {}),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.search, arguments: value);
          }
        },
      ),
    );
  }

  Widget _buildBannerSlider() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _bannerController,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = index;
                });
                HapticFeedback.lightImpact();
              },
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Navigate to banner link
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      banner.color,
                                      banner.color.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.image_rounded,
                                  size: 60,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                banner.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentBannerIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentBannerIndex == index
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNewProducts() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final colorScheme = Theme.of(context).colorScheme;

        if (productProvider.isLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.new_releases_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'منتجات جديدة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildProductShimmer(),
                    );
                  },
                ),
              ),
            ],
          );
        }

        final newProducts = productProvider.products
            .where((product) {
              final now = DateTime.now();
              final difference = now.difference(product.createdAt);
              return difference.inDays <= 7; // Products added in last 7 days
            })
            .take(10)
            .toList();

        if (newProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.new_releases_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'منتجات جديدة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: newProducts.length,
                itemBuilder: (context, index) {
                  final product = newProducts[index];
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Consumer<FavoritesProvider>(
                      builder: (context, favoritesProvider, child) {
                        return ProductCard(
                          product: product,
                          onTap: () => _navigateToProductDetail(product),
                          onBuyPressed: () => _handleBuyProduct(product),
                          onFavoritePressed: () =>
                              _handleFavoriteProduct(product),
                          isFavorite: favoritesProvider.isFavorite(product.id),
                          compact: true,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategories() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final colorScheme = Theme.of(context).colorScheme;

        if (categoryProvider.isLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'التصنيفات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildCategoryShimmer(),
                    );
                  },
                ),
              ),
            ],
          );
        }

        if (categoryProvider.categories.isEmpty) {
          // عرض رسالة إذا لم تكن هناك فئات
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'التصنيفات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        categoryProvider.error ??
                            'لا توجد تصنيفات متاحة حالياً',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (categoryProvider.error != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              categoryProvider.fetchCategories(refresh: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          color: colorScheme.onTertiaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'التصنيفات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.category),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categoryProvider.categories.length,
                itemBuilder: (context, index) {
                  final category = categoryProvider.categories[index];
                  final colors = [
                    const Color(0xFF4CAF50),
                    const Color(0xFF2196F3),
                    const Color(0xFF9C27B0),
                    const Color(0xFFFF9800),
                    const Color(0xFFF44336),
                    const Color(0xFF607D8B),
                  ];
                  final color = colors[index % colors.length];

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.category,
                        arguments: {'id': category.id, 'name': category.name},
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'category_${category.id}',
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child:
                                    category.imageUrl != null &&
                                        category.imageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: category.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: Icon(
                                                Icons.category_rounded,
                                                color: color,
                                                size: 32,
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: Icon(
                                                Icons.category_rounded,
                                                color: color,
                                                size: 32,
                                              ),
                                            ),
                                      )
                                    : Icon(
                                        Icons.category_rounded,
                                        color: color,
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedStores() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        final colorScheme = Theme.of(context).colorScheme;

        if (storeProvider.isLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'المتاجر المميزة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildCategoryShimmer(),
                    );
                  },
                ),
              ),
            ],
          );
        }

        if (storeProvider.featuredStores.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayStores = storeProvider.featuredStores.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: colorScheme.onTertiaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'المتاجر المميزة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.stores),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: displayStores.length,
                itemBuilder: (context, index) {
                  final store = displayStores[index];
                  final colors = [
                    const Color(0xFFE91E63),
                    const Color(0xFF00BCD4),
                    const Color(0xFF8BC34A),
                    const Color(0xFFFF5722),
                    const Color(0xFF3F51B5),
                    const Color(0xFFFFEB3B),
                  ];
                  final color = colors[index % colors.length];

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.storeDetail,
                        arguments: store,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'store_${store.id}',
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child:
                                    store.logoUrl != null &&
                                        store.logoUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: store.logoUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: Icon(
                                                Icons.storefront_rounded,
                                                color: color,
                                                size: 32,
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: Icon(
                                                Icons.storefront_rounded,
                                                color: color,
                                                size: 32,
                                              ),
                                            ),
                                      )
                                    : Icon(
                                        Icons.storefront_rounded,
                                        color: color,
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            store.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedProducts() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final colorScheme = Theme.of(context).colorScheme;

        if (productProvider.isLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'الأكثر مبيعاً',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return _buildGridProductShimmer();
                },
              ),
            ],
          );
        }

        // Get products for best sellers (sorted by newest as rating doesn't exist)
        final featuredProducts = productProvider.products.toList();
        if (featuredProducts.isNotEmpty) {
          featuredProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        final displayProducts = featuredProducts.take(6).toList();

        if (displayProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: colorScheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الأكثر مبيعاً',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                final product = displayProducts[index];
                return Consumer<FavoritesProvider>(
                  builder: (context, favoritesProvider, child) {
                    return ProductCard(
                      product: product,
                      onTap: () => _navigateToProductDetail(product),
                      onBuyPressed: () => _handleBuyProduct(product),
                      onFavoritePressed: () => _handleFavoriteProduct(product),
                      isFavorite: favoritesProvider.isFavorite(product.id),
                      compact: true,
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Helper methods
  void _navigateToProductDetail(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _handleBuyProduct(ProductModel product) {
    _checkLoginForAction(() async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final colorScheme = Theme.of(context).colorScheme;
      final success = await cartProvider.addToCart(productId: product.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تمت إضافة ${product.name} إلى السلة'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل إضافة ${product.name} إلى السلة'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }, loginMessage: 'يرجى تسجيل الدخول لإضافة المنتجات إلى السلة');
  }

  void _handleFavoriteProduct(ProductModel product) {
    _checkLoginForAction(() async {
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );

      // استخدام toggleFavoriteProduct الذي يحفظ في قاعدة البيانات
      final success = await favoritesProvider.toggleFavoriteProduct(product);

      if (mounted && success) {
        final isFavorite = favoritesProvider.isFavorite(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite
                  ? 'تمت إضافة ${product.name} إلى المفضلة'
                  : 'تمت إزالة ${product.name} من المفضلة',
            ),
            backgroundColor: isFavorite ? Colors.red : null,
          ),
        );
      } else if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(favoritesProvider.error ?? 'فشلت العملية'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }, loginMessage: 'يرجى تسجيل الدخول للتعامل مع المفضلة');
  }

  // Shimmer Effect Widgets
  Widget _buildProductShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 50,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
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

  Widget _buildCategoryShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Shimmer.fromColors(
          baseColor: colorScheme.surfaceContainerHighest,
          highlightColor: colorScheme.surface,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Shimmer.fromColors(
          baseColor: colorScheme.surfaceContainerHighest,
          highlightColor: colorScheme.surface,
          child: Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridProductShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 50,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
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

// Data Models
class BannerItem {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color color;

  BannerItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.color,
  });
}
