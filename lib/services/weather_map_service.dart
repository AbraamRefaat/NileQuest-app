import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

/// Service for weather integration on maps
class WeatherMapService {
  // Using OpenWeatherMap API (free tier)
  static const String _apiKey = 'YOUR_OPENWEATHERMAP_API_KEY'; // User needs to add their key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  final Dio _dio = Dio();

  /// Get current weather for location
  Future<WeatherData?> getCurrentWeather({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/weather',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'appid': _apiKey,
          'units': 'metric', // Celsius
        },
      );

      if (response.statusCode == 200) {
        return WeatherData.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  /// Get weather forecast (5 days)
  Future<List<WeatherForecast>> getWeatherForecast({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/forecast',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'appid': _apiKey,
          'units': 'metric',
        },
      );

      if (response.statusCode == 200) {
        final list = response.data['list'] as List;
        return list.map((item) => WeatherForecast.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching forecast: $e');
      return [];
    }
  }

  /// Get weather-based recommendations
  TouristRecommendations getRecommendations(WeatherData weather) {
    final temp = weather.temperature;
    final condition = weather.condition.toLowerCase();
    
    List<String> recommendations = [];
    List<String> warnings = [];
    List<String> indoorAlternatives = [];

    // Temperature-based recommendations
    if (temp > 40) {
      warnings.add('Extreme heat! Stay hydrated and seek shade frequently.');
      warnings.add('Avoid outdoor activities between 11 AM - 4 PM.');
      indoorAlternatives.addAll([
        'Egyptian Museum',
        'Grand Egyptian Museum',
        'Shopping malls',
        'Indoor restaurants and cafes',
      ]);
      recommendations.add('Carry water bottle and sunscreen (SPF 50+)');
    } else if (temp > 35) {
      warnings.add('Very hot weather. Take breaks in air-conditioned places.');
      recommendations.add('Visit outdoor sites early morning or late afternoon');
      recommendations.add('Wear light, breathable clothing');
    } else if (temp > 30) {
      recommendations.add('Perfect weather for sightseeing!');
      recommendations.add('Bring sun protection');
    } else if (temp > 20) {
      recommendations.add('Ideal temperature for exploring');
      recommendations.add('Great day for walking tours');
    } else if (temp < 15) {
      recommendations.add('Cool weather - bring a light jacket');
      recommendations.add('Good for hiking and outdoor activities');
    }

    // Condition-based recommendations
    if (condition.contains('rain')) {
      warnings.add('Rain expected. Carry an umbrella.');
      indoorAlternatives.addAll([
        'Museums',
        'Khan el-Khalili indoor markets',
        'Cafes and restaurants',
      ]);
      recommendations.add('Visit indoor attractions today');
    } else if (condition.contains('cloud')) {
      recommendations.add('Cloudy weather - perfect for photography!');
      recommendations.add('Less harsh sunlight, great for outdoor tours');
    } else if (condition.contains('clear')) {
      recommendations.add('Clear skies - excellent for photography');
      recommendations.add('Perfect for sunset views at the Nile');
    }

    // UV Index recommendations
    if (weather.uvIndex != null && weather.uvIndex! > 8) {
      warnings.add('Very high UV index. Wear sunscreen and hat.');
      recommendations.add('Seek shade during peak sun hours');
    }

    // Humidity recommendations
    if (weather.humidity > 70) {
      recommendations.add('High humidity - stay hydrated');
      recommendations.add('Take frequent breaks in air-conditioned spaces');
    }

    return TouristRecommendations(
      recommendations: recommendations,
      warnings: warnings,
      indoorAlternatives: indoorAlternatives,
      bestTimeToVisit: _getBestTimeToVisit(temp, condition),
    );
  }

  String _getBestTimeToVisit(double temp, String condition) {
    if (temp > 35) {
      return 'Early morning (6-9 AM) or evening (5-7 PM)';
    } else if (temp > 30) {
      return 'Morning (8-11 AM) or late afternoon (4-6 PM)';
    } else if (condition.contains('rain')) {
      return 'Wait for rain to clear, check forecast';
    } else {
      return 'Anytime during daylight hours';
    }
  }

  /// Get weather icon for display
  String getWeatherIcon(String condition) {
    condition = condition.toLowerCase();
    if (condition.contains('clear')) return '☀️';
    if (condition.contains('cloud')) return '☁️';
    if (condition.contains('rain')) return '🌧️';
    if (condition.contains('thunder')) return '⛈️';
    if (condition.contains('snow')) return '❄️';
    if (condition.contains('mist') || condition.contains('fog')) return '🌫️';
    return '🌤️';
  }
}

class WeatherData {
  final double temperature; // Celsius
  final double feelsLike;
  final int humidity; // Percentage
  final double windSpeed; // m/s
  final String condition; // Clear, Clouds, Rain, etc.
  final String description; // Detailed description
  final int? uvIndex;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.description,
    this.uvIndex,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      condition: json['weather'][0]['main'] as String,
      description: json['weather'][0]['description'] as String,
      uvIndex: json['uvi'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
    );
  }

  String get temperatureText => '${temperature.round()}°C';
  String get feelsLikeText => 'Feels like ${feelsLike.round()}°C';
  String get humidityText => '$humidity%';
  String get windSpeedText => '${windSpeed.toStringAsFixed(1)} m/s';

  bool get isHot => temperature > 35;
  bool get isVeryHot => temperature > 40;
  bool get isCool => temperature < 20;
  bool get isRainy => condition.toLowerCase().contains('rain');
}

class WeatherForecast {
  final DateTime dateTime;
  final double temperature;
  final String condition;
  final String description;
  final int humidity;

  WeatherForecast({
    required this.dateTime,
    required this.temperature,
    required this.condition,
    required this.description,
    required this.humidity,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      temperature: (json['main']['temp'] as num).toDouble(),
      condition: json['weather'][0]['main'] as String,
      description: json['weather'][0]['description'] as String,
      humidity: json['main']['humidity'] as int,
    );
  }

  String get timeText => DateFormat('HH:mm').format(dateTime);
  String get dateText => DateFormat('EEE, MMM d').format(dateTime);
  String get temperatureText => '${temperature.round()}°C';
}

class TouristRecommendations {
  final List<String> recommendations;
  final List<String> warnings;
  final List<String> indoorAlternatives;
  final String bestTimeToVisit;

  TouristRecommendations({
    required this.recommendations,
    required this.warnings,
    required this.indoorAlternatives,
    required this.bestTimeToVisit,
  });
}
