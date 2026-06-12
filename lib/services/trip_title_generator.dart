import '../models/itinerary.dart';
import '../models/user_preferences.dart';

/// Generates evocative, personal trip titles instead of the generic
/// "Cairo Adventure (2026-06-12)".
///
/// The title is built from what actually makes the trip unique — its top
/// interests, its signature stop, and its length — and the template is
/// picked deterministically from the itinerary's content, so the same trip
/// always keeps the same name while different trips get varied ones.
///
/// Examples:
///   "Gardens & Sacred Sites — 3 Days in Cairo"
///   "Al-Azhar Park & Beyond: A Cairo Journey"
///   "One Day of Local Flavors in Luxor"
class TripTitleGenerator {
  TripTitleGenerator._();

  /// Evocative descriptors per interest. A couple of options each so titles
  /// don't all read the same; the seed picks which one is used.
  static const Map<String, List<String>> _descriptors = {
    'history': ['Ancient Wonders', 'Echoes of History', 'Timeless Treasures'],
    'food': ['Local Flavors', 'Street Food & Spices', 'Tastes & Traditions'],
    'nature': ['Gardens & Nile Breezes', 'Green Escapes', 'Nature Trails'],
    'shopping': ['Bazaars & Hidden Gems', 'Souks & Treasures'],
    'entertainment': ['Lights & Nights', 'City Rhythms'],
    'religious': ['Sacred Sites', 'Minarets & Monasteries', 'Holy Places'],
  };

  static String generate(Itinerary itinerary, UserPreferences? preferences) {
    final city = preferences?.city ?? 'Egypt';
    final days = itinerary.totalDays;
    final interests =
        preferences?.interests.isNotEmpty == true
            ? preferences!.interests
            : itinerary.interests;

    // Stable per-trip seed: same itinerary → same title, different
    // itineraries → different template/descriptor picks.
    final seed = _seedFor(itinerary);

    final descriptors = _pickDescriptors(interests, seed);
    final signatureStop = _signatureStop(itinerary);

    final dayLabel = days == 1 ? 'One Day' : '$days Days';

    // Candidate templates, in seed-rotated order. Falls through to later
    // candidates when ingredients (descriptors / signature stop) are missing.
    final templates = <String?>[
      if (descriptors.length >= 2)
        '${descriptors[0]} & ${descriptors[1]} — $dayLabel in $city',
      if (signatureStop != null && descriptors.isNotEmpty)
        '$signatureStop & Beyond: A $city Journey',
      if (descriptors.isNotEmpty)
        days == 1
            ? 'One Day of ${descriptors[0]} in $city'
            : '$city Unveiled: ${descriptors[0]}',
      if (signatureStop != null) '$signatureStop & Beyond — $dayLabel in $city',
    ];
    final candidates = templates.whereType<String>().toList();
    if (candidates.isEmpty) return '$dayLabel in $city';

    return candidates[seed % candidates.length];
  }

  /// First stop of the first day — the trip's "headline" place.
  static String? _signatureStop(Itinerary itinerary) {
    if (itinerary.days.isEmpty) return null;
    final firstDay = (itinerary.days.keys.toList()..sort()).first;
    final events = itinerary.days[firstDay];
    if (events == null || events.isEmpty) return null;
    final name = events.first.poi.name.trim();
    // Long POI names make clunky titles — skip them.
    if (name.isEmpty || name.length > 28) return null;
    return name;
  }

  /// Map the user's top two interests to evocative descriptors.
  static List<String> _pickDescriptors(List<String> interests, int seed) {
    final picked = <String>[];
    for (final interest in interests.take(2)) {
      final options = _descriptors[interest.toLowerCase().trim()];
      if (options != null) {
        picked.add(options[seed % options.length]);
      }
    }
    return picked;
  }

  /// Content-derived seed, stable across restarts for the same itinerary.
  /// (Uses a hand-rolled string hash — String.hashCode isn't guaranteed
  /// stable across runs, and the title must not change between saves.)
  static int _seedFor(Itinerary itinerary) {
    var hash = itinerary.totalPois * 31 + itinerary.totalDays;
    if (itinerary.days.isNotEmpty) {
      final firstDay = (itinerary.days.keys.toList()..sort()).first;
      final events = itinerary.days[firstDay];
      if (events != null && events.isNotEmpty) {
        for (final unit in events.first.poi.name.codeUnits) {
          hash = (hash * 31 + unit) & 0x7fffffff;
        }
      }
    }
    return hash.abs();
  }
}
