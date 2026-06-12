import 'package:flutter_test/flutter_test.dart';
import 'package:nile_quest/services/gamification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('visiting a new attraction awards 50 XP once', () async {
    final service = GamificationService();

    final first = await service.visitAttraction('poi_1', 'Pyramids');
    expect(first.xpGained, 50);

    final repeat = await service.visitAttraction('poi_1', 'Pyramids');
    expect(repeat.xpGained, 0);

    final progress = await service.getUserProgress();
    expect(progress.xp, 50);
    expect(progress.visitedAttractions, ['poi_1']);
  });

  test('level increments and persists when XP crosses the threshold', () async {
    final service = GamificationService();

    // Level 2 needs 220 XP (2 * 100 * 1.1^1). Five visits = 250 XP.
    AchievementResult? lastResult;
    for (var i = 0; i < 5; i++) {
      lastResult = await service.visitAttraction('poi_$i', 'POI $i');
    }

    final progress = await service.getUserProgress();
    expect(progress.xp, 250);
    expect(progress.level, 2, reason: 'stored level must actually increment');
    expect(lastResult!.levelUp, isTrue);
  });

  test('first visit unlocks the First Steps badge', () async {
    final service = GamificationService();
    final result = await service.visitAttraction('poi_1', 'Pyramids');

    expect(result.newBadges.map((b) => b.id), contains('first_visit'));

    final progress = await service.getUserProgress();
    expect(progress.unlockedBadges, contains('first_visit'));
  });

  test('addPhotos batches XP and counts in one call', () async {
    final service = GamificationService();
    final result = await service.addPhotos(3);

    expect(result.xpGained, 30);
    final progress = await service.getUserProgress();
    expect(progress.totalPhotos, 3);
    expect(progress.xp, 30);
  });

  test('distance accumulates and unlocks distance badges', () async {
    final service = GamificationService();
    final result = await service.addDistance(12.0);

    expect(result.newBadges.map((b) => b.id), contains('walker_10km'));
    final progress = await service.getUserProgress();
    expect(progress.totalDistance, 12.0);
  });
}
