import 'package:flutter_test/flutter_test.dart';

import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/models/person_model.dart';
import 'package:ai_form_vault/core/services/ask_engine.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final user = Person(id: 'u', displayName: 'You', isUser: true, createdAt: now);
  final father = Person(id: 'f', displayName: 'Ramesh Kumar', createdAt: now);
  final fatherOfUser = Relationship(
    id: 'r1',
    fromPersonId: 'f',
    toPersonId: 'u',
    type: RelationshipType.father,
    status: RelationshipStatus.confirmed,
    createdAt: now,
  );

  group('AskEngine.planFor', () {
    test('self fact question resolves to the user', () {
      final plan = AskEngine.planFor("what's my pan number", [user], []);
      expect(plan, isNotNull);
      expect(plan!.factKey, FactKeys.panNumber);
      expect(plan.personId, 'u');
      expect(plan.personLabel, 'your');
      expect(plan.wantsExpiry, isFalse);
    });

    test("relation-scoped fact resolves to the related person", () {
      final plan = AskEngine.planFor(
        "my father's aadhaar",
        [user, father],
        [fatherOfUser],
      );
      expect(plan, isNotNull);
      expect(plan!.factKey, FactKeys.aadhaarNumber);
      expect(plan.personId, 'f');
      expect(plan.personLabel, "your father's");
    });

    test("relation's name maps to the owner's relation-name fact", () {
      final plan = AskEngine.planFor(
        "what is my father's name",
        [user, father],
        [fatherOfUser],
      );
      expect(plan!.factKey, FactKeys.fatherName);
      expect(plan.personId, 'u');
    });

    test('expiry question is flagged', () {
      final plan = AskEngine.planFor('when does my passport expire', [user], []);
      expect(plan!.wantsExpiry, isTrue);
      expect(plan.factKey, FactKeys.expiryDate);
    });

    test('a bare keyword is not treated as a question', () {
      expect(AskEngine.planFor('aadhaar', [user], []), isNull);
      expect(AskEngine.planFor('pan card', [user], []), isNull);
    });
  });

  group('AskResult masking', () {
    test('masks all but the last four alphanumerics, keeping separators', () {
      const pan = AskResult(answer: '', value: 'ABCDE1234F', isSensitive: true);
      expect(pan.maskedValue, '••••••234F');

      const aadhaar =
          AskResult(answer: '', value: '1234 5678 9012', isSensitive: true);
      expect(aadhaar.maskedValue, '•••• •••• 9012');
    });
  });
}
