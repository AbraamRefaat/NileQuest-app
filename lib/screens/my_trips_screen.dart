import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import '../services/current_trip_service.dart';
import '../services/trip_storage_service.dart';
import 'itinerary_screen.dart';

class MyTripsScreen extends StatefulWidget {
  final Function(Itinerary, String?) OnViewTrip;
  final VoidCallback onBack;
  final bool isEmbedded;

  const MyTripsScreen({
    super.key,
    required this.OnViewTrip,
    required this.onBack,
    this.isEmbedded = false,
  });

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final TripStorageService _tripStorageService = TripStorageService();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Mongo `_id` of a fetched trip, tolerating both `{ $oid: ... }` and
  /// plain-string shapes.
  static String _tripId(Map<String, dynamic> trip) {
    final raw = trip['_id'];
    if (raw is Map) return raw[_mongoOid]?.toString() ?? raw.toString();
    return raw?.toString() ?? '';
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final trips = await _tripStorageService.getUserTrips();
      // The active trip is auto-saved to the backend the moment it's
      // generated — hide it here so it only shows up in history once the
      // user finishes (or completes) it.
      final activeId = await CurrentTripService().getBackendId();
      final visible = activeId == null
          ? trips
          : trips.where((t) => _tripId(t) != activeId).toList();
      if (mounted) {
        setState(() {
          _trips = visible;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  Future<void> _deleteTrip(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip memory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await _tripStorageService.deleteTrip(id);
      if (success && mounted) {
        _loadTrips();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting trip: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: widget.isEmbedded 
          ? null 
          : AppBar(
              title: const Text(
                'Trip history',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
                onPressed: widget.onBack,
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _trips.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    return _buildTripCard(trip);
                  },
                ),
      floatingActionButton: _showBackToTop
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: AppColors.primary,
                mini: true,
                child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.5,
            child: Image.network(
              'https://cdn-icons-png.flaticon.com/512/3126/3126027.png',
              width: 120,
              errorBuilder: (_, __, ___) => const Icon(Icons.map_outlined, size: 80, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No trips saved yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start generating recommendations\nto see your history here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> tripData) {
    final itineraryData = tripData['itinerary'];
    final String title = tripData['title'] ?? 'Generic Trip';
    
    // Safer ID extraction
    String id = '';
    if (tripData['_id'] is Map) {
      id = tripData['_id'][_mongoOid] ?? tripData['_id'].toString();
    } else {
      id = tripData['_id']?.toString() ?? 'no-id';
    }
    
    // Safer summary extraction for fallback
    Map? summary;
    if (itineraryData is Map) {
      summary = itineraryData['summary'] as Map?;
    }
    
    Itinerary? itinerary;
    try {
      if (itineraryData is Map<String, dynamic>) {
        itinerary = Itinerary.fromJson(itineraryData);
      } else if (itineraryData is Map) {
        itinerary = Itinerary.fromJson(Map<String, dynamic>.from(itineraryData));
      }
    } catch (e) {
      print('⚠️ [MyTripsScreen] Error parsing itinerary object for $title: $e');
    }

    // Extract a representative image from the first day
    String? imageUrl;
    if (itinerary != null && itinerary.days.isNotEmpty) {
      try {
        final sortedDays = itinerary.sortedDays;
        if (sortedDays.isNotEmpty) {
          final firstDayEvents = itinerary.days[sortedDays.first];
          if (firstDayEvents != null && firstDayEvents.isNotEmpty) {
            imageUrl = firstDayEvents.first.poi.photoUrl;
          }
        }
      } catch (e) {
        print('⚠️ [MyTripsScreen] Error finding preview image: $e');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final itinerary = Itinerary.fromJson(itineraryData);
              final backendId = (id.isEmpty || id == 'no-id') ? null : id;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    backgroundColor: AppColors.cream,
                    appBar: AppBar(
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: ItineraryScreen(
                      itinerary: itinerary,
                      preferences: UserPreferences(
                        city: title.split(' ').first,
                        durationDays: itinerary.totalDays,
                        interests: itinerary.interests,
                        pace: 'moderate',
                        budgetTier: 'moderate',
                      ),
                      isHistoryView: true,
                      isEmbedded: true,
                      onPlaceClick: (_, __) {},
                      // Saved trips can be edited; changes replace the same
                      // backend document.
                      tripBackendId: backendId,
                      onItineraryChanged: backendId != null ? (_) {} : null,
                      tripTitle: title,
                    ),
                  ),
                ),
              ).then((_) {
                // Refresh the list — the trip may have been edited (re-saved
                // under a new backend id).
                if (mounted) _loadTrips();
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Image Section
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.temple_hindu_rounded, color: Colors.white, size: 40),
                            ),
                      // Overlay gradient
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
                      // Title on Image
                      Positioned(
                        bottom: 15,
                        left: 20,
                        right: 20,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Delete Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          ),
                          onPressed: () => _deleteTrip(id),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (itinerary != null && itinerary.interests.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: itinerary.interests.map((interest) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.secondary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  interest,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (itinerary != null && itinerary.interestSearch != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 12, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Search: ${itinerary.interestSearch!['query'] ?? 'Specific Interest'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat(Icons.calendar_today_outlined, 
                              '${itinerary?.totalDays ?? summary?['total_days'] ?? 0} Days'),
                          _buildStat(Icons.place_outlined, 
                              '${itinerary?.totalPois ?? summary?['total_pois'] ?? 0} Places'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

// Helper to handle MongoDB ObjectId string format if it comes as a map or string
const String _mongoOid = '\$oid';
