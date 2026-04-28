import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';

/// Service for audio guides at tourist attractions
class AudioGuideService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  String? _currentAttractionId;
  
  // Geofencing
  final Map<String, GeofenceZone> _activeGeofences = {};
  Timer? _geofenceTimer;

  AudioGuideService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5); // Slower for tourists
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
    });
  }

  /// Play audio guide for an attraction
  Future<void> playGuide(String attractionId, String text, {String? language}) async {
    if (_isPlaying && _currentAttractionId == attractionId) {
      await stop();
      return;
    }

    if (language != null) {
      await _flutterTts.setLanguage(language);
    }

    _currentAttractionId = attractionId;
    _isPlaying = true;
    await _flutterTts.speak(text);
  }

  /// Stop current audio
  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
    _currentAttractionId = null;
  }

  /// Pause audio
  Future<void> pause() async {
    await _flutterTts.pause();
    _isPlaying = false;
  }

  /// Resume audio
  Future<void> resume() async {
    // Note: Flutter TTS doesn't support resume, need to replay
    _isPlaying = true;
  }

  /// Set language
  Future<void> setLanguage(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
  }

  /// Set speech rate (0.5 = slow, 1.0 = normal, 1.5 = fast)
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }

  /// Add geofence for auto-play
  void addGeofence({
    required String attractionId,
    required double lat,
    required double lng,
    required double radiusMeters,
    required String audioText,
    String? language,
  }) {
    _activeGeofences[attractionId] = GeofenceZone(
      attractionId: attractionId,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      audioText: audioText,
      language: language,
      hasTriggered: false,
    );
  }

  /// Start monitoring geofences
  void startGeofenceMonitoring(Stream<UserLocation> locationStream) {
    locationStream.listen((userLocation) {
      _checkGeofences(userLocation.lat, userLocation.lng);
    });
  }

  /// Check if user entered any geofence
  void _checkGeofences(double userLat, double userLng) {
    for (var geofence in _activeGeofences.values) {
      if (geofence.hasTriggered) continue;

      final distance = _calculateDistance(
        userLat,
        userLng,
        geofence.lat,
        geofence.lng,
      );

      if (distance * 1000 <= geofence.radiusMeters) {
        // User entered geofence
        geofence.hasTriggered = true;
        playGuide(
          geofence.attractionId,
          geofence.audioText,
          language: geofence.language,
        );
      }
    }
  }

  /// Remove geofence
  void removeGeofence(String attractionId) {
    _activeGeofences.remove(attractionId);
  }

  /// Clear all geofences
  void clearAllGeofences() {
    _activeGeofences.clear();
  }

  /// Get audio guide content for major attractions
  static Map<String, AudioGuideContent> getAudioGuides() {
    return {
      'great_pyramid': AudioGuideContent(
        title: 'Great Pyramid of Giza',
        language: 'en-US',
        duration: 180, // seconds
        text: '''
Welcome to the Great Pyramid of Giza, one of the Seven Wonders of the Ancient World. 
Built around 2560 BC for Pharaoh Khufu, this magnificent structure stood as the tallest 
man-made structure for over 3,800 years. The pyramid was originally 146.5 meters tall 
and consists of approximately 2.3 million stone blocks, each weighing an average of 2.5 tons.

The precision of its construction is remarkable. The base is level to within just 2 centimeters, 
and the sides are aligned almost perfectly with the cardinal directions. Inside, you'll find 
three chambers: the King's Chamber, the Queen's Chamber, and an unfinished chamber cut into 
the bedrock beneath the pyramid.

The pyramid was originally covered in smooth white limestone casing stones, which would have 
made it shine brilliantly in the Egyptian sun. Most of these stones were removed over the 
centuries and used for other building projects in Cairo.

Take a moment to imagine the thousands of workers who built this incredible monument, 
working for decades to create a tomb fit for a pharaoh. The Great Pyramid remains a 
testament to ancient Egyptian engineering and ambition.
        ''',
      ),
      'sphinx': AudioGuideContent(
        title: 'Great Sphinx of Giza',
        language: 'en-US',
        duration: 120,
        text: '''
You are now standing before the Great Sphinx of Giza, one of the most iconic monuments 
of ancient Egypt. This limestone statue, with the body of a lion and the head of a human, 
is believed to represent Pharaoh Khafre, who ruled Egypt around 2500 BC.

The Sphinx measures 73 meters long and 20 meters high, making it the largest monolith 
statue in the world. It was carved directly from the limestone bedrock of the Giza plateau.

Throughout history, the Sphinx has been buried up to its shoulders in sand multiple times. 
The first recorded excavation was by Thutmose IV around 1400 BC. Between its paws, you 
can see the Dream Stele, which tells the story of how Thutmose cleared the sand after 
the Sphinx appeared to him in a dream.

The Sphinx has lost its nose, and while many theories exist about how this happened, 
the most likely explanation is erosion and deliberate vandalism in medieval times. 
Despite the damage, the Sphinx continues to captivate visitors with its mysterious 
expression and imposing presence.
        ''',
      ),
      'egyptian_museum': AudioGuideContent(
        title: 'Egyptian Museum Cairo',
        language: 'en-US',
        duration: 150,
        text: '''
Welcome to the Egyptian Museum in Tahrir Square, home to the world's most extensive 
collection of ancient Egyptian artifacts. Founded in 1902, this museum houses over 
120,000 items, with thousands more in storage.

The museum's most famous exhibit is the treasures of Tutankhamun, discovered by 
Howard Carter in 1922. The collection includes the iconic golden death mask, which 
weighs 11 kilograms and is made of solid gold inlaid with semi-precious stones.

As you explore the museum, you'll encounter mummies of pharaohs, including Ramses II 
and Hatshepsut, intricate jewelry, everyday objects, and monumental statues. Each 
artifact tells a story of life in ancient Egypt, from the grandeur of royal courts 
to the daily lives of ordinary people.

The museum is organized chronologically, starting with the Old Kingdom on the ground 
floor and progressing through the Middle and New Kingdoms. Don't miss the Royal Mummy 
Room, where you can see the actual preserved bodies of Egypt's greatest rulers.

Take your time to absorb the incredible history surrounding you. These artifacts 
have survived for thousands of years and offer us a unique window into one of 
humanity's greatest civilizations.
        ''',
      ),
      'karnak_temple': AudioGuideContent(
        title: 'Karnak Temple',
        language: 'en-US',
        duration: 200,
        text: '''
Welcome to the Karnak Temple Complex, the largest religious building ever constructed. 
This vast site covers over 100 hectares and was built over a period of 2,000 years, 
with contributions from numerous pharaohs.

You are standing in the Great Hypostyle Hall, one of the most impressive architectural 
achievements of ancient Egypt. This hall contains 134 massive columns arranged in 16 rows. 
The central columns are 21 meters high and 3.5 meters in diameter. Look up at the capitals 
- they're designed to resemble papyrus plants, sacred to the ancient Egyptians.

Karnak was dedicated to the Theban triad of gods: Amun, Mut, and Khonsu. The temple 
served as the center of religious life in ancient Thebes for over 2,000 years. Pharaohs 
would come here to legitimize their rule and communicate with the gods.

As you walk through the complex, notice the hieroglyphics carved into the walls. These 
tell stories of military victories, religious ceremonies, and the daily rituals performed 
by priests. The Sacred Lake, which you'll see ahead, was used by priests for ritual 
purification ceremonies.

The Avenue of Sphinxes once connected Karnak to Luxor Temple, 3 kilometers away. 
Imagine the grand processions that would have traveled this route during religious 
festivals, with thousands of people celebrating their gods.
        ''',
      ),
    };
  }

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

  void dispose() {
    _geofenceTimer?.cancel();
    stop();
  }
}

class GeofenceZone {
  final String attractionId;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String audioText;
  final String? language;
  bool hasTriggered;

  GeofenceZone({
    required this.attractionId,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.audioText,
    this.language,
    this.hasTriggered = false,
  });
}

class AudioGuideContent {
  final String title;
  final String language;
  final int duration; // in seconds
  final String text;

  AudioGuideContent({
    required this.title,
    required this.language,
    required this.duration,
    required this.text,
  });
}

class UserLocation {
  final double lat;
  final double lng;

  UserLocation({required this.lat, required this.lng});
}
