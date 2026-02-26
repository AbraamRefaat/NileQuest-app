import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../theme.dart';
import '../models/tourist_attraction.dart';
import '../services/places_service.dart';
import '../services/directions_service.dart';
import '../widgets/directions_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  bool _isMapReady = false;
  bool _showAttractionsList = false;
  
  // Dynamic data
  final PlacesService _placesService = PlacesService();
  List<TouristAttraction> _allAttractions = [];
  List<TouristAttraction> _filteredAttractions = [];
  Map<String, TouristAttraction> _markerToAttraction = {}; // Map marker IDs to attractions
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  
  // Map state
  double _currentZoom = 6.0;
  Position? _userLocation; // Mapbox Position

  @override
  void initState() {
    super.initState();
    _loadAttractions();
    _getUserLocation();
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

      // Add markers after attractions are loaded
      if (_mapboxMap != null) {
        await _addAttractionMarkers();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attractions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserLocation() async {

    try {
      // Check permissions
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          print('Location permissions denied');
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return;
      }

      // Get current position
      final geoPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      // Convert to Mapbox Position
      setState(() {
        _userLocation = Position(geoPosition.longitude, geoPosition.latitude);
      });

      // Center map on user location if map is ready
      if (_mapboxMap != null && _userLocation != null) {
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: _userLocation!),
            zoom: 12.0,
          ),
          MapAnimationOptions(duration: 1500),
        );
        _currentZoom = 12.0;
        await _addAttractionMarkers();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapbox Map
          MapWidget(
            key: const ValueKey('mapWidget'),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(30.8025, 26.8206), // Center of Egypt
              ),
              zoom: 6.0,
              pitch: 0.0,
            ),
            styleUri: MapboxStyles.OUTDOORS,
            textureView: true,
            onMapCreated: _onMapCreated,
            // ✅ Enable tapping on ANY place (like Google Maps!)
            onTapListener: _onMapTapped,
          ),

          // Attractions List
          if (_showAttractionsList)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              bottom: 120,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Tourist Attractions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_filteredAttractions.length} places',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _filteredAttractions.isEmpty
                          ? const Center(
                              child: Text('No attractions found'),
                            )
                          : ListView.builder(
                              itemCount: _filteredAttractions.length,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (context, index) {
                                final attraction = _filteredAttractions[index];
                                return _buildAttractionListItem(attraction);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading Indicator
          if (_isLoading || !_isMapReady)
            Container(
              color: Colors.white.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _isLoading
                          ? 'Loading attractions...'
                          : 'Initializing map...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error Message
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadAttractions,
                    ),
                  ],
                ),
              ),
            ),

          // Category Filter (Horizontal scroll at top)
          if (!_showAttractionsList && !_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.only(top: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryChip('All', Icons.grid_view_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Historical', Icons.account_balance_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Museum', Icons.museum_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Religious', Icons.mosque_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Natural', Icons.landscape_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Beach Resort', Icons.beach_access_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Shopping', Icons.shopping_bag_rounded),
                  ],
                ),
              ),
            ),
          ),

          // Zoom Info Indicator
          if (!_isLoading && !_showAttractionsList)
            Positioned(
              left: 16,
              bottom: 120,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getZoomMessage(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Map Controls
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _recenterMap,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.layers_rounded,
                  onPressed: _showMapStyleOptions,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.filter_list_rounded,
                  onPressed: () {
                    setState(() {
                      _showAttractionsList = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCategoryChip(String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    final color = category == 'All' 
        ? AppColors.primary 
        : _getCategoryColor(category);
    
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedCategory = category;
          if (category == 'All') {
            _filteredAttractions = _allAttractions;
          } else {
            _filteredAttractions = _placesService.filterByCategory(
              _allAttractions,
              category,
            );
          }
        });

        // Refresh markers to show only filtered attractions
        if (_mapboxMap != null) {
          await _addAttractionMarkers();
        }

        // Show feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                category == 'All'
                    ? 'Showing all attractions'
                    : 'Showing ${_filteredAttractions.length} $category attractions',
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttractionListItem(TouristAttraction attraction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(attraction.category),
            color: AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          attraction.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${attraction.city} • ${attraction.category}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
        ),
        onTap: () {
          setState(() {
            _showAttractionsList = false;
          });
          _onAttractionTapped(attraction);
        },
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async{
    _mapboxMap = mapboxMap;

    // Hide Mapbox default UI elements (compass, logo, attribution)
    _mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));
    _mapboxMap?.logo.updateSettings(LogoSettings(enabled: false));
    _mapboxMap?.attribution.updateSettings(AttributionSettings(enabled: false));
    _mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Listen to camera changes for zoom-based features
    _mapboxMap?.getCameraState().then((cameraState) {
      setState(() {
        _currentZoom = cameraState.zoom;
      });
    });

    // Add continuous camera listener to update markers as user zooms
    _startCameraListener();

    // Add markers for all attractions
    await _addAttractionMarkers();

    setState(() {
      _isMapReady = true;
    });
  }

  void _startCameraListener() {
    // Update camera state periodically (every 500ms)
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_mapboxMap != null && mounted) {
        final cameraState = await _mapboxMap!.getCameraState();
        final newZoom = cameraState.zoom;
        
        // Only update if zoom changed significantly (more than 0.5)
        if ((newZoom - _currentZoom).abs() > 0.5) {
          setState(() {
            _currentZoom = newZoom;
          });
          
          // Refresh markers based on new zoom level
          await _addAttractionMarkers();
        }
        
        // Continue listening
        _startCameraListener();
      }
    });
  }

  Future<void> _addAttractionMarkers() async {
    if (_mapboxMap == null) return;

    try {
      // Clear existing markers and mapping
      await _pointAnnotationManager?.deleteAll();
      _markerToAttraction.clear();
      
      // Create point annotation manager
      _pointAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();

      // ✅ SET UP MARKER CLICK LISTENER - EXACTLY LIKE GOOGLE MAPS!
      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        _MarkerClickListener(
          onMarkerClicked: (String markerId) {
            debugPrint('✅ Marker clicked! ID: $markerId');
            
            // Find the attraction that matches this marker
            final attraction = _markerToAttraction[markerId];
            
            if (attraction != null) {
              debugPrint('✅ Opening: ${attraction.name}');
              _onAttractionTapped(attraction);
            } else {
              debugPrint('❌ No attraction found for marker ID: $markerId');
            }
          },
        ),
      );

      // Determine which attractions to show based on zoom
      final attractionsToShow = _getVisibleAttractions();

      // Add markers for each attraction
      for (int i = 0; i < attractionsToShow.length; i++) {
        final attraction = attractionsToShow[i];
        final color = _getCategoryColor(attraction.category);
        
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              attraction.longitude,
              attraction.latitude,
            ),
          ),
          iconImage: 'marker',
          iconSize: _currentZoom > 12 ? 2.5 : (_currentZoom > 10 ? 2.0 : 1.5), // MUCH BIGGER!
          iconAnchor: IconAnchor.BOTTOM,
          iconColor: color.value,
        );
        
        // Create individual marker and store mapping
        final annotation = await _pointAnnotationManager?.create(options);
        if (annotation != null) {
          _markerToAttraction[annotation.id] = attraction;
        }
      }

      debugPrint('Added ${_markerToAttraction.length} markers to map');
    } catch (e) {
      debugPrint('Error adding markers: $e');
    }
  }

  // ✅ Handle taps on ANY place on the map (like Google Maps!)
  Future<void> _onMapTapped(MapContentGestureContext gestureContext) async {
    if (!mounted) return;
    
    final BuildContext? ctx = context;
    if (ctx == null) return;
    
    try {
      final point = gestureContext.point;
      final tapLat = point.coordinates.lat.toDouble();
      final tapLng = point.coordinates.lng.toDouble();
      
      debugPrint('🗺️ Map tapped at: lat=$tapLat, lng=$tapLng');
      
      // Show loading indicator
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Searching for places nearby...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
      
      // ✅ Use Google Places API to find what's at this location!
      final response = await _placesService.searchNearbyPlace(tapLat, tapLng);
      
      if (!mounted) return;
      
      if (response != null) {
        debugPrint('✅ Found place: ${response.name}');
        _onAttractionTapped(response);
      } else {
        debugPrint('❌ No place found at tap location');
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('No place found at this location'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling map tap: $e');
    }
  }

  void _showAttractionDetails(TouristAttraction attraction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(0),
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Image
              if (attraction.photoReference != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: _placesService.getPhotoUrl(
                      attraction.photoReference!,
                      maxWidth: 800,
                    ),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      attraction.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Category chip
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            attraction.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: _getCategoryColor(attraction.category),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        if (attraction.isOpen != null)
                          Chip(
                            label: Text(
                              attraction.isOpen! ? 'Open Now' : 'Closed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: attraction.isOpen! ? Colors.green : Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Rating
                    if (attraction.rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${attraction.rating}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (attraction.userRatingsTotal != null)
                            Text(
                              ' (${attraction.userRatingsTotal} reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    
                    // Description
                    if (attraction.description.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            attraction.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    
                    // Address
                    if (attraction.address != null && attraction.address!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on_rounded,
                        attraction.address!,
                      ),
                    
                    // Phone
                    if (attraction.phoneNumber != null && attraction.phoneNumber!.isNotEmpty)
                      _buildInfoRow(
                        Icons.phone_rounded,
                        attraction.phoneNumber!,
                      ),
                    
                    // Website
                    if (attraction.website != null && attraction.website!.isNotEmpty)
                      _buildInfoRow(
                        Icons.language_rounded,
                        attraction.website!,
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToAttraction(attraction);
                            },
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('Navigate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Close'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TouristAttraction> _getVisibleAttractions() {
    // Very zoomed in - show all filtered attractions
    if (_currentZoom >= 13) {
      return _filteredAttractions;
    }
    
    // Zoomed in moderately - show highly rated
    if (_currentZoom >= 11) {
      return _filteredAttractions
          .where((a) => (a.rating ?? 0) >= 4.3)
          .toList();
    }
    
    // Medium zoom - show top rated
    if (_currentZoom >= 9) {
      return _filteredAttractions
          .where((a) => (a.rating ?? 0) >= 4.5)
          .take(100)
          .toList();
    }
    
    // Zoomed out - show only best attractions
    if (_currentZoom >= 7) {
      return _filteredAttractions
          .where((a) => (a.rating ?? 0) >= 4.7)
          .take(30)
          .toList();
    }
    
    // Very zoomed out - show only top 15 attractions
    return _filteredAttractions
        .where((a) => (a.rating ?? 0) >= 4.8)
        .take(15)
        .toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Historical':
        return const Color(0xFFE67E22); // Orange
      case 'Museum':
        return const Color(0xFF9B59B6); // Purple
      case 'Religious':
        return const Color(0xFF3498DB); // Blue
      case 'Natural':
        return const Color(0xFF27AE60); // Green
      case 'Shopping':
        return const Color(0xFFF39C12); // Yellow-Orange
      case 'Beach Resort':
        return const Color(0xFF1ABC9C); // Teal
      case 'Art & Culture':
        return const Color(0xFFE74C3C); // Red
      case 'Food & Dining':
        return const Color(0xFFF1C40F); // Yellow
      default:
        return AppColors.primary;
    }
  }

  void _onAttractionTapped(TouristAttraction attraction) async {
    setState(() {
      _showAttractionsList = false;
    });

    // Animate camera to the selected location
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            attraction.longitude,
            attraction.latitude,
          ),
        ),
        zoom: 14.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 1500, startDelay: 0),
    );
    
    // Update zoom level and refresh markers
    _currentZoom = 14.0;
    await _addAttractionMarkers();

    // Show attraction details in bottom sheet
    _showAttractionDetails(attraction);
  }

  Future<void> _recenterMap() async {
    // If we have user location, center on that
    if (_userLocation != null) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: _userLocation!),
          zoom: 12.0,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );

      setState(() {
        _currentZoom = 12.0;
      });
    } else {
      // Otherwise, get user location first
      await _getUserLocation();
      
      // If still no location, center on Egypt
      if (_userLocation == null) {
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(30.8025, 26.8206),
            ),
            zoom: 6.0,
            pitch: 0.0,
          ),
          MapAnimationOptions(duration: 1500, startDelay: 0),
        );

        setState(() {
          _currentZoom = 6.0;
        });
      }
    }
    
    // Refresh markers for new zoom level
    await _addAttractionMarkers();
  }

  void _showMapStyleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Map Style',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 20),
            _buildStyleOption('Streets', MapboxStyles.MAPBOX_STREETS),
            _buildStyleOption('Outdoors', MapboxStyles.OUTDOORS),
            _buildStyleOption('Satellite', MapboxStyles.SATELLITE),
            _buildStyleOption('Satellite Streets', MapboxStyles.SATELLITE_STREETS),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(String name, String styleUri) {
    return ListTile(
      title: Text(name),
      onTap: () {
        _mapboxMap?.loadStyleURI(styleUri);
        Navigator.pop(context);
        
        // Re-add markers after style change
        Future.delayed(const Duration(milliseconds: 500), () {
          _addAttractionMarkers();
        });
      },
    );
  }

  Future<void> _navigateToAttraction(TouristAttraction attraction) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          backgroundColor: AppColors.accent,
        ),
      );
      
      await _getUserLocation();
      
      if (_userLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get your location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get directions
      final directionsService = DirectionsService();
      final directions = await directionsService.getDirections(
        originLat: _userLocation!.lat.toDouble(),
        originLng: _userLocation!.lng.toDouble(),
        destLat: attraction.latitude,
        destLng: attraction.longitude,
        mode: 'driving',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (directions != null) {
        // Draw route on map
        await _drawRouteOnMap(directions.routePoints);

        // Show directions bottom sheet
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: DirectionsBottomSheet(
              directions: directions,
              onClose: () {
                Navigator.pop(context);
                _clearRoute();
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find route. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  PolylineAnnotationManager? _polylineAnnotationManager;

  Future<void> _drawRouteOnMap(List<Position> routePoints) async {
    if (_mapboxMap == null || routePoints.isEmpty) return;

    try {
      // Clear existing route
      await _clearRoute();

      // Create polyline annotation manager
      _polylineAnnotationManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();

      // Create polyline options
      final polylineOptions = PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePoints),
        lineColor: Colors.blue.value,
        lineWidth: 5.0,
        lineOpacity: 0.8,
      );

      // Add polyline
      await _polylineAnnotationManager?.create(polylineOptions);

      // Fit map to show entire route
      // Calculate center of the route
      double minLat = routePoints[0].lat.toDouble();
      double maxLat = routePoints[0].lat.toDouble();
      double minLng = routePoints[0].lng.toDouble();
      double maxLng = routePoints[0].lng.toDouble();

      for (var point in routePoints) {
        if (point.lat < minLat) minLat = point.lat.toDouble();
        if (point.lat > maxLat) maxLat = point.lat.toDouble();
        if (point.lng < minLng) minLng = point.lng.toDouble();
        if (point.lng > maxLng) maxLng = point.lng.toDouble();
      }

      // Animate to show entire route
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              (minLng + maxLng) / 2,
              (minLat + maxLat) / 2,
            ),
          ),
          zoom: 10.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  Future<void> _clearRoute() async {
    try {
      await _polylineAnnotationManager?.deleteAll();
    } catch (e) {
      print('Error clearing route: $e');
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Historical':
        return Icons.account_balance_rounded;
      case 'Museum':
        return Icons.museum_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Landmark':
        return Icons.location_city_rounded;
      case 'Beach Resort':
        return Icons.beach_access_rounded;
      case 'Religious':
        return Icons.mosque_rounded;
      case 'Natural':
        return Icons.landscape_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  String _getZoomMessage() {
    final visibleCount = _getVisibleAttractions().length;
    final totalCount = _filteredAttractions.length;
    
    if (_currentZoom >= 13) {
      return 'Showing all $totalCount attractions';
    } else if (_currentZoom >= 11) {
      return 'Showing $visibleCount best attractions';
    } else if (_currentZoom >= 9) {
      return 'Showing top $visibleCount (4.5★+)';
    } else if (_currentZoom >= 7) {
      return 'Showing top $visibleCount (4.7★+)';
    } else {
      return 'Zoom in to see more • Top $visibleCount shown';
    }
  }

  @override
  void dispose() {
    _pointAnnotationManager?.deleteAll();
    super.dispose();
  }
}

// ✅ Marker Click Listener - EXACTLY like Google Maps!
class _MarkerClickListener extends OnPointAnnotationClickListener {
  final Function(String) onMarkerClicked;

  _MarkerClickListener({required this.onMarkerClicked});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onMarkerClicked(annotation.id);
  }
}
