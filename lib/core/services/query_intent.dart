import '../models/document_model.dart';

/// What an on-device search query is actually asking for, extracted with
/// plain heuristics (no LLM required) so search still feels conversational.
class QueryIntent {
  /// Cleaned search terms with question phrasing and noise words removed.
  final List<String> terms;

  /// True when the query is about expiry/validity ("when does X expire").
  final bool wantsExpiry;

  /// A document category implied by a synonym in the query (e.g. "ID").
  final DocumentCategory? categoryHint;

  const QueryIntent({
    required this.terms,
    this.wantsExpiry = false,
    this.categoryHint,
  });

  /// Leading question/command phrasing to strip so what's left is the
  /// subject of the query — "find my passport" -> "passport".
  static final _leadingPhrases = <RegExp>[
    RegExp(r'^(please\s+)?find\s+(my|me|the)?\s*', caseSensitive: false),
    RegExp(r'^show\s+(me\s+)?(my|the)?\s*', caseSensitive: false),
    RegExp(r'^search\s+(for\s+)?(my|the)?\s*', caseSensitive: false),
    RegExp(r'^where\s+(is|are)\s+(my|the)?\s*', caseSensitive: false),
    RegExp(r"^when\s+(does|do|is)\s+(my|the)?\s*", caseSensitive: false),
    RegExp(r"^what(\'s|s|\s+is)\s+(my|the)?\s*", caseSensitive: false),
    RegExp(r'^do\s+i\s+have\s+(a|an|any)?\s*', caseSensitive: false),
    RegExp(r'^i\s+(need|want)\s+(my|the)?\s*', caseSensitive: false),
    RegExp(r'^(get|open|view)\s+(my|the)?\s*', caseSensitive: false),
  ];

  static const _expiryWords = {
    'expire', 'expires', 'expiry', 'expiring', 'valid', 'validity',
  };

  static const _stopWords = {
    'a', 'an', 'the', 'my', 'me', 'is', 'are', 'of', 'for', 'to', 'in',
  };

  static const Map<DocumentCategory, List<String>> _categorySynonyms = {
    DocumentCategory.identity: ['id', 'identity'],
    DocumentCategory.education: ['education'],
    DocumentCategory.finance: ['finance', 'bank', 'insurance', 'tax'],
    DocumentCategory.medical: ['medical', 'health'],
    DocumentCategory.travel: ['travel'],
    DocumentCategory.family: ['family'],
  };

  /// Parses a raw search string into a [QueryIntent].
  static QueryIntent parse(String rawQuery) {
    var query = rawQuery.trim().toLowerCase();
    query = query.replaceAll(RegExp(r'[?!.]+$'), '').trim();

    for (final phrase in _leadingPhrases) {
      final stripped = query.replaceFirst(phrase, '');
      if (stripped != query) {
        query = stripped.trim();
        break;
      }
    }

    final rawTerms = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    var wantsExpiry = false;
    final terms = <String>[];
    for (final term in rawTerms) {
      if (_expiryWords.contains(term)) {
        wantsExpiry = true;
        continue;
      }
      if (_stopWords.contains(term) || term.length <= 1) continue;
      terms.add(term);
    }

    DocumentCategory? categoryHint;
    for (final entry in _categorySynonyms.entries) {
      if (terms.any((t) => entry.value.contains(t))) {
        categoryHint = entry.key;
        break;
      }
    }

    return QueryIntent(
      terms: terms.isEmpty ? rawTerms : terms,
      wantsExpiry: wantsExpiry,
      categoryHint: categoryHint,
    );
  }
}
