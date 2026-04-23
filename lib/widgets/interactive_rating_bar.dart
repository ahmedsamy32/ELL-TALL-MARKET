import 'package:flutter/material.dart';

class InteractiveRatingBar extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingUpdate;
  final double size;
  final Color filledColor;
  final Color emptyColor;

  const InteractiveRatingBar({
    super.key,
    required this.rating,
    required this.onRatingUpdate,
    this.size = 32,
    this.filledColor = Colors.amber,
    this.emptyColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => onRatingUpdate(starIndex.toDouble()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              starIndex <= rating
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: size,
              color: starIndex <= rating ? filledColor : emptyColor,
            ),
          ),
        );
      }),
    );
  }
}
