class Poi {
  final String id;
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
  final String? priceRange;

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
    this.priceRange,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    double parsedCost = 0.0;
    if (json['cost'] != null) {
      parsedCost = (json['cost'] as num).toDouble();
    } else if (json['price_range'] != null) {
      final pr = json['price_range'] as String;
      switch (pr) {
        case '\$':
          parsedCost = 50.0;
          break;
        case '\$\$':
          parsedCost = 150.0;
          break;
        case '\$\$\$':
          parsedCost = 400.0;
          break;
        case '\$\$\$\$':
          parsedCost = 1000.0;
          break;
        default:
          parsedCost = 0.0;
      }
    }

    return Poi(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0.0,
      cost: parsedCost,
      openingHours: json['opening_hours'] as String? ?? '00:00 - 24:00',
      indoorOutdoor: json['indoor_outdoor'] as String? ?? 'Indoor/Outdoor',
      description: json['description'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photo_url'] as String?,
      priceRange: json['price_range'] as String?,
    );
  }

  String get priceDisplay {
    if (priceRange != null && priceRange!.trim().isNotEmpty) {
      return priceRange!.trim();
    }
    if (cost == 0) return 'Free';
    if (cost <= 50) return '\$';
    if (cost <= 150) return '\$\$';
    if (cost <= 400) return '\$\$\$';
    return '\$\$\$\$';
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
      'price_range': priceRange,
    };
  }
}
