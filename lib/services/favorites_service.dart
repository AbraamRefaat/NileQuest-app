import 'package:shared_preferences/shared_preferences.dart';

/// Persists favorited places locally (SharedPreferences string list).
/// Keys are POI ids where available, otherwise place names.
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _key = 'favorite_pois';

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<bool> isFavorite(String id) async {
    return (await getFavorites()).contains(id);
  }

  /// Toggles and returns the new state (true = now favorited).
  Future<bool> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    final nowFavorite = !favorites.contains(id);
    if (nowFavorite) {
      favorites.add(id);
    } else {
      favorites.remove(id);
    }
    await prefs.setStringList(_key, favorites);
    return nowFavorite;
  }
}
