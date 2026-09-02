import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'pressable.dart';

/// The standard surface: an M3 tonal card using the theme's
/// `surfaceContainerLow` (a flat, elevated-in-tint surface) with a hairline
/// outline and a soft ambient shadow. Tappable when [onTap] is given (with
/// spring press feedback).
///
/// Passing an explicit [color] opts out of the default surface (used by
/// tinted banners like warnings), keeping those solid.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final bool shadow;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.radius = 20,
    this.color,
    this.shadow = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(
          border ?? BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        boxShadow: shadow ? AppColors.cardShadow : null,
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
