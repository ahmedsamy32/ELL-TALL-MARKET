import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/product_card.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key});

  @override
  _StoreDetailScreenState createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  String _selectedCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    _startBannerAutoScroll();
  }

  void _startBannerAutoScroll() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (_bannerController.hasClients && mounted) {
        if (_currentBannerIndex < 2) {
          _currentBannerIndex++;
        } else {
          _currentBannerIndex = 0;
        }
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  void _checkLoginAndNavigate(Function action) {
    final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  void _addToCart(ProductModel product) {
    _checkLoginAndNavigate(() {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addItem(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة ${product.name} إلى السلة'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _navigateToProductDetail(ProductModel product) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
  }

  /// 🏪 رأس المتجر
  Widget _buildStoreHeader(StoreModel store) {
    return Column(
      children: [
        // صورة المتجر
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              // صورة الخلفية
              CachedNetworkImage(
                imageUrl: store.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.store, size: 50, color: Colors.grey),
                ),
              ),

              // طبقة تظليل
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),

              // معلومات المتجر
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      store.category,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          '${store.rating} (${store.reviewCount} تقييم)',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.timer, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '${store.deliveryTime} دقيقة',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // زر الرجوع
              Positioned(
                top: 40,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // حالة المتجر
              Positioned(
                top: 40,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: store.isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        store.isOpen ? 'مفتوح' : 'مغلق',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // معلومات التوصيل
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.delivery_dining,
                title: 'التوصيل',
                value: store.deliveryFee == 0
                    ? 'مجاني'
                    : '${store.deliveryFee} ر.س',
                color: store.deliveryFee == 0 ? Colors.green : Colors.orange,
              ),
              _buildInfoItem(
                icon: Icons.attach_money,
                title: 'الحد الأدنى',
                value: '${store.minOrder} ر.س',
                color: Colors.blue,
              ),
              _buildInfoItem(
                icon: Icons.timer,
                title: 'الوقت',
                value: '${store.deliveryTime} دقيقة',
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 📋 معلومات المتجر
  Widget _buildStoreInfo(StoreModel store) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عن المتجر',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            store.description,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: 16),
          _buildInfoRow(Icons.location_on, 'العنوان', store.address),
          _buildInfoRow(Icons.phone, 'الهاتف', store.phone),
          SizedBox(height: 16),
          Text(
            'أوقات العمل',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Column(
            children: store.openingHours.asMap().entries.map((entry) {
              final index = entry.key;
              final time = entry.value;
              final days = [
                'الإثنين',
                'الثلاثاء',
                'الأربعاء',
                'الخميس',
                'الجمعة',
                'السبت',
                'الأحد',
              ];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      days[index],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(time, style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🏷️ تصنيفات المنتجات
  Widget _buildCategoryFilter(List<String> categories) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : 'الكل';
                });
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: _selectedCategory == category
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🛒 قائمة المنتجات
  Widget _buildProductsList(List<ProductModel> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد منتجات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => _navigateToProductDetail(product),
          onBuyPressed: () => _addToCart(product),
        );
      },
    );
  }

  /// 🎬 Banner للعروض
  Widget _buildPromoBanner() {
    final List<String> promoImages = [
      'https://via.placeholder.com/400x120?text=خصم%2020%25%20على%20الطلبات%20أول%20طلب',
      'https://via.placeholder.com/400x120?text=توصيل%20مجاني%20للطلبات%20أكثر%20من%20100%20ر.س',
      'https://via.placeholder.com/400x120?text=عروض%20خاصة%20للموسم',
    ];

    return Container(
      height: 120,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: PageView.builder(
        controller: _bannerController,
        itemCount: promoImages.length,
        onPageChanged: (index) => setState(() => _currentBannerIndex = index),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: promoImages[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.local_offer, size: 40, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ModalRoute.of(context)!.settings.arguments as StoreModel;
    final productProvider = Provider.of<ProductProvider>(context);
    final storeProducts = productProvider.products
        .where((product) => product.storeId == store.id)
        .toList();

    // الحصول على التصنيفات الفريدة
    final categories = [
      'الكل',
      ...storeProducts.map((p) => p.categoryId).toSet(),
    ];

    // تصفية المنتجات حسب التصنيف المختار
    final filteredProducts = _selectedCategory == 'الكل'
        ? storeProducts
        : storeProducts
              .where((p) => p.categoryId == _selectedCategory)
              .toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildStoreHeader(store),
              ),
            ),
          ];
        },
        body: ListView(
          children: [
            _buildStoreInfo(store),
            _buildPromoBanner(),
            SizedBox(height: 16),
            Text(
              'منتجات المتجر',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            _buildCategoryFilter(categories),
            SizedBox(height: 16),
            _buildProductsList(filteredProducts),
          ],
        ),
      ),

      // زر الطلب السريع
      floatingActionButton: store.isOpen
          ? FloatingActionButton.extended(
              onPressed: () {
                _checkLoginAndNavigate(() {
                  if (filteredProducts.isNotEmpty) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.checkout,
                      arguments: {'store': store, 'products': filteredProducts},
                    );
                  }
                });
              },
              icon: Icon(Icons.shopping_cart),
              label: Text('اطلب الآن'),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
