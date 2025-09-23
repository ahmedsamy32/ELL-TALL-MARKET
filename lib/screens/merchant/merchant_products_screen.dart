import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';

class MerchantProductsScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const MerchantProductsScreen({
    required this.merchantId,
    required this.merchantName,
    super.key,
  });

  @override
  _MerchantProductsScreenState createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(
        context,
        listen: false,
      ).fetchProductsByMerchant(widget.merchantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchantName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // الانتقال إلى صفحة إضافة منتج جديد
              // Navigator.pushNamed(context, AppRoutes.addEditProduct);
            },
          ),
        ],
      ),
      body: productProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : productProvider.products.isEmpty
          ? _buildEmptyState()
          : _buildProductsList(productProvider),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'لا توجد منتجات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text('ابدأ بإضافة منتجك الأول', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 20),
          CustomButton(
            text: 'إضافة منتج جديد',
            onPressed: () {
              // الانتقال إلى صفحة إضافة منتج جديد
              // Navigator.pushNamed(context, AppRoutes.addEditProduct);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(ProductProvider provider) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: provider.products.length,
      itemBuilder: (context, index) {
        final product = provider.products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(product.imageUrl),
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.price} ر.س'),
            Text('المخزون: ${product.stockQuantity}'),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text(
                  '${product.rating.toStringAsFixed(1)} (${product.ratingCount})',
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // تعديل المنتج
                // Navigator.pushNamed(context, AppRoutes.addEditProduct, arguments: product);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showDeleteDialog(product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف المنتج'),
        content: Text('هل أنت متأكد من أنك تريد حذف "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(ProductModel product) async {
    try {
      // await Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف المنتج بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف المنتج: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
