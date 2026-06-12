import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip_session.dart';

/// "NileQuest Wrapped" — Spotify-Wrapped-style animated recap of the trip.
/// Auto-advancing story pages with stats and the photos taken at each stop.
class TripWrappedScreen extends StatefulWidget {
  final TripSession session;

  const TripWrappedScreen({super.key, required this.session});

  @override
  State<TripWrappedScreen> createState() => _TripWrappedScreenState();
}

class _TripWrappedScreenState extends State<TripWrappedScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  late final AnimationController _bounceController;
  Timer? _autoAdvance;
  int _page = 0;

  static const _pageDuration = Duration(seconds: 5);

  List<_WrappedPage> get _pages {
    final s = widget.session;
    final photoStops =
        s.stops.where((st) => st.photoPaths.isNotEmpty).toList();
    final funTitles = [
      'Absolute legend.',
      'Pharaoh-approved.',
      'Cleopatra would be jealous.',
      'The Nile called — it misses you.',
    ];
    final rnd = math.Random(s.id.hashCode);

    return [
      _WrappedPage(
        gradient: const [Color(0xFF1F4E5F), Color(0xFF0E2A33)],
        builder: (anim) => _bigStat(
          emoji: '🏺',
          title: 'Your Day ${s.day} Wrapped',
          big: 'is here.',
          sub: 'Let\'s relive it →',
          anim: anim,
        ),
      ),
      _WrappedPage(
        gradient: const [Color(0xFFE67E22), Color(0xFF9A4A0D)],
        builder: (anim) => _bigStat(
          emoji: '📍',
          title: 'You conquered',
          big: '${s.visitedCount} stops',
          sub: s.visitedCount == s.stops.length
              ? 'A perfect run. ${funTitles[rnd.nextInt(funTitles.length)]}'
              : 'out of ${s.stops.length} planned. Not bad, explorer!',
          anim: anim,
        ),
      ),
      _WrappedPage(
        gradient: const [Color(0xFF9B59B6), Color(0xFF4A2363)],
        builder: (anim) => _bigStat(
          emoji: '🚶',
          title: 'You wandered',
          big: '${s.distanceWalkedKm.toStringAsFixed(1)} km',
          sub:
              'That\'s ~${(s.distanceWalkedKm * 1300).round()} steps. Ancient Egyptians built pyramids — you built stamina.',
          anim: anim,
        ),
      ),
      _WrappedPage(
        gradient: const [Color(0xFF27AE60), Color(0xFF0E5A2E)],
        builder: (anim) => _bigStat(
          emoji: '⏱️',
          title: 'Your adventure lasted',
          big: _formatDuration(s.duration),
          sub: 'Time flies when you\'re basically Indiana Jones.',
          anim: anim,
        ),
      ),
      _WrappedPage(
        gradient: const [Color(0xFFD4AF7A), Color(0xFF8A6A3B)],
        builder: (anim) => _bigStat(
          emoji: '❤️',
          title: 'Your top vibe was',
          big: s.topCategory,
          sub: 'We see you. We respect it.',
          anim: anim,
        ),
      ),
      _WrappedPage(
        gradient: const [Color(0xFF3498DB), Color(0xFF11405E)],
        builder: (anim) => _bigStat(
          emoji: '📸',
          title: 'You captured',
          big: '${s.totalPhotos} photos',
          sub: s.totalPhotos == 0
              ? 'The memories live in your heart instead 💭'
              : 'Each one a masterpiece. Obviously.',
          anim: anim,
        ),
      ),
      // One photo-collage page per stop with photos
      for (final stop in photoStops)
        _WrappedPage(
          gradient: const [Color(0xFF2C3E50), Color(0xFF131C26)],
          builder: (anim) => _photoCollage(stop, anim),
        ),
      _WrappedPage(
        gradient: const [Color(0xFF1F4E5F), Color(0xFFE67E22)],
        builder: (anim) => _finale(s, anim),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController =
        AnimationController(vsync: this, duration: _pageDuration);
    _bounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _startPage();
  }

  void _startPage() {
    _bounceController.forward(from: 0);
    _progressController.forward(from: 0);
    _autoAdvance?.cancel();
    _autoAdvance = Timer(_pageDuration, _next);
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _autoAdvance?.cancel();
      _progressController.stop();
    }
  }

  void _previous() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final w = MediaQuery.of(context).size.width;
          details.globalPosition.dx < w / 3 ? _previous() : _next();
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pages.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                _startPage();
              },
              itemBuilder: (context, i) {
                final p = pages[i];
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: p.gradient,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: p.builder(_bounceController),
                    ),
                  ),
                );
              },
            ),

            // Story progress bars
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: List.generate(pages.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (_, __) => LinearProgressIndicator(
                            value: i < _page
                                ? 1
                                : i == _page
                                    ? _progressController.value
                                    : 0,
                            minHeight: 3,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation(
                                Colors.white),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Close button
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 8, 0),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page builders ──────────────────────────────────────────────────

  Widget _bigStat({
    required String emoji,
    required String title,
    required String big,
    required String sub,
    required AnimationController anim,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: Text(emoji, style: const TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: anim,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim,
            child: Text(
              big,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: anim,
          child: Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoCollage(TripStop stop, AnimationController anim) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeTransition(
          opacity: anim,
          child: Text(
            '📍 ${stop.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              for (int i = 0; i < stop.photoPaths.length && i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: anim,
                        curve: Interval(i * 0.2, 1.0,
                            curve: Curves.easeOutBack),
                      ),
                      child: Transform.rotate(
                        angle: (i - 1) * 0.06,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(stop.photoPaths[i]),
                            fit: BoxFit.cover,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white12,
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Colors.white38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: anim,
          child: Text(
            stop.arrivedAt != null
                ? 'Visited at ${TimeOfDay.fromDateTime(stop.arrivedAt!).format(context)} • iconic.'
                : 'A moment to remember.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _finale(TripSession s, AnimationController anim) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: const Text('🎉', style: TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 20),
        const Text(
          'That\'s a wrap!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${s.visitedCount} stops • ${s.distanceWalkedKm.toStringAsFixed(1)} km • ${s.totalPhotos} photos',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 36),
        ElevatedButton.icon(
          onPressed: () {
            Share.share(
              '🏺 My NileQuest Day ${s.day} Wrapped:\n'
              '📍 ${s.visitedCount} stops conquered\n'
              '🚶 ${s.distanceWalkedKm.toStringAsFixed(1)} km wandered\n'
              '📸 ${s.totalPhotos} memories captured\n'
              'Egypt, you were amazing! ✨',
            );
          },
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share my Wrapped'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F4E5F),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }
}

class _WrappedPage {
  final List<Color> gradient;
  final Widget Function(AnimationController anim) builder;
  _WrappedPage({required this.gradient, required this.builder});
}
