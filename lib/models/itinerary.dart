import 'itinerary_event.dart';

class Itinerary {
  final Map<int, List<ItineraryEvent>> days;
  final int totalDays;
  final int totalPois;
  // Non-null only when /recommend was called with a specific_interest
  final Map<String, dynamic>? interestSearch;
  final List<String> interests;

  Itinerary({
    required this.days,
    required this.totalDays,
    required this.totalPois,
    this.interestSearch,
    List<String>? interests,
  }) : this.interests = interests ?? [];

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    final Map<int, List<ItineraryEvent>> days = {};

    final rawItinerary = json['itinerary'];
    
    if (rawItinerary is Map) {
      rawItinerary.forEach((dayStr, eventsJson) {
        final day = int.tryParse(dayStr) ?? 0;
        if (day == 0) return;
        
        final events = (eventsJson as List)
            .map((e) => ItineraryEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        days[day] = events;
      });
    } else if (rawItinerary is List) {
      // MongoDB sometimes converts maps with numeric keys into lists
      for (int i = 0; i < rawItinerary.length; i++) {
        final eventsJson = rawItinerary[i];
        if (eventsJson == null) continue;
        
        // MongoDB index might be 0-based, our days are 1-based
        // If the list starts with null at index 0, then index 1 is Day 1
        final day = i; 
        if (day == 0 && rawItinerary.length > 1) continue; // Skip padding if it exists
        
        final events = (eventsJson as List)
            .map((e) => ItineraryEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        days[day] = events;
      }
    }

    // Parse summary data
    final summary = json['summary'] as Map<String, dynamic>? ?? {};

    return Itinerary(
      days: days,
      totalDays: summary['total_days'] as int? ?? 1,
      totalPois: summary['total_pois'] as int? ?? 0,
      // interest_search is optional — only present when specific_interest was sent
      interestSearch: json['interest_search'] as Map<String, dynamic>?,
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> itineraryJson = {};
    days.forEach((day, events) {
      itineraryJson[day.toString()] = events.map((e) => e.toJson()).toList();
    });

    return {
      'itinerary': itineraryJson,
      'summary': {
        'total_days': totalDays,
        'total_pois': totalPois,
      },
      'interests': interests,
      'interest_search': interestSearch,
    };
  }

  /// Get list of all days sorted
  List<int> get sortedDays {
    final daysList = days.keys.toList();
    daysList.sort();
    return daysList;
  }
}
