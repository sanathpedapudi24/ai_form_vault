import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/document_model.dart';
import '../models/person_model.dart';
import '../repositories/settings_repository.dart';
import '../services/document_intelligence.dart';
import '../services/field_enrichment.dart';
import '../services/identity_engine.dart';
import '../services/image_prep.dart';
import '../services/image_vault.dart';
import '../services/notification_service.dart';
import 'document_provider.dart';
import 'person_provider.dart';
import 'service_providers.dart';

/// Stages the scanning screen animates through.
enum CaptureStage {
  idle,
  reading, // on-device OCR
  understanding, // Gemini vision
  organizing, // facts + relationships
  ready, // draft awaiting review
  saving,
  saved,
  failed,
}

class CaptureState {
  final CaptureStage stage;

  /// Draft document under review (unsaved until the user confirms).
  final DocumentModel? draft;
  final DocumentAnalysis? analysis;
  final Person? suggestedOwner;

  /// First page — the document's primary image.
  final Uint8List? imageBytes;

  /// Pages beyond the first (multi-page scans, PDF imports).
  final List<Uint8List> extraPageBytes;
  final String? error;
  final IngestOutcome? outcome;

  /// True when the primary page's scan quality (focus/brightness) was poor
  /// enough that the review screen should offer a retake.
  final bool lowQualityScan;

  const CaptureState({
    this.stage = CaptureStage.idle,
    this.draft,
    this.analysis,
    this.suggestedOwner,
    this.imageBytes,
    this.extraPageBytes = const [],
    this.error,
    this.outcome,
    this.lowQualityScan = false,
  });

  CaptureState copyWith({
    CaptureStage? stage,
    DocumentModel? draft,
    DocumentAnalysis? analysis,
    Person? suggestedOwner,
    Uint8List? imageBytes,
    List<Uint8List>? extraPageBytes,
    String? error,
    IngestOutcome? outcome,
    bool? lowQualityScan,
  }) => CaptureState(
    stage: stage ?? this.stage,
    draft: draft ?? this.draft,
    analysis: analysis ?? this.analysis,
    suggestedOwner: suggestedOwner ?? this.suggestedOwner,
    imageBytes: imageBytes ?? this.imageBytes,
    extraPageBytes: extraPageBytes ?? this.extraPageBytes,
    error: error ?? this.error,
    outcome: outcome ?? this.outcome,
    lowQualityScan: lowQualityScan ?? this.lowQualityScan,
  );
}

/// Runs the whole scan pipeline:
/// image → OCR → AI analysis → draft → (user review) → encrypted save →
/// embedding → identity graph ingest.
class CaptureNotifier extends StateNotifier<CaptureState> {
  CaptureNotifier(this._ref) : super(const CaptureState());

  final Ref _ref;

  /// Processes one or more page images as a single document. The first
  /// page drives classification; OCR text from every page is combined so
  /// fields printed on later pages still get extracted.
  Future<void> process(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;
    state = const CaptureState(stage: CaptureStage.reading);
    try {
      // 1. Preprocess (deskew/grayscale/contrast/sharpen) + OCR each page.
      //    The first page is the primary side — its scan quality drives the
      //    "retake?" prompt on review.
      final ocrTexts = <String>[];
      var lowQuality = false;
      for (var i = 0; i < imagePaths.length; i++) {
        final prepped = await ImagePrep.prepareForOcr(imagePaths[i]);
        if (i == 0) lowQuality = prepped.looksPoor;
        final ocr =
            await _ref.read(ocrServiceProvider).processImage(prepped.path);
        ocrTexts.add(ocr.text);
      }
      final combinedText = ocrTexts.join('\n\n');

      // 2. Downscale each page once; the same bytes go into the vault.
      final imageBytes = await ImagePrep.prepareForUpload(imagePaths.first);
      final extraPageBytes = <Uint8List>[
        for (final path in imagePaths.skip(1))
          await ImagePrep.prepareForUpload(path),
      ];

      state = state.copyWith(
        stage: CaptureStage.understanding,
        imageBytes: imageBytes,
        extraPageBytes: extraPageBytes,
        lowQualityScan: lowQuality,
      );

      // 3. AI (or fallback) analysis, voting fields across pages.
      final analysis = await _ref
          .read(documentIntelligenceProvider)
          .analyze(
            imageBytes: imageBytes,
            ocrText: combinedText,
            pageTexts: ocrTexts,
          );

      // 3b. On-device entity extraction + value normalization: cleans up the
      //     regex parser's values and fills phone/email/address gaps. Fully
      //     local; degrades to no-op if the ML Kit model isn't available.
      final entities =
          await _ref.read(entityExtractorProvider).extract(combinedText);
      final enrichedFields =
          FieldEnrichment.enrich(analysis.fields, entities);

      state = state.copyWith(stage: CaptureStage.organizing);

      // 4. Suggest an owner for the review screen.
      final owner = await _ref
          .read(identityEngineProvider)
          .resolveOwner(analysis.ownerName);

      final draft = DocumentModel(
        id: const Uuid().v4(),
        name: analysis.documentType,
        ownerName: analysis.ownerName,
        personId: owner.id,
        category: analysis.category,
        type: analysis.documentType,
        detectedType: analysis.documentType,
        uploadDate: DateTime.now(),
        confidence: analysis.confidence,
        extractedFields: enrichedFields,
        rawText: combinedText,
        summary: analysis.summary,
        source: analysis.source,
      );

      state = state.copyWith(
        stage: CaptureStage.ready,
        draft: draft,
        analysis: analysis,
        suggestedOwner: owner,
      );
    } catch (e) {
      state = state.copyWith(
        stage: CaptureStage.failed,
        error: 'Could not read this document. Try a clearer photo.',
      );
    }
  }

