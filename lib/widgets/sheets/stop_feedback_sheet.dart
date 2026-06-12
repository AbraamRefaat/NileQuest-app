import 'package:flutter/material.dart';
import '../../models/feedback.dart';
import '../../models/trip_session.dart';
import '../../services/auth_service.dart';
import '../../services/feedback_service.dart';
import '../../theme.dart';
import '../common/rating_stars.dart';

/// Quick rating sheet shown right after a stop is completed.
/// One tap on a star submits immediately unless a note is being typed.
Future<void> showStopFeedbackSheet(
  BuildContext context, {
  required TripStop stop,
  required String tripSessionId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _StopFeedbackSheet(
      stop: stop,
      tripSessionId: tripSessionId,
    ),
  );
}

class _StopFeedbackSheet extends StatefulWidget {
  final TripStop stop;
  final String tripSessionId;

  const _StopFeedbackSheet({required this.stop, required this.tripSessionId});

  @override
  State<_StopFeedbackSheet> createState() => _StopFeedbackSheetState();
}

class _StopFeedbackSheetState extends State<_StopFeedbackSheet> {
  final TextEditingController _noteController = TextEditingController();
  int _rating = 0;
  bool _noteFocused = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) return;
    final note = _noteController.text.trim();
    FeedbackService().submitStopFeedback(StopFeedback(
      poiId: widget.stop.poiId,
      poiName: widget.stop.name,
      category: widget.stop.category,
      rating: _rating,
      note: note.isEmpty ? null : note,
      tripSessionId: widget.tripSessionId,
      firebaseUid: AuthService().currentUser?.uid,
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks for the feedback! 🙌'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
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
            Text(
              'How was ${widget.stop.name}?',
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            RatingStars(
              value: _rating.toDouble(),
              size: 38,
              onChanged: (value) {
                setState(() => _rating = value);
                // One-tap happy path: submit right away when no note typed.
                if (!_noteFocused && _noteController.text.trim().isEmpty) {
                  Future.delayed(
                      const Duration(milliseconds: 250), () {
                    if (mounted) _submit();
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              onTap: () => _noteFocused = true,
              decoration: const InputDecoration(
                hintText: 'Anything to add? (optional)',
              ),
              maxLines: 2,
              minLines: 1,
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
