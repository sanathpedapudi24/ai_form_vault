import 'package:flutter/material.dart';

import '../../../core/models/relationship_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RelationshipNodeWidget extends StatelessWidget {
  final PersonNode person;
  final double radius;
  final bool isHighlighted;

  const RelationshipNodeWidget({
    super.key,
    required this.person,
    this.radius = 32,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final double avatarRadius = radius;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isHighlighted ? AppColors.accent : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            padding: isHighlighted ? const EdgeInsets.all(3) : null,
            child: Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isHighlighted
                    ? AppColors.accentGradient
                    : LinearGradient(
                        colors: [AppColors.bgTertiary, AppColors.cardBg],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Center(
                child: Text(
                  person.initial,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: isHighlighted
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: isHighlighted ? 20 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            person.name,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            person.isUser ? 'You' : (person.relationship?.label ?? ''),
            style: AppTextStyles.labelSmall.copyWith(
              color: isHighlighted ? AppColors.accent : AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
