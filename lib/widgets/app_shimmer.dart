import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer {
  static Color _base(ColorScheme cs) => cs.surfaceContainerHighest;
  static Color _highlight(ColorScheme cs) => cs.surfaceContainerLow;

  static Widget box(
    BuildContext context, {
    required double width,
    required double height,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(12),
    ),
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: _base(cs), borderRadius: borderRadius),
    );
  }

  static Widget circle(BuildContext context, {required double size}) {
    return box(
      context,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  static Widget wrap(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: _base(cs),
      highlightColor: _highlight(cs),
      child: child,
    );
  }

  static Widget centeredLines(
    BuildContext context, {
    int lines = 3,
    double maxWidth = 260,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                circle(context, size: 40),
                const SizedBox(height: 16),
                for (int i = 0; i < lines; i++) ...[
                  box(
                    context,
                    width: maxWidth * (i == 0 ? 1.0 : (i == 1 ? 0.85 : 0.7)),
                    height: 12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );

        // Prevent shimmer render assertions when parent gives unbounded size.
        if (constraints.hasBoundedHeight && constraints.hasBoundedWidth) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: wrap(context, child: content),
          );
        }

        return wrap(context, child: content);
      },
    );
  }

  static Widget list(
    BuildContext context, {
    int itemCount = 6,
    double itemHeight = 72,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    Widget shimmerItem(BuildContext context) {
      return Container(
        height: itemHeight,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            circle(context, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  box(
                    context,
                    width: double.infinity,
                    height: 12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 10),
                  box(
                    context,
                    width: 180,
                    height: 10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return wrap(
            context,
            child: ListView.separated(
              padding: padding,
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => shimmerItem(context),
            ),
          );
        }

        // Fallback for unbounded parents (e.g. nested inside another scroll/sliver)
        return wrap(
          context,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < itemCount; i++) ...[
                  shimmerItem(context),
                  if (i != itemCount - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget grid(
    BuildContext context, {
    int itemCount = 6,
    int crossAxisCount = 2,
    double childAspectRatio = 0.7,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return wrap(
      context,
      child: GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
