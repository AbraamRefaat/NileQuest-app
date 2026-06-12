import 'package:flutter/material.dart';
import '../../services/gamification_service.dart' as gam;
import '../../theme.dart';

/// Level number + XP progress bar toward the next level.
class LevelProgressBar extends StatelessWidget {
  final gam.UserProgress progress;

  const LevelProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress.progressPercent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${progress.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'LVL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _levelTitle(progress.level),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${progress.xp} / ${progress.xpForNextLevel} XP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelTitle(int level) {
    if (level >= 20) return 'Pharaoh';
    if (level >= 15) return 'Vizier';
    if (level >= 10) return 'Temple Master';
    if (level >= 5) return 'Nile Navigator';
    if (level >= 3) return 'Desert Wanderer';
    return 'Young Explorer';
  }
}
