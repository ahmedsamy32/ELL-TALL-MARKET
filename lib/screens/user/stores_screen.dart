import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/safe_network_image.dart';
import 'package:shimmer/shimmer.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'الكل';
  String _sortBy = 'الافتراضي';
  bool _showSearchBar = false;

  final List<String> _categories = [
    'الكل',
    'سوبرماركت',
    'مطاعم',
    'مقاهي',
    'إلكترونيات',
    'ملابس',
    'أدوات منزلية',
    'صيدلية',
    'مخابز',
  ];

  final List<String> _sortOptions = [
    'الافتراضي',
    'الأقرب',
    'الأعلى تقييماً',
    'الأكثر طلباً',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreProvider>(context, listen: false).fetchStores();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _onSearchChanged('');
      }
    });
  }

  void _onSearchChanged(String query) {
    Provider.of<StoreProvider>(
      context,
      listen: false,
    ).filterStores(query, _selectedCategory);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تصفية المتاجر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('التصنيف:'),
              Wrap(
                spacing: 8,
                children: _categories.map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('ترتيب حسب:'),
              DropdownButton<String>(
                value: _sortBy,
                isExpanded: true,
                items: _sortOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt));
                }).toList(),
                onChanged: (val) {
                  setState(() => _sortBy = val!);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'الكل';
                        _sortBy = 'الافتراضي';
                      });
                      _onSearchChanged(_searchController.text);
                      Navigator.pop(context);
                    },
                    child: const Text('إعادة تعيين'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _onSearchChanged(_searchController.text);
                      Navigator.pop(context);
                    },
                    child: const Text('تطبيق'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border,
                size: 64,
                color: Color(0xFF6A5AE0),
              ),
              const SizedBox(height: 16),
              const Text(
                'تسجيل الدخول مطلوب',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجل دخولك لحفظ متاجرك المفضلة والوصول إليها في أي وقت',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.login);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A5AE0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'المتاجر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearchBar,
          ),
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<StoreProvider>(
            context,
            listen: false,
          ).fetchStores();
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showSearchBar ? 70 : 0,
              child: _showSearchBar ? _buildSearchBar() : null,
            ),
            Expanded(
              child: Consumer<StoreProvider>(
                builder: (context, storeProvider, child) {
                  if (storeProvider.isLoading) {
                    return _buildLoadingShimmer();
                  }

                  final stores = storeProvider.filteredStores;
                  if (stores.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildStoresGrid(stores);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن متجر...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildStoresGrid(List<StoreModel> stores) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        return _buildStoreCard(stores[index]);
      },
    );
  }

  Widget _buildStoreCard(StoreModel store) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

    final isFavorite = favoritesProvider.isFavoriteStore(store.id);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SafeNetworkImage(
                      imageUrl: store.imageUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: _buildPlaceholder(store.category ?? 'متجر'),
                      errorWidget: _buildPlaceholder(store.category ?? 'متجر'),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () {
                        _checkLoginForFavoriteAction(() {
                          favoritesProvider.toggleFavoriteStore(store);
                        });
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.white70,
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      store.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "(${store.reviewCount} طلب)",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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

  Widget _buildPlaceholder(String category) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.store, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            "لا توجد متاجر",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
