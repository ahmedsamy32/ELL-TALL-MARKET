// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsConfigGen {
  const $AssetsConfigGen();

  /// File path: assets/config/ui_config.json
  String get uiConfig => 'assets/config/ui_config.json';

  /// List of all assets
  List<String> get values => [uiConfig];
}

class $AssetsFontsGen {
  const $AssetsFontsGen();

  /// File path: assets/fonts/Cairo-Bold.ttf
  String get cairoBold => 'assets/fonts/Cairo-Bold.ttf';

  /// File path: assets/fonts/Cairo-Regular.ttf
  String get cairoRegular => 'assets/fonts/Cairo-Regular.ttf';

  /// File path: assets/fonts/Cairo-SemiBold.ttf
  String get cairoSemiBold => 'assets/fonts/Cairo-SemiBold.ttf';

  /// List of all assets
  List<String> get values => [cairoBold, cairoRegular, cairoSemiBold];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/icon.png
  AssetGenImage get icon => const AssetGenImage('assets/icons/icon.png');

  /// File path: assets/icons/icon2.png
  AssetGenImage get icon2 => const AssetGenImage('assets/icons/icon2.png');

  /// List of all assets
  List<AssetGenImage> get values => [icon, icon2];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/IMG-20250817-WA0005.jpg
  AssetGenImage get img20250817Wa0005 =>
      const AssetGenImage('assets/images/IMG-20250817-WA0005.jpg');

  /// File path: assets/images/onboarding1.jpg
  AssetGenImage get onboarding1 =>
      const AssetGenImage('assets/images/onboarding1.jpg');

  /// File path: assets/images/onboarding11.png
  AssetGenImage get onboarding11 =>
      const AssetGenImage('assets/images/onboarding11.png');

  /// File path: assets/images/onboarding2.jpg
  AssetGenImage get onboarding2 =>
      const AssetGenImage('assets/images/onboarding2.jpg');

  /// File path: assets/images/onboarding21.png
  AssetGenImage get onboarding21 =>
      const AssetGenImage('assets/images/onboarding21.png');

  /// File path: assets/images/onboarding3.jpg
  AssetGenImage get onboarding3 =>
      const AssetGenImage('assets/images/onboarding3.jpg');

  /// File path: assets/images/onboarding31.webp
  AssetGenImage get onboarding31 =>
      const AssetGenImage('assets/images/onboarding31.webp');

  /// List of all assets
  List<AssetGenImage> get values => [
    img20250817Wa0005,
    onboarding1,
    onboarding11,
    onboarding2,
    onboarding21,
    onboarding3,
    onboarding31,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsConfigGen config = $AssetsConfigGen();
  static const $AssetsFontsGen fonts = $AssetsFontsGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
