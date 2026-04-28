import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/tourist_attraction.dart';

/// Service for managing offline map data
class OfflineMapsService {
  static Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize local database for offline data
  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/offline_maps.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Downloaded regions table
        await db.execute('''
          CREATE TABLE downloaded_regions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            center_lat REAL NOT NULL,
            center_lng REAL NOT NULL,
            radius_km REAL NOT NULL,
            download_date INTEGER NOT NULL,
            size_mb REAL NOT NULL
          )
        ''');

        // Cached attractions table
        await db.execute('''
          CREATE TABLE cached_attractions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            category TEXT NOT NULL,
            description TEXT,
            city TEXT,
            rating REAL,
            photo_reference TEXT,
            address TEXT,
            phone_number TEXT,
            website TEXT,
            region_id INTEGER,
            FOREIGN KEY (region_id) REFERENCES downloaded_regions (id)
          )
        ''');

        // Cached routes table
        await db.execute('''
          CREATE TABLE cached_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            origin_lat REAL NOT NULL,
            origin_lng REAL NOT NULL,
            dest_lat REAL NOT NULL,
            dest_lng REAL NOT NULL,
            polyline TEXT NOT NULL,
            distance TEXT NOT NULL,
            duration TEXT NOT NULL,
            mode TEXT NOT NULL,
            cached_date INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Download region for offline use
  Future<OfflineRegion> downloadRegion({
    required String name,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    required List<TouristAttraction> attractions,
  }) async {
    final db = await database;

    // Calculate approximate size (rough estimate)
    final sizeMb = attractions.length * 0.05; // ~50KB per attraction

    // Insert region
    final regionId = await db.insert('downloaded_regions', {
      'name': name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_km': radiusKm,
      'download_date': DateTime.now().millisecondsSinceEpoch,
      'size_mb': sizeMb,
    });

    // Insert attractions
    for (var attraction in attractions) {
      await db.insert(
        'cached_attractions',
        {
          'id': attraction.id,
          'name': attraction.name,
          'latitude': attraction.latitude,
          'longitude': attraction.longitude,
          'category': attraction.category,
          'description': attraction.description,
          'city': attraction.city,
          'rating': attraction.rating,
          'photo_reference': attraction.photoReference,
          'address': attraction.address,
          'phone_number': attraction.phoneNumber,
          'website': attraction.website,
          'region_id': regionId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return OfflineRegion(
      id: regionId,
      name: name,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
      downloadDate: DateTime.now(),
      sizeMb: sizeMb,
      attractionCount: attractions.length,
    );
  }

  /// Get all downloaded regions
  Future<List<OfflineRegion>> getDownloadedRegions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloaded_regions');

    List<OfflineRegion> regions = [];
    for (var map in maps) {
      final attractionCount = await db.query(
        'cached_attractions',
        where: 'region_id = ?',
        whereArgs: [map['id']],
      );

      regions.add(OfflineRegion(
        id: map['id'],
        name: map['name'],
        centerLat: map['center_lat'],
        centerLng: map['center_lng'],
        radiusKm: map['radius_km'],
        downloadDate: DateTime.fromMillisecondsSinceEpoch(map['download_date']),
        sizeMb: map['size_mb'],
        attractionCount: attractionCount.length,
      ));
    }

    return regions;
  }

  /// Delete downloaded region
  Future<void> deleteRegion(int regionId) async {
    final db = await database;
    await db.delete('cached_attractions', where: 'region_id = ?', whereArgs: [regionId]);
    await db.delete('downloaded_regions', where: 'id = ?', whereArgs: [regionId]);
  }

  /// Get cached attractions for a region
  Future<List<TouristAttraction>> getCachedAttractions(int regionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_attractions',
      where: 'region_id = ?',
      whereArgs: [regionId],
    );

    return maps.map((map) {
      return TouristAttraction(
        id: map['id'],
        name: map['name'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        category: map['category'],
        description: map['description'] ?? '',
        city: map['city'] ?? '',
        rating: map['rating'],
        photoReference: map['photo_reference'],
        address: map['address'],
        phoneNumber: map['phone_number'],
        website: map['website'],
      );
    }).toList();
  }

  /// Check if location is within any downloaded region
  Future<OfflineRegion?> findRegionForLocation(double lat, double lng) async {
    final regions = await getDownloadedRegions();
    
    for (var region in regions) {
      final distance = _calculateDistance(
        lat,
        lng,
        region.centerLat,
        region.centerLng,
      );
      
      if (distance <= region.radiusKm) {
        return region;
      }
    }
    
    return null;
  }

  /// Cache a route for offline use
  Future<void> cacheRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String polyline,
    required String distance,
    required String duration,
    required String mode,
  }) async {
    final db = await database;
    
    await db.insert(
      'cached_routes',
      {
        'origin_lat': originLat,
        'origin_lng': originLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'polyline': polyline,
        'distance': distance,
        'duration': duration,
        'mode': mode,
        'cached_date': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached route
  Future<CachedRoute?> getCachedRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String mode,
  }) async {
    final db = await database;
    
    // Find route within 100m tolerance
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_routes',
      where: '''
        mode = ? AND
        ABS(origin_lat - ?) < 0.001 AND
        ABS(origin_lng - ?) < 0.001 AND
        ABS(dest_lat - ?) < 0.001 AND
        ABS(dest_lng - ?) < 0.001
      ''',
      whereArgs: [mode, originLat, originLng, destLat, destLng],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return CachedRoute(
      polyline: map['polyline'],
      distance: map['distance'],
      duration: map['duration'],
      mode: map['mode'],
      cachedDate: DateTime.fromMillisecondsSinceEpoch(map['cached_date']),
    );
  }

  /// Clear old cached routes (older than 7 days)
  Future<void> clearOldRoutes() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    await db.delete(
      'cached_routes',
      where: 'cached_date < ?',
      whereArgs: [sevenDaysAgo.millisecondsSinceEpoch],
    );
  }

  /// Get total offline storage size
  Future<double> getTotalStorageSizeMb() async {
    final regions = await getDownloadedRegions();
    double total = 0.0;
    for (var region in regions) {
      total += region.sizeMb;
    }
    return total;
  }

  /// Calculate distance between two points (km)
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

  /// Predefined regions for quick download
  static List<PredefinedRegion> getPredefinedRegions() {
    return [
      PredefinedRegion(
        name: 'Cairo & Giza',
        centerLat: 30.0444,
        centerLng: 31.2357,
        radiusKm: 25,
        estimatedSizeMb: 15,
        description: 'Pyramids, Egyptian Museum, Islamic Cairo, Citadel',
      ),
      PredefinedRegion(
        name: 'Luxor',
        centerLat: 25.6872,
        centerLng: 32.6396,
        radiusKm: 15,
        estimatedSizeMb: 8,
        description: 'Valley of the Kings, Karnak Temple, Luxor Temple',
      ),
      PredefinedRegion(
        name: 'Aswan',
        centerLat: 24.0889,
        centerLng: 32.8998,
        radiusKm: 20,
        estimatedSizeMb: 6,
        description: 'Philae Temple, Abu Simbel, Nubian Village',
      ),
      PredefinedRegion(
        name: 'Alexandria',
        centerLat: 31.2001,
        centerLng: 29.9187,
        radiusKm: 20,
        estimatedSizeMb: 10,
        description: 'Bibliotheca Alexandrina, Citadel of Qaitbay, Corniche',
      ),
      PredefinedRegion(
        name: 'Sharm El Sheikh',
        centerLat: 27.9158,
        centerLng: 34.3300,
        radiusKm: 15,
        estimatedSizeMb: 5,
        description: 'Naama Bay, Ras Mohammed, diving spots',
      ),
      PredefinedRegion(
        name: 'Hurghada',
        centerLat: 27.2579,
        centerLng: 33.8116,
        radiusKm: 15,
        estimatedSizeMb: 5,
        description: 'Red Sea resorts, diving, water sports',
      ),
    ];
  }
}

class OfflineRegion {
  final int id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final DateTime downloadDate;
  final double sizeMb;
  final int attractionCount;

  OfflineRegion({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.downloadDate,
    required this.sizeMb,
    required this.attractionCount,
  });

  String get sizeText {
    if (sizeMb < 1) {
      return '${(sizeMb * 1024).toStringAsFixed(0)} KB';
    }
    return '${sizeMb.toStringAsFixed(1)} MB';
  }

  String get downloadDateText {
    final now = DateTime.now();
    final difference = now.difference(downloadDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }
}

class PredefinedRegion {
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final double estimatedSizeMb;
  final String description;

  PredefinedRegion({
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.estimatedSizeMb,
    required this.description,
  });
}

class CachedRoute {
  final String polyline;
  final String distance;
  final String duration;
  final String mode;
  final DateTime cachedDate;

  CachedRoute({
    required this.polyline,
    required this.distance,
    required this.duration,
    required this.mode,
    required this.cachedDate,
  });
}
