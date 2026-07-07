import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/document_model.dart';
import '../models/person_model.dart';
import '../services/document_intelligence.dart';
import '../services/identity_engine.dart';
import '../services/image_prep.dart';
import '../services/image_vault.dart';
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
  final Uint8List? imageBytes;
  final String? error;
  final IngestOutcome? outcome;

  const CaptureState({
    this.stage = CaptureStage.idle,
    this.draft,
    this.analysis,
    this.suggestedOwner,
    this.imageBytes,
    this.error,
    this.outcome,
  });

  CaptureState copyWith({
    CaptureStage? stage,
    DocumentModel? draft,
    DocumentAnalysis? analysis,
    Person? suggestedOwner,
    Uint8List? imageBytes,
    String? error,
    IngestOutcome? outcome,
  }) => CaptureState(
    stage: stage ?? this.stage,
    draft: draft ?? this.draft,
    analysis: analysis ?? this.analysis,
    suggestedOwner: suggestedOwner ?? this.suggestedOwner,
    imageBytes: imageBytes ?? this.imageBytes,
    error: error ?? this.error,
    outcome: outcome ?? this.outcome,
  );
}

/// Runs the whole scan pipeline:
/// image → OCR → AI analysis → draft → (user review) → encrypted save →
/// embedding → identity graph ingest.
class CaptureNotifier extends StateNotifier<CaptureState> {
  CaptureNotifier(this._ref) : super(const CaptureState());

  final Ref _ref;

  Future<void> process(String imagePath) async {
    state = const CaptureState(stage: CaptureStage.reading);
    try {
      // 1. On-device OCR (also feeds the offline fallback).
      final ocr = await _ref.read(ocrServiceProvider).processImage(imagePath);

      // 2. Downscale once; the same bytes go to Gemini and the vault.
      final imageBytes = await ImagePrep.prepareForUpload(imagePath);

      state = state.copyWith(
        stage: CaptureStage.understanding,
        imageBytes: imageBytes,
      );

      // 3. AI (or fallback) analysis.
      final analysis = await _ref
          .read(documentIntelligenceProvider)
          .analyze(imageBytes: imageBytes, ocrText: ocr.text);

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
        extractedFields: analysis.fields,
        rawText: ocr.text,
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
        toSave = draft.copyWith(imageFile: imageFile, thumbFile: thumbFile);
      }

      await _ref.read(documentsProvider.notifier).add(toSave);

      // Semantic index (no-op when offline; backfilled later).
      await _ref.read(embeddingServiceProvider).embedDocument(toSave);

      // Identity graph: facts + relationship suggestions.
      final outcome = await _ref.read(identityEngineProvider).ingest(
        document: toSave,
        mentions: analysis.people,
        ownerPersonId: toSave.personId!,
      );
      await _ref.read(identityGraphProvider.notifier).refresh();

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
