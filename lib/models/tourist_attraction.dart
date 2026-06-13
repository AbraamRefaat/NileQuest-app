import 'dart:math';
import 'itinerary_event.dart';
import 'poi.dart';

class TouristAttraction {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final String description;
  final String city;
  final double? rating;
  final int? userRatingsTotal;
  final String? photoReference;
  final bool? isOpen;
  final List<String>? types;
  final String? address;
  final String? phoneNumber;
  final String? website;

  TouristAttraction({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    required this.city,
    this.rating,
    this.userRatingsTotal,
    this.photoReference,
    this.isOpen,
    this.types,
    this.address,
    this.phoneNumber,
    this.website,
  });

  factory TouristAttraction.fromJson(Map<String, dynamic> json) {
    return TouristAttraction(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      city: json['city'] as String,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      userRatingsTotal: json['userRatingsTotal'] as int?,
      photoReference: json['photoReference'] as String?,
      isOpen: json['isOpen'] as bool?,
      types: json['types'] != null ? List<String>.from(json['types']) : null,
      address: json['address'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'description': description,
      'city': city,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'photoReference': photoReference,
      'isOpen': isOpen,
      'types': types,
      'address': address,
      'phoneNumber': phoneNumber,
      'website': website,
    };
  }

  TouristAttraction copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? category,
    String? description,
    String? city,
    double? rating,
    int? userRatingsTotal,
    String? photoReference,
    bool? isOpen,
    List<String>? types,
    String? address,
    String? phoneNumber,
    String? website,
  }) {
    return TouristAttraction(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      description: description ?? this.description,
      city: city ?? this.city,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      photoReference: photoReference ?? this.photoReference,
      isOpen: isOpen ?? this.isOpen,
      types: types ?? this.types,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
    );
  }

  /// How "popular" this place is, used to rank the home carousel.
  /// Combines the star rating with how many people reviewed it (log-scaled so
  /// a handful of 5-star reviews can't outrank a world landmark with
  /// thousands). Places without a rating sink to the bottom.
  double get popularityScore {
    if (rating == null) return 0;
    final reviews = userRatingsTotal ?? 0;
    return rating! * log(reviews + 1);
  }

  /// Adapt this attraction to the [ItineraryEvent]/[Poi] shape that
  /// PlaceDetailScreen consumes, so a destination card can open the same
  /// detail view the itinerary uses.
  ItineraryEvent toItineraryEvent() {
    return ItineraryEvent(
      poi: Poi(
        id: id,
        name: name,
        lat: latitude,
        lon: longitude,
        category: category,
        subcategory: (types != null && types!.isNotEmpty)
            ? types!.first.replaceAll('_', ' ')
            : '',
        durationHours: 1.5,
        cost: 0,
        openingHours: isOpen == null
            ? '00:00 - 24:00'
            : (isOpen! ? 'Open now' : 'Closed now'),
        indoorOutdoor: 'Indoor/Outdoor',
        description: description,
        score: popularityScore,
      ),
      startTime: '',
      endTime: '',
      travelTimeHours: 0,
      reason: '',
    );
  }
}
