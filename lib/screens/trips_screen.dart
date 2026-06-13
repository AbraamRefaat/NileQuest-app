import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import 'itinerary_screen.dart';

class TripsScreen extends StatelessWidget {
  final Itinerary? currentItinerary;
  final UserPreferences? currentPreferences;
  final bool isHistoryView;
  final String? tripBackendId;
  final Function(int day, int placeIndex) onPlaceClick;
  final Function(Itinerary, String?) OnViewTrip;
  final ValueChanged<Itinerary>? onItineraryChanged;
  final ValueChanged<String>? onTripSaved;

  /// Called when the user finishes / dismisses the current trip so it moves
  /// to history and the Trip tab shows the empty state again.
  final VoidCallback? onTripFinished;

  const TripsScreen({
    super.key,
    this.currentItinerary,
    this.currentPreferences,
    required this.isHistoryView,
    this.tripBackendId,
    required this.onPlaceClick,
    required this.OnViewTrip,
    this.onItineraryChanged,
    this.onTripSaved,
    this.onTripFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Trips',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  // "Finish Trip" button — only shown when a current trip exists
                  if (currentItinerary != null && onTripFinished != null)
                    TextButton.icon(
                      onPressed: () => _confirmFinishTrip(context),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Finish Trip'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _buildCurrentTripTab(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmFinishTrip(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finish this trip?'),
        content: const Text(
          'The trip will be moved to your Trip history in your Profile. '
          'You can always view it there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              onTripFinished?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip moved to history ✓'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTripTab(BuildContext context) {
    if (currentItinerary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready for your next adventure?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Generate a personalized itinerary on the Home tab to start your journey.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ItineraryScreen(
      itinerary: currentItinerary,
      preferences: currentPreferences,
      onPlaceClick: onPlaceClick,
      isHistoryView: isHistoryView,
      isEmbedded: true,
      tripBackendId: tripBackendId,
      onItineraryChanged: onItineraryChanged,
      onTripSaved: onTripSaved,
    );
  }
}
