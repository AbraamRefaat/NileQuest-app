import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import '../theme.dart';
import '../constants/categories.dart';
import '../models/tourist_attraction.dart';
import '../models/itinerary.dart';
import '../services/places_service.dart';
import '../services/itinerary_map_service.dart';
import '../services/nearby_discoveries_service.dart';
import '../services/audio_guide_service.dart';
import '../services/google_places_photo_service.dart';
import '../services/trip_session_service.dart';
import '../services/vector_search_service.dart';
import '../services/notification_service.dart';
import '../services/gamification_service.dart' as gam;
import '../models/trip_session.dart';
import '../widgets/modern_map_panels.dart';
import '../widgets/gamification/xp_snackbar.dart';
import '../widgets/sheets/stop_feedback_sheet.dart';
import '../widgets/sheets/trip_feedback_sheet.dart';
import 'stop_photo_screen.dart';
import 'trip_wrapped_screen.dart';

enum MapStyleKind { outdoors, streets, satellite, dark, light }

class _AttractionTapHandler extends OnPointAnnotationClickListener {
  _AttractionTapHandler(this.onTap);
  final void Function(PointAnnotation) onTap;

  @override
  void onPointAnnotationClick(PointAnnotation annotation) => onTap(annotation);
}

/// 🎨 FULLY FUNCTIONAL BEAUTIFUL MAP
/// Everything works perfectly for tourists!
class EnhancedMapScreenV2Functional extends StatefulWidget {
  final Itinerary? itinerary;
  final int? selectedDay;

  /// Called when the live trip session ends so the parent can clear the
  /// current trip and move it to history.
  final VoidCallback? onTripFinished;

  const EnhancedMapScreenV2Functional({
    super.key,
    this.itinerary,
    this.selectedDay,
    this.onTripFinished,
  });

  @override
  State<EnhancedMapScreenV2Functional> createState() => _EnhancedMapScreenV2FunctionalState();
}

