import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/itinerary.dart';
import '../models/user_preferences.dart';
import 'itinerary_screen.dart';
import 'my_trips_screen.dart';

class TripsScreen extends StatefulWidget {
  final Itinerary? currentItinerary;
  final UserPreferences? currentPreferences;
  final bool isHistoryView;
  final String? tripBackendId;
  final Function(int) onPlaceClick;
  final Function(Itinerary, String?) OnViewTrip;
  final ValueChanged<Itinerary>? onItineraryChanged;
  final ValueChanged<String>? onTripSaved;

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
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Start on History tab if it's history view, otherwise Current Trip
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: (widget.isHistoryView || widget.currentItinerary == null) ? 1 : 0
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
              child: Text(
                'My Trips',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.charcoal.withValues(alpha: 0.6),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Current Trip'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                   _buildCurrentTripTab(),
                  MyTripsScreen(
                    onBack: () {}, // Not used in tab view
                    OnViewTrip: (itinerary, backendId) {
                      widget.OnViewTrip(itinerary, backendId);
                      // Switch to current trip tab to show the selected history trip
                      _tabController.animateTo(0);
                    },
                    isEmbedded: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTripTab() {
    if (widget.currentItinerary == null) {
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
      itinerary: widget.currentItinerary,
      preferences: widget.currentPreferences,
      onPlaceClick: widget.onPlaceClick,
      isHistoryView: widget.isHistoryView,
      isEmbedded: true,
      tripBackendId: widget.tripBackendId,
      onItineraryChanged: widget.onItineraryChanged,
      onTripSaved: widget.onTripSaved,
    );
  }
}
