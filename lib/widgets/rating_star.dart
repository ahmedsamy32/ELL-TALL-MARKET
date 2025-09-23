import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double starSize;
  final Color color;

  const RatingStars({
    super.key,
    required this.rating,
    this.starSize = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // نجمة مملوءة بالكامل
          return Icon(Icons.star, size: starSize, color: color);
        } else if (index < rating.ceil()) {
          // نجمة نصف مملوءة
          return Icon(Icons.star_half, size: starSize, color: color);
        } else {
          // نجمة فارغة
          return Icon(Icons.star_border, size: starSize, color: color);
        }
      }),
    );
  }
}

class RatingBar extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final bool showReviewsCount;

  const RatingBar({
    super.key,
    required this.rating,
    this.totalReviews = 0,
    this.showReviewsCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RatingStars(rating: rating),
        if (showReviewsCount && totalReviews > 0) ...[
          SizedBox(width: 4),
          Text(
            '($totalReviews)',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class RatingProgressIndicator extends StatelessWidget {
  final int starCount;
  final int totalReviews;
  final int reviewsForStar;

  const RatingProgressIndicator({
    super.key,
    required this.starCount,
    required this.totalReviews,
    required this.reviewsForStar,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalReviews > 0
        ? (reviewsForStar / totalReviews) * 100
        : 0;

    return Row(
      children: [
        Text('$starCount', style: TextStyle(fontSize: 12)),
        SizedBox(width: 4),
        Icon(Icons.star, size: 12, color: Colors.amber),
        SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            minHeight: 6,
          ),
        ),
        SizedBox(width: 8),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class RatingSummary extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  const RatingSummary({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingStars(rating: averageRating, starSize: 20),
                SizedBox(height: 4),
                Text(
                  '$totalReviews تقييم${totalReviews != 1 ? 'ات' : ''}',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        ...List.generate(5, (index) {
          final starCount = 5 - index;
          final reviews = ratingDistribution[starCount] ?? 0;
          return RatingProgressIndicator(
            starCount: starCount,
            totalReviews: totalReviews,
            reviewsForStar: reviews,
          );
        }).reversed,
      ],
    );
  }
}
