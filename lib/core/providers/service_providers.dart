import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/document_repository.dart';
import '../repositories/person_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/document_intelligence.dart';
import '../services/form_fill_service.dart';
import '../services/gemini_client.dart';
import '../services/identity_engine.dart';
import '../services/ocr_service.dart';
import '../services/search_service.dart';

/// Single home for service/repository singletons so everything is
/// injectable and testable.
final geminiClientProvider = Provider<GeminiClient>((ref) {
  final client = GeminiClient();
  ref.onDispose(client.dispose);
  return client;
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => const DocumentRepository(),
);

final personRepositoryProvider = Provider<PersonRepository>(
  (ref) => const PersonRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => const SettingsRepository(),
);

final documentIntelligenceProvider = Provider<DocumentIntelligence>(
  (ref) => DocumentIntelligence(),
);

final searchServiceProvider = Provider<SearchService>(
  (ref) => SearchService(),
);

final identityEngineProvider = Provider<IdentityEngine>(
  (ref) => IdentityEngine(persons: ref.watch(personRepositoryProvider)),
);

final formFillServiceProvider = Provider<FormFillService>(
  (ref) => FormFillService(gemini: ref.watch(geminiClientProvider)),
);
