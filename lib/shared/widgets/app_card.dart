import 'package:flutter/material.dart';

import 'pressable.dart';

/// The standard surface: a real M3 [Card] using the theme's `cardTheme`
/// (`surfaceContainerLow`, flat elevation, hairline outline). Tappable when
/// [onTap] is given (with spring press feedback via [Pressable]).
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

    final card = Card(
      margin: EdgeInsets.zero,
      color: color ?? scheme.surfaceContainerLow,
      elevation: shadow ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border ?? BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
