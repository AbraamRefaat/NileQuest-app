import '../models/itinerary.dart';

/// Status of a single stop during an active trip
enum StopStatus { upcoming, arrived, completed }

/// One stop in an active trip session
class TripStop {
  final String poiId;
  final String name;
  final String category;
  final double lat;
  final double lon;
  final String startTime;
  final String endTime;
  final double cost;
  final String? photoUrl;
  StopStatus status;
  DateTime? arrivedAt;
  List<String> photoPaths;

  TripStop({
    required this.poiId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    required this.startTime,
    required this.endTime,
    required this.cost,
    this.photoUrl,
    this.status = StopStatus.upcoming,
    this.arrivedAt,
    List<String>? photoPaths,
  }) : photoPaths = photoPaths ?? [];

  Map<String, dynamic> toJson() => {
        'poiId': poiId,
        'name': name,
        'category': category,
        'lat': lat,
        'lon': lon,
        'startTime': startTime,
        'endTime': endTime,
        'cost': cost,
        'photoUrl': photoUrl,
        'status': status.index,
        'arrivedAt': arrivedAt?.toIso8601String(),
        'photoPaths': photoPaths,
      };

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        poiId: json['poiId'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        startTime: json['startTime'] ?? '',
        endTime: json['endTime'] ?? '',
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
        photoUrl: json['photoUrl'],
        status: StopStatus.values[json['status'] ?? 0],
        arrivedAt: json['arrivedAt'] != null
            ? DateTime.tryParse(json['arrivedAt'])
            : null,
        photoPaths: (json['photoPaths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

/// An active or finished trip session for one itinerary day
class TripSession {
  final String id;
  final int day;
  final List<TripStop> stops;
  final DateTime startedAt;
  DateTime? endedAt;
  double distanceWalkedKm;

  TripSession({
    required this.id,
    required this.day,
    required this.stops,
    required this.startedAt,
    this.endedAt,
    this.distanceWalkedKm = 0,
  });

  bool get isActive => endedAt == null;
  int get visitedCount =>
      stops.where((s) => s.status != StopStatus.upcoming).length;
  int get totalPhotos =>
      stops.fold(0, (sum, s) => sum + s.photoPaths.length);
  TripStop? get nextStop {
    for (final s in stops) {
      if (s.status == StopStatus.upcoming) return s;
    }
    return null;
  }

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  /// Most visited category — for the Wrapped stats
  String get topCategory {
    final counts = <String, int>{};
    for (final s in stops.where((s) => s.status != StopStatus.upcoming)) {
      counts[s.category] = (counts[s.category] ?? 0) + 1;
    }
    if (counts.isEmpty) return '—';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get totalCostVisited => stops
      .where((s) => s.status != StopStatus.upcoming)
      .fold(0.0, (sum, s) => sum + s.cost);

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'stops': stops.map((s) => s.toJson()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'distanceWalkedKm': distanceWalkedKm,
      };

  factory TripSession.fromJson(Map<String, dynamic> json) => TripSession(
        id: json['id'],
        day: json['day'] ?? 1,
        stops: (json['stops'] as List)
            .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        startedAt: DateTime.parse(json['startedAt']),
        endedAt:
            json['endedAt'] != null ? DateTime.tryParse(json['endedAt']) : null,
        distanceWalkedKm:
            (json['distanceWalkedKm'] as num?)?.toDouble() ?? 0,
      );

  /// Build a session from one day of an itinerary
  factory TripSession.fromItineraryDay(Itinerary itinerary, int day) {
    final events = itinerary.days[day] ?? [];
    return TripSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      day: day,
      startedAt: DateTime.now(),
      stops: events
          .map((e) => TripStop(
                poiId: e.poi.id,
                name: e.poi.name,
                category: e.poi.category,
                lat: e.poi.lat,
                lon: e.poi.lon,
                startTime: e.startTime,
                endTime: e.endTime,
                cost: e.poi.cost,
                photoUrl: e.poi.photoUrl,
              ))
          .toList(),
    );
  }
}
