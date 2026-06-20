import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RecentDocumentTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String fileType;
  final String daysAgo;
  final IconData icon;
  final Color iconColor;
  final double? confidence;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RecentDocumentTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.fileType,
    required this.daysAgo,
    required this.icon,
    required this.iconColor,
    this.confidence,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(fileType);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          fileType.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Updated $daysAgo',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE53E3E);
      case 'JPG':
      case 'JPEG':
        return const Color(0xFF3182CE);
      case 'PNG':
        return const Color(0xFF38A169);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2B6CB0);
      default:
        return AppColors.textSecondary;
    }
  }
}
