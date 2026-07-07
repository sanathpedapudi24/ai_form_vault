/// Decides whether two extracted names likely refer to the same person.
///
/// Document OCR/AI extraction of the same real person rarely produces
/// byte-identical strings across documents — honorifics get added or
/// dropped ("Mr. Ravi Sharma" vs "Ravi Sharma"), OCR mangles a letter
/// ("Sarma" vs "Sharma"), word order shifts ("Sharma Ravi Kumar" vs "Ravi
/// Kumar Sharma"), or a middle name is missing on one document. Exact-match
/// normalization alone creates a duplicate [Person] for every one of these
/// — this combines token overlap (handles reordering/missing words) with
/// character-bigram similarity (handles typos) so near-duplicates collapse
/// into one person instead of multiplying.
class NameMatcher {
  NameMatcher._();

  static const _honorifics = {
    'mr',
    'mrs',
    'ms',
    'miss',
    'dr',
    'shri',
    'sri',
    'smt',
    'kumari',
    'master',
    'mx',
  };

  /// Lowercase, strip punctuation, drop honorifics, collapse whitespace.
  static String normalize(String name) {
    final stripped = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_honorifics.contains(w))
        .join(' ');
    return stripped.trim();
  }

  static List<String> _tokens(String normalized) =>
      normalized.split(' ').where((w) => w.isNotEmpty).toList();

  /// Similarity in [0, 1] — 1 means "certainly the same name".
  static double similarity(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA.isEmpty || normB.isEmpty) return 0;
    if (normA == normB) return 1;

    final tokensA = _tokens(normA);
    final tokensB = _tokens(normB);

    // A missing middle name ("Ravi Sharma" vs "Ravi Kumar Sharma") drags
    // Jaccard down purely from the length difference even though every
    // word that IS present agrees — treat clean containment as a strong
    // match on its own rather than penalizing it for being shorter.
    final setA = tokensA.toSet();
    final setB = tokensB.toSet();
    final smaller = setA.length <= setB.length ? setA : setB;
    final larger = setA.length <= setB.length ? setB : setA;
    if (smaller.length >= 2 && smaller.every(larger.contains)) {
      return 0.9;
    }

    final tokenScore = _tokenJaccard(tokensA, tokensB);
    final charScore = _bigramDice(normA, normB);
    return tokenScore > charScore ? tokenScore : charScore;
  }

  /// Whether [a] and [b] should be treated as the same person.
  ///
  /// Single-word names (just "Ravi", no surname) need near-exact agreement
  /// before merging — a common first name alone is too weak a signal and
  /// merging on it risks conflating two different people.
  static bool isSameName(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;

    final singleWord =
        _tokens(normA).length == 1 || _tokens(normB).length == 1;
    final threshold = singleWord ? 0.92 : 0.82;
    return similarity(a, b) >= threshold;
  }

  static double _tokenJaccard(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  static Set<String> _bigrams(String s) {
    if (s.length < 2) return {s};
    return {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
  }

  /// Dice coefficient over character bigrams — tolerant of single-letter
  /// OCR misreads ("Sarma" vs "Sharma") without needing full edit distance.
  static double _bigramDice(String a, String b) {
    final bigramsA = _bigrams(a.replaceAll(' ', ''));
    final bigramsB = _bigrams(b.replaceAll(' ', ''));
    if (bigramsA.isEmpty || bigramsB.isEmpty) return 0;
    final shared = bigramsA.intersection(bigramsB).length;
    return (2 * shared) / (bigramsA.length + bigramsB.length);
  }
}
