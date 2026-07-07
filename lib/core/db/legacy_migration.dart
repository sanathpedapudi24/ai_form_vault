import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/image_vault.dart';

/// One-time import of documents saved by earlier builds, which kept
/// everything as a JSON blob in SharedPreferences with unencrypted images.
/// Images are pulled into the encrypted vault and originals deleted.
class LegacyMigration {
  const LegacyMigration({
    this.documents = const DocumentRepository(),
    this.settings = const SettingsRepository(),
  });

  final DocumentRepository documents;
  final SettingsRepository settings;

  Future<void> runIfNeeded() async {
    final done = await settings.getBool(SettingsRepository.legacyMigrationDone);
    if (done) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('documents');
      if (data != null && data.isNotEmpty) {
        final list = (jsonDecode(data) as List)
            .map((e) => DocumentModel.fromMap(e as Map<String, dynamic>))
            .toList();

        for (final doc in list) {
          var migrated = doc;
          // Legacy imageFile holds an absolute path to a plain file.
          final legacyPath = doc.imageFile;
          if (legacyPath.isNotEmpty && !legacyPath.endsWith('.enc')) {
            final file = File(legacyPath);
            if (await file.exists()) {
              final bytes = Uint8List.fromList(await file.readAsBytes());
              final vaultName = await ImageVault.instance.save(bytes);
              migrated = doc.copyWith(imageFile: vaultName);
              try {
                await file.delete();
              } catch (_) {}
            } else {
              migrated = doc.copyWith(imageFile: '');
            }
          }
          await documents.insert(migrated);
        }
        await prefs.remove('documents');
      }
      // Old profile blob is superseded by the facts engine; drop it.
      await prefs.remove('profile');
    } catch (_) {
      // Never block app start on legacy data. Whatever failed stays in
      // SharedPreferences for a later attempt.
      return;
    }

    await settings.setBool(SettingsRepository.legacyMigrationDone, true);
  }
}
