import 'dart:math' as math;
import 'package:image_picker/image_picker.dart' as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for user-generated content (photos, tips, reviews)
class UserContentService {
  final picker.ImagePicker _imagePicker = picker.ImagePicker();
  
  // Local storage for demo (in production, use Firebase/backend)
  static const String _storageKey = 'user_content';

  /// Upload photo with location
  Future<UserPhoto?> uploadPhoto({
    required double lat,
    required double lng,
    required String attractionName,
    String? caption,
    List<String>? tags,
  }) async {
    try {
      // Pick image from gallery or camera
      final picker.XFile? image = await _imagePicker.pickImage(
        source: picker.ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      // In production, upload to Firebase Storage or your backend
      // For now, store locally
      final photo = UserPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user', // Replace with actual user ID
        userName: 'Tourist', // Replace with actual user name
        imagePath: image.path,
        lat: lat,
        lng: lng,
        attractionName: attractionName,
        caption: caption,
        tags: tags ?? [],
        timestamp: DateTime.now(),
        likes: 0,
      );

      await _savePhotoLocally(photo);
      return photo;
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  /// Add tip/advice for location
  Future<UserTip> addTip({
    required double lat,
    required double lng,
    required String attractionName,
    required String tipText,
    required TipCategory category,
  }) async {
    final tip = UserTip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      userName: 'Tourist',
      lat: lat,
      lng: lng,
      attractionName: attractionName,
      tipText: tipText,
      category: category,
      timestamp: DateTime.now(),
      helpful: 0,
    );

    await _saveTipLocally(tip);
    return tip;
  }

  /// Add review for attraction
  Future<UserReview> addReview({
    required double lat,
    required double lng,
    required String attractionName,
    required double rating,
    required String reviewText,
    List<String>? pros,
    List<String>? cons,
  }) async {
    final review = UserReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      userName: 'Tourist',
      lat: lat,
      lng: lng,
      attractionName: attractionName,
      rating: rating,
      reviewText: reviewText,
      pros: pros ?? [],
      cons: cons ?? [],
      timestamp: DateTime.now(),
      helpful: 0,
    );

    await _saveReviewLocally(review);
    return review;
  }

  /// Get photos near location
  Future<List<UserPhoto>> getPhotosNearLocation({
    required double lat,
    required double lng,
    double radiusKm = 1.0,
  }) async {
    final allPhotos = await _getAllPhotos();
    
    return allPhotos.where((photo) {
      final distance = _calculateDistance(lat, lng, photo.lat, photo.lng);
      return distance <= radiusKm;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get tips near location
  Future<List<UserTip>> getTipsNearLocation({
    required double lat,
    required double lng,
    double radiusKm = 1.0,
  }) async {
    final allTips = await _getAllTips();
    
    return allTips.where((tip) {
      final distance = _calculateDistance(lat, lng, tip.lat, tip.lng);
      return distance <= radiusKm;
    }).toList()
      ..sort((a, b) => b.helpful.compareTo(a.helpful));
  }

  /// Get reviews near location
  Future<List<UserReview>> getReviewsNearLocation({
    required double lat,
    required double lng,
    double radiusKm = 1.0,
  }) async {
    final allReviews = await _getAllReviews();
    
    return allReviews.where((review) {
      final distance = _calculateDistance(lat, lng, review.lat, review.lng);
      return distance <= radiusKm;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Mark tip as helpful
  Future<void> markTipHelpful(String tipId) async {
    final tips = await _getAllTips();
    final tipIndex = tips.indexWhere((t) => t.id == tipId);
    
    if (tipIndex != -1) {
      tips[tipIndex] = UserTip(
        id: tips[tipIndex].id,
        userId: tips[tipIndex].userId,
        userName: tips[tipIndex].userName,
        lat: tips[tipIndex].lat,
        lng: tips[tipIndex].lng,
        attractionName: tips[tipIndex].attractionName,
        tipText: tips[tipIndex].tipText,
        category: tips[tipIndex].category,
        timestamp: tips[tipIndex].timestamp,
        helpful: tips[tipIndex].helpful + 1,
      );
      
      await _saveTipsLocally(tips);
    }
  }

  /// Like photo
  Future<void> likePhoto(String photoId) async {
    final photos = await _getAllPhotos();
    final photoIndex = photos.indexWhere((p) => p.id == photoId);
    
    if (photoIndex != -1) {
      photos[photoIndex] = UserPhoto(
        id: photos[photoIndex].id,
        userId: photos[photoIndex].userId,
        userName: photos[photoIndex].userName,
        imagePath: photos[photoIndex].imagePath,
        lat: photos[photoIndex].lat,
        lng: photos[photoIndex].lng,
        attractionName: photos[photoIndex].attractionName,
        caption: photos[photoIndex].caption,
        tags: photos[photoIndex].tags,
        timestamp: photos[photoIndex].timestamp,
        likes: photos[photoIndex].likes + 1,
      );
      
      await _savePhotosLocally(photos);
    }
  }

  // Local storage methods
  Future<void> _savePhotoLocally(UserPhoto photo) async {
    final photos = await _getAllPhotos();
    photos.add(photo);
    await _savePhotosLocally(photos);
  }

  Future<void> _saveTipLocally(UserTip tip) async {
    final tips = await _getAllTips();
    tips.add(tip);
    await _saveTipsLocally(tips);
  }

  Future<void> _saveReviewLocally(UserReview review) async {
    final reviews = await _getAllReviews();
    reviews.add(review);
    await _saveReviewsLocally(reviews);
  }

  Future<List<UserPhoto>> _getAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList('${_storageKey}_photos') ?? [];
    return photosJson.map((json) => UserPhoto.fromJson(json)).toList();
  }

  Future<List<UserTip>> _getAllTips() async {
    final prefs = await SharedPreferences.getInstance();
    final tipsJson = prefs.getStringList('${_storageKey}_tips') ?? [];
    return tipsJson.map((json) => UserTip.fromJson(json)).toList();
  }

  Future<List<UserReview>> _getAllReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final reviewsJson = prefs.getStringList('${_storageKey}_reviews') ?? [];
    return reviewsJson.map((json) => UserReview.fromJson(json)).toList();
  }

  Future<void> _savePhotosLocally(List<UserPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = photos.map((p) => p.toJson()).toList();
    await prefs.setStringList('${_storageKey}_photos', photosJson);
  }

  Future<void> _saveTipsLocally(List<UserTip> tips) async {
    final prefs = await SharedPreferences.getInstance();
    final tipsJson = tips.map((t) => t.toJson()).toList();
    await prefs.setStringList('${_storageKey}_tips', tipsJson);
  }

  Future<void> _saveReviewsLocally(List<UserReview> reviews) async {
    final prefs = await SharedPreferences.getInstance();
    final reviewsJson = reviews.map((r) => r.toJson()).toList();
    await prefs.setStringList('${_storageKey}_reviews', reviewsJson);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}

class UserPhoto {
  final String id;
  final String userId;
  final String userName;
  final String imagePath;
  final double lat;
  final double lng;
  final String attractionName;
  final String? caption;
  final List<String> tags;
  final DateTime timestamp;
  final int likes;

  UserPhoto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.attractionName,
    this.caption,
    required this.tags,
    required this.timestamp,
    required this.likes,
  });

  Position get position => Position(lng, lat);

  String toJson() {
    return '$id|$userId|$userName|$imagePath|$lat|$lng|$attractionName|${caption ?? ''}|${tags.join(',')}|${timestamp.millisecondsSinceEpoch}|$likes';
  }

  factory UserPhoto.fromJson(String json) {
    final parts = json.split('|');
    return UserPhoto(
      id: parts[0],
      userId: parts[1],
      userName: parts[2],
      imagePath: parts[3],
      lat: double.parse(parts[4]),
      lng: double.parse(parts[5]),
      attractionName: parts[6],
      caption: parts[7].isEmpty ? null : parts[7],
      tags: parts[8].isEmpty ? [] : parts[8].split(','),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[9])),
      likes: int.parse(parts[10]),
    );
  }
}

enum TipCategory {
  timing,
  pricing,
  safety,
  photography,
  food,
  transport,
  general,
}

class UserTip {
  final String id;
  final String userId;
  final String userName;
  final double lat;
  final double lng;
  final String attractionName;
  final String tipText;
  final TipCategory category;
  final DateTime timestamp;
  final int helpful;

