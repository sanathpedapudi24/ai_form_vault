import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';

/// Sits in `MaterialApp.router`'s `builder`, gating the routed app behind
/// three layers, in order: Firebase sign-in (mandatory), onboarding (once),
/// and the local PIN/biometric lock. Re-locks automatically when the app is
/// backgrounded.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget? child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  /// null = still reading from the DB, true/false = known.
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final done = await const SettingsRepository().getBool(
      SettingsRepository.onboardingDone,
    );
    if (mounted) setState(() => _onboardingDone = done);
  }

  Future<void> _finishOnboarding() async {
    await const SettingsRepository().setBool(
      SettingsRepository.onboardingDone,
      true,
    );
    if (mounted) setState(() => _onboardingDone = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layer 1: Firebase auth. Until a user is signed in, nothing else shows.
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.asData?.value != null;

    if (auth.isLoading) {
      return Scaffold(backgroundColor: AppColors.bg);
    }
    if (!signedIn) {
      return const AuthScreen();
    }

    // Layers 2 & 3: onboarding, then the local PIN/biometric lock.
    final phase = ref.watch(appLockProvider.select((s) => s.phase));

    return switch (phase) {
      AppLockPhase.loading => Scaffold(backgroundColor: AppColors.bg),
      AppLockPhase.needsSetup => switch (_onboardingDone) {
        null => Scaffold(backgroundColor: AppColors.bg),
        false => OnboardingScreen(onDone: _finishOnboarding),
        true => const PinSetupScreen(),
      },
      AppLockPhase.locked => const LockScreen(),
      AppLockPhase.unlocked => widget.child ?? const SizedBox.shrink(),
    };
  }
}
