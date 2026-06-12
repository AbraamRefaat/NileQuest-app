import 'package:flutter/material.dart';
import '../../constants/categories.dart';
import '../../models/poi.dart';
import '../../services/nearby_discoveries_service.dart';
import '../../services/vector_search_service.dart';
import '../../theme.dart';
import '../common/empty_state.dart';
import '../common/error_state.dart';
import '../common/loading_state.dart';

/// Bottom sheet for adding a stop to an itinerary day.
///
/// Two sources: semantic Search against the recommendation model's POI
/// dataset, and Nearby places around the day's last stop. Pops with the
/// chosen place synthesized into a [Poi], or null when dismissed.
class AddStopSheet extends StatefulWidget {
  /// Anchor for the Nearby tab; tab is hidden when null.
  final double? anchorLat;
  final double? anchorLon;

  const AddStopSheet({super.key, this.anchorLat, this.anchorLon});

  @override
  State<AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<AddStopSheet> {
  final TextEditingController _searchController = TextEditingController();

  int _tab = 0; // 0 = search, 1 = nearby
  bool get _hasNearby => widget.anchorLat != null && widget.anchorLon != null;

  // Search tab state
  bool _searching = false;
  String? _searchError;
  List<VectorSearchResult>? _searchResults;

  // Nearby tab state
  bool _loadingNearby = false;
  String? _nearbyError;
  List<NearbyDiscovery>? _nearbyResults;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final response = await VectorSearchService.search(query, topK: 10);
      if (!mounted) return;
      setState(() {
        _searchResults =
            response.places.where((p) => p.hasCoordinates).toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Search failed — check your connection and try again.';
        _searching = false;
      });
    }
  }

  Future<void> _loadNearby() async {
    if (!_hasNearby || _loadingNearby || _nearbyResults != null) return;
    setState(() {
      _loadingNearby = true;
      _nearbyError = null;
    });
    final results = await NearbyDiscoveriesService().findNearbyAttractions(
      lat: widget.anchorLat!,
      lng: widget.anchorLon!,
      radiusMeters: 2000,
    );
    if (!mounted) return;
    setState(() {
      _nearbyResults = results;
      _loadingNearby = false;
      if (results.isEmpty) {
        _nearbyError = null; // empty is a valid result, not an error
      }
    });
  }

  Poi _poiFromSearchResult(VectorSearchResult result) {
    return Poi(
      id: 'vs_${result.name.hashCode}',
      name: result.name,
      lat: result.lat,
      lon: result.lon,
      category: result.category,
      subcategory: '',
      durationHours: defaultDurationHoursFor(result.category),
      cost: 0,
      openingHours: '00:00 - 24:00',
      indoorOutdoor: 'Indoor/Outdoor',
      description: result.description,
      score: result.score ?? 0,
      photoUrl: result.photoUrl,
    );
  }

  Poi _poiFromNearby(NearbyDiscovery discovery) {
    return Poi(
      id: discovery.id,
      name: discovery.name,
      lat: discovery.lat,
      lon: discovery.lng,
      category: discovery.category,
      subcategory: '',
      durationHours: defaultDurationHoursFor(discovery.category),
      cost: 0,
      openingHours: '00:00 - 24:00',
      indoorOutdoor: 'Indoor/Outdoor',
      description: discovery.address ?? '',
      score: (discovery.rating ?? 0) / 5.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text('Add a stop', style: AppTextStyles.sectionTitle),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.charcoal),
                ),
              ],
            ),
          ),
          if (_hasNearby)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _tabButton('Search', 0, Icons.auto_awesome_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  _tabButton('Nearby', 1, Icons.near_me_rounded),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _tab == 0 ? _buildSearchTab() : _buildNearbyTab(),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 1) _loadNearby();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.charcoal),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.chipLabel.copyWith(
                  color: selected ? Colors.white : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'e.g. quiet places with ancient art',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary),
                onPressed: _runSearch,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const LoadingState(message: 'Searching places…');
    }
    if (_searchError != null) {
      return ErrorState(message: _searchError!, onRetry: _runSearch);
    }
    if (_searchResults == null) {
      return const EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Describe what you want to see',
        subtitle:
            'AI search finds places matching your words — try "local food markets" or "pharaonic temples".',
      );
    }
    if (_searchResults!.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No places found',
        subtitle: 'Try different words.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final result = _searchResults![index];
        final style = categoryStyleFor(result.category);
        return _placeTile(
          name: result.name,
          category: result.category,
          subtitle: result.description,
          style: style,
          onTap: () => Navigator.pop(context, _poiFromSearchResult(result)),
        );
      },
    );
  }

  Widget _buildNearbyTab() {
    if (_loadingNearby) {
      return const LoadingState(message: 'Finding places nearby…');
    }
    if (_nearbyError != null) {
      return ErrorState(message: _nearbyError!, onRetry: () {
        _nearbyResults = null;
        _loadNearby();
      });
    }
    if (_nearbyResults == null) {
      // First open — trigger load.
      _loadNearby();
      return const LoadingState(message: 'Finding places nearby…');
    }
    if (_nearbyResults!.isEmpty) {
      return const EmptyState(
        icon: Icons.near_me_disabled_rounded,
        title: 'Nothing found nearby',
        subtitle: 'Try the Search tab instead.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: _nearbyResults!.length,
      itemBuilder: (context, index) {
        final discovery = _nearbyResults![index];
        final style = categoryStyleFor(discovery.category);
        final distanceLabel = discovery.distance < 1
            ? '${(discovery.distance * 1000).round()} m away'
            : '${discovery.distance.toStringAsFixed(1)} km away';
        return _placeTile(
          name: discovery.name,
          category: discovery.category,
          subtitle: discovery.rating != null
              ? '$distanceLabel · ★ ${discovery.rating!.toStringAsFixed(1)}'
              : distanceLabel,
          style: style,
          onTap: () => Navigator.pop(context, _poiFromNearby(discovery)),
        );
      },
    );
  }

  Widget _placeTile({
    required String name,
    required String category,
    required String subtitle,
    required CategoryStyle style,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.add_circle_rounded,
                color: AppColors.primary, size: 26),
          ],
        ),
      ),
    );
  }
}
