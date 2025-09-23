import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart'; // ✅ تصحيح الاستيراد
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart'; // ✅ إضافة مقدم المفضلة
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart'; // ✅ إضافة شريط البحث المخصص
import 'package:ell_tall_market/widgets/notifications_sidebar.dart'; // ✅ إضافة الشريط الجانبي للإشعارات
import 'package:ell_tall_market/models/product_model.dart';
import 'dart:async';

import '../../models/user_model.dart';
import '../../utils/route_helper.dart';

// ألوان التطبيق
const Color primaryColor = Color(0xFF6A5AE0);
const Color secondaryColor = Color(0xFFFD6F9C);
const Color accentColor = Color(0xFFFF9E80);
const Color backgroundColor = Color(0xFFF5F5F7);
const Color surfaceColor = Color(0xFFFFFFFF);
const Color textPrimaryColor = Color(0xFF1D1D1D);
const Color textSecondaryColor = Color(0xFF757575);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _flashSaleTimer;
  Duration _flashSaleDuration = Duration(hours: 2, minutes: 0, seconds: 0);
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
    _startFlashSaleCountdown();
    _startBannerAutoScroll();
  }

  void _startFlashSaleCountdown() {
    _flashSaleTimer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        if (_flashSaleDuration.inSeconds > 0) {
          _flashSaleDuration -= Duration(seconds: 1);
        } else {
          _flashSaleTimer?.cancel();
        }
      });
    });
  }

  void _startBannerAutoScroll() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (_bannerController.hasClients) {
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
    _flashSaleTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _checkLoginForAction(Function action, {String? loginMessage}) {
    final authProvider = Provider.of<FirebaseAuthProvider>(
      context,
      listen: false,
    );
    if (authProvider.isLoggedIn) {
      action();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginMessage ?? 'يرجى تسجيل الدخول أولاً'),
          action: SnackBarAction(
            label: 'تسجيل الدخول',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.login);
            },
          ),
        ),
      );
    }
  }

  /// 🔹 AppBar مخصص مع عنوان التوصيل وأيقونات
  PreferredSizeWidget _buildAppBar() {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItemCount = cartProvider.items.length;
    final authProvider = Provider.of<FirebaseAuthProvider>(context);
    final user = authProvider.user;

    // الحصول على العنوان الافتراضي للمستخدم
    String deliveryAddress = 'التل الكبير الاسماعيلية'; // عنوان افتراضي
    if (user != null && user.address != null && user.address!.isNotEmpty) {
      // تقسيم العنوان المحفوظ لأخذ أول جزئين فقط
      final addressParts = user.address!
          .split(',')
          .map((e) => e.trim())
          .take(2);
      if (addressParts.isNotEmpty) {
        deliveryAddress = addressParts.join('، ');
      } else {
        // استخدام العنوان الكامل إذا كان قصيراً
        deliveryAddress = user.address!.length > 25
            ? '${user.address!.substring(0, 25)}...'
            : user.address!;
      }
    }

    return AppBar(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      title: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.addresses);
        },
        child: Row(
          children: [
            Icon(Icons.location_on, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التوصيل إلى',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    deliveryAddress,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () {
                _checkLoginForAction(() {
                  Navigator.pushNamed(context, AppRoutes.cart);
                }, loginMessage: 'يرجى تسجيل الدخول لعرض السلة');
              },
            ),
            if (cartItemCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    cartItemCount.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // إظهار زر لوحة التحكم للمستخدمين المميزين فقط
        if (user != null && user.type != UserType.customer)
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'لوحة التحكم',
            onPressed: () {
              RouteHelper.navigateToDashboard(context, user.type);
            },
          ),
      ],
      leading: Stack(
        children: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Scaffold.of(
                context,
              ).openEndDrawer(); // ✅ فتح الشريط الجانبي للإشعارات
            },
          ),
          // مؤشر الإشعارات الجديدة
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '3', // يمكن ربطها بـ Provider للإشعارات الحقيقية
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔍 شريط البحث
  Widget _buildSearchBar() {
    return CustomSearchBar(
      controller: _searchController,
      hintText: 'ابحث عن المنتجات أو المتاجر...',
      onSubmitted: (value) {
        Navigator.pushNamed(context, AppRoutes.search, arguments: value);
      },
    );
  }

  /// 🎬 Banner/Slider للعروض الخاصة
  Widget _buildBannerSlider() {
    final List<String> banners = [
      'https://via.placeholder.com/400x180?text=خصم%2020%25%20على%20الإلكترونيات',
      'https://via.placeholder.com/400x180?text=عروض%20ملابس%20مميزة',
      'https://via.placeholder.com/400x180?text=مطاعم%20وتوصيل%20مجاني',
    ];

    return Column(
      children: [
        Container(
          height: 180,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (index) =>
                  setState(() => _currentBannerIndex = index),
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: banners[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لا يمكن تحميل الصورة',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerIndex == index
                    ? primaryColor
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 🏪 المتاجر المميزة (سكرول أفقي فقط)
  Widget _buildFeaturedStores() {
    final List<Map<String, String>> featuredStores = [
      {
        'name': 'متجر الإلكترونيات',
        'image': 'https://via.placeholder.com/100?text=إلكترونيات',
        'rating': '4.8',
      },
      {
        'name': 'سوبرماركت التل',
        'image': 'https://via.placeholder.com/100?text=سوبرماركت',
        'rating': '4.5',
      },
      {
        'name': 'ملابس أونلاين',
        'image': 'https://via.placeholder.com/100?text=ملابس',
        'rating': '4.7',
      },
      {
        'name': 'مطعم الشيف',
        'image': 'https://via.placeholder.com/100?text=مطعم',
        'rating': '4.9',
      },
      {
        'name': 'متجر الأجهزة',
        'image': 'https://via.placeholder.com/100?text=أجهزة',
        'rating': '4.6',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'متاجر مميزة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.stores);
                },
                child: Text(
                  'المزيد',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 180, // تعديل ارتفاع القائمة
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: featuredStores.length,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final store = featuredStores[index];
              return Container(
                width: 160, // تعديل عرض البطاقة
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: store['image']!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.store,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        store['name']!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14, // تعديل حجم الخط
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(store['rating']!, style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 🆕 منتجات جديدة (تظهر مباشرة عند إضافتها)
  Widget _buildNewProductsSection() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        // هنا نأخذ المنتجات التي تم إضافتها حديثاً (في الساعات الأخيرة)
        final newProducts = productProvider.products.where((product) {
          final now = DateTime.now();
          final addedDate = product.createdAt;
          final difference = now.difference(addedDate);
          return difference.inHours < 24;
        }).toList();

        if (newProducts.isEmpty) return SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'منتجات جديدة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ),
            SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // تغيير عدد الأعمدة إلى 2
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75, // تعديل نسبة العرض للارتفاع
              ),
              itemCount: newProducts.length > 4
                  ? 4
                  : newProducts.length, // تقليل عدد المنتجات
              itemBuilder: (context, index) {
                final product = newProducts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      return ProductCard(
                        product: product,
                        onTap: () => _navigateToProductDetail(product),
                        onBuyPressed: () => _handleBuyProduct(product),
                        onFavoritePressed: () =>
                            _handleFavoriteProduct(product),
                        isFavorite: favoritesProvider.isFavorite(product.id),
                        compact: true,
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// 🏷️ فئات المنتجات
  Widget _buildCategoriesSection() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        if (categoryProvider.categories.isEmpty) {
          return SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'فئات المنتجات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.category);
                    },
                    child: Text(
                      'المزيد',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 100, // تقليل الارتفاع
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categoryProvider.categories.length,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, index) {
                  final category = categoryProvider.categories[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.category,
                          arguments: {'id': category.id, 'name': category.name},
                        );
                      },
                      child: SizedBox(
                        width: 80, // تقليل العرض
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: category.imageUrl ?? '',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.category,
                                          size: 32,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// ⭐ منتجات من اختيارنا (المنتجات التي مضى على نشرها أسبوع)
  Widget _buildSelectedProductsSection() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        // هنا نأخذ المنتجات التي مضى على نشرها أسبوع
        final selectedProducts = productProvider.products.where((product) {
          final now = DateTime.now();
          final addedDate = product.createdAt;
          final difference = now.difference(addedDate);
          return difference.inDays >= 7 && difference.inDays < 14;
        }).toList();

        if (selectedProducts.isEmpty) return SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'منتجات من اختيارنا',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ),
            SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // تغيير عدد الأعمدة إلى 2
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75, // تعديل نسبة العرض للارتفاع
              ),
              itemCount: selectedProducts.length > 4
                  ? 4
                  : selectedProducts.length, // تقليل عدد المنتجات
              itemBuilder: (context, index) {
                final product = selectedProducts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      return ProductCard(
                        product: product,
                        onTap: () => _navigateToProductDetail(product),
                        onBuyPressed: () => _handleBuyProduct(product),
                        onFavoritePressed: () =>
                            _handleFavoriteProduct(product),
                        isFavorite: favoritesProvider.isFavorite(product.id),
                        compact: true,
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// 🏠 بناء الصفحة الرئيسية حسب الترتيب المطلوب
  Widget _buildBody() {
    final productProvider = Provider.of<ProductProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    if (productProvider.isLoading || categoryProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'جاري التحميل...',
              style: TextStyle(fontSize: 16, color: textSecondaryColor),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(bottom: kBottomNavigationBarHeight + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              _buildBannerSlider(),
              SizedBox(height: 16),
              _buildFeaturedStores(),
              SizedBox(height: 16),
              _buildNewProductsSection(),
              SizedBox(height: 16),
              _buildCategoriesSection(),
              SizedBox(height: 16),
              _buildSelectedProductsSection(),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 BottomNavigationBar
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => _onItemTapped(index),
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey[600],
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.category_outlined),
          activeIcon: Icon(Icons.category),
          label: 'الفئات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'الطلبات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border),
          activeIcon: Icon(Icons.favorite),
          label: 'المفضلة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'حسابي',
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // الرئيسية
        break;
      case 1: // الفئات
        Navigator.pushNamed(context, AppRoutes.category);
        break;
      case 2: // الطلبات
        _checkLoginForAction(() {
          Navigator.pushNamed(context, AppRoutes.orderHistory);
        }, loginMessage: 'يرجى تسجيل الدخول لعرض الطلبات');
        break;
      case 3: // المفضلة
        _checkLoginForAction(() {
          Navigator.pushNamed(context, AppRoutes.favorites);
        }, loginMessage: 'يرجى تسجيل الدخول لعرض المفضلة');
        break;
      case 4: // حسابي
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  void _navigateToProductDetail(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _handleBuyProduct(ProductModel product) {
    _checkLoginForAction(() {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addItem(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة ${product.name} إلى السلة'),
          duration: Duration(seconds: 2),
          backgroundColor: primaryColor,
        ),
      );
    }, loginMessage: 'يرجى تسجيل الدخول لإضافة المنتجات إلى السلة');
  }

  void _handleFavoriteProduct(ProductModel product) {
    _checkLoginForAction(() {
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );
      final isFavorite = favoritesProvider.isFavorite(product.id);

      if (isFavorite) {
        favoritesProvider.removeFromFavorites(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إزالة ${product.name} من المفضلة'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        favoritesProvider.addToFavorites(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة ${product.name} إلى المفضلة'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }, loginMessage: 'يرجى تسجيل الدخول للتعامل مع المفضلة');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      endDrawer:
          const NotificationsSidebar(), // ✅ إضافة الشريط الجانبي للإشعارات
    );
  }
}
