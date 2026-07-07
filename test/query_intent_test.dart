import 'package:flutter_test/flutter_test.dart';
import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/services/query_intent.dart';

void main() {
  group('NaturalLanguageQuery.parse', () {
    test('strips "find my" phrasing', () {
      final intent = NaturalLanguageQuery.parse('Find my passport');
      expect(intent.terms, ['passport']);
    });

    test('detects expiry intent and removes it from terms', () {
      final intent = NaturalLanguageQuery.parse('When does my passport expire?');
      expect(intent.wantsExpiry, isTrue);
      expect(intent.terms, contains('passport'));
      expect(intent.terms, isNot(contains('expire')));
    });

    test('maps a category synonym', () {
      final intent = NaturalLanguageQuery.parse('find my ID');
      expect(intent.categoryHint, DocumentCategory.identity);
    });

    test('maps "bank documents" to finance', () {
      final intent = NaturalLanguageQuery.parse('bank documents');
      expect(intent.categoryHint, DocumentCategory.finance);
    });

    test('plain keyword queries still work with no phrasing to strip', () {
      final intent = NaturalLanguageQuery.parse('roll number 12345');
      expect(intent.terms, ['roll', 'number', '12345']);
      expect(intent.wantsExpiry, isFalse);
      expect(intent.categoryHint, isNull);
    });

    test('specific document-type words do not hint a category', () {
      // "passport" already matches its document literally by type/name —
      // if it also hinted the identity category, it would spuriously pull
      // in every unrelated identity document (Aadhaar, PAN, Voter ID).
      final intent = NaturalLanguageQuery.parse('passport');
      expect(intent.categoryHint, isNull);
    });

    test('falls back to raw terms when everything would otherwise be stripped', () {
      final intent = NaturalLanguageQuery.parse('is');
      expect(intent.terms, isNotEmpty);
    });
  });
}
