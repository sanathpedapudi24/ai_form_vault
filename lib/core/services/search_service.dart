import 'dart:math';
import 'dart:typed_data';

import '../config/app_config.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import 'embedding_service.dart';
import 'query_intent.dart';

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
/// expire" rank by meaning; without one, [NaturalLanguageQuery] strips the
/// question phrasing and reasons about expiry/category intent directly, so
/// search still feels conversational rather than purely literal keyword
/// matching. Both paths run entirely over local data.
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

    final intent = NaturalLanguageQuery.parse(q);

    final keywordScores = <String, SearchResult>{};
    for (final doc in docs) {
      final result = _keywordScore(intent, doc);
      if (result != null) keywordScores[doc.id] = result;
    }

    // Semantic pass (only when AI is configured and embeddings exist).
    // The raw query goes to the embedding model — it handles phrasing on
    // its own and shouldn't be pre-stripped the way the keyword path is.
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

  SearchResult? _keywordScore(QueryIntent intent, DocumentModel doc) {
    final terms = intent.terms;
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

      // A user-written note is a deliberate signal — worth more than raw
      // OCR noise ("visa application" in a note should rank well).
      if (containsTerm(doc.note, term)) termScore = max(termScore, 0.45);

      if (termScore == 0 && containsTerm(doc.rawText, term)) termScore = 0.15;
      if (termScore == 0 && containsTerm(doc.summary, term)) termScore = 0.2;

      score += termScore;
    }

    // A category synonym ("find my ID") counts as a real signal even when
    // the word itself never appears on the document.
    if (intent.categoryHint != null && intent.categoryHint == doc.category) {
      score += terms.length * 0.25;
    }

    if (score <= 0 && !(intent.wantsExpiry && _hasExpiryData(doc))) {
      return null;
    }

    // Normalize by term count so long queries don't inflate scores, then
    // apply expiry reasoning on top — this is what makes "when does my
    // passport expire" surface the right document even offline.
    var normalized = terms.isEmpty
        ? 0.0
        : (score / terms.length).clamp(0.0, 1.0) * 0.6;

    if (intent.wantsExpiry) {
      final expiryField = doc.fieldByKey(FactKeys.expiryDate);
      if (expiryField != null) {
        normalized += 0.25;
        if (matchedLabel.isEmpty) {
          matchedLabel = expiryField.label;
          matchedValue = expiryField.value;
        }
        final expiry = parseFlexibleDate(expiryField.value);
        if (expiry != null) {
          final daysLeft = expiry.difference(DateTime.now()).inDays;
          if (daysLeft < 0) {
            normalized += 0.15; // already expired — surface it prominently
          } else if (daysLeft <= 90) {
            normalized += 0.1; // expiring soon
          }
        }
      }
    }

    if (normalized <= 0) return null;
    return SearchResult(
      document: doc,
      score: normalized.clamp(0.0, 1.0),
      matchedLabel: matchedLabel,
      matchedValue: matchedValue,
    );
  }

  bool _hasExpiryData(DocumentModel doc) =>
      doc.fieldByKey(FactKeys.expiryDate) != null;

  /// Parses the common date formats this app's parser and Gemini extraction
  /// actually produce (dd/mm/yyyy, dd-mm-yyyy, yyyy-mm-dd, ISO). Returns
  /// null rather than guessing when the format is ambiguous. Public because
  /// expiry reminders parse the same field values.
  static DateTime? parseFlexibleDate(String value) {
    final trimmed = value.trim();

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final match = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$')
        .firstMatch(trimmed);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
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
