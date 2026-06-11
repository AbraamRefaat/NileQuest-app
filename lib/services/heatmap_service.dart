import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';

/// Service for generating heatmaps (crowd density, popular times, safety zones)
class HeatmapService {
  static const String _googleApiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';
  final Dio _dio = Dio();

  /// Get popular times heatmap data for an area
  Future<List<HeatmapPoint>> getPopularTimesHeatmap({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    List<HeatmapPoint> heatmapPoints = [];

    try {
      // Search for places in the area
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$centerLat,$centerLng',
          'radius': radiusKm * 1000,
          'type': 'tourist_attraction',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;

        for (var place in results) {
          final placeId = place['place_id'];
          
          // Get place details for popular times
          final detailsResponse = await _dio.get(
            'https://maps.googleapis.com/maps/api/place/details/json',
            queryParameters: {
              'place_id': placeId,
              'fields': 'name,geometry,rating,user_ratings_total',
              'key': _googleApiKey,
            },
          );

          if (detailsResponse.statusCode == 200) {
            final details = detailsResponse.data['result'];
            final userRatingsTotal = details['user_ratings_total'] ?? 0;
            final rating = details['rating'] ?? 0.0;

            // Calculate crowd intensity based on ratings and popularity
            final intensity = _calculateCrowdIntensity(
              userRatingsTotal,
              rating.toDouble(),
            );

            heatmapPoints.add(HeatmapPoint(
              lat: details['geometry']['location']['lat'],
              lng: details['geometry']['location']['lng'],
              intensity: intensity,
              type: HeatmapType.crowdDensity,
              name: details['name'],
              description: 'Based on $userRatingsTotal reviews',
            ));
          }

          // Rate limiting
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      print('Error fetching popular times heatmap: $e');
    }

    return heatmapPoints;
  }

  /// Get safety heatmap (well-lit areas, tourist-friendly zones)
  Future<List<HeatmapPoint>> getSafetyHeatmap({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    List<HeatmapPoint> safetyPoints = [];

    try {
      // Get police stations
      final policeResponse = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$centerLat,$centerLng',
          'radius': radiusKm * 1000,
          'type': 'police',
          'key': _googleApiKey,
        },
      );

      if (policeResponse.statusCode == 200 && policeResponse.data['status'] == 'OK') {
        final results = policeResponse.data['results'] as List;
        
        for (var place in results) {
          // Create safety zones around police stations (500m radius)
          safetyPoints.add(HeatmapPoint(
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            intensity: 0.8, // High safety
            type: HeatmapType.safety,
            name: place['name'],
            description: 'Police station nearby',
            radiusMeters: 500,
          ));
        }
      }

      // Get tourist attractions (generally safe areas)
      final attractionsResponse = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$centerLat,$centerLng',
          'radius': radiusKm * 1000,
          'type': 'tourist_attraction',
          'key': _googleApiKey,
        },
      );

      if (attractionsResponse.statusCode == 200 && attractionsResponse.data['status'] == 'OK') {
        final results = attractionsResponse.data['results'] as List;
        
        for (var place in results) {
          final rating = place['rating'] ?? 0.0;
          final userRatingsTotal = place['user_ratings_total'] ?? 0;

          // High-rated tourist areas are generally safer
          if (rating >= 4.0 && userRatingsTotal > 100) {
            safetyPoints.add(HeatmapPoint(
              lat: place['geometry']['location']['lat'],
              lng: place['geometry']['location']['lng'],
              intensity: 0.6, // Moderate safety
              type: HeatmapType.safety,
              name: place['name'],
              description: 'Popular tourist area',
              radiusMeters: 300,
            ));
          }
        }
      }
    } catch (e) {
      print('Error fetching safety heatmap: $e');
    }

