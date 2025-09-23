import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';

class CategoryScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName; // جعل المعامل اختيارياً

  const CategoryScreen({
    super.key,
    this.categoryId,
    this.categoryName, // جعل المعامل اختيارياً
  });

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
    _scrollController.addListener(_scrollListener);
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
        // البحث عن الفئ�� باستخدام المعرف
        final category = categoryProvider.categories.firstWhere(
          (cat) => cat.id == widget.categoryId,
          orElse: () => CategoryModel(
            id: widget.categoryId!,
            name: widget.categoryName ?? '', // استخدام القيمة الافتراضية
            imageUrl: '',
            createdAt: DateTime.now(), // إضافة createdAt
          ),
        );

        _selectedCategory = category;
        productProvider.fetchProductsByCategory(widget.categoryId!);
      } else {
        // إذا لم يتم تحديد فئة محددة، جلب كل الفئات والمنتجات
        if (categoryProvider.categories.isEmpty) {
          categoryProvider.fetchCategories();
        }
        productProvider.fetchProducts();
      }
    });
  }

  void _scrollListener() {
    // Trigger load more slightly before the end to avoid equality edge cases
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    if (productProvider.hasMore && !productProvider.isLoadingMore) {
      if (_selectedCategory != null) {
        await productProvider.loadMoreProductsByCategory();
      } else {
        await productProvider.loadMoreProducts();
      }
    }
  }

  void _refreshData() async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    if (_selectedCategory != null) {
      await productProvider.refreshProductsByCategory(_selectedCategory!.id);
    } else {
      await productProvider.refreshProducts();
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
    productProvider.fetchProductsByCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory?.name ?? 'الفئات'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refreshData(),
          child: _selectedCategory == null
              ? _buildCategoriesList(categoryProvider)
              : _buildProductsSection(productProvider, categoryProvider),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(CategoryProvider provider) {
    if (provider.isLoading && provider.categories.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              provider.error!,
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.fetchCategories(refresh: true),
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              return _buildCategoryCard(category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    final Map<String, Map<String, dynamic>> categoryStyles = {
      'supermarket': {
        'icon': Icons.shopping_cart,
        'color': Colors.blue[700],
        'backgroundColor': Colors.blue[50],
      },
      'pharmacy': {
        'icon': Icons.local_pharmacy,
        'color': Colors.green[700],
        'backgroundColor': Colors.green[50],
      },
      'restaurants': {
        'icon': Icons.restaurant,
        'color': Colors.orange[700],
        'backgroundColor': Colors.orange[50],
      },
      'bakery': {
        'icon': Icons.bakery_dining,
        'color': Colors.brown[700],
        'backgroundColor': Colors.brown[50],
      },
      'butcher': {
        'icon': Icons.rice_bowl,
        'color': Colors.red[700],
        'backgroundColor': Colors.red[50],
      },
      'vegetables': {
        'icon': Icons.local_florist,
        'color': Colors.lightGreen[700],
        'backgroundColor': Colors.lightGreen[50],
      },
    };

    final key = category.name.toLowerCase();
    final style =
        categoryStyles[key] ??
        {
          'icon': Icons.store,
          'color': Colors.grey[700],
          'backgroundColor': Colors.grey[50],
        };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _selectCategory(category),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  (style['color'] as Color?)?.withAlpha(51) ??
                  Colors.grey.withAlpha(51),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if ((category.imageUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: CachedNetworkImage(
                    imageUrl: category.imageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (style['backgroundColor'] as Color?),
                      ),
                      child: Icon(
                        style['icon'] as IconData,
                        color: style['color'] as Color?,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (style['backgroundColor'] as Color?),
                      ),
                      child: Icon(
                        style['icon'] as IconData,
                        color: style['color'] as Color?,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style['backgroundColor'] as Color?,
                  ),
                  child: Icon(
                    style['icon'] as IconData,
                    size: 40,
                    color: style['color'] as Color?,
                  ),
                ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
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
    );
  }

  Widget _buildProductsSection(
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
  ) {
    // حالة التحميل الأولي
    if (productProvider.isLoading && productProvider.products.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    // حالة الخطأ
    if (productProvider.error != null && productProvider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              productProvider.error!,
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    // حالة عدم وجود منتجات
    if (productProvider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _selectedCategory != null
                  ? 'لا توجد منتجات في فئة ${_selectedCategory!.name}'
                  : 'لا توجد منتجات متاحة',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshData, child: Text('إعادة تحميل')),
          ],
        ),
      );
    }

    // حالة وجود منتجات
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount:
            productProvider.products.length +
            (productProvider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= productProvider.products.length) {
            return Center(child: CircularProgressIndicator());
          }

          final product = productProvider.products[index];
          return ProductCard(
            product: product,
            onTap: () => _navigateToProductDetail(product),
          );
        },
      ),
    );
  }
}
