import 'package:flutter_test/flutter_test.dart';
import 'package:nile_quest/models/itinerary.dart';
import 'package:nile_quest/models/itinerary_event.dart';
import 'package:nile_quest/models/poi.dart';
import 'package:nile_quest/services/itinerary_editor.dart';

Poi poi(String id, {double lat = 30.0, double lon = 31.2, double duration = 2.0}) {
  return Poi(
    id: id,
    name: 'POI $id',
    lat: lat,
    lon: lon,
    category: 'Historical',
    subcategory: '',
    durationHours: duration,
    cost: 100,
    openingHours: '09:00 - 17:00',
    indoorOutdoor: 'Outdoor',
    score: 0.9,
  );
}

ItineraryEvent event(String id,
    {String start = '09:00',
    String end = '11:00',
    double travel = 0.0,
    double lat = 30.0,
    double lon = 31.2,
    double duration = 2.0}) {
  return ItineraryEvent(
    poi: poi(id, lat: lat, lon: lon, duration: duration),
    startTime: start,
    endTime: end,
    travelTimeHours: travel,
    reason: 'test',
  );
}

Itinerary itinerary(Map<int, List<ItineraryEvent>> days) {
  final total = days.values.fold<int>(0, (s, e) => s + e.length);
  return Itinerary(
    days: days,
    totalDays: days.length,
    totalPois: total,
    interests: ['history'],
  );
}

void main() {
  group('recalcDayTimes', () {
    test('anchors on first event start and cascades sequentially', () {
      final events = [
        event('a', start: '09:00', duration: 2.0),
        event('b', lat: 30.05, duration: 1.0),
        event('c', lat: 30.1, duration: 1.5),
      ];
      final result = ItineraryEditor.recalcDayTimes(events);

      expect(result[0].startTime, '09:00');
      expect(result[0].endTime, '11:00');
      expect(result[0].travelTimeHours, 0.0);

      // Each next start = previous end + travel (>= 9 min floor, rounded to 5)
      for (var i = 1; i < result.length; i++) {
        expect(result[i].travelTimeHours, greaterThanOrEqualTo(0.15));
        final prevEnd = _minutes(result[i - 1].endTime);
        final start = _minutes(result[i].startTime);
        expect(start, greaterThan(prevEnd));
      }
    });

    test('is deterministic', () {
      final events = [
        event('a', duration: 2.0),
        event('b', lat: 30.07, duration: 1.0),
      ];
      final once = ItineraryEditor.recalcDayTimes(events);
      final twice = ItineraryEditor.recalcDayTimes(once);
      expect(twice[0].startTime, once[0].startTime);
      expect(twice[1].startTime, once[1].startTime);
      expect(twice[1].endTime, once[1].endTime);
    });

    test('falls back to 09:00 anchor on malformed start time', () {
      final events = [event('a', start: 'garbage', duration: 1.0)];
      final result = ItineraryEditor.recalcDayTimes(events);
      expect(result[0].startTime, '09:00');
      expect(result[0].endTime, '10:00');
    });

    test('enforces 30-minute floor for zero-duration POIs', () {
      final events = [event('a', start: '10:00', duration: 0.0)];
      final result = ItineraryEditor.recalcDayTimes(events);
      expect(_minutes(result[0].endTime) - _minutes(result[0].startTime), 30);
    });

    test('clamps at 23:55 and reports overload', () {
      final events = [
        event('a', start: '21:00', duration: 2.0),
        event('b', lat: 30.3, duration: 3.0),
        event('c', lat: 30.6, duration: 3.0),
      ];
      final result = ItineraryEditor.recalcDayTimes(events);
      expect(_minutes(result.last.endTime), lessThanOrEqualTo(23 * 60 + 55));
      expect(ItineraryEditor.isDayOverloaded(result), isTrue);
    });
  });

  group('removeStop', () {
    test('removes and retimes, recomputes totalPois', () {
      final it = itinerary({
        1: [event('a'), event('b', lat: 30.05), event('c', lat: 30.1)],
        2: [event('d')],
      });
      final updated = ItineraryEditor.removeStop(it, 1, 1);

      expect(updated.days[1]!.length, 2);
      expect(updated.days[1]![1].poi.id, 'c');
      expect(updated.totalPois, 3);
      // travel time for c now estimated from a, not b
      expect(updated.days[1]![1].travelTimeHours, greaterThan(0));
      // original untouched
      expect(it.days[1]!.length, 3);
    });

    test('out-of-range index is a no-op', () {
      final it = itinerary({
        1: [event('a')]
      });
      expect(ItineraryEditor.removeStop(it, 1, 5), same(it));
      expect(ItineraryEditor.removeStop(it, 9, 0), same(it));
    });

    test('emptied day keeps an empty list (no re-indexing)', () {
      final it = itinerary({
        1: [event('a')],
        2: [event('b')],
      });
      final updated = ItineraryEditor.removeStop(it, 1, 0);
      expect(updated.days[1], isEmpty);
      expect(updated.days[2]!.length, 1);
      expect(updated.totalPois, 1);
    });
  });

  group('reorderWithinDay', () {
    test('moves event and refreshes successor travel times', () {
      final it = itinerary({
        1: [
          event('a', lat: 30.0),
          event('b', lat: 30.1),
          event('c', lat: 30.2),
        ],
      });
      final updated = ItineraryEditor.reorderWithinDay(it, 1, 0, 2);
      final ids = updated.days[1]!.map((e) => e.poi.id).toList();
      expect(ids, ['b', 'c', 'a']);
      expect(updated.days[1]![0].travelTimeHours, 0.0);
      expect(updated.days[1]![2].travelTimeHours, greaterThan(0));
    });
  });

  group('moveBetweenDays', () {
    test('moves stop, retimes both days, preserves day keys', () {
      final it = itinerary({
        1: [event('a'), event('b', lat: 30.05)],
        2: [event('c')],
      });
      final updated = ItineraryEditor.moveBetweenDays(it, 1, 0, 2);

      expect(updated.days[1]!.map((e) => e.poi.id), ['b']);
      expect(updated.days[2]!.map((e) => e.poi.id), ['c', 'a']);
      expect(updated.days.keys.toSet(), {1, 2});
      expect(updated.totalPois, 3);
      // first event of day 1 now has zero travel time
      expect(updated.days[1]![0].travelTimeHours, 0.0);
    });

    test('move into empty day anchors at fallback time', () {
      final it = itinerary({
        1: [event('a', start: '14:00')],
        2: <ItineraryEvent>[],
      });
      final updated = ItineraryEditor.moveBetweenDays(it, 1, 0, 2);
      expect(updated.days[1], isEmpty);
      expect(updated.days[2]!.single.startTime, '14:00');
    });
  });

  group('addStop', () {
    test('appends with retimed schedule and bumped totalPois', () {
      final it = itinerary({
        1: [event('a', start: '09:00', duration: 2.0)],
      });
      final updated = ItineraryEditor.addStop(it, 1, poi('new', lat: 30.08));

      expect(updated.days[1]!.length, 2);
      expect(updated.days[1]![1].poi.id, 'new');
      expect(updated.totalPois, 2);
      final prevEnd = _minutes(updated.days[1]![0].endTime);
      expect(_minutes(updated.days[1]![1].startTime), greaterThan(prevEnd));
    });
  });
}

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
