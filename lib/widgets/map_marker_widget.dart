import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../theme.dart';

class MapMarkerWidget extends StatelessWidget {
  final String category;
  final String name;
  final double? rating;
  final bool showLabel;
  final VoidCallback? onTap;

  const MapMarkerWidget({
    super.key,
    required this.category,
    required this.name,
    this.rating,
    this.showLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label (only show if enabled)
          if (showLabel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (showLabel) const SizedBox(height: 4),
          
          // Marker Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getCategoryColor(category),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: Colors.white,
              size: 18,
            ),
          ),
          
          // Pin pointer
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinPointerPainter(color: _getCategoryColor(category)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) => categoryStyleFor(category).color;

  IconData _getCategoryIcon(String category) => categoryStyleFor(category).icon;
}

class _PinPointerPainter extends CustomPainter {
  final Color color;

  _PinPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Cluster Marker Widget
class ClusterMarkerWidget extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const ClusterMarkerWidget({
    super.key,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _getSize(),
        height: _getSize(),
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  double _getSize() {
    if (count > 50) return 56;
    if (count > 20) return 48;
    if (count > 10) return 40;
    return 36;
  }
}
