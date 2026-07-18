import 'dart:math';

import '../config/app_config.dart';
import '../models/document_model.dart';
import '../models/person_model.dart';
import 'query_intent.dart';
import 'text_similarity.dart';
import 'vault_lexicon.dart';

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

/// Natural-language, fuzzy, on-device search.
///
/// [QueryIntent] extracts field/person/time/expiry intent; matching tolerates
/// typos (bigram similarity), expands synonyms ("uid" → "aadhaar"), and honors
/// person scope ("wife's passport") and relative time ("expiring next month").
/// Runs entirely over local data — no network.
class SearchService {
  Future<List<SearchResult>> search(
    String query,
    List<DocumentModel> docs, {
    List<Person> persons = const [],
    List<Relationship> rels = const [],
  }) async {
    final q = query.trim();
    if (q.isEmpty || docs.isEmpty) return [];

    final intent = QueryIntent.parse(q);
    final personScopeId = _resolvePersonScope(intent, persons, rels);

    final scores = <String, SearchResult>{};
    for (final doc in docs) {
      // Hard filters first.
      if (personScopeId != null && doc.personId != personScopeId) continue;
      if (intent.timeScope != null &&
          !intent.timeScope!.matches(doc, parseFlexibleDate)) {
        continue;
      }

      final result = _keywordScore(intent, doc);
      if (result != null) {
        scores[doc.id] = result;
      } else if (intent.terms.isEmpty &&
          (personScopeId != null || intent.timeScope != null)) {
        // "documents expiring next month" / "wife's documents" — no search
        // terms, but the filters matched; include, ranked by recency.
        scores[doc.id] = SearchResult(document: doc, score: 0.4);
      }
    }

    final results = scores.values.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.document.uploadDate.compareTo(a.document.uploadDate);
      });
    return results.take(AppConfig.searchMaxResults).toList();
  }

  String? _resolvePersonScope(
    QueryIntent intent,
    List<Person> persons,
    List<Relationship> rels,
  ) {
    final relation = intent.personRelation;
    if (relation == null) return null;
    final user = persons.where((p) => p.isUser).firstOrNull;
    if (user == null) return null;
    // "X is the [relation] of user" → from=X, to=user.
    final match = rels
        .where((r) => r.type == relation && r.toPersonId == user.id)
        .firstOrNull;
    return match?.fromPersonId;
  }

  // --- Scoring ----------------------------------------------------------------

  SearchResult? _keywordScore(QueryIntent intent, DocumentModel doc) {
    final terms = intent.terms;
    if (terms.isEmpty) return null;

    var score = 0.0;
    var matchedLabel = '';
    var matchedValue = '';

    for (final term in terms) {
      // Expand the term to its concept aliases so "uid" hits "aadhaar".
      final variants = VaultLexicon.expand(term);
      var termScore = 0.0;

      double hit(String haystack, double weight) {
        for (final v in variants) {
          if (TextSimilarity.fuzzyContains(haystack, v)) return weight;
        }
        return 0;
      }

      termScore = max(termScore, hit(doc.name, 0.5));
      termScore = max(termScore, hit(doc.detectedType, 0.5));
      termScore = max(termScore, hit(doc.type, 0.45));
      termScore = max(termScore, hit(doc.ownerName, 0.45));
      termScore = max(termScore, hit(doc.category.label, 0.35));

      for (final field in doc.extractedFields) {
        final fieldHit =
            hit(field.value, 0.4) > 0 || hit(field.label, 0.4) > 0;
        if (fieldHit && termScore < 0.4) {
          termScore = 0.4;
          matchedLabel = field.label;
          matchedValue = field.value;
        }
      }

      if (hit(doc.note, 0.45) > 0) termScore = max(termScore, 0.45);
      if (termScore == 0 && hit(doc.rawText, 0.15) > 0) termScore = 0.15;
      if (termScore == 0 && hit(doc.summary, 0.2) > 0) termScore = 0.2;

      score += termScore;
    }

    // Category synonym ("find my ID") counts even when the word isn't printed.
    if (intent.categoryHint != null && intent.categoryHint == doc.category) {
      score += terms.length * 0.25;
    }

    // Boost the document that actually holds the targeted field.
    if (intent.fieldHint != null && doc.fieldByKey(intent.fieldHint!) != null) {
      score += 0.3;
      final f = doc.fieldByKey(intent.fieldHint!)!;
      if (matchedLabel.isEmpty) {
        matchedLabel = f.label;
        matchedValue = f.value;
      }
    }

    if (score <= 0 && !(intent.wantsExpiry && _hasExpiryData(doc))) {
      return null;
    }

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
            normalized += 0.15;
          } else if (daysLeft <= 90) {
            normalized += 0.1;
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

  /// Parses the common date formats this app produces (dd/mm/yyyy, dd-mm-yyyy,
  /// yyyy-mm-dd, ISO). Returns null rather than guessing when ambiguous.
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
