import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../services/app_lock_service.dart';
import '../services/image_vault.dart';
import 'document_provider.dart';
import 'person_provider.dart';

/// Where the app-lock gate currently stands.
enum AppLockPhase {
  /// Reading secure storage — show nothing but a blank screen.
  loading,

  /// No PIN has ever been set and the user hasn't opted out. Forces the
  /// setup flow (skippable once).
  needsSetup,

  /// A PIN exists but this session hasn't unlocked yet.
  locked,

  /// Either unlocked this session, or the user opted out of app lock.
  unlocked,
}

class AppLockState {
  final AppLockPhase phase;
  final bool hasPin;
  final bool biometricAvailable;
  final bool biometricEnabled;

  const AppLockState({
    this.phase = AppLockPhase.loading,
    this.hasPin = false,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
  });

  AppLockState copyWith({
    AppLockPhase? phase,
    bool? hasPin,
    bool? biometricAvailable,
    bool? biometricEnabled,
  }) => AppLockState(
    phase: phase ?? this.phase,
    hasPin: hasPin ?? this.hasPin,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier(this._ref, this._service) : super(const AppLockState()) {
    _init();
  }

  final Ref _ref;
  final AppLockService _service;

  Future<void> _init() async {
    final hasPin = await _service.isPinSet();
    final biometricAvailable = await _service.isBiometricAvailable();
    final biometricEnabled = hasPin && await _service.isBiometricEnabled();

    AppLockPhase phase;
    if (hasPin) {
      phase = AppLockPhase.locked;
    } else if (await _service.isOptedOut()) {
      phase = AppLockPhase.unlocked;
    } else {
      phase = AppLockPhase.needsSetup;
    }

    state = AppLockState(
      phase: phase,
      hasPin: hasPin,
      biometricAvailable: biometricAvailable,
      biometricEnabled: biometricEnabled,
    );
  }

  /// Completes first-time (or re-enabled) setup. Setting the PIN implicitly
  /// unlocks the current session.
  Future<void> completeSetup(String pin, {required bool enableBiometric}) async {
    await _service.setPin(pin);
    if (enableBiometric && state.biometricAvailable) {
      await _service.setBiometricEnabled(true);
    }
    state = state.copyWith(
      phase: AppLockPhase.unlocked,
      hasPin: true,
      biometricEnabled: enableBiometric && state.biometricAvailable,
    );
  }

  /// Skips setup for now — the prompt won't reappear until the user opts
  /// back in from Profile settings.
  Future<void> skipSetup() async {
    await _service.setOptedOut(true);
    state = state.copyWith(phase: AppLockPhase.unlocked);
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _service.verifyPin(pin);
    if (ok) state = state.copyWith(phase: AppLockPhase.unlocked);
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled) return false;
    final ok = await _service.authenticateWithBiometrics();
    if (ok) state = state.copyWith(phase: AppLockPhase.unlocked);
    return ok;
  }

  /// Launching the camera, document scanner, or gallery picker briefly
  /// backgrounds the app the same way switching apps does (Android reports
  /// the same `paused` lifecycle state for both) — without this, every
  /// scan attempt would immediately re-lock and lose the in-flight pick.
  /// Screens that launch one of those must call this before and
  /// [resumeAutoLock] after, in a `finally`.
  int _suppressionDepth = 0;

  void suppressAutoLock() => _suppressionDepth++;

  void resumeAutoLock() {
    if (_suppressionDepth > 0) _suppressionDepth--;
  }

  /// Called when the app is backgrounded. No-op unless a PIN is actually
  /// configured, the app is currently unlocked, and no screen has asked to
  /// suppress locking for an in-flight camera/gallery pick.
  void lock() {
    if (_suppressionDepth > 0) return;
    if (state.hasPin && state.phase == AppLockPhase.unlocked) {
      state = state.copyWith(phase: AppLockPhase.locked);
    }
  }

  Future<bool> changePin(String currentPin, String newPin) async {
    final ok = await _service.verifyPin(currentPin);
    if (!ok) return false;
    await _service.setPin(newPin);
    return true;
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _service.setBiometricEnabled(value);
    state = state.copyWith(biometricEnabled: value);
  }

  /// Turns app lock off entirely (data stays intact). Requires the current
  /// PIN so a stranger holding an unlocked phone can't disable it.
  Future<bool> disableLock(String currentPin) async {
    final ok = await _service.verifyPin(currentPin);
    if (!ok) return false;
    await _service.clearPin();
    await _service.setOptedOut(true);
    state = state.copyWith(
      phase: AppLockPhase.unlocked,
      hasPin: false,
      biometricEnabled: false,
    );
    return true;
  }

  /// Last-resort recovery when the PIN is forgotten: wipes the encrypted
  /// database and image vault (there's no cloud account to reset through),
  /// then drops back to first-run setup.
  Future<void> forgotPinFactoryReset() async {
    await AppDatabase.deleteAll();
    await ImageVault.instance.wipeAll();
    await _service.clearPin();
    await _service.setOptedOut(false);
    state = const AppLockState(phase: AppLockPhase.needsSetup, hasPin: false);
    // Downstream providers hold stale in-memory state pointing at deleted
    // rows — refresh them now that the database is empty.
    await _ref.read(documentsProvider.notifier).refresh();
    await _ref.read(identityGraphProvider.notifier).refresh();
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>(
  (ref) => AppLockNotifier(ref, ref.watch(appLockServiceProvider)),
);
