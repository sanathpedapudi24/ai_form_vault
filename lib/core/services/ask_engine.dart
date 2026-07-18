import 'package:collection/collection.dart';

import '../models/document_model.dart';
import '../models/person_model.dart';
import '../repositories/person_repository.dart';
import 'search_service.dart';
import 'text_similarity.dart';
import 'vault_lexicon.dart';

/// A direct answer to a natural-language question about the vault.
class AskResult {
  /// One-sentence human answer, e.g. "Your PAN is ABCDE1234F."
  final String answer;

  /// The raw value (unmasked). May be empty for a not-found answer.
  final String value;

  final String factKey;
  final String personName;
  final String? sourceDocumentId;
  final double confidence;

  /// True when [value] is a government ID that should be masked until tapped.
  final bool isSensitive;

  /// True when the question was understood but no value exists yet.
  final bool notFound;

  const AskResult({
    required this.answer,
    this.value = '',
    this.factKey = '',
    this.personName = '',
    this.sourceDocumentId,
    this.confidence = 0,
    this.isSensitive = false,
    this.notFound = false,
  });

  /// Value with every alphanumeric masked except the last four, keeping
  /// separators intact (e.g. "1234 5678 9012" → "•••• •••• 9012").
  String get maskedValue {
    final alnum = RegExp(r'[A-Za-z0-9]');
    // Index of the 4th alphanumeric counting from the end.
    var seen = 0;
    var revealFrom = 0;
    for (var i = value.length - 1; i >= 0; i--) {
      if (alnum.hasMatch(value[i])) {
        seen++;
        if (seen == 4) {
          revealFrom = i;
          break;
        }
      }
    }
    final buf = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final c = value[i];
      buf.write(i >= revealFrom || !alnum.hasMatch(c) ? c : '•');
    }
    return buf.toString();
  }
}

/// Answers factual questions about the vault entirely on-device by resolving
/// the query to a (person, fact) and reading the aggregated identity graph —
/// no model, no network. Returns null when the query isn't a question this
/// engine can answer (the caller then falls back to normal search).
class AskEngine {
  AskEngine({PersonRepository? persons})
    : _persons = persons ?? const PersonRepository();

  final PersonRepository _persons;

  static const _questionWords = {
    'what', "what's", 'whats', 'when', 'where', 'who', "who's", 'whose',
    'which', 'how', 'is', 'do', 'does',
  };

  Future<AskResult?> ask(String rawQuery, List<DocumentModel> docs) async {
    final query = rawQuery.trim().toLowerCase().replaceAll(
      RegExp(r'[?!.]+$'),
      '',
    );
    if (query.isEmpty) return null;

    final persons = await _persons.getAllPersons();
    final rels = await _persons.getRelationships();

    final plan = planFor(query, persons, rels);
    if (plan == null) return null;

    if (plan.wantsExpiry) return _answerExpiry(query, docs);

    final person = persons.firstWhereOrNull((p) => p.id == plan.personId);
    if (person == null) return null;

    final factKey = plan.factKey;
    final personLabel = plan.personLabel;
    final resolved = await _lookupValue(person.id, factKey, docs);
    final label = FactKeys.labelFor(factKey).toLowerCase();
    final sensitive = FactKeys.sensitive.contains(factKey);

    if (resolved == null || resolved.value.trim().isEmpty) {
      return AskResult(
        answer: "I couldn't find $personLabel $label saved yet.",
        factKey: factKey,
        personName: person.displayName,
        notFound: true,
      );
    }

    return AskResult(
      answer: _capitalize('$personLabel $label is ${resolved.value}.'),
      value: resolved.value,
      factKey: factKey,
      personName: person.displayName,
      sourceDocumentId: resolved.sourceDocId,
      confidence: resolved.confidence,
      isSensitive: sensitive,
    );
  }

