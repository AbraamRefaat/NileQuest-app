/// User feedback models. Payloads carry poiId/category/rating so they can
/// later feed the recommendation model as training signal.
class StopFeedback {
  final String poiId;
  final String poiName;
  final String category;
  final int rating; // 1-5
  final String? note;
  final String tripSessionId;
  final String? firebaseUid;
  final DateTime createdAt;

  StopFeedback({
    required this.poiId,
    required this.poiName,
    required this.category,
    required this.rating,
    this.note,
    required this.tripSessionId,
    this.firebaseUid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'poi_id': poiId,
        'poi_name': poiName,
        'category': category,
        'rating': rating,
        'note': note,
        'trip_session_id': tripSessionId,
        'firebase_uid': firebaseUid,
        'created_at': createdAt.toIso8601String(),
      };

  factory StopFeedback.fromJson(Map<String, dynamic> json) => StopFeedback(
        poiId: json['poi_id'] ?? '',
        poiName: json['poi_name'] ?? '',
        category: json['category'] ?? '',
        rating: json['rating'] ?? 0,
        note: json['note'],
        tripSessionId: json['trip_session_id'] ?? '',
        firebaseUid: json['firebase_uid'],
        createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      );
}

class TripFeedback {
  final String tripSessionId;
  final int overallRating; // 1-5
  final String? comment;
  final bool wouldRecommend;
  final int stopsCompleted;
  final int stopsPlanned;
  final double distanceKm;
  final String? firebaseUid;
  final DateTime createdAt;

  TripFeedback({
    required this.tripSessionId,
    required this.overallRating,
    this.comment,
    required this.wouldRecommend,
    required this.stopsCompleted,
    required this.stopsPlanned,
    required this.distanceKm,
    this.firebaseUid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'trip_session_id': tripSessionId,
        'overall_rating': overallRating,
        'comment': comment,
        'would_recommend': wouldRecommend,
        'stops_completed': stopsCompleted,
        'stops_planned': stopsPlanned,
        'distance_km': distanceKm,
        'firebase_uid': firebaseUid,
        'created_at': createdAt.toIso8601String(),
      };

  factory TripFeedback.fromJson(Map<String, dynamic> json) => TripFeedback(
        tripSessionId: json['trip_session_id'] ?? '',
        overallRating: json['overall_rating'] ?? 0,
        comment: json['comment'],
        wouldRecommend: json['would_recommend'] ?? false,
        stopsCompleted: json['stops_completed'] ?? 0,
        stopsPlanned: json['stops_planned'] ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
        firebaseUid: json['firebase_uid'],
        createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      );
}
