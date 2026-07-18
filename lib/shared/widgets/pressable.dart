import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';

/// CRED-style tactile press: the card sinks quickly under the finger, then
/// springs back with a soft overshoot on release — weight in, bounce out.
/// A light haptic fires on touch-down so the surface feels physical.
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
    this.pressedScale = 0.96,
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
      onTapDown: enabled
          ? (_) {
              if (widget.enableHaptics) HapticFeedback.lightImpact();
              _setPressed(true);
            }
          : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        // Sink fast under the finger; spring back with overshoot on release.
        duration: _pressed
            ? const Duration(milliseconds: 110)
            : const Duration(milliseconds: 360),
        curve: _pressed ? Curves.easeOut : AppMotion.spring,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.9 : 1.0,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
