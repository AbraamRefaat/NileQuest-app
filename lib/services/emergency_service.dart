import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for emergency features and tourist safety
class EmergencyService {
  /// Emergency contact numbers in Egypt
  static const Map<String, String> emergencyNumbers = {
    'Tourist Police': '126',
    'Police': '122',
    'Ambulance': '123',
    'Fire Department': '180',
    'Traffic Police': '128',
  };

  /// Major embassy locations in Cairo
  static final List<EmergencyLocation> cairoDiplomaticMissions = [
    EmergencyLocation(
      name: 'U.S. Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0626,
      lng: 31.2197,
      address: '5 Tawfik Diab St, Garden City, Cairo',
      phone: '+20 2 2797 3300',
      country: 'United States',
    ),
    EmergencyLocation(
      name: 'British Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0626,
      lng: 31.2262,
      address: '7 Ahmed Ragheb St, Garden City, Cairo',
      phone: '+20 2 2791 6000',
      country: 'United Kingdom',
    ),
    EmergencyLocation(
      name: 'German Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0731,
      lng: 31.2089,
      address: '2 Berlin St, Zamalek, Cairo',
      phone: '+20 2 2728 2000',
      country: 'Germany',
    ),
    EmergencyLocation(
      name: 'French Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0444,
      lng: 31.2357,
      address: '29 Charles de Gaulle St, Giza',
      phone: '+20 2 3567 3200',
      country: 'France',
    ),
    EmergencyLocation(
      name: 'Canadian Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0626,
      lng: 31.2197,
      address: '26 Kamel El Shenawy St, Garden City, Cairo',
      phone: '+20 2 2791 8700',
      country: 'Canada',
    ),
    EmergencyLocation(
      name: 'Australian Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0444,
      lng: 31.2357,
      address: 'World Trade Center, 11th Floor, Corniche El Nil, Cairo',
      phone: '+20 2 2575 0444',
      country: 'Australia',
    ),
    EmergencyLocation(
      name: 'Japanese Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0626,
      lng: 31.2197,
      address: '81 Corniche El Nil, Maadi, Cairo',
      phone: '+20 2 2528 5910',
      country: 'Japan',
    ),
    EmergencyLocation(
      name: 'Chinese Embassy Cairo',
      type: EmergencyType.embassy,
      lat: 30.0444,
      lng: 31.2357,
      address: '14 Bahgat Ali St, Zamalek, Cairo',
      phone: '+20 2 2736 5508',
      country: 'China',
    ),
  ];

  /// Major hospitals in Cairo
  static final List<EmergencyLocation> cairoHospitals = [
    EmergencyLocation(
      name: 'As-Salam International Hospital',
      type: EmergencyType.hospital,
      lat: 30.0626,
      lng: 31.3357,
      address: 'Corniche El Nile, Maadi, Cairo',
      phone: '+20 2 2524 0250',
      hasEmergency: true,
    ),
    EmergencyLocation(
      name: 'Dar Al Fouad Hospital',
      type: EmergencyType.hospital,
      lat: 30.0731,
      lng: 31.0089,
      address: '26th of July Corridor, 6th of October City',
      phone: '+20 2 3835 0500',
      hasEmergency: true,
    ),
    EmergencyLocation(
      name: 'Anglo-American Hospital',
      type: EmergencyType.hospital,
      lat: 30.0444,
      lng: 31.2357,
      address: 'Zamalek, Cairo',
      phone: '+20 2 2735 6162',
      hasEmergency: true,
    ),
  ];

  /// Common tourist scams to warn about
  static final List<TouristWarning> commonScams = [
    TouristWarning(
      title: 'Unofficial Tour Guides',
      description: 'Avoid unlicensed guides at tourist sites. Always use official guides with badges.',
      severity: WarningSeverity.medium,
      location: 'Pyramids, Luxor, Aswan',
    ),
    TouristWarning(
      title: 'Overpriced Taxis',
      description: 'Always agree on fare before starting or use Uber/Careem. Insist on using the meter.',
      severity: WarningSeverity.low,
      location: 'All cities',
    ),
    TouristWarning(
      title: 'Papyrus Shops',
      description: 'Many "papyrus" items are fake banana leaf. Buy from reputable shops only.',
      severity: WarningSeverity.low,
      location: 'Cairo, Luxor',
    ),
    TouristWarning(
      title: 'Photography Fees',
      description: 'Some people may demand payment after you photograph them. Ask permission first.',
      severity: WarningSeverity.low,
      location: 'Tourist areas',
    ),
    TouristWarning(
      title: 'Perfume Shops',
      description: 'High-pressure sales tactics. Politely decline if not interested.',
      severity: WarningSeverity.low,
      location: 'Cairo, Luxor',
    ),
  ];

