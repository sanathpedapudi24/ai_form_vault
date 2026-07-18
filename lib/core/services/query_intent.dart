import '../models/document_model.dart';
import '../models/person_model.dart';
import 'vault_lexicon.dart';

/// A relative time window a query asked about, applied to either expiry or
/// upload dates.
class TimeScope {
  final DateTime? from;
  final DateTime? to;

  /// Match documents already past their expiry.
  final bool expiredOnly;

  /// True → test the document's expiry date; false → its upload date.
  final bool onExpiry;

  const TimeScope({
    this.from,
    this.to,
    this.expiredOnly = false,
    this.onExpiry = true,
  });

  bool matches(DocumentModel doc, DateTime? Function(String) parseDate) {
    final value = onExpiry
        ? doc.fieldByKey(FactKeys.expiryDate)?.value
        : null;
    final date = onExpiry
        ? (value == null ? null : parseDate(value))
        : doc.uploadDate;
    if (date == null) return false;
    if (expiredOnly) return date.isBefore(DateTime.now());
    if (from != null && date.isBefore(from!)) return false;
    if (to != null && date.isAfter(to!)) return false;
    return true;
  }
}

/// What an on-device search query is actually asking for, extracted with
/// plain heuristics (no LLM) so search feels conversational.
class QueryIntent {
  /// Cleaned search terms with question phrasing and noise words removed.
  final List<String> terms;

  /// True when the query is about expiry/validity ("when does X expire").
  final bool wantsExpiry;

  /// A document category implied by a synonym in the query (e.g. "ID").
  final DocumentCategory? categoryHint;

  /// The specific fact the query targets ("pan number" → panNumber), if any.
  final String? fieldHint;

  /// A relationship the query scopes to ("wife's documents" → spouse).
  final RelationshipType? personRelation;

  /// A relative time window the query asked about.
  final TimeScope? timeScope;

  const QueryIntent({
    required this.terms,
    this.wantsExpiry = false,
    this.categoryHint,
    this.fieldHint,
    this.personRelation,
    this.timeScope,
  });

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
    'documents', 'document', 'docs', 'doc',
  };

  /// Words that belong to a time window, stripped so they aren't searched
  /// literally ("expiring next month" shouldn't try to match "next").
  static const _timeWords = {
    'next', 'this', 'last', 'month', 'year', 'soon', 'today', 'tomorrow',
    'expired', 'added', 'uploaded', 'scanned', 'saved',
  };

  /// Parses a raw search string into a [QueryIntent].
  static QueryIntent parse(String rawQuery) {
    var query = rawQuery.trim().toLowerCase();
    query = query.replaceAll(RegExp(r'[?!.]+$'), '').trim();

    final fieldHint = VaultLexicon.factKeyInQuery(query);
    final timeScope = _parseTimeScope(query);

    RelationshipType? personRelation;

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
      final base = term.replaceAll(RegExp(r"'s$|s'$"), '');
      final rel = VaultLexicon.relationFor(base);
      if (rel != null && personRelation == null) {
        personRelation = rel;
        continue; // it's a scope, not a search term
      }
      if (_expiryWords.contains(term)) {
        wantsExpiry = true;
        continue;
      }
      if (_timeWords.contains(term)) continue;
      if (_stopWords.contains(term) || term.length <= 1) continue;
      terms.add(term);
    }

    DocumentCategory? categoryHint;
    for (final term in terms) {
      final cat = VaultLexicon.categoryFor(term);
      if (cat != null) {
        categoryHint = cat;
        break;
      }
    }

    final effectiveExpiry = wantsExpiry || timeScope?.onExpiry == true;
    // If nothing meaningful survived and there's no other intent, fall back to
    // the raw words so a query that's all noise still searches something.
    final noSignal = terms.isEmpty &&
        timeScope == null &&
        personRelation == null &&
        !effectiveExpiry &&
        categoryHint == null;

    return QueryIntent(
      terms: noSignal ? rawTerms : terms,
      wantsExpiry: effectiveExpiry,
      categoryHint: categoryHint,
      fieldHint: fieldHint,
      personRelation: personRelation,
      timeScope: timeScope,
    );
  }

  /// Detects relative time windows: "expired", "expiring soon", "next month",
  /// "this month/year", "last month/year", "added this year".
  static TimeScope? _parseTimeScope(String query) {
    final now = DateTime.now();
    final onExpiry = !RegExp(r'\b(added|uploaded|scanned|saved)\b').hasMatch(query);

    if (RegExp(r'\bexpired\b').hasMatch(query)) {
      return const TimeScope(expiredOnly: true, onExpiry: true);
    }
    if (RegExp(r'\bexpir(e|es|ing|y)\b').hasMatch(query) &&
        RegExp(r'\bsoon\b').hasMatch(query)) {
      return TimeScope(from: now, to: now.add(const Duration(days: 90)));
    }
    if (RegExp(r'\bnext month\b').hasMatch(query)) {
      final start = DateTime(now.year, now.month + 1, 1);
      final end = DateTime(now.year, now.month + 2, 0, 23, 59, 59);
      return TimeScope(from: start, to: end, onExpiry: onExpiry);
    }
    if (RegExp(r'\bthis month\b').hasMatch(query)) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return TimeScope(from: start, to: end, onExpiry: onExpiry);
    }
    if (RegExp(r'\blast month\b').hasMatch(query)) {
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return TimeScope(from: start, to: end, onExpiry: false);
    }
    if (RegExp(r'\bthis year\b').hasMatch(query)) {
      return TimeScope(
        from: DateTime(now.year),
        to: DateTime(now.year, 12, 31, 23, 59, 59),
        onExpiry: onExpiry,
      );
    }
    if (RegExp(r'\blast year\b').hasMatch(query)) {
      return TimeScope(
        from: DateTime(now.year - 1),
        to: DateTime(now.year - 1, 12, 31, 23, 59, 59),
        onExpiry: false,
      );
    }
    // Bare "expiring"/"expiring documents" with no window → next 90 days.
    if (RegExp(r'\bexpir(ing|es|e|y)\b').hasMatch(query)) {
      return TimeScope(from: now, to: now.add(const Duration(days: 90)));
    }
    return null;
  }
}
