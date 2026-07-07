import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import 'pressable.dart';

/// Section marker: small-caps overline title with optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: AppTextStyles.overline),
          if (actionLabel != null)
            Pressable(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTextStyles.buttonSmall.copyWith(
                  color: const Color(0xFFA54E2C),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
