import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';

/// Wraps any child with iOS-style press feedback: a quick scale-down and
/// slight fade while the finger is down, springing back on release.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the widget shrinks while pressed (1.0 = no shrink).
  final double pressedScale;
  final bool enableHaptics;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enableHaptics = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.enableHaptics) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