  UserTip({
    required this.id,
    required this.userId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.attractionName,
    required this.tipText,
    required this.category,
    required this.timestamp,
    required this.helpful,
  });

  Position get position => Position(lng, lat);

  String get categoryLabel {
    switch (category) {
      case TipCategory.timing:
        return 'Best Time';
      case TipCategory.pricing:
        return 'Pricing';
      case TipCategory.safety:
        return 'Safety';
      case TipCategory.photography:
        return 'Photography';
      case TipCategory.food:
        return 'Food';
      case TipCategory.transport:
        return 'Transport';
      case TipCategory.general:
        return 'General';
    }
  }

  String toJson() {
    return '$id|$userId|$userName|$lat|$lng|$attractionName|$tipText|${category.index}|${timestamp.millisecondsSinceEpoch}|$helpful';
  }

  factory UserTip.fromJson(String json) {
    final parts = json.split('|');
    return UserTip(
      id: parts[0],
      userId: parts[1],
      userName: parts[2],
      lat: double.parse(parts[3]),
      lng: double.parse(parts[4]),
      attractionName: parts[5],
      tipText: parts[6],
      category: TipCategory.values[int.parse(parts[7])],
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[8])),
      helpful: int.parse(parts[9]),
    );
  }
}

class UserReview {
  final String id;
  final String userId;
  final String userName;
  final double lat;
  final double lng;
  final String attractionName;
  final double rating; // 1-5
  final String reviewText;
  final List<String> pros;
  final List<String> cons;
  final DateTime timestamp;
  final int helpful;

  UserReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.attractionName,
    required this.rating,
    required this.reviewText,
    required this.pros,
    required this.cons,
    required this.timestamp,
    required this.helpful,
  });

  Position get position => Position(lng, lat);

  String toJson() {
    return '$id|$userId|$userName|$lat|$lng|$attractionName|$rating|$reviewText|${pros.join(',')}|${cons.join(',')}|${timestamp.millisecondsSinceEpoch}|$helpful';
  }

  factory UserReview.fromJson(String json) {
    final parts = json.split('|');
    return UserReview(
      id: parts[0],
      userId: parts[1],
      userName: parts[2],
      lat: double.parse(parts[3]),
      lng: double.parse(parts[4]),
      attractionName: parts[5],
      rating: double.parse(parts[6]),
      reviewText: parts[7],
      pros: parts[8].isEmpty ? [] : parts[8].split(','),
      cons: parts[9].isEmpty ? [] : parts[9].split(','),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[10])),
      helpful: int.parse(parts[11]),
    );
  }
}
