import 'package:flutter/material.dart';

import '../../../core/models/document_model.dart';
import '../../../core/theme/app_colors.dart';

/// Icon + color for a document category, used wherever a thumbnail is
/// unavailable.
class CategoryVisual extends StatelessWidget {
  final DocumentCategory category;
  final double size;

  const CategoryVisual({super.key, required this.category, this.size = 44});

  static Color colorOf(DocumentCategory category) => switch (category) {
    DocumentCategory.identity => AppColors.categoryIdentity,
    DocumentCategory.education => AppColors.categoryEducation,
    DocumentCategory.finance => AppColors.categoryFinance,
    DocumentCategory.medical => AppColors.categoryMedical,
    DocumentCategory.travel => AppColors.categoryTravel,
    DocumentCategory.family => AppColors.categoryFamily,
    DocumentCategory.other => AppColors.categoryOther,
  };

  static IconData iconOf(DocumentCategory category) => switch (category) {
    DocumentCategory.identity => Icons.badge_outlined,
    DocumentCategory.education => Icons.school_outlined,
    DocumentCategory.finance => Icons.account_balance_outlined,
    DocumentCategory.medical => Icons.medical_information_outlined,
    DocumentCategory.travel => Icons.flight_takeoff_rounded,
    DocumentCategory.family => Icons.people_outline_rounded,
    DocumentCategory.other => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.wash(color),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(iconOf(category), color: color, size: size * 0.45),
    );
  }
}
