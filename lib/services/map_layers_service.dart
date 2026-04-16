import 'package:dio/dio.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing different map layers (transport, amenities, safety, etc.)
class MapLayersService {
  static const String _googleApiKey = 'AIzaSyBCzhyILiS8FlaBqWepcZpUJNTra-ce3Do';
  final Dio _dio = Dio();

  /// Get nearby transport options (metro, bus, taxi stands)
  Future<List<MapLayerPoint>> getTransportLayer({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'transit_station|bus_station|taxi_stand',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.transport,
            subtype: _getTransportSubtype(place['types']),
            rating: place['rating']?.toDouble(),
            isOpen: place['opening_hours']?['open_now'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching transport layer: $e');
      return [];
    }
  }

  /// Get nearby amenities (ATMs, restrooms, WiFi, pharmacies)
  Future<List<MapLayerPoint>> getAmenitiesLayer({
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
          'type': 'atm|pharmacy|hospital|police',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.amenities,
            subtype: _getAmenitySubtype(place['types']),
            rating: place['rating']?.toDouble(),
            isOpen: place['opening_hours']?['open_now'],
            address: place['vicinity'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching amenities layer: $e');
      return [];
    }
  }

  /// Get nearby restaurants and cafes
  Future<List<MapLayerPoint>> getFoodLayer({
    required double lat,
    required double lng,
    double radiusMeters = 1500,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'restaurant|cafe',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.food,
            subtype: place['types'].contains('cafe') ? 'Cafe' : 'Restaurant',
            rating: place['rating']?.toDouble(),
            isOpen: place['opening_hours']?['open_now'],
            priceLevel: place['price_level'],
            address: place['vicinity'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching food layer: $e');
      return [];
    }
  }

  /// Get nearby shopping options
  Future<List<MapLayerPoint>> getShoppingLayer({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
  }) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'shopping_mall|store|supermarket',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.shopping,
            subtype: _getShoppingSubtype(place['types']),
            rating: place['rating']?.toDouble(),
            isOpen: place['opening_hours']?['open_now'],
            address: place['vicinity'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching shopping layer: $e');
      return [];
    }
  }

  /// Get safety points (police stations, embassies, hospitals)
  Future<List<MapLayerPoint>> getSafetyLayer({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
  }) async {
    List<MapLayerPoint> safetyPoints = [];

    try {
      // Get police stations
      final policeResponse = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'police',
          'key': _googleApiKey,
        },
      );

      if (policeResponse.statusCode == 200 && policeResponse.data['status'] == 'OK') {
        final results = policeResponse.data['results'] as List;
        safetyPoints.addAll(results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.safety,
            subtype: 'Police',
            address: place['vicinity'],
          );
        }));
      }

      // Get hospitals
      final hospitalResponse = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters,
          'type': 'hospital',
          'key': _googleApiKey,
        },
      );

      if (hospitalResponse.statusCode == 200 && hospitalResponse.data['status'] == 'OK') {
        final results = hospitalResponse.data['results'] as List;
        safetyPoints.addAll(results.map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.safety,
            subtype: 'Hospital',
            address: place['vicinity'],
          );
        }));
      }

      // Add known embassies in major Egyptian cities
      safetyPoints.addAll(_getEmbassyLocations(lat, lng));

      return safetyPoints;
    } catch (e) {
      print('Error fetching safety layer: $e');
      return safetyPoints;
    }
  }

  /// Get photo spots (highly rated viewpoints and landmarks)
  Future<List<MapLayerPoint>> getPhotoSpotsLayer({
    required double lat,
    required double lng,
    double radiusMeters = 3000,
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
        // Filter for highly rated places (good for photos)
        return results
            .where((place) => (place['rating'] ?? 0) >= 4.5)
            .map((place) {
          return MapLayerPoint(
            id: place['place_id'],
            name: place['name'],
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            type: MapLayerType.photoSpot,
            subtype: 'Photo Spot',
            rating: place['rating']?.toDouble(),
            photoReference: place['photos']?[0]?['photo_reference'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching photo spots layer: $e');
      return [];
    }
  }

  String _getTransportSubtype(List<dynamic> types) {
    if (types.contains('subway_station')) return 'Metro';
    if (types.contains('bus_station')) return 'Bus';
    if (types.contains('taxi_stand')) return 'Taxi';
    if (types.contains('train_station')) return 'Train';
    return 'Transit';
  }

  String _getAmenitySubtype(List<dynamic> types) {
    if (types.contains('atm')) return 'ATM';
    if (types.contains('pharmacy')) return 'Pharmacy';
    if (types.contains('hospital')) return 'Hospital';
    if (types.contains('police')) return 'Police';
    return 'Amenity';
  }

  String _getShoppingSubtype(List<dynamic> types) {
    if (types.contains('shopping_mall')) return 'Mall';
    if (types.contains('supermarket')) return 'Supermarket';
    if (types.contains('convenience_store')) return 'Store';
    return 'Shopping';
  }

  /// Get known embassy locations (hardcoded for major cities)
  List<MapLayerPoint> _getEmbassyLocations(double lat, double lng) {
    // Cairo embassies (if user is in Cairo area)
    if ((lat - 30.0444).abs() < 0.5 && (lng - 31.2357).abs() < 0.5) {
      return [
        MapLayerPoint(
          id: 'us_embassy_cairo',
          name: 'U.S. Embassy Cairo',
          lat: 30.0626,
          lng: 31.2197,
          type: MapLayerType.safety,
          subtype: 'Embassy',
          address: 'Garden City, Cairo',
        ),
        MapLayerPoint(
          id: 'uk_embassy_cairo',
          name: 'British Embassy Cairo',
          lat: 30.0626,
          lng: 31.2262,
          type: MapLayerType.safety,
          subtype: 'Embassy',
          address: 'Garden City, Cairo',
        ),
        MapLayerPoint(
          id: 'german_embassy_cairo',
          name: 'German Embassy Cairo',
          lat: 30.0731,
          lng: 31.2089,
          type: MapLayerType.safety,
          subtype: 'Embassy',
          address: 'Berlin St, Cairo',
        ),
      ];
    }
    return [];
  }
}

enum MapLayerType {
  transport,
  amenities,
  food,
  shopping,
  safety,
  photoSpot,
}

class MapLayerPoint {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final MapLayerType type;
  final String subtype;
  final double? rating;
  final bool? isOpen;
  final int? priceLevel;
  final String? address;
  final String? photoReference;

  MapLayerPoint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.subtype,
    this.rating,
    this.isOpen,
    this.priceLevel,
    this.address,
    this.photoReference,
  });

  Position get position => Position(lng, lat);
}
