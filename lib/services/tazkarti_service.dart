import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import 'server_config_tazkarti.dart';

class TazkartiService {
  static const String baseUrl = 'https://www.tazkarti.com';

  // Get API URL from configuration
  String get apiBaseUrl => TazkartiServerConfig.getApiUrl();

  // Category IDs from Tazkarti
  static const String musicCategoryId = '3';

  /// Fetches events dynamically from backend API
  Future<List<Event>> fetchEvents({String? categoryId}) async {
    try {
      final url = TazkartiServerConfig.getMusicEventsUrl();
      print('Fetching events from API: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - API took too long to respond');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['events'] != null) {
          final List<dynamic> eventsJson = data['events'];
          print('Successfully fetched ${eventsJson.length} events from API');

          // Parse all events returned by the API (already filtered server-side)
          final allEvents =
              eventsJson.map((json) => Event.fromJson(json)).toList();

          print('Showing ${allEvents.length} events');
          return allEvents;
        } else {
          throw Exception('Invalid response format from API');
        }
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Tazkarti events from API: $e');
      rethrow;
    }
  }

  /// Get events from the music category
  Future<List<Event>> fetchMusicEvents() async {
    return fetchEvents(categoryId: musicCategoryId);
  }

  /// Build event URL for a specific event
  static String getEventUrl(String eventId) {
    return '$baseUrl/#/event/$eventId';
  }

  /// Open Tazkarti music category page
  static String getMusicCategoryUrl() {
    return '$baseUrl/#/events/category/$musicCategoryId';
  }
}
