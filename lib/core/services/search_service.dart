import 'dart:math';

import '../config/app_config.dart';
import '../models/document_model.dart';
import 'query_intent.dart';

/// One search hit: the document, why it matched, and how strongly.
class SearchResult {
  final DocumentModel document;
  final double score;

  /// The field or snippet that matched, for highlighting in results.
  final String matchedLabel;
  final String matchedValue;

  const SearchResult({
    required this.document,
    required this.score,
    this.matchedLabel = '',
    this.matchedValue = '',
  });
}

/// Keyword search with natural-language intent parsing.
///
/// [QueryIntent.parse] strips question phrasing and reasons about
/// expiry/category intent directly, so search feels conversational
/// rather than purely literal keyword matching. Runs entirely over
/// local data — no network calls.
class SearchService {
  Future<List<SearchResult>> search(
    String query,
    List<DocumentModel> docs,
  ) async {
    final q = query.trim();
    if (q.isEmpty || docs.isEmpty) return [];

    final intent = QueryIntent.parse(q);

    final scores = <String, SearchResult>{};
    for (final doc in docs) {
      final result = _keywordScore(intent, doc);
      if (result != null) scores[doc.id] = result;
    }

    final results = scores.values.toList()
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
}
