import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/review_model.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:ell_tall_market/widgets/rating_star.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/services/rating_service.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({required this.product, super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // ===========================================================================
  // 1. State & Logic
  // ===========================================================================
  int _quantity = 1;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<String> _allProductImages = [];
  bool _isLoadingImages = true;
  BuildContext? _addToCartSheetContext;

  // Attributes State
  List<ProductVariantGroup> _variantGroups = [];
  final Map<String, String> _selectedOptions = {};
  bool _isLoadingVariants = true;
  bool _showVariantValidationError = false;
  String? _variantErrorMessage;

  // Store State
  StoreModel? _store;
  bool _isLoadingStore = true;

  // Reviews State
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  double _realRating = 0.0;
  int _realReviewCount = 0;
  Map<int, int> _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  // ===========================================================================
  // 2. Lifecycle
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadAllProductImages();

    // إذا كانت البيانات موجودة في الموديل، استخدمها مباشرة
    if (widget.product.variantGroups != null &&
        widget.product.variantGroups!.isNotEmpty) {
      _variantGroups = widget.product.variantGroups!;
      // اختر تلقائياً المجموعات التي تحتوي على خيار واحد فقط
      for (final group in _variantGroups) {
        if (group.options.length == 1) {
          _selectedOptions[group.name] = group.options.first.value;
        }
      }
      _isLoadingVariants = false;
    } else {
      // إذا لم تكن موجودة (مثلاً تم فتح الصفحة من رابط خارجي)، حاول تحميلها
      _loadVariants();
    }
    _loadStoreInfo();
    _loadReviews();
  }

  // ===========================================================================

  Future<void> _loadAllProductImages() async {
    try {
      // استخدم ProductService لتحميل جميع الصور من Storage
      final images = await _fetchProductImagesFromStorage();
      final effectiveImages = images.isNotEmpty ? images : _productImages;

      final shouldResetPage = _currentPage >= effectiveImages.length;

      if (mounted) {
        setState(() {
          _allProductImages = effectiveImages;
          if (shouldResetPage) _currentPage = 0;
          _isLoadingImages = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _precacheFirstImages(_allProductImages);
        });

        if (shouldResetPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        }
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل تحميل صور المنتج: $e');
      // في حالة الفشل، استخدم الصور من الموديل
      if (mounted) {
        setState(() {
          _allProductImages = _productImages;
          _isLoadingImages = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _precacheFirstImages(_allProductImages);
        });
      }
    }
  }

  Future<void> _precacheFirstImages(List<String> urls) async {
    // تحسين تجربة الدخول للصفحة: حضّر أول صورة/صورتين لتقليل الوميض.
    final toCache = urls.take(2).toList(growable: false);
    for (final url in toCache) {
      if (!mounted) return;
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (_) {
        // تجاهل أي أخطاء تحميل/شبكة أثناء الـ precache
      }
    }
  }

  Future<List<String>> _fetchProductImagesFromStorage() async {
    final primaryImageUrl = widget.product.imageUrl;
    final primaryFileName =
        (primaryImageUrl != null && primaryImageUrl.isNotEmpty)
        ? primaryImageUrl.split('/').last
        : null;

    // اجمع الصور بترتيب ثابت: الأساسية أولاً ثم الباقي، مع إزالة التكرار.
    final out = <String>[];
    final seen = <String>{};
    void addUrl(String? url) {
      if (url == null || url.isEmpty) return;
      if (seen.add(url)) out.add(url);
    }

    addUrl(primaryImageUrl);
    for (final url in widget.product.imageUrls ?? const <String>[]) {
      addUrl(url);
    }

    // إذا كانت قاعدة البيانات تحتوي على أكثر من صورة، لا حاجة لاستعلام Storage.
    if (out.length > 1) {
      AppLogger.info('✅ تم تحميل ${out.length} صورة من قاعدة البيانات');
      return out;
    }

    // ثانياً: جرب تحميل الصور من Storage
    try {
      final supabase = Supabase.instance.client;
      final bucket = supabase.storage.from('products');

      final result = await bucket.list(
        path: '${widget.product.storeId}/${widget.product.id}',
      );

      if (result.isNotEmpty) {
        for (final file in result) {
          if (primaryFileName != null && file.name == primaryFileName) {
            continue;
          }
          addUrl(
            bucket.getPublicUrl(
              '${widget.product.storeId}/${widget.product.id}/${file.name}',
            ),
          );
        }

        AppLogger.info('✅ تم تحميل ${out.length} صورة (DB + Storage)');
        return out;
      }

      AppLogger.info('⚠️ لا توجد صور في Storage');
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في قراءة الصور من Storage: $e');
    }

    AppLogger.info('⚠️ لا توجد صور إضافية متاحة');
    return out;
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

  Future<void> _loadVariants() async {
    // إذا كانت البيانات موجودة في الموديل، لا داعي للتحميل مرة أخرى
    if (widget.product.variantGroups != null) {
      if (mounted) {
        setState(() {
          _variantGroups = widget.product.variantGroups!;
          for (final group in _variantGroups) {
            if (group.options.length == 1) {
              _selectedOptions[group.name] = group.options.first.value;
            }
          }
          _isLoadingVariants = false;
        });
      }
      return;
    }

    try {
      final groups = await ProductService.getProductVariantGroups(
        widget.product.id,
      );
      if (mounted) {
        setState(() {
          _variantGroups = groups;
          // تهيئة الاختيارات الافتراضية بأول خيار من كل مجموعة
          for (final group in groups) {
            if (group.options.length == 1) {
              _selectedOptions[group.name] = group.options.first.value;
            }
          }
          _isLoadingVariants = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading variants', e, stackTrace);
      if (mounted) {
        setState(() => _isLoadingVariants = false);
      }
    }
  }

  Future<void> _loadStoreInfo() async {
    try {
      final store = await StoreService.getStoreById(widget.product.storeId);
      if (mounted) {
        setState(() {
          _store = store;
          _isLoadingStore = false;
        });
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل تحميل معلومات المتجر: $e');
      if (mounted) {
        setState(() => _isLoadingStore = false);
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      final ratingService = RatingService(Supabase.instance.client);
      final reviews = await ratingService.getProductReviews(
        widget.product.id,
        limit: 50,
      );

      // حساب التقييم الحقيقي من المراجعات
      double avgRating = 0.0;
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      if (reviews.isNotEmpty) {
        final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
        avgRating = total / reviews.length;
        for (final r in reviews) {
          distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _realRating = avgRating;
          _realReviewCount = reviews.length;
          _ratingDistribution = distribution;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل تحميل تقييمات المنتج: $e');
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  // ===========================================================================
  // 9. Helper Methods
  // ===========================================================================

  List<String> _missingRequiredGroupNames() {
    if (_variantGroups.isEmpty) return const [];
    final missing = <String>[];
    for (final group in _variantGroups) {
      if (!_selectedOptions.containsKey(group.name)) {
        missing.add(group.name);
      }
    }
    return missing;
  }

  String _buildShareText() {
    final name = widget.product.name;
    final price = widget.product.priceFormatted;
    return '$name\n$price';
  }

  // Removed _parseColor helper

  // ===========================================================================
  // 4. Action Handlers
  // ===========================================================================

  void _navigateToProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  Future<void> _handleSharePressed() async {
    try {
      final shareText = _buildShareText();

      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox != null
          ? (renderBox.localToGlobal(Offset.zero) & renderBox.size)
          : null;

      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: widget.product.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر مشاركة المنتج حالياً')),
      );
    }
  }

  // Space reserved for action handlers

  Future<void> _handleFavoritePressed() async {
    final authProvider = context.read<SupabaseProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      Navigator.of(context).pushNamed(AppRoutes.login);
      return;
    }

    final favoritesProvider = context.read<FavoritesProvider>();
    final wasFavorite = favoritesProvider.isFavoriteProduct(widget.product.id);

    final ok = await favoritesProvider.toggleFavoriteProduct(widget.product);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite ? 'تمت الإزالة من المفضلة' : 'تمت الإضافة للمفضلة',
          ),
          backgroundColor: wasFavorite ? Colors.red : Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(favoritesProvider.error ?? 'فشل تحديث المفضلة'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddedToCartBottomSheet() {
    _addToCartSheetContext = null;
    final sheetFuture = showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        _addToCartSheetContext = sheetContext;
        return SafeArea(
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
                          Navigator.of(sheetContext).pop();
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
                          Navigator.of(sheetContext).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartScreen(),
                            ),
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
        );
      },
    );

    sheetFuture.whenComplete(() {
      _addToCartSheetContext = null;
    });
  }

  // Removed unused old attribute UI methods

  Widget _buildSelectionSummary() {
    if (_selectedOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: _selectedOptions.entries.map((entry) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.key}: ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 7. Secondary/Helper UI Components
  // ===========================================================================

  Widget _buildReviewsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(Icons.reviews_rounded, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'التقييمات والمراجعات',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingReviews)
            SizedBox(height: 120, child: AppShimmer.centeredLines(context))
          else if (_reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد تقييمات بعد',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'كن أول من يقيّم هذا المنتج!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // ملخص التقييمات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: RatingSummary(
                averageRating: _realRating,
                totalReviews: _realReviewCount,
                ratingDistribution: _ratingDistribution,
              ),
            ),
            const SizedBox(height: 16),

            // قائمة المراجعات
            ...(_reviews.take(5).map((review) => _buildReviewCard(review))),

            // زر عرض المزيد
            if (_reviews.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAllReviewsSheet(),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('عرض كل التقييمات (${_reviews.length})'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = intl.DateFormat('yyyy/MM/dd').format(review.createdAt);
    final userName = review.userName ?? 'مستخدم';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // صورة المستخدم أو الحرف الأول
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    review.userAvatar != null && review.userAvatar!.isNotEmpty
                    ? NetworkImage(review.userAvatar!)
                    : null,
                child: review.userAvatar == null || review.userAvatar!.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // النجوم
              RatingStars(rating: review.rating.toDouble(), starSize: 16),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showAllReviewsSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'كل التقييمات (${_reviews.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      return _buildReviewCard(_reviews[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedProductsSection() {
    return FutureBuilder<List<ProductModel>>(
      future: ProductService.getRelatedProducts(
        productId: widget.product.id,
        categoryId: widget.product.categoryId,
        limit: 4,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final relatedProducts = snapshot.data!;

        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'منتجات مشابهة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260, // تم زيادة الارتفاع ليتناسب مع الكارت الجديد
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, _) {
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: relatedProducts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final product = relatedProducts[index];
                          final isFavorite = favoritesProvider.isFavorite(
                            product.id,
                          );

                          return SizedBox(
                            width:
                                180, // تم زيادة العرض ليتناسب مع الكارت الجديد
                            child: ProductCard(
                              product: product,
                              isFavorite: isFavorite,
                              onTap: () => _navigateToProduct(product),
                              onFavoritePressed: () async {
                                final wasFavorite = favoritesProvider
                                    .isFavoriteProduct(product.id);
                                await favoritesProvider.toggleFavoriteProduct(
                                  product,
                                );
                                if (mounted && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        wasFavorite
                                            ? 'تمت الإزالة من المفضلة'
                                            : 'تمت الإضافة للمفضلة',
                                      ),
                                      backgroundColor: wasFavorite
                                          ? Colors.red
                                          : Colors.green,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              onBuyPressed: () {
                                // التوجيه لصفحة المنتج عند الضغط على إضافة للسلة
                                // لأن المنتج قد يحتوي على خيارات تحتاج لاختيارها
                                _navigateToProduct(product);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 5. Build Method
  // ===========================================================================

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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildWideLayout(theme, hasDiscount, discountPercentage);
          }
          return _buildMobileLayout(theme, hasDiscount, discountPercentage);
        },
      ),
    );
  }

  // Wide (web) two-column layout
  Widget _buildWideLayout(
    ThemeData theme,
    bool hasDiscount,
    int discountPercentage,
  ) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Right column (RTL) — info + attributes + related
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back / fav / share buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          _buildGlassButton(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Consumer<FavoritesProvider>(
                            builder: (context, favoritesProvider, _) {
                              final isFavorite = favoritesProvider
                                  .isFavoriteProduct(widget.product.id);
                              return _buildGlassButton(
                                icon: isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? Colors.red : null,
                                onPressed: _handleFavoritePressed,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildGlassButton(
                            icon: Icons.share_outlined,
                            onPressed: _handleSharePressed,
                          ),
                        ],
                      ),
                    ),
                    _buildMainInfo(hasDiscount, discountPercentage),
                    _buildEnhancedAttributesSection(),
                    _buildRelatedProductsSection(),
                  ],
                ),
              ),
              // Left column (RTL) — image + store + rating + reviews
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildImageCarousel(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStoreCard(),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildRatingBadge(),
                    ),
                    const SizedBox(height: 8),
                    _buildReviewsSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
      ],
    );
  }

  // Mobile (original) layout
  Widget _buildMobileLayout(
    ThemeData theme,
    bool hasDiscount,
    int discountPercentage,
  ) {
    return ResponsiveCenter(
      maxWidth: 900,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Immersive AppBar & Product Images
              SliverAppBar(
                expandedHeight: 450,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leadingWidth: 60,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildGlassButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                    child: Consumer<FavoritesProvider>(
                      builder: (context, favoritesProvider, _) {
                        final isFavorite = favoritesProvider.isFavoriteProduct(
                          widget.product.id,
                        );
                        return _buildGlassButton(
                          icon: isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFavorite ? Colors.red : null,
                          onPressed: _handleFavoritePressed,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildGlassButton(
                      icon: Icons.share_outlined,
                      onPressed: _handleSharePressed,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageCarousel(),
                      // Bottom gradient for white text legibility
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.1),
                                ],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product Info Sections
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Card (Moved to top as requested)
                    _buildStoreCard(),

                    // Title & Description Card
                    _buildMainInfo(hasDiscount, discountPercentage),

                    // Attributes Selection
                    _buildEnhancedAttributesSection(),

                    // Reviews Section
                    _buildReviewsSection(),

                    // Related Products
                    _buildRelatedProductsSection(),

                    const SizedBox(height: 180), // Bottom bar workspace
                  ],
                ),
              ),
            ],
          ),

          // Floating Bottom Navigation
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.black87, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  // ===========================================================================
  // 6. Primary Component Builders
  // ===========================================================================

  Widget _buildMainInfo(bool hasDiscount, int discountPercentage) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.product.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildRatingBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'وصف المنتج',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description ?? 'لا يوجد وصف متاح',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.product.customFields != null &&
              widget.product.customFields!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showSpecificationsSheet,
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('تفاصيل المنتج'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.product.priceFormatted,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 12),
                Text(
                  '${widget.product.comparePrice!.toStringAsFixed(0)} ج.م',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$discountPercentage% خصم',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge() {
    final rating = _isLoadingReviews ? widget.product.rating : _realRating;
    final count = _isLoadingReviews
        ? widget.product.reviewCount
        : _realReviewCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : '0.0',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. Secondary / Helper UI Components
  // ===========================================================================

  Widget _buildImageCarousel() {
    if (_isLoadingImages) {
      return AppShimmer.centeredLines(context);
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          physics: const AlwaysScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemCount: _allProductImages.length,
          itemBuilder: (context, index) {
            return Hero(
              tag: index == 0
                  ? 'product_${widget.product.id}'
                  : 'product_${widget.product.id}_$index',
              child: Image.network(
                _allProductImages[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 50),
              ),
            );
          },
        ),
        if (_allProductImages.length > 1)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_allProductImages.length, (index) {
                final isSelected = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildStoreCard() {
    if (_isLoadingStore) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: AppShimmer.centeredLines(context),
      );
    }

    final theme = Theme.of(context);
    final storeName = _store?.name ?? 'متجر غير معروف';
    final storeRating = _store?.rating.toString() ?? '0.0';

    return GestureDetector(
      onTap: () {
        if (_store != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.storeDetail,
            arguments: _store,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _store?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _store!.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.storefront_rounded,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'بائع موثوق • تقييم $storeRating',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 8. Bottom & Selection UI
  // ===========================================================================

  Widget _buildEnhancedAttributesSection() {
    if (_isLoadingVariants) {
      return _buildAttributesShimmer();
    }

    if (_variantGroups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          iconColor: theme.primaryColor,
          collapsedIconColor: theme.hintColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'خصائص المنتج',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              if (_selectedOptions.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedOptions.length} اختيار',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._variantGroups.map((group) {
                    final isMissingRequired =
                        _showVariantValidationError &&
                        !_selectedOptions.containsKey(group.name);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              group.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isMissingRequired
                                    ? colorScheme.error
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                              ),
                            ),
                            if (group.isRequired) ...[
                              const SizedBox(width: 4),
                              Text(
                                '*',
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'مطلوب',
                            style: TextStyle(
                              color: isMissingRequired
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildEnhancedChipOptions(group),
                      ],
                    );
                  }),
                  if (_variantErrorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _variantErrorMessage!,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributesShimmer() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: AppShimmer.centeredLines(context),
    );
  }

  // Removed _buildEnhancedColorOptions

  Widget _buildEnhancedChipOptions(ProductVariantGroup group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: group.options.map((option) {
        final isSelected = _selectedOptions[group.name] == option.value;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedOptions[group.name] = option.value;
              if (_showVariantValidationError) {
                _showVariantValidationError =
                    _missingRequiredGroupNames().isNotEmpty;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor : colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              option.value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final isOutOfStock =
        !widget.product.inStock || widget.product.stockQuantity <= 0;
    final isLowStock =
        widget.product.inStock &&
        widget.product.stockQuantity > 0 &&
        widget.product.stockQuantity < 10;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عرض حالة المخزون
          if (isOutOfStock)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'هذا المنتج غير متوفر حالياً',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else if (isLowStock)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'آخر ${widget.product.stockQuantity} قطع متاحة',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedOptions.isNotEmpty) ...[
            _buildSelectionSummary(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (!isOutOfStock) _buildSelector(),
              if (!isOutOfStock) const SizedBox(width: 16),
              Expanded(
                child: Hero(
                  tag: 'add_to_cart_${widget.product.id}',
                  child: ElevatedButton(
                    onPressed: isOutOfStock ? null : _handleAddToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOutOfStock
                          ? Colors.grey[400]
                          : theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isOutOfStock ? 'غير متوفر' : 'أضف للعربة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildSelectorBtn(Icons.remove, () {
            if (_quantity > 1) setState(() => _quantity--);
          }),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                _quantity.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          _buildSelectorBtn(Icons.add, () {
            if (_quantity < widget.product.stockQuantity) {
              setState(() => _quantity++);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildSelectorBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Future<void> _handleAddToCart() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    final missingGroups = _missingRequiredGroupNames();
    if (missingGroups.isNotEmpty) {
      setState(() {
        _showVariantValidationError = true;
        _variantErrorMessage = 'يرجى اختيار: ${missingGroups.join('، ')}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار: ${missingGroups.join('، ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      _showAddedToCartBottomSheet();

      final success = await cartProvider.addToCart(
        productId: widget.product.id,
        quantity: _quantity,
        selectedOptions: _selectedOptions,
      );

      if (!success) {
        if (!mounted) return;
        if (_addToCartSheetContext != null && _addToCartSheetContext!.mounted) {
          Navigator.of(_addToCartSheetContext!).pop();
        }
        messenger.showSnackBar(
          const SnackBar(content: Text('فشل إضافة المنتج إلى السلة')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (_addToCartSheetContext != null && _addToCartSheetContext!.mounted) {
        Navigator.of(_addToCartSheetContext!).pop();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('حدث خطأ في تحديث السلة')),
      );
    }
  }

  void _showSpecificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تفاصيل المنتج',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (widget.product.customFields == null ||
                    widget.product.customFields!.isEmpty)
                  const Text('لا توجد مواصفات إضافية')
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        children: widget.product.customFields!.entries.map((
                          entry,
                        ) {
                          return TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
