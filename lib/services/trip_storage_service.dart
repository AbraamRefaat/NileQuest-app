import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';
import 'auth_service.dart';

class TripStorageService {
  final AuthService _authService = AuthService();
  
  // The dedicated Vercel URL for the trip persistence backend
  static const String _baseUrl = 'https://trip-backend-iota.vercel.app';
  static String get _tripsUrl => '$_baseUrl/api/trips';

  /// Save a trip to the backend. Returns the created trip's backend id,
  /// an empty string when the save succeeded but the response carried no
  /// recognizable id, or null when the save failed.
  Future<String?> saveTrip(Itinerary itinerary, String title, Map<String, String?> photoCache) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('User must be signed in to save a trip');
    }

    try {
      // Create a mutable copy of the itinerary data to inject photo URLs
      final Map<String, dynamic> itineraryJson = itinerary.toJson();
      final Map<String, dynamic> days = itineraryJson['itinerary'];

      days.forEach((dayKey, eventsJson) {
        final List events = eventsJson as List;
        for (var eventJson in events) {
          final Map<String, dynamic> poiJson = eventJson['poi'];
          final String name = poiJson['name'];
          final double lat = poiJson['lat'];
          final double lon = poiJson['lon'];
          
          final cacheKey = '${name}_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
          if (photoCache.containsKey(cacheKey)) {
            final url = photoCache[cacheKey];
            if (url != null) {
              poiJson['photo_url'] = url;
              print('🖼️ [TripStorageService] Injected photo URL for: $name');
            }
          } else {
            print('❓ [TripStorageService] No photo URL found in cache for: $name (Key: $cacheKey)');
          }
        }
      });

      print('🚀 [TripStorageService] Attempting to save trip with ${itinerary.totalPois} POIs...');
      print('📍 URL: $_tripsUrl');

      final payload = {
        'firebaseUid': user.uid,
        'title': title,
        'itinerary': itineraryJson,
      };

      final response = await http.post(
        Uri.parse(_tripsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📥 [TripStorageService] Response Status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        print('✅ [TripStorageService] Trip saved successfully!');
        final id = _extractTripId(response.body);
        if (id == null) {
          print('⚠️ [TripStorageService] Saved, but no id found in response.');
        }
        return id ?? '';
      } else {
        print('⚠️ [TripStorageService] Failed to save trip.');
        print('📝 Response Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ [TripStorageService] Error saving trip: $e');
      return null;
    }
  }

  /// Replaces a previously saved trip with an edited version. The backend has
  /// no PUT, so this deletes the old document (best effort) and POSTs the new
  /// one. Returns the new backend id, or null if the save failed.
  Future<String?> updateTrip(
    String? existingId,
    Itinerary itinerary,
    String title,
    Map<String, String?> photoCache,
  ) async {
    if (existingId != null) {
      final deleted = await deleteTrip(existingId);
      if (!deleted) {
        print('⚠️ [TripStorageService] Could not delete old trip $existingId '
            '(continuing with save).');
      }
    }
    var id = await saveTrip(itinerary, title, photoCache);
    // One retry: after a DELETE the old version is gone, so a failed POST
    // would otherwise lose the saved copy.
    id ??= await saveTrip(itinerary, title, photoCache);
    return id;
  }

  /// Pulls a Mongo-style id out of a POST response body, tolerating several
  /// shapes: {tripId} (what api/trips.js actually returns), {_id},
  /// {insertedId}, {id}, {trip: {_id}}, and {$oid} wrappers.
  String? _extractTripId(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      dynamic raw = decoded['tripId'] ??
          decoded['_id'] ??
          decoded['insertedId'] ??
          decoded['id'] ??
          (decoded['trip'] is Map ? (decoded['trip'] as Map)['_id'] : null);

      if (raw is Map && raw.containsKey(r'$oid')) raw = raw[r'$oid'];
      if (raw is String && raw.isNotEmpty) return raw;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get all saved trips for the current user
  Future<List<Map<String, dynamic>>> getUserTrips() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('User must be signed in to fetch trips');
    }

    try {
      final response = await http.get(
        Uri.parse('$_tripsUrl?uid=${user.uid}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['trips']);
      }
      return [];
    } catch (e) {
      print('Error fetching trips: $e');
      return [];
    }
  }

  /// Delete a trip by ID
  Future<bool> deleteTrip(String tripId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_tripsUrl?id=$tripId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting trip: $e');
      return false;
    }
  }
}
