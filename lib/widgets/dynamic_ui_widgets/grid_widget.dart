import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/product_card.dart';

// ===================== GridWidget =====================
class GridWidget extends StatelessWidget {
  final List<ProductModel> products;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Function(ProductModel)? onProductTap;

  const GridWidget({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => onProductTap?.call(product),
        );
      },
    );
  }
}

// ===================== StaggeredGridWidget =====================
class StaggeredGridWidget extends StatelessWidget {
  final List<ProductModel> products;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Function(ProductModel)? onProductTap;

  const StaggeredGridWidget({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: EdgeInsets.all(16),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => onProductTap?.call(product),
        );
      },
    );
  }
}

// ===================== CategoryGrid =====================
class CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int crossAxisCount;
  final Function(Map<String, dynamic>)? onCategoryTap;

  const CategoryGrid({
    super.key,
    required this.categories,
    this.crossAxisCount = 3,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () => onCategoryTap?.call(category),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(category['imageUrl']),
              ),
              SizedBox(height: 8),
              Text(
                category['name'],
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '${category['count']} منتج',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================== ResponsiveGrid =====================
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxCrossAxisCount;
  final double childMinWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxCrossAxisCount = 4,
    this.childMinWidth = 200,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / childMinWidth)
            .floor()
            .clamp(1, maxCrossAxisCount);

        return GridView.builder(
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
