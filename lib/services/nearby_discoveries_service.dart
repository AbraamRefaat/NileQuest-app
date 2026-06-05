import 'dart:math' as math;
import 'package:dio/dio.dart';

/// Service for discovering nearby attractions and services
class NearbyDiscoveriesService {
  static const String _googleApiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';
  final Dio _dio = Dio();

  /// Find nearby attractions within walking distance
  Future<List<NearbyDiscovery>> findNearbyAttractions({
    required double lat,
    required double lng,
    double radiusMeters = 500,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'tourist_attraction|museum|park|art_gallery',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          final distance = _calculateDistance(
            lat,
            lng,
            place['geometry']['location']['lat'],
            place['geometry']['location']['lng'],
          );

          return NearbyDiscovery(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: DiscoveryType.attraction,
            category: _categorizePlace(place['types']),
            distance: distance,
            rating: place['rating']?.toDouble(),
            isOpen: place['opening_hours']?['open_now'],
            photoReference: place['photos']?[0]?['photo_reference'],
            address: place['vicinity'],
            priceLevel: place['price_level'],
          );
        }).toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
      }
      return [];
    } catch (e) {
      print('Error finding nearby attractions: $e');
      return [];
    }
  }

  /// Find quick detours (places that add <30 min to route)
  Future<List<NearbyDiscovery>> findQuickDetours({
    required double currentLat,
    required double currentLng,
    required double destinationLat,
    required double destinationLng,
    int maxDetourMinutes = 30,
  }) async {
    try {
      // Search along the route
      final midLat = (currentLat + destinationLat) / 2;
      final midLng = (currentLng + destinationLng) / 2;

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$midLat,$midLng',
          'radius': 1000,
          'type': 'tourist_attraction|cafe|restaurant|park',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        List<NearbyDiscovery> detours = [];

        for (var place in results) {
          final placeLat = place['geometry']['location']['lat'];
          final placeLng = place['geometry']['location']['lng'];

          // Calculate detour distance
          final directDistance = _calculateDistance(
            currentLat,
            currentLng,
            destinationLat,
            destinationLng,
          );

          final detourDistance = _calculateDistance(
                currentLat,
                currentLng,
                placeLat,
                placeLng,
              ) +
              _calculateDistance(
                placeLat,
                placeLng,
                destinationLat,
                destinationLng,
              );

          final extraDistance = detourDistance - directDistance;
          final extraMinutes = (extraDistance / 5) * 60; // Assume 5 km/h walking

          if (extraMinutes <= maxDetourMinutes) {
            detours.add(NearbyDiscovery(
              id: place['place_id'],
              name: place['name'],
              lat: placeLat,
              lng: placeLng,
              type: DiscoveryType.detour,
              category: _categorizePlace(place['types']),
              distance: _calculateDistance(currentLat, currentLng, placeLat, placeLng),
              rating: place['rating']?.toDouble(),
              isOpen: place['opening_hours']?['open_now'],
              photoReference: place['photos']?[0]?['photo_reference'],
              address: place['vicinity'],
              detourMinutes: extraMinutes.round(),
            ));
          }
        }

        detours.sort((a, b) => (a.detourMinutes ?? 0).compareTo(b.detourMinutes ?? 0));
        return detours;
      }
      return [];
    } catch (e) {
      print('Error finding quick detours: $e');
      return [];
    }
  }

  /// Find hidden gems (highly rated, less popular places)
  Future<List<NearbyDiscovery>> findHiddenGems({
    required double lat,
    required double lng,
    double radiusMeters = 1000,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'cafe|restaurant|park|art_gallery|store',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        
        // Filter for high rating but lower review count (hidden gems)
        return results
            .where((place) {
              final rating = place['rating'] ?? 0;
              final reviewCount = place['user_ratings_total'] ?? 0;
              return rating >= 4.5 && reviewCount >= 10 && reviewCount <= 500;
            })
            .map((place) {
              return NearbyDiscovery(
                id: place['place_id'],
                name: place['name'],
                lat: place['geometry']['location']['lat'],
                lng: place['geometry']['location']['lng'],
                type: DiscoveryType.hiddenGem,
                category: _categorizePlace(place['types']),
                distance: _calculateDistance(
                  lat,
                  lng,
                  place['geometry']['location']['lat'],
                  place['geometry']['location']['lng'],
                ),
                rating: place['rating']?.toDouble(),
                isOpen: place['opening_hours']?['open_now'],
                photoReference: place['photos']?[0]?['photo_reference'],
                address: place['vicinity'],
                reviewCount: place['user_ratings_total'],
              );
            })
            .toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      }
      return [];
    } catch (e) {
      print('Error finding hidden gems: $e');
      return [];
    }
  }

  /// Find photo opportunities along route
  Future<List<NearbyDiscovery>> findPhotoOpportunities({
    required double lat,
    required double lng,
    double radiusMeters = 800,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'tourist_attraction|point_of_interest',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        
        // Filter for places with photos and high ratings
        return results
            .where((place) {
              final hasPhotos = place['photos'] != null && (place['photos'] as List).isNotEmpty;
              final rating = place['rating'] ?? 0;
              return hasPhotos && rating >= 4.3;
            })
            .map((place) {
              return NearbyDiscovery(
                id: place['place_id'],
                name: place['name'],
                lat: place['geometry']['location']['lat'],
                lng: place['geometry']['location']['lng'],
                type: DiscoveryType.photoSpot,
                category: 'Photo Spot',
                distance: _calculateDistance(
                  lat,
                  lng,
                  place['geometry']['location']['lat'],
                  place['geometry']['location']['lng'],
                ),
                rating: place['rating']?.toDouble(),
                photoReference: place['photos']?[0]?['photo_reference'],
                address: place['vicinity'],
              );
            })
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
      }
      return [];
    } catch (e) {
      print('Error finding photo opportunities: $e');
      return [];
    }
  }

  /// Find essential services (ATM, pharmacy, restroom)
  Future<List<NearbyDiscovery>> findEssentialServices({
    required double lat,
    required double lng,
    String serviceType = 'all', // 'atm', 'pharmacy', 'restroom', 'all'
  }) async {
    try {
      String types;
      switch (serviceType) {
        case 'atm':
          types = 'atm|bank';
          break;
        case 'pharmacy':
          types = 'pharmacy|drugstore';
          break;
        case 'restroom':
          types = 'gas_station|restaurant|cafe'; // Places with restrooms
          break;
        default:
          types = 'atm|pharmacy|hospital|police';
      }

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': 500,
          'type': types,
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          return NearbyDiscovery(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: DiscoveryType.service,
            category: _categorizePlace(place['types']),
            distance: _calculateDistance(
              lat,
              lng,
              place['geometry']['location']['lat'],
              place['geometry']['location']['lng'],
            ),
            isOpen: place['opening_hours']?['open_now'],
            address: place['vicinity'],
          );
        }).toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
      }
      return [];
    } catch (e) {
      print('Error finding essential services: $e');
      return [];
    }
  }

  String _categorizePlace(List<dynamic> types) {
    if (types.contains('tourist_attraction')) return 'Attraction';
    if (types.contains('museum')) return 'Museum';
    if (types.contains('park')) return 'Park';
    if (types.contains('restaurant')) return 'Restaurant';
    if (types.contains('cafe')) return 'Cafe';
    if (types.contains('shopping_mall')) return 'Shopping';
    if (types.contains('art_gallery')) return 'Art Gallery';
    if (types.contains('atm')) return 'ATM';
    if (types.contains('pharmacy')) return 'Pharmacy';
    return 'Place';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }
}

