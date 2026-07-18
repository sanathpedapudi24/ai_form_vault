import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'pressable.dart';

/// The standard surface, styled after CRED's cards: a softly lit obsidian
/// slab — a top-to-bottom gradient over a light-catching hairline edge and a
/// deep, diffuse shadow — with generous rounding. Tappable when [onTap] is
/// given (with spring press feedback).
///
/// Passing an explicit [color] opts out of the gradient (used by tinted
/// banners like warnings), keeping those solid.
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
    // Resolve dark/light from the inherited Theme (not the AppColors global
    // flag): reading it here subscribes this card to theme changes, so the
    // CRED gradient re-resolves the instant dark mode is toggled — without a
    // full-tree rebuild. AppColors' own getters still read the global flag,
    // which the theme keeps in sync, so both agree.
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Only the default (untinted) card gets the CRED gradient; an explicit
    // color means the caller wants a specific solid fill.
    final useGradient = color == null;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useGradient ? null : color,
        gradient: useGradient ? AppColors.cardGradientFor(dark) : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(
          border ?? BorderSide(color: AppColors.cardBorderFor(dark)),
        ),
        boxShadow: shadow ? AppColors.cardShadowFor(dark) : null,
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
