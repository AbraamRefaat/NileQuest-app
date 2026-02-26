import 'package:dio/dio.dart';

class NavigationSDKService {
  static const String _apiKey = 'AIzaSyBCzhyILiS8FlaBqWepcZpUJNTra-ce3Do';
  static const String _baseUrl = 'https://routes.googleapis.com/directions/v2:computeRoutes';
  
  final Dio _dio = Dio();

  /// Get advanced route with Navigation SDK
  /// Includes: traffic, tolls, lane guidance, speed limits
  Future<NavigationRoute?> getNavigationRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String travelMode = 'DRIVE', // DRIVE, WALK, BICYCLE, TWO_WHEELER
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = false,
  }) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline,'
                'routes.legs.steps,routes.legs.localizedValues,'
                'routes.travelAdvisory,routes.legs.steps.navigationInstruction,'
                'routes.legs.steps.localizedValues',
          },
        ),
        data: {
          'origin': {
            'location': {
              'latLng': {
                'latitude': originLat,
                'longitude': originLng,
              },
            },
          },
          'destination': {
            'location': {
              'latLng': {
                'latitude': destLat,
                'longitude': destLng,
              },
            },
          },
          'travelMode': travelMode,
          'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
          'computeAlternativeRoutes': true,
          'routeModifiers': {
            'avoidTolls': avoidTolls,
            'avoidHighways': avoidHighways,
            'avoidFerries': avoidFerries,
          },
          'languageCode': 'en-US',
          'units': 'METRIC',
        },
      );

      if (response.statusCode == 200) {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          return NavigationRoute.fromJson(routes[0]);
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting navigation route: $e');
      return null;
    }
  }

  /// Get multiple route alternatives
  Future<List<NavigationRoute>> getRouteAlternatives({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String travelMode = 'DRIVE',
  }) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline,'
                'routes.legs.steps,routes.legs.localizedValues,routes.description,'
                'routes.warnings,routes.travelAdvisory',
          },
        ),
        data: {
          'origin': {
            'location': {
              'latLng': {
                'latitude': originLat,
                'longitude': originLng,
              },
            },
          },
          'destination': {
            'location': {
              'latLng': {
                'latitude': destLat,
                'longitude': destLng,
              },
            },
          },
          'travelMode': travelMode,
          'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
          'computeAlternativeRoutes': true,
          'languageCode': 'en-US',
          'units': 'METRIC',
        },
      );

      if (response.statusCode == 200) {
        final routes = response.data['routes'] as List;
        return routes.map((route) => NavigationRoute.fromJson(route)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting route alternatives: $e');
      return [];
    }
  }

  /// Decode polyline from Navigation SDK
  List<Map<String, double>> decodePolyline(String encoded) {
    List<Map<String, double>> points = [];
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

      points.add({
        'latitude': lat / 1E5,
        'longitude': lng / 1E5,
      });
    }

    return points;
  }
}

class NavigationRoute {
  final String duration;
  final int distanceMeters;
  final String polyline;
  final List<NavigationStep> steps;
  final String? description;
  final List<String> warnings;
  final TrafficAdvisory? trafficAdvisory;

  NavigationRoute({
    required this.duration,
    required this.distanceMeters,
    required this.polyline,
    required this.steps,
    this.description,
    required this.warnings,
    this.trafficAdvisory,
  });

  String get distanceText => '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  String get durationText => _formatDuration(duration);

  String _formatDuration(String duration) {
    // Parse duration like "1200s" or "PT1H30M"
    if (duration.endsWith('s')) {
      final seconds = int.tryParse(duration.replaceAll('s', '')) ?? 0;
      final minutes = (seconds / 60).round();
      if (minutes < 60) {
        return '$minutes min';
      }
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
    return duration;
  }

  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    final legs = json['legs'] as List? ?? [];
    List<NavigationStep> allSteps = [];
    
    for (var leg in legs) {
      final steps = leg['steps'] as List? ?? [];
      for (var step in steps) {
        allSteps.add(NavigationStep.fromJson(step));
      }
    }

    return NavigationRoute(
      duration: json['duration'] ?? '0s',
      distanceMeters: json['distanceMeters'] ?? 0,
      polyline: json['polyline']?['encodedPolyline'] ?? '',
      steps: allSteps,
      description: json['description'],
      warnings: (json['warnings'] as List?)?.cast<String>() ?? [],
      trafficAdvisory: json['travelAdvisory'] != null
          ? TrafficAdvisory.fromJson(json['travelAdvisory'])
          : null,
    );
  }
}

class NavigationStep {
  final String instruction;
  final int distanceMeters;
  final String duration;
  final String? maneuver;
  final Map<String, double> startLocation;
  final Map<String, double> endLocation;

  NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.duration,
    this.maneuver,
    required this.startLocation,
    required this.endLocation,
  });

  String get distanceText => '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    final navInstruction = json['navigationInstruction'];
    final startLoc = json['startLocation']?['latLng'] ?? {};
    final endLoc = json['endLocation']?['latLng'] ?? {};

    return NavigationStep(
      instruction: navInstruction?['instructions'] ?? 
                   json['localizedValues']?['staticDuration']?['text'] ?? 
                   'Continue',
      distanceMeters: json['distanceMeters'] ?? 0,
      duration: json['staticDuration'] ?? '0s',
      maneuver: navInstruction?['maneuver'],
      startLocation: {
        'latitude': startLoc['latitude'] ?? 0.0,
        'longitude': startLoc['longitude'] ?? 0.0,
      },
      endLocation: {
        'latitude': endLoc['latitude'] ?? 0.0,
        'longitude': endLoc['longitude'] ?? 0.0,
      },
    );
  }
}

class TrafficAdvisory {
  final String? speedReadingIntervals;
  final String? fuelConsumption;

  TrafficAdvisory({
    this.speedReadingIntervals,
    this.fuelConsumption,
  });

  factory TrafficAdvisory.fromJson(Map<String, dynamic> json) {
    return TrafficAdvisory(
      speedReadingIntervals: json['speedReadingIntervals']?.toString(),
      fuelConsumption: json['fuelConsumptionMicroliters']?.toString(),
    );
  }
}
