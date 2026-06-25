import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which itinerary stops the traveller has manually ticked off as
/// "done" on the current trip — independent of the live (GPS) trip session.
///
/// This powers the green ✓ stop pins on the map so the user can see at a
/// glance which places they've already visited, even before/without pressing
/// "Start Trip". Progress is keyed by "<day>_<poiId>" and persisted locally,
/// then cleared when the current trip moves to history (finish / sign-out).
class TripProgressService extends ChangeNotifier {
  static final TripProgressService _instance = TripProgressService._();
  factory TripProgressService() => _instance;
  TripProgressService._();

  static const _storageKey = 'completed_trip_stops';

  final Set<String> _done = {};
  bool _restored = false;

  static String _keyFor(int day, String poiId) => '${day}_$poiId';

  /// Whether the given stop has been marked done.
  bool isDone(int day, String poiId) => _done.contains(_keyFor(day, poiId));

  /// Load persisted progress once (safe to call repeatedly).
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];
    _done
      ..clear()
      ..addAll(saved);
    if (saved.isNotEmpty) notifyListeners();
  }

  /// Flip a stop between done / not-done. Returns the resulting state.
  Future<bool> toggle(int day, String poiId) async {
    final nowDone = !isDone(day, poiId);
    await setDone(day, poiId, nowDone);
    return nowDone;
  }

  /// Mark a stop done (or not). No-op if already in that state.
  Future<void> setDone(int day, String poiId, bool done) async {
    final key = _keyFor(day, poiId);
    final changed = done ? _done.add(key) : _done.remove(key);
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// Forget all progress (current trip finished, deleted, or signed out).
  Future<void> clearAll() async {
    if (_done.isEmpty) {
      // Still wipe storage in case it held stale keys from a prior run.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      return;
    }
    _done.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _done.toList());
  }
}
