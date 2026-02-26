class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final String? time;
  final String? imageUrl;
  final String eventUrl;
  final String? category;
  final double? price;
  final bool isBookmarked;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startDate,
    this.endDate,
    this.time,
    this.imageUrl,
    required this.eventUrl,
    this.category,
    this.price,
    this.isBookmarked = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? json['venue'] ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      time: json['time'] ?? json['startTime'],
      imageUrl: json['imageUrl'] ?? json['image'],
      eventUrl: json['eventUrl'] ?? json['url'] ?? '',
      category: json['category'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'time': time,
      'imageUrl': imageUrl,
      'eventUrl': eventUrl,
      'category': category,
      'price': price,
      'isBookmarked': isBookmarked,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    String? time,
    String? imageUrl,
    String? eventUrl,
    String? category,
    double? price,
    bool? isBookmarked,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      time: time ?? this.time,
      imageUrl: imageUrl ?? this.imageUrl,
      eventUrl: eventUrl ?? this.eventUrl,
      category: category ?? this.category,
      price: price ?? this.price,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  String get formattedDay {
    return startDate.day.toString().padLeft(2, '0');
  }

  String get formattedMonth {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[startDate.month - 1];
  }

  String get formattedYear {
    return startDate.year.toString();
  }
}
