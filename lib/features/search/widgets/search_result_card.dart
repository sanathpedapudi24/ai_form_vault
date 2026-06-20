import 'package:flutter/material.dart';

import '../../../core/models/document_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class SearchResultCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;

  const SearchResultCard({super.key, required this.document, this.onTap});

  Color _categoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.identity:
        return AppColors.categoryIdentity;
      case DocumentCategory.education:
        return AppColors.categoryEducation;
      case DocumentCategory.finance:
        return AppColors.categoryFinance;
      case DocumentCategory.medical:
        return AppColors.categoryMedical;
      case DocumentCategory.travel:
        return AppColors.categoryTravel;
      case DocumentCategory.family:
        return AppColors.categoryFamily;
      case DocumentCategory.other:
        return AppColors.categoryOther;
    }
  }

  IconData _categoryIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.identity:
        return Icons.badge_rounded;
      case DocumentCategory.education:
        return Icons.school_rounded;
      case DocumentCategory.finance:
        return Icons.account_balance_rounded;
      case DocumentCategory.medical:
        return Icons.local_hospital_rounded;
      case DocumentCategory.travel:
        return Icons.flight_rounded;
      case DocumentCategory.family:
        return Icons.people_rounded;
      case DocumentCategory.other:
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(document.category);
    final icon = _categoryIcon(document.category);

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        document.type,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${document.ownerName} • ${document.dateFormatted}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
