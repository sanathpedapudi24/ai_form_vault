import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'widgets/pin_keypad.dart';

enum _Step { enter, confirm, biometricOffer }

/// Creates (or re-creates) the app's 4-digit PIN. Used two ways:
///  - by [AppLockGate] on first run (rendered directly, no route) — shows a
///    "Skip for now" option and simply lets the lock state change reveal
///    the app once done.
///  - pushed from Profile settings to re-enable lock — no skip option, and
///    [onComplete] pops the route.
class PinSetupScreen extends ConsumerStatefulWidget {
  final bool allowSkip;
  final VoidCallback? onComplete;

  const PinSetupScreen({super.key, this.allowSkip = true, this.onComplete});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _Step _step = _Step.enter;
  String _firstPin = '';
  String _entry = '';
  bool _error = false;

  void _onDigit(String digit) {
    if (_entry.length >= 4) return;
    setState(() {
      _error = false;
      _entry += digit;
    });
    if (_entry.length == 4) _onComplete();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _onComplete() async {
    if (_step == _Step.enter) {
      final pin = _entry;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _firstPin = pin;
        _entry = '';
        _step = _Step.confirm;
      });
      return;
    }

    // Confirm step.
    if (_entry != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _entry = '';
        _firstPin = '';
        _error = false;
        _step = _Step.enter;
      });
      return;
    }

    final biometricAvailable = ref.read(appLockProvider).biometricAvailable;
    if (biometricAvailable) {
      setState(() => _step = _Step.biometricOffer);
    } else {
      await _finish(enableBiometric: false);
    }
  }

  Future<void> _finish({required bool enableBiometric}) async {
    await ref
        .read(appLockProvider.notifier)
        .completeSetup(_firstPin, enableBiometric: enableBiometric);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.biometricOffer) {
      return _BiometricOfferView(
        onEnable: () => _finish(enableBiometric: true),
        onSkip: () => _finish(enableBiometric: false),
      );
    }

    final title = _step == _Step.enter ? 'Create a PIN' : 'Confirm your PIN';
    final subtitle = _step == _Step.enter
        ? 'You\'ll use this to unlock your vault.'
        : 'Enter it once more to confirm.';

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                    decoration: const BoxDecoration(
                      color: AppColors.accentWash,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accentDeep,
                      size: 26,
                    ),
                  ),
                  const Gap(20),
                  Text(title, style: AppTextStyles.title),
                  const Gap(6),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                  const Gap(28),
                  PinDots(filled: _entry.length, error: _error),
                ],
              ),
            ),
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const Gap(12),
            if (widget.allowSkip)
              TextButton(
                onPressed: () =>
                    ref.read(appLockProvider.notifier).skipSetup(),
                child: Text(
                  'Skip for now',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              const Gap(20),
            const Gap(12),
          ],
        ),
      ),
    );
  }
}

class _BiometricOfferView extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const _BiometricOfferView({required this.onEnable, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideIn(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.accentWash,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.accentDeep,
                        size: 30,
                      ),
                    ),
                    const Gap(20),
                    Text(
                      'Use biometric unlock too?',
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    Text(
                      'Unlock faster with your fingerprint or face. Your PIN '
                      'still works any time.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Gap(32),
              PrimaryButton(
                label: 'Enable biometric unlock',
                icon: Icons.fingerprint_rounded,
                onPressed: onEnable,
              ),
              const Gap(10),
              SecondaryButton(label: 'Not now', onPressed: onSkip),
            ],
          ),
        ),
      ),
    );
  }
}
