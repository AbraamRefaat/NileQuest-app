import 'package:flutter/material.dart';
import '../../theme.dart';

/// Star rating widget with two modes:
/// - display: pass [value] (supports half stars), leave [onChanged] null
/// - interactive: pass [onChanged]; taps set a 1-5 rating
class RatingStars extends StatelessWidget {
  final double value;
  final ValueChanged<int>? onChanged;
  final double size;
  final Color color;

  const RatingStars({
    super.key,
    this.value = 0,
    this.onChanged,
    this.size = 20,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final IconData icon;
        if (value >= starValue) {
          icon = Icons.star_rounded;
        } else if (value >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        final star = Icon(icon, size: size, color: color);
        if (onChanged == null) return star;
        return GestureDetector(
          onTap: () => onChanged!(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: star,
          ),
        );
      }),
    );
  }
}