  /// Pure query-understanding step: decides whether this is an answerable
  /// question and, if so, which person + fact key it targets. No DB, no I/O —
  /// so it can be unit-tested with in-memory people/relationships.
  static AskPlan? planFor(
    String rawQuery,
    List<Person> persons,
    List<Relationship> rels,
  ) {
    final query = rawQuery.trim().toLowerCase().replaceAll(
      RegExp(r'[?!.]+$'),
      '',
    );
    if (query.isEmpty) return null;

    final tokens = query.split(RegExp(r'\s+'));
    final hasQuestionWord = tokens.any(_questionWords.contains);
    final hasSelfWord = tokens.any(VaultLexicon.selfWords.contains);
    final hasPossessive = query.contains("'s") || query.contains('s ');
    final wantsExpiry = _mentionsExpiry(query);

    final scope = _stripRelationStatic(query);
    final relation = scope.relation;
    final remainingFactKey = VaultLexicon.factKeyInQuery(scope.remaining);
    final fullFactKey = VaultLexicon.factKeyInQuery(query);

    final looksLikeQuestion =
        hasQuestionWord || hasSelfWord || hasPossessive || relation != null;
    if (!looksLikeQuestion) return null;
    if (fullFactKey == null && !wantsExpiry) return null;

    // Any "expire/valid" question is about a document's expiry date; a
    // doc-type word in the query (e.g. "passport") just says which document,
    // so it must not divert this into a personal-fact lookup.
    if (wantsExpiry) {
      return const AskPlan(
        factKey: FactKeys.expiryDate,
        personId: null,
        personLabel: 'your',
        wantsExpiry: true,
      );
    }

    final user = persons.firstWhereOrNull((p) => p.isUser);

    if (relation != null) {
      final nameFact = _relationNameFact(relation);
      if ((remainingFactKey == null || remainingFactKey == FactKeys.fullName) &&
          nameFact != null) {
        // "my father's name" → the owner's father-name fact on themselves.
        return AskPlan(
          factKey: nameFact,
          personId: user?.id,
          personLabel: 'your',
        );
      }
      final related = _relatedPersonStatic(relation, user, rels, persons);
      return AskPlan(
        factKey: remainingFactKey ?? FactKeys.fullName,
        personId: related?.id,
        personLabel: "your ${relation.label.toLowerCase()}'s",
      );
    }

    final named = _namedPersonStatic(query, persons);
    return AskPlan(
      factKey: fullFactKey!,
      personId: (named ?? user)?.id,
      personLabel: named != null ? "${named.displayName}'s" : 'your',
    );
  }

  // --- Expiry questions -------------------------------------------------------

  AskResult? _answerExpiry(String query, List<DocumentModel> docs) {
    // Find the document the question is about (e.g. "passport").
    final doc = _docForQuery(query, docs);
    if (doc == null) {
      return const AskResult(
        answer: "I couldn't tell which document you mean. Try naming it, "
            'like "passport" or "licence".',
        notFound: true,
      );
    }
    final field = doc.fieldByKey(FactKeys.expiryDate);
    if (field == null || field.value.trim().isEmpty) {
      return AskResult(
        answer: "I don't have an expiry date saved for your "
            '${doc.displayTitle}.',
        notFound: true,
      );
    }
    final date = SearchService.parseFlexibleDate(field.value);
    final title = doc.displayTitle;
    if (date == null) {
      return AskResult(
        answer: 'Your $title expires on ${field.value}.',
        value: field.value,
        factKey: FactKeys.expiryDate,
        sourceDocumentId: doc.id,
      );
    }
    final days = date.difference(DateTime.now()).inDays;
    final when = days < 0
        ? 'it expired ${-days} day${days == -1 ? '' : 's'} ago'
        : days == 0
        ? 'it expires today'
        : 'that\'s $days day${days == 1 ? '' : 's'} from now';
    return AskResult(
      answer: 'Your $title expires on ${field.value} — $when.',
      value: field.value,
      factKey: FactKeys.expiryDate,
      sourceDocumentId: doc.id,
    );
  }

