import 'package:dio/dio.dart';
import '../models/tourist_attraction.dart';

class DistanceMatrixService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';
  
  final Dio _dio = Dio();

  /// Get distances from origin to multiple destinations
  Future<List<AttractionWithDistance>> getDistancesToAttractions({
    required double originLat,
    required double originLng,
    required List<TouristAttraction> attractions,
    String mode = 'driving',
  }) async {
    try {
      // Google Distance Matrix API has a limit of 25 destinations per request
      List<AttractionWithDistance> results = [];
      
      // Process in batches of 25
      for (int i = 0; i < attractions.length; i += 25) {
        final batch = attractions.sublist(
          i,
          i + 25 > attractions.length ? attractions.length : i + 25,
        );
        
        final destinations = batch
            .map((a) => '${a.latitude},${a.longitude}')
            .join('|');

        final response = await _dio.get(
          '$_baseUrl/distancematrix/json',
          queryParameters: {
            'origins': '$originLat,$originLng',
            'destinations': destinations,
            'mode': mode,
            'key': _apiKey,
          },
        );

        if (response.statusCode == 200 && response.data['status'] == 'OK') {
          final rows = response.data['rows'][0]['elements'] as List;
          
          for (int j = 0; j < rows.length; j++) {
            final element = rows[j];
            if (element['status'] == 'OK') {
              results.add(AttractionWithDistance(
                attraction: batch[j],
                distanceText: element['distance']['text'],
                distanceValue: element['distance']['value'], // meters
                durationText: element['duration']['text'],
                durationValue: element['duration']['value'], // seconds
              ));
            }
          }
        }
      }
      
      return results;
    } catch (e) {
      print('Error getting distances: $e');
      return [];
    }
  }

  /// Get nearby attractions within a radius
  Future<List<AttractionWithDistance>> getNearbyAttractions({
    required double originLat,
    required double originLng,
    required List<TouristAttraction> allAttractions,
    required double radiusKm,
    String mode = 'driving',
  }) async {
    // Filter attractions by approximate distance first
    final nearby = allAttractions.where((attraction) {
      final distance = _calculateApproximateDistance(
        originLat,
        originLng,
        attraction.latitude,
        attraction.longitude,
      );
      return distance <= radiusKm;
    }).toList();

    // Get accurate distances
    final withDistances = await getDistancesToAttractions(
      originLat: originLat,
      originLng: originLng,
      attractions: nearby,
      mode: mode,
    );

    // Sort by distance
    withDistances.sort((a, b) => a.distanceValue.compareTo(b.distanceValue));

    return withDistances;
  }

  /// Calculate approximate distance in km (Haversine formula)
  double _calculateApproximateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = 
        (dLat / 2).abs() * (dLat / 2).abs() +
        (lon1).abs() * (lat2).abs() *
        (dLon / 2).abs() * (dLon / 2).abs();

    final c = 2 * (a.abs() + (1 - a).abs());

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180;
  }
}

class AttractionWithDistance {
  final TouristAttraction attraction;
  final String distanceText;
  final int distanceValue; // meters
  final String durationText;
  final int durationValue; // seconds

  AttractionWithDistance({
    required this.attraction,
    required this.distanceText,
    required this.distanceValue,
    required this.durationText,
    required this.durationValue,
  });

  double get distanceInKm => distanceValue / 1000.0;
  int get durationInMinutes => (durationValue / 60).round();
}
