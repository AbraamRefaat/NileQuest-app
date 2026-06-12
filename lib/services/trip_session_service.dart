import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/itinerary.dart';
import '../models/trip_session.dart';
import 'notification_service.dart';

/// Manages a live trip: geofences each stop, fires photo notifications
/// on arrival, tracks walked distance, and persists everything so the
/// session survives app restarts.
class TripSessionService extends ChangeNotifier {
  static final TripSessionService _instance = TripSessionService._();
  factory TripSessionService() => _instance;
  TripSessionService._();

  static const _storageKey = 'active_trip_session';
  static const _historyKey = 'trip_session_history';
  static const double arrivalRadiusMeters = 150;

  TripSession? _session;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;

  TripSession? get session => _session;
  bool get hasActiveTrip => _session != null && _session!.isActive;

  /// Fired when the user arrives at a stop (UI can open the camera sheet)
  void Function(int stopIndex)? onStopArrival;

  // ── Lifecycle ──────────────────────────────────────────────────────

  Future<void> startTrip(Itinerary itinerary, int day) async {
    _session = TripSession.fromItineraryDay(itinerary, day);
    await NotificationService().init();
    await _persist();
    _startTracking();
    notifyListeners();
  }

  Future<TripSession?> endTrip() async {
    if (_session == null) return null;
    _session!.endedAt = DateTime.now();
    final finished = _session;
    await _stopTracking();
    await _archiveSession(finished!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _session = null;
    notifyListeners();
    return finished;
  }

  /// Restore an interrupted session (call on app start / map open)
  Future<void> restore() async {
    if (_session != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      _session = TripSession.fromJson(jsonDecode(raw));
      if (_session!.isActive) {
        _startTracking();
        notifyListeners();
      }
    } catch (_) {
      await prefs.remove(_storageKey);
    }
  }

  // ── Stop interaction ───────────────────────────────────────────────

  /// Manual check-in fallback when GPS hasn't triggered (or for testing)
  Future<void> checkInAtStop(int index) async {
    final stop = _stopAt(index);
    if (stop == null || stop.status != StopStatus.upcoming) return;
    stop.status = StopStatus.arrived;
    stop.arrivedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> addPhotosToStop(int index, List<String> paths) async {
    final stop = _stopAt(index);
    if (stop == null) return;
    stop.photoPaths.addAll(paths);
    if (stop.status == StopStatus.upcoming) {
      stop.status = StopStatus.arrived;
      stop.arrivedAt = DateTime.now();
    }
    if (stop.photoPaths.length >= 3) {
      stop.status = StopStatus.completed;
    }
    await _persist();
    notifyListeners();

    // All stops done → celebrate
    if (_session != null &&
        _session!.stops.every((s) => s.status == StopStatus.completed)) {
      NotificationService().showTripCompleteNotification();
    }
  }

  /// Distance in meters from last known position to a stop (null if unknown)
  double? distanceToStop(TripStop stop) {
    if (_lastPosition == null) return null;
    return Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      stop.lat,
      stop.lon,
    );
  }

  // ── History (for Wrapped re-viewing) ───────────────────────────────

  Future<List<TripSession>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw
        .map((s) {
          try {
            return TripSession.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<TripSession>()
        .toList();
  }

  // ── Internals ──────────────────────────────────────────────────────

  TripStop? _stopAt(int index) {
    if (_session == null || index < 0 || index >= _session!.stops.length) {
      return null;
    }
    return _session!.stops[index];
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // update every ~20 m of movement
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  Future<void> _stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  void _onPosition(Position pos) {
    if (_session == null || !_session!.isActive) return;

    // Accumulate walked distance
    if (_lastPosition != null) {
      final meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      // Ignore GPS jumps > 500 m between updates
      if (meters < 500) {
        _session!.distanceWalkedKm += meters / 1000;
      }
    }
    _lastPosition = pos;

    // Geofence check on upcoming stops
    for (int i = 0; i < _session!.stops.length; i++) {
      final stop = _session!.stops[i];
      if (stop.status != StopStatus.upcoming) continue;
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        stop.lat,
        stop.lon,
      );
      if (d <= arrivalRadiusMeters) {
        stop.status = StopStatus.arrived;
        stop.arrivedAt = DateTime.now();
        NotificationService().showStopArrivalNotification(
          stopIndex: i,
          stopName: stop.name,
        );
        onStopArrival?.call(i);
        notifyListeners();
        break; // one arrival per update
      }
    }

    _persist();
  }

  Future<void> _persist() async {
    if (_session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_session!.toJson()));
  }

  Future<void> _archiveSession(TripSession s) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.add(jsonEncode(s.toJson()));
    // Keep last 20 trips
    while (history.length > 20) {
      history.removeAt(0);
    }
    await prefs.setStringList(_historyKey, history);
  }

  /// Fun fact for the Wrapped — equivalent steps walked (~1300 steps/km)
  int get estimatedSteps =>
      ((_session?.distanceWalkedKm ?? 0) * 1300).round();

  static double haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double deg2rad(double d) => d * math.pi / 180.0;
    final dLat = deg2rad(lat2 - lat1);
    final dLon = deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(lat1)) *
            math.cos(deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
