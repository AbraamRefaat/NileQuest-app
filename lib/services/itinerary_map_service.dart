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

  /// Calculate route between consecutive POIs for a day. Every pair of
  /// stops is always connected: when the directions API fails or returns
  /// nothing, the segment falls back to a straight line so the trip never
  /// shows up as disconnected dots.
  Future<List<Position>> getRouteForDay(Itinerary itinerary, int day) async {
    final points = getPointsForDay(itinerary, day);
    if (points.length < 2) return [];

    List<Position> fullRoute = [];

    for (int i = 0; i < points.length - 1; i++) {
      final origin = points[i];
      final destination = points[i + 1];

      List<Position>? segment;
      try {
        final directions = await _directionsService.getDirections(
          originLat: origin.position.lat.toDouble(),
          originLng: origin.position.lng.toDouble(),
          destLat: destination.position.lat.toDouble(),
          destLng: destination.position.lng.toDouble(),
          mode: 'driving',
        );
        if (directions != null && directions.routePoints.isNotEmpty) {
          segment = directions.routePoints;
        }
      } catch (e) {
        print('Error getting route segment: $e');
      }

      fullRoute.addAll(segment ?? [origin.position, destination.position]);
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
