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
}
