import 'poi.dart';

class ItineraryEvent {
  final Poi poi;
  final String startTime;
  final String endTime;
  final double travelTimeHours;
  final String reason;

  ItineraryEvent({
    required this.poi,
    required this.startTime,
    required this.endTime,
    required this.travelTimeHours,
    required this.reason,
  });

  factory ItineraryEvent.fromJson(Map<String, dynamic> json) {
    return ItineraryEvent(
      poi: Poi.fromJson(json['poi'] as Map<String, dynamic>),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      travelTimeHours: (json['travel_time_hours'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poi': poi.toJson(),
      'start_time': startTime,
      'end_time': endTime,
      'travel_time_hours': travelTimeHours,
      'reason': reason,
    };
  }
}
