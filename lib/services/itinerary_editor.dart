import 'dart:math' as math;

import '../models/itinerary.dart';
import '../models/itinerary_event.dart';
import '../models/poi.dart';

/// Pure itinerary editing operations.
///
/// Every operation returns a NEW [Itinerary] (deep-copied day lists) so the
/// UI can hold the result in setState without aliasing the previous instance.
/// Day keys stay fixed at 1..totalDays — a day emptied by removal keeps an
/// empty list rather than re-indexing the trip.
///
/// `travelTimeHours` on an event means travel TO that event from the previous
/// one (or from the hotel for the first event of a day). Whenever an event's
/// predecessor changes, its travel time is re-estimated offline via haversine
/// distance — no network call per drag.
class ItineraryEditor {
  ItineraryEditor._();

  /// Average road speed (km/h) and winding factor for offline travel
  /// estimates between stops in Egyptian cities.
  static const double _roadWindingFactor = 1.4;
  static const double _avgSpeedKmh = 25.0;
  static const double _minTravelHours = 0.15; // 9-minute floor

  static Itinerary removeStop(Itinerary itinerary, int day, int index) {
    final days = _copyDays(itinerary);
    final events = days[day];
    if (events == null || index < 0 || index >= events.length) {
      return itinerary;
    }
    events.removeAt(index);
    days[day] = _retimeDay(events);
    return _rebuild(itinerary, days);
  }

  static Itinerary reorderWithinDay(
      Itinerary itinerary, int day, int oldIndex, int newIndex) {
    final days = _copyDays(itinerary);
    final events = days[day];
    if (events == null ||
        oldIndex < 0 ||
        oldIndex >= events.length ||
        oldIndex == newIndex) {
      return itinerary;
    }
    final moved = events.removeAt(oldIndex);
    final insertAt = newIndex.clamp(0, events.length);
    events.insert(insertAt, moved);
    days[day] = _retimeDay(events);
    return _rebuild(itinerary, days);
  }

  /// Moves a stop to another day. [toIndex] null appends at the end.
  static Itinerary moveBetweenDays(
      Itinerary itinerary, int fromDay, int fromIndex, int toDay,
      [int? toIndex]) {
    if (fromDay == toDay) {
      return reorderWithinDay(
          itinerary, fromDay, fromIndex, toIndex ?? fromIndex);
    }
    final days = _copyDays(itinerary);
    final from = days[fromDay];
    if (from == null || fromIndex < 0 || fromIndex >= from.length) {
      return itinerary;
    }
    final moved = from.removeAt(fromIndex);
    final to = days.putIfAbsent(toDay, () => <ItineraryEvent>[]);
    final insertAt = (toIndex ?? to.length).clamp(0, to.length);
    to.insert(insertAt, moved);
    days[fromDay] = _retimeDay(from);
    days[toDay] = _retimeDay(to);
    return _rebuild(itinerary, days);
  }

  static Itinerary addStop(Itinerary itinerary, int day, Poi poi,
      {int? index, String reason = 'Added by you'}) {
    final days = _copyDays(itinerary);
    final events = days.putIfAbsent(day, () => <ItineraryEvent>[]);
    final insertAt = (index ?? events.length).clamp(0, events.length);
    events.insert(
      insertAt,
      ItineraryEvent(
        poi: poi,
        startTime: '09:00',
        endTime: '09:00',
        travelTimeHours: 0,
        reason: reason,
      ),
    );
    days[day] = _retimeDay(events);
    return _rebuild(itinerary, days);
  }

  /// Recomputes travel times and start/end times for a day's sequence.
  ///
  /// The first event keeps its current start time as the anchor (falling back
  /// to [fallbackAnchor] when unparsable) and gets zero travel time. Each
  /// subsequent event starts when the previous ends plus travel. Boundaries
  /// are rounded to 5 minutes and clamped at 23:55.
  static List<ItineraryEvent> recalcDayTimes(List<ItineraryEvent> events,
      {String fallbackAnchor = '09:00'}) {
    if (events.isEmpty) return events;

    final anchor =
        _parseMinutes(events.first.startTime) ?? _parseMinutes(fallbackAnchor)!;

    final result = <ItineraryEvent>[];
    int cursor = anchor;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final travelHours = i == 0
          ? 0.0
          : estimateTravelHours(events[i - 1].poi, event.poi);

      int start = i == 0 ? cursor : cursor + (travelHours * 60).round();
      start = _roundTo5(start).clamp(0, _maxMinutes);

      final durationMinutes =
          math.max(30, (event.poi.durationHours * 60).round());
      int end = _roundTo5(start + durationMinutes).clamp(0, _maxMinutes);
      if (end <= start) end = math.min(start + 30, _maxMinutes);

      result.add(event.copyWith(
        startTime: _formatMinutes(start),
        endTime: _formatMinutes(end),
        travelTimeHours: double.parse(travelHours.toStringAsFixed(2)),
      ));
      cursor = end;
    }
    return result;
  }

  /// True when a day's schedule got pinned at the 23:55 ceiling — the day
  /// holds more than fits; the UI shows an "overloaded" warning.
  static bool isDayOverloaded(List<ItineraryEvent> events) {
    if (events.isEmpty) return false;
    final last = events.last;
    return _parseMinutes(last.endTime) == _maxMinutes ||
        _parseMinutes(last.startTime) == _maxMinutes;
  }

  static double estimateTravelHours(Poi from, Poi to) {
    final km = _haversineKm(from.lat, from.lon, to.lat, to.lon);
    return math.max(_minTravelHours, km * _roadWindingFactor / _avgSpeedKmh);
  }

  // ---------------------------------------------------------------- internal

  static const int _maxMinutes = 23 * 60 + 55;

  static Map<int, List<ItineraryEvent>> _copyDays(Itinerary itinerary) {
    return {
      for (final entry in itinerary.days.entries)
        entry.key: List<ItineraryEvent>.from(entry.value),
    };
  }

  static List<ItineraryEvent> _retimeDay(List<ItineraryEvent> events) =>
      recalcDayTimes(events);

  static Itinerary _rebuild(
      Itinerary source, Map<int, List<ItineraryEvent>> days) {
    final totalPois =
        days.values.fold<int>(0, (sum, events) => sum + events.length);
    return Itinerary(
      days: days,
      totalDays: source.totalDays,
      totalPois: totalPois,
      interestSearch: source.interestSearch,
      interests: List<String>.from(source.interests),
    );
  }

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  static String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int _roundTo5(int minutes) => ((minutes + 2) ~/ 5) * 5;

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;
}
