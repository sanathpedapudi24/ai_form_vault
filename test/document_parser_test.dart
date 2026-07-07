import 'package:flutter_test/flutter_test.dart';
import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/services/document_intelligence.dart';
import 'package:ai_form_vault/core/services/document_parser.dart';

void main() {
  final parser = DocumentParser();

  group('DocumentParser — category detection', () {
    test('detects Aadhaar from UIDAI markers', () {
      final result = parser.parse('''
        Government of India
        UIDAI
        Name: Priya Sharma
        DOB: 12/08/1998
        1234 5678 9012
      ''');
      expect(result.category, DocumentCategory.identity);
    });

    test('detects PAN from Income Tax markers', () {
      final result = parser.parse('''
        INCOME TAX DEPARTMENT
        Permanent Account Number Card
        ABCDE1234F
      ''');
      expect(result.category, DocumentCategory.identity);
    });

    test('falls back to other for unrecognized text', () {
      final result = parser.parse('Just some random shopping list text');
      expect(result.category, DocumentCategory.other);
    });
  });

  group('DocumentParser — field extraction', () {
    test('extracts Aadhaar number with spaces preserved', () {
      final result = parser.parse('''
        UIDAI
        Name: Ravi Kumar
        2345 6789 0123
      ''');
      final field = result.fields.firstWhere(
        (f) => f.label.toLowerCase().contains('aadhaar'),
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(field.value, contains('2345'));
    });

    test('extracts PAN number in correct format', () {
      final result = parser.parse('''
        INCOME TAX DEPARTMENT
        Permanent Account Number
        Name: Ravi Kumar
        ABCDE1234F
      ''');
      final field = result.fields.firstWhere(
        (f) => f.label.toLowerCase().contains('pan'),
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(field.value, 'ABCDE1234F');
    });

    test('produces empty fields for unparseable text without crashing', () {
      final result = parser.parse('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });
  });

  group('DocumentIntelligence.semanticKeyForLabel', () {
    test('maps common labels to canonical fact keys', () {
      expect(
        DocumentIntelligence.semanticKeyForLabel('Aadhaar Number'),
        FactKeys.aadhaarNumber,
      );
      expect(
        DocumentIntelligence.semanticKeyForLabel('PAN Number'),
        FactKeys.panNumber,
      );
      expect(
        DocumentIntelligence.semanticKeyForLabel("Father's Name"),
        FactKeys.fatherName,
      );
      expect(
        DocumentIntelligence.semanticKeyForLabel('Full Name'),
        FactKeys.fullName,
      );
      expect(DocumentIntelligence.semanticKeyForLabel('Unknown Thing'), '');
    });
  });
}
