import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;

  late AnimationController _iconController;
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Welcome to\nNile Quest',
      subtitle: 'Your Gateway to Egypt\'s Wonders',
      description:
          'Discover 7,000 years of history, breathtaking landscapes, and unforgettable experiences — all in one app.',
      icon: Icons.account_balance_rounded,
      accentColor: AppColors.secondary,
      gradientColors: [Color(0xFF1F4E5F), Color(0xFF163949)],
    ),
    _OnboardingPageData(
      title: 'AI-Powered\nRecommendations',
      subtitle: 'Smart Trips Tailored Just for You',
      description:
          'Our AI analyzes your interests, budget, and travel pace to craft the perfect personalized Egyptian itinerary.',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFFE67E22),
      gradientColors: [Color(0xFF1F4E5F), Color(0xFF24384A)],
    ),
    _OnboardingPageData(
      title: 'Explore the\nInteractive Map',
      subtitle: 'Navigate Egypt\'s Landmarks',
      description:
          'Find every pyramid, temple, and hidden gem around you with a live interactive map powered by Mapbox.',
      icon: Icons.map_rounded,
      accentColor: AppColors.secondary,
      gradientColors: [Color(0xFF1F4E5F), Color(0xFF1A3D4F)],
    ),
    _OnboardingPageData(
      title: 'Ready to\nExplore Egypt?',
      subtitle: 'Your Adventure Awaits',
      description:
          'Sign in to unlock AI recommendations and save your trips, or jump in as a guest to start exploring right away.',
      icon: Icons.explore_rounded,
      accentColor: Color(0xFFE67E22),
      gradientColors: [Color(0xFF1F4E5F), Color(0xFF163949)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _orb1Controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _orb2Controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );
    _iconFade = CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _orb1Anim = CurvedAnimation(parent: _orb1Controller, curve: Curves.easeInOut);
    _orb2Anim = CurvedAnimation(parent: _orb2Controller, curve: Curves.easeInOut);

    _iconController.forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconController.reset();
    _iconController.forward();
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skip() {
    _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    await _onboardingService.markOnboardingSeen();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Animated background orbs
          _buildAnimatedOrbs(page),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button row
                _buildTopBar(isLastPage),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index]);
                    },
                  ),
                ),

                // Bottom indicator + button
                _buildBottomSection(isLastPage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedOrbs(_OnboardingPageData page) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orb1Anim, _orb2Anim]),
      builder: (context, _) {
        return Stack(
          children: [
            // Top-right orb
            Positioned(
              top: -40 + (_orb1Anim.value * 30),
              right: -60 + (_orb1Anim.value * 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.accentColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Bottom-left orb
            Positioned(
              bottom: -60 + (_orb2Anim.value * 25),
              left: -40 + (_orb2Anim.value * 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Small accent orb center-right
            Positioned(
              top: 160 + (_orb1Anim.value * 20),
              right: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.accentColor.withValues(alpha: 0.12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo / App name
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Nile Quest',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!isLastPage)
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container
          ScaleTransition(
            scale: _iconScale,
            child: FadeTransition(
              opacity: _iconFade,
              child: _buildIconContainer(page),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          FadeTransition(
            opacity: _iconFade,
            child: Text(
              page.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle badge
          FadeTransition(
            opacity: _iconFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: page.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: page.accentColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                page.subtitle,
                style: GoogleFonts.inter(
                  color: page.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Description
          FadeTransition(
            opacity: _iconFade,
            child: Text(
              page.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.65,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(_OnboardingPageData page) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            page.accentColor.withValues(alpha: 0.25),
            page.accentColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: page.accentColor.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: page.accentColor.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner ring
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: page.accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          Icon(
            page.icon,
            size: 54,
            color: page.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        children: [
          // Dot indicator
          _buildDotIndicator(),

          const SizedBox(height: 32),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _goToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.primary,
                elevation: 12,
                shadowColor: AppColors.secondary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  key: ValueKey(isLastPage),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastPage ? 'Get Started' : 'Next',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastPage
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isLastPage) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _skip,
              child: Text(
                'Continue as Guest',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.secondary
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.5),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
