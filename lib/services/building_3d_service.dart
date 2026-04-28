import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';

/// Service for 3D building visualization on maps
class Building3DService {
  /// Major Egyptian attractions with 3D models
  static final Map<String, Building3DModel> attractions3D = {
    'great_pyramid': Building3DModel(
      id: 'great_pyramid',
      name: 'Great Pyramid of Giza',
      lat: 29.9792,
      lng: 31.1342,
      height: 138.8, // meters
      baseWidth: 230.4,
      baseLength: 230.4,
      color: const Color(0xFFD4A574), // Sandy color
      modelType: Building3DType.pyramid,
      description: 'The oldest and largest of the three pyramids',
      constructionYear: -2560,
      architect: 'Hemiunu',
    ),
    'khafre_pyramid': Building3DModel(
      id: 'khafre_pyramid',
      name: 'Pyramid of Khafre',
      lat: 29.9763,
      lng: 31.1309,
      height: 136.4,
      baseWidth: 215.5,
      baseLength: 215.5,
      color: const Color(0xFFD4A574),
      modelType: Building3DType.pyramid,
      description: 'Second largest pyramid at Giza',
      constructionYear: -2570,
    ),
    'menkaure_pyramid': Building3DModel(
      id: 'menkaure_pyramid',
      name: 'Pyramid of Menkaure',
      lat: 29.9722,
      lng: 31.1285,
      height: 65.5,
      baseWidth: 108.5,
      baseLength: 108.5,
      color: const Color(0xFFD4A574),
      modelType: Building3DType.pyramid,
      description: 'Smallest of the three main pyramids',
      constructionYear: -2510,
    ),
    'sphinx': Building3DModel(
      id: 'sphinx',
      name: 'Great Sphinx of Giza',
      lat: 29.9753,
      lng: 31.1376,
      height: 20.0,
      baseWidth: 73.0,
      baseLength: 19.0,
      color: const Color(0xFFE6C9A8),
      modelType: Building3DType.statue,
      description: 'Limestone statue with lion body and human head',
      constructionYear: -2500,
    ),
    'cairo_tower': Building3DModel(
      id: 'cairo_tower',
      name: 'Cairo Tower',
      lat: 30.0459,
      lng: 31.2243,
      height: 187.0,
      baseWidth: 30.0,
      baseLength: 30.0,
      color: const Color(0xFF8B7355),
      modelType: Building3DType.tower,
      description: 'Free-standing concrete tower in Zamalek',
      constructionYear: 1961,
    ),
    'citadel': Building3DModel(
      id: 'citadel',
      name: 'Citadel of Cairo',
      lat: 30.0297,
      lng: 31.2600,
      height: 35.0,
      baseWidth: 150.0,
      baseLength: 200.0,
      color: const Color(0xFFB8956A),
      modelType: Building3DType.fortress,
      description: 'Medieval Islamic fortification',
      constructionYear: 1176,
    ),
    'al_azhar_mosque': Building3DModel(
      id: 'al_azhar_mosque',
      name: 'Al-Azhar Mosque',
      lat: 30.0458,
      lng: 31.2632,
      height: 45.0,
      baseWidth: 85.0,
      baseLength: 110.0,
      color: const Color(0xFFF5F5DC),
      modelType: Building3DType.mosque,
      description: 'One of the oldest mosques in Cairo',
      constructionYear: 970,
      hasMinaret: true,
      minaretHeight: 60.0,
    ),
    'muhammad_ali_mosque': Building3DModel(
      id: 'muhammad_ali_mosque',
      name: 'Muhammad Ali Mosque',
      lat: 30.0283,
      lng: 31.2597,
      height: 52.0,
      baseWidth: 41.0,
      baseLength: 41.0,
      color: const Color(0xFFE8E8E8),
      modelType: Building3DType.mosque,
      description: 'Ottoman-style mosque in the Citadel',
      constructionYear: 1848,
      hasMinaret: true,
      minaretHeight: 84.0,
    ),
    'karnak_temple': Building3DModel(
      id: 'karnak_temple',
      name: 'Karnak Temple Complex',
      lat: 25.7188,
      lng: 32.6573,
      height: 25.0,
      baseWidth: 400.0,
      baseLength: 600.0,
      color: const Color(0xFFD2B48C),
      modelType: Building3DType.temple,
      description: 'Largest ancient religious site',
      constructionYear: -2055,
      hasColumns: true,
      columnCount: 134,
    ),
    'luxor_temple': Building3DModel(
      id: 'luxor_temple',
      name: 'Luxor Temple',
      lat: 25.6995,
      lng: 32.6392,
      height: 20.0,
      baseWidth: 200.0,
      baseLength: 260.0,
      color: const Color(0xFFDEB887),
      modelType: Building3DType.temple,
      description: 'Ancient Egyptian temple complex',
      constructionYear: -1400,
      hasColumns: true,
    ),
  };