  /// Make emergency call
  Future<bool> makeEmergencyCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Send emergency SMS with location
  Future<bool> sendEmergencySMS({
    required String number,
    required double lat,
    required double lng,
  }) async {
    final message = 'EMERGENCY: I need help. My location: https://maps.google.com/?q=$lat,$lng';
    final uri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: {'body': message},
    );
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Open location in Google Maps for navigation
  Future<bool> navigateToEmergencyLocation(EmergencyLocation location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lng}',
    );
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Get nearest embassy based on user location
  EmergencyLocation? getNearestEmbassy(double userLat, double userLng) {
    if (cairoDiplomaticMissions.isEmpty) return null;

    EmergencyLocation? nearest;
    double minDistance = double.infinity;

    for (var embassy in cairoDiplomaticMissions) {
      final distance = _calculateDistance(userLat, userLng, embassy.lat, embassy.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = embassy;
      }
    }

    return nearest;
  }

  /// Get nearest hospital
  EmergencyLocation? getNearestHospital(double userLat, double userLng) {
    if (cairoHospitals.isEmpty) return null;

    EmergencyLocation? nearest;
    double minDistance = double.infinity;

    for (var hospital in cairoHospitals) {
      final distance = _calculateDistance(userLat, userLng, hospital.lat, hospital.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = hospital;
      }
    }

    return nearest;
  }

  /// Get safe route recommendations (well-lit, populated areas)
  List<String> getSafetyTips(String city, String timeOfDay) {
    List<String> tips = [
      'Keep your valuables secure and out of sight',
      'Stay in well-lit, populated areas',
      'Use official taxis or ride-sharing apps (Uber, Careem)',
      'Keep a copy of your passport in a separate location',
      'Have emergency numbers saved in your phone',
    ];

    if (timeOfDay == 'night') {
      tips.addAll([
        'Avoid walking alone at night in unfamiliar areas',
        'Let someone know your whereabouts',
        'Stay on main streets and avoid shortcuts through alleys',
      ]);
    }

    if (city.toLowerCase() == 'cairo') {
      tips.add('Use the metro during daytime - it\'s safe and efficient');
      tips.add('Downtown Cairo can be crowded - watch for pickpockets');
    }

    return tips;
  }

  /// Medical translation phrases
  static const Map<String, String> medicalPhrases = {
    'I need a doctor': 'أنا بحاجة إلى طبيب (Ana beḥaga ela ṭabīb)',
    'Hospital': 'مستشفى (Mustashfa)',
    'Pharmacy': 'صيدلية (Ṣaydalīya)',
    'I am allergic to': 'أنا عندي حساسية من (Ana ʿandi ḥasāsīya min)',
    'I have pain here': 'عندي ألم هنا (ʿAndi alam hena)',
    'Call an ambulance': 'اتصل بسيارة إسعاف (Ittaṣil bi-sayyārat isʿāf)',
    'I need help': 'أنا بحاجة إلى مساعدة (Ana beḥaga ela musāʿada)',
  };

  /// Useful Arabic phrases for emergencies
  static const Map<String, String> emergencyPhrases = {
    'Help!': 'النجدة! (An-najda!)',
    'Police!': 'شرطة! (Shurṭa!)',
    'Stop!': 'قف! (Qif!)',
    'Fire!': 'حريق! (Ḥarīq!)',
    'I am lost': 'أنا تايه (Ana tāyeh)',
    'Where is the police station?': 'فين قسم الشرطة؟ (Fēn qism ash-shurṭa?)',
    'I need the embassy': 'أنا بحاجة إلى السفارة (Ana beḥaga ela as-sifāra)',
  };

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }
}

enum EmergencyType {
  embassy,
  hospital,
  police,
  touristPolice,
}

class EmergencyLocation {
  final String name;
  final EmergencyType type;
  final double lat;
  final double lng;
  final String address;
  final String phone;
  final String? country;
  final bool? hasEmergency;

  EmergencyLocation({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.address,
    required this.phone,
    this.country,
    this.hasEmergency,
  });

  Position get position => Position(lng, lat);

  String get typeLabel {
    switch (type) {
      case EmergencyType.embassy:
        return 'Embassy';
      case EmergencyType.hospital:
        return 'Hospital';
      case EmergencyType.police:
        return 'Police';
      case EmergencyType.touristPolice:
        return 'Tourist Police';
    }
  }
}

enum WarningSeverity {
  low,
  medium,
  high,
}

class TouristWarning {
  final String title;
  final String description;
  final WarningSeverity severity;
  final String location;

  TouristWarning({
    required this.title,
    required this.description,
    required this.severity,
    required this.location,
  });
}
