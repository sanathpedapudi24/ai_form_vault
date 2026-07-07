import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/theme/app_colors.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';

/// Sits in `MaterialApp.router`'s `builder`, replacing the routed app with
/// a setup or lock screen whenever the vault isn't unlocked, and re-locking
/// automatically when the app is backgrounded.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget? child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final phase = ref.watch(appLockProvider.select((s) => s.phase));

    return switch (phase) {
      AppLockPhase.loading => const Scaffold(backgroundColor: AppColors.bg),
      AppLockPhase.needsSetup => const PinSetupScreen(),
      AppLockPhase.locked => const LockScreen(),
      AppLockPhase.unlocked => widget.child ?? const SizedBox.shrink(),
    };
  }
}
