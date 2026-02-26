import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const LoadingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pyramidController;
  late AnimationController _dotsController;
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  Timer? _completeTimer;

  final List<String> _messages = [
    'Exploring ancient routes...',
    'Finding hidden gems...',
    'Building your personalized Egypt journey...',
  ];

  @override
  void initState() {
    super.initState();
    
    _pyramidController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    // Cycle through messages
    _messageTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (timer) {
        if (mounted) {
          setState(() {
            _currentMessageIndex =
                (_currentMessageIndex + 1) % _messages.length;
          });
        }
      },
    );

    // Complete after 4.5 seconds
    _completeTimer = Timer(
      const Duration(milliseconds: 4500),
      () {
        if (mounted) {
          widget.onComplete();
        }
      },
    );
  }

  @override
  void dispose() {
    _pyramidController.dispose();
    _dotsController.dispose();
    _messageTimer?.cancel();
    _completeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pyramid Animation
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background pyramid
                    CustomPaint(
                      size: const Size(120, 100),
                      painter: PyramidPainter(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        progress: 1.0,
                      ),
                    ),
                    // Animated pyramid
                    AnimatedBuilder(
                      animation: _pyramidController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(120, 100),
                          painter: PyramidPainter(
                            color: AppColors.accent,
                            progress: _pyramidController.value,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // Loading Text
              SizedBox(
                height: 60,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _messages[_currentMessageIndex],
                    key: ValueKey(_currentMessageIndex),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              // Progress Dots
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _dotsController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final value = (_dotsController.value - delay) % 1.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Transform.scale(
                          scale: 1.0 + (value * 0.5),
                          child: Opacity(
                            opacity: 0.5 + (value * 0.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PyramidPainter extends CustomPainter {
  final Color color;
  final double progress;

  PyramidPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Draw pyramid with progress (bottom to top)
    final currentHeight = size.height * progress;
    final currentTop = Offset(size.width / 2, size.height - currentHeight);
    final currentLeft = Offset(
      size.width / 2 - (currentHeight / size.height * size.width / 2),
      size.height,
    );
    final currentRight = Offset(
      size.width / 2 + (currentHeight / size.height * size.width / 2),
      size.height,
    );
    
    path.moveTo(currentTop.dx, currentTop.dy);
    path.lineTo(currentLeft.dx, currentLeft.dy);
    path.lineTo(currentRight.dx, currentRight.dy);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PyramidPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
