import 'dart:math';
import 'dart:typed_data';

import '../config/app_config.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import 'embedding_service.dart';

/// One search hit: the document, why it matched, and how strongly.
class SearchResult {
  final DocumentModel document;
  final double score;

  /// The field or snippet that matched, for highlighting in results.
  final String matchedLabel;
  final String matchedValue;
  final bool semantic;

  const SearchResult({
    required this.document,
    required this.score,
    this.matchedLabel = '',
    this.matchedValue = '',
    this.semantic = false,
  });
}

/// Hybrid search: semantic (vector cosine) + keyword, merged.
///
/// With a Gemini key, natural-language queries like "when does my insurance
/// expire" rank by meaning; without one, weighted keyword matching still
/// gives useful results. Both paths run entirely over local data.
class SearchService {
  SearchService({
    EmbeddingService? embeddings,
    DocumentRepository? documents,
  }) : _embeddings = embeddings ?? EmbeddingService(),
       _documents = documents ?? const DocumentRepository();

  final EmbeddingService _embeddings;
  final DocumentRepository _documents;

  Future<List<SearchResult>> search(
    String query,
    List<DocumentModel> docs,
  ) async {
    final q = query.trim();
    if (q.isEmpty || docs.isEmpty) return [];

    final keywordScores = <String, SearchResult>{};
    for (final doc in docs) {
      final result = _keywordScore(q, doc);
      if (result != null) keywordScores[doc.id] = result;
    }

    // Semantic pass (only when AI is configured and embeddings exist).
    final semanticScores = <String, double>{};
    final queryVector = await _embeddings.embedQuery(q);
    if (queryVector != null) {
      final stored = await _documents.getAllEmbeddings();
      stored.forEach((id, vector) {
        final score = _cosine(queryVector, vector);
        if (score >= AppConfig.semanticSearchThreshold) {
          semanticScores[id] = score;
        }
      });
    }

    // Merge: semantic similarity dominates, keyword hits boost/anchor.
    final byId = {for (final d in docs) d.id: d};
    final merged = <String, SearchResult>{};

    semanticScores.forEach((id, score) {
      final doc = byId[id];
      if (doc == null) return;
      final keyword = keywordScores[id];
      merged[id] = SearchResult(
        document: doc,
        score: score + (keyword != null ? 0.15 : 0),
        matchedLabel: keyword?.matchedLabel ?? '',
        matchedValue: keyword?.matchedValue ?? '',
        semantic: true,
      );
    });
    keywordScores.forEach((id, result) {
      merged.putIfAbsent(id, () => result);
    });

    final results = merged.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return results.take(AppConfig.searchMaxResults).toList();
  }

  // --- Keyword scoring ---------------------------------------------------------

  SearchResult? _keywordScore(String query, DocumentModel doc) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
    if (terms.isEmpty) return null;

    var score = 0.0;
    var matchedLabel = '';
    var matchedValue = '';

    bool containsTerm(String haystack, String term) =>
        haystack.toLowerCase().contains(term);

    for (final term in terms) {
      var termScore = 0.0;

      if (containsTerm(doc.name, term)) termScore = max(termScore, 0.5);
      if (containsTerm(doc.detectedType, term)) termScore = max(termScore, 0.5);
      if (containsTerm(doc.type, term)) termScore = max(termScore, 0.45);
      if (containsTerm(doc.ownerName, term)) termScore = max(termScore, 0.45);
      if (containsTerm(doc.category.label, term)) {
        termScore = max(termScore, 0.35);
      }

      for (final field in doc.extractedFields) {
        if (containsTerm(field.value, term) || containsTerm(field.label, term)) {
          if (termScore < 0.4) {
            termScore = 0.4;
            matchedLabel = field.label;
            matchedValue = field.value;
          }
        }
      }

      if (termScore == 0 && containsTerm(doc.rawText, term)) termScore = 0.15;
      if (termScore == 0 && containsTerm(doc.summary, term)) termScore = 0.2;

      score += termScore;
    }

    if (score <= 0) return null;
    // Normalize by term count so long queries don't inflate scores.
    return SearchResult(
      document: doc,
      score: (score / terms.length).clamp(0.0, 1.0) * 0.6,
      matchedLabel: matchedLabel,
      matchedValue: matchedValue,
    );
  }

  static double _cosine(List<double> a, Float32List b) {
    final n = min(a.length, b.length);
    var dot = 0.0, magA = 0.0, magB = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0;
    return dot / (sqrt(magA) * sqrt(magB));
  }
}