enum DiscoveryType {
  attraction,
  detour,
  hiddenGem,
  photoSpot,
  service,
}

class NearbyDiscovery {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final DiscoveryType type;
  final String category;
  final double distance; // in km
  final double? rating;
  final bool? isOpen;
  final String? photoReference;
  final String? address;
  final int? priceLevel;
  final int? detourMinutes;
  final int? reviewCount;

  NearbyDiscovery({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.category,
    required this.distance,
    this.rating,
    this.isOpen,
    this.photoReference,
    this.address,
    this.priceLevel,
    this.detourMinutes,
    this.reviewCount,
  });

  String get distanceText {
    if (distance < 1) {
      return '${(distance * 1000).round()}m away';
    }
    return '${distance.toStringAsFixed(1)}km away';
  }

  String get walkingTime {
    final minutes = (distance / 5 * 60).round(); // 5 km/h walking speed
    if (minutes < 1) return '< 1 min walk';
    if (minutes == 1) return '1 min walk';
    return '$minutes mins walk';
  }

  String get typeLabel {
    switch (type) {
      case DiscoveryType.attraction:
        return 'Nearby Attraction';
      case DiscoveryType.detour:
        return 'Quick Detour (+${detourMinutes ?? 0} min)';
      case DiscoveryType.hiddenGem:
        return 'Hidden Gem';
      case DiscoveryType.photoSpot:
        return 'Photo Spot';
      case DiscoveryType.service:
        return 'Service';
    }
  }

  String get priceLevelText {
    if (priceLevel == null) return '';
    return '\$' * priceLevel!;
  }
}
