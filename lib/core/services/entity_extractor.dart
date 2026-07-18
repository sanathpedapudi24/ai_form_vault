import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

import 'field_enrichment.dart';

/// Wraps ML Kit Entity Extraction. Inference runs entirely on-device; the
/// model is downloaded once (a generic model file, never your document data).
/// Every call is defensive — if the model isn't available (e.g. first run
/// offline) it returns nothing and the regex parser stands alone.
class EntityExtractorService {
  EntityExtractor? _extractor;
  final _models = EntityExtractorModelManager();

  Future<ExtractedEntities> extract(String text) async {
    if (text.trim().isEmpty) return const ExtractedEntities();
    try {
      _extractor ??= EntityExtractor(
        language: EntityExtractorLanguage.english,
      );

      // Ensure the on-device model exists; download once if missing.
      const tag = 'en';
      final downloaded = await _models.isModelDownloaded(tag);
      if (!downloaded) {
        await _models.downloadModel(tag, isWifiRequired: false);
      }

      final annotations = await _extractor!.annotateText(
        text,
        entityTypesFilter: const [
          EntityType.phone,
          EntityType.email,
          EntityType.address,
        ],
      );

      final phones = <String>[];
      final emails = <String>[];
      final addresses = <String>[];
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          switch (entity.type) {
            case EntityType.phone:
              phones.add(annotation.text.trim());
            case EntityType.email:
              emails.add(annotation.text.trim());
            case EntityType.address:
              addresses.add(annotation.text.trim());
            default:
              break;
          }
        }
      }
      return ExtractedEntities(
        phones: phones,
        emails: emails,
        addresses: addresses,
      );
    } catch (_) {
      // Model missing / offline / platform quirk — fall back to regex-only.
      return const ExtractedEntities();
    }
  }

  Future<void> dispose() async {
    await _extractor?.close();
    _extractor = null;
  }
}
