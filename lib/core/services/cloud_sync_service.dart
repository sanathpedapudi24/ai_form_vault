import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backup_service.dart';

/// Encrypted cloud backup over Firestore.
///
/// The whole vault (documents, facts, relationships, and images) is packed
/// and encrypted client-side by [BackupService] — Firestore only ever sees
/// the resulting ciphertext, never plaintext. Because a single Firestore
/// document is capped at ~1 MB, the encrypted blob is base64-encoded and
/// split into ~700 KB chunks written under `users/{uid}/vault_backup/*`.
///
/// This keeps the on-device privacy stance intact while giving real
/// multi-device restore: sign in on a new phone, enter the same passphrase,
/// pull it back down.
class CloudSyncService {
  CloudSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    BackupService? backup,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _backup = backup ?? BackupService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final BackupService _backup;

  // ~700 KB of base64 per chunk stays comfortably under Firestore's ~1 MB
  // document limit even with field overhead.
  static const _chunkChars = 700000;

  CollectionReference<Map<String, dynamic>> _chunks(String uid) =>
      _db.collection('users').doc(uid).collection('vault_backup');

  DocumentReference<Map<String, dynamic>> _meta(String uid) =>
      _db.collection('users').doc(uid).collection('vault_meta').doc('backup');

  /// Encrypts the whole vault with [passphrase] and uploads it. Replaces any
  /// previous cloud backup for this user.
  Future<DateTime> upload(String passphrase) async {
    final uid = _requireUid();
    final Uint8List blob = await _backup.export(passphrase);
    final b64 = base64Encode(blob);

    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += _chunkChars) {
      chunks.add(
        b64.substring(
          i,
          i + _chunkChars > b64.length ? b64.length : i + _chunkChars,
        ),
      );
    }

    // Clear stale chunks first (a smaller new backup must not leave old
    // trailing chunks behind).
    await _deleteChunks(uid);

    final batch = _db.batch();
    for (var i = 0; i < chunks.length; i++) {
      batch.set(_chunks(uid).doc('$i'), {'data': chunks[i]});
    }
    final now = DateTime.now();
    batch.set(_meta(uid), {
      'chunkCount': chunks.length,
      'updatedAt': now.toIso8601String(),
      'bytes': blob.length,
    });
    await batch.commit();
    return now;
  }

  /// Timestamp of the current cloud backup, or null if none exists.
  Future<DateTime?> lastBackupTime() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _meta(uid).get();
    final raw = snap.data()?['updatedAt'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Downloads, decrypts and restores the cloud backup. Throws
  /// [BackupException] on a wrong passphrase, [CloudSyncException] if there's
  /// no backup to restore.
  Future<RestoreResult> restore(String passphrase) async {
    final uid = _requireUid();
    final meta = await _meta(uid).get();
    final count = meta.data()?['chunkCount'] as int?;
    if (count == null || count == 0) {
      throw const CloudSyncException('No cloud backup found for this account.');
    }

    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      final snap = await _chunks(uid).doc('$i').get();
      final part = snap.data()?['data'] as String?;
      if (part == null) {
        throw const CloudSyncException('Cloud backup is incomplete.');
      }
      buffer.write(part);
    }

    final blob = base64Decode(buffer.toString());
    // BackupService throws BackupException for a wrong passphrase.
    return _backup.restore(blob, passphrase);
  }

  Future<void> _deleteChunks(String uid) async {
    final existing = await _chunks(uid).get();
    if (existing.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const CloudSyncException('You must be signed in to sync.');
    }
    return uid;
  }
}

class CloudSyncException implements Exception {
  final String message;
  const CloudSyncException(this.message);

  @override
  String toString() => message;
}
