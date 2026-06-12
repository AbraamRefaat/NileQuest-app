import 'package:flutter/material.dart';
import '../../theme.dart';

/// Horizontal scrollable filter chip row.
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return GestureDetector(
            onTap: () => onSelected(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                category,
                style: AppTextStyles.chipLabel.copyWith(
                  color: isSelected ? Colors.white : AppColors.charcoal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
