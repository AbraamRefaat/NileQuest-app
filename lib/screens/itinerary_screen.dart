import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../constants/categories.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import '../models/itinerary_event.dart';
import '../models/poi.dart';
import '../services/google_places_photo_service.dart';
import '../services/trip_storage_service.dart';
import '../services/trip_title_generator.dart';
import '../services/auth_service.dart';
import '../services/itinerary_editor.dart';
import '../services/trip_session_service.dart';
import '../widgets/sheets/add_stop_sheet.dart';

class ItineraryScreen extends StatefulWidget {
  final Itinerary? itinerary;
  final UserPreferences? preferences;
  final Function(int day, int placeIndex) onPlaceClick;
  final bool isHistoryView;
  final bool isEmbedded;

  /// Backend id of the already-saved copy of this trip (null = not saved
  /// yet). When set, auto-save is skipped and edits update that document.
  final String? tripBackendId;

  /// Enables edit mode. Called with the updated itinerary after every edit
  /// so the owner (main.dart) can propagate it to the map screen.
  final ValueChanged<Itinerary>? onItineraryChanged;

  /// Reports the backend id after a successful save (auto-save or edit save).
  final ValueChanged<String>? onTripSaved;

  /// Title to save under; defaults to "<city> Adventure (<date>)".
  final String? tripTitle;

