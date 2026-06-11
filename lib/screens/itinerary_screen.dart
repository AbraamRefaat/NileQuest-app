import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import '../models/itinerary_event.dart';
import '../services/google_places_photo_service.dart';
import '../services/trip_storage_service.dart';
import '../services/auth_service.dart';

class ItineraryScreen extends StatefulWidget {
  final Itinerary? itinerary;
  final UserPreferences? preferences;
  final Function(int) onPlaceClick;
  final bool isHistoryView;
  final bool isEmbedded;

  const ItineraryScreen({
    super.key,
    this.itinerary,
    this.preferences,
    required this.onPlaceClick,
    this.isHistoryView = false,
    this.isEmbedded = false,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final GooglePlacesPhotoService _photoService = GooglePlacesPhotoService();
  final TripStorageService _tripStorageService = TripStorageService();
  final Map<String, String?> _photoCache = {};
  final ScrollController _scrollController = ScrollController();
  bool _isAutoSaving = false;
  bool _hasAutoSaved = false;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isHistoryView) {
      _saveTripAutomatically();
    } else {
      print('📜 [ItineraryScreen] Day History view detected. Auto-saving disabled.');
    }
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

  @override
  Widget build(BuildContext context) {
    // Show placeholder if no data
    if (widget.itinerary == null || widget.preferences == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No itinerary generated yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalDays = widget.itinerary!.totalDays;
    final budgetTier = widget.preferences!.budgetTier ?? 'moderate';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Enhanced Header with gradient - as a Sliver
          if (!widget.isEmbedded)
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      Color(0xFF2A6678),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'YOUR TRIP',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.secondary,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${widget.preferences!.city ?? 'Cairo'} Adventure',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 26,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$totalDays Days',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 14,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getBudgetLabel(budgetTier),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.preferences?.interests != null && widget.preferences!.interests.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: widget.preferences!.interests.map((interest) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.add_circle_outline_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              interest,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, widget.isEmbedded ? 120 : 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  int currentIndex = index;

                  // 1. Optional Summary Card (only if embedded)
                  if (widget.isEmbedded) {
                    if (currentIndex == 0) {
                      return _TripSummaryCard(itinerary: widget.itinerary!);
                    }
                    currentIndex--;
                  }

                  // ── Interest-search result card (step 6 response) ──
                  if (widget.itinerary!.interestSearch != null) {
                    if (currentIndex == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _InterestSearchCard(
                          data: widget.itinerary!.interestSearch!,
                        ),
                      );
                    }
                    // Shift day index by 1 from the remaining index
                    final dayNumber = currentIndex; // currentIndex 1 → day 1, etc.
                    final dayEvents = widget.itinerary!.days[dayNumber] ?? [];
                    if (dayEvents.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: DayCard(
                        day: dayNumber,
                        events: dayEvents,
                        isOpen: currentIndex == 1,
                        onPlaceClick: () => widget.onPlaceClick(dayNumber),
                        photoService: _photoService,
                        photoCache: _photoCache,
                      ),
                    );
                  }

                  // ── Normal day cards (no interest-search) ──
                  final dayNumber = currentIndex + 1;
                  final dayEvents = widget.itinerary!.days[dayNumber] ?? [];

                  if (dayEvents.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DayCard(
                      day: dayNumber,
                      events: dayEvents,
                      isOpen: currentIndex == 0,
                      onPlaceClick: () => widget.onPlaceClick(dayNumber),
                      photoService: _photoService,
                      photoCache: _photoCache,
                    ),
                  );
                },
                childCount: totalDays +
                    (widget.itinerary!.interestSearch != null ? 1 : 0) +
                    (widget.isEmbedded ? 1 : 0),
              ),
            ),
          ),
        ],
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

  /// Pre-fetch photos for all POIs in the itinerary to ensure they are available for saving
  Future<void> _preFetchAllPhotos() async {
    if (widget.itinerary == null) return;
    
    print('📸 [ItineraryScreen] Pre-fetching photos for all POIs...');
    
    final allPois = <Map<String, dynamic>>[];
    widget.itinerary!.days.forEach((_, events) {
      for (var event in events) {
        allPois.add({
          'name': event.poi.name,
          'lat': event.poi.lat,
          'lon': event.poi.lon,
        });
      }
    });

    if (allPois.isEmpty) return;

    // Fetch photos in parallel
    await Future.wait(allPois.map((poiData) async {
      final name = poiData['name'] as String;
      final lat = poiData['lat'] as double;
      final lon = poiData['lon'] as double;
      
      final cacheKey = '${name}_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
      
      if (!_photoCache.containsKey(cacheKey)) {
        final url = await _photoService.getPlacePhotoUrl(name, lat, lon);
        if (url != null) {
          _photoCache[cacheKey] = url;
          print('📸 [ItineraryScreen] Pre-fetched photo for: $name');
        }
      }
    }));
    
    print('✅ [ItineraryScreen] All ${allPois.length} photos pre-fetched or cached.');
  }

  Future<void> _saveTripAutomatically() async {
    if (_hasAutoSaved || widget.itinerary == null || widget.preferences == null) return;

    // Check if user is guest - don't autosave for guests (they can't anyway)
    final authService = AuthService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      print('ℹ️ [ItineraryScreen] Saving skipped: User is a Guest.');
      return;
    }

    print('🚀 [ItineraryScreen] Starting automatic trip save for user: ${currentUser.uid}');

    setState(() {
      _isAutoSaving = true;
    });

    try {
      // 1. Pre-fetch all photos first to ensure we have URLs for the database
      await _preFetchAllPhotos();

      // 2. Generate a professional default title
      final String city = widget.preferences!.city ?? 'Cairo';
      final String date = DateTime.now().toString().split(' ')[0];
      final String title = '$city Adventure ($date)';

      // 3. Populate metadata from preferences
      widget.itinerary!.interests.clear();
      widget.itinerary!.interests.addAll(widget.preferences!.interests);

      // 4. Perform save with the populated photo cache
      final success = await _tripStorageService.saveTrip(
        widget.itinerary!, 
        title, 
        _photoCache
      );

      if (success) {
        _hasAutoSaved = true;
        print('✅ Trip autosaved successfully: $title');
      }
    } catch (e) {
      print('❌ Error in autosave: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
      }
    }
  }

  String _getBudgetLabel(String tier) {
    switch (tier) {
      case 'budget':
        return 'Budget';
      case 'moderate':
        return 'Moderate';
      case 'luxury':
        return 'Luxury';
      default:
        return 'Moderate';
    }
  }
}

