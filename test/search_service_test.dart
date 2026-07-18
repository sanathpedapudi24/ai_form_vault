import 'package:flutter_test/flutter_test.dart';
import 'package:ai_form_vault/core/models/document_model.dart';
import 'package:ai_form_vault/core/models/person_model.dart';
import 'package:ai_form_vault/core/services/search_service.dart';

DocumentModel _doc({
  required String id,
  required String name,
  DocumentCategory category = DocumentCategory.identity,
  String ownerName = '',
  List<ExtractedField> fields = const [],
  String summary = '',
}) {
  return DocumentModel(
    id: id,
    name: name,
    ownerName: ownerName,
    category: category,
    type: name,
    detectedType: name,
    uploadDate: DateTime(2026, 1, 1),
    extractedFields: fields,
    summary: summary,
  );
}

void main() {
  // SearchService has no Gemini/network dependency in its keyword path when
  // constructed with a client whose isConfigured is false (no API key) —
  // embedQuery short-circuits to null and only keyword matching runs.
  final service = SearchService();

  group('SearchService — keyword fallback (no AI key)', () {
    test('matches by document type', () async {
      final docs = [
        _doc(id: '1', name: 'Passport'),
        _doc(id: '2', name: 'Aadhaar Card'),
      ];
      final results = await service.search('passport', docs);
      expect(results, hasLength(1));
      expect(results.first.document.id, '1');
    });

    test('matches by owner name', () async {
      final docs = [
        _doc(id: '1', name: 'PAN Card', ownerName: 'Charan Sai'),
        _doc(id: '2', name: 'PAN Card', ownerName: 'Priya Sharma'),
      ];
      final results = await service.search('priya', docs);
      expect(results, hasLength(1));
      expect(results.first.document.id, '2');
    });

    test('matches by extracted field value', () async {
      final docs = [
        _doc(
          id: '1',
          name: 'Marksheet',
          category: DocumentCategory.education,
          fields: const [
            ExtractedField(label: 'Institution', value: 'Delhi University'),
          ],
        ),
        _doc(id: '2', name: 'Passport'),
      ];
      final results = await service.search('delhi university', docs);
      expect(results, hasLength(1));
      expect(results.first.document.id, '1');
      expect(results.first.matchedLabel, 'Institution');
    });

    test('returns empty list for blank query', () async {
      final docs = [_doc(id: '1', name: 'Passport')];
      final results = await service.search('   ', docs);
      expect(results, isEmpty);
    });

    test('returns empty list when nothing matches', () async {
      final docs = [_doc(id: '1', name: 'Passport')];
      final results = await service.search('xyzzy', docs);
      expect(results, isEmpty);
    });

    test('ranks a title match above a raw-text-only match', () async {
      final docs = [
        _doc(id: '1', name: 'Random Document', summary: 'mentions insurance briefly'),
        _doc(id: '2', name: 'Insurance Policy'),
      ];
      final results = await service.search('insurance', docs);
      expect(results.first.document.id, '2');
    });
  });

  group('SearchService — natural-language phrasing', () {
    test('"find my X" matches the same as the bare keyword', () async {
      final docs = [_doc(id: '1', name: 'Passport')];
      final results = await service.search('find my passport', docs);
      expect(results, hasLength(1));
      expect(results.first.document.id, '1');
    });

    test('a category synonym surfaces a document with no literal match', () async {
      final docs = [
        _doc(id: '1', name: 'Aadhaar Card', category: DocumentCategory.identity),
        _doc(id: '2', name: 'Marksheet', category: DocumentCategory.education),
      ];
      final results = await service.search('show me my ID', docs);
      expect(results, isNotEmpty);
      expect(results.first.document.id, '1');
    });

    test('expiry question surfaces a document with an expiry field', () async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final formatted =
          '${futureDate.day.toString().padLeft(2, '0')}/'
          '${futureDate.month.toString().padLeft(2, '0')}/${futureDate.year}';
      final docs = [
        _doc(
          id: '1',
          name: 'Passport',
          fields: [ExtractedField(label: 'Expiry Date', value: formatted, semanticKey: FactKeys.expiryDate)],
        ),
        _doc(id: '2', name: 'Aadhaar Card'),
      ];
      final results = await service.search('when does my passport expire', docs);
      expect(results, isNotEmpty);
      expect(results.first.document.id, '1');
    });
  });

  group('SearchService — fuzzy + synonym + scopes', () {
    test('tolerates a typo in the query', () async {
      final docs = [
        _doc(id: '1', name: 'Aadhaar Card'),
        _doc(id: '2', name: 'Passport'),
      ];
      final results = await service.search('adhaar', docs); // misspelled
      expect(results.first.document.id, '1');
    });

    test('a synonym matches the underlying document', () async {
      final docs = [
        _doc(
          id: '1',
          name: 'Aadhaar Card',
          fields: const [
            ExtractedField(label: 'Aadhaar Number', value: '1234 5678 9012'),
          ],
        ),
        _doc(id: '2', name: 'Passport'),
      ];
      final results = await service.search('uid', docs); // uid → aadhaar
      expect(results.first.document.id, '1');
    });

    test('person scope filters to the related person\'s documents', () async {
      final now = DateTime(2026, 1, 1);
      final user = Person(id: 'u', displayName: 'You', isUser: true, createdAt: now);
      final wife = Person(id: 'w', displayName: 'Priya', createdAt: now);
      final rel = Relationship(
        id: 'r',
        fromPersonId: 'w',
        toPersonId: 'u',
        type: RelationshipType.spouse,
        status: RelationshipStatus.confirmed,
        createdAt: now,
      );
      final docs = [
        DocumentModel(
          id: 'd1', name: 'Passport', ownerName: 'You', personId: 'u',
          category: DocumentCategory.travel, type: 'Passport',
          detectedType: 'Passport', uploadDate: now,
        ),
        DocumentModel(
          id: 'd2', name: 'Passport', ownerName: 'Priya', personId: 'w',
          category: DocumentCategory.travel, type: 'Passport',
          detectedType: 'Passport', uploadDate: now,
        ),
      ];
      final results = await service.search(
        "my wife's passport",
        docs,
        persons: [user, wife],
        rels: [rel],
      );
      expect(results, hasLength(1));
      expect(results.first.document.id, 'd2');
    });
  });
}
