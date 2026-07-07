import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Encrypted at-rest store for document images.
///
/// Files are encrypted with AES-256-GCM before touching disk; the key is
/// generated once and kept in the platform Keystore/Keychain. Decrypted
/// bytes only ever live in memory (a small LRU cache avoids re-decrypting
/// while scrolling).
class ImageVault {
  ImageVault._();

  static final ImageVault instance = ImageVault._();

  static const _keyStorageKey = 'vault_image_key';
  static const _secureStorage = FlutterSecureStorage();
  static const _dirName = 'vault_images';

  final _cipher = AesGcm.with256bits();
  SecretKey? _key;
  Directory? _dir;

  // Tiny LRU cache of decrypted images (name → bytes).
  static const _cacheLimit = 24;
  final _cache = <String, Uint8List>{};

  Future<SecretKey> _getKey() async {
    if (_key != null) return _key!;
    var stored = await _secureStorage.read(key: _keyStorageKey);
    if (stored == null || stored.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      stored = base64Encode(bytes);
      await _secureStorage.write(key: _keyStorageKey, value: stored);
    }
    _key = SecretKey(base64Decode(stored));
    return _key!;
  }

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(docs.path, _dirName));
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return _dir!;
  }

  /// Encrypts [bytes] and stores them; returns the vault filename.
  Future<String> save(Uint8List bytes) async {
    final key = await _getKey();
    final dir = await _getDir();
    final name = '${const Uuid().v4()}.enc';

    final secretBox = await _cipher.encrypt(bytes, secretKey: key);
    // File layout: [12-byte nonce][ciphertext][16-byte MAC].
    final out = BytesBuilder()
      ..add(secretBox.nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    await File(p.join(dir.path, name)).writeAsBytes(out.toBytes(), flush: true);

    _cachePut(name, bytes);
    return name;
  }

  /// Reads and decrypts a stored image. Returns null if missing/corrupt.
  Future<Uint8List?> read(String name) async {
    if (name.isEmpty) return null;
    final cached = _cache[name];
    if (cached != null) return cached;

    try {
      final dir = await _getDir();
      final file = File(p.join(dir.path, name));
      if (!await file.exists()) return null;

      final raw = await file.readAsBytes();
      if (raw.length < 28) return null;
      final key = await _getKey();
      final box = SecretBox(
        raw.sublist(12, raw.length - 16),
        nonce: raw.sublist(0, 12),
        mac: Mac(raw.sublist(raw.length - 16)),
      );
      final clear = Uint8List.fromList(
        await _cipher.decrypt(box, secretKey: key),
      );
      _cachePut(name, clear);
      return clear;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String name) async {
    if (name.isEmpty) return;
    _cache.remove(name);
    try {
      final dir = await _getDir();
      final file = File(p.join(dir.path, name));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — orphaned files are unreadable without the key anyway.
    }
  }

  void _cachePut(String name, Uint8List bytes) {
    _cache.remove(name);
    _cache[name] = bytes;
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Deletes every stored image and the encryption key. Used only by the
  /// "forgotten PIN" recovery path.
  Future<void> wipeAll() async {
    _cache.clear();
    final dir = await _getDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await _secureStorage.delete(key: _keyStorageKey);
    _key = null;
    _dir = null;
  }
}
