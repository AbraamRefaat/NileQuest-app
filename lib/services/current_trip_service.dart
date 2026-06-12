import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';

/// The locally persisted "current trip" — restored after an app restart.
class CurrentTripState {
  final Itinerary itinerary;
  final UserPreferences? preferences;
  final String? backendId;

  CurrentTripState({
    required this.itinerary,
    this.preferences,
    this.backendId,
  });
}

/// Persists the active (not yet finished) trip locally so it survives app
/// restarts. The trip is auto-saved to the backend the moment it's generated,
/// so without this the Trip tab came back empty after a restart while the
/// backend copy showed up in Trip history. A trip only "moves" to history
/// when this state is cleared: user taps Finish, completes every stop, or
/// deletes the trip.
class CurrentTripService {
  static final CurrentTripService _instance = CurrentTripService._();
  factory CurrentTripService() => _instance;
  CurrentTripService._();

  static const _stateKey = 'current_trip_state';

  /// Save (or overwrite) the current trip.
  Future<void> save({
    required Itinerary itinerary,
    UserPreferences? preferences,
    String? backendId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stateKey,
      jsonEncode({
        'itinerary': itinerary.toJson(),
        'preferences': preferences?.toJson(),
        'backendId': backendId,
      }),
    );
  }

  /// Update only the backend id (called after the auto-save / edit-save
  /// succeeds) without touching the rest of the stored state.
  Future<void> setBackendId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data['backendId'] = id;
      await prefs.setString(_stateKey, jsonEncode(data));
    } catch (_) {
      // Corrupt state — drop it rather than crash.
      await prefs.remove(_stateKey);
    }
  }

  /// Restore the current trip after a restart, or null if there is none.
  Future<CurrentTripState?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final itinerary =
          Itinerary.fromJson(data['itinerary'] as Map<String, dynamic>);
      final prefsJson = data['preferences'];
      return CurrentTripState(
        itinerary: itinerary,
        preferences: prefsJson is Map<String, dynamic>
            ? UserPreferences.fromJson(prefsJson)
            : null,
        backendId: data['backendId'],
      );
    } catch (_) {
      await prefs.remove(_stateKey);
      return null;
    }
  }

  /// Backend id of the current trip without parsing the whole itinerary —
  /// used by Trip history to hide the still-active trip from the list.
  Future<String?> getBackendId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final id = data['backendId'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  /// Clear the current trip (finish / delete / sign-out). After this the
  /// backend copy becomes visible in Trip history.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
}