  /// Enable 3D buildings layer on map
  Future<void> enable3DBuildings(MapboxMap mapboxMap) async {
    try {
      // Note: 3D terrain and building layers require Mapbox style configuration
      // This is a placeholder for the actual implementation
      // In production, you would use mapboxMap.style APIs to add 3D layers
      print('3D buildings layer enabled (requires Mapbox style configuration)');
    } catch (e) {
      print('Error enabling 3D buildings: $e');
    }
  }

  /// Disable 3D buildings layer
  Future<void> disable3DBuildings(MapboxMap mapboxMap) async {
    try {
      await mapboxMap.style.removeStyleLayer('3d-buildings');
    } catch (e) {
      print('Error disabling 3D buildings: $e');
    }
  }

  /// Get 3D model for attraction
  Building3DModel? get3DModel(String attractionId) {
    return attractions3D[attractionId];
  }

  /// Get all 3D models in area
  List<Building3DModel> get3DModelsInArea({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) {
    return attractions3D.values.where((model) {
      final distance = _calculateDistance(
        centerLat,
        centerLng,
        model.lat,
        model.lng,
      );
      return distance <= radiusKm;
    }).toList();
  }

  /// Get camera position for best 3D view
  CameraOptions get3DViewCamera(Building3DModel model) {
    // Position camera at an angle for 3D effect
    return CameraOptions(
      center: Point(coordinates: Position(model.lng, model.lat)),
      zoom: 17.0,
      pitch: 60.0, // Tilt camera
      bearing: 45.0, // Rotate camera
    );
  }

  /// Animate camera around 3D model
  Future<void> animate3DView(
    MapboxMap mapboxMap,
    Building3DModel model, {
    int durationSeconds = 10,
  }) async {
    final steps = 36; // 10 degrees per step
    final stepDuration = (durationSeconds * 1000) ~/ steps;

    for (int i = 0; i < steps; i++) {
      final bearing = (i * 10.0) % 360;
      
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(model.lng, model.lat)),
          zoom: 17.0,
          pitch: 60.0,
          bearing: bearing,
        ),
        MapAnimationOptions(duration: stepDuration),
      );

      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  /// Get info card for 3D model
  Widget get3DModelInfoCard(Building3DModel model) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              model.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              model.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('Height', '${model.height.toStringAsFixed(1)}m'),
                const SizedBox(width: 8),
                _buildInfoChip('Built', model.constructionYear > 0 
                    ? '${model.constructionYear} AD'
                    : '${-model.constructionYear} BC'),
              ],
            ),
            if (model.architect != null) ...[
              const SizedBox(height: 8),
              _buildInfoChip('Architect', model.architect!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}

enum Building3DType {
  pyramid,
  temple,
  mosque,
  tower,
  fortress,
  statue,
}

class Building3DModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double height; // meters
  final double baseWidth;
  final double baseLength;
  final Color color;
  final Building3DType modelType;
  final String description;
  final int constructionYear; // Negative for BC
  final String? architect;
  final bool hasMinaret;
  final double? minaretHeight;
  final bool hasColumns;
  final int? columnCount;

  Building3DModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.height,
    required this.baseWidth,
    required this.baseLength,
    required this.color,
    required this.modelType,
    required this.description,
    required this.constructionYear,
    this.architect,
    this.hasMinaret = false,
    this.minaretHeight,
    this.hasColumns = false,
    this.columnCount,
  });

  Position get position => Position(lng, lat);

  String get typeLabel {
    switch (modelType) {
      case Building3DType.pyramid:
        return 'Pyramid';
      case Building3DType.temple:
        return 'Temple';
      case Building3DType.mosque:
        return 'Mosque';
      case Building3DType.tower:
        return 'Tower';
      case Building3DType.fortress:
        return 'Fortress';
      case Building3DType.statue:
        return 'Statue';
    }
  }

  String get ageText {
    final currentYear = DateTime.now().year;
    final age = constructionYear > 0 
        ? currentYear - constructionYear
        : currentYear + (-constructionYear);
    return '$age years old';
  }
}
