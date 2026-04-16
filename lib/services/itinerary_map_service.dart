import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../models/itinerary.dart';
import '../models/itinerary_event.dart';
import 'directions_service.dart';

/// Service for visualizing itineraries on the map
class ItineraryMapService {
  final DirectionsService _directionsService = DirectionsService();

  /// Get all POI positions for a specific day
  List<ItineraryMapPoint> getPointsForDay(Itinerary itinerary, int day) {
    final events = itinerary.days[day];
    if (events == null || events.isEmpty) return [];

    return events.asMap().entries.map((entry) {
      final index = entry.key;
      final event = entry.value;
      return ItineraryMapPoint(
        position: Position(event.poi.lon, event.poi.lat),
        name: event.poi.name,
        category: event.poi.category,
        orderNumber: index + 1,
        startTime: event.startTime,
        endTime: event.endTime,
        duration: event.poi.durationHours,
        cost: event.poi.cost,
        description: event.poi.description,
        photoUrl: event.poi.photoUrl,
        event: event,
      );
    }).toList();
  }

  /// Get all POI positions for entire itinerary
  Map<int, List<ItineraryMapPoint>> getAllPoints(Itinerary itinerary) {
    final Map<int, List<ItineraryMapPoint>> allPoints = {};
    
    for (final day in itinerary.sortedDays) {
      allPoints[day] = getPointsForDay(itinerary, day);
    }
    
    return allPoints;
  }

  /// Calculate route between consecutive POIs for a day
  Future<List<Position>> getRouteForDay(Itinerary itinerary, int day) async {
    final points = getPointsForDay(itinerary, day);
    if (points.length < 2) return [];

    List<Position> fullRoute = [];

    for (int i = 0; i < points.length - 1; i++) {
      final origin = points[i];
      final destination = points[i + 1];

      try {
        final directions = await _directionsService.getDirections(
          originLat: origin.position.lat.toDouble(),
          originLng: origin.position.lng.toDouble(),
          destLat: destination.position.lat.toDouble(),
          destLng: destination.position.lng.toDouble(),
          mode: 'driving',
        );

        if (directions != null) {
          fullRoute.addAll(directions.routePoints);
        }
      } catch (e) {
        print('Error getting route segment: $e');
        // Fallback: draw straight line
        fullRoute.add(origin.position);
        fullRoute.add(destination.position);
      }
    }

    return fullRoute;
  }

  /// Get color for day (for multi-day visualization)
  Color getColorForDay(int day) {
    final colors = [
      const Color(0xFF3498DB), // Blue
      const Color(0xFFE67E22), // Orange
      const Color(0xFF9B59B6), // Purple
      const Color(0xFF27AE60), // Green
      const Color(0xFFE74C3C), // Red
      const Color(0xFF1ABC9C), // Teal
      const Color(0xFFF39C12), // Yellow
    ];
    return colors[(day - 1) % colors.length];
  }

  /// Get color for time of day
  Color getColorForTimeOfDay(String startTime) {
    try {
      final hour = int.parse(startTime.split(':')[0]);
      if (hour < 12) {
        return const Color(0xFF3498DB); // Morning - Blue
      } else if (hour < 17) {
        return const Color(0xFFF39C12); // Afternoon - Orange
      } else {
        return const Color(0xFF9B59B6); // Evening - Purple
      }
    } catch (e) {
      return const Color(0xFF3498DB);
    }
  }

  /// Calculate bounds to fit all points
  CameraOptions getCameraOptionsForPoints(List<ItineraryMapPoint> points) {
    if (points.isEmpty) {
      return CameraOptions(
        center: Point(coordinates: Position(31.2357, 30.0444)), // Cairo default
        zoom: 12.0,
      );
    }

    if (points.length == 1) {
      return CameraOptions(
        center: Point(coordinates: points[0].position),
        zoom: 14.0,
      );
    }

    double minLat = points[0].position.lat.toDouble();
    double maxLat = points[0].position.lat.toDouble();
    double minLng = points[0].position.lng.toDouble();
    double maxLng = points[0].position.lng.toDouble();

    for (var point in points) {
      final lat = point.position.lat.toDouble();
      final lng = point.position.lng.toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom;
    if (maxDiff > 0.5) {
      zoom = 9.0;
    } else if (maxDiff > 0.2) {
      zoom = 10.5;
    } else if (maxDiff > 0.1) {
      zoom = 11.5;
    } else if (maxDiff > 0.05) {
      zoom = 12.5;
    } else {
      zoom = 13.5;
    }

    return CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: zoom,
    );
  }

