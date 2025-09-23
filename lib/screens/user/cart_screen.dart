import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/cart_item_widget.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _checkLoginAndNavigate(BuildContext context, Function action) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('سلة التسوق'), centerTitle: true),
      body: SafeArea(
        child: cartProvider.items.isEmpty
            ? _buildEmptyCart(context)
            : _buildCartWithItems(cartProvider, context),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            'سلة التسوق فارغة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'أضف بعض المنتجات إلى سلة التسوق',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'تسوق الآن',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(CartProvider cartProvider, BuildContext context) {
    final deliveryFee = 10.0;
    final discount = cartProvider.discount;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cartProvider.items.length,
            itemBuilder: (context, index) {
              final item = cartProvider.items[index];
              return CartItemWidget(
                item: item,
                onIncrease: () async => await cartProvider.increaseQuantity(item.product.id),
                onDecrease: () async => await cartProvider.decreaseQuantity(item.product.id),
                onRemove: () async => await cartProvider.removeItem(item.product.id),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
                _buildSummaryRow('المجموع الفرعي', cartProvider.total),
              const SizedBox(height: 8),
              _buildSummaryRow('رسوم التوصيل', deliveryFee),
              if (discount > 0) ...[
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'الخصم (${cartProvider.couponCode})',
                  discount,
                  valueColor: Colors.green,
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'المجموع النهائي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(cartProvider.total + deliveryFee - discount).toStringAsFixed(2)} ر.س',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'إتمام الشراء',
                onPressed: () {
                  _checkLoginAndNavigate(context, () {
                    Navigator.pushNamed(context, AppRoutes.checkout);
                  });
                },
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'الدفع',
                onPressed: () => _checkLoginAndNavigate(context, () {
                  Navigator.pushNamed(context, AppRoutes.paymentMethods);
                }),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '${value.toStringAsFixed(2)} ر.س',
          style: TextStyle(color: valueColor),
        ),
      ],
    );
  }
}
