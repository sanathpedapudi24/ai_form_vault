import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'widgets/pin_keypad.dart';

enum _Step { current, next, confirm }

/// Verifies the existing PIN, then creates and confirms a new one.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.current;
  String _currentPin = '';
  String _nextPin = '';
  String _entry = '';
  bool _error = false;
  String? _errorMessage;

  (String, String) get _copy => switch (_step) {
    _Step.current => ('Enter your current PIN', ''),
    _Step.next => ('Create a new PIN', ''),
    _Step.confirm => ('Confirm your new PIN', 'Enter it once more to confirm.'),
  };

  void _onDigit(String digit) {
    if (_entry.length >= 4) return;
    setState(() {
      _error = false;
      _entry += digit;
    });
    if (_entry.length == 4) _advance();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _shakeAndReset({String? message, _Step? resetTo}) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = true;
      _errorMessage = message;
    });
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _entry = '';
      _error = false;
      if (resetTo != null) _step = resetTo;
    });
  }

  Future<void> _advance() async {
    switch (_step) {
      case _Step.current:
        // Verification happens once, at the confirm step, via changePin —
        // capturing it here just avoids asking twice.
        _currentPin = _entry;
        setState(() {
          _entry = '';
          _step = _Step.next;
        });
      case _Step.next:
        _nextPin = _entry;
        setState(() {
          _entry = '';
          _step = _Step.confirm;
        });
      case _Step.confirm:
        if (_entry != _nextPin) {
          await _shakeAndReset(
            message: 'PINs didn\'t match — try again.',
            resetTo: _Step.next,
          );
          return;
        }
        final changed = await ref
            .read(appLockProvider.notifier)
            .changePin(_currentPin, _nextPin);
        if (!mounted) return;
        if (changed) {
          Navigator.of(context).pop();
        } else {
          await _shakeAndReset(
            message: 'Current PIN was incorrect.',
            resetTo: _Step.current,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _copy;
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            FadeSlideIn(
              child: Column(
                children: [
                  Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
                  if (subtitle.isNotEmpty) ...[
                    const Gap(6),
                    Text(subtitle, style: AppTextStyles.bodySecondary),
                  ],
                  if (_errorMessage != null && _error) ...[
                    const Gap(8),
                    Text(
                      _errorMessage!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ],
                  const Gap(28),
                  PinDots(filled: _entry.length, error: _error),
                ],
              ),
            ),
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}
