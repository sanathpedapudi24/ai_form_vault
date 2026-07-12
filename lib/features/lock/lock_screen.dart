import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'widgets/pin_keypad.dart';

/// Shown whenever the app is locked: on cold start (if a PIN is set) and
/// after returning from the background.
///
/// This screen fully replaces the routed app content while locked, so it
/// has no Navigator ancestor to show dialogs through — the "forgot PIN"
/// confirmation is built as inline state instead of showDialog().
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entry = '';
  bool _error = false;
  bool _checkingBiometric = false;
  bool _triedBiometricOnOpen = false;
  bool _confirmingReset = false;
  bool _resetting = false;
  Duration _lockout = Duration.zero;
  Timer? _lockoutTicker;

  bool get _lockedOut => _lockout > Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_triedBiometricOnOpen) {
      _triedBiometricOnOpen = true;
      _refreshLockout();
      final enabled = ref.read(appLockProvider).biometricEnabled;
      if (enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
      }
    }
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final remaining =
        await ref.read(appLockServiceProvider).lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockout = remaining);
    _lockoutTicker?.cancel();
    if (remaining > Duration.zero) {
      _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _lockout -= const Duration(seconds: 1);
          if (_lockout <= Duration.zero) {
            _lockout = Duration.zero;
            _lockoutTicker?.cancel();
          }
        });
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);
    await ref.read(appLockProvider.notifier).unlockWithBiometric();
    if (mounted) setState(() => _checkingBiometric = false);
  }

  void _onDigit(String digit) {
    if (_lockedOut || _entry.length >= 4) return;
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
    final ok = await ref.read(appLockProvider.notifier).unlockWithPin(_entry);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await _refreshLockout();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _entry = '';
          _error = false;
        });
      }
    }
  }

  Future<void> _confirmReset() async {
    setState(() => _resetting = true);
    await ref.read(appLockProvider.notifier).forgotPinFactoryReset();
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmingReset) {
      return _ForgotPinConfirm(
        resetting: _resetting,
        onCancel: () => setState(() => _confirmingReset = false),
        onConfirm: _confirmReset,
      );
    }

    final biometricEnabled = ref.watch(
      appLockProvider.select((s) => s.biometricEnabled),
    );

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
                    decoration: BoxDecoration(
                      color: AppColors.accentWash,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accentDeep,
                      size: 26,
                    ),
                  ),
                  const Gap(20),
                  Text('Enter your PIN', style: AppTextStyles.title),
                  if (_lockedOut) ...[
                    const Gap(8),
                    Text(
                      'Too many attempts — try again in ${_lockout.inSeconds}s',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Gap(28),
                  PinDots(filled: _entry.length, error: _error),
                ],
              ),
            ),
            const Spacer(),
            NumericKeypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              leftAccessory: biometricEnabled
                  ? IconButton(
                      onPressed: _checkingBiometric ? null : _tryBiometric,
                      icon: Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                    )
                  : null,
            ),
            const Gap(12),
            TextButton(
              onPressed: () => setState(() => _confirmingReset = true),
              child: Text(
                'Forgot PIN?',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const Gap(12),
          ],
        ),
      ),
    );
  }
}

class _ForgotPinConfirm extends StatelessWidget {
  final bool resetting;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ForgotPinConfirm({
    required this.resetting,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideIn(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.errorWash,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 30,
                      ),
                    ),
                    const Gap(20),
                    Text(
                      'There\'s no account to recover this through',
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(10),
                    Text(
                      'Resetting deletes every document, fact, and '
                      'relationship in your vault permanently, then lets you '
                      'set up a new PIN. This can\'t be undone.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Gap(32),
              AnimatedSwitcher(
                duration: AppMotion.base,
                child: resetting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: CircularProgressIndicator(),
                      )
                    : Column(
                        key: const ValueKey('actions'),
                        children: [
                          PrimaryButton(
                            label: 'Delete everything and reset',
                            icon: Icons.delete_forever_rounded,
                            danger: true,
                            onPressed: onConfirm,
                          ),
                          const Gap(10),
                          SecondaryButton(label: 'Cancel', onPressed: onCancel),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
