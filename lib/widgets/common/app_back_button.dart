import 'package:flutter/material.dart';
import '../../theme.dart';

/// The circular back button used across screens, in two variants:
/// - [AppBackButton.onDark] — translucent white circle for dark/gradient headers
/// - [AppBackButton.onLight] — white circle with gold border for light backgrounds
class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool _dark;

  const AppBackButton.onDark({super.key, this.onTap}) : _dark = true;
  const AppBackButton.onLight({super.key, this.onTap}) : _dark = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        margin: _dark ? const EdgeInsets.all(AppSpacing.sm) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: _dark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
          shape: BoxShape.circle,
          border: _dark
              ? null
              : Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: _dark ? Colors.white : AppColors.charcoal,
          size: _dark ? 20 : 24,
        ),
      ),
    );
  }
}
