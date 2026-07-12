import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../models/person_model.dart';
import '../repositories/document_repository.dart';
import '../repositories/person_repository.dart';
import 'image_vault.dart';

/// Result of a restore, for the confirmation snackbar.
class RestoreResult {
  final int documents;
  final int persons;

  const RestoreResult({required this.documents, required this.persons});
}

/// Passphrase-protected vault backups.
///
/// The file is a single `.aivault` blob:
///   [8-byte magic "AIVAULT1"][16-byte salt][12-byte nonce][ciphertext][16-byte MAC]
/// where the ciphertext is gzip-compressed JSON (all documents, fields,
/// people, facts, relationships, and every image base64-embedded),
/// encrypted with AES-256-GCM under a PBKDF2-HMAC-SHA256 key derived from
/// the user's passphrase. Without the passphrase the file is opaque — safe
/// to park in Drive, email, anywhere.
///
/// This is the answer to "one lost phone = vault gone" that doesn't
/// compromise the no-cloud privacy stance: the *user* decides where the
/// encrypted file goes.
class BackupService {
  BackupService({
    DocumentRepository? documents,
    PersonRepository? persons,
  }) : _documents = documents ?? const DocumentRepository(),
       _persons = persons ?? const PersonRepository();

  final DocumentRepository _documents;
  final PersonRepository _persons;

  static const _magic = 'AIVAULT1';
  static const _pbkdf2Iterations = 150000;

  final _cipher = AesGcm.with256bits();

  // --- Export -----------------------------------------------------------------

