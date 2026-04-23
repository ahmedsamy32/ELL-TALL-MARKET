import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'dart:async';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/banner_provider.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/models/banner_model.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';
import 'package:ell_tall_market/utils/location_ui_text.dart';
import 'package:ell_tall_market/utils/cart_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

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
  int _bannerCount = 0;
  bool _isRefreshing = false;

  // ── عروض اليوم (متاجر لديها كوبونات فعّالة) ──
  Map<String, CouponModel> _storeCouponDeals = {};
  bool _isLoadingDeals = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _startBannerAutoSlide();

    // جلب البيانات مباشرة في initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bannerProvider = Provider.of<BannerProvider>(
        context,
        listen: false,
      );
      if (!bannerProvider.isLoading && bannerProvider.banners.isEmpty) {
        bannerProvider.fetchActiveBanners();
      }
    });

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
      if (_bannerController.hasClients && _bannerCount > 0) {
        final nextPage = (_currentBannerIndex + 1) % _bannerCount;
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
      final bannerProvider = Provider.of<BannerProvider>(
        context,
        listen: false,
      );

      // جلب البانرات فقط (لا تعتمد على الموقع)
      storeProvider.ensureRealtimeSubscription();
      if (!bannerProvider.isLoading) {
        bannerProvider.fetchActiveBanners();
      }

      // جلب المتاجر القريبة بناءً على موقع المستخدم
      // هذا سيقوم بجلب المتاجر + الأقسام + المنتجات + العروض مرة واحدة
      _loadNearbyStores();

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

  Future<void> _requestLocationAndReload() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final gotLocation = await locationProvider.getCurrentLocation();
    if (!mounted) return;

    if (gotLocation) {
      await _loadNearbyStores();
    }
  }

  /// جلب المتاجر القريبة من موقع المستخدم
  Future<void> _loadNearbyStores() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    // الحصول على الموقع إذا لم يكن متاحاً
    if (!locationProvider.hasLocation) {
      final gotLocation = await locationProvider.getCurrentLocation();
      debugPrint('📍 محاولة الحصول على الموقع: $gotLocation');
    }

    // إذا تم الحصول على الموقع، جلب المتاجر القريبة
    if (locationProvider.hasLocation) {
      // نفعّل تحميل العروض مبكراً لتجنب فجوة بين الشيمرين
      if (!_isLoadingDeals) {
        setState(() => _isLoadingDeals = true);
      }
      debugPrint(
        '📍 الموقع: ${locationProvider.latitude}, ${locationProvider.longitude}',
      );
      await storeProvider.fetchNearbyStores(
        latitude: locationProvider.latitude!,
        longitude: locationProvider.longitude!,
        maxDistanceKm: 15, // نطاق البحث الافتراضي
      );
      debugPrint('🏪 المتاجر القريبة: ${storeProvider.nearbyStores.length}');
      debugPrint('🏪 المتاجر المميزة: ${storeProvider.featuredStores.length}');

      final allowedStoreIds = storeProvider.nearbyStores
          .map((s) => s.id)
          .toList(growable: false);

      // تحميل كل البيانات دفعة واحدة
      await Future.wait([
        categoryProvider.fetchCategories(),
        productProvider.fetchProducts(allowedStoreIds: allowedStoreIds),
      ]);

      // تطبيق نطاق التوفر على الأقسام
      await categoryProvider.applyAvailabilityScope(
        allowedStoreIds: allowedStoreIds,
      );

      // جلب عروض اليوم
      _loadTodayDeals();
    } else {
      // في حالة عدم توفر الموقع، نعرض رسالة ولا نجلب أي متاجر
      debugPrint('⚠️ لم يتم الحصول على الموقع - لن تظهر متاجر');
      productProvider.clearProducts();
      await categoryProvider.applyAvailabilityScope(allowedStoreIds: const []);
    }
  }

  /// جلب عروض اليوم — متاجر لديها كوبونات فعّالة
  Future<void> _loadTodayDeals() async {
    // _isLoadingDeals ممكن يكون true مسبقاً من _loadNearbyStores — ده مقصود
    if (!_isLoadingDeals) {
      setState(() => _isLoadingDeals = true);
    }
    try {
      final deals = await CouponService.fetchBestCouponPerStore();
      if (mounted) {
        setState(() {
          _storeCouponDeals = deals;
          _isLoadingDeals = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDeals = false);
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
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final bannerProvider = Provider.of<BannerProvider>(context, listen: false);

    // تحديث المتاجر القريبة أولاً (لتحديد نطاق المتاجر)
    await _loadNearbyStores();

    final allowedStoreIds = storeProvider.nearbyStores
        .map((s) => s.id)
        .toList(growable: false);

    // تحديث باقي البيانات
    await Future.wait([
      productProvider.fetchProducts(allowedStoreIds: allowedStoreIds),
      categoryProvider.fetchCategories(),
      bannerProvider.fetchActiveBanners(),
    ]);

    storeProvider.ensureRealtimeSubscription();

    // تحديث عروض اليوم
    _loadTodayDeals();

    // تحميل المفضلة والسلة إذا كان المستخدم مسجل دخول
    if (authProvider.isLoggedIn && authProvider.currentUser != null) {
      await Future.wait([
        favoritesProvider.loadUserFavorites(authProvider.currentUser!.id),
        cartProvider.loadCart(),
      ]);
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _refreshData();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _cacheBustedStoreImage(String url, StoreModel store) {
    final version =
        store.updatedAt?.millisecondsSinceEpoch ??
        store.createdAt.millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}cb=$version';
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

  /// Handle banner tap navigation based on target type
  void _handleBannerTap(BannerModel banner) async {
    final targetType = banner.targetType;
    final targetId = banner.targetId;
    final actionUrl = banner.actionUrl;

    // If custom action URL is provided, prioritize it
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // You can add custom URL handling here (e.g., launch URL)
      debugPrint('Custom action URL: $actionUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رابط مخصص: $actionUrl'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate based on target type
    if (targetType != null && targetId != null) {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('جاري التحميل...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      switch (targetType) {
        case BannerType.product:
          final productProvider = Provider.of<ProductProvider>(
            context,
            listen: false,
          );
          final product = await productProvider.getProductById(targetId);

          if (!mounted) return;

          if (product != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.productDetail,
              arguments: product,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عذراً، المنتج غير موجود'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;

        case BannerType.store:
          final storeProvider = Provider.of<StoreProvider>(
            context,
            listen: false,
          );
          final store = storeProvider.getStoreById(targetId);

          if (!mounted) return;

          if (store != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.storeDetail,
              arguments: store,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عذراً، المتجر غير موجود'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;

        case BannerType.category:
          final categoryProvider = Provider.of<CategoryProvider>(
            context,
            listen: false,
          );
          final category = await categoryProvider.getCategoryById(targetId);

          if (!mounted) return;

          if (category != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.category,
              arguments: category,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عذراً، الفئة غير موجودة'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;

        case BannerType.promotion:
          // Handle promotion - show a snackbar or dialog
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(banner.title),
              duration: const Duration(seconds: 2),
            ),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      child: Container(
        color: colorScheme.surface,
        child: Consumer2<LocationProvider, StoreProvider>(
          builder: (context, locationProvider, storeProvider, _) {
            final hasLocation = locationProvider.hasLocation;
            final noStoresInArea =
                hasLocation &&
                !storeProvider.isLoading &&
                storeProvider.nearbyStores.isEmpty;

            final showLocationRequired = !hasLocation;

            // التحقق: هل البيانات الأساسية لسه بتحمّل بعد تحديد الموقع؟
            final productProvider = Provider.of<ProductProvider>(context);
            final categoryProvider = Provider.of<CategoryProvider>(context);
            final isInitialLoading =
                hasLocation &&
                (storeProvider.isLoading ||
                    productProvider.isLoading ||
                    categoryProvider.isLoading ||
                    _isLoadingDeals);

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: showLocationRequired
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: _buildLocationRequiredFullMessage(
                                locationProvider,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : noStoresInArea
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(child: _buildNoStoresInAreaMessage()),
                          ),
                        );
                      },
                    )
                  : (_isRefreshing || isInitialLoading)
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _buildHomeRefreshingShimmer(),
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Search Bar
                            SliverToBoxAdapter(child: _buildSearchBar()),

                            // Banner Slider
                            SliverToBoxAdapter(child: _buildBannerSlider()),

                            // Location Required Banner
                            SliverToBoxAdapter(
                              child: _buildLocationRequiredBanner(),
                            ),

                            // Today's Deals — عروض اليوم
                            SliverToBoxAdapter(child: _buildTodayDeals()),

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
                              child: SizedBox(height: 100),
                            ),
                          ],
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationRequiredFullMessage(LocationProvider locationProvider) {
    final isDeniedForever = LocationUiText.isDeniedForever(locationProvider);
    final isServiceOff = LocationUiText.isServiceOff(locationProvider);
    final title = LocationUiText.title;
    final message = LocationUiText.message(locationProvider);

    return _buildCenteredStateMessage(
      icon: Icons.location_off_rounded,
      title: title,
      message: message,
      actions: [
        FilledButton.icon(
          onPressed: isDeniedForever
              ? () => Geolocator.openAppSettings()
              : _requestLocationAndReload,
          icon: Icon(
            isDeniedForever
                ? Icons.settings_rounded
                : Icons.my_location_rounded,
          ),
          label: Text(LocationUiText.primaryButtonLabel(locationProvider)),
        ),
        if (isServiceOff)
          OutlinedButton.icon(
            onPressed: () => Geolocator.openLocationSettings(),
            icon: const Icon(Icons.location_on_outlined),
            label: const Text(LocationUiText.secondaryButtonLabel),
          ),
      ],
    );
  }

  Widget _buildCenteredStateMessage({
    required IconData icon,
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            title,
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
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoStoresInAreaMessage() {
    return _buildCenteredStateMessage(
      icon: Icons.storefront_outlined,
      title: 'لا يوجد متاجر متاحة في منطقتك حالياً',
      message: 'حاول مرة أخرى لاحقاً أو حدّث موقعك.',
      actions: [
        FilledButton.icon(
          onPressed: _handleRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث'),
        ),
      ],
    );
  }

  Widget _buildHomeRefreshingShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget box({
      double? width,
      required double height,
      BorderRadiusGeometry? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: radius ?? BorderRadius.circular(12),
        ),
      );
    }

    Widget sectionHeader({
      required double iconSize,
      required double titleWidth,
    }) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            box(
              width: iconSize,
              height: iconSize,
              radius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 8),
            box(
              width: titleWidth,
              height: 16,
              radius: BorderRadius.circular(8),
            ),
          ],
        ),
      );
    }

    return AppShimmer.wrap(
      context,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Search bar placeholder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: box(height: 52, radius: BorderRadius.circular(16)),
            ),
          ),

          // Banner placeholder
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(
                        width: 160,
                        height: 14,
                        radius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 10),
                      box(
                        width: 220,
                        height: 12,
                        radius: BorderRadius.circular(8),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.center,
                        child: box(
                          width: 44,
                          height: 44,
                          radius: BorderRadius.circular(22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Featured stores placeholder
          SliverToBoxAdapter(
            child: sectionHeader(iconSize: 36, titleWidth: 140),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        box(
                          width: 64,
                          height: 64,
                          radius: BorderRadius.circular(16),
                        ),
                        const SizedBox(height: 8),
                        box(
                          width: 60,
                          height: 12,
                          radius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Categories placeholder
          SliverToBoxAdapter(
            child: sectionHeader(iconSize: 36, titleWidth: 120),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        box(
                          width: 64,
                          height: 64,
                          radius: BorderRadius.circular(16),
                        ),
                        const SizedBox(height: 8),
                        box(
                          width: 60,
                          height: 12,
                          radius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // New products placeholder
          SliverToBoxAdapter(
            child: sectionHeader(iconSize: 36, titleWidth: 140),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: box(
                            height: double.infinity,
                            radius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        box(
                          width: double.infinity,
                          height: 12,
                          radius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 6),
                        box(
                          width: 90,
                          height: 10,
                          radius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Featured products placeholder
          SliverToBoxAdapter(
            child: sectionHeader(iconSize: 36, titleWidth: 140),
          ),
          SliverToBoxAdapter(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.responsiveCrossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: box(
                            height: double.infinity,
                            radius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        box(
                          width: double.infinity,
                          height: 14,
                          radius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 6),
                        box(
                          width: 80,
                          height: 12,
                          radius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildLocationRequiredBanner() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, _) {
        if (locationProvider.hasLocation) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        final isDeniedForever = LocationUiText.isDeniedForever(
          locationProvider,
        );
        final isServiceOff = LocationUiText.isServiceOff(locationProvider);
        final title = LocationUiText.title;
        final message = LocationUiText.message(locationProvider);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
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
                          label: const Text(
                            LocationUiText.secondaryButtonLabel,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return AppSearchBar(
      controller: _searchController,
      hintText: 'ابحث عن المنتجات أو المتاجر...',
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, AppRoutes.search, arguments: value);
        }
      },
    );
  }

  Widget _buildBannerSlider() {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<BannerProvider>(
      builder: (context, bannerProvider, child) {
        // إظهار حالة التحميل
        if (bannerProvider.isLoading) {
          return Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.5),
                      colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: AppShimmer.wrap(
                    context,
                    child: AppShimmer.circle(context, size: 44),
                  ),
                ),
              ),
            ),
          );
        }

        // إظهار خطأ إذا وجد
        if (bannerProvider.hasError) {
          return Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.errorContainer,
                      colorScheme.errorContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'فشل تحميل الإعلانات',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () => bannerProvider.fetchActiveBanners(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final banners = bannerProvider.banners
            .where((b) => b.isActive)
            .toList();

        // Update banner count for auto-slide
        if (_bannerCount != banners.length) {
          _bannerCount = banners.length;
          // Reset to first banner if current index is out of bounds
          if (_currentBannerIndex >= _bannerCount && _bannerCount > 0) {
            _currentBannerIndex = 0;
          }
        }

        if (banners.isEmpty) {
          return Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لا توجد إعلانات حالياً',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final bannerHeight = MediaQuery.sizeOf(context).width >= 1200
            ? 280.0
            : MediaQuery.sizeOf(context).width >= 600
            ? 240.0
            : 200.0;
        return Container(
          height: bannerHeight,
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
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final banner = banners[index];
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
                          _handleBannerTap(banner);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: banner.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: AppShimmer.wrap(
                                    context,
                                    child: AppShimmer.circle(context, size: 44),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.campaign,
                                      size: 40,
                                      color: colorScheme.onPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'بانر إعلاني',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
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
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentBannerIndex == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentBannerIndex == index
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                height: 255,
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
            context.isWide
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: newProducts.length,
                    itemBuilder: (context, index) {
                      final product = newProducts[index];
                      return Consumer<FavoritesProvider>(
                        builder: (context, favoritesProvider, child) {
                          return ProductCard(
                            product: product,
                            onTap: () => _navigateToProductDetail(product),
                            onBuyPressed: () => _handleBuyProduct(product),
                            onFavoritePressed: () =>
                                _handleFavoriteProduct(product),
                            isFavorite: favoritesProvider.isFavorite(
                              product.id,
                            ),
                            compact: true,
                          );
                        },
                      );
                    },
                  )
                : SizedBox(
                    height: 255,
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
                                isFavorite: favoritesProvider.isFavorite(
                                  product.id,
                                ),
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
                      'الفئات',
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
                      'الفئات',
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
                            (categoryProvider.availabilityScopeActive
                                ? 'لا توجد فئات متاحة في منطقتك حالياً'
                                : 'لا توجد تصنيفات متاحة حالياً'),
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
                        'الفئات',
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
            context.isWide
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(
                        categoryProvider.availableCategories.length,
                        (index) {
                          final category =
                              categoryProvider.availableCategories[index];
                          return _buildCategoryCircleItem(
                            category,
                            index,
                            colorScheme,
                          );
                        },
                      ),
                    ),
                  )
                : SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: categoryProvider.availableCategories.length,
                      itemBuilder: (context, index) {
                        final category =
                            categoryProvider.availableCategories[index];
                        return _buildCategoryCircleItem(
                          category,
                          index,
                          colorScheme,
                        );
                      },
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCircleItem(
    CategoryModel category,
    int index,
    ColorScheme colorScheme,
  ) {
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
      child: SizedBox(
        width: 80,
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
                      category.imageUrl != null && category.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.category_rounded,
                              color: color,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.category_rounded,
                              color: color,
                              size: 32,
                            ),
                          ),
                        )
                      : Icon(Icons.category_rounded, color: color, size: 32),
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
  }

  // ─── قسم عروض اليوم — متاجر لديها كوبونات فعّالة ───
  Widget _buildTodayDeals() {
    // لا نعرض القسم قبل تحديد الموقع
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (!locationProvider.hasLocation) return const SizedBox.shrink();

    // لا شيء للعرض
    if (_storeCouponDeals.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    // بناء القائمة الفعلية — فقط المتاجر القريبة من المستخدم
    final nearbyIds = storeProvider.nearbyStores.map((s) => s.id).toSet();
    final dealItems = _storeCouponDeals.entries
        .where((entry) => nearbyIds.contains(entry.key))
        .map((entry) {
          final store = storeProvider.getStoreById(entry.key);
          if (store == null) return null;
          return MapEntry<StoreModel, CouponModel>(store, entry.value);
        })
        .whereType<MapEntry<StoreModel, CouponModel>>()
        .toList();

    if (dealItems.isEmpty) return const SizedBox.shrink();

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
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'عروض اليوم 🔥',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        context.isWide
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: dealItems.length,
                itemBuilder: (context, index) {
                  final store = dealItems[index].key;
                  final coupon = dealItems[index].value;

                  return _buildDealItem(store, coupon, colorScheme);
                },
              )
            : SizedBox(
                height: 155,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: dealItems.length,
                  itemBuilder: (context, index) {
                    final store = dealItems[index].key;
                    final coupon = dealItems[index].value;

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
                        width: 130,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // صورة المتجر كخلفية
                              store.logoUrl != null && store.logoUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _cacheBustedStoreImage(
                                        store.logoUrl!,
                                        store,
                                      ),
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(
                                        color: colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.storefront_rounded,
                                          color: colorScheme.onPrimaryContainer,
                                          size: 48,
                                        ),
                                      ),
                                      errorWidget: (_, _, _) => Container(
                                        color: colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.storefront_rounded,
                                          color: colorScheme.onPrimaryContainer,
                                          size: 48,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.storefront_rounded,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 48,
                                      ),
                                    ),
                              // محتوى النص
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // شارة الخصم
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.error,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          coupon.couponType ==
                                                  CouponType.freeDelivery
                                              ? 'توصيل مجاني'
                                              : 'خصم ${coupon.discountValueFormatted}',
                                          style: TextStyle(
                                            color: colorScheme.onError,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // اسم المتجر
                                      Text(
                                        store.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildDealItem(
    StoreModel store,
    CouponModel coupon,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              store.logoUrl != null && store.logoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _cacheBustedStoreImage(store.logoUrl!, store),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 48,
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 48,
                        ),
                      ),
                    )
                  : Container(
                      color: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.storefront_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 48,
                      ),
                    ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          coupon.couponType == CouponType.freeDelivery
                              ? 'توصيل مجاني'
                              : 'خصم ${coupon.discountValueFormatted}',
                          style: TextStyle(
                            color: colorScheme.onError,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedStores() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, _) {
        // لا نعرض المتاجر قبل تحديد الموقع لتجنب ظهور كل المتاجر ثم اختفائها.
        if (!locationProvider.hasLocation) {
          return const SizedBox.shrink();
        }

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

            final displayStores = storeProvider.featuredStores
                .where((s) => s.address.trim().isNotEmpty)
                .take(10)
                .toList();

            if (displayStores.isEmpty) {
              return const SizedBox.shrink();
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
                context.isWide
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(displayStores.length, (
                            index,
                          ) {
                            final store = displayStores[index];
                            return _buildStoreCircleItem(
                              store,
                              index,
                              colorScheme,
                            );
                          }),
                        ),
                      )
                    : SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: displayStores.length,
                          itemBuilder: (context, index) {
                            final store = displayStores[index];
                            return _buildStoreCircleItem(
                              store,
                              index,
                              colorScheme,
                            );
                          },
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStoreCircleItem(
    StoreModel store,
    int index,
    ColorScheme colorScheme,
  ) {
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
        Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
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
                  child: store.logoUrl != null && store.logoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _cacheBustedStoreImage(
                            store.logoUrl!,
                            store,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.storefront_rounded,
                              color: color,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.storefront_rounded,
                              color: color,
                              size: 32,
                            ),
                          ),
                        )
                      : Icon(Icons.storefront_rounded, color: color, size: 32),
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.responsiveCrossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.68,
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.responsiveCrossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.68,
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
    CartHelper.addToCart(context, product);
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
            backgroundColor: isFavorite ? Colors.green : Colors.red,
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
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: AppShimmer.wrap(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
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
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
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

    return AppShimmer.wrap(
      context,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridProductShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: AppShimmer.wrap(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
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
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
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