  DocumentModel? _docForQuery(String query, List<DocumentModel> docs) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList();
    DocumentModel? best;
    var bestScore = 0.0;
    for (final doc in docs) {
      final hay = '${doc.detectedType} ${doc.type} ${doc.name} '
          '${doc.category.label}';
      var score = 0.0;
      for (final t in tokens) {
        score += TextSimilarity.bestWordScore(hay, t);
      }
      if (score > bestScore) {
        bestScore = score;
        best = doc;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }

  // --- Value lookup -----------------------------------------------------------

  Future<_Resolved?> _lookupValue(
    String personId,
    String factKey,
    List<DocumentModel> docs,
  ) async {
    final facts = await _persons.getFacts(personId);
    final fact = facts.firstWhereOrNull((f) => f.factKey == factKey);
    if (fact != null && fact.value.trim().isNotEmpty) {
      return _Resolved(fact.value, fact.sourceDocumentId, fact.confidence);
    }
    // Fallback: read straight from the person's documents.
    for (final doc in docs.where((d) => d.personId == personId)) {
      final field = doc.fieldByKey(factKey);
      if (field != null && field.value.trim().isNotEmpty) {
        return _Resolved(field.value, doc.id, field.confidence);
      }
    }
    return null;
  }

  // --- Person resolution (static: pure, used by planFor) ----------------------

  static Person? _relatedPersonStatic(
    RelationshipType relation,
    Person? user,
    List<Relationship> rels,
    List<Person> persons,
  ) {
    if (user == null) return null;
    Person? byId(String id) => persons.firstWhereOrNull((p) => p.id == id);

    // Canonical direction: "X is the [relation] of user" → from=X, to=user.
    final confirmed = rels.where(
      (r) => r.status == RelationshipStatus.confirmed,
    );
    final match =
        confirmed.firstWhereOrNull(
          (r) => r.type == relation && r.toPersonId == user.id,
        ) ??
        rels.firstWhereOrNull(
          (r) => r.type == relation && r.toPersonId == user.id,
        );
    return match == null ? null : byId(match.fromPersonId);
  }

  static Person? _namedPersonStatic(String query, List<Person> persons) {
    // Look for a token matching a non-user person's name.
    for (final p in persons) {
      if (p.isUser) continue;
      if (_queryMentionsName(query, p.displayName)) return p;
    }
    return null;
  }

  static String? _relationNameFact(RelationshipType r) => switch (r) {
    RelationshipType.father => FactKeys.fatherName,
    RelationshipType.mother => FactKeys.motherName,
    RelationshipType.spouse => FactKeys.spouseName,
    RelationshipType.guardian => FactKeys.guardianName,
    _ => null,
  };

  static _RelationScope _stripRelationStatic(String query) {
    final tokens = query.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length; i++) {
      final base = tokens[i].replaceAll(RegExp(r"'s$|s'$"), '');
      final rel = VaultLexicon.relationFor(base);
      if (rel != null) {
        final remaining = [...tokens]..removeAt(i);
        return _RelationScope(rel, remaining.join(' '));
      }
    }
    return _RelationScope(null, query);
  }

  static bool _mentionsExpiry(String query) => RegExp(
    r'\b(expire|expires|expiry|expiring|valid|validity)\b',
  ).hasMatch(query);

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// The resolved plan for a question: which fact of which person to fetch.
/// [personId] may be null when the target person can't be resolved (e.g. a
/// relation that isn't in the graph yet) — the caller returns a not-found.
class AskPlan {
  final String factKey;
  final String? personId;
  final String personLabel;
  final bool wantsExpiry;

  const AskPlan({
    required this.factKey,
    required this.personId,
    required this.personLabel,
    this.wantsExpiry = false,
  });
}

class _Resolved {
  final String value;
  final String? sourceDocId;
  final double confidence;
  const _Resolved(this.value, this.sourceDocId, this.confidence);
}

class _RelationScope {
  final RelationshipType? relation;
  final String remaining;
  const _RelationScope(this.relation, this.remaining);
}

/// Whether a query mentions a person's name (fuzzy, token-based).
bool _queryMentionsName(String query, String name) {
  final nameTokens = name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 3)
      .toList();
  if (nameTokens.isEmpty) return false;
  for (final nt in nameTokens) {
    if (TextSimilarity.fuzzyContains(query, nt)) return true;
  }
  return false;
}
