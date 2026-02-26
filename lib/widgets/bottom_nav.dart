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

  const BottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.primary : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
