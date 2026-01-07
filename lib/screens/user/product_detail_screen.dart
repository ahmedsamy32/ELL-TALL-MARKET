import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({required this.product, super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFavorite = false;
  List<String> _allProductImages = [];
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadAllProductImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProductImages() async {
    try {
      // استخدم ProductService لتحميل جميع الصور من Storage
      final images = await _fetchProductImagesFromStorage();

      if (mounted) {
        setState(() {
          _allProductImages = images;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل تحميل صور المنتج: $e');
      // في حالة الفشل، استخدم الصور من الموديل
      if (mounted) {
        setState(() {
          _allProductImages = _productImages;
          _isLoadingImages = false;
        });
      }
    }
  }

  Future<List<String>> _fetchProductImagesFromStorage() async {
    final primaryImageUrl = widget.product.imageUrl;

    // أولاً: جرب استخدام الصور من قاعدة البيانات (imageUrls)
    if (widget.product.imageUrls != null &&
        widget.product.imageUrls!.isNotEmpty) {
      // احذف الصورة الرئيسية من القائمة
      final galleryImages = widget.product.imageUrls!.where((url) {
        return primaryImageUrl == null || url != primaryImageUrl;
      }).toList();

      if (galleryImages.isNotEmpty) {
        AppLogger.info(
          '✅ تم تحميل ${galleryImages.length} صورة من قاعدة البيانات (imageUrls)',
        );
        return galleryImages;
      }
    }

    // ثانياً: جرب تحميل الصور من Storage
    try {
      final supabase = Supabase.instance.client;
      final bucket = supabase.storage.from('products');

      final result = await bucket.list(
        path: '${widget.product.storeId}/${widget.product.id}',
      );

      if (result.isNotEmpty) {
        // احصل على URLs لجميع الصور من Storage
        final imageUrls = result.map((file) {
          return bucket.getPublicUrl(
            '${widget.product.storeId}/${widget.product.id}/${file.name}',
          );
        }).toList();

        // احذف الصورة الرئيسية من القائمة
        final galleryImages = imageUrls.where((url) {
          return primaryImageUrl == null ||
              !url.contains(primaryImageUrl.split('/').last);
        }).toList();

        AppLogger.info('✅ تم تحميل ${galleryImages.length} صورة من Storage');
        return galleryImages;
      }

      AppLogger.info('⚠️ لا توجد صور في Storage');
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في قراءة الصور من Storage: $e');
    }

    AppLogger.info('⚠️ لا توجد صور إضافية متاحة');
    return [];
  }

  List<String> get _productImages {
    if (widget.product.imageUrls != null &&
        widget.product.imageUrls!.isNotEmpty) {
      return widget.product.imageUrls!;
    } else if (widget.product.imageUrl != null) {
      return [widget.product.imageUrl!];
    }
    return [];
  }

  void _showAddedToCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Image and Info (Horizontal Layout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image with Check Mark
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.product.imageUrl != null
                              ? Image.network(
                                  widget.product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.image, size: 40);
                                  },
                                )
                              : const Icon(Icons.image, size: 40),
                        ),
                      ),
                      Positioned(
                        bottom: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'في عربة التسوق',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.product.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons Row
              Row(
                children: [
                  // "تشوّف حاجات تانية" Button (Outlined)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        // Navigate to home screen
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'تشوّف حاجات تانية',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // "عرض السلة" Button (Filled)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CartScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'عرض السلة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount =
        widget.product.comparePrice != null &&
        widget.product.comparePrice! > widget.product.price;
    final discountPercentage = hasDiscount
        ? ((widget.product.comparePrice! - widget.product.price) /
                  widget.product.comparePrice! *
                  100)
              .round()
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isFavorite
                                ? 'تمت الإضافة للمفضلة'
                                : 'تمت الإزالة من المفضلة',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('مشاركة المنتج')),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Title and Description Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Product Description
                            Text(
                              widget.product.description ?? 'لا يوجد وصف متاح',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),

                            // Rating
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '4.3',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(42)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Image Carousel with Indicators
                      if (_isLoadingImages)
                        Container(
                          height: 350,
                          color: Colors.grey[50],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_allProductImages.isNotEmpty) ...[
                        SizedBox(
                          height: 350,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                itemCount: _allProductImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    color: Colors.grey[50],
                                    child: Image.network(
                                      _allProductImages[index],
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image,
                                                size: 50,
                                              ),
                                            );
                                          },
                                    ),
                                  );
                                },
                              ),
                              // Dots Indicator
                              if (_allProductImages.length > 1)
                                Positioned(
                                  bottom: 16,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      _allProductImages.length,
                                      (index) => Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _currentPage == index
                                              ? theme.primaryColor
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else
                        Container(
                          height: 350,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image, size: 50),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Color Variants Section (if multiple images exist)
                      if (!_isLoadingImages &&
                          _allProductImages.length > 1) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'صور المنتج',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _allProductImages.length,
                                  itemBuilder: (context, index) {
                                    final isSelected = _currentPage == index;
                                    return GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Container(
                                        width: 70,
                                        margin: EdgeInsets.only(
                                          right:
                                              index ==
                                                  _allProductImages.length - 1
                                              ? 0
                                              : 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.primaryColor
                                                : Colors.grey[300]!,
                                            width: isSelected ? 2.5 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.network(
                                            _allProductImages[index],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.image,
                                                      size: 30,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Price Section with Discount
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              widget.product.priceFormatted,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 12),
                              Text(
                                '${widget.product.comparePrice!.toStringAsFixed(0)} ج.م',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$discountPercentage% خصم',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Stock Information
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              widget.product.inStock
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 20,
                              color: widget.product.inStock
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.product.stockStatus,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.product.inStock
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 80), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Add to Cart Button (Fixed)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Quantity Selector (Compact)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _quantity.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: _quantity < widget.product.stock
                                ? () => setState(() => _quantity++)
                                : null,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add to Cart Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final authProvider = Provider.of<SupabaseProvider>(
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

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          try {
                            final cartProvider = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );

                            // إظهار BottomSheet فوراً قبل إضافة المنتج
                            _showAddedToCartBottomSheet();

                            // إضافة المنتج في الخلفية
                            final success = await cartProvider.addToCart(
                              productId: widget.product.id,
                              quantity: _quantity,
                            );

                            if (!success) {
                              if (!mounted) return;
                              // في حالة الفشل، أغلق BottomSheet وأظهر رسالة خطأ
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('فشل إضافة المنتج إلى السلة'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            // في حالة خطأ، أغلق BottomSheet وأظهر رسالة الخطأ
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF0D6EFD,
                          ), // Noon blue color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'أضف للعربة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
