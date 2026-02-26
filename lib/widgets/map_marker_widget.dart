import 'package:flutter/material.dart';
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Historical':
        return const Color(0xFFE67E22); // Orange
      case 'Museum':
        return const Color(0xFF9B59B6); // Purple
      case 'Religious':
        return const Color(0xFF3498DB); // Blue
      case 'Natural':
        return const Color(0xFF27AE60); // Green
      case 'Shopping':
        return const Color(0xFFF39C12); // Yellow-Orange
      case 'Beach Resort':
        return const Color(0xFF1ABC9C); // Teal
      case 'Art & Culture':
        return const Color(0xFFE74C3C); // Red
      case 'Food & Dining':
        return const Color(0xFFF1C40F); // Yellow
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Historical':
        return Icons.account_balance_rounded;
      case 'Museum':
        return Icons.museum_rounded;
      case 'Religious':
        return Icons.mosque_rounded;
      case 'Natural':
        return Icons.landscape_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Beach Resort':
        return Icons.beach_access_rounded;
      case 'Art & Culture':
        return Icons.palette_rounded;
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }
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
