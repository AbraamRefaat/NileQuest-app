import '../constants/categories.dart';
import '../models/trip_session.dart';

/// Turns a finished [TripSession] into the human-facing identity used on the
/// Highlights gallery — an evocative, *stable* title (never "Trip 1"), a
/// subtitle, and the cover photo.
///
/// Titles are derived from what makes the trip unique (its dominant vibe and
/// its headline stop) and picked deterministically from the session id, so a
/// given trip always keeps the same name while different trips read varied.
class WrappedHighlights {
  WrappedHighlights._();

  /// Evocative descriptors keyed by the resolved category label
  /// (see [categoryStyleFor]). A few options each so titles don't all rhyme.
  static const Map<String, List<String>> _descriptors = {
    'Historical': ['Ancient Wonders', 'Echoes of History', 'Timeless Treasures'],
    'Museum': ['Halls of Wonder', 'Curated Treasures'],
    'Religious': ['Sacred Sites', 'Minarets & Monasteries', 'Holy Ground'],
    'Natural': ['Nile Breezes', 'Green Escapes', 'Open Skies'],
    'Shopping': ['Bazaars & Hidden Gems', 'Souks & Treasures'],
    'Beach Resort': ['Sun & Sea', 'Coastal Calm'],
    'Art & Culture': ['Color & Culture', 'City Rhythms'],
    'Food & Dining': ['Tastes & Traditions', 'Street Food & Spices'],
    'Place': ['Egyptian Wanderings', 'A Day of Discovery'],
  };

  /// The evocative title shown on the card and the Wrapped finale.
  static String titleFor(TripSession s) {
    final seed = _seedFor(s);
    final descriptors = _descriptors[
            categoryStyleFor(s.topCategory).label] ??
        _descriptors['Place']!;
    final descriptor = descriptors[seed % descriptors.length];
    final signature = _signatureStop(s);

    final templates = <String>[
      if (signature != null) '$signature & Beyond',
      descriptor,
      'A Day of $descriptor',
      if (signature != null) '$descriptor at $signature',
    ];
    return templates[seed % templates.length];
  }

  /// "Jun 14, 2026 · Day 1 · 4 stops"
  static String subtitleFor(TripSession s) {
    final date = _dateLabel(s.startedAt);
    final stops = s.visitedCount == 1 ? '1 stop' : '${s.visitedCount} stops';
    return '$date · Day ${s.day} · $stops';
  }

  /// First photo taken anywhere on the trip — used as the card cover.
  static String? coverPhotoFor(TripSession s) {
    for (final stop in s.stops) {
      if (stop.photoPaths.isNotEmpty) return stop.photoPaths.first;
    }
    return null;
  }

  /// Headline place: the first *visited* stop, falling back to the first stop.
  static String? _signatureStop(TripSession s) {
    TripStop? pick;
    for (final stop in s.stops) {
      if (stop.status != StopStatus.upcoming) {
        pick = stop;
        break;
      }
    }
    pick ??= s.stops.isNotEmpty ? s.stops.first : null;
    final name = pick?.name.trim() ?? '';
    // Long POI names make clunky titles — skip them.
    if (name.isEmpty || name.length > 24) return null;
    return name;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dateLabel(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// Stable per-trip seed (String.hashCode isn't stable across runs).
  static int _seedFor(TripSession s) {
    var hash = s.day * 31 + s.stops.length;
    for (final unit in s.id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash.abs();
  }
}
