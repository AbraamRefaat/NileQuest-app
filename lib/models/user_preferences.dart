class UserPreferences {
  final String? city;
  final int? durationDays;
  final String? budgetTier; // "budget" | "moderate" | "luxury"
  final List<String> interests; // Ordered by priority
  final String? pace; // "relaxed" | "moderate" | "packed"
  final String startTime;
  final String endTime;
  final String? specificInterest; // Optional free-text from Step 6

  UserPreferences({
    this.city,
    this.durationDays,
    this.budgetTier,
    this.interests = const [],
    this.pace,
    this.startTime = "09:00",
    this.endTime = "18:00",
    this.specificInterest,
  });

  Map<String, dynamic> toJson() => {
        'city': city,
        'durationDays': durationDays,
        'budgetTier': budgetTier,
        'interests': interests,
        'pace': pace,
        'startTime': startTime,
        'endTime': endTime,
        'specificInterest': specificInterest,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        city: json['city'],
        durationDays: json['durationDays'],
        budgetTier: json['budgetTier'],
        interests: (json['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        pace: json['pace'],
        startTime: json['startTime'] ?? '09:00',
        endTime: json['endTime'] ?? '18:00',
        specificInterest: json['specificInterest'],
      );

  // Convert ordered interests list to weighted map
  // First interest gets weight 1.0, second 0.9, third 0.8, etc., minimum 0.1
  Map<String, double> getInterestsWeighted() {
    final Map<String, double> weighted = {};
    for (int i = 0; i < interests.length; i++) {
      final weight = (1.0 - (i * 0.1)).clamp(0.1, 1.0);
      weighted[interests[i]] = weight;
    }
    return weighted;
  }

  Map<String, dynamic> toApiRequest() {
    final tier = budgetTier ?? 'moderate';
    final days = durationDays ?? 1;

    // Map budget tier to daily budget
    final budgetDaily = _getBudgetDailyFromTier(tier);

    final body = <String, dynamic>{
      'interests': getInterestsWeighted(),
      'budget_tier': tier,
      'budget_daily': budgetDaily,
      'budget_total': budgetDaily * days * 1.5,
      'duration_days': days,
      'pace': pace ?? 'moderate',
      'start_time': startTime,
      'end_time': endTime,
      'geo_center': _getGeoCenterForCity(city),
      'geo_radius_km': 20.0,
      'willingness_to_pay_entry': true,
      'indoor_preference': 'neutral',
    };

    // Only include specific_interest when the user actually typed something
    final trimmed = (specificInterest ?? '').trim();
    if (trimmed.isNotEmpty) {
      body['specific_interest'] = trimmed;
    }

    return body;
  }

  double _getBudgetDailyFromTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'budget':
        return 1500.0;
      case 'luxury':
        return 10000.0;
      case 'moderate':
      default:
        return 3500.0;
    }
  }

  List<double>? _getGeoCenterForCity(String? city) {
    if (city == null) return null;

    // Cairo coordinates
    switch (city.toLowerCase()) {
      case 'cairo':
        return [30.0444, 31.2357];
      case 'giza':
        return [30.0131, 31.2089];
      case 'alexandria':
        return [31.2001, 29.9187];
      case 'luxor':
        return [25.6872, 32.6396];
      case 'aswan':
        return [24.0889, 32.8998];
      default:
        return [30.0444, 31.2357]; // Default to Cairo
    }
  }

  bool isComplete() {
    return city != null &&
        durationDays != null &&
        durationDays! > 0 &&
        budgetTier != null &&
        interests.isNotEmpty &&
        pace != null;
  }

  UserPreferences copyWith({
    String? city,
    int? durationDays,
    String? budgetTier,
    List<String>? interests,
    String? pace,
    String? startTime,
    String? endTime,
    String? specificInterest,
  }) {
    return UserPreferences(
      city: city ?? this.city,
      durationDays: durationDays ?? this.durationDays,
      budgetTier: budgetTier ?? this.budgetTier,
      interests: interests ?? this.interests,
      pace: pace ?? this.pace,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      specificInterest: specificInterest ?? this.specificInterest,
    );
  }

  String getBudgetDisplay() {
    switch (budgetTier?.toLowerCase()) {
      case 'budget':
        return 'Budget';
      case 'moderate':
        return 'Moderate';
      case 'luxury':
        return 'Luxury';
      default:
        return 'Moderate';
    }
  }
}