  const ItineraryScreen({
    super.key,
    this.itinerary,
    this.preferences,
    required this.onPlaceClick,
    this.isHistoryView = false,
    this.isEmbedded = false,
    this.tripBackendId,
    this.onItineraryChanged,
    this.onTripSaved,
    this.tripTitle,
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

  // Editing state: _working is the local copy all edits apply to.
  Itinerary? _working;
  bool _isEditing = false;
  bool _isDirty = false;
  bool _isSavingEdits = false;
  String? _backendId;

  bool get _canEdit => widget.onItineraryChanged != null && _working != null;

  @override
  void initState() {
    super.initState();
    _working = widget.itinerary;
    _backendId = widget.tripBackendId;
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
  void didUpdateWidget(covariant ItineraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt a new itinerary instance (e.g. a history trip was opened), but
    // not the echo of our own edit coming back from the parent.
    if (!identical(widget.itinerary, _working)) {
      _working = widget.itinerary;
      _isEditing = false;
      _isDirty = false;
    }
    if (widget.tripBackendId != oldWidget.tripBackendId &&
        widget.tripBackendId != null) {
      _backendId = widget.tripBackendId;
    }
  }

  @override
  void deactivate() {
    // Screen is being torn down (tab switch recreates it) — don't lose edits.
    if (_isDirty && !_isSavingEdits) {
      _persistEdits(showFeedback: false);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────── editing ──────────────────────────────

  void _applyEdit(Itinerary updated) {
    setState(() {
      _working = updated;
      _isDirty = true;
    });
    widget.onItineraryChanged?.call(updated);
  }

  /// Blocks edits to a day that is currently being walked as a live trip.
  bool _canEditDay(int day) {
    final sessionService = TripSessionService();
    if (sessionService.hasActiveTrip && sessionService.session!.day == day) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish your live trip before editing this day'),
          backgroundColor: AppColors.charcoal,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _toggleEditing() async {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      return;
    }
    setState(() => _isEditing = false);
    await _persistEdits();
  }

  String get _saveTitle {
    if (widget.tripTitle != null) return widget.tripTitle!;
    if (_working != null) {
      return TripTitleGenerator.generate(_working!, widget.preferences);
    }
    return '${widget.preferences?.city ?? 'Egypt'} Adventure';
  }

  Future<void> _persistEdits({bool showFeedback = true}) async {
    if (!_isDirty || _working == null || _isSavingEdits) return;

    if (AuthService().currentUser == null) {
      // Guests keep their in-memory edits; nothing to sync.
      _isDirty = false;
      return;
    }

    _isSavingEdits = true;
    try {
      await _preFetchAllPhotos();
      final id = await _tripStorageService.updateTrip(
        (_backendId?.isEmpty ?? true) ? null : _backendId,
        _working!,
        _saveTitle,
        _photoCache,
      );
      if (id != null) {
        _isDirty = false;
        if (id.isNotEmpty) {
          _backendId = id;
          widget.onTripSaved?.call(id);
        }
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip updated'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip not synced — will retry when you edit again'),
            backgroundColor: AppColors.charcoal,
          ),
        );
      }
    } catch (e) {
      print('❌ [ItineraryScreen] Error saving edits: $e');
    } finally {
      _isSavingEdits = false;
    }
  }

  Future<void> _openAddStopSheet(int day) async {
    if (!_canEditDay(day)) return;

    // Anchor nearby search at the day's last stop, falling back to the
    // trip's first stop anywhere.
    Poi? anchor;
    final dayEvents = _working!.days[day];
    if (dayEvents != null && dayEvents.isNotEmpty) {
      anchor = dayEvents.last.poi;
    } else {
      for (final d in _working!.sortedDays) {
        final events = _working!.days[d];
        if (events != null && events.isNotEmpty) {
          anchor = events.first.poi;
          break;
        }
      }
    }

    final poi = await showModalBottomSheet<Poi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddStopSheet(
        anchorLat: anchor?.lat,
        anchorLon: anchor?.lon,
      ),
    );

    if (poi != null && mounted) {
      _applyEdit(ItineraryEditor.addStop(_working!, day, poi));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if no data
    if (_working == null || widget.preferences == null) {
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

    final itinerary = _working!;
    final totalDays = itinerary.totalDays;
    final budgetTier = widget.preferences!.budgetTier ?? 'moderate';
    final allDays = List<int>.generate(totalDays, (i) => i + 1);

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
                      AppColors.primaryLight,
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
                                    _saveTitle,
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
                      return _TripSummaryCard(itinerary: itinerary);
                    }
                    currentIndex--;
                  }

                  // ── Interest-search result card (step 6 response) ──
                  int dayNumber;
                  bool openByDefault;
                  if (itinerary.interestSearch != null) {
                    if (currentIndex == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _InterestSearchCard(
                          data: itinerary.interestSearch!,
                        ),
                      );
                    }
                    // Shift day index by 1 from the remaining index
                    dayNumber = currentIndex; // currentIndex 1 → day 1, etc.
                    openByDefault = currentIndex == 1;
                  } else {
                    dayNumber = currentIndex + 1;
                    openByDefault = currentIndex == 0;
                  }

                  final dayEvents = itinerary.days[dayNumber] ?? [];

                  // Empty days are hidden in view mode, but shown in edit
                  // mode so stops can be added or moved into them.
                  if (dayEvents.isEmpty && !_isEditing) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DayCard(
                      // Force a rebuild of the card's local expansion state
                      // when toggling edit mode.
                      key: ValueKey('day_${dayNumber}_$_isEditing'),
                      day: dayNumber,
                      events: dayEvents,
                      isOpen: openByDefault || _isEditing,
                      onPlaceClick: (placeIndex) => widget.onPlaceClick(dayNumber, placeIndex),
                      photoService: _photoService,
                      photoCache: _photoCache,
                      isEditing: _isEditing,
                      allDays: allDays,
                      onRemove: (index) {
                        if (_canEditDay(dayNumber)) {
                          _applyEdit(ItineraryEditor.removeStop(
                              _working!, dayNumber, index));
                        }
                      },
                      onReorder: (oldIndex, newIndex) {
                        if (_canEditDay(dayNumber)) {
                          _applyEdit(ItineraryEditor.reorderWithinDay(
                              _working!, dayNumber, oldIndex, newIndex));
                        }
                      },
                      onMoveToDay: (index, targetDay) {
                        if (_canEditDay(dayNumber) && _canEditDay(targetDay)) {
                          _applyEdit(ItineraryEditor.moveBetweenDays(
                              _working!, dayNumber, index, targetDay));
                        }
                      },
                      onAddStop: () => _openAddStopSheet(dayNumber),
                    ),
                  );
                },
                childCount: totalDays +
                    (itinerary.interestSearch != null ? 1 : 0) +
                    (widget.isEmbedded ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showBackToTop)
              FloatingActionButton(
                heroTag: 'itinerary_back_to_top',
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
            if (_canEdit) ...[
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'itinerary_edit_toggle',
                onPressed: _toggleEditing,
                backgroundColor:
                    _isEditing ? AppColors.success : AppColors.accent,
                icon: Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  _isEditing ? 'Done' : 'Edit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pre-fetch photos for all POIs in the itinerary to ensure they are available for saving
  Future<void> _preFetchAllPhotos() async {
    if (_working == null) return;

    print('📸 [ItineraryScreen] Pre-fetching photos for all POIs...');

    final allPois = <Map<String, dynamic>>[];
    _working!.days.forEach((_, events) {
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
    if (_hasAutoSaved || _working == null || widget.preferences == null) return;

    // Already saved in a previous mount of this screen (tab switches recreate
    // it) — without this check every Trip-tab visit POSTed a duplicate trip.
    if (widget.tripBackendId != null) {
      _hasAutoSaved = true;
      return;
    }

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

      // 2. Populate metadata from preferences
      _working!.interests.clear();
      _working!.interests.addAll(widget.preferences!.interests);

      // 3. Perform save with the populated photo cache
      final id = await _tripStorageService.saveTrip(
        _working!,
        _saveTitle,
        _photoCache,
      );

      if (id != null) {
        _hasAutoSaved = true;
        if (id.isNotEmpty) {
          _backendId = id;
          widget.onTripSaved?.call(id);
        }
        print('✅ Trip autosaved successfully: $_saveTitle');
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
  final void Function(int placeIndex) onPlaceClick;
  final GooglePlacesPhotoService photoService;
  final Map<String, String?> photoCache;

  // Edit mode (all no-ops when isEditing is false)
  final bool isEditing;
  final List<int> allDays;
  final void Function(int index)? onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(int index, int targetDay)? onMoveToDay;
  final VoidCallback? onAddStop;

  const DayCard({
    super.key,
    required this.day,
    required this.events,
    this.isOpen = false,
    required this.onPlaceClick,
    required this.photoService,
    required this.photoCache,
    this.isEditing = false,
    this.allDays = const [],
    this.onRemove,
    this.onReorder,
    this.onMoveToDay,
    this.onAddStop,
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
                            AppColors.primaryLight,
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
              child: widget.isEditing ? _buildEditBody() : _buildViewBody(),
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

  Widget _buildViewBody() {
    return Column(
      children: widget.events.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;
        final isLast = index == widget.events.length - 1;

        return _ActivityItem(
          event: event,
          onClick: () => widget.onPlaceClick(index),
          photoService: widget.photoService,
          photoCache: widget.photoCache,
          isLast: isLast,
        );
      }).toList(),
    );
  }

  Widget _buildEditBody() {
    final overloaded = ItineraryEditor.isDayOverloaded(widget.events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overloaded)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This day is overloaded — consider moving a stop to another day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No stops planned for this day yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: widget.events.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              widget.onReorder?.call(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final event = widget.events[index];
              return Row(
                key: ValueKey('stop_${event.poi.id}_$index'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.charcoal.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ActivityItem(
                      event: event,
                      photoService: widget.photoService,
                      photoCache: widget.photoCache,
                      isLast: index == widget.events.length - 1,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.charcoal.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        widget.onRemove?.call(index);
                      } else if (value.startsWith('move_')) {
                        final targetDay = int.parse(value.substring(5));
                        widget.onMoveToDay?.call(index, targetDay);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Remove'),
                          ],
                        ),
                      ),
                      ...widget.allDays
                          .where((d) => d != widget.day)
                          .map((d) => PopupMenuItem(
                                value: 'move_$d',
                                child: Row(
                                  children: [
                                    const Icon(Icons.low_priority_rounded,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text('Move to Day $d'),
                                  ],
                                ),
                              )),
                    ],
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onAddStop,
          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
          label: const Text('Add a stop'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
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

  IconData _getCategoryIcon(String category) => categoryStyleFor(category).icon;

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
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
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
            AppColors.primaryLight,
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

