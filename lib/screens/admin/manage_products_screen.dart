import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        centerTitle: true,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addProduct(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsRow(productProvider),
            _buildSearchAndFilterBar(),
            Expanded(child: _buildProductsList(productProvider)),
          ],
        ),
      ),
    );
  }

  /// 🔹 بطاقات الإحصائيات
  Widget _buildStatsRow(ProductProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("الكل", provider.products.length, Colors.blue),
          _buildStatCard(
            "متوفر",
            provider.products.where((p) => p.stock > 0).length,
            Colors.green,
          ),
          _buildStatCard(
            "غير متوفر",
            provider.products.where((p) => p.stock == 0).length,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 البحث والفلاتر
  Widget _buildSearchAndFilterBar() {
    return AdminSearchBar(
      controller: _searchController,
      hintText: 'ابحث باسم المنتج',
      onChanged: (_) => setState(() {}),
      filterChips: [
        _buildFilterChip('الكل', 'all'),
        _buildFilterChip('متوفر', 'inStock'),
        _buildFilterChip('غير متوفر', 'outOfStock'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == filter,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: AppColors.primary.withValues(
        alpha: 51,
      ), // 20% opacity = 51/255
      checkmarkColor: AppColors.primary,
    );
  }

  /// 🔹 قائمة المنتجات
  Widget _buildProductsList(ProductProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد منتجات', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final filteredProducts = _filterProducts(provider.products);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        if (_searchController.text.isNotEmpty &&
            !product.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            )) {
          return const SizedBox.shrink();
        }
        return _buildProductCard(product);
      },
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    switch (_selectedFilter) {
      case 'inStock':
        return products.where((p) => p.stock > 0).toList();
      case 'outOfStock':
        return products.where((p) => p.stock == 0).toList();
      default:
        return products;
    }
  }

  /// 🔹 بطاقة المنتج
  Widget _buildProductCard(ProductModel product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? NetworkImage(product.imageUrl!)
              : const AssetImage('assets/images/default_product.png')
                    as ImageProvider,
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("السعر: ${product.priceFormatted}"),
            Text(
              product.stock > 0 ? "متوفر (${product.stock})" : "غير متوفر",
              style: TextStyle(
                color: product.stock > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editProduct(product),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteProduct(product),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 إضافة منتج
  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('إضافة منتج جديد'),
        content: const Text('هنا فورم إضافة المنتج الجديد'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: حفظ المنتج الجديد
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// 🔹 تعديل المنتج
  void _editProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('تعديل المنتج'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                initialValue: product.name,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
              ),
              TextFormField(
                initialValue: product.price.toString(),
                decoration: const InputDecoration(labelText: 'السعر'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: حفظ التعديلات
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// 🔹 حذف المنتج
  void _deleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('حذف المنتج'),
        content: Text('هل أنت متأكد من حذ�� ��لمنتج "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // Note: حذف المنتج
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
