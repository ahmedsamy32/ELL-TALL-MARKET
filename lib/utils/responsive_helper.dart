/// Responsive Helper Utilities
/// Provides breakpoints, helpers, and widgets for responsive design
/// across mobile, tablet, and desktop/web layouts.
library;

import 'package:flutter/material.dart';

/// Breakpoint constants matching admin dashboard pattern
class Breakpoints {
  Breakpoints._();

  /// Mobile: < 600px
  static const double mobile = 600;

  /// Tablet: 600–1200px
  static const double tablet = 1200;

  /// Max content width for forms and reading content
  static const double maxContentWidth = 700;

  /// Max form width for centered forms
  static const double maxFormWidth = 600;

  /// Max card width for centered cards
  static const double maxCardWidth = 500;
}

/// Extension on BuildContext for quick responsive checks
extension ResponsiveContext on BuildContext {
  /// Screen width
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Screen height
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True if screen width < 600
  bool get isMobile => screenWidth < Breakpoints.mobile;

  /// True if screen width >= 600 and < 1200
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;

  /// True if screen width >= 1200 (desktop/web)
  bool get isWide => screenWidth >= Breakpoints.tablet;

  /// True if NOT mobile (tablet or wide)
  bool get isLargeScreen => screenWidth >= Breakpoints.mobile;

  /// Responsive value: returns [mobile] for phones, [tablet] for tablets,
  /// [wide] for desktop. If [wide] is null, falls back to [tablet].
  T responsive<T>({required T mobile, required T tablet, T? wide}) {
    if (isWide) return wide ?? tablet;
    if (isTablet) return tablet;
    return mobile;
  }

  /// Responsive grid cross-axis count
  int get responsiveCrossAxisCount => responsive(mobile: 2, tablet: 3, wide: 4);

  /// Responsive padding
  double get responsivePadding =>
      responsive(mobile: 12.0, tablet: 20.0, wide: 24.0);

  /// Responsive horizontal padding for content
  EdgeInsets get responsiveContentPadding {
    if (isWide) {
      final horizontalPad = (screenWidth - Breakpoints.maxContentWidth) / 2;
      return EdgeInsets.symmetric(
        horizontal: horizontalPad.clamp(24, double.infinity),
        vertical: 20,
      );
    }
    return EdgeInsets.all(responsivePadding);
  }
}

/// A builder widget that provides responsive layout information
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for mobile layout (required)
  final Widget Function(BuildContext context, BoxConstraints constraints)
  mobileBuilder;

  /// Builder for tablet layout (optional, falls back to mobile)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
  tabletBuilder;

  /// Builder for wide/desktop layout (optional, falls back to tablet)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
  wideBuilder;

  const ResponsiveBuilder({
    super.key,
    required this.mobileBuilder,
    this.tabletBuilder,
    this.wideBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.sizeOf(context).width;
        if (width >= Breakpoints.tablet && wideBuilder != null) {
          return wideBuilder!(context, constraints);
        }
        if (width >= Breakpoints.mobile && tabletBuilder != null) {
          return tabletBuilder!(context, constraints);
        }
        return mobileBuilder(context, constraints);
      },
    );
  }
}

/// Wraps content with a max-width constraint and centers it.
/// Useful for forms, text content, and card layouts on wide screens.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // On small/mobile screens: return child unchanged (full constraints)
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= maxWidth) {
          return content;
        }
        // On wide screens: center with exact width & height so children like
        // Column(Expanded) and SafeArea(Column) get tight constraints,
        // not the loose ones that Center/Align would give them.
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: content,
          ),
        );
      },
    );
  }
}

/// A responsive grid that adapts cross-axis count based on screen width.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final int? mobileCrossAxisCount;
  final int? tabletCrossAxisCount;
  final int? wideCrossAxisCount;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 0.7,
    this.mobileCrossAxisCount,
    this.tabletCrossAxisCount,
    this.wideCrossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.responsive(
      mobile: mobileCrossAxisCount ?? 2,
      tablet: tabletCrossAxisCount ?? 3,
      wide: wideCrossAxisCount ?? 4,
    );

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
