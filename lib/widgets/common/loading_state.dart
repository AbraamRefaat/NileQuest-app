import 'package:flutter/material.dart';
import '../../theme.dart';

/// Centered loading spinner with an optional message.
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