  /// Get estimated travel time between two points (in minutes)
  Future<int?> getTravelTimeBetween(
    ItineraryMapPoint origin,
    ItineraryMapPoint destination,
  ) async {
    try {
      final directions = await _directionsService.getDirections(
        originLat: origin.position.lat.toDouble(),
        originLng: origin.position.lng.toDouble(),
        destLat: destination.position.lat.toDouble(),
        destLng: destination.position.lng.toDouble(),
        mode: 'driving',
      );

      if (directions != null) {
        // Parse duration string (e.g., "15 mins" or "1 hour 30 mins")
        final durationStr = directions.duration;
        final regex = RegExp(r'(\d+)\s*(hour|min)');
        final matches = regex.allMatches(durationStr);
        
        int totalMinutes = 0;
        for (var match in matches) {
          final value = int.parse(match.group(1)!);
          final unit = match.group(2);
          if (unit == 'hour') {
            totalMinutes += value * 60;
          } else {
            totalMinutes += value;
          }
        }
        return totalMinutes;
      }
    } catch (e) {
      print('Error getting travel time: $e');
    }
    return null;
  }

  /// Optimize route order (simple nearest-neighbor algorithm)
  List<ItineraryMapPoint> optimizeRoute(
    List<ItineraryMapPoint> points,
    Position? startPosition,
  ) {
    if (points.length <= 2) return points;

    List<ItineraryMapPoint> optimized = [];
    List<ItineraryMapPoint> remaining = List.from(points);

    // Start from user's location or first point
    Position currentPos = startPosition ?? points[0].position;

    while (remaining.isNotEmpty) {
      // Find nearest point
      ItineraryMapPoint? nearest;
      double minDistance = double.infinity;

      for (var point in remaining) {
        final distance = _calculateDistance(
          currentPos.lat.toDouble(),
          currentPos.lng.toDouble(),
          point.position.lat.toDouble(),
          point.position.lng.toDouble(),
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = point;
        }
      }

      if (nearest != null) {
        optimized.add(nearest);
        remaining.remove(nearest);
        currentPos = nearest.position;
      }
    }

    // Renumber the points
    for (int i = 0; i < optimized.length; i++) {
      optimized[i] = ItineraryMapPoint(
        position: optimized[i].position,
        name: optimized[i].name,
        category: optimized[i].category,
        orderNumber: i + 1,
        startTime: optimized[i].startTime,
        endTime: optimized[i].endTime,
        duration: optimized[i].duration,
        cost: optimized[i].cost,
        description: optimized[i].description,
        photoUrl: optimized[i].photoUrl,
        event: optimized[i].event,
      );
    }

    return optimized;
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
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

class ItineraryMapPoint {
  final Position position;
  final String name;
  final String category;
  final int orderNumber;
  final String startTime;
  final String endTime;
  final double duration;
  final double cost;
  final String description;
  final String? photoUrl;
  final ItineraryEvent event;

  ItineraryMapPoint({
    required this.position,
    required this.name,
    required this.category,
    required this.orderNumber,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.cost,
    required this.description,
    this.photoUrl,
    required this.event,
  });

  String get timeRange => '$startTime - $endTime';
  
  String get formattedDuration {
    if (duration < 1) {
      return '${(duration * 60).round()} mins';
    } else if (duration == 1) {
      return '1 hour';
    } else {
      final hours = duration.floor();
      final mins = ((duration - hours) * 60).round();
      if (mins == 0) {
        return '$hours hours';
      }
      return '$hours hrs $mins mins';
    }
  }

  String get formattedCost {
    if (cost == 0) return 'Free';
    return '${cost.toStringAsFixed(0)} EGP';
  }
}
