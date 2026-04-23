import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class BannerWidget extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const BannerWidget({
    super.key,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.onTap,
    this.height = 150,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: Stack(
          children: [
            // الصورة الخلفية
            ClipRRect(
              borderRadius: borderRadius,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: fit,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.error),
                ),
              ),
            ),

            // التدرج اللوني
            if (title != null || subtitle != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

            // النصوص
            if (title != null || subtitle != null)
              Positioned(
                left: 16,
                bottom: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final double height;
  final double viewportFraction;
  final bool autoPlay;
  final Duration autoPlayInterval;

  const BannerCarousel({
    super.key,
    required this.banners,
    this.height = 200,
    this.viewportFraction = 0.8,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (mounted && widget.banners.length > 1) {
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      }
    });
  }

  /// Handle banner tap navigation based on target type
  void _handleBannerTap(BuildContext context, Map<String, dynamic> banner) {
    final targetType = banner['targetType'] as String?;
    final targetId = banner['targetId'] as String?;
    final actionUrl = banner['actionUrl'] as String?;

    // If custom action URL is provided, prioritize it
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // You can add custom URL handling here (e.g., launch URL)
      debugPrint('Custom action URL: $actionUrl');
      return;
    }

    // Navigate based on target type
    if (targetType != null && targetId != null) {
      switch (targetType.toLowerCase()) {
        case 'product':
          Navigator.pushNamed(
            context,
            AppRoutes.productDetail,
            arguments: {'productId': targetId},
          );
          break;

        case 'store':
          Navigator.pushNamed(
            context,
            AppRoutes.storeDetail,
            arguments: {'storeId': targetId},
          );
          break;

        case 'category':
          Navigator.pushNamed(
            context,
            AppRoutes.category,
            arguments: {'categoryId': targetId},
          );
          break;

        case 'promotion':
          // Handle promotion - could show a dialog or navigate to a special screen
          debugPrint('Promotion banner tapped: $targetId');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(banner['title'] ?? 'عرض خاص'),
              duration: Duration(seconds: 2),
            ),
          );
          break;

        default:
          debugPrint('Unknown banner target type: $targetType');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: BannerWidget(
                  imageUrl: banner['imageUrl'],
                  title: banner['title'],
                  subtitle: banner['subtitle'],
                  onTap: () => _handleBannerTap(context, banner),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8),
        if (widget.banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                ),
              );
            }),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
