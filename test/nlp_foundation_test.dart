import 'package:flutter_test/flutter_test.dart';

import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/models/person_model.dart';
import 'package:ai_form_vault/core/services/text_similarity.dart';
import 'package:ai_form_vault/core/services/vault_lexicon.dart';

void main() {
  group('TextSimilarity', () {
    test('dice is 1 for identical, 0 for empty', () {
      expect(TextSimilarity.diceCoefficient('aadhaar', 'aadhaar'), 1.0);
      expect(TextSimilarity.diceCoefficient('', 'x'), 0.0);
    });

    test('tolerates a single-letter typo', () {
      expect(
        TextSimilarity.diceCoefficient('adhaar', 'aadhaar'),
        greaterThan(0.7),
      );
    });

    test('fuzzyContains matches a misspelled word', () {
      expect(TextSimilarity.fuzzyContains('my aadhaar card', 'adhaar'), isTrue);
      expect(TextSimilarity.fuzzyContains('passport document', 'pan'), isFalse);
    });

    test('fuzzyContains requires exact match for very short terms', () {
      // "pan" (3 chars) must appear literally, not fuzzily.
      expect(TextSimilarity.fuzzyContains('pan card', 'pan'), isTrue);
      expect(TextSimilarity.fuzzyContains('van card', 'pan'), isFalse);
    });
  });

  group('VaultLexicon', () {
    test('maps everyday words to canonical fact keys', () {
      expect(VaultLexicon.factKeyFor('uid'), FactKeys.aadhaarNumber);
      expect(VaultLexicon.factKeyFor('licence'), FactKeys.drivingLicense);
      expect(VaultLexicon.factKeyFor('birthday'), FactKeys.dob);
      expect(VaultLexicon.factKeyFor('tax'), isNull); // 'tax' is a category word
    });

    test('finds the longest fact phrase in a full query', () {
      expect(
        VaultLexicon.factKeyInQuery('what is my date of birth'),
        FactKeys.dob,
      );
      // 'number' is no longer a phone alias, so "pan number" resolves to PAN.
      expect(
        VaultLexicon.factKeyInQuery('show my pan number'),
        FactKeys.panNumber,
      );
    });

    test('maps generic words to categories and relations', () {
      expect(VaultLexicon.categoryFor('id'), DocumentCategory.identity);
      expect(VaultLexicon.categoryFor('bank'), DocumentCategory.finance);
      // Specific doc types are NOT category words (they match documents).
      expect(VaultLexicon.categoryFor('passport'), isNull);
      expect(VaultLexicon.relationFor('wife'), RelationshipType.spouse);
      expect(VaultLexicon.relationFor('dad'), RelationshipType.father);
    });

    test('expands a term to its concept aliases', () {
      final aliases = VaultLexicon.expand('uid');
      expect(aliases, contains('aadhaar'));
      expect(aliases, contains('uidai'));
    });
  });
}
