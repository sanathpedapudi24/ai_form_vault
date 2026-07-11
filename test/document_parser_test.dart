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

  group('DocumentParser — date of birth accuracy', () {
    test('picks the date near "Date of Birth" over an earlier unrelated date', () {
      final result = parser.parse('''
        UIDAI
        Issue Date: 01/01/2020
        Name: Ravi Kumar Sharma
        Date of Birth
        15/08/1995
        Male
      ''');
      final dob = result.fields.firstWhere(
        (f) => f.label == 'Date of Birth',
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(dob.value, '15/08/1995');
    });

    test('rejects an impossible date (month 13) rather than accepting it', () {
      final result = parser.parse('''
        UIDAI
        Date of Birth: 31/13/1995
        Name: Ravi Kumar
      ''');
      final dob = result.fields.firstWhere(
        (f) => f.label == 'Date of Birth',
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      // No plausible date anywhere in the text — must not fabricate one.
      expect(dob.value, isEmpty);
    });
  });

  group('DocumentParser — address, care-of, and state', () {
    test('captures a multi-line address up to the PIN code', () {
      final result = parser.parse('''
        UIDAI
        Name: Ravi Kumar Sharma
        Address:
        S/O Suresh Kumar Sharma
        12 MG Road, Indiranagar
        Bengaluru, Karnataka - 560038
      ''');
      final address = result.fields.firstWhere(
        (f) => f.label == 'Address',
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(address.value, contains('MG Road'));
      expect(address.value, contains('Bengaluru'));
    });

    test('extracts Care Of from S/O', () {
      final result = parser.parse('''
        UIDAI
        Name: Ravi Kumar Sharma
        S/O: Suresh Kumar Sharma
        Address: 12 MG Road
      ''');
      final careOf = result.fields.firstWhere(
        (f) => f.label == 'Care Of',
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(careOf.value, contains('Suresh'));
    });

    test('extracts a known Indian state', () {
      final result = parser.parse('''
        UIDAI
        Address: 12 MG Road, Bengaluru, Karnataka - 560038
      ''');
      final state = result.fields.firstWhere(
        (f) => f.label == 'State',
        orElse: () => const ExtractedField(label: '', value: ''),
      );
      expect(state.value, 'Karnataka');
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
