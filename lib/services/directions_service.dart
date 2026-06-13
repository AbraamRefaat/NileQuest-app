import 'package:dio/dio.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';
  
  final Dio _dio = Dio();

  /// Get directions from origin to destination
  Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving', // driving, walking, bicycling, transit
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'mode': mode,
          'key': _apiKey,
          'alternatives': true, // Get alternative routes
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        return DirectionsResult.fromJson(response.data);
      }
      
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  /// Get multiple route options
  Future<List<DirectionsResult>> getAlternativeRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'mode': mode,
          'alternatives': true,
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final routes = response.data['routes'] as List;
        return routes.map((route) {
          return DirectionsResult.fromJsonRoute(route);
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting alternative routes: $e');
      return [];
    }
  }

  /// Decode polyline string to list of coordinates
  List<Position> decodePolyline(String encoded) {
    List<Position> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(Position(lng / 1E5, lat / 1E5));
    }

    return points;
  }
}

class DirectionsResult {
  final String summary;
  final String duration;
  final String distance;
  // Numeric totals straight from the API — used for live ETA math
  final int? distanceMeters;
  final int? durationSeconds;
  final List<Position> routePoints;
  final List<DirectionStep> steps;

  DirectionsResult({
    required this.summary,
    required this.duration,
    required this.distance,
    this.distanceMeters,
    this.durationSeconds,
    required this.routePoints,
    required this.steps,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) =>
      DirectionsResult.fromJsonRoute(json['routes'][0]);

  factory DirectionsResult.fromJsonRoute(Map<String, dynamic> route) {
    final leg = route['legs'][0];

    final service = DirectionsService();
    final polyline = route['overview_polyline']['points'] as String;
    final points = service.decodePolyline(polyline);

    final steps = (leg['steps'] as List).map((step) {
      final end = step['end_location'];
      return DirectionStep(
        instruction: step['html_instructions'] ?? '',
        distance: step['distance']?['text'] ?? '',
        duration: step['duration']?['text'] ?? '',
        maneuver: step['maneuver'] ?? '',
        endLat: (end?['lat'] as num?)?.toDouble(),
        endLng: (end?['lng'] as num?)?.toDouble(),
        distanceMeters: step['distance']?['value'] as int?,
      );
    }).toList();

    return DirectionsResult(
      summary: route['summary'] ?? '',
      duration: leg['duration']?['text'] ?? '',
      distance: leg['distance']?['text'] ?? '',
      distanceMeters: leg['distance']?['value'] as int?,
      durationSeconds: leg['duration']?['value'] as int?,
      routePoints: points,
      steps: steps,
    );
  }
}

class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final String maneuver;
  // Where this step ends — i.e. where the NEXT maneuver happens
  final double? endLat;
  final double? endLng;
  final int? distanceMeters;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
    this.endLat,
    this.endLng,
    this.distanceMeters,
  });

  /// Instruction with the HTML tags stripped ("Turn <b>right</b>…" → plain)
  String get plainInstruction => instruction
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
