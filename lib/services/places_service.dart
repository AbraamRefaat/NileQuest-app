import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tourist_attraction.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyBCzhyILiS8FlaBqWepcZpUJNTra-ce3Do';

  final Dio _dio = Dio();

  // Egyptian cities coordinates for searching
  static const Map<String, Map<String, double>> egyptianCities = {
    'Cairo': {'lat': 30.0444, 'lng': 31.2357},
    'Giza': {'lat': 29.9870, 'lng': 31.2118},
    'Luxor': {'lat': 25.6872, 'lng': 32.6396},
    'Aswan': {'lat': 24.0889, 'lng': 32.8998},
    'Alexandria': {'lat': 31.2001, 'lng': 29.9187},
    'Hurghada': {'lat': 27.2579, 'lng': 33.8116},
    'Sharm El Sheikh': {'lat': 27.9158, 'lng': 34.3300},
    'Dahab': {'lat': 28.5047, 'lng': 34.5160},
    'Port Said': {'lat': 31.2653, 'lng': 32.3019},
    'Faiyum': {'lat': 29.3084, 'lng': 30.8428},
  };

  // Tourist attraction types to search for
  static const List<String> attractionTypes = [
    'tourist_attraction',
    'museum',
    'church',
    'mosque',
    'synagogue',
    'park',
    'art_gallery',
    'historical_landmark',
    'natural_feature',
  ];

  /// Fetch all tourist attractions across Egypt
  Future<List<TouristAttraction>> fetchAllAttractions() async {
    try {
      // Check cache first
      final cached = await _getCachedAttractions();
      if (cached != null && cached.isNotEmpty) {
        print('Loaded ${cached.length} attractions from cache');
        return cached;
      }

      // Fetch from API
      List<TouristAttraction> allAttractions = [];

      // Search in each major city
      for (var cityEntry in egyptianCities.entries) {
        final cityName = cityEntry.key;
        final coords = cityEntry.value;

        print('Fetching attractions in $cityName...');

        final attractions = await _searchNearbyPlaces(
          latitude: coords['lat']!,
          longitude: coords['lng']!,
          city: cityName,
          radius: 50000, // 50km radius
        );

        allAttractions.addAll(attractions);
      }

      // Remove duplicates based on place_id
      final uniqueAttractions = _removeDuplicates(allAttractions);

      // Cache the results
      await _cacheAttractions(uniqueAttractions);

      print('Fetched ${uniqueAttractions.length} unique attractions');
      return uniqueAttractions;
    } catch (e) {
      print('Error fetching attractions: $e');
      rethrow;
    }
  }

  /// Search for places near a specific location
  Future<List<TouristAttraction>> _searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String city,
    int radius = 50000,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/place/nearbysearch/json',
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radius,
          'type': 'tourist_attraction',
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] as List;

        List<TouristAttraction> attractions = [];

        for (var place in results) {
          try {
            final attraction = _parsePlaceToAttraction(place, city);
            attractions.add(attraction);
          } catch (e) {
            print('Error parsing place: $e');
          }
        }

        return attractions;
      } else {
        throw Exception('Failed to fetch places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in nearby search: $e');
      return [];
    }
  }

  /// Get detailed information about a specific place
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'name,formatted_address,geometry,photos,rating,'
              'opening_hours,formatted_phone_number,website,reviews,types',
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        return response.data['result'];
      }
      return null;
    } catch (e) {
      print('Error fetching place details: $e');
      return null;
    }
  }

  /// Get photo URL for a place
  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
  }

  /// Parse Google Place to TouristAttraction model
  TouristAttraction _parsePlaceToAttraction(
    Map<String, dynamic> place,
    String city,
  ) {
    final geometry = place['geometry']['location'];
    final types = (place['types'] as List?)?.cast<String>() ?? [];

    // Determine category from types
    String category = _determineCategoryFromTypes(types);

    return TouristAttraction(
      id: place['place_id'] ?? '',
      name: place['name'] ?? 'Unknown',
      latitude: geometry['lat']?.toDouble() ?? 0.0,
      longitude: geometry['lng']?.toDouble() ?? 0.0,
      category: category,
      description: place['vicinity'] ?? '',
      city: city,
      rating: place['rating']?.toDouble(),
      userRatingsTotal: place['user_ratings_total'],
      photoReference: place['photos']?[0]?['photo_reference'],
      isOpen: place['opening_hours']?['open_now'],
      types: types,
    );
  }

  /// Determine category from Google Place types
  String _determineCategoryFromTypes(List<String> types) {
    if (types.contains('museum')) return 'Museum';
    if (types.contains('church') ||
        types.contains('mosque') ||
        types.contains('synagogue') ||
        types.contains('hindu_temple')) {
      return 'Religious';
    }
    if (types.contains('park') || types.contains('natural_feature')) {
      return 'Natural';
    }
    if (types.contains('art_gallery')) return 'Art & Culture';
    if (types.contains('shopping_mall') || types.contains('store')) {
      return 'Shopping';
    }
    if (types.contains('restaurant') || types.contains('cafe')) {
      return 'Food & Dining';
    }
    if (types.contains('lodging') || types.contains('resort')) {
      return 'Accommodation';
    }
    return 'Historical';
  }

  /// Remove duplicate attractions
  List<TouristAttraction> _removeDuplicates(
      List<TouristAttraction> attractions) {
    final seen = <String>{};
    return attractions.where((attraction) {
      if (seen.contains(attraction.id)) {
        return false;
      }
      seen.add(attraction.id);
      return true;
    }).toList();
  }

  /// Cache attractions locally
  Future<void> _cacheAttractions(List<TouristAttraction> attractions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = attractions.map((a) => a.toJson()).toList();
      await prefs.setString('cached_attractions', jsonEncode(jsonList));
      await prefs.setInt(
          'cache_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching attractions: $e');
    }
  }

  /// Get cached attractions
  Future<List<TouristAttraction>?> _getCachedAttractions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_attractions');
      final timestamp = prefs.getInt('cache_timestamp') ?? 0;

      // Check if cache is less than 24 hours old
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - timestamp;
      final maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      if (cached != null && cacheAge < maxAge) {
        final jsonList = jsonDecode(cached) as List;
        return jsonList
            .map((json) => TouristAttraction.fromJson(json))
            .toList();
      }

      return null;
    } catch (e) {
      print('Error reading cache: $e');
      return null;
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_attractions');
    await prefs.remove('cache_timestamp');
  }

  /// Search attractions by name or location
  Future<List<TouristAttraction>> searchAttractions(
    String query,
    List<TouristAttraction> allAttractions,
  ) async {
    final lowerQuery = query.toLowerCase();
    return allAttractions.where((attraction) {
      return attraction.name.toLowerCase().contains(lowerQuery) ||
          attraction.city.toLowerCase().contains(lowerQuery) ||
          attraction.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter attractions by category
  List<TouristAttraction> filterByCategory(
    List<TouristAttraction> attractions,
    String category,
  ) {
    if (category == 'All') return attractions;
    return attractions.where((a) => a.category == category).toList();
  }

  /// Filter attractions by city
  List<TouristAttraction> filterByCity(
    List<TouristAttraction> attractions,
    String city,
  ) {
    if (city == 'All') return attractions;
    return attractions.where((a) => a.city == city).toList();
  }

  /// Sort attractions by rating
  List<TouristAttraction> sortByRating(List<TouristAttraction> attractions) {
    final sorted = List<TouristAttraction>.from(attractions);
    sorted.sort((a, b) {
      final ratingA = a.rating ?? 0.0;
      final ratingB = b.rating ?? 0.0;
      return ratingB.compareTo(ratingA);
    });
    return sorted;
  }

  /// Get top rated attractions
  List<TouristAttraction> getTopRated(
    List<TouristAttraction> attractions, {
    int limit = 10,
  }) {
    final sorted = sortByRating(attractions);
    return sorted.take(limit).toList();
  }

  /// ✅ Search for a place near the tapped location (EXACTLY like Google Maps!)
  Future<TouristAttraction?> searchNearbyPlace(double lat, double lng) async {
    try {
      // Use Google Places Nearby Search with a small radius (50 meters)
      final response = await _dio.get(
        '$_baseUrl/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': '50', // Very small radius to get the exact place clicked
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          // Get the CLOSEST place (first result)
          final place = results[0];
          final placeId = place['place_id'] as String;
          
          // Fetch detailed information about this place
          final details = await getPlaceDetails(placeId);
          
          if (details != null) {
            // Convert to TouristAttraction
            return _convertPlaceToAttraction(place, details);
          }
        }
      }

      return null;
    } catch (e) {
      print('Error searching nearby place: $e');
      return null;
    }
  }

  /// Convert Google Place data to TouristAttraction
  TouristAttraction _convertPlaceToAttraction(
    Map<String, dynamic> place,
    Map<String, dynamic> details,
  ) {
    final location = place['geometry']['location'];
    final types = List<String>.from(place['types'] ?? []);
    
    // Determine category based on types
    String category = 'Landmark';
    if (types.contains('mosque')) {
      category = 'Religious';
    } else if (types.contains('church') || types.contains('synagogue')) {
      category = 'Religious';
    } else if (types.contains('museum')) {
      category = 'Museum';
    } else if (types.contains('shopping_mall') || types.contains('store')) {
      category = 'Shopping';
    } else if (types.contains('beach_resort') || types.contains('resort')) {
      category = 'Beach Resort';
    } else if (types.contains('park') || types.contains('natural_feature')) {
      category = 'Natural';
    } else if (types.contains('historical_landmark') || types.contains('historical')) {
      category = 'Historical';
    }

    return TouristAttraction(
      id: place['place_id'],
      name: place['name'] ?? 'Unknown Place',
      latitude: location['lat'].toDouble(),
      longitude: location['lng'].toDouble(),
      category: category,
      description: details['editorial_summary']?['overview'] ?? place['vicinity'] ?? '',
      city: _extractCityFromAddress(details['formatted_address'] ?? ''),
      rating: place['rating']?.toDouble(),
      userRatingsTotal: place['user_ratings_total'],
      photoReference: place['photos']?[0]?['photo_reference'],
      isOpen: place['opening_hours']?['open_now'],
      types: types,
      address: details['formatted_address'],
      phoneNumber: details['formatted_phone_number'],
      website: details['website'],
    );
  }

  /// Extract city name from formatted address
  String _extractCityFromAddress(String address) {
    // Try to extract Egyptian city from address
    for (var city in egyptianCities.keys) {
      if (address.contains(city)) {
        return city;
      }
    }
    return 'Egypt'; // Default fallback
  }
}
