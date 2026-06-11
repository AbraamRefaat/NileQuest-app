import 'package:dio/dio.dart';

class GooglePlacesPhotoService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';

  // In-memory caches to save API costs and improve performance
  final Map<String, String> _singlePhotoCache = {};
  final Map<String, List<String>> _multiPhotoCache = {};

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Main entry point to get a single photo for a place
  Future<String?> getPlacePhotoUrl(String placeName, double lat, double lng) async {
    final cacheKey = '${placeName.toLowerCase()}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    if (_singlePhotoCache.containsKey(cacheKey)) {
      return _singlePhotoCache[cacheKey];
    }

    // 1️⃣ Try Google Places Nearby Search
    try {
      final response = await _dio.get(
        '$_baseUrl/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': '200',
          'keyword': placeName,
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final photos = results[0]['photos'] as List?;
            if (photos != null && photos.isNotEmpty) {
              final url = getPhotoUrl(photos[0]['photo_reference']);
              _singlePhotoCache[cacheKey] = url;
              return url;
            }
          }
        }
      }
    } catch (e) {
      _logError('NearbySearch', placeName, e);
    }

    // 2️⃣ Fallback: Wikipedia
    final wikiUrl = await _getWikipediaPhotoUrl(placeName);
    if (wikiUrl != null) {
      _singlePhotoCache[cacheKey] = wikiUrl;
      return wikiUrl;
    }

    // 3️⃣ Final Fallback: Category-based placeholder
    return _getPlaceholderUrl(placeName);
  }

  /// Construct the actual Google Photos URL from a reference
  String getPhotoUrl(String photoReference, {int maxWidth = 800}) {
    return '$_baseUrl/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
  }

  /// Search for a place by name and city to get its photo
  Future<String?> searchPlaceAndGetPhoto(String placeName, {String? city}) async {
    final cacheKey = 'search_${placeName.toLowerCase()}_${city?.toLowerCase() ?? 'none'}';
    if (_singlePhotoCache.containsKey(cacheKey)) {
      return _singlePhotoCache[cacheKey];
    }

    try {
      String query = placeName;
      if (city != null) {
        query = '$placeName, $city, Egypt';
      }

      final response = await _dio.get(
        '$_baseUrl/place/findplacefromtext/json',
        queryParameters: {
          'input': query,
          'inputtype': 'textquery',
          'fields': 'photos,place_id,name,geometry',
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final candidates = data['candidates'] as List;
          if (candidates.isNotEmpty) {
            final photos = candidates[0]['photos'] as List?;
            if (photos != null && photos.isNotEmpty) {
              final url = getPhotoUrl(photos[0]['photo_reference']);
              _singlePhotoCache[cacheKey] = url;
              return url;
            }
          }
        }
      }
    } catch (e) {
      _logError('FindPlace', placeName, e);
    }

    final wikiUrl = await _getWikipediaPhotoUrl(placeName);
    if (wikiUrl != null) {
      _singlePhotoCache[cacheKey] = wikiUrl;
      return wikiUrl;
    }

    return _getPlaceholderUrl(placeName);
  }

  /// Fetch image from Wikipedia/Wikimedia Commons as a reliable fallback
  Future<String?> _getWikipediaPhotoUrl(String placeName) async {
    try {
      final searchResponse = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'list': 'search',
          'srsearch': '$placeName Egypt',
          'srlimit': '1',
          'format': 'json',
          'origin': '*',
        },
      );

      if (searchResponse.statusCode == 200) {
        final results = searchResponse.data['query']?['search'] as List?;
        if (results != null && results.isNotEmpty) {
          final pageTitle = results[0]['title'] as String;

          final imageResponse = await _dio.get(
            'https://en.wikipedia.org/w/api.php',
            queryParameters: {
              'action': 'query',
              'titles': pageTitle,
              'prop': 'pageimages',
              'pithumbsize': '800',
              'format': 'json',
              'origin': '*',
            },
          );

          if (imageResponse.statusCode == 200) {
            final pages = imageResponse.data['query']?['pages'] as Map?;
            if (pages != null && pages.isNotEmpty) {
              final page = pages.values.first;
              final thumbnail = page['thumbnail'];
              if (thumbnail != null) {
                return thumbnail['source'] as String?;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Wikipedia error for "$placeName": $e');
    }
    return null;
  }

  /// Get multiple photos for a gallery view
  Future<List<String>> getMultiplePlacePhotos(
    String placeName,
    double lat,
    double lng, {
    int maxPhotos = 5,
  }) async {
    final cacheKey = 'multi_${placeName.toLowerCase()}_$lat-$lng';
    if (_multiPhotoCache.containsKey(cacheKey)) {
      return _multiPhotoCache[cacheKey]!;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': '200',
          'keyword': placeName,
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final photos = results[0]['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final photoUrls = photos
                .take(maxPhotos)
                .map((p) => getPhotoUrl(p['photo_reference']))
                .toList();
            _multiPhotoCache[cacheKey] = photoUrls;
            return photoUrls;
          }
        }
      }
    } catch (e) {
      _logError('MultiPhotos', placeName, e);
    }

    final wikiUrl = await _getWikipediaPhotoUrl(placeName);
    return wikiUrl != null ? [wikiUrl] : [_getPlaceholderUrl(placeName)];
  }

  /// Simple placeholder logic based on keywords in the place name
  String _getPlaceholderUrl(String placeName) {
    final lowerName = placeName.toLowerCase();
    String category = 'travel'; // Default

    if (lowerName.contains('restaurant') || lowerName.contains('food') || lowerName.contains('cafe')) {
      category = 'food';
    } else if (lowerName.contains('museum') || lowerName.contains('temple') || lowerName.contains('pyramid')) {
      category = 'history';
    } else if (lowerName.contains('park') || lowerName.contains('garden') || lowerName.contains('nature')) {
      category = 'nature';
    } else if (lowerName.contains('hotel') || lowerName.contains('resort')) {
      category = 'hotel';
    }

    // Using Unsplash Source (reliable for placeholders)
    return 'https://source.unsplash.com/featured/800x600/?egypt,$category';
  }

  /// Centralized error logging
  void _logError(String method, String place, dynamic error) {
    if (error is DioException) {
      print('GooglePlacesPhotoService [$method] timeout or network error for "$place": ${error.type}');
    } else {
      print('GooglePlacesPhotoService [$method] unexpected error for "$place": $error');
    }
  }
}
