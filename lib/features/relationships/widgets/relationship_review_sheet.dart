import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/models/relationship_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RelationshipReviewSheet extends StatelessWidget {
  final String personName;
  final void Function(RelationshipType type) onConfirm;

  const RelationshipReviewSheet({
    super.key,
    required this.personName,
    required this.onConfirm,
  });

  static Future<RelationshipType?> show(
    BuildContext context, {
    required String personName,
  }) {
    return showModalBottomSheet<RelationshipType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RelationshipReviewSheet(
        personName: personName,
        onConfirm: (type) => Navigator.of(ctx).pop(type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      RelationshipType.sister,
      RelationshipType.mother,
      RelationshipType.spouse,
      RelationshipType.friend,
      RelationshipType.other,
    ];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    personName.isNotEmpty ? personName[0].toUpperCase() : '?',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Gap(16),
                Text(
                  'We found $personName',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(4),
                Text(
                  'Who is this person?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap(24),
                ...types.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => onConfirm(type),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: type == RelationshipType.other
                              ? AppColors.bgTertiary
                              : AppColors.accent.withValues(alpha: 0.1),
                          foregroundColor: type == RelationshipType.other
                              ? AppColors.textPrimary
                              : AppColors.accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          type.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
