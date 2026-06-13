import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/tourist_attraction.dart';
import '../../theme.dart';

/// Builds the data map a [DestinationCard] expects from a live
/// [TouristAttraction]. [imageUrl] is the resolved Google Places photo URL
/// (built by the caller via PlacesService.getPhotoUrl), or null.
Map<String, dynamic> destinationCardData(
  TouristAttraction attraction, {
  String? imageUrl,
}) {
  return {
    'name': attraction.name,
    'location': attraction.city.isNotEmpty
        ? '${attraction.city}, Egypt'
        : 'Egypt',
    'rating': attraction.rating ?? 0,
    'reviews': attraction.userRatingsTotal?.toString() ?? '0',
    'imageUrl': imageUrl,
    'isPopular': (attraction.userRatingsTotal ?? 0) >= 1000,
  };
}

/// Destination showcase card for the home carousel.
///
/// The image comes from either a bundled asset (`destination['image']`) or a
/// live network URL (`destination['imageUrl']`, e.g. a Google Places photo);
/// the network URL takes priority when both are present. Pass [onTap] to make
/// the card open a detail view.
class DestinationCard extends StatelessWidget {
  final Map<String, dynamic> destination;
  final VoidCallback? onTap;

  /// Card width. Defaults to the fixed 220 used by the home carousel; pass
  /// `double.infinity` to let the card fill its parent (e.g. a grid cell).
  final double width;

  /// Outer margin. Defaults to a right gap for the horizontal carousel; pass
  /// [EdgeInsets.zero] when the parent already handles spacing (e.g. a grid).
  final EdgeInsets? margin;

  const DestinationCard({
    super.key,
    required this.destination,
    this.onTap,
    this.width = 220,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: margin ?? const EdgeInsets.only(right: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Container
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
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
                            _buildImage(destination),
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
            // Rating (hidden when the place has no rating yet)
            if (((destination['rating'] as num?) ?? 0) > 0)
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
      ),
    );
  }

  /// Network photo (Google Places) when available, otherwise a bundled asset,
  /// falling back to a gradient placeholder if either fails to load.
  Widget _buildImage(Map<String, dynamic> destination) {
    final imageUrl = destination['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _gradientPlaceholder(),
        errorWidget: (context, url, error) => _gradientPlaceholder(),
      );
    }
    if (destination['image'] != null) {
      return Image.asset(
        destination['image'],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _gradientPlaceholder(),
      );
    }
    return _gradientPlaceholder();
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
