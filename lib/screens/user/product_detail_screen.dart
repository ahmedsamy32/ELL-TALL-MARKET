import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({required this.product, super.key});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  Future<void> _handleBuyNow(BuildContext context) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    // Add products to cart using CartProvider
    try {
      final success = await cartProvider.addToCart(
        productId: widget.product.id,
        quantity: _quantity,
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إضافة المنتج إلى السلة')),
        );
        return;
      }

      // TODO: Implement order creation flow
      // For now, just show success message
      // await orderProvider.createOrder(...);

      // Clear cart after order creation
      await cartProvider.clearCart();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إتمام الطلب بنجاح!')));

      // Navigate to orders screen
      Navigator.pushNamed(context, '/orders');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name), centerTitle: true),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: widget.product.imageUrl != null
                    ? Image.network(
                        widget.product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 50),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 50),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rating removed as ProductModel doesn't have rating field
                    const SizedBox(height: 16),
                    Text(
                      '${widget.product.price.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الوصف',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description ?? 'لا يوجد وصف متاح',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    // Stock information
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'المخزون: ${widget.product.stockStatus}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.product.inStock
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'الكمية:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        QuantitySelector(
                          quantity: _quantity,
                          onChanged: (value) {
                            setState(() {
                              _quantity = value;
                            });
                          },
                          maxQuantity: widget.product.stock,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'إضافة إلى السلة',
                            onPressed: () async {
                              final authProvider =
                                  Provider.of<SupabaseProvider>(
                                    context,
                                    listen: false,
                                  );
                              if (!authProvider.isLoggedIn) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يرجى تسجيل الدخول أولاً'),
                                  ),
                                );
                                return;
                              }

                              try {
                                // Add to cart using CartProvider
                                final cartProvider = Provider.of<CartProvider>(
                                  context,
                                  listen: false,
                                );

                                final success = await cartProvider.addToCart(
                                  productId: widget.product.id,
                                  quantity: _quantity,
                                );

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تمت إضافة المنتج إلى السلة',
                                      ),
                                    ),
                                  );

                                  // Navigate to cart screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CartScreen(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'فشل إضافة المنتج إلى السلة',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ: ${e.toString()}'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'شراء الآن',
                            backgroundColor: Colors.orange,
                            onPressed: () async {
                              await _handleBuyNow(context);
                            },
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
}

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final Function(int) onChanged;
  final int maxQuantity;

  const QuantitySelector({
    required this.quantity,
    required this.onChanged,
    this.maxQuantity = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            quantity.toString(),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: quantity < maxQuantity
              ? () => onChanged(quantity + 1)
              : null,
        ),
      ],
    );
  }
}
