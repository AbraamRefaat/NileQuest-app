import 'package:flutter/material.dart';
import '../../services/gamification_service.dart' as gam;
import '../../theme.dart';
import 'badge_unlock_dialog.dart';

/// Surfaces an [gam.AchievementResult]: XP toast, level-up toast, and the
/// badge celebration dialog when new badges were earned.
void showAchievement(BuildContext context, gam.AchievementResult result) {
  if (result.xpGained > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded,
                color: AppColors.secondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (result.levelUp) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        content: const Row(
          children: [
            Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Level up! 🎉',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  if (result.newBadges.isNotEmpty) {
    showBadgeUnlockDialog(context, result.newBadges);
  }
}
