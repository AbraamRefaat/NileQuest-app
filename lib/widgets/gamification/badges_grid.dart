import 'package:flutter/material.dart';
import '../../services/gamification_service.dart' as gam;
import '../../theme.dart';

/// Grid of all badges; locked ones render greyed out with a lock overlay.
/// Tapping a badge shows its description and progress.
class BadgesGrid extends StatelessWidget {
  final gam.UserProgress progress;

  const BadgesGrid({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final badges = gam.GamificationService().getAllBadges();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final unlocked = progress.unlockedBadges.contains(badge.id);
        return GestureDetector(
          onTap: () => _showBadgeDetails(context, badge, unlocked),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? badge.color.withValues(alpha: 0.15)
                          : AppColors.charcoal.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unlocked
                            ? badge.color
                            : AppColors.charcoal.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      badge.icon,
                      size: 26,
                      color: unlocked
                          ? badge.color
                          : AppColors.charcoal.withValues(alpha: 0.25),
                    ),
                  ),
                  if (!unlocked)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: AppColors.charcoal.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                badge.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: unlocked
                      ? AppColors.charcoal
                      : AppColors.charcoal.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBadgeDetails(BuildContext context, gam.Badge badge, bool unlocked) {
    final current = switch (badge.type) {
      gam.BadgeType.visitCount => progress.visitedAttractions.length,
      gam.BadgeType.distance => progress.totalDistance.round(),
      gam.BadgeType.photoCount => progress.totalPhotos,
      gam.BadgeType.tipCount => progress.totalTips,
      gam.BadgeType.special => 0,
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        title: Row(
          children: [
            Icon(badge.icon,
                color: unlocked ? badge.color : AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(badge.name, style: AppTextStyles.sectionTitle),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(badge.description, style: AppTextStyles.cardSubtitle),
            const SizedBox(height: AppSpacing.md),
            if (unlocked)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Unlocked',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (badge.type != gam.BadgeType.special)
              Text(
                'Progress: $current / ${badge.requirement}',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
