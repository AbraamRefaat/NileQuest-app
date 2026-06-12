import 'package:flutter/material.dart';
import '../../services/gamification_service.dart' as gam;
import '../../theme.dart';

/// Celebration dialog shown when one or more badges are unlocked.
Future<void> showBadgeUnlockDialog(
    BuildContext context, List<gam.Badge> badges) async {
  if (badges.isEmpty) return;
  await showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badges.length == 1 ? 'Badge Unlocked! 🎉' : 'Badges Unlocked! 🎉',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            ...badges.map((badge) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: badge.color, width: 3),
                          ),
                          child:
                              Icon(badge.icon, size: 40, color: badge.color),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(badge.name, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Awesome!'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
