import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Shows how confident the AI is about a value — honestly.
/// High = green, Medium = ochre, Low = clay red.
class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  final bool compact;

  const ConfidenceBadge({
    super.key,
    required this.confidence,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, wash) = switch (confidence) {
      >= AppConfig.confidenceHigh => (
        'High',
        AppColors.success,
        AppColors.successWash,
      ),
      >= AppConfig.confidenceMedium => (
        'Medium',
        AppColors.warning,
        AppColors.warningWash,
      ),
      _ => ('Low', AppColors.error, AppColors.errorWash),
    };

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted tag ("Aadhaar", "Verified", category names).
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.wash(c),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
