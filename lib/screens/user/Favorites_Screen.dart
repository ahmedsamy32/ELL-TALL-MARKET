import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _navigateToProductDetail(BuildContext context, ProductModel product) {
    Navigator.pushNamed(
      context,
      AppRoutes.productDetail,
      arguments: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favorites = favoritesProvider.favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text("المفضلة"),
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                "لا توجد منتجات في المفضلة",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عدد الأعمدة
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final product = favorites[index];
                return ProductCard(
                  product: product,
                  onTap: () => _navigateToProductDetail(context, product),
                );
              },
            ),
    );
  }
}
