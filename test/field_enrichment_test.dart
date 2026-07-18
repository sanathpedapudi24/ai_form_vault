import 'package:flutter_test/flutter_test.dart';

import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/services/field_enrichment.dart';

void main() {
  group('FieldEnrichment.normalizeValue', () {
    test('title-cases names', () {
      expect(
        FieldEnrichment.normalizeValue(FactKeys.fullName, 'RAVI kumar SHARMA'),
        'Ravi Kumar Sharma',
      );
    });

    test('normalizes phone: strips +91 / spaces / leading zero', () {
      expect(
        FieldEnrichment.normalizeValue(FactKeys.phone, '+91 98765 43210'),
        '9876543210',
      );
      expect(
        FieldEnrichment.normalizeValue(FactKeys.phone, '098765 43210'),
        '9876543210',
      );
    });

    test('canonicalizes dates to dd/MM/yyyy', () {
      expect(
        FieldEnrichment.normalizeValue(FactKeys.dob, '1998-08-12'),
        '12/08/1998',
      );
      expect(
        FieldEnrichment.normalizeValue(FactKeys.expiryDate, '5/3/2030'),
        '05/03/2030',
      );
    });

    test('upper-cases PAN and formats Aadhaar', () {
      expect(
        FieldEnrichment.normalizeValue(FactKeys.panNumber, 'abcde1234f'),
        'ABCDE1234F',
      );
      expect(
        FieldEnrichment.normalizeValue(FactKeys.aadhaarNumber, '123456789012'),
        '1234 5678 9012',
      );
    });
  });

  group('FieldEnrichment.enrich', () {
    test('fills a missing phone from entities', () {
      final fields = [
        const ExtractedField(
          label: 'Full Name',
          value: 'ravi kumar',
          semanticKey: FactKeys.fullName,
        ),
      ];
      final out = FieldEnrichment.enrich(
        fields,
        const ExtractedEntities(phones: ['+91 98765 43210']),
      );
      final phone = out.firstWhere((f) => f.semanticKey == FactKeys.phone);
      expect(phone.value, '9876543210');
      // Existing name field was normalized in passing.
      expect(
        out.firstWhere((f) => f.semanticKey == FactKeys.fullName).value,
        'Ravi Kumar',
      );
    });

    test('does not overwrite a phone the parser already found', () {
      final fields = [
        const ExtractedField(
          label: 'Phone Number',
          value: '9999999999',
          semanticKey: FactKeys.phone,
        ),
      ];
      final out = FieldEnrichment.enrich(
        fields,
        const ExtractedEntities(phones: ['8888888888']),
      );
      final phones = out.where((f) => f.semanticKey == FactKeys.phone).toList();
      expect(phones, hasLength(1));
      expect(phones.first.value, '9999999999');
    });
  });
}
