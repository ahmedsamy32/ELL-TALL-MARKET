import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/review_model.dart';
import 'package:ell_tall_market/services/rating_service.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/interactive_rating_bar.dart';
import 'package:ell_tall_market/widgets/rating_star.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class RateOrderScreen extends StatefulWidget {
  final List<OrderModel> orders;

  const RateOrderScreen({super.key, this.orders = const []});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  // Product Ratings (key: orderId:productId)
  final Map<String, double> _productRatings = {};
  final Map<String, TextEditingController> _productComments = {};
  final Map<String, ReviewModel> _existingReviews = {};
  final Map<String, bool> _isEditing = {};

  Future<List<OrderItemModel>>? _itemsFuture;
  List<OrderItemModel> _allItems = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadOrderItems();
  }

  @override
  void dispose() {
    for (var controller in _productComments.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _productKey(String orderId, String productId) {
    return '$orderId:$productId';
  }

  Future<List<OrderItemModel>> _loadOrderItems() async {
    final orderIds = widget.orders.map((o) => o.id).toList();
    if (orderIds.isEmpty) return [];

    final client = context.read<SupabaseProvider>().client;
    final response = await client
        .from('order_items')
        .select('*, products(image_url)')
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: true);

    final items = (response as List)
        .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
        .toList();

    _allItems = items;

    // Initialize controllers for fetched items
    for (final item in items) {
      if (item.productId != null) {
        final key = _productKey(item.orderId, item.productId!);
        _productRatings.putIfAbsent(key, () => 0);
        _productComments.putIfAbsent(key, () => TextEditingController());
      }
    }

    await _loadExistingReviews(orderIds);

    return items;
  }

  Future<void> _loadExistingReviews(List<String> orderIds) async {
    final userId = context.read<SupabaseProvider>().currentUser?.id;
    if (userId == null) return;

    final ratingService = RatingService(
      context.read<SupabaseProvider>().client,
    );

    final reviews = await ratingService.getUserProductReviewsForOrders(
      orderIds,
      userId,
    );

    for (final review in reviews) {
      if (review.productId == null) continue;
      final key = _productKey(review.orderId, review.productId!);
      _existingReviews[key] = review;
      _productRatings[key] = review.rating.toDouble();
      _productComments.putIfAbsent(key, () => TextEditingController());
      _productComments[key]!.text = review.comment ?? '';
      _isEditing.putIfAbsent(key, () => false);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitReviews() async {
    final userId = context.read<SupabaseProvider>().currentUser?.id;
    if (userId == null) return;

    // Validation: At least one rating must be provided
    bool hasProductRating = _productRatings.values.any((r) => r > 0);

    if (!hasProductRating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تقييم منتج واحد على الأقل')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final reviewsToSubmit = <ReviewModel>[];
    final ratingService = RatingService(
      context.read<SupabaseProvider>().client,
    );

    try {
      // Product Reviews (per item/order)
      for (final item in _allItems) {
        if (item.productId == null) continue;
        final key = _productKey(item.orderId, item.productId!);
        final rating = _productRatings[key] ?? 0;
        if (rating > 0) {
          reviewsToSubmit.add(
            ReviewModel(
              id: '',
              userId: userId,
              orderId: item.orderId,
              productId: item.productId,
              rating: rating.toInt(),
              comment: _productComments[key]?.text.trim().isEmpty == true
                  ? null
                  : _productComments[key]?.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      // Submit all
      if (reviewsToSubmit.isNotEmpty) {
        await ratingService.submitBatchReviews(reviewsToSubmit);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لمشاركتنا رأيك! 🌟')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      AppLogger.error('Failed to submit reviews', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء إرسال التقييم')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('تقييم الطلب')),
        body: const Center(child: Text('لا توجد طلبات لتقييمها')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تقييم الطلب')),
      body: ResponsiveCenter(
        maxWidth: 600,
        child: SafeArea(
          child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<OrderItemModel>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر تحميل منتجات الطلب',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }

                    final items = snapshot.data ?? const <OrderItemModel>[];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (items.isNotEmpty) ...[
                            Text(
                              'تقييم المنتجات',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Product List
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final order = widget.orders.firstWhere(
                                  (o) => o.id == item.orderId,
                                  orElse: () => widget.orders.first,
                                );
                                // Skip if productId is missing
                                if (item.productId == null) {
                                  return const SizedBox.shrink();
                                }

                                return _buildProductRatingCard(
                                  item,
                                  storeName: order.storeName,
                                );
                              },
                            ),
                          ],

                          if (items.isEmpty)
                            const Center(child: Text('لا توجد منتجات لعرضها')),

                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: _submitReviews,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'إرسال التقييم',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildProductRatingCard(OrderItemModel item, {String? storeName}) {
    final key = _productKey(item.orderId, item.productId!);
    final rating = _productRatings[key] ?? 0;
    final existingReview = _existingReviews[key];
    final isEditing = _isEditing[key] ?? existingReview == null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
                image: item.productImage != null
                    ? DecorationImage(
                        image: NetworkImage(item.productImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.productImage == null
                  ? const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (storeName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      storeName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (existingReview != null && !isEditing) ...[
                    RatingStars(rating: rating, starSize: 20),
                    const SizedBox(height: 6),
                    Text(
                      existingReview.comment?.trim().isNotEmpty == true
                          ? existingReview.comment!
                          : 'بدون تعليق',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() => _isEditing[key] = true);
                        },
                        child: const Text('تعديل'),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: InteractiveRatingBar(
                            rating: rating,
                            onRatingUpdate: (val) {
                              setState(() {
                                _productRatings[key] = val;
                              });
                            },
                            size: 24,
                          ),
                        ),
                        if (existingReview != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _isEditing[key] = false);
                            },
                            child: const Text('إلغاء'),
                          ),
                      ],
                    ),
                    if (rating > 0) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _productComments[key],
                        decoration: const InputDecoration(
                          hintText: 'رأيك في المنتج...',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
