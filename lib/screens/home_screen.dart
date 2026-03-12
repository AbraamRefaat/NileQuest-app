import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/event.dart';
import '../services/tazkarti_service.dart';
import '../widgets/location_chip.dart';
import 'all_events_screen.dart';
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
  List<Event> _upcomingEvents = [];
  bool _isLoadingEvents = true;
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
                                  ? const Color(0xFF2A6678).withValues(alpha: 0.75)
                                  : const Color(0xFF2A6678),
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
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to all destinations
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
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _popularDestinations.length,
                  itemBuilder: (context, index) {
                    final destination = _popularDestinations[index];
                    return _buildDestinationCard(destination);
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
                  : _upcomingEvents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No upcoming events available',
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
                              ..._upcomingEvents.take(4).map((event) {
                                return _buildEventCard(event);
                              }),
                              // "View more" footer pill if there are more than 4
                              if (_upcomingEvents.length > 4)
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
                                        'View ${_upcomingEvents.length - 4} more events',
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
                          Color(0xFF2A6678),
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

  Widget _buildDestinationCard(Map<String, dynamic> destination) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Stack(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      destination['image'] != null
                          ? Image.asset(
                              destination['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary
                                            .withValues(alpha: 0.7),
                                        AppColors.secondary
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.image_rounded,
                                    size: 60,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                );
                              },
                            )
                          : Container(
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
                            ),
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
                    destination['isFavorite']
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: destination['isFavorite']
                        ? Colors.red
                        : AppColors.charcoal.withValues(alpha: 0.6),
                    size: 20,
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
                      borderRadius: BorderRadius.circular(20),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Location
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  destination['location'],
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.charcoal.withValues(alpha: 0.6),
                  ),
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

  Widget _buildEventCard(Event event) {
    // Check if event is from Tazkarti (has eventUrl containing tazkarti.com)
    final isTazkartiEvent = event.eventUrl.contains('tazkarti.com');

    return GestureDetector(
      onTap: () => _openEventUrl(event.eventUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Container(
                width: 60,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.formattedMonth,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.formattedDay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.charcoal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.charcoal.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.charcoal.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.price != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Prices From: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.charcoal.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${event.price!.toInt()} EGP',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Tazkarti logo for Tazkarti events
                    if (isTazkartiEvent) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/Tazkarti_Logo.webp',
                            height: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // External link icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sample data for popular destinations
final List<Map<String, dynamic>> _popularDestinations = [
  {
    'name': 'Valley of the Kings',
    'location': 'Luxor, Egypt',
    'rating': 4.7,
    'reviews': '8930',
    'image': 'assets/images/cities/luxor.jpg',
    'isFavorite': false,
    'isPopular': true,
  },
  {
    'name': 'Great Pyramid of Giza',
    'location': 'Giza, Egypt',
    'rating': 4.9,
    'reviews': '15240',
    'image': 'assets/images/cities/cairo.jpg',
    'isFavorite': true,
    'isPopular': true,
  },
  {
    'name': 'Abu Simbel Temples',
    'location': 'Aswan, Egypt',
    'rating': 4.8,
    'reviews': '6720',
    'image': 'assets/images/cities/aswan.jpg',
    'isFavorite': false,
    'isPopular': false,
  },
  {
    'name': 'Karnak Temple',
    'location': 'Luxor, Egypt',
    'rating': 4.6,
    'reviews': '7850',
    'image': 'assets/images/cities/luxor.jpg',
    'isFavorite': false,
    'isPopular': false,
  },
];


