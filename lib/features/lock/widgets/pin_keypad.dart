import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';

/// Four dots showing how many PIN digits have been entered. Shakes and
/// tints red on [error].
class PinDots extends StatefulWidget {
  final int length;
  final int filled;
  final bool error;

  const PinDots({
    super.key,
    this.length = 4,
    required this.filled,
    this.error = false,
  });

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;
        final offset = t == 0 ? 0.0 : (16 * (1 - t)) * ((t * 24).floor().isEven ? 1 : -1);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final isFilled = i < widget.filled;
          return AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.error
                  ? AppColors.error
                  : (isFilled ? AppColors.accent : Colors.transparent),
              border: Border.all(
                color: widget.error
                    ? AppColors.error
                    : (isFilled ? AppColors.accent : AppColors.borderStrong),
                width: 1.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A 3x4 numeric keypad (1-9, an optional left accessory, 0, backspace).
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Rendered in the bottom-left slot — typically a biometric icon.
  final Widget? leftAccessory;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leftAccessory,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in row) _Key(label: d, onTap: () => onDigit(d))],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Key(onTap: null, child: leftAccessory),
              _Key(label: '0', onTap: () => onDigit('0')),
              _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;

  const _Key({this.label, this.icon, this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        (label != null
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              )
            : icon != null
            ? Icon(icon, color: AppColors.textPrimary, size: 22)
            : const SizedBox.shrink());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: 68,
            height: 68,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
