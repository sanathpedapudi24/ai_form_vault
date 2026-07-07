import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// PIN + biometric gate for the app itself (separate from the vault's
/// data-at-rest encryption). The PIN is never stored in plaintext — only a
/// salted SHA-256 hash, in the platform Keystore/Keychain via
/// flutter_secure_storage.
class AppLockService {
  AppLockService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  static const _storage = FlutterSecureStorage();
  static const _kPinHash = 'app_lock_pin_hash';
  static const _kPinSalt = 'app_lock_pin_salt';
  static const _kBiometricEnabled = 'app_lock_biometric_enabled';
  static const _kOptedOut = 'app_lock_opted_out';

  final LocalAuthentication _localAuth;

  Future<bool> isPinSet() async =>
      (await _storage.read(key: _kPinHash)) != null;

  Future<bool> isOptedOut() async =>
      (await _storage.read(key: _kOptedOut)) == 'true';

  Future<void> setOptedOut(bool value) =>
      _storage.write(key: _kOptedOut, value: value.toString());

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = await _hash(pin, salt);
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: hash);
    await _storage.write(key: _kOptedOut, value: 'false');
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt);
    final storedHash = await _storage.read(key: _kPinHash);
    if (salt == null || storedHash == null) return false;
    final hash = await _hash(pin, salt);
    return _constantTimeEquals(hash, storedHash);
  }

  /// Removes the PIN and biometric flag. Does not touch document data —
  /// callers decide separately whether to also wipe the vault.
  Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
    await _storage.delete(key: _kBiometricEnabled);
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _kBiometricEnabled)) == 'true';

  Future<void> setBiometricEnabled(bool value) =>
      _storage.write(key: _kBiometricEnabled, value: value.toString());

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock AI Form & Vault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<String> _hash(String pin, String saltB64) async {
    final salt = base64Decode(saltB64);
    final bytes = [...utf8.encode(pin), ...salt];
    final digest = await Sha256().hash(bytes);
    return base64Encode(digest.bytes);
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Avoids leaking hash-comparison timing (defense in depth for a 4-digit
  /// PIN, where brute force isn't the real threat model but cheap to add).
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
