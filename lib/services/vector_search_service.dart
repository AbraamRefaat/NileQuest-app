import 'dart:convert';
import 'package:http/http.dart' as http;
import 'server_config.dart';

/// A POI returned by the model's vector (semantic) search
class VectorSearchResult {
  final String name;
  final double lat;
  final double lon;
  final String category;
  final String description;
  final double? score;
  final String? photoUrl;

  VectorSearchResult({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    required this.description,
    this.score,
    this.photoUrl,
  });

  factory VectorSearchResult.fromJson(Map<String, dynamic> json) {
    // Tolerant parsing — the model may return lat/lon under different keys
    double parseNum(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return VectorSearchResult(
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      lat: parseNum(json['lat'] ?? json['latitude'] ?? json['Latitude']),
      lon: parseNum(json['lon'] ?? json['lng'] ?? json['longitude'] ?? json['Longitude']),
      category: (json['category'] ?? json['Category'] ?? '').toString(),
      description:
          (json['description'] ?? json['Description'] ?? '').toString(),
      score: json['score'] is num ? (json['score'] as num).toDouble() : null,
      photoUrl: json['photo_url']?.toString(),
    );
  }

  bool get hasCoordinates => lat != 0 && lon != 0;
}

class VectorSearchResponse {
  final List<VectorSearchResult> places;
  final String? aiRecommendation;

  VectorSearchResponse({required this.places, this.aiRecommendation});
}

/// Semantic search against the recommendation model's vector dataset
/// (SentenceTransformer embeddings over the 150+ POI dataset).
class VectorSearchService {
  /// e.g. query: "quiet places with ancient art" → semantically ranked POIs
  static Future<VectorSearchResponse> search(String query,
      {int topK = 10}) async {
    final baseUrl = await ServerConfig.getServerUrl();
    final response = await http
        .post(
          Uri.parse('$baseUrl/search-by-interest'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query, 'top_k': topK}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Vector search failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final placesRaw = (data['places'] as List?) ?? [];
    final places = placesRaw
        .map((p) => VectorSearchResult.fromJson(p as Map<String, dynamic>))
        .where((p) => p.name.isNotEmpty)
        .toList();

    return VectorSearchResponse(
      places: places,
      aiRecommendation: _cleanRecommendation(data['recommendation']),
    );
  }

  /// The backend sometimes returns raw internal ids (UUID lists) in the
  /// recommendation field — those are useless to show a tourist, so only
  /// keep recommendations that read like an actual sentence.
  static String? _cleanRecommendation(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final uuidRe = RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    if (text.startsWith('[') || text.startsWith('{') || uuidRe.hasMatch(text)) {
      return null;
    }
    return text;
  }
}
