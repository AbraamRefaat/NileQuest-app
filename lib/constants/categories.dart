import 'package:flutter/material.dart';
import '../theme.dart';

/// Single source of truth for POI category styling.
///
/// Replaces the duplicated `_getCategoryColor` / `_getCategoryIcon` switches
/// in the map screen, map marker widget, and itinerary screen. Color values
/// are preserved exactly from the original map implementations.
class CategoryStyle {
  final Color color;
  final IconData icon;
  final String label;

  const CategoryStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

const Map<String, CategoryStyle> _exactStyles = {
  'Historical': CategoryStyle(
    color: Color(0xFFE67E22),
    icon: Icons.account_balance_rounded,
    label: 'Historical',
  ),
  'Museum': CategoryStyle(
    color: Color(0xFF9B59B6),
    icon: Icons.museum_rounded,
    label: 'Museum',
  ),
  'Religious': CategoryStyle(
    color: Color(0xFF3498DB),
    icon: Icons.mosque_rounded,
    label: 'Religious',
  ),
  'Natural': CategoryStyle(
    color: Color(0xFF27AE60),
    icon: Icons.landscape_rounded,
    label: 'Natural',
  ),
  'Shopping': CategoryStyle(
    color: Color(0xFFF39C12),
    icon: Icons.shopping_bag_rounded,
    label: 'Shopping',
  ),
  'Beach Resort': CategoryStyle(
    color: Color(0xFF1ABC9C),
    icon: Icons.beach_access_rounded,
    label: 'Beach Resort',
  ),
  'Art & Culture': CategoryStyle(
    color: Color(0xFFE74C3C),
    icon: Icons.palette_rounded,
    label: 'Art & Culture',
  ),
  'Food & Dining': CategoryStyle(
    color: Color(0xFFF1C40F),
    icon: Icons.restaurant_rounded,
    label: 'Food & Dining',
  ),
};

const CategoryStyle _defaultStyle = CategoryStyle(
  color: AppColors.primary,
  icon: Icons.place_rounded,
  label: 'Place',
);

/// Resolves a category string (exact label or free text from the
/// recommendation API) to its style. Falls back to substring matching for
/// free-text categories like "history & heritage", then to a neutral default.
CategoryStyle categoryStyleFor(String category) {
  final exact = _exactStyles[category];
  if (exact != null) return exact;

  final cat = category.toLowerCase();
  if (cat.contains('histor') || cat.contains('heritage')) {
    return _exactStyles['Historical']!;
  }
  if (cat.contains('museum')) return _exactStyles['Museum']!;
  if (cat.contains('religi') || cat.contains('mosque') || cat.contains('church')) {
    return _exactStyles['Religious']!;
  }
  if (cat.contains('natur') || cat.contains('park') || cat.contains('garden')) {
    return _exactStyles['Natural']!;
  }
  if (cat.contains('shop') || cat.contains('bazaar') || cat.contains('market')) {
    return _exactStyles['Shopping']!;
  }
  if (cat.contains('beach') || cat.contains('resort')) {
    return _exactStyles['Beach Resort']!;
  }
  if (cat.contains('art') || cat.contains('culture') || cat.contains('entertainment')) {
    return _exactStyles['Art & Culture']!;
  }
  if (cat.contains('food') || cat.contains('dining') || cat.contains('restaurant') || cat.contains('cafe')) {
    return _exactStyles['Food & Dining']!;
  }
  return _defaultStyle;
}

/// Typical visit duration used when adding a stop manually (the
/// recommendation API normally provides durations; manual adds need a guess).
double defaultDurationHoursFor(String category) {
  final cat = category.toLowerCase();
  if (cat.contains('museum')) return 2.0;
  if (cat.contains('histor') || cat.contains('heritage')) return 2.0;
  if (cat.contains('religi') || cat.contains('mosque') || cat.contains('church')) {
    return 1.0;
  }
  if (cat.contains('food') || cat.contains('dining') || cat.contains('restaurant') || cat.contains('cafe')) {
    return 1.5;
  }
  return 1.5;
}
