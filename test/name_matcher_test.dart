import 'package:flutter_test/flutter_test.dart';
import 'package:ai_form_vault/core/services/name_matcher.dart';

void main() {
  group('NameMatcher — should merge (same person)', () {
    test('case and whitespace differences', () {
      expect(
        NameMatcher.isSameName('Ravi Kumar Sharma', 'ravi  kumar sharma'),
        isTrue,
      );
    });

    test('honorific added or dropped', () {
      expect(
        NameMatcher.isSameName('Mr. Ravi Kumar Sharma', 'Ravi Kumar Sharma'),
        isTrue,
      );
      expect(
        NameMatcher.isSameName('Shri Suresh Sharma', 'Suresh Sharma'),
        isTrue,
      );
    });

    test('reordered words', () {
      expect(
        NameMatcher.isSameName('Sharma Ravi Kumar', 'Ravi Kumar Sharma'),
        isTrue,
      );
    });

    test('single-letter OCR misread', () {
      expect(
        NameMatcher.isSameName('Ravi Kumar Sarma', 'Ravi Kumar Sharma'),
        isTrue,
      );
    });

    test('missing middle name is still a strong match', () {
      expect(
        NameMatcher.isSameName('Ravi Sharma', 'Ravi Kumar Sharma'),
        isTrue,
      );
    });
  });

  group('NameMatcher — should NOT merge (different people)', () {
    test('different people entirely', () {
      expect(
        NameMatcher.isSameName('Ravi Kumar Sharma', 'Priya Singh Mehta'),
        isFalse,
      );
    });

    test('same surname, different first name', () {
      expect(
        NameMatcher.isSameName('Ravi Sharma', 'Suresh Sharma'),
        isFalse,
      );
    });

    test('bare common first name alone requires near-exact match', () {
      expect(NameMatcher.isSameName('Ravi', 'Ravindra'), isFalse);
      expect(NameMatcher.isSameName('Ravi', 'Ravi'), isTrue);
    });

    test('empty or blank names never match', () {
      expect(NameMatcher.isSameName('', 'Ravi Sharma'), isFalse);
      expect(NameMatcher.isSameName('   ', 'Ravi Sharma'), isFalse);
    });
  });
}
