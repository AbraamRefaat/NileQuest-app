import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final String city;
  final double temperatureC;
  final bool isDay;

  const WeatherInfo({
    required this.city,
    required this.temperatureC,
    required this.isDay,
  });

  String get temperatureDisplay => '${temperatureC.round()}°C';

  IconData get weatherIcon {
    if (isDay) {
      return Icons.wb_sunny_rounded;
    } else {
      return Icons.nightlight_round;
    }
  }
}

class WeatherData {
  final String cityName;
  final double temperature;
  final int weatherCode;

  const WeatherData({
    required this.cityName,
    required this.temperature,
    required this.weatherCode,
  });

  String get temperatureDisplay => '${temperature.round()}°C';

  IconData get weatherIcon {
    if (weatherCode == 0) return Icons.wb_sunny_rounded;
    if (weatherCode <= 3) return Icons.wb_cloudy_rounded;
    if (weatherCode <= 49) return Icons.foggy;
    if (weatherCode <= 67) return Icons.grain_rounded;
    if (weatherCode <= 77) return Icons.ac_unit_rounded;
    if (weatherCode <= 82) return Icons.water_drop_rounded;
    return Icons.thunderstorm_rounded;
  }

  String get weatherDescription {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode <= 49) return 'Foggy';
    if (weatherCode <= 67) return 'Rainy';
    if (weatherCode <= 77) return 'Snowy';
    if (weatherCode <= 82) return 'Showers';
    return 'Thunderstorm';
  }
}

class WeatherService {
  static Future<WeatherInfo?> getCurrentWeather() async {
    try {
      final position = await _determinePosition();
      if (position == null) {
        return _getFallbackWeather();
      }

      final cityName = await _getCityNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final weatherData = await _fetchWeatherFromOpenMeteo(
        position.latitude,
        position.longitude,
      );

      if (weatherData == null) {
        return _getFallbackWeather();
      }

      return WeatherInfo(
        city: cityName ?? 'Your Location',
        temperatureC: weatherData['temperature'],
        isDay: weatherData['isDay'],
      );
    } catch (_) {
      return _getFallbackWeather();
    }
  }

  static Future<WeatherData?> fetchWeatherAndLocation() async {
    try {
      final position = await _determinePosition();
      if (position == null) return null;

      final results = await Future.wait([
        _fetchCityName(position.latitude, position.longitude),
        _fetchWeather(position.latitude, position.longitude),
      ]);

      final cityName = results[0] as String? ?? 'Your Location';
      final weather = results[1] as Map<String, dynamic>?;

      if (weather == null) return null;

      final currentWeather = weather['current_weather'] as Map<String, dynamic>;
      final temperature = (currentWeather['temperature'] as num).toDouble();
      final weatherCode = (currentWeather['weathercode'] as num).toInt();

      return WeatherData(
        cityName: cityName,
        temperature: temperature,
        weatherCode: weatherCode,
      );
    } catch (_) {
      return null;
    }
  }

  static WeatherInfo _getFallbackWeather() {
    return const WeatherInfo(
      city: 'Cairo',
      temperatureC: 25.0,
      isDay: true,
    );
  }

  static Future<String?> _getCityNameFromCoordinates(
    double lat,
    double lon,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality ?? place.administrativeArea ?? place.country;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchWeatherFromOpenMeteo(
    double lat,
    double lon,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon&current=temperature_2m,is_day&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;
        
        return {
          'temperature': (current['temperature_2m'] as num).toDouble(),
          'isDay': (current['is_day'] as num) == 1,
        };
      }
    } catch (_) {}
    return null;
  }

  static Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  static Future<String?> _fetchCityName(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'NileQuest/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          return address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['county'] as String? ??
              address['state'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchWeather(
      double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon&current_weather=true&temperature_unit=celsius',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
