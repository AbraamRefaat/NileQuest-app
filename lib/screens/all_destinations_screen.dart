import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/tourist_attraction.dart';
import '../services/places_service.dart';
import '../widgets/cards/destination_card.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/category_chips.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/error_state.dart';
import 'place_detail_screen.dart';

/// Full, scrollable list of Egypt's tourist attractions pulled live from
/// Google Places, ranked by popularity and filterable by city. Opened from
/// the home screen's "Popular Destinations → See All".
class AllDestinationsScreen extends StatefulWidget {
  const AllDestinationsScreen({super.key});

  @override
  State<AllDestinationsScreen> createState() => _AllDestinationsScreenState();
}

class _AllDestinationsScreenState extends State<AllDestinationsScreen> {
  final PlacesService _placesService = PlacesService();
  List<TouristAttraction> _attractions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedCity = 'All';

  @override
  void initState() {
    super.initState();
    _loadAttractions();
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final attractions = await _placesService.fetchAllAttractions();
      // Rank by popularity (rating × log reviews); best first.
      attractions.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      setState(() {
        _attractions = attractions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  List<String> get _cities =>
      ['All', ...{for (final a in _attractions) if (a.city.isNotEmpty) a.city}];

  List<TouristAttraction> get _filtered => _selectedCity == 'All'
      ? _attractions
      : _attractions.where((a) => a.city == _selectedCity).toList();

  void _openDetail(TouristAttraction attraction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          event: attraction.toItineraryEvent(),
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: const Center(child: AppBackButton.onDark()),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Destinations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!_isLoading && !_hasError && _attractions.isNotEmpty)
                    Text(
                      '${_attractions.length} places to explore',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -30,
                    top: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -30,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_hasError)
            SliverFillRemaining(
              child: ErrorState(
                message: 'Could not load destinations.\nCheck your connection.',
                onRetry: _loadAttractions,
              ),
            )
          else if (_attractions.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.explore_off_rounded,
                title: 'No destinations available',
              ),
            )
          else ...[
            if (_cities.length > 2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: CategoryChips(
                    categories: _cities,
                    selected: _selectedCity,
                    onSelected: (city) =>
                        setState(() => _selectedCity = city),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                24,
                AppSpacing.md,
                24,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final attraction = _filtered[index];
                    return DestinationCard(
                      width: double.infinity,
                      margin: EdgeInsets.zero,
                      destination: destinationCardData(
                        attraction,
                        imageUrl: attraction.photoReference != null
                            ? _placesService
                                .getPhotoUrl(attraction.photoReference!)
                            : null,
                      ),
                      onTap: () => _openDetail(attraction),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
