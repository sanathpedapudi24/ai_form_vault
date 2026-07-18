import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Encrypted app database (SQLCipher). The passphrase is a random 256-bit
/// secret generated on first launch and held in the platform
/// Keystore/Keychain via flutter_secure_storage — it never leaves the device.
class AppDatabase {
  AppDatabase._();

  static const _dbFileName = 'vault.db';
  static const _dbKeyStorageKey = 'vault_db_key';
  static const _secureStorage = FlutterSecureStorage();

  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbFileName);
    final password = await _getOrCreateDbKey();

    try {
      return await _openWithKey(path, password);
    } catch (_) {
      // The file exists but this key can't decrypt it — happens when a
      // reinstall restored the DB file while the Keystore key was lost.
      // The data is cryptographically unrecoverable; set the wreck aside
      // (don't delete) and start fresh so the app can still boot.
      final wreck = File(path);
      if (await wreck.exists()) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        await wreck.rename('$path.unreadable-$ts');
      }
      return await _openWithKey(path, password);
    }
  }

  static Future<Database> _openWithKey(String path, String password) =>
      openDatabase(
        path,
        password: password,
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      );

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // v2: free-text notes per document + extra pages for multi-page scans
      // (JSON list of encrypted image filenames).
      await db.execute(
        "ALTER TABLE documents ADD COLUMN note TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE documents ADD COLUMN extra_pages TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  static Future<String> _getOrCreateDbKey() async {
    String? existing;
    try {
      existing = await _secureStorage.read(key: _dbKeyStorageKey);
    } catch (_) {
      // Restored-but-undecryptable secure prefs (Keystore key lost on
      // reinstall). Clear the wedged entries so a fresh key can be written.
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
    }
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _secureStorage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL DEFAULT '',
        person_id TEXT,
        category TEXT NOT NULL,
        doc_type TEXT NOT NULL DEFAULT '',
        detected_type TEXT NOT NULL DEFAULT '',
        upload_date INTEGER NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        raw_text TEXT NOT NULL DEFAULT '',
        summary TEXT NOT NULL DEFAULT '',
        image_file TEXT NOT NULL DEFAULT '',
        thumb_file TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'onDevice',
        embedding BLOB,
        note TEXT NOT NULL DEFAULT '',
        extra_pages TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE fields (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        value TEXT NOT NULL,
        semantic_key TEXT NOT NULL DEFAULT '',
        confidence REAL NOT NULL DEFAULT 1,
        verified INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_fields_document ON fields(document_id)',
    );

    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        is_user INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE facts (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
        fact_key TEXT NOT NULL,
        value TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 1,
        source_document_id TEXT,
        verified INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        UNIQUE(person_id, fact_key)
      )
    ''');
    await db.execute('CREATE INDEX idx_facts_person ON facts(person_id)');

    await db.execute('''
      CREATE TABLE relationships (
        id TEXT PRIMARY KEY,
        from_person_id TEXT NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
        to_person_id TEXT NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
        rel_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        confidence REAL NOT NULL DEFAULT 0,
        evidence TEXT NOT NULL DEFAULT '',
        source_document_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_rel_from ON relationships(from_person_id)',
    );
    await db.execute('CREATE INDEX idx_rel_to ON relationships(to_person_id)');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Closes the database (tests / teardown).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Deletes the database file and its encryption key entirely. Used only
  /// by the "forgotten PIN" recovery path — there is no cloud account to
  /// reset through, so recovery means starting the vault over.
  static Future<void> deleteAll() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbFileName);
    await databaseFactory.deleteDatabase(path);
    await _secureStorage.delete(key: _dbKeyStorageKey);
  }
}
