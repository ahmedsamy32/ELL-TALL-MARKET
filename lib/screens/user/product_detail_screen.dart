import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/widgets/rating_star.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({required this.product, super.key});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  final _supabase = SupabaseConfig.client;

  Future<void> _handleBuyNow(BuildContext context) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    // Add products to cart locally
    for (int i = 0; i < _quantity; i++) {
      cartProvider.addItem(widget.product);
    }

    // Add products to cart in Supabase
    try {
      final cartItem = await _supabase
          .from('cart_items')
          .select()
          .eq('user_id', authProvider.user!.id)
          .eq('product_id', widget.product.id)
          .maybeSingle();

      if (cartItem != null) {
        final currentQty = cartItem['quantity'] as int;
        await _supabase
            .from('cart_items')
            .update({'quantity': currentQty + _quantity})
            .eq('user_id', authProvider.user!.id)
            .eq('product_id', widget.product.id);
      } else {
        await _supabase.from('cart_items').insert({
          'user_id': authProvider.user!.id,
          'product_id': widget.product.id,
          'quantity': _quantity,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Create order from cart
      await orderProvider.createOrderFromCart(authProvider.user!.id);

      // Clear cart after order creation
      await cartProvider.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إتمام الطلب بنجاح!')),
      );

      // Navigate to orders screen
      Navigator.pushNamed(context, '/orders');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    PageView.builder(
                      itemCount:
                          (widget.product.images.isNotEmpty
                              ? widget.product.images.length
                              : 1) +
                          1,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Image.network(
                            widget.product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 50),
                              );
                            },
                          );
                        } else {
                          final imgIndex = index - 1;
                          if (widget.product.images.isNotEmpty &&
                              imgIndex < widget.product.images.length) {
                            return Image.network(
                              widget.product.images[imgIndex],
                              fit: BoxFit.cover,
                            );
                          } else {
                            return Container(color: Colors.grey[200]);
                          }
                        }
                      },
                    ),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          (widget.product.images.isNotEmpty
                                  ? widget.product.images.length
                                  : 1) +
                              1,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedImageIndex == index
                                  ? Colors.white
                                  : Color.fromRGBO(255, 255, 255, 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    Row(
                      children: [
                        RatingStars(rating: widget.product.rating),
                        const SizedBox(width: 8),
                        Text(
                          '(${widget.product.ratingCount})',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.product.finalPrice.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (widget.product.hasDiscount)
                      Text(
                        '${widget.product.price.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'الوصف',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (widget.product.unit != null) ...[
                      const Text(
                        'المواصفات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'الوحدة: ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(widget.product.unit!),
                        ],
                      ),
                    ],
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
                          maxQuantity: widget.product.stockQuantity,
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
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              if (!authProvider.isLoggedIn) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
                                );
                                return;
                              }

                              try {
                                // Add to local cart
                                final cartProvider = Provider.of<CartProvider>(context, listen: false);
                                for (int i = 0; i < _quantity; i++) {
                                  cartProvider.addItem(widget.product);
                                }

                                // Add to Supabase cart
                                final cartItem = await _supabase
                                    .from('cart_items')
                                    .select()
                                    .eq('user_id', authProvider.user!.id)
                                    .eq('product_id', widget.product.id)
                                    .maybeSingle();

                                if (cartItem != null) {
                                  final currentQty = cartItem['quantity'] as int;
                                  await _supabase
                                      .from('cart_items')
                                      .update({'quantity': currentQty + _quantity})
                                      .eq('user_id', authProvider.user!.id)
                                      .eq('product_id', widget.product.id);
                                } else {
                                  await _supabase.from('cart_items').insert({
                                    'user_id': authProvider.user!.id,
                                    'product_id': widget.product.id,
                                    'quantity': _quantity,
                                    'created_at': DateTime.now().toIso8601String(),
                                  });
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')),
                                );

                                // Navigate to cart screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CartScreen()),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
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
