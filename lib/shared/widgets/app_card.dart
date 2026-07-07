import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'pressable.dart';

/// The standard surface: white card on ivory, hairline border, soft shadow.
/// Tappable when [onTap] is provided (with press feedback).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color color;
  final bool shadow;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.radius = 18,
    this.color = AppColors.surface,
    this.shadow = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(
          border ?? const BorderSide(color: AppColors.border),
        ),
        boxShadow: shadow ? AppColors.cardShadow : null,
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
