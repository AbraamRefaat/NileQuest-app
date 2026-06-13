import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/event.dart';
import '../models/tourist_attraction.dart';
import '../services/tazkarti_service.dart';
import '../services/places_service.dart';
import '../widgets/location_chip.dart';
import '../widgets/cards/event_card.dart';
import '../widgets/cards/destination_card.dart';
import '../widgets/common/category_chips.dart';
import 'all_events_screen.dart';
import 'all_destinations_screen.dart';
import 'place_detail_screen.dart';
import 'who_am_i_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGenerateTrip;
  final bool isGuest;

  const HomeScreen({
    super.key,
    required this.onGenerateTrip,
    this.isGuest = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TazkartiService _tazkartiService = TazkartiService();
  final PlacesService _placesService = PlacesService();
  List<Event> _upcomingEvents = [];
  bool _isLoadingEvents = true;
  String _selectedEventCategory = 'All';
  List<TouristAttraction> _popularDestinations = [];
  bool _isLoadingDestinations = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadEvents();
    _loadDestinations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _tazkartiService.fetchMusicEvents();
      setState(() {
        _upcomingEvents = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final attractions = await _placesService.fetchAllAttractions();
      // Keep only rated places, rank by popularity, show the top handful.
      final ranked = attractions.where((a) => a.rating != null).toList()
        ..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      setState(() {
        _popularDestinations = ranked.take(10).toList();
        _isLoadingDestinations = false;
      });
    } catch (e) {
      print('Error loading destinations: $e');
      setState(() {
        _isLoadingDestinations = false;
      });
    }
  }

  void _openDestination(TouristAttraction attraction) {
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

  List<String> get _eventCategories =>
      ['All', ...{for (final e in _upcomingEvents) e.category ?? 'Other'}];

  List<Event> get _filteredEvents => _selectedEventCategory == 'All'
      ? _upcomingEvents
      : _upcomingEvents
          .where((e) => (e.category ?? 'Other') == _selectedEventCategory)
          .toList();

  Future<void> _openEventUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open event page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Explore Egypt',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const LocationChip(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover your perfect journey',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),

              // AI Recommendations Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: widget.onGenerateTrip,
                  child: Stack(
                    children: [
                      // Main card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.isGuest
                                  ? AppColors.primary.withValues(alpha: 0.75)
                                  : AppColors.primary,
                              widget.isGuest
                                  ? AppColors.primaryLight.withValues(alpha: 0.75)
                                  : AppColors.primaryLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Decorative circle accent
                            Positioned(
                              right: -20,
                              top: -20,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.secondary.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 30,
                              bottom: -30,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppColors.secondary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'AI Recommendations',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.isGuest
                                              ? 'Sign in to unlock'
                                              : 'Personalized for You',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Arrow or Lock icon
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: widget.isGuest
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : AppColors.secondary,
                                      shape: BoxShape.circle,
                                      boxShadow: widget.isGuest
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: AppColors.secondary
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Icon(
                                      widget.isGuest
                                          ? Icons.lock_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: widget.isGuest
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Guest badge chip overlay
                      if (widget.isGuest)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.lock_rounded,
                                    size: 11, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Sign in required',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),


              const SizedBox(height: 32),

              // Popular Destinations Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popular Destinations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (!_isLoadingDestinations &&
                        _popularDestinations.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllDestinationsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Popular Destinations List
              _isLoadingDestinations
                  ? const SizedBox(
                      height: 280,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _popularDestinations.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 40,
                          ),
                          child: Center(
                            child: Text('No destinations available'),
                          ),
                        )
                      : SizedBox(
                          height: 280,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _popularDestinations.length,
                            itemBuilder: (context, index) {
                              final attraction = _popularDestinations[index];
                              return DestinationCard(
                                destination: destinationCardData(
                                  attraction,
                                  imageUrl: attraction.photoReference != null
                                      ? _placesService.getPhotoUrl(
                                          attraction.photoReference!)
                                      : null,
                                ),
                                onTap: () => _openDestination(attraction),
                              );
                            },
                          ),
                        ),

              const SizedBox(height: 40),

              // Upcoming Events Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Events',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (!_isLoadingEvents && _upcomingEvents.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllEventsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category filter (hidden when all events share one category)
              if (!_isLoadingEvents && _eventCategories.length > 2) ...[
                CategoryChips(
                  categories: _eventCategories,
                  selected: _selectedEventCategory,
                  onSelected: (category) =>
                      setState(() => _selectedEventCategory = category),
                ),
                const SizedBox(height: 16),
              ],

              // Upcoming Events List (limited to 4)
              _isLoadingEvents
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _filteredEvents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              _upcomingEvents.isEmpty
                                  ? 'No upcoming events available'
                                  : 'No events in this category',
                              style: TextStyle(
                                color:
                                    AppColors.charcoal.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              ..._filteredEvents.take(4).map((event) {
                                return EventCard(
                                  event: event,
                                  onTap: () => _openEventUrl(event.eventUrl),
                                );
                              }),
                              // "View more" footer pill if there are more than 4
                              if (_filteredEvents.length > 4)
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AllEventsScreen(),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'View ${_filteredEvents.length - 4} more events',
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 15,
                                        color: AppColors.accent,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 72,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90, right: 8),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3 * _pulseAnim.value),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, anim, __) => const WhoAmIScreen(),
                        transitionsBuilder: (_, anim, __, child) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(
                                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                        ),
                        transitionDuration: const Duration(milliseconds: 450),
                      ),
                    );
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  highlightElevation: 0,
                  shape: const CircleBorder(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_enhance_rounded,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}



