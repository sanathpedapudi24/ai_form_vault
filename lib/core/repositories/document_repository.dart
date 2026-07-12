import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/document_model.dart';

/// All persistence for documents and their extracted fields.
class DocumentRepository {
  const DocumentRepository();

  Future<List<DocumentModel>> getAll() async {
    final db = await AppDatabase.instance;
    final docRows = await db.query('documents', orderBy: 'upload_date DESC');
    if (docRows.isEmpty) return [];

    final fieldRows = await db.query('fields', orderBy: 'position ASC');
    final fieldsByDoc = <String, List<ExtractedField>>{};
    for (final row in fieldRows) {
      fieldsByDoc
          .putIfAbsent(row['document_id'] as String, () => [])
          .add(_fieldFromRow(row));
    }

    return docRows
        .map((row) => _docFromRow(row, fieldsByDoc[row['id']] ?? const []))
        .toList();
  }

  Future<DocumentModel?> getById(String id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final fields = await db.query(
      'fields',
      where: 'document_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return _docFromRow(rows.first, fields.map(_fieldFromRow).toList());
  }

  Future<void> insert(DocumentModel doc) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.insert(
        'documents',
        _docToRow(doc),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceFields(txn, doc);
    });
  }

  Future<void> update(DocumentModel doc) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.update(
        'documents',
        _docToRow(doc),
        where: 'id = ?',
        whereArgs: [doc.id],
      );
      await _replaceFields(txn, doc);
    });
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    // fields cascade via FK
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // --- Embeddings ---------------------------------------------------------

  Future<void> saveEmbedding(String documentId, List<double> embedding) async {
    final db = await AppDatabase.instance;
    final floats = Float32List.fromList(embedding);
    await db.update(
      'documents',
      {'embedding': floats.buffer.asUint8List()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Returns id → embedding for every document that has one.
  Future<Map<String, Float32List>> getAllEmbeddings() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'documents',
      columns: ['id', 'embedding'],
      where: 'embedding IS NOT NULL',
    );
    final result = <String, Float32List>{};
    for (final row in rows) {
      final blob = row['embedding'] as Uint8List?;
      if (blob == null || blob.isEmpty) continue;
      result[row['id'] as String] = blob.buffer.asFloat32List(
        blob.offsetInBytes,
        blob.lengthInBytes ~/ 4,
      );
    }
    return result;
  }

  /// Ids of documents that still need an embedding (for backfill).
  Future<List<String>> getIdsWithoutEmbedding() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'documents',
      columns: ['id'],
      where: 'embedding IS NULL',
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  // --- Row mapping ---------------------------------------------------------

  Future<void> _replaceFields(Transaction txn, DocumentModel doc) async {
    await txn.delete(
      'fields',
      where: 'document_id = ?',
      whereArgs: [doc.id],
    );
    for (var i = 0; i < doc.extractedFields.length; i++) {
      final f = doc.extractedFields[i];
      await txn.insert('fields', {
        'id': const Uuid().v4(),
        'document_id': doc.id,
        'label': f.label,
        'value': f.value,
        'semantic_key': f.semanticKey,
        'confidence': f.confidence,
        'verified': f.verified ? 1 : 0,
        'position': i,
      });
    }
  }

  Map<String, Object?> _docToRow(DocumentModel doc) => {
    'id': doc.id,
    'name': doc.name,
    'owner_name': doc.ownerName,
    'person_id': doc.personId,
    'category': doc.category.name,
    'doc_type': doc.type,
    'detected_type': doc.detectedType,
    'upload_date': doc.uploadDate.millisecondsSinceEpoch,
    'confidence': doc.confidence,
    'raw_text': doc.rawText,
    'summary': doc.summary,
    'image_file': doc.imageFile,
    'thumb_file': doc.thumbFile,
    'source': doc.source.name,
    'note': doc.note,
    'extra_pages': jsonEncode(doc.extraPages),
  };

  DocumentModel _docFromRow(
    Map<String, Object?> row,
    List<ExtractedField> fields,
  ) => DocumentModel(
    id: row['id'] as String,
    name: row['name'] as String,
    ownerName: row['owner_name'] as String? ?? '',
    personId: row['person_id'] as String?,
    category: DocumentCategory.fromName(row['category'] as String),
    type: row['doc_type'] as String? ?? '',
    detectedType: row['detected_type'] as String? ?? '',
    uploadDate: DateTime.fromMillisecondsSinceEpoch(
      row['upload_date'] as int,
    ),
    confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
    rawText: row['raw_text'] as String? ?? '',
    summary: row['summary'] as String? ?? '',
    imageFile: row['image_file'] as String? ?? '',
    thumbFile: row['thumb_file'] as String? ?? '',
    source: ExtractionSource.fromName(row['source'] as String? ?? 'onDevice'),
    note: row['note'] as String? ?? '',
    extraPages: _decodePages(row['extra_pages'] as String?),
    extractedFields: fields,
  );

  static List<String> _decodePages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toList();
    } catch (_) {
      return const [];
    }
  }

  ExtractedField _fieldFromRow(Map<String, Object?> row) => ExtractedField(
    label: row['label'] as String,
    value: row['value'] as String,
    semanticKey: row['semantic_key'] as String? ?? '',
    confidence: (row['confidence'] as num?)?.toDouble() ?? 1,
    verified: (row['verified'] as int? ?? 0) == 1,
  );
}
