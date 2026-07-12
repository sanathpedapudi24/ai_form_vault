import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_buttons.dart';
import 'fade_slide_in.dart';

/// Friendly empty state: soft icon medallion, serif headline, quiet body,
/// optional call to action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentWash,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: AppColors.accentDeep),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: AppTextStyles.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 24),
                PrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
