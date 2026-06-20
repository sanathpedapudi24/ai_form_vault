import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class ProfileSectionTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isComplete;
  final VoidCallback? onTap;
  final Color? color;

  const ProfileSectionTile({
    super.key,
    required this.name,
    required this.icon,
    required this.isComplete,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.accent;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tileColor.withValues(alpha: 0.2),
                  tileColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tileColor.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, size: 22, color: tileColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isComplete ? 'Completed' : 'Incomplete',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isComplete ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isComplete ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isComplete ? Icons.check_circle_rounded : Icons.warning_rounded,
              size: 18,
              color: isComplete ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
