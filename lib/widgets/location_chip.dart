import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../theme.dart';

class LocationChip extends StatefulWidget {
  const LocationChip({super.key});

  @override
  State<LocationChip> createState() => _LocationChipState();
}

class _LocationChipState extends State<LocationChip> {
  Future<WeatherInfo?>? _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = WeatherService.getCurrentWeather();
  }

  void _retry() {
    setState(() {
      _weatherFuture = WeatherService.getCurrentWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherInfo?>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: snapshot.connectionState == ConnectionState.waiting
              ? null
              : _retry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, Color(0xFFE8A87C)],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildContent(snapshot),
          ),
        );
      },
    );
  }

  Widget _buildContent(AsyncSnapshot<WeatherInfo?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (!snapshot.hasData || snapshot.data == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Tap to get weather',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final weather = snapshot.data!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        // Always-scrolling ticker for city name
        _TickerText(
          text: weather.city,
          viewWidth: 80,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        Icon(weather.weatherIcon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          weather.temperatureDisplay,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TickerText — infinite left-scrolling ticker.
// The text scrolls from right to left in a seamless loop.
// It always scrolls, regardless of whether the city name is short or long.
// Speed is constant at [pixelsPerSecond].
// ---------------------------------------------------------------------------
class _TickerText extends StatefulWidget {
  final String text;

  /// The visible window width in logical pixels.
  final double viewWidth;

  final TextStyle style;

  /// Scroll speed in logical pixels per second.
  final double pixelsPerSecond;

  const _TickerText({
    required this.text,
    required this.viewWidth,
    required this.style,
    this.pixelsPerSecond = 30,
  });

  @override
  State<_TickerText> createState() => _TickerTextState();
}

class _TickerTextState extends State<_TickerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // The full width of one "unit" = text width + a gap before it repeats.
  double _unitWidth = 0;

  // Horizontal gap between end of text and start of next copy.
  static const double _gap = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(_TickerText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.pixelsPerSecond != widget.pixelsPerSecond) {
      _controller.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _start() {
    if (!mounted) return;

    // Measure raw text width
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    // One "cycle" = text + gap. We scroll this distance then loop.
    // We ensure the unit is at least viewWidth so the loop looks seamless
    // even for short city names.
    final textWidth = tp.size.width;
    _unitWidth = textWidth + _gap;
    if (_unitWidth < widget.viewWidth) {
      _unitWidth = widget.viewWidth + _gap;
    }

    // Duration to scroll one unit at the configured speed.
    final durationMs = ((_unitWidth / widget.pixelsPerSecond) * 1000).round();
    _controller.duration = Duration(milliseconds: durationMs);

    // Single 0→1 tween; we map it to pixel offset in the builder.
    _controller.repeat();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: widget.viewWidth,
        height: 16, // matches font size nicely
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // How far we've scrolled in the current cycle (0 → _unitWidth)
            final offset = _controller.value * _unitWidth;

            // Draw two copies of the text side-by-side for a seamless loop:
            //   copy A starts at -offset      (leaving from the left)
            //   copy B starts at _unitWidth-offset  (entering from the right)
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -offset,
                  top: 0,
                  child: _textWidget(),
                ),
                Positioned(
                  left: _unitWidth - offset,
                  top: 0,
                  child: _textWidget(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _textWidget() => Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      );
}