  /// Updates a field on the draft during review (marks it verified).
  void updateDraftField(int index, String newValue) {
    final draft = state.draft;
    if (draft == null || index < 0 || index >= draft.extractedFields.length) {
      return;
    }
    final fields = [...draft.extractedFields];
    fields[index] = fields[index].copyWith(
      value: newValue,
      verified: true,
      confidence: 1.0,
    );
    state = state.copyWith(draft: draft.copyWith(extractedFields: fields));
  }

  void updateDraftName(String name) {
    final draft = state.draft;
    if (draft == null || name.trim().isEmpty) return;
    state = state.copyWith(draft: draft.copyWith(name: name.trim()));
  }

  void updateDraftCategory(DocumentCategory category) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(category: category));
  }

  /// Persists the reviewed draft. Encrypts the image, stores the document,
  /// embeds it for search, and feeds the identity graph.
  Future<DocumentModel?> save() async {
    final draft = state.draft;
    final analysis = state.analysis;
    final imageBytes = state.imageBytes;
    if (draft == null || analysis == null) return null;

    state = state.copyWith(stage: CaptureStage.saving);
    try {
      var toSave = draft;
      if (imageBytes != null) {
        final imageFile = await ImageVault.instance.save(imageBytes);
        final thumbBytes = await ImagePrep.makeThumbnail(imageBytes);
        final thumbFile = await ImageVault.instance.save(thumbBytes);
        final extraPages = <String>[
          for (final page in state.extraPageBytes)
            await ImageVault.instance.save(page),
        ];
        toSave = draft.copyWith(
          imageFile: imageFile,
          thumbFile: thumbFile,
          extraPages: extraPages,
        );
      }

      await _ref.read(documentsProvider.notifier).add(toSave);

      // Identity graph: facts + relationship suggestions.
      final outcome = await _ref.read(identityEngineProvider).ingest(
        document: toSave,
        mentions: analysis.people,
        ownerPersonId: toSave.personId!,
      );
      await _ref.read(identityGraphProvider.notifier).refresh();

      // Expiry reminders (local notifications; respects the settings
      // toggle and no-ops when the document has no expiry date).
      final remindersOn = await _ref
          .read(settingsRepositoryProvider)
          .getBool(SettingsRepository.expiryRemindersEnabled,
              defaultValue: true);
      if (remindersOn) {
        await NotificationService.instance.requestPermission();
        await NotificationService.instance.scheduleForDocument(toSave);
      }

      state = state.copyWith(
        stage: CaptureStage.saved,
        draft: toSave,
        outcome: outcome,
      );
      return toSave;
    } catch (e) {
      state = state.copyWith(
        stage: CaptureStage.failed,
        error: 'Could not save the document. Please try again.',
      );
      return null;
    }
  }

  void reset() => state = const CaptureState();
}

final captureProvider = StateNotifierProvider<CaptureNotifier, CaptureState>(
  (ref) => CaptureNotifier(ref),
);
