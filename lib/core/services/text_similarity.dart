/// Small, dependency-free text-similarity helpers shared across the on-device
/// intelligence layer (fuzzy search, name matching, Q&A term resolution).
///
/// Everything here is character/token math — no models, no network — so it
/// stays fast and keeps the privacy guarantee (nothing leaves the device).
class TextSimilarity {
  TextSimilarity._();

  /// Character-bigram set of [s] (spaces removed). Single-char strings map to
  /// themselves so short tokens still compare.
  static Set<String> bigrams(String s) {
    final t = s.replaceAll(' ', '');
    if (t.length < 2) return {t};
    return {for (var i = 0; i < t.length - 1; i++) t.substring(i, i + 2)};
  }

  /// Sørensen–Dice coefficient over character bigrams, in [0, 1]. Tolerant of
  /// single-letter OCR/typo differences ("adhaar" vs "aadhaar") without the
  /// cost of full edit distance.
  static double diceCoefficient(String a, String b) {
    final an = a.toLowerCase();
    final bn = b.toLowerCase();
    if (an.isEmpty || bn.isEmpty) return 0;
    if (an == bn) return 1;
    final ba = bigrams(an);
    final bb = bigrams(bn);
    if (ba.isEmpty || bb.isEmpty) return 0;
    final shared = ba.intersection(bb).length;
    return (2 * shared) / (ba.length + bb.length);
  }

  /// True if [term] appears in [haystack] either literally or as a close
  /// fuzzy match of one of its words. [threshold] is the minimum Dice score
  /// for a fuzzy word hit. Short terms (≤3 chars) require an exact word match —
  /// fuzzy matching tiny tokens produces too many false positives.
  static bool fuzzyContains(
    String haystack,
    String term, {
    double threshold = 0.82,
  }) {
    final h = haystack.toLowerCase();
    final t = term.toLowerCase().trim();
    if (t.isEmpty) return false;
    if (h.contains(t)) return true;
    if (t.length <= 3) return false;

    for (final word in h.split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length < 3) continue;
      if (diceCoefficient(word, t) >= threshold) return true;
    }
    return false;
  }

  /// Best Dice score between [term] and any word in [haystack] (0 if none).
  /// Used for ranking rather than a boolean gate.
  static double bestWordScore(String haystack, String term) {
    final h = haystack.toLowerCase();
    final t = term.toLowerCase().trim();
    if (t.isEmpty) return 0;
    if (h.contains(t)) return 1;
    var best = 0.0;
    for (final word in h.split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length < 3) continue;
      final s = diceCoefficient(word, t);
      if (s > best) best = s;
    }
    return best;
  }
}
