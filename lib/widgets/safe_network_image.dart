import 'dart:convert';
import 'dart:typed_data';
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
    final trimmed = imageUrl.trim();

    // إذا كان الرابط فارغ أو يحتوي على via.placeholder.com، عرض widget افتراضي مباشرة
    if (trimmed.isEmpty || trimmed.contains('via.placeholder.com')) {
      return _buildDefaultWidget();
    }

    // دعم صور Data URL / Base64 (data:image/...)
    if (trimmed.startsWith('data:image/') || trimmed.startsWith('data:')) {
      try {
        final commaIndex = trimmed.indexOf(',');
        final base64String = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
        final cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
        final Uint8List bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildDefaultWidget(),
        );
      } catch (_) {
        return errorWidget ?? _buildDefaultWidget();
      }
    }

    // إذا لم يكن رابط شبكة صحيح (http / https)
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return _buildDefaultWidget();
    }

    // رابط شبكة عادي
    return CachedNetworkImage(
      imageUrl: trimmed,
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
