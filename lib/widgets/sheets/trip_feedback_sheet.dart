import 'package:flutter/material.dart';
import '../../models/feedback.dart';
import '../../models/trip_session.dart';
import '../../services/auth_service.dart';
import '../../services/feedback_service.dart';
import '../../theme.dart';
import '../common/rating_stars.dart';

/// Post-trip survey shown after the user closes Trip Wrapped.
Future<void> showTripFeedbackSheet(
    BuildContext context, TripSession session) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TripFeedbackSheet(session: session),
  );
}

class _TripFeedbackSheet extends StatefulWidget {
  final TripSession session;

  const _TripFeedbackSheet({required this.session});

  @override
  State<_TripFeedbackSheet> createState() => _TripFeedbackSheetState();
}

class _TripFeedbackSheetState extends State<_TripFeedbackSheet> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool? _wouldRecommend;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) return;
    final comment = _commentController.text.trim();
    FeedbackService().submitTripFeedback(TripFeedback(
      tripSessionId: widget.session.id,
      overallRating: _rating,
      comment: comment.isEmpty ? null : comment,
      wouldRecommend: _wouldRecommend ?? true,
      stopsCompleted: widget.session.visitedCount,
      stopsPlanned: widget.session.stops.length,
      distanceKm: widget.session.distanceWalkedKm,
      firebaseUid: AuthService().currentUser?.uid,
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks — this makes your next trip better! 💙'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _recommendChip(String label, bool value, IconData icon) {
    final selected = _wouldRecommend == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _wouldRecommend = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.charcoal),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.chipLabel.copyWith(
                  color: selected ? Colors.white : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('How was your trip?', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(
              '${widget.session.visitedCount} of ${widget.session.stops.length} stops · '
              '${widget.session.distanceWalkedKm.toStringAsFixed(1)} km',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            RatingStars(
              value: _rating.toDouble(),
              size: 38,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Would you recommend NileQuest?',
                style: AppTextStyles.cardSubtitle
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _recommendChip('Yes!', true, Icons.thumb_up_rounded),
                const SizedBox(width: AppSpacing.sm),
                _recommendChip('Not yet', false, Icons.thumb_down_rounded),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'What should we improve? (optional)',
              ),
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _rating > 0 ? _submit : null,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
