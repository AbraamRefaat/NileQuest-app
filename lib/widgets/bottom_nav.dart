import 'package:flutter/material.dart';
import '../theme.dart';

enum BottomNavTab {
  home,
  itinerary,
  map,
  profile,
}

class BottomNav extends StatelessWidget {
  final BottomNavTab activeTab;
  final Function(BottomNavTab) onTabChange;
  final VoidCallback onCameraPressed;

  const BottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.onCameraPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80 + MediaQuery.of(context).padding.bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Bar background ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),
          ),

          // ── Nav items (2 left + 2 right, gap in the middle) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom,
            child: Row(
              children: [
                // Left two
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isActive: activeTab == BottomNavTab.home,
                        onTap: () => onTabChange(BottomNavTab.home),
                      ),
                      _NavItem(
                        icon: Icons.route_rounded,
                        label: 'Trip',
                        isActive: activeTab == BottomNavTab.itinerary,
                        onTap: () => onTabChange(BottomNavTab.itinerary),
                      ),
                    ],
                  ),
                ),

                // Gap for the floating button
                const SizedBox(width: 80),

                // Right two
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        isActive: activeTab == BottomNavTab.map,
                        onTap: () => onTabChange(BottomNavTab.map),
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        isActive: activeTab == BottomNavTab.profile,
                        onTap: () => onTabChange(BottomNavTab.profile),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Outstanding center camera button ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 18,
            left: 0,
            right: 0,
            child: Center(
              child: _CameraButton(onPressed: onCameraPressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CameraButton({required this.onPressed});

  @override
  State<_CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<_CameraButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.50),
                  blurRadius: 24,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_enhance_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : Colors.grey[400],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.primary : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
