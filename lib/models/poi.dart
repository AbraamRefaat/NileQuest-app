class Poi {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final String category;
  final String subcategory;
  final double durationHours;
  final double cost;
  final String openingHours;
  final String indoorOutdoor;
  final String description;
  final double score;
  final String? photoUrl;

  Poi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    required this.subcategory,
    required this.durationHours,
    required this.cost,
    required this.openingHours,
    required this.indoorOutdoor,
    this.description = '',
    required this.score,
    this.photoUrl,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'] as int,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      durationHours: (json['duration_hours'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      openingHours: json['opening_hours'] as String,
      indoorOutdoor: json['indoor_outdoor'] as String,
      description: json['description'] as String? ?? '',
      score: (json['score'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'category': category,
      'subcategory': subcategory,
      'duration_hours': durationHours,
      'cost': cost,
      'opening_hours': openingHours,
      'indoor_outdoor': indoorOutdoor,
      'description': description,
      'score': score,
      'photo_url': photoUrl,
    };
  }
}
