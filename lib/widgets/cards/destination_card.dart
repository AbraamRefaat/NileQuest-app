import 'package:flutter/material.dart';
import '../../services/favorites_service.dart';
import '../../theme.dart';

/// Destination showcase card for the home carousel, with a persisted
/// favorite toggle.
class DestinationCard extends StatefulWidget {
  final Map<String, dynamic> destination;

  const DestinationCard({super.key, required this.destination});

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  bool _isFavorite = false;

  String get _favoriteKey => widget.destination['name'] as String;

  @override
  void initState() {
    super.initState();
    FavoritesService().isFavorite(_favoriteKey).then((value) {
      if (mounted && value != _isFavorite) {
        setState(() => _isFavorite = value);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final nowFavorite = await FavoritesService().toggle(_favoriteKey);
    if (mounted) setState(() => _isFavorite = nowFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Stack(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      destination['image'] != null
                          ? Image.asset(
                              destination['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _gradientPlaceholder(),
                            )
                          : _gradientPlaceholder(),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      color: _isFavorite
                          ? Colors.red
                          : AppColors.charcoal.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Popular badge
              if (destination['isPopular'] == true)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            destination['name'],
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Location
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  destination['location'],
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Rating
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                '${destination['rating']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${destination['reviews']})',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.charcoal.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.7),
            AppColors.secondary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Icon(
        Icons.image_rounded,
        size: 60,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}