    return safetyPoints;
  }

  /// Get price heatmap (expensive vs budget-friendly areas)
  Future<List<HeatmapPoint>> getPriceHeatmap({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    List<HeatmapPoint> pricePoints = [];

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$centerLat,$centerLng',
          'radius': radiusKm * 1000,
          'type': 'restaurant',
          'key': _googleApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;

        for (var place in results) {
          final priceLevel = place['price_level'] ?? 2;
          
          // Convert price level to intensity (1-4 scale)
          final intensity = priceLevel / 4.0;

          pricePoints.add(HeatmapPoint(
            lat: place['geometry']['location']['lat'],
            lng: place['geometry']['location']['lng'],
            intensity: intensity,
            type: HeatmapType.price,
            name: place['name'],
            description: _getPriceLevelDescription(priceLevel),
            radiusMeters: 200,
          ));
        }
      }
    } catch (e) {
      print('Error fetching price heatmap: $e');
    }

    return pricePoints;
  }

  /// Generate grid-based heatmap for visualization
  List<HeatmapCell> generateHeatmapGrid({
    required List<HeatmapPoint> points,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int gridSize = 20,
  }) {
    List<HeatmapCell> cells = [];
    
    final latStep = (maxLat - minLat) / gridSize;
    final lngStep = (maxLng - minLng) / gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final cellLat = minLat + (i * latStep) + (latStep / 2);
        final cellLng = minLng + (j * lngStep) + (lngStep / 2);

        // Calculate intensity based on nearby points
        double totalIntensity = 0.0;
        int contributingPoints = 0;

        for (var point in points) {
          final distance = _calculateDistance(
            cellLat,
            cellLng,
            point.lat,
            point.lng,
          );

          // Points within radius contribute to cell intensity
          if (distance * 1000 <= (point.radiusMeters ?? 500)) {
            // Use inverse distance weighting
            final weight = 1.0 - (distance * 1000 / (point.radiusMeters ?? 500));
            totalIntensity += point.intensity * weight;
            contributingPoints++;
          }
        }

        if (contributingPoints > 0) {
          final avgIntensity = totalIntensity / contributingPoints;
          cells.add(HeatmapCell(
            lat: cellLat,
            lng: cellLng,
            intensity: avgIntensity.clamp(0.0, 1.0),
            size: latStep,
          ));
        }
      }
    }

    return cells;
  }

  /// Get color for heatmap intensity
  Color getHeatmapColor(double intensity, HeatmapType type) {
    switch (type) {
      case HeatmapType.crowdDensity:
        // Green (low) -> Yellow -> Red (high)
        if (intensity < 0.33) {
          return Color.lerp(Colors.green, Colors.yellow, intensity * 3)!;
        } else if (intensity < 0.66) {
          return Color.lerp(Colors.yellow, Colors.orange, (intensity - 0.33) * 3)!;
        } else {
          return Color.lerp(Colors.orange, Colors.red, (intensity - 0.66) * 3)!;
        }

      case HeatmapType.safety:
        // Red (unsafe) -> Yellow -> Green (safe)
        if (intensity < 0.33) {
          return Color.lerp(Colors.red, Colors.orange, intensity * 3)!;
        } else if (intensity < 0.66) {
          return Color.lerp(Colors.orange, Colors.yellow, (intensity - 0.33) * 3)!;
        } else {
          return Color.lerp(Colors.yellow, Colors.green, (intensity - 0.66) * 3)!;
        }

      case HeatmapType.price:
        // Green (cheap) -> Yellow -> Red (expensive)
        if (intensity < 0.33) {
          return Color.lerp(Colors.green, Colors.yellow, intensity * 3)!;
        } else if (intensity < 0.66) {
          return Color.lerp(Colors.yellow, Colors.orange, (intensity - 0.33) * 3)!;
        } else {
          return Color.lerp(Colors.orange, Colors.red, (intensity - 0.66) * 3)!;
        }

      case HeatmapType.photoPopularity:
        // Blue (low) -> Purple -> Pink (high)
        if (intensity < 0.5) {
          return Color.lerp(Colors.blue, Colors.purple, intensity * 2)!;
        } else {
          return Color.lerp(Colors.purple, Colors.pink, (intensity - 0.5) * 2)!;
        }
    }
  }

  /// Calculate crowd intensity from ratings data
  double _calculateCrowdIntensity(int userRatingsTotal, double rating) {
    // More reviews = more popular = more crowded
    // High rating also indicates popularity
    
    final popularityScore = (userRatingsTotal / 1000).clamp(0.0, 1.0);
    final ratingScore = (rating / 5.0).clamp(0.0, 1.0);
    
    // Weighted average (70% popularity, 30% rating)
    return (popularityScore * 0.7 + ratingScore * 0.3).clamp(0.0, 1.0);
  }

  String _getPriceLevelDescription(int priceLevel) {
    switch (priceLevel) {
      case 0:
        return 'Free';
      case 1:
        return 'Budget-friendly (\$)';
      case 2:
        return 'Moderate (\$\$)';
      case 3:
        return 'Expensive (\$\$\$)';
      case 4:
        return 'Very Expensive (\$\$\$\$)';
      default:
        return 'Unknown';
    }
  }

  /// Get best time to visit based on heatmap data
  String getBestTimeToVisit(List<HeatmapPoint> crowdData) {
    if (crowdData.isEmpty) return 'Anytime';

    final avgIntensity = crowdData.fold<double>(
      0.0,
      (sum, point) => sum + point.intensity,
    ) / crowdData.length;

    if (avgIntensity > 0.7) {
      return 'Very crowded. Visit early morning (6-8 AM) or late evening (6-8 PM)';
    } else if (avgIntensity > 0.5) {
      return 'Moderately crowded. Best times: 8-10 AM or 4-6 PM';
    } else if (avgIntensity > 0.3) {
      return 'Light crowds. Most times are good';
    } else {
      return 'Not crowded. Visit anytime';
    }
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
    return degrees * (math.pi / 180.0);
  }
}

enum HeatmapType {
  crowdDensity,
  safety,
  price,
  photoPopularity,
}

class HeatmapPoint {
  final double lat;
  final double lng;
  final double intensity; // 0.0 to 1.0
  final HeatmapType type;
  final String name;
  final String description;
  final double? radiusMeters;

  HeatmapPoint({
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.type,
    required this.name,
    required this.description,
    this.radiusMeters,
  });

  Position get position => Position(lng, lat);
}

class HeatmapCell {
  final double lat;
  final double lng;
  final double intensity;
  final double size;

  HeatmapCell({
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.size,
  });

  Position get position => Position(lng, lat);
}
