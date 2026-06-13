import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/trip_session.dart';
import '../services/trip_session_service.dart';
import '../services/wrapped_highlights.dart';
import '../theme.dart';
import 'trip_wrapped_screen.dart';

/// "Highlights" — a gallery of every finished trip's Wrapped recap, so the
/// user can relive any adventure on demand. Reached from the Profile screen.
class HighlightsScreen extends StatefulWidget {
  const HighlightsScreen({super.key});

  @override
  State<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends State<HighlightsScreen> {
  List<TripSession>? _sessions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await TripSessionService().getHistory();
    if (!mounted) return;
    setState(() {
      _sessions = history.reversed.toList();
      _loading = false;
    });
  }

  void _openWrapped(TripSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripWrappedScreen(session: session)),
    );
  }

  Future<void> _confirmDelete(TripSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: const Text("Delete highlight?"),
        content: Text(
          '${WrappedHighlights.titleFor(session)} and its '
          '${session.totalPhotos} photo${session.totalPhotos == 1 ? "" : "s"} '
          "will be permanently removed. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove instantly from the UI, then persist.
    setState(() => _sessions?.removeWhere((s) => s.id == session.id));
    await TripSessionService().deleteFromHistory(session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Highlight deleted")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const <TripSession>[];
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          _buildHeader(sessions.length),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (sessions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _HighlightCard(
                    session: sessions[i],
                    onTap: () => _openWrapped(sessions[i]),
                    onDelete: () => _confirmDelete(sessions[i]),
                  ),
                  childCount: sessions.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Highlights',
                        style: AppTextStyles.screenTitle.copyWith(fontSize: 30)),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'Your trip recaps live here'
                          : count == 1
                              ? '1 adventure relived anytime'
                              : '$count adventures, relived anytime',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Text('🏺', style: TextStyle(fontSize: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 24),
          Text('No highlights yet',
              style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Finish a trip and your personalized recap — stats, photos and all — '
            'will be saved here to relive whenever you want.',
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A "story cover" tile: real trip photo (or a category gradient) under a
/// scrim, with the evocative title and quick stats.
class _HighlightCard extends StatelessWidget {
  final TripSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HighlightCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cover = WrappedHighlights.coverPhotoFor(session);
    final style = categoryStyleFor(session.topCategory);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Cover ──
                if (cover != null)
                  Image.file(
                    File(cover),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _gradientCover(style),
                  )
                else
                  _gradientCover(style),

                // ── Readability scrim ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.35, 0.6, 1.0],
                    ),
                  ),
                ),

                // ── Category pill (top-left) ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Day ${session.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── "Play" affordance (top-right) ──
                const Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.play_arrow_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                ),

                // ── Title + stats ──
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WrappedHighlights.titleFor(session),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        WrappedHighlights.subtitleFor(session),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _stat(Icons.photo_camera_rounded,
                              '${session.totalPhotos}'),
                          const SizedBox(width: 8),
                          _stat(Icons.directions_walk_rounded,
                              '${session.distanceWalkedKm.toStringAsFixed(1)}km'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Delete button (bottom-right corner, red) ──
                Positioned(
                  bottom: 12,
                  right: 10,
                  child: Material(
                    color: Colors.red,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientCover(CategoryStyle style) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.color, Color.lerp(style.color, Colors.black, 0.45)!],
        ),
      ),
      child: Center(
        child: Icon(style.icon,
            color: Colors.white.withValues(alpha: 0.30), size: 64),
      ),
    );
  }

  Widget _stat(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
