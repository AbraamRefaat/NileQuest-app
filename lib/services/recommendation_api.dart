import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import 'server_config.dart';

class RecommendationApiException implements Exception {
  final String message;
  final int? statusCode;

  RecommendationApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class RecommendationApi {
  /// Get base URL dynamically from configuration
  static Future<String> getBaseUrl() async {
    return await ServerConfig.getServerUrl();
  }

  /// Generate an itinerary based on user preferences
  static Future<Itinerary> generateItinerary(
      UserPreferences preferences) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/recommend');

    try {
      print('🚀 Sending request to: $uri');
      print('📋 Request body: ${jsonEncode(preferences.toApiRequest())}');

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(preferences.toApiRequest()),
      )
          .timeout(
        const Duration(seconds: 120), // AI model can take time (increased to 2 minutes)
        onTimeout: () {
          throw RecommendationApiException(
            'Request timed out after 2 minutes.\n\n'
            'If this is your first request, the server might be starting up (cold start).\n'
            'Please try again - it should be much faster the second time.',
          );
        },
      );

      print('✅ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print(
            '📦 Received itinerary with ${data['summary']['total_pois']} POIs');
        return Itinerary.fromJson(data);
      } else if (response.statusCode == 503) {
        throw RecommendationApiException(
          'Recommendation system is not ready. Please wait a moment and try again.',
          response.statusCode,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw RecommendationApiException(
          errorData['detail'] ?? 'Failed to generate itinerary',
          response.statusCode,
        );
      }
    } on SocketException {
      final url = await getBaseUrl();
      throw RecommendationApiException(
        'Cannot connect to server at $url.\n\n'
        'For Physical Device:\n'
        '1. Go to Settings (gear icon)\n'
        '2. Configure your computer\'s IP\n'
        '3. Make sure server is running\n\n'
        'For Emulator:\n'
        'Server should work automatically',
      );
    } on http.ClientException catch (e) {
      throw RecommendationApiException(
        'Network error. Please check your connection.\n\nError: $e',
      );
    } on FormatException {
      throw RecommendationApiException(
        'Invalid response format from server. Please check the API logs.',
      );
    } catch (e) {
      if (e is RecommendationApiException) rethrow;
      throw RecommendationApiException(
        'An unexpected error occurred: $e',
      );
    }
  }

  /// Health check endpoint
  static Future<bool> checkHealth() async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed health status
  static Future<Map<String, dynamic>?> getHealthDetails() async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Test connection with specific URL
  static Future<bool> testConnection(String url) async {
    try {
      final uri = Uri.parse('$url/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
