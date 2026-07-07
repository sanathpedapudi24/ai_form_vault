import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/document_model.dart';

/// Bridge to the native Android AutofillService.
///
/// Flutter pushes the vault owner's facts (as key → value JSON) into
/// Android's EncryptedSharedPreferences via a MethodChannel; the native
/// `VaultAutofillService` reads them when other apps request autofill.
/// No-ops safely on iOS and when the platform side is unavailable.
class AutofillBridge {
  AutofillBridge._();

  static const _channel = MethodChannel('com.aiformvault/autofill');

  /// Pushes facts to the native side. Only whitelisted keys are shared —
  /// system autofill never sees full Aadhaar numbers.
  static Future<bool> setAutofillData(Map<String, String> facts) async {
    final safe = <String, String>{};
    for (final entry in facts.entries) {
      if (_sharedKeys.contains(entry.key)) safe[entry.key] = entry.value;
    }
    try {
      await _channel.invokeMethod('setAutofillData', jsonEncode(safe));
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> clearAutofillData() async {
    try {
      await _channel.invokeMethod('clearAutofillData');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Whether this app is currently the selected system autofill service.
  static Future<bool> isServiceEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutofillServiceEnabled') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens Android's "choose autofill service" settings for this app.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAutofillSettings');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Facts safe to expose to system-wide autofill. Deliberately excludes
  /// Aadhaar/passport/voter/license numbers.
  static const _sharedKeys = {
    FactKeys.fullName,
    FactKeys.dob,
    FactKeys.gender,
    FactKeys.fatherName,
    FactKeys.motherName,
    FactKeys.phone,
    FactKeys.email,
    FactKeys.address,
    FactKeys.pinCode,
    FactKeys.panNumber,
    FactKeys.bloodGroup,
    FactKeys.nationality,
  };
}
