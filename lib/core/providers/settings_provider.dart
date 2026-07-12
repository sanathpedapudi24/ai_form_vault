import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';
import '../services/autofill_bridge.dart';
import '../services/notification_service.dart';
import 'app_lock_provider.dart';
import 'document_provider.dart';
import 'person_provider.dart';
import 'service_providers.dart';

class SettingsState {
  final bool autofillEnabled;

  /// Whether the app is actually selected as the system autofill service.
  final bool autofillServiceActive;
  final bool aiEnabled;
  final bool remindersEnabled;
  final bool darkMode;

  const SettingsState({
    this.autofillEnabled = false,
    this.autofillServiceActive = false,
    this.aiEnabled = false,
    this.remindersEnabled = true,
    this.darkMode = false,
  });

  SettingsState copyWith({
    bool? autofillEnabled,
    bool? autofillServiceActive,
    bool? aiEnabled,
    bool? remindersEnabled,
    bool? darkMode,
  }) => SettingsState(
    autofillEnabled: autofillEnabled ?? this.autofillEnabled,
    autofillServiceActive: autofillServiceActive ?? this.autofillServiceActive,
    aiEnabled: aiEnabled ?? this.aiEnabled,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    darkMode: darkMode ?? this.darkMode,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._ref) : super(const SettingsState()) {
    _load();
  }

  final Ref _ref;

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);

  Future<void> _load() async {
    final autofill = await _repo.getBool(
      SettingsRepository.systemAutofillEnabled,
    );
    final reminders = await _repo.getBool(
      SettingsRepository.expiryRemindersEnabled,
      defaultValue: true,
    );
    final dark = await _repo.getBool(SettingsRepository.darkModeEnabled);
    final active = await AutofillBridge.isServiceEnabled();
    state = SettingsState(
      autofillEnabled: autofill,
      autofillServiceActive: active,
      aiEnabled: AppConfig.aiEnabled,
      remindersEnabled: reminders,
      darkMode: dark,
    );
    if (autofill) await syncAutofillData();
  }

  /// Turns sharing vault facts with system autofill on/off.
  Future<void> setAutofillEnabled(bool enabled) async {
    await _repo.setBool(SettingsRepository.systemAutofillEnabled, enabled);
    state = state.copyWith(autofillEnabled: enabled);
    if (enabled) {
      await syncAutofillData();
      final active = await AutofillBridge.isServiceEnabled();
      state = state.copyWith(autofillServiceActive: active);
      if (!active) {
        // Opens Android's own settings screen — same re-lock hazard as any
        // other Activity switch (camera, gallery, share sheet).
        _ref.read(appLockProvider.notifier).suppressAutoLock();
        try {
          await AutofillBridge.openSettings();
        } finally {
          _ref.read(appLockProvider.notifier).resumeAutoLock();
        }
      }
    } else {
      await AutofillBridge.clearAutofillData();
    }
  }

  /// Turns expiry reminders on/off — off cancels everything scheduled, on
  /// re-registers reminders for every stored document.
  Future<void> setRemindersEnabled(bool enabled) async {
    await _repo.setBool(SettingsRepository.expiryRemindersEnabled, enabled);
    state = state.copyWith(remindersEnabled: enabled);
    if (enabled) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.rescheduleAll(
        _ref.read(documentsProvider),
      );
    } else {
      await NotificationService.instance.cancelAll();
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    await _repo.setBool(SettingsRepository.darkModeEnabled, enabled);
    state = state.copyWith(darkMode: enabled);
  }

  /// Re-checks whether we're the selected service (call on app resume).
  Future<void> refreshServiceStatus() async {
    final active = await AutofillBridge.isServiceEnabled();
    state = state.copyWith(autofillServiceActive: active);
  }

  /// Pushes the user's current facts to the native side.
  Future<void> syncAutofillData() async {
    if (!state.autofillEnabled) return;
    final facts = await _ref.read(userFactsProvider.future);
    if (facts.isNotEmpty) await AutofillBridge.setAutofillData(facts);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref),
);