class _EnhancedMapScreenV2FunctionalState extends State<EnhancedMapScreenV2Functional> 
    with TickerProviderStateMixin {
  // Map controllers
  MapboxMap? _mapboxMap;
  bool _isMapReady = false;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // Services
  final PlacesService _placesService = PlacesService();
  final ItineraryMapService _itineraryService = ItineraryMapService();
  final NearbyDiscoveriesService _nearbyService = NearbyDiscoveriesService();
  final AudioGuideService _audioService = AudioGuideService();
  final GooglePlacesPhotoService _photoService = GooglePlacesPhotoService();

  // Data
  List<TouristAttraction> _allAttractions = [];
  List<TouristAttraction> _filteredAttractions = [];
  List<ItineraryMapPoint> _itineraryPoints = [];
  List<NearbyDiscovery> _nearbyDiscoveries = [];
  final Map<String, TouristAttraction> _markerToAttraction = {};

  // State
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  Position? _userLocation;
  TouristAttraction? _selectedAttraction;
  
  // UI State
  bool _showSearchBar = false;
  String _searchQuery = '';
  MapPanelType? _activePanel;
  
  // Itinerary mode
  bool _isItineraryMode = false;
  int? _currentDay;

  // Trip session (live trip with photo stops)
  final TripSessionService _tripService = TripSessionService();
  final Map<String, int> _markerToStopIndex = {};

  // Vector (AI semantic) search
  final Map<String, VectorSearchResult> _markerToVectorResult = {};
  List<VectorSearchResult> _vectorResults = [];
  String? _aiRecommendation;
  bool _isVectorSearching = false;

  // Style + view
  MapStyleKind _styleKind = MapStyleKind.outdoors;
  bool _is3D = false;
  bool _showStyleMenu = false;
  String? _selectedPhotoUrl;
  bool _isLoadingSelectedPhoto = false;
  Timer? _searchDebounce;
  
  // Animation controllers
  late AnimationController _fabController;
  late AnimationController _searchController;
  late AnimationController _panelController;
  late Animation<double> _fabAnimation;
  late Animation<double> _searchAnimation;
  late Animation<Offset> _panelSlideAnimation;

  // Search focus
  final TextEditingController _searchTextController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAttractions();
    _getUserLocation();
    
    if (widget.itinerary != null) {
      _isItineraryMode = true;
      _currentDay = widget.selectedDay ?? 1;
      _loadItineraryPoints();
    }

    // Trip session: restore any in-progress trip + wire arrival callback
    _tripService.restore();
    _tripService.addListener(_onTripChanged);
    _tripService.onStopArrival = (stopIndex) {
      if (mounted) _openStopCamera(stopIndex);
    };
    NotificationService().onNotificationTap = (payload) {
      if (!mounted) return;
      final idx = int.tryParse(payload);
      if (idx != null) _openStopCamera(idx);
    };

    // Listen to search changes (debounced)
    _searchTextController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _searchQuery = _searchTextController.text;
        });
        _filterAttractions();
      });
    });
  }

  void _initAnimations() {
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );
    _fabController.forward();

    _searchController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchController,
      curve: Curves.easeOutCubic,
    );

    _panelController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _panelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _tripService.removeListener(_onTripChanged);
    _tripService.onStopArrival = null;
    _searchDebounce?.cancel();
    _fabController.dispose();
    _searchController.dispose();
    _panelController.dispose();
    _audioService.dispose();
    _searchTextController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final attractions = await _placesService.fetchAllAttractions();
      setState(() {
        _allAttractions = attractions;
        _filteredAttractions = attractions;
        _isLoading = false;
      });

      if (_mapboxMap != null) {
        await _addAttractionMarkers();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attractions';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItineraryPoints() async {
    if (widget.itinerary == null || _currentDay == null) return;

    final points = _itineraryService.getPointsForDay(widget.itinerary!, _currentDay!);
    setState(() {
      _itineraryPoints = points;
    });

    if (_mapboxMap != null) {
      await _addItineraryMarkers();
      await _drawItineraryRoute();
      
      final cameraOptions = _itineraryService.getCameraOptionsForPoints(points);
      await _mapboxMap?.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));
    }
  }

  Future<void> _getUserLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          return;
        }
      }

      final geoPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      setState(() {
        _userLocation = Position(geoPosition.longitude, geoPosition.latitude);
      });

      if (_mapboxMap != null && _userLocation != null && !_isItineraryMode) {
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: _userLocation!),
            zoom: 12.0,
          ),
          MapAnimationOptions(duration: 1500),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _filterAttractions() {
    List<TouristAttraction> filtered = _allAttractions;

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = _placesService.filterByCategory(filtered, _selectedCategory);
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((attraction) {
        return attraction.name.toLowerCase().contains(query) ||
               attraction.category.toLowerCase().contains(query) ||
               attraction.description.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredAttractions = filtered;
    });

    if (_mapboxMap != null) {
      _addAttractionMarkers().then((_) {
        // Auto-fit only when user is actively narrowing (category or text)
        if (_isMapReady &&
            (_selectedCategory != 'All' || _searchQuery.isNotEmpty) &&
            filtered.length >= 2) {
          _fitToFiltered();
        }
      });
    }
  }

  Future<void> _addAttractionMarkers() async {
    if (_pointAnnotationManager == null) return;

    // Clear existing markers
    await _pointAnnotationManager?.deleteAll();
    _markerToAttraction.clear();

    // Add markers for filtered attractions, colored by category
    for (var attraction in _filteredAttractions) {
      final point = Point(
        coordinates: Position(attraction.longitude, attraction.latitude),
      );

      final color = _getCategoryColor(attraction.category);
      final selected = _selectedAttraction?.id == attraction.id;

      final options = PointAnnotationOptions(
        geometry: point,
        iconImage: 'marker-15',
        iconSize: selected ? 2.2 : 1.6,
        iconColor: color.toARGB32(),
        symbolSortKey: selected ? 100.0 : (attraction.rating ?? 0).toDouble(),
      );

      final annotation = await _pointAnnotationManager?.create(options);
      if (annotation != null) {
        _markerToAttraction[annotation.id] = attraction;
      }
    }
  }

  Future<void> _addItineraryMarkers() async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager?.deleteAll();
    _markerToAttraction.clear();
    _markerToStopIndex.clear();

    final dayColor = _itineraryService.getColorForDay(_currentDay ?? 1);
    final session = _tripService.session;

    for (int i = 0; i < _itineraryPoints.length; i++) {
      final point = _itineraryPoints[i];
      final position = Point(coordinates: point.position);

      // Color by trip progress: green = done, orange = arrived, day color = upcoming
      Color markerColor = dayColor;
      String label = '${i + 1}';
      if (session != null && i < session.stops.length) {
        switch (session.stops[i].status) {
          case StopStatus.completed:
            markerColor = const Color(0xFF27AE60);
            label = '✓';
            break;
          case StopStatus.arrived:
            markerColor = const Color(0xFFE67E22);
            break;
          case StopStatus.upcoming:
            break;
        }
      }

      final options = PointAnnotationOptions(
        geometry: position,
        iconImage: 'marker-15',
        iconSize: 2.2,
        iconColor: markerColor.toARGB32(),
        textField: label,
        textSize: 13.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: markerColor.toARGB32(),
        textHaloWidth: 1.5,
        symbolSortKey: 100.0 - i,
      );

      final annotation = await _pointAnnotationManager?.create(options);
      if (annotation != null) {
        _markerToStopIndex[annotation.id] = i;
      }
    }
  }

  Future<void> _drawItineraryRoute() async {
    if (_polylineAnnotationManager == null || _itineraryPoints.isEmpty) return;

    await _polylineAnnotationManager?.deleteAll();

    final dayColor = _itineraryService.getColorForDay(_currentDay ?? 1);

    // Get route from directions service
    final route = await _itineraryService.getRouteForDay(
      widget.itinerary!,
      _currentDay!,
    );

    if (route.isNotEmpty) {
      // Soft outline under the main line for depth
      await _polylineAnnotationManager?.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: route),
        lineWidth: 8.0,
        lineColor: dayColor.withValues(alpha: 0.25).toARGB32(),
      ));
      await _polylineAnnotationManager?.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: route),
        lineWidth: 4.5,
        lineColor: dayColor.toARGB32(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ Map
          _buildMapWithOverlay(),

          // 🎨 Top Bar
          _buildModernTopBar(),

          // 🎯 Categories or Days
          if (!_isItineraryMode && !_isLoading)
            _buildFloatingCategories(),
          if (_isItineraryMode)
            _buildAnimatedDaySelector(),

          // 🔍 Search Bar
          _buildExpandableSearch(),

          // ⚡ Quick Actions
          _buildQuickActionButtons(),

          // 📊 Stats Card (hidden in itinerary mode — trip HUD takes its place)
          if (!_isLoading && _isMapReady && !_isItineraryMode)
            _buildStatsCard(),

          // 🎯 Map Controls
          _buildMapControls(),

          // 🚶 Trip HUD: Start Trip button / live progress
          if (_isItineraryMode && _isMapReady)
            _buildTripHud(),

          // 🤖 AI recommendation banner (after vector search)
          if (_aiRecommendation != null && _aiRecommendation!.isNotEmpty)
            _buildAiBanner(),

          // 🌟 Loading
          if (_isLoading || !_isMapReady)
            _buildBeautifulLoading(),

          // ❌ Error
          if (_errorMessage != null)
            _buildBlurredError(),

          // 📱 Panel
          if (_activePanel != null)
            _buildModernPanel(),

          // 📍 Selected Attraction Card
          if (_selectedAttraction != null)
            _buildAttractionCard(),
        ],
      ),
    );
  }

  Widget _buildMapWithOverlay() {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('functionalMapWidget'),
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(30.8025, 26.8206)),
            zoom: 6.0,
            pitch: 0.0,
          ),
          styleUri: MapboxStyles.OUTDOORS,
          textureView: true,
          onMapCreated: _onMapCreated,
          onTapListener: _onMapTapped,
        ),
        
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.03),
                  ],
                  stops: const [0.0, 0.1, 0.9, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _fabAnimation,
                  child: _buildGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isItineraryMode ? Icons.route_rounded : Icons.explore_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isItineraryMode 
                                    ? 'Your Journey'
                                    : 'Discover Egypt',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.charcoal,
                                  height: 1.2,
                                ),
                              ),
                              if (_isItineraryMode)
                                Text(
                                  'Day $_currentDay • ${_itineraryPoints.length} stops',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.charcoal.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                Text(
                                  '${_filteredAttractions.length} places',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.charcoal.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                ScaleTransition(
                  scale: _fabAnimation,
                  child: _buildGlassButton(
                    icon: Icons.search_rounded,
                    onPressed: () {
                      setState(() => _showSearchBar = !_showSearchBar);
                      if (_showSearchBar) {
                        _searchController.forward();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _searchFocusNode.requestFocus();
                        });
                      } else {
                        _searchController.reverse();
                        _searchTextController.clear();
                      }
                    },
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                ScaleTransition(
                  scale: _fabAnimation,
                  child: _buildGlassButton(
                    icon: Icons.ios_share_rounded,
                    onPressed: _shareLocation,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCategories() {
    final categories = [
      ('All', Icons.grid_view_rounded, AppColors.primary),
      ('Historical', Icons.account_balance_rounded, const Color(0xFFE67E22)),
      ('Museum', Icons.museum_rounded, const Color(0xFF9B59B6)),
      ('Religious', Icons.mosque_rounded, const Color(0xFF3498DB)),
      ('Natural', Icons.landscape_rounded, const Color(0xFF27AE60)),
      ('Beach Resort', Icons.beach_access_rounded, const Color(0xFF1ABC9C)),
      ('Shopping', Icons.shopping_bag_rounded, const Color(0xFFF39C12)),
    ];

    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 70,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final (name, icon, color) = categories[index];
            final isSelected = _selectedCategory == name;
            
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _buildModernCategoryChip(
                  name: name,
                  icon: icon,
                  color: color,
                  isSelected: isSelected,
                  onTap: () => _selectCategory(name),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernCategoryChip({
    required String name,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected 
                ? color.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 15 : 8,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.charcoal,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDaySelector() {
    if (widget.itinerary == null) return const SizedBox.shrink();
    
    final days = widget.itinerary!.sortedDays;
    
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final isSelected = _currentDay == day;
            final color = _itineraryService.getColorForDay(day);
            final events = widget.itinerary!.days[day]?.length ?? 0;
            
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _selectDay(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSelected ? 160 : 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.85),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? color.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                            ? color.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: isSelected ? 15 : 8,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Day $day',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$events stops',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected 
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.charcoal.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandableSearch() {
    return Positioned(
      top: 90,
      left: 16,
      right: 16,
      child: SizeTransition(
        sizeFactor: _searchAnimation,
        axisAlignment: -1.0,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchTextController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Try "quiet places with ancient art"...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runVectorSearch,
                ),
              ),
              // 🤖 AI semantic search — queries the model's vector dataset
              if (_isVectorSearching)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _runVectorSearch(_searchTextController.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E44AD), Color(0xFF5E2D79)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '🤖 AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchTextController.clear();
                    _clearVectorSearch();
                  },
                  child: Icon(
                    Icons.clear_rounded,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    final actions = [
      ('Layers', Icons.layers_rounded, MapPanelType.layers, AppColors.primary),
      ('Nearby', Icons.explore_rounded, MapPanelType.nearby, const Color(0xFF27AE60)),
      ('SOS', Icons.emergency_rounded, MapPanelType.emergency, const Color(0xFFE74C3C)),
      ('Offline', Icons.cloud_download_rounded, MapPanelType.offline, const Color(0xFF9B59B6)),
    ];

    return Positioned(
      right: 16,
      bottom: 140,
      child: Column(
        children: actions.map((action) {
          final (label, icon, type, color) = action;
          final isActive = _activePanel == type;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScaleTransition(
              scale: _fabAnimation,
              child: _buildQuickActionButton(
                label: label,
                icon: icon,
                color: color,
                isActive: isActive,
                onPressed: () => _togglePanel(type),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive 
                ? color.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive 
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isActive ? 15 : 10,
              offset: Offset(0, isActive ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : color,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.charcoal,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final count = _isItineraryMode 
        ? _itineraryPoints.length 
        : _filteredAttractions.length;
    final label = _isItineraryMode ? 'stops' : 'places';

    return Positioned(
      left: 16,
      bottom: 140,
      child: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    final whiteGradient = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.95),
        Colors.white.withValues(alpha: 0.85),
      ],
    );
    final accentGradient = LinearGradient(
      colors: [
        AppColors.primary.withValues(alpha: 0.18),
        AppColors.primary.withValues(alpha: 0.1),
      ],
    );
    return Positioned(
      right: 16,
      top: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildGlassButton(
            icon: Icons.add_rounded,
            onPressed: () => _zoomMap(true),
            gradient: whiteGradient,
          ),
          const SizedBox(height: 8),
          _buildGlassButton(
            icon: Icons.remove_rounded,
            onPressed: () => _zoomMap(false),
            gradient: whiteGradient,
          ),
          const SizedBox(height: 12),
          _buildGlassButton(
            icon: _is3D ? Icons.threed_rotation_rounded : Icons.threed_rotation_outlined,
            onPressed: _toggle3D,
            gradient: _is3D ? accentGradient : whiteGradient,
          ),
          const SizedBox(height: 8),
          _buildGlassButton(
            icon: Icons.layers_outlined,
            onPressed: () => setState(() => _showStyleMenu = !_showStyleMenu),
            gradient: _showStyleMenu ? accentGradient : whiteGradient,
          ),
          if (_showStyleMenu) ...[
            const SizedBox(height: 8),
            _buildStyleMenu(),
          ],
          const SizedBox(height: 12),
          _buildGlassButton(
            icon: Icons.fit_screen_rounded,
            onPressed: _fitToFiltered,
            gradient: whiteGradient,
          ),
          const SizedBox(height: 8),
          _buildGlassButton(
            icon: Icons.my_location_rounded,
            onPressed: _recenterMap,
            gradient: accentGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildStyleMenu() {
    final styles = <(String, IconData, MapStyleKind)>[
      ('Outdoors', Icons.terrain_rounded, MapStyleKind.outdoors),
      ('Streets', Icons.map_rounded, MapStyleKind.streets),
      ('Satellite', Icons.satellite_alt_rounded, MapStyleKind.satellite),
      ('Light', Icons.light_mode_rounded, MapStyleKind.light),
      ('Dark', Icons.dark_mode_rounded, MapStyleKind.dark),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: styles.map((s) {
          final (label, icon, kind) = s;
          final selected = _styleKind == kind;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _changeStyle(kind),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
    required LinearGradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeautifulLoading() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isLoading ? 'Discovering Egypt...' : 'Preparing your map...',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding the best places for you',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurredError() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAttractions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernPanel() {
    return SlideTransition(
      position: _panelSlideAnimation,
      child: ModernMapPanel(
        type: _activePanel!,
        onClose: () => _togglePanel(null),
        userLocation: _userLocation,
        nearbyDiscoveries: _nearbyDiscoveries,
      ),
    );
  }

  Widget _buildAttractionCard() {
    final a = _selectedAttraction!;
    final categoryColor = _getCategoryColor(a.category);
    final distanceKm = _userLocation == null
        ? null
        : _haversineKm(
            _userLocation!.lat.toDouble(),
            _userLocation!.lng.toDouble(),
            a.latitude,
            a.longitude,
          );

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_selectedPhotoUrl != null)
                        CachedNetworkImage(
                          imageUrl: _selectedPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _photoPlaceholder(categoryColor),
                          errorWidget: (_, __, ___) => _photoPlaceholder(categoryColor),
                        )
                      else if (_isLoadingSelectedPhoto)
                        _photoPlaceholder(categoryColor, showSpinner: true)
                      else
                        _photoPlaceholder(categoryColor),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        right: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() {
                              _selectedAttraction = null;
                              _selectedPhotoUrl = null;
                              _addAttractionMarkers();
                            }),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (a.rating != null) ...[
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
                          const SizedBox(width: 4),
                          Text(
                            a.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (a.userRatingsTotal != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${a.userRatingsTotal})',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.charcoal.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                        ],
                        if (distanceKm != null) ...[
                          Icon(Icons.near_me_rounded,
                              size: 16, color: AppColors.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            distanceKm < 1
                                ? '${(distanceKm * 1000).round()} m'
                                : '${distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (a.isOpen != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (a.isOpen! ? Colors.green : Colors.red).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              a.isOpen! ? 'Open' : 'Closed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: a.isOpen! ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (a.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        a.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.charcoal.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openDirections(a),
                            icon: const Icon(Icons.directions_rounded, size: 18),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _smallIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Share',
                          onTap: () => Share.share(
                            '${a.name} in ${a.city}\nhttps://maps.google.com/?q=${a.latitude},${a.longitude}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _smallIconButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Copy coordinates',
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text: '${a.latitude}, ${a.longitude}',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Coordinates copied'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(Color color, {bool showSpinner = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.5)],
        ),
      ),
      child: Center(
        child: showSpinner
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.image_rounded, color: Colors.white.withValues(alpha: 0.85), size: 48),
      ),
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
        ),
      ),
    );
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double deg2rad(double d) => d * math.pi / 180.0;
    final dLat = deg2rad(lat2 - lat1);
    final dLng = deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // Helper Methods
  void _selectCategory(String category) async {
    setState(() {
      _selectedCategory = category;
    });
    _filterAttractions();
  }

  void _selectDay(int day) async {
    setState(() => _currentDay = day);
    await _loadItineraryPoints();
  }

  void _togglePanel(MapPanelType? type) async {
    if (_activePanel == type) {
      setState(() => _activePanel = null);
      _panelController.reverse();
    } else {
      // Load nearby discoveries if opening nearby panel
      if (type == MapPanelType.nearby && _userLocation != null) {
        final discoveries = await _nearbyService.findNearbyAttractions(
          lat: _userLocation!.lat.toDouble(),
          lng: _userLocation!.lng.toDouble(),
          radiusMeters: 5000,
        );
        setState(() {
          _nearbyDiscoveries = discoveries;
          _activePanel = type;
        });
      } else {
        setState(() => _activePanel = type);
      }
      _panelController.forward();
    }
  }

  void _zoomMap(bool zoomIn) async {
    final currentZoom = await _mapboxMap?.getCameraState().then((state) => state.zoom) ?? 6.0;
    final newZoom = zoomIn ? currentZoom + 1 : currentZoom - 1;
    
    await _mapboxMap?.flyTo(
      CameraOptions(zoom: newZoom),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _recenterMap() async {
    if (_userLocation != null) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: _userLocation!),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _shareLocation() {
    if (_userLocation != null) {
      Share.share(
        'Check out my location in Egypt: https://maps.google.com/?q=${_userLocation!.lat},${_userLocation!.lng}',
      );
    }
  }

  Color _getCategoryColor(String category) => categoryStyleFor(category).color;

  // Map Methods
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));
    _mapboxMap?.logo.updateSettings(LogoSettings(enabled: false));
    _mapboxMap?.attribution.updateSettings(AttributionSettings(enabled: false));
    _mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Create annotation managers
    _pointAnnotationManager = await _mapboxMap?.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();

    // Wire up marker tap → open attraction card
    _pointAnnotationManager?.addOnPointAnnotationClickListener(
      _AttractionTapHandler(_handleMarkerTap),
    );

    // Show user location puck if permission was granted
    await _enableLocationPuck();

    if (_isItineraryMode) {
      await _loadItineraryPoints();
    } else {
      await _addAttractionMarkers();
    }

    setState(() => _isMapReady = true);
  }

  Future<void> _onMapTapped(MapContentGestureContext gestureContext) async {
    // Close attraction card / style menu when tapping map
    if (_selectedAttraction != null || _showStyleMenu) {
      setState(() {
        _selectedAttraction = null;
        _selectedPhotoUrl = null;
        _showStyleMenu = false;
      });
      _addAttractionMarkers();
    }
  }

  void _handleMarkerTap(PointAnnotation annotation) {
    // Itinerary stop marker → stop sheet
    final stopIndex = _markerToStopIndex[annotation.id];
    if (stopIndex != null) {
      HapticFeedback.selectionClick();
      _showStopSheet(stopIndex);
      return;
    }

    // Vector search result marker → simple result sheet
    final vectorResult = _markerToVectorResult[annotation.id];
    if (vectorResult != null) {
      HapticFeedback.selectionClick();
      _showVectorResultSheet(vectorResult);
      return;
    }

    final attraction = _markerToAttraction[annotation.id];
    if (attraction == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedAttraction = attraction;
      _selectedPhotoUrl = null;
      _isLoadingSelectedPhoto = true;
    });

    // Re-render markers so the selected one is enlarged
    _addAttractionMarkers();

    // Fly to it with a slight upward offset so the card doesn't cover it
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(attraction.longitude, attraction.latitude)),
        zoom: 15.0,
        padding: MbxEdgeInsets(top: 80, left: 0, bottom: 280, right: 0),
      ),
      MapAnimationOptions(duration: 800),
    );

    _loadSelectedPhoto(attraction);
  }

  Future<void> _loadSelectedPhoto(TouristAttraction a) async {
    try {
      final url = await _photoService.getPlacePhotoUrl(a.name, a.latitude, a.longitude);
      if (!mounted || _selectedAttraction?.id != a.id) return;
      setState(() {
        _selectedPhotoUrl = url;
        _isLoadingSelectedPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSelectedPhoto = false);
    }
  }

  Future<void> _enableLocationPuck() async {
    try {
      await _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
          puckBearingEnabled: true,
        ),
      );
    } catch (_) {}
  }

  Future<void> _changeStyle(MapStyleKind kind) async {
    setState(() {
      _styleKind = kind;
      _showStyleMenu = false;
    });
    final uri = switch (kind) {
      MapStyleKind.outdoors => MapboxStyles.OUTDOORS,
      MapStyleKind.streets => MapboxStyles.MAPBOX_STREETS,
      MapStyleKind.satellite => MapboxStyles.SATELLITE_STREETS,
      MapStyleKind.dark => MapboxStyles.DARK,
      MapStyleKind.light => MapboxStyles.LIGHT,
    };
    await _mapboxMap?.loadStyleURI(uri);
    // Re-create annotation managers since they get cleared on style change
    _pointAnnotationManager = await _mapboxMap?.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager?.addOnPointAnnotationClickListener(
      _AttractionTapHandler(_handleMarkerTap),
    );
    if (_isItineraryMode) {
      await _addItineraryMarkers();
      await _drawItineraryRoute();
    } else {
      await _addAttractionMarkers();
    }
  }

  Future<void> _toggle3D() async {
    setState(() => _is3D = !_is3D);
    final state = await _mapboxMap?.getCameraState();
    if (state == null) return;
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: state.center,
        zoom: _is3D ? (state.zoom < 14 ? 14 : state.zoom) : state.zoom,
        pitch: _is3D ? 60.0 : 0.0,
        bearing: _is3D ? 30.0 : 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _fitToFiltered() async {
    if (_mapboxMap == null || _filteredAttractions.length < 2) return;
    final points = _filteredAttractions
        .map((a) => Point(coordinates: Position(a.longitude, a.latitude)))
        .toList();
    try {
      final cam = await _mapboxMap!.cameraForCoordinates(
        points,
        MbxEdgeInsets(top: 180, left: 40, bottom: 200, right: 40),
        null,
        null,
      );
      await _mapboxMap?.flyTo(cam, MapAnimationOptions(duration: 1000));
    } catch (_) {}
  }

  Future<void> _openDirections(TouristAttraction a) async {
    final lat = a.latitude;
    final lng = a.longitude;
    final scheme = Platform.isIOS
        ? 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'
        : 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final uri = Uri.parse(scheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════ TRIP SESSION (live trip mode) ═══════════════════

  void _onTripChanged() {
    if (!mounted) return;
    setState(() {});
    // Refresh marker colors to reflect visit progress
    if (_isItineraryMode) _addItineraryMarkers();
  }

  Future<void> _startTrip() async {
    if (widget.itinerary == null || _currentDay == null) return;
    HapticFeedback.mediumImpact();
    await _tripService.startTrip(widget.itinerary!, _currentDay!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            '🚀 Trip started! We\'ll ping you for photos at every stop.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _endTrip({bool skipConfirm = false}) async {
    if (!skipConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('End your trip?'),
          content: const Text(
              'We\'ll wrap up your day and show you your trip recap! 🎁'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('End & see Wrapped'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final finished = await _tripService.endTrip();
    if (finished == null || !mounted) return;

    // Count the day's walking toward distance badges.
    final distanceResult =
        await gam.GamificationService().addDistance(finished.distanceWalkedKm);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TripWrappedScreen(session: finished)),
    );

    if (mounted && (distanceResult.newBadges.isNotEmpty || distanceResult.levelUp)) {
      showAchievement(context, distanceResult);
    }

    // Post-trip survey after Wrapped is closed (not inside it — Wrapped
    // auto-advances pages, which is hostile to form input).
    if (mounted) {
      await showTripFeedbackSheet(context, finished);
    }

    // Move the trip to history (clear from current trip tab)
    widget.onTripFinished?.call();
  }

  Future<void> _openStopCamera(int stopIndex) async {
    final session = _tripService.session;
    if (session == null || stopIndex >= session.stops.length) return;
    final stop = session.stops[stopIndex];

    final photos = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StopPhotoScreen(
          stop: stop,
          stopNumber: stopIndex + 1,
        ),
      ),
    );
    if (photos != null && photos.isNotEmpty) {
      await _tripService.addPhotosToStop(stopIndex, photos);
      await _onStopPhotosAdded(stopIndex, photos.length);
    }
  }

  /// Awards XP / badges after photos were added to a stop.
  Future<void> _onStopPhotosAdded(int stopIndex, int photoCount) async {
    final session = _tripService.session;
    final stop = (session != null && stopIndex < session.stops.length)
        ? session.stops[stopIndex]
        : null;
    if (stop == null || !mounted) return;

    final service = gam.GamificationService();
    final photoResult = await service.addPhotos(photoCount);

    gam.AchievementResult? visitResult;
    if (stop.status == StopStatus.completed) {
      // Idempotent per POI — re-completing an already visited stop gives 0 XP.
      visitResult = await service.visitAttraction(stop.poiId, stop.name);
    }

    if (!mounted) return;
    if (visitResult != null && visitResult.xpGained > 0) {
      showAchievement(context, visitResult);
      // Photo XP rides along silently unless it carries badges or a level-up.
      if (photoResult.newBadges.isNotEmpty || photoResult.levelUp) {
        showAchievement(
          context,
          gam.AchievementResult(
            xpGained: 0,
            newBadges: photoResult.newBadges,
            levelUp: photoResult.levelUp,
            message: '',
          ),
        );
      }
    } else {
      showAchievement(context, photoResult);
    }

    // Ask for a quick rating once the stop is done (dismissible).
    if (stop.status == StopStatus.completed && session != null && mounted) {
      await showStopFeedbackSheet(
        context,
        stop: stop,
        tripSessionId: session.id,
      );
    }

    // If ALL stops in the session are completed, auto-finish the trip
    if (session != null &&
        session.stops.every((s) => s.status == StopStatus.completed)) {
      // Small delay so the user sees the last achievement before the dialog
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        final autoEnd = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('🎉 All stops completed!'),
            content: const Text(
              'You\'ve visited every place and captured all your photos! '
              'Ready to end the trip and see your Wrapped?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep exploring'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End & see Wrapped'),
              ),
            ],
          ),
        );
        if (autoEnd == true) {
          await _endTrip(skipConfirm: true);
        }
      }
    }
  }

  /// Bottom sheet with stop details + check-in / photo actions
  void _showStopSheet(int stopIndex) {
    final point = stopIndex < _itineraryPoints.length
        ? _itineraryPoints[stopIndex]
        : null;
    if (point == null) return;
    final session = _tripService.session;
    final stop = (session != null && stopIndex < session.stops.length)
        ? session.stops[stopIndex]
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _itineraryService.getColorForDay(_currentDay ?? 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stop?.status == StopStatus.completed
                        ? '✓ Stop ${stopIndex + 1}'
                        : 'Stop ${stopIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(point.timeRange,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                const Icon(Icons.hourglass_bottom_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(point.formattedDuration,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                const Icon(Icons.payments_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(point.formattedCost,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (point.event.reason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point.event.reason,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.charcoal.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${point.position.lat},${point.position.lng}&travelmode=walking');
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (_tripService.hasActiveTrip && stop != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (stop.status == StopStatus.upcoming) {
                          await _tripService.checkInAtStop(stopIndex);
                        }
                        _openStopCamera(stopIndex);
                      },
                      icon: Icon(
                        stop.status == StopStatus.upcoming
                            ? Icons.where_to_vote_rounded
                            : Icons.photo_camera_rounded,
                        size: 18,
                      ),
                      label: Text(stop.status == StopStatus.upcoming
                          ? 'I\'m here!'
                          : 'Photos (${stop.photoPaths.length}/3)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Floating trip control: Start Trip button or live progress HUD
  Widget _buildTripHud() {
    final session = _tripService.session;
    final active = _tripService.hasActiveTrip;

    if (!active) {
      // Start Trip button
      return Positioned(
        left: 16,
        right: 16,
        bottom: 100,
        child: Center(
          child: ElevatedButton.icon(
            onPressed: _itineraryPoints.isEmpty ? null : _startTrip,
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('Start Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE67E22),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
      );
    }

    final next = session!.nextStop;
    final nextIndex = next != null ? session.stops.indexOf(next) : -1;
    final distance = next != null ? _tripService.distanceToStop(next) : null;
    final progress =
        session.stops.isEmpty ? 0.0 : session.visitedCount / session.stops.length;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 100,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_walk_rounded,
                      color: Color(0xFFE67E22), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next != null
                            ? 'Next: ${next.name}'
                            : 'All stops visited! 🎉',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        next != null
                            ? (distance != null
                                ? '${distance < 1000 ? "${distance.round()} m" : "${(distance / 1000).toStringAsFixed(1)} km"} away • ${session.visitedCount}/${session.stops.length} visited'
                                : '${session.visitedCount}/${session.stops.length} visited')
                            : 'End the trip to see your Wrapped!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.charcoal.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (next != null)
                  IconButton(
                    tooltip: 'I\'m here — take photos',
                    onPressed: () async {
                      await _tripService.checkInAtStop(nextIndex);
                      _openStopCamera(nextIndex);
                    },
                    icon: const Icon(Icons.photo_camera_rounded,
                        color: Color(0xFFE67E22), size: 26),
                  ),
                IconButton(
                  tooltip: 'End trip',
                  onPressed: _endTrip,
                  icon: const Icon(Icons.stop_circle_rounded,
                      color: Color(0xFFE74C3C), size: 26),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFFE67E22)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ VECTOR (AI) SEARCH ═══════════════════

  Future<void> _runVectorSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isVectorSearching = true;
      _aiRecommendation = null;
    });
    try {
      final result = await VectorSearchService.search(query, topK: 10);
      if (!mounted) return;
      setState(() {
        _vectorResults =
            result.places.where((p) => p.hasCoordinates).toList();
        _aiRecommendation = result.aiRecommendation;
        _isVectorSearching = false;
      });
      await _addVectorResultMarkers();
      _fitToVectorResults();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVectorSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI search unavailable right now — try again soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addVectorResultMarkers() async {
    if (_pointAnnotationManager == null) return;
    await _pointAnnotationManager?.deleteAll();
    _markerToAttraction.clear();
    _markerToVectorResult.clear();

    for (final r in _vectorResults) {
      final annotation = await _pointAnnotationManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(r.lon, r.lat)),
          iconImage: 'marker-15',
          iconSize: 2.2,
          iconColor: const Color(0xFF8E44AD).toARGB32(), // AI purple
          symbolSortKey: (r.score ?? 0) * 100,
        ),
      );
      if (annotation != null) {
        _markerToVectorResult[annotation.id] = r;
      }
    }
  }

  Future<void> _fitToVectorResults() async {
    if (_mapboxMap == null || _vectorResults.isEmpty) return;
    if (_vectorResults.length == 1) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
              coordinates:
                  Position(_vectorResults[0].lon, _vectorResults[0].lat)),
          zoom: 13.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      return;
    }
    final points = _vectorResults
        .map((r) => Point(coordinates: Position(r.lon, r.lat)))
        .toList();
    try {
      final cam = await _mapboxMap!.cameraForCoordinates(
        points,
        MbxEdgeInsets(top: 220, left: 40, bottom: 200, right: 40),
        null,
        null,
      );
      await _mapboxMap?.flyTo(cam, MapAnimationOptions(duration: 1000));
    } catch (_) {}
  }

  void _clearVectorSearch() {
    setState(() {
      _vectorResults = [];
      _aiRecommendation = null;
      _markerToVectorResult.clear();
    });
    if (_isItineraryMode) {
      _addItineraryMarkers();
    } else {
      _addAttractionMarkers();
    }
  }

  void _showVectorResultSheet(VectorSearchResult r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E44AD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🤖 AI match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            if (r.category.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                r.category,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                r.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.charcoal.withValues(alpha: 0.85),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${r.lat},${r.lon}');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner showing the AI's text recommendation after a vector search
  Widget _buildAiBanner() {
    return Positioned(
      top: 200,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E44AD), Color(0xFF5E2D79)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E44AD).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _aiRecommendation!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: _clearVectorSearch,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
