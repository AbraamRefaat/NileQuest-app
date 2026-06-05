import 'package:dio/dio.dart';

class LocationService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyBGqoMpCdzZt8bRE3I4K3sc2R9eueddPVA';
  
  final Dio _dio = Dio();

  /// Get user location using Google Geolocation API
  /// (fallback when GPS is unavailable)
  Future<UserLocation?> getCurrentLocation() async {
    try {
      final response = await _dio.post(
        '$_baseUrl/geolocate/json?key=$_apiKey',
        data: {
          'considerIp': true,
        },
      );

      if (response.statusCode == 200) {
        final location = response.data['location'];
        return UserLocation(
          latitude: location['lat'],
          longitude: location['lng'],
          accuracy: response.data['accuracy'],
        );
      }
      
      return null;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Get Street View image URL
  String getStreetViewUrl({
    required double latitude,
    required double longitude,
    int width = 600,
    int height = 400,
    int fov = 90,
    int heading = 0,
    int pitch = 0,
  }) {
    return '$_baseUrl/streetview?size=${width}x$height'
        '&location=$latitude,$longitude'
        '&fov=$fov'
        '&heading=$heading'
        '&pitch=$pitch'
        '&key=$_apiKey';
  }

  /// Check if Street View is available at location
  Future<bool> isStreetViewAvailable({
    required double latitude,
    required double longitude,
    int radius = 50,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/streetview/metadata',
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radius,
          'key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        return response.data['status'] == 'OK';
      }
      
      return false;
    } catch (e) {
      print('Error checking street view: $e');
      return false;
    }
  }
}

class UserLocation {
  final double latitude;
  final double longitude;
  final double accuracy;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}
