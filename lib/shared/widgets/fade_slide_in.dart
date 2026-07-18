import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

/// CRED-style entrance: the child rises from below while fading in and
/// scaling up from 96%, so cards feel like they surface with weight.
/// Give list items an increasing [index] for a staggered cascade.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? delay;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.offset = 26,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(curved);

    final delay = widget.delay ?? AppMotion.stagger * widget.index;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
