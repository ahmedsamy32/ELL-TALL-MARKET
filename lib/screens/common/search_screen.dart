import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/widgets/custom_appbar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: SearchAppBar(
        controller: _searchController,
        onChanged: (query) {
          productProvider.filterProducts(query);
        },
        onCancel: () {
          Navigator.pop(context);
        },
        hintText: 'ابحث عن منتج، فئة، أو ماركة...',
      ),
      body: _buildSearchResults(productProvider),
    );
  }

  Widget _buildSearchResults(ProductProvider provider) {
    if (_searchController.text.isEmpty) {
      return _buildRecentSearches();
    }

    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(child: Text(provider.error!));
    }

    if (provider.products.isEmpty) {
      return _buildNoResults();
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: provider.products.length,
      itemBuilder: (context, index) {
        final product = provider.products[index];
        return ProductCard(
          product: product,
          onTap: () {
            // الانتقال إلى صفحة تفاصيل المنتج
            // Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
          },
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    final List<String> recentSearches = [
      'هواتف',
      'لابتوب',
      'أحذية',
      'ملابس رياضية',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'عمليات البحث الأخيرة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.history),
                title: Text(recentSearches[index]),
                onTap: () {
                  _searchController.text = recentSearches[index];
                  Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  ).filterProducts(recentSearches[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد نتائج',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('حاول البحث بكلمات أخرى', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