class DayCard extends StatefulWidget {
  final int day;
  final List<ItineraryEvent> events;
  final bool isOpen;
  final VoidCallback onPlaceClick;
  final GooglePlacesPhotoService photoService;
  final Map<String, String?> photoCache;

  const DayCard({
    super.key,
    required this.day,
    required this.events,
    this.isOpen = false,
    required this.onPlaceClick,
    required this.photoService,
    required this.photoCache,
  });

  @override
  State<DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<DayCard> with AutomaticKeepAliveClientMixin {
  late bool _expanded;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isOpen;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);


    String title = 'Day ${widget.day}';
    if (widget.events.isNotEmpty) {
      final firstPlace = widget.events.first.poi.name;
      if (widget.events.length == 1) {
        title = firstPlace;
      } else {
        title = '$firstPlace & more';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            Color(0xFF2A6678),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'DAY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${widget.day}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.place_rounded,
                                      size: 12,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.events.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _expanded 
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: widget.events.asMap().entries.map((entry) {
                  final index = entry.key;
                  final event = entry.value;
                  final isLast = index == widget.events.length - 1;
                  
                  return _ActivityItem(
                    event: event,
                    onClick: widget.onPlaceClick,
                    photoService: widget.photoService,
                    photoCache: widget.photoCache,
                    isLast: isLast,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatefulWidget {
  final ItineraryEvent event;
  final VoidCallback? onClick;
  final GooglePlacesPhotoService photoService;
  final Map<String, String?> photoCache;
  final bool isLast;

  const _ActivityItem({
    required this.event,
    this.onClick,
    required this.photoService,
    required this.photoCache,
    this.isLast = false,
  });

  @override
  State<_ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<_ActivityItem> {
  String? _photoUrl;
  bool _isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final poi = widget.event.poi;
    final cacheKey = '${poi.name}_${poi.lat.toStringAsFixed(5)}_${poi.lon.toStringAsFixed(5)}';

    if (widget.photoCache.containsKey(cacheKey)) {
      setState(() {
        _photoUrl = widget.photoCache[cacheKey];
      });
      return;
    }

    setState(() {
      _isLoadingPhoto = true;
    });

    final photoUrl = await widget.photoService.getPlacePhotoUrl(
      poi.name,
      poi.lat,
      poi.lon,
    );

    if (mounted) {
      setState(() {
        _photoUrl = photoUrl;
        _isLoadingPhoto = false;
        widget.photoCache[cacheKey] = photoUrl;
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('history') || cat.contains('museum')) return Icons.account_balance_rounded;
    if (cat.contains('food')) return Icons.restaurant_rounded;
    if (cat.contains('nature')) return Icons.park_rounded;
    if (cat.contains('shopping')) return Icons.shopping_bag_rounded;
    if (cat.contains('entertainment')) return Icons.theater_comedy_rounded;
    if (cat.contains('religious')) return Icons.mosque_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.event.poi;
    
    return Column(
      children: [
        GestureDetector(
          onTap: widget.onClick,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      child: Container(
                        width: 120,
                        height: 140,
                        color: Colors.grey[200],
                        child: _photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primary.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.3),
                                        AppColors.secondary.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(poi.category),
                                    size: 40,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            : _isLoadingPhoto
                                ? Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primary.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.3),
                                          AppColors.secondary.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(poi.category),
                                      size: 40,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                      ),
                    ),
                    
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.event.startTime,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              poi.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.charcoal,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 12,
                                  color: AppColors.charcoal.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    poi.subcategory,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.charcoal.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${poi.durationHours.toStringAsFixed(1)}h',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 12,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        poi.priceDisplay,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 58),
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.3),
                        AppColors.accent.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Interest Search Result Card ──────────────────────────────────────────────

class _InterestSearchCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _InterestSearchCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final query = data['query'] as String? ?? '';
    final places = (data['places'] as List<dynamic>? ?? []);
    final recommendation = data['recommendation'] as String?;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFF2A6678),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR SPECIFIC REQUEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"$query"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Matching places chips
            if (places.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Matching places found',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: places.take(6).map((p) {
                  final name =
                      (p as Map<String, dynamic>)['Name'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Gemini recommendation text
            if (recommendation != null && recommendation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Trip Summary Card (Header for Embedded View) ──────────────────────────────

class _TripSummaryCard extends StatelessWidget {
  final Itinerary itinerary;

  const _TripSummaryCard({required this.itinerary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (itinerary.interests.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: itinerary.interests.map((interest) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cream.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(Icons.calendar_today_outlined, '${itinerary.totalDays} Days'),
              _buildStat(Icons.place_outlined, '${itinerary.totalPois} Places'),
            ],
          ),
        ],
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

