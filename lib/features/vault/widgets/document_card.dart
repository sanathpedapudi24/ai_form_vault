import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onLongPress,
  });

  static Color categoryColor(DocumentCategory category) {
    return switch (category) {
      DocumentCategory.identity => AppColors.accent,
      DocumentCategory.education => AppColors.categoryEducation,
      DocumentCategory.finance => AppColors.categoryFinance,
      DocumentCategory.medical => AppColors.categoryMedical,
      DocumentCategory.travel => AppColors.categoryTravel,
      DocumentCategory.family => AppColors.categoryFamily,
      DocumentCategory.other => AppColors.categoryOther,
    };
  }

  static IconData categoryIcon(DocumentCategory category) {
    return switch (category) {
      DocumentCategory.identity => Icons.badge_rounded,
      DocumentCategory.education => Icons.school_rounded,
      DocumentCategory.finance => Icons.account_balance_rounded,
      DocumentCategory.medical => Icons.medical_services_rounded,
      DocumentCategory.travel => Icons.flight_rounded,
      DocumentCategory.family => Icons.family_restroom_rounded,
      DocumentCategory.other => Icons.folder_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(document.category);
    final icon = categoryIcon(document.category);
    final confidenceLabel = document.confidenceLabel;
    final confidenceColor = document.confidence >= 0.9
        ? AppColors.success
        : document.confidence >= 0.7
        ? AppColors.warning
        : AppColors.error;

    return GlassCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        document.type,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: confidenceColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      confidenceLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: confidenceColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  document.name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${document.ownerName} • ${document.dateFormatted}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
