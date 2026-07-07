import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import 'gemini_client.dart';

/// Creates and stores semantic embeddings for documents.
class EmbeddingService {
  EmbeddingService({
    GeminiClient? gemini,
    DocumentRepository? documents,
  }) : _gemini = gemini ?? GeminiClient(),
       _documents = documents ?? const DocumentRepository();

  final GeminiClient _gemini;
  final DocumentRepository _documents;

  bool get isAvailable => _gemini.isConfigured;

  /// The text that represents a document in vector space: its type, owner,
  /// summary and field labels/values — but never long raw OCR noise.
  static String embeddingText(DocumentModel doc) {
    final buffer = StringBuffer()
      ..writeln(doc.displayTitle)
      ..writeln('Category: ${doc.category.label}')
      ..writeln('Owner: ${doc.ownerName}');
    if (doc.summary.isNotEmpty) buffer.writeln(doc.summary);
    for (final f in doc.extractedFields.take(24)) {
      // Skip raw ID numbers — they don't help semantic matching.
      if (FactKeys.sensitive.contains(f.semanticKey)) continue;
      buffer.writeln('${f.label}: ${f.value}');
    }
    return buffer.toString().trim();
  }

  /// Embeds one document and persists the vector. Silently no-ops when AI
  /// is unavailable (search falls back to keywords).
  Future<void> embedDocument(DocumentModel doc) async {
    if (!isAvailable) return;
    try {
      final vectors = await _gemini.embed([embeddingText(doc)]);
      if (vectors.isNotEmpty) {
        await _documents.saveEmbedding(doc.id, vectors.first);
      }
    } on GeminiException {
      // Non-fatal: the document just won't rank semantically until backfill.
    }
  }

  /// Embeds any documents missing a vector (e.g. scanned while offline).
  Future<void> backfill() async {
    if (!isAvailable) return;
    final missing = await _documents.getIdsWithoutEmbedding();
    for (final id in missing) {
      final doc = await _documents.getById(id);
      if (doc != null) await embedDocument(doc);
    }
  }

  /// Embeds a search query.
  Future<List<double>?> embedQuery(String query) async {
    if (!isAvailable) return null;
    try {
      final vectors = await _gemini.embed([query]);
      return vectors.isEmpty ? null : vectors.first;
    } on GeminiException {
      return null;
    }
  }
}
