import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../models/store_model.dart';
import '../../utils/app_routes.dart';

class StoresScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;

  const StoresScreen({super.key, this.categoryId, this.categoryName});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';
  Map<String, String> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId ?? 'all';
    _loadData();
  }

  String _cacheBustedImageUrl(String url, StoreModel store) {
    final version =
        store.updatedAt?.millisecondsSinceEpoch ??
        store.createdAt.millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}cb=$version';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    await storeProvider.fetchStores();
    _updateCategoriesFromStores();
    setState(() => _isLoading = false);
  }

  void _updateCategoriesFromStores() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    setState(() {
      _categories = storeProvider.getStoreCategories();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterStores();
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _filterStores();
  }

  void _filterStores() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    storeProvider.filterStores(_searchQuery, _selectedCategoryId);
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategoryId != 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              leading: _buildBackButton(colorScheme),
              title: Consumer<StoreProvider>(
                builder: (context, provider, _) {
                  final filteredCount = provider.filteredStores.length;
                  final totalCount = provider.stores.length;

                  String subtitle;
                  if (_selectedCategoryId != 'all') {
                    final categoryName = _categories[_selectedCategoryId] ?? '';
                    subtitle =
                        '$categoryName • $filteredCount ${filteredCount == 1 ? 'متجر' : 'متجر'}';
                  } else {
                    subtitle =
                        '$totalCount ${totalCount == 1 ? 'متجر' : 'متجر'}';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المتاجر',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _hasActiveFilters
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                      ),
                      onPressed: () {},
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'ابحث عن متجر...',
                        leading: const Icon(Icons.search_rounded),
                        trailing: _searchQuery.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                              ]
                            : null,
                        onChanged: _onSearchChanged,
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: WidgetStatePropertyAll(
                          colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _categories.entries
                            .map(
                              (entry) => _buildCategoryChip(
                                entry.key,
                                entry.value,
                                colorScheme,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : Consumer<StoreProvider>(
                builder: (context, storeProvider, _) {
                  final stores = storeProvider.filteredStores;

                  if (stores.isEmpty) {
                    return _buildEmptyState(colorScheme);
                  }

                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: stores.length,
                      itemBuilder: (context, index) {
                        return _buildStoreCard(
                          stores[index],
                          storeProvider,
                          colorScheme,
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBackButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String categoryId,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = _selectedCategoryId == categoryId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _onCategorySelected(categoryId);
        },
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide(
          color: isSelected ? colorScheme.secondary : colorScheme.outline,
          width: isSelected ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildStoreCard(
    StoreModel store,
    StoreProvider storeProvider,
    ColorScheme colorScheme,
  ) {
    final categoryName = storeProvider.getCategoryName(store.category);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store image with overlay badge
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: store.imageUrl != null && store.imageUrl!.isNotEmpty
                        ? Image.network(
                            _cacheBustedImageUrl(store.imageUrl!, store),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder(
                                store.category,
                                categoryName,
                                colorScheme,
                              );
                            },
                          )
                        : _buildPlaceholder(
                            store.category,
                            categoryName,
                            colorScheme,
                          ),
                  ),
                  // Status badge positioned on image
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: store.isOpen
                              ? Colors.green
                              : colorScheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: store.isOpen
                                  ? Colors.green
                                  : colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            store.isOpen ? 'مفتوح' : 'مغلق',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: store.isOpen
                                      ? Colors.green
                                      : colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Store info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Store name
                  Text(
                    store.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        store.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: colorScheme.onSurface,
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

  Widget _buildPlaceholder(
    String? categoryId,
    String categoryName,
    ColorScheme colorScheme,
  ) {
    IconData icon;
    List<Color> gradientColors;

    switch (categoryName.toLowerCase()) {
      case 'مطعم':
      case 'مطاعم':
        icon = Icons.restaurant_rounded;
        gradientColors = [Colors.orange[400]!, Colors.deepOrange[600]!];
        break;
      case 'سوبرماركت':
      case 'بقالة':
        icon = Icons.shopping_cart_rounded;
        gradientColors = [Colors.green[400]!, Colors.teal[600]!];
        break;
      case 'صيدلية':
        icon = Icons.local_pharmacy_rounded;
        gradientColors = [Colors.blue[400]!, Colors.indigo[600]!];
        break;
      case 'مقهى':
      case 'كافيه':
        icon = Icons.local_cafe_rounded;
        gradientColors = [Colors.brown[400]!, Colors.brown[700]!];
        break;
      case 'إلكترونيات':
        icon = Icons.devices_rounded;
        gradientColors = [Colors.purple[400]!, Colors.deepPurple[600]!];
        break;
      case 'ملابس':
      case 'أزياء':
        icon = Icons.checkroom_rounded;
        gradientColors = [const Color(0xFFDA413F), const Color(0xFFC22118)];
        break;
      case 'مخبز':
      case 'حلويات':
        icon = Icons.cake_rounded;
        gradientColors = [Colors.amber[400]!, Colors.orange[600]!];
        break;
      case 'كتب':
      case 'مكتبة':
        icon = Icons.menu_book_rounded;
        gradientColors = [Colors.indigo[400]!, Colors.blue[700]!];
        break;
      default:
        icon = Icons.store_rounded;
        gradientColors = [colorScheme.primary, colorScheme.primaryContainer];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.1,
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                categoryName,
                style: TextStyle(
                  color: gradientColors[1],
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store_mall_directory_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد متاجر',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لم نجد أي متاجر مطابقة لبحثك'
                  : 'لا توجد متاجر في هذه الفئة حالياً',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_hasActiveFilters)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedCategoryId = 'all';
                  });
                  _filterStores();
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('مسح الفلاتر'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