  Future<Uint8List> export(String passphrase) async {
    final docs = await _documents.getAll();
    final persons = await _persons.getAllPersons();
    final facts = await _persons.getAllFacts();
    final relationships = await _persons.getRelationships();

    // Collect every encrypted image, decrypted here and re-protected by the
    // backup's own passphrase encryption.
    final images = <String, String>{};
    for (final doc in docs) {
      for (final name in [doc.imageFile, doc.thumbFile, ...doc.extraPages]) {
        if (name.isEmpty || images.containsKey(name)) continue;
        final bytes = await ImageVault.instance.read(name);
        if (bytes != null) images[name] = base64Encode(bytes);
      }
    }

    final payload = jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'documents': docs.map((d) => d.toMap()).toList(),
      'persons': [
        for (final p in persons)
          {
            'id': p.id,
            'displayName': p.displayName,
            'isUser': p.isUser,
            'createdAt': p.createdAt.toIso8601String(),
          },
      ],
      'facts': [
        for (final f in facts)
          {
            'id': f.id,
            'personId': f.personId,
            'factKey': f.factKey,
            'value': f.value,
            'confidence': f.confidence,
            'sourceDocumentId': f.sourceDocumentId,
            'verified': f.verified,
            'updatedAt': f.updatedAt.toIso8601String(),
          },
      ],
      'relationships': [
        for (final r in relationships)
          {
            'id': r.id,
            'fromPersonId': r.fromPersonId,
            'toPersonId': r.toPersonId,
            'type': r.type.name,
            'status': r.status.name,
            'confidence': r.confidence,
            'evidence': r.evidence,
            'sourceDocumentId': r.sourceDocumentId,
            'createdAt': r.createdAt.toIso8601String(),
          },
      ],
      'images': images,
    });

    // Compress + encrypt off the UI thread — backups with images run to
    // tens of MB.
    final salt = _randomBytes(16);
    final key = await _deriveKey(passphrase, salt);
    final compressed = await compute(_gzipEncode, utf8.encode(payload));
    final box = await _cipher.encrypt(compressed, secretKey: key);

    final out = BytesBuilder()
      ..add(ascii.encode(_magic))
      ..add(salt)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  // --- Restore ----------------------------------------------------------------

  /// Decrypts and restores a backup. Existing entries with the same IDs are
  /// replaced; everything else is left alone (merge, not wipe). Throws
  /// [BackupException] for a wrong passphrase or a corrupt/foreign file.
  Future<RestoreResult> restore(Uint8List fileBytes, String passphrase) async {
    if (fileBytes.length < 8 + 16 + 12 + 16 ||
        ascii.decode(fileBytes.sublist(0, 8)) != _magic) {
      throw const BackupException('Not an AI Form & Vault backup file.');
    }

    final salt = fileBytes.sublist(8, 24);
    final nonce = fileBytes.sublist(24, 36);
    final cipherText = fileBytes.sublist(36, fileBytes.length - 16);
    final mac = Mac(fileBytes.sublist(fileBytes.length - 16));

    final key = await _deriveKey(passphrase, salt);
    List<int> compressed;
    try {
      compressed = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupException('Wrong passphrase for this backup.');
    }

    final json =
        jsonDecode(utf8.decode(await compute(_gzipDecode, compressed)))
            as Map<String, dynamic>;

    // Images first, so restored documents immediately resolve their files.
    final images = (json['images'] as Map<String, dynamic>? ?? {});
    final nameMap = <String, String>{};
    for (final entry in images.entries) {
      final newName = await ImageVault.instance.save(
        base64Decode(entry.value as String),
      );
      nameMap[entry.key] = newName;
    }

    var docCount = 0;
    for (final raw in (json['documents'] as List? ?? [])) {
      final map = raw as Map<String, dynamic>;
      var doc = DocumentModel.fromMap(map);
      doc = doc.copyWith(
        imageFile: nameMap[doc.imageFile] ?? '',
        thumbFile: nameMap[doc.thumbFile] ?? '',
        extraPages: [
          for (final p in doc.extraPages)
            if (nameMap.containsKey(p)) nameMap[p]!,
        ],
      );
      await _documents.insert(doc);
      docCount++;
    }

    var personCount = 0;
    for (final raw in (json['persons'] as List? ?? [])) {
      final map = raw as Map<String, dynamic>;
      final person = Person(
        id: map['id'] as String,
        displayName: map['displayName'] as String? ?? '',
        isUser: map['isUser'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
      try {
        await _persons.insertPerson(person);
        personCount++;
      } catch (_) {
        // Already exists (same id) — fine, merge semantics.
      }
    }

    for (final raw in (json['facts'] as List? ?? [])) {
      final map = raw as Map<String, dynamic>;
      await _persons.upsertFact(
        PersonFact(
          id: map['id'] as String,
          personId: map['personId'] as String,
          factKey: map['factKey'] as String,
          value: map['value'] as String? ?? '',
          confidence: (map['confidence'] as num?)?.toDouble() ?? 1,
          sourceDocumentId: map['sourceDocumentId'] as String?,
          verified: map['verified'] as bool? ?? false,
          updatedAt:
              DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }

    for (final raw in (json['relationships'] as List? ?? [])) {
      final map = raw as Map<String, dynamic>;
      try {
        await _persons.insertRelationship(
          Relationship(
            id: map['id'] as String,
            fromPersonId: map['fromPersonId'] as String,
            toPersonId: map['toPersonId'] as String,
            type: RelationshipType.fromName(map['type'] as String? ?? 'other'),
            status: RelationshipStatus.fromName(
              map['status'] as String? ?? 'pending',
            ),
            confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
            evidence: map['evidence'] as String? ?? '',
            sourceDocumentId: map['sourceDocumentId'] as String?,
            createdAt:
                DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      } catch (_) {
        // Duplicate edge — merge semantics again.
      }
    }

    return RestoreResult(documents: docCount, persons: personCount);
  }

  // --- Crypto helpers -----------------------------------------------------------

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  static Uint8List _randomBytes(int n) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(n, (_) => random.nextInt(256)),
    );
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

// Top-level for compute().
List<int> _gzipEncode(List<int> data) => GZipEncoder().encodeBytes(data);
List<int> _gzipDecode(List<int> data) => GZipDecoder().decodeBytes(data);
