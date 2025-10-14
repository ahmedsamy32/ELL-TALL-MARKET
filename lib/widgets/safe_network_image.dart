import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final IconData defaultIcon;
  final Color defaultColor;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.defaultIcon = Icons.image,
    this.defaultColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    // إذا كان الرابط فارغ أو يحتوي على via.placeholder.com، عرض widget افتراضي مباشرة
    if (imageUrl.isEmpty || imageUrl.contains('via.placeholder.com')) {
      return _buildDefaultWidget();
    }

    // فقط إذا كان الرابط صحيح ولا يحتوي على via.placeholder.com
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildDefaultWidget(),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultWidget(),
    );
  }

  Widget _buildDefaultWidget() {
    return Container(
      width: width,
      height: height,
      color: defaultColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          defaultIcon,
          size: width != null ? width! * 0.3 : 40,
          color: defaultColor,
        ),
      ),
    );
  }
}
