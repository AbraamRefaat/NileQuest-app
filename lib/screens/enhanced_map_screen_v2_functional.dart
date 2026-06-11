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
import '../models/tourist_attraction.dart';
import '../models/itinerary.dart';
import '../services/places_service.dart';
import '../services/itinerary_map_service.dart';
import '../services/nearby_discoveries_service.dart';
import '../services/audio_guide_service.dart';
import '../services/google_places_photo_service.dart';
import '../widgets/modern_map_panels.dart';

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

  const EnhancedMapScreenV2Functional({
    super.key,
    this.itinerary,
    this.selectedDay,
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

    for (int i = 0; i < _itineraryPoints.length; i++) {
      final point = _itineraryPoints[i];
      final position = Point(coordinates: point.position);

      final options = PointAnnotationOptions(
        geometry: position,
        iconImage: 'marker-15',
        iconSize: 2.0,
        textField: '${i + 1}',
        textSize: 12.0,
      );

      await _pointAnnotationManager?.create(options);
    }
  }

  Future<void> _drawItineraryRoute() async {
    if (_polylineAnnotationManager == null || _itineraryPoints.isEmpty) return;

    await _polylineAnnotationManager?.deleteAll();

    // Get route from directions service
    final route = await _itineraryService.getRouteForDay(
      widget.itinerary!,
      _currentDay!,
    );

    if (route.isNotEmpty) {
      final lineString = LineString(coordinates: route);
      final options = PolylineAnnotationOptions(
        geometry: lineString,
        lineWidth: 4.0,
      );

      await _polylineAnnotationManager?.create(options);
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

          // 📊 Stats Card
          if (!_isLoading && _isMapReady)
            _buildStatsCard(),

          // 🎯 Map Controls
          _buildMapControls(),

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
                    hintText: 'Search attractions, places...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchTextController.clear();
                  },
                  child: Icon(
                    Icons.clear_rounded,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Historical':
        return const Color(0xFFE67E22);
      case 'Museum':
        return const Color(0xFF9B59B6);
      case 'Religious':
        return const Color(0xFF3498DB);
      case 'Natural':
        return const Color(0xFF27AE60);
      case 'Shopping':
        return const Color(0xFFF39C12);
      case 'Beach Resort':
        return const Color(0xFF1ABC9C);
      default:
        return AppColors.primary;
    }
  }

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
}
