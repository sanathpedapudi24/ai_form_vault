import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'widgets/pin_keypad.dart';

/// Confirms the current PIN before turning app lock off entirely.
class DisableLockScreen extends ConsumerStatefulWidget {
  const DisableLockScreen({super.key});

  @override
  ConsumerState<DisableLockScreen> createState() => _DisableLockScreenState();
}

class _DisableLockScreenState extends ConsumerState<DisableLockScreen> {
  String _entry = '';
  bool _error = false;

  void _onDigit(String digit) {
    if (_entry.length >= 4) return;
    setState(() {
      _error = false;
      _entry += digit;
    });
    if (_entry.length == 4) _submit();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    final ok = await ref.read(appLockProvider.notifier).disableLock(_entry);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() { _entry = ''; _error = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turn off app lock')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            FadeSlideIn(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.errorWash,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_open_outlined,
                      color: AppColors.error,
                      size: 26,
                    ),
                  ),
                  const Gap(20),
                  Text('Enter your PIN to confirm', style: AppTextStyles.title, textAlign: TextAlign.center),
                  const Gap(6),
                  Text(
                    'Your documents stay put — only the lock screen goes away.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
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
