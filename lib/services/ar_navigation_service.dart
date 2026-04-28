import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Service for AR (Augmented Reality) navigation
class ARNavigationService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<Position>? _locationSubscription;

  double _currentHeading = 0.0; // Device compass heading
  
  final StreamController<ARNavigationData> _navigationController =
      StreamController<ARNavigationData>.broadcast();

  Stream<ARNavigationData> get navigationStream => _navigationController.stream;

  /// Start AR navigation to destination
  Future<void> startARNavigation({
    required double destLat,
    required double destLng,
    required String destinationName,
  }) async {
    // Start sensor listeners
    _startSensorListeners();
    
    // Start location tracking
    _startLocationTracking(destLat, destLng, destinationName);
  }

  /// Stop AR navigation
  void stopARNavigation() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _locationSubscription?.cancel();
  }

  void _startSensorListeners() {
    // Listen to magnetometer for compass heading
    _magnetometerSubscription = magnetometerEvents.listen((event) {
      // Calculate heading from magnetometer data
      _currentHeading = _calculateHeading(event.x, event.y);
    });

    // Listen to accelerometer for device tilt
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      // Can be used for gesture detection or tilt compensation
    });

    // Listen to gyroscope for rotation
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      // Can be used for smooth rotation tracking
    });
  }

  void _startLocationTracking(double destLat, double destLng, String destName) {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((position) {
      
      // Calculate AR navigation data
      final navData = _calculateARData(
        position.latitude,
        position.longitude,
        destLat,
        destLng,
        destName,
      );

      _navigationController.add(navData);
    });
  }

  ARNavigationData _calculateARData(
    double currentLat,
    double currentLng,
    double destLat,
    double destLng,
    String destName,
  ) {
    // Calculate distance
    final distance = _calculateDistance(currentLat, currentLng, destLat, destLng);
    
    // Calculate bearing to destination
    final bearing = _calculateBearing(currentLat, currentLng, destLat, destLng);
    
    // Calculate relative angle (difference between device heading and bearing)
    double relativeAngle = bearing - _currentHeading;
    
    // Normalize to -180 to 180
    while (relativeAngle > 180) {
      relativeAngle -= 360;
    }
    while (relativeAngle < -180) {
      relativeAngle += 360;
    }

    // Determine direction
    final direction = _getDirection(relativeAngle);
    
    // Determine instruction
    final instruction = _getInstruction(distance, relativeAngle);

    return ARNavigationData(
      destinationName: destName,
      distance: distance,
      bearing: bearing,
      relativeAngle: relativeAngle,
      direction: direction,
      instruction: instruction,
      currentHeading: _currentHeading,
    );
  }

  double _calculateHeading(double x, double y) {
    // Calculate heading from magnetometer data
    double heading = math.atan2(y, x) * (180 / math.pi);
    
    // Normalize to 0-360
    if (heading < 0) heading += 360;
    
    return heading;
  }

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

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRadians(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_toRadians(lat2));
    final x = math.cos(_toRadians(lat1)) * math.sin(_toRadians(lat2)) -
        math.sin(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.cos(dLon);
    
    double bearing = math.atan2(y, x) * (180 / math.pi);
    
    // Normalize to 0-360
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }

  ARDirection _getDirection(double relativeAngle) {
    final absAngle = relativeAngle.abs();
    
    if (absAngle < 22.5) {
      return ARDirection.straight;
    } else if (absAngle < 67.5) {
      return relativeAngle > 0 ? ARDirection.slightRight : ARDirection.slightLeft;
    } else if (absAngle < 112.5) {
      return relativeAngle > 0 ? ARDirection.right : ARDirection.left;
    } else if (absAngle < 157.5) {
      return relativeAngle > 0 ? ARDirection.sharpRight : ARDirection.sharpLeft;
    } else {
      return ARDirection.behind;
    }
  }

  String _getInstruction(double distanceKm, double relativeAngle) {
    final distanceM = distanceKm * 1000;
    
    if (distanceM < 10) {
      return 'You have arrived!';
    } else if (distanceM < 50) {
      return 'Destination ahead (${distanceM.round()}m)';
    }

    final direction = _getDirection(relativeAngle);
    String directionText;

    switch (direction) {
      case ARDirection.straight:
        directionText = 'Continue straight';
        break;
      case ARDirection.slightLeft:
        directionText = 'Bear slightly left';
        break;
      case ARDirection.slightRight:
        directionText = 'Bear slightly right';
        break;
      case ARDirection.left:
        directionText = 'Turn left';
        break;
      case ARDirection.right:
        directionText = 'Turn right';
        break;
      case ARDirection.sharpLeft:
        directionText = 'Sharp left turn';
        break;
      case ARDirection.sharpRight:
        directionText = 'Sharp right turn';
        break;
      case ARDirection.behind:
        directionText = 'Turn around';
        break;
    }

    if (distanceKm < 1) {
      return '$directionText (${distanceM.round()}m)';
    } else {
      return '$directionText (${distanceKm.toStringAsFixed(1)}km)';
    }
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  void dispose() {
    stopARNavigation();
    _navigationController.close();
  }
}

enum ARDirection {
  straight,
  slightLeft,
  slightRight,
  left,
  right,
  sharpLeft,
  sharpRight,
  behind,
}

class ARNavigationData {
  final String destinationName;
  final double distance; // km
  final double bearing; // degrees (0-360)
  final double relativeAngle; // degrees (-180 to 180)
  final ARDirection direction;
  final String instruction;
  final double currentHeading;

  ARNavigationData({
    required this.destinationName,
    required this.distance,
    required this.bearing,
    required this.relativeAngle,
    required this.direction,
    required this.instruction,
    required this.currentHeading,
  });

  String get distanceText {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  IconData get directionIcon {
    switch (direction) {
      case ARDirection.straight:
        return Icons.arrow_upward;
      case ARDirection.slightLeft:
        return Icons.north_west;
      case ARDirection.slightRight:
        return Icons.north_east;
      case ARDirection.left:
        return Icons.arrow_back;
      case ARDirection.right:
        return Icons.arrow_forward;
      case ARDirection.sharpLeft:
        return Icons.south_west;
      case ARDirection.sharpRight:
        return Icons.south_east;
      case ARDirection.behind:
        return Icons.arrow_downward;
    }
  }

  Color get directionColor {
    switch (direction) {
      case ARDirection.straight:
        return Colors.green;
      case ARDirection.slightLeft:
      case ARDirection.slightRight:
        return Colors.blue;
      case ARDirection.left:
      case ARDirection.right:
        return Colors.orange;
      case ARDirection.sharpLeft:
      case ARDirection.sharpRight:
        return Colors.red;
      case ARDirection.behind:
        return Colors.purple;
    }
  }
}

/// AR Overlay Widget for camera view
class ARNavigationOverlay extends StatelessWidget {
  final ARNavigationData navigationData;

  const ARNavigationOverlay({
    super.key,
    required this.navigationData,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Direction arrow (center of screen)
        Center(
          child: Transform.rotate(
            angle: navigationData.relativeAngle * (math.pi / 180),
            child: Icon(
              Icons.navigation,
              size: 120,
              color: navigationData.directionColor,
            ),
          ),
        ),

        // Distance indicator (top center)
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    navigationData.destinationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    navigationData.distanceText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instruction (bottom)
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: navigationData.directionColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  navigationData.directionIcon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    navigationData.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Compass (top right)
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Transform.rotate(
                angle: -navigationData.currentHeading * (math.pi / 180),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
