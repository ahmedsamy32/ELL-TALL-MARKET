import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/product_model.dart';

class ListWidget extends StatelessWidget {
  final List<ProductModel> products;
  final bool showImages;
  final Function(ProductModel)? onProductTap;
  final Function(ProductModel)? onAddToCart;

  const ListWidget({
    super.key,
    required this.products,
    this.showImages = true,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductListTile(
          product: product,
          showImage: showImages,
          onTap: () => onProductTap?.call(product),
          onAddToCart: () => onAddToCart?.call(product),
        );
      },
    );
  }
}

class ProductListTile extends StatelessWidget {
  final ProductModel product;
  final bool showImage;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductListTile({
    super.key,
    required this.product,
    this.showImage = true,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (showImage)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(product.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (showImage) SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${product.finalPrice} ج.م',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (product.hasDiscount)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              '${product.price} ج.م',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: Icon(Icons.add_shopping_cart),
                onPressed: onAddToCart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryList extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Function(Map<String, dynamic>)? onCategoryTap;

  const CategoryList({super.key, required this.categories, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(category['imageUrl']),
          ),
          title: Text(category['name']),
          subtitle: Text('${category['count']} منتج'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onCategoryTap?.call(category),
        );
      },
    );
  }
}

class OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Function(Map<String, dynamic>)? onOrderTap;

  const OrderList({super.key, required this.orders, this.onOrderTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Icon(Icons.receipt, color: Theme.of(context).primaryColor),
            title: Text('طلب #${order['id']}'),
            subtitle: Text('${order['date']} - ${order['status']}'),
            trailing: Text('${order['total']} ر.س'),
            onTap: () => onOrderTap?.call(order),
          ),
        );
      },
    );
  }
}
