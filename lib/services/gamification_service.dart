import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service for gamification (badges, achievements, tracking)
class GamificationService {
  static const String _storageKey = 'gamification';

  /// Get user progress
  Future<UserProgress> getUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    return UserProgress(
      level: prefs.getInt('${_storageKey}_level') ?? 1,
      xp: prefs.getInt('${_storageKey}_xp') ?? 0,
      visitedAttractions: prefs.getStringList('${_storageKey}_visited') ?? [],
      unlockedBadges: prefs.getStringList('${_storageKey}_badges') ?? [],
      totalDistance: prefs.getDouble('${_storageKey}_distance') ?? 0.0,
      totalPhotos: prefs.getInt('${_storageKey}_photos') ?? 0,
      totalTips: prefs.getInt('${_storageKey}_tips') ?? 0,
    );
  }

  /// Mark attraction as visited
  Future<AchievementResult> visitAttraction(String attractionId, String attractionName) async {
    final progress = await getUserProgress();
    
    if (!progress.visitedAttractions.contains(attractionId)) {
      progress.visitedAttractions.add(attractionId);
      progress.xp += 50; // XP for visiting new place
      
      await _saveProgress(progress);
      
      // Check for new badges
      final newBadges = await _checkForNewBadges(progress);
      
      return AchievementResult(
        xpGained: 50,
        newBadges: newBadges,
        levelUp: _checkLevelUp(progress),
        message: 'Visited $attractionName! +50 XP',
      );
    }
    
    return AchievementResult(
      xpGained: 0,
      newBadges: [],
      levelUp: false,
      message: 'Already visited',
    );
  }

  /// Add distance traveled
  Future<void> addDistance(double km) async {
    final progress = await getUserProgress();
    progress.totalDistance += km;
    await _saveProgress(progress);
  }

  /// Add photo taken
  Future<AchievementResult> addPhoto() async {
    final progress = await getUserProgress();
    progress.totalPhotos += 1;
    progress.xp += 10;
    
    await _saveProgress(progress);
    
    final newBadges = await _checkForNewBadges(progress);
    
    return AchievementResult(
      xpGained: 10,
      newBadges: newBadges,
      levelUp: _checkLevelUp(progress),
      message: 'Photo added! +10 XP',
    );
  }

  /// Add tip shared
  Future<AchievementResult> addTip() async {
    final progress = await getUserProgress();
    progress.totalTips += 1;
    progress.xp += 20;
    
    await _saveProgress(progress);
    
    final newBadges = await _checkForNewBadges(progress);
    
    return AchievementResult(
      xpGained: 20,
      newBadges: newBadges,
      levelUp: _checkLevelUp(progress),
      message: 'Tip shared! +20 XP',
    );
  }

  /// Get all available badges
  List<Badge> getAllBadges() {
    return [
      // Explorer Badges
      Badge(
        id: 'first_visit',
        name: 'First Steps',
        description: 'Visit your first attraction',
        icon: Icons.flag,
        color: Colors.blue,
        category: BadgeCategory.explorer,
        requirement: 1,
        type: BadgeType.visitCount,
      ),
      Badge(
        id: 'explorer_5',
        name: 'Explorer',
        description: 'Visit 5 attractions',
        icon: Icons.explore,
        color: Colors.green,
        category: BadgeCategory.explorer,
        requirement: 5,
        type: BadgeType.visitCount,
      ),
      Badge(
        id: 'adventurer_10',
        name: 'Adventurer',
        description: 'Visit 10 attractions',
        icon: Icons.hiking,
        color: Colors.orange,
        category: BadgeCategory.explorer,
        requirement: 10,
        type: BadgeType.visitCount,
      ),
      Badge(
        id: 'master_25',
        name: 'Master Explorer',
        description: 'Visit 25 attractions',
        icon: Icons.workspace_premium,
        color: Colors.purple,
        category: BadgeCategory.explorer,
        requirement: 25,
        type: BadgeType.visitCount,
      ),
      Badge(
        id: 'legend_50',
        name: 'Legend',
        description: 'Visit 50 attractions',
        icon: Icons.emoji_events,
        color: Colors.amber,
        category: BadgeCategory.explorer,
        requirement: 50,
        type: BadgeType.visitCount,
      ),

      // Distance Badges
      Badge(
        id: 'walker_10km',
        name: 'Walker',
        description: 'Travel 10 km',
        icon: Icons.directions_walk,
        color: Colors.blue,
        category: BadgeCategory.distance,
        requirement: 10,
        type: BadgeType.distance,
      ),
      Badge(
        id: 'hiker_50km',
        name: 'Hiker',
        description: 'Travel 50 km',
        icon: Icons.terrain,
        color: Colors.green,
        category: BadgeCategory.distance,
        requirement: 50,
        type: BadgeType.distance,
      ),
      Badge(
        id: 'nomad_100km',
        name: 'Nomad',
        description: 'Travel 100 km',
        icon: Icons.flight_takeoff,
        color: Colors.orange,
        category: BadgeCategory.distance,
        requirement: 100,
        type: BadgeType.distance,
      ),

      // Photography Badges
      Badge(
        id: 'photographer_10',
        name: 'Photographer',
        description: 'Take 10 photos',
        icon: Icons.camera_alt,
        color: Colors.pink,
        category: BadgeCategory.photographer,
        requirement: 10,
        type: BadgeType.photoCount,
      ),
      Badge(
        id: 'artist_50',
        name: 'Artist',
        description: 'Take 50 photos',
        icon: Icons.photo_camera,
        color: Colors.purple,
        category: BadgeCategory.photographer,
        requirement: 50,
        type: BadgeType.photoCount,
      ),

      // Social Badges
      Badge(
        id: 'helper_5',
        name: 'Helper',
        description: 'Share 5 tips',
        icon: Icons.lightbulb,
        color: Colors.yellow,
        category: BadgeCategory.social,
        requirement: 5,
        type: BadgeType.tipCount,
      ),
      Badge(
        id: 'guide_20',
        name: 'Local Guide',
        description: 'Share 20 tips',
        icon: Icons.stars,
        color: Colors.amber,
        category: BadgeCategory.social,
        requirement: 20,
        type: BadgeType.tipCount,
      ),

      // Special Badges
      Badge(
        id: 'pyramid_visitor',
        name: 'Pyramid Explorer',
        description: 'Visit all 3 Giza Pyramids',
        icon: Icons.change_history,
        color: Colors.brown,
        category: BadgeCategory.special,
        requirement: 3,
        type: BadgeType.special,
      ),
      Badge(
        id: 'museum_buff',
        name: 'Museum Buff',
        description: 'Visit 5 museums',
        icon: Icons.museum,
        color: Colors.indigo,
        category: BadgeCategory.special,
        requirement: 5,
        type: BadgeType.special,
      ),
      Badge(
        id: 'temple_seeker',
        name: 'Temple Seeker',
        description: 'Visit 5 temples',
        icon: Icons.account_balance,
        color: Colors.teal,
        category: BadgeCategory.special,
        requirement: 5,
        type: BadgeType.special,
      ),
    ];
  }

  /// Check for newly earned badges
  Future<List<Badge>> _checkForNewBadges(UserProgress progress) async {
    final allBadges = getAllBadges();
    final newBadges = <Badge>[];

    for (var badge in allBadges) {
      if (!progress.unlockedBadges.contains(badge.id)) {
        bool earned = false;

        switch (badge.type) {
          case BadgeType.visitCount:
            earned = progress.visitedAttractions.length >= badge.requirement;
            break;
          case BadgeType.distance:
            earned = progress.totalDistance >= badge.requirement;
            break;
          case BadgeType.photoCount:
            earned = progress.totalPhotos >= badge.requirement;
            break;
          case BadgeType.tipCount:
            earned = progress.totalTips >= badge.requirement;
            break;
          case BadgeType.special:
            // Special badges require custom logic
            earned = false;
            break;
        }

        if (earned) {
          progress.unlockedBadges.add(badge.id);
          newBadges.add(badge);
        }
      }
    }

    if (newBadges.isNotEmpty) {
      await _saveProgress(progress);
    }

    return newBadges;
  }

  /// Check if user leveled up
  bool _checkLevelUp(UserProgress progress) {
    final requiredXP = _getXPForLevel(progress.level + 1);
    return progress.xp >= requiredXP;
  }

  /// Calculate XP required for level
  int _getXPForLevel(int level) {
    return (level * 100 * math.pow(1.1, level - 1)).round();
  }

  /// Get leaderboard (mock data for demo)
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final progress = await getUserProgress();
    
    return [
      LeaderboardEntry(
        rank: 1,
        userName: 'You',
        level: progress.level,
        xp: progress.xp,
        visitedCount: progress.visitedAttractions.length,
        isCurrentUser: true,
      ),
      LeaderboardEntry(
        rank: 2,
        userName: 'Explorer123',
        level: 15,
        xp: 8500,
        visitedCount: 42,
        isCurrentUser: false,
      ),
      LeaderboardEntry(
        rank: 3,
        userName: 'TravelBug',
        level: 12,
        xp: 6200,
        visitedCount: 35,
        isCurrentUser: false,
      ),
    ];
  }

  Future<void> _saveProgress(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_storageKey}_level', progress.level);
    await prefs.setInt('${_storageKey}_xp', progress.xp);
    await prefs.setStringList('${_storageKey}_visited', progress.visitedAttractions);
    await prefs.setStringList('${_storageKey}_badges', progress.unlockedBadges);
    await prefs.setDouble('${_storageKey}_distance', progress.totalDistance);
    await prefs.setInt('${_storageKey}_photos', progress.totalPhotos);
    await prefs.setInt('${_storageKey}_tips', progress.totalTips);
  }
}

