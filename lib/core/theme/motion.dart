import 'package:flutter/animation.dart';

/// Motion tokens — one vocabulary of durations and curves so the whole app
/// moves the same way. Apple-like: quick to respond, soft to settle.
class AppMotion {
  AppMotion._();

  /// Press feedback, hover, small toggles.
  static const Duration fast = Duration(milliseconds: 140);

  /// Most transitions: cards, sheets, selections.
  static const Duration base = Duration(milliseconds: 260);

  /// Entrances, page-level movement.
  static const Duration slow = Duration(milliseconds: 420);

  /// The workhorse curve — fast start, long soft landing (iOS-like).
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  /// For elements entering the screen.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// For elements leaving — accelerate away.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Gentle overshoot for playful moments (checkmarks, success states).
  static const Curve spring = Cubic(0.34, 1.4, 0.64, 1);

  /// Stagger interval between list items animating in. Long enough that the
  /// cascade reads as deliberate (CRED-style), short enough not to drag.
  static const Duration stagger = Duration(milliseconds: 60);
}
