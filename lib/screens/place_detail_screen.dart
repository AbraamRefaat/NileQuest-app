import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../constants/categories.dart';
import '../models/itinerary_event.dart';
import '../services/google_places_photo_service.dart';
import '../services/favorites_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final ItineraryEvent? event;
  final VoidCallback onBack;

  const PlaceDetailScreen({
    super.key,
    this.event,
    required this.onBack,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final GooglePlacesPhotoService _photoService = GooglePlacesPhotoService();
  String? _photoUrl;
  bool _isLoadingPhoto = false;
  bool _isFavorite = false;

  String? get _favoriteKey {
    final poi = widget.event?.poi;
    if (poi == null) return null;
    return poi.id.isNotEmpty ? poi.id : poi.name;
  }

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final key = _favoriteKey;
    if (key == null) return;
    final value = await FavoritesService().isFavorite(key);
    if (mounted && value != _isFavorite) {
      setState(() => _isFavorite = value);
    }
  }

  Future<void> _toggleFavorite() async {
    final key = _favoriteKey;
    if (key == null) return;
    final nowFavorite = await FavoritesService().toggle(key);
    if (!mounted) return;
    setState(() => _isFavorite = nowFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowFavorite ? 'Added to favorites ❤️' : 'Removed from favorites'),
        backgroundColor: AppColors.charcoal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _loadPhoto() async {
    if (widget.event == null) return;

    setState(() {
      _isLoadingPhoto = true;
    });

    final poi = widget.event!.poi;
    final photoUrl = await _photoService.getPlacePhotoUrl(
      poi.name,
      poi.lat,
      poi.lon,
    );

    if (mounted) {
      setState(() {
        _photoUrl = photoUrl;
        _isLoadingPhoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no event data, show placeholder
    if (widget.event == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('No place selected'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final poi = widget.event!.poi;
    return Scaffold(
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            child: Column(
              children: [
                // Hero Image
                Stack(
                  children: [
                    Container(
                      height: 350,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: _photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _photoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.5),
                                      AppColors.secondary.withValues(alpha: 0.5),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.account_balance_rounded,
                                  size: 120,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          : _isLoadingPhoto
                              ? Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.5),
                                        AppColors.secondary.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_rounded,
                                    size: 120,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                    ),
                    // Gradient overlay
                    Container(
                      height: 350,
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
                    // Top Navigation
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: widget.onBack,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.share_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _toggleFavorite,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _isFavorite
                                          ? Colors.redAccent
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Title Overlay
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryStyleFor(poi.category).color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  poi.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  poi.indoorOutdoor.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            poi.name,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${poi.lat.toStringAsFixed(4)}, ${poi.lon.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Content
                Container(
                  transform: Matrix4.translationValues(0, -24, 0),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Row
                        Container(
                          padding: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.secondary.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Time
                              Column(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'TIME',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    widget.event!.startTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.secondary.withValues(alpha: 0.2),
                              ),
                              // Duration
                              Column(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'DURATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    '${poi.durationHours.toStringAsFixed(1)}h',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.secondary.withValues(alpha: 0.2),
                              ),
                              // Price
                              Column(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ENTRY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    poi.priceDisplay,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // About Section
                        Text(
                          'About',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          poi.subcategory.isNotEmpty 
                              ? poi.subcategory 
                              : 'A wonderful ${poi.category.toLowerCase()} destination in Egypt.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.charcoal.withValues(alpha: 0.7),
                                height: 1.6,
                              ),
                        ),

                        const SizedBox(height: 32),

                        // Details
                        Text(
                          'Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Category',
                          value: poi.category,
                        ),
                        _DetailRow(
                          label: 'Type',
                          value: poi.subcategory,
                        ),
                        _DetailRow(
                          label: 'Opening Hours',
                          value: poi.openingHours,
                        ),
                        _DetailRow(
                          label: 'Setting',
                          value: poi.indoorOutdoor,
                        ),
                        
                        const SizedBox(height: 24),

                        // Why this place
                        Text(
                          'Why this place?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            widget.event!.reason,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.charcoal.withValues(alpha: 0.8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 100), // Space for CTA button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating CTA Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 12,
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    child: const Text(
                      'Add to Itinerary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