class UserProgress {
  int level;
  int xp;
  List<String> visitedAttractions;
  List<String> unlockedBadges;
  double totalDistance;
  int totalPhotos;
  int totalTips;

  UserProgress({
    required this.level,
    required this.xp,
    required this.visitedAttractions,
    required this.unlockedBadges,
    required this.totalDistance,
    required this.totalPhotos,
    required this.totalTips,
  });

  int get xpForNextLevel => (level * 100 * math.pow(1.1, level)).round();
  int get xpProgress => xp;
  double get progressPercent => (xp / xpForNextLevel * 100).clamp(0, 100);
}

class AchievementResult {
  final int xpGained;
  final List<Badge> newBadges;
  final bool levelUp;
  final String message;

  AchievementResult({
    required this.xpGained,
    required this.newBadges,
    required this.levelUp,
    required this.message,
  });
}

enum BadgeCategory {
  explorer,
  distance,
  photographer,
  social,
  special,
}

enum BadgeType {
  visitCount,
  distance,
  photoCount,
  tipCount,
  special,
}

class Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final BadgeCategory category;
  final int requirement;
  final BadgeType type;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.requirement,
    required this.type,
  });

  String get categoryLabel {
    switch (category) {
      case BadgeCategory.explorer:
        return 'Explorer';
      case BadgeCategory.distance:
        return 'Distance';
      case BadgeCategory.photographer:
        return 'Photographer';
      case BadgeCategory.social:
        return 'Social';
      case BadgeCategory.special:
        return 'Special';
    }
  }
}

class LeaderboardEntry {
  final int rank;
  final String userName;
  final int level;
  final int xp;
  final int visitedCount;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userName,
    required this.level,
    required this.xp,
    required this.visitedCount,
    required this.isCurrentUser,
  });
}
