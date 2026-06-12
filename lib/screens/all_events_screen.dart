import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/event.dart';
import '../services/tazkarti_service.dart';
import '../widgets/cards/event_card.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/category_chips.dart';
import '../widgets/common/empty_state.dart';

class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  final TazkartiService _tazkartiService = TazkartiService();
  List<Event> _events = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  List<String> get _categories =>
      ['All', ...{for (final e in _events) e.category ?? 'Other'}];

  List<Event> get _filteredEvents => _selectedCategory == 'All'
      ? _events
      : _events
          .where((e) => (e.category ?? 'Other') == _selectedCategory)
          .toList();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _tazkartiService.fetchMusicEvents();
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openEventUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open event page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // Elegant SliverAppBar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: const Center(child: AppBackButton.onDark()),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!_isLoading && _events.isNotEmpty)
                    Text(
                      '${_events.length} events available',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    right: -30,
                    top: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 60,
                    bottom: -40,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -30,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_events.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No upcoming events available',
              ),
            )
          else ...[
            // Category filter (hidden when all events share one category)
            if (_categories.length > 2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: CategoryChips(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelected: (category) =>
                        setState(() => _selectedCategory = category),
                  ),
                ),
              ),
            if (_filteredEvents.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No events in this category',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = _filteredEvents[index];
                      return EventCard(
                        event: event,
                        onTap: () => _openEventUrl(event.eventUrl),
                      );
                    },
                    childCount: _filteredEvents.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

}
