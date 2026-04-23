import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';
import 'package:ell_tall_market/services/search_history_service.dart';
import 'package:ell_tall_market/services/universal_search_service.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/utils/location_ui_text.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/utils/cart_helper.dart';
import 'package:ell_tall_market/services/coupon_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  final UniversalSearchService _universalSearchService =
      UniversalSearchService();
  List<String> _searchHistory = [];
  SearchResult? _searchResult;
  bool _isSearching = false;
  String? _searchError;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Set<String> _storeIdsWithCoupons = {};

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _loadStoresWithCoupons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // تفعيل نطاق الفئات المتاحة مرة واحدة لتصفية الفئات الفارغة
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final allowedStoreIds = storeProvider.nearbyStores
          .map((s) => s.id)
          .toList(growable: false);
      categoryProvider.applyAvailabilityScope(allowedStoreIds: allowedStoreIds);

      // استقبال النص المُرسل من الصفحة الرئيسية
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _searchController.text = args;
        _performSearch(args);
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(
      context,
      listen: false,
    );
    final userId = supabaseProvider.currentUser?.id ?? 'guest';
    final history = await _searchHistoryService.getSearchHistory(userId);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _loadStoresWithCoupons() async {
    try {
      final ids = await CouponService.fetchStoreIdsWithActiveCoupons();
      if (mounted) {
        setState(() => _storeIdsWithCoupons = ids);
      }
    } catch (_) {
      // تجاهل — الشارة لن تظهر فقط
    }
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    final supabaseProvider = Provider.of<SupabaseProvider>(
      context,
      listen: false,
    );
    final userId = supabaseProvider.currentUser?.id ?? 'guest';
    await _searchHistoryService.saveSearch(userId, query);
    await _loadSearchHistory();
  }

  Future<void> _removeSearch(String query) async {
    final supabaseProvider = Provider.of<SupabaseProvider>(
      context,
      listen: false,
    );
    final userId = supabaseProvider.currentUser?.id ?? 'guest';
    await _searchHistoryService.removeSearch(userId, query);
    await _loadSearchHistory();
  }

  Future<void> _clearHistory() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(
      context,
      listen: false,
    );
    final userId = supabaseProvider.currentUser?.id ?? 'guest';
    await _searchHistoryService.clearHistory(userId);
    await _loadSearchHistory();
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.trim().isEmpty || query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final allowedStoreIds = storeProvider.nearbyStores
          .map((s) => s.id)
          .toList(growable: false);

      final result = await _universalSearchService.search(
        query,
        allowedStoreIds: allowedStoreIds,
      );

      final availableCategoryIds = categoryProvider.availableCategoryIds;
      final categories =
          (categoryProvider.availabilityScopeActive &&
              availableCategoryIds.isNotEmpty)
          ? result.categories
                .where((c) => availableCategoryIds.contains(c.id))
                .toList(growable: false)
          : result.categories;
      final suggestions = <String>[];

      // إضافة أسماء المنتجات
      for (var product in result.products.take(5)) {
        suggestions.add(product.name);
      }

      // إضافة أسماء المتاجر
      for (var store in result.stores.take(3)) {
        suggestions.add('🏪 ${store.name}');
      }

      // إضافة أسماء الفئات
      for (var category in categories.take(3)) {
        suggestions.add('📂 ${category.name}');
      }

      setState(() {
        _suggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      AppLogger.error('خطأ في تحميل الاقتراحات', e);
    }
  }

  Future<void> _performSearch(String query) async {
    AppLogger.info('بدء البحث عن: "$query"');

    setState(() {
      _showSuggestions = false;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      _saveSearch(query);
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final allowedStoreIds = storeProvider.nearbyStores
          .map((s) => s.id)
          .toList(growable: false);

      final result = await _universalSearchService.search(
        query,
        allowedStoreIds: allowedStoreIds,
      );

      final availableCategoryIds = categoryProvider.availableCategoryIds;
      final filteredCategories =
          (categoryProvider.availabilityScopeActive &&
              availableCategoryIds.isNotEmpty)
          ? result.categories
                .where((c) => availableCategoryIds.contains(c.id))
                .toList(growable: false)
          : result.categories;

      AppLogger.info('انتهى البحث - النتائج:');
      AppLogger.info('   📦 منتجات: ${result.products.length}');
      AppLogger.info('   🏪 متاجر: ${result.stores.length}');
      AppLogger.info('   📂 فئات: ${filteredCategories.length}');

      setState(() {
        _searchResult = SearchResult(
          products: result.products,
          stores: result.stores,
          categories: filteredCategories,
        );
        _isSearching = false;
      });
    } catch (e) {
      AppLogger.error('خطأ في البحث', e);
      setState(() {
        _searchError = e.toString();
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: AppSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'ابحث عن منتج، فئة، أو متجر...',
                onChanged: (query) {
                  _loadSuggestions(query);
                  setState(() {});
                },
                onSubmitted: _performSearch,
                margin: EdgeInsets.zero,
                autofocus: true,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildSearchResults(),
      bottomNavigationBar: _buildBottomNavigationBar(colorScheme),
    );
  }

  Widget _buildBottomNavigationBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'الرئيسية',
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              _buildNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'الطلبات',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/order-history'),
              ),
              _buildNavItem(
                icon: Icons.favorite_outline,
                activeIcon: Icons.favorite,
                label: 'المفضلة',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/favorites'),
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'الملف الشخصي',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[600], size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    // عرض الاقتراحات أثناء الكتابة
    if (_showSuggestions && _searchController.text.isNotEmpty) {
      return _buildSuggestionsView();
    }

    if (_searchController.text.isEmpty) {
      return _buildRecentSearches();
    }

    if (_isSearching) {
      return _buildSearchShimmer();
    }

    if (_searchError != null) {
      return _buildErrorState(_searchError!);
    }

    if (_searchResult == null || _searchResult!.isEmpty) {
      return _buildNoResults();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // المنتجات
          if (_searchResult!.products.isNotEmpty) ...[
            _buildSectionHeader('المنتجات (${_searchResult!.products.length})'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.responsiveCrossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _searchResult!.products.length,
              itemBuilder: (context, index) {
                final product = _searchResult!.products[index];
                return Consumer2<FavoritesProvider, CartProvider>(
                  builder: (context, favProvider, cartProvider, _) {
                    final isFavorite = favProvider.isFavoriteProduct(
                      product.id,
                    );
                    return ProductCard(
                      product: product,
                      isFavorite: isFavorite,
                      onBuyPressed: () {
                        CartHelper.addToCart(context, product);
                      },
                      onFavoritePressed: () async {
                        final authProvider = Provider.of<SupabaseProvider>(
                          context,
                          listen: false,
                        );
                        if (authProvider.isLoggedIn) {
                          final wasFavorite = favProvider.isFavoriteProduct(
                            product.id,
                          );
                          await favProvider.toggleFavoriteProduct(product);
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  wasFavorite
                                      ? 'تمت الإزالة من المفضلة'
                                      : 'تمت الإضافة للمفضلة',
                                ),
                                backgroundColor: wasFavorite
                                    ? Colors.red
                                    : Colors.green,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('يرجى تسجيل الدخول أولاً'),
                              action: SnackBarAction(
                                label: 'تسجيل الدخول',
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.login,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.productDetail,
                          arguments: product,
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // المتاجر
          if (_searchResult!.stores.isNotEmpty) ...[
            _buildSectionHeader('المتاجر (${_searchResult!.stores.length})'),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResult!.stores.length,
              itemBuilder: (context, index) {
                final store = _searchResult!.stores[index];
                return _buildStoreCard(store);
              },
            ),
            const SizedBox(height: 24),
          ],

          // الفئات
          if (_searchResult!.categories.isNotEmpty) ...[
            _buildSectionHeader('الفئات (${_searchResult!.categories.length})'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchResult!.categories.map((category) {
                return _buildCategoryChip(category);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchShimmer() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget shimmerBox({
      required double width,
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

    return AppShimmer.wrap(
      context,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shimmerBox(
              width: 160,
              height: 16,
              radius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.responsiveCrossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return shimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  radius: BorderRadius.circular(16),
                );
              },
            ),
            const SizedBox(height: 24),
            shimmerBox(
              width: 140,
              height: 16,
              radius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < 3; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    shimmerBox(
                      width: 40,
                      height: 40,
                      radius: BorderRadius.circular(20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shimmerBox(
                            width: double.infinity,
                            height: 12,
                            radius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 8),
                          shimmerBox(
                            width: 180,
                            height: 10,
                            radius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            shimmerBox(
              width: 120,
              height: 16,
              radius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                6,
                (_) => shimmerBox(
                  width: 90,
                  height: 32,
                  radius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildStoreCard(StoreModel store) {
    final hasCoupon = _storeIdsWithCoupons.contains(store.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundImage: store.logoUrl != null
                  ? NetworkImage(store.logoUrl!)
                  : null,
              child: store.logoUrl == null
                  ? const Icon(Icons.store, size: 24)
                  : null,
            ),
            if (hasCoupon)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'كوبون',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          store.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          store.description ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
        },
      ),
    );
  }

  Widget _buildCategoryChip(CategoryModel category) {
    return ActionChip(
      avatar: const Icon(Icons.category, size: 18),
      label: Text(category.name),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.category, arguments: category);
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'ابحث عن المنتجات',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
              Text(
                'عمليات البحث الأخيرة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  _clearHistory();
                },
                child: Text(
                  'مسح الكل',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: Icon(Icons.history, color: Colors.grey[600], size: 20),
                title: Text(query),
                trailing: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                  onPressed: () => _removeSearch(query),
                ),
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsView() {
    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final cleanSuggestion = suggestion
            .replaceAll('🏪 ', '')
            .replaceAll('📂 ', '');

        return ListTile(
          leading: Icon(
            suggestion.startsWith('🏪')
                ? Icons.store
                : suggestion.startsWith('📂')
                ? Icons.category
                : Icons.shopping_bag,
            color: Colors.grey[600],
            size: 20,
          ),
          title: Text(
            cleanSuggestion,
            style: TextStyle(fontSize: 15, color: Colors.grey[800]),
          ),
          trailing: Icon(Icons.north_west, size: 18, color: Colors.grey[400]),
          onTap: () {
            _searchController.text = cleanSuggestion;
            _performSearch(cleanSuggestion);
          },
        );
      },
    );
  }

  Widget _buildNoResults() {
    final colorScheme = Theme.of(context).colorScheme;
    final locationProvider = Provider.of<LocationProvider>(context);

    if (!locationProvider.hasLocation) {
      final isDeniedForever = LocationUiText.isDeniedForever(locationProvider);
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      if (isDeniedForever) {
                        await Geolocator.openAppSettings();
                        return;
                      }

                      final got = await locationProvider.getCurrentLocation();
                      if (!mounted) return;

                      if (got && locationProvider.hasLocation) {
                        final storeProvider = Provider.of<StoreProvider>(
                          context,
                          listen: false,
                        );
                        final categoryProvider = Provider.of<CategoryProvider>(
                          context,
                          listen: false,
                        );

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

                        if (_searchController.text.isNotEmpty) {
                          _performSearch(_searchController.text);
                        }
                      }
                    },
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
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'حاول البحث بكلمات أخرى',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
