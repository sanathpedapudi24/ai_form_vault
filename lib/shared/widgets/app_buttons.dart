import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import 'pressable.dart';

/// Filled terracotta call-to-action. Shows a spinner when [loading].
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  /// Uses the error color instead of accent — for irreversible actions.
  final bool danger;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.ease,
        width: expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: enabled
              ? (danger ? AppColors.error : AppColors.accent)
              : AppColors.bgDeep,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.textOnAccent),
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(
                  color: enabled
                      ? AppColors.textOnAccent
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet outlined button for secondary actions.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.98,
      child: Container(
        width: expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill button for inline actions (e.g. "Confirm", "Edit").
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.textOnAccent : AppColors.textPrimary;
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : AppColors.bgSunken,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppTextStyles.buttonSmall.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
