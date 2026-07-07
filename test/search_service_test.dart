import 'package:flutter_test/flutter_test.dart';
import 'package:ai_form_vault/core/models/document_model.dart';
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
}
