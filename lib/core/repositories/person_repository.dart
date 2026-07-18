import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/person_model.dart';
import '../services/name_matcher.dart';

/// Persistence for the identity graph: persons, facts, relationships.
class PersonRepository {
  const PersonRepository();

  // --- Persons --------------------------------------------------------------

  Future<List<Person>> getAllPersons() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT p.*, COUNT(d.id) AS doc_count
      FROM persons p
      LEFT JOIN documents d ON d.person_id = p.id
      GROUP BY p.id
      ORDER BY p.is_user DESC, p.display_name ASC
    ''');
    return rows.map(_personFromRow).toList();
  }

  Future<Person?> getUser() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'persons',
      where: 'is_user = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : _personFromRow(rows.first);
  }

  /// Ensures a vault-owner person exists; returns it.
  Future<Person> getOrCreateUser({String defaultName = 'You'}) async {
    final existing = await getUser();
    if (existing != null) return existing;
    final person = Person(
      id: const Uuid().v4(),
      displayName: defaultName,
      isUser: true,
      createdAt: DateTime.now(),
    );
    await insertPerson(person);
    return person;
  }

  /// Finds the closest matching existing person by fuzzy name similarity
  /// (handles OCR typos, honorifics, reordered or partial names — see
  /// [NameMatcher]), or null if nothing crosses the match threshold.
  Future<Person?> findByName(String name) async {
    if (NameMatcher.normalize(name).isEmpty) return null;
    final all = await getAllPersons();

    Person? best;
    var bestScore = 0.0;
    for (final p in all) {
      if (!NameMatcher.isSameName(name, p.displayName)) continue;
      final score = NameMatcher.similarity(name, p.displayName);
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return best;
  }

  Future<Person> getOrCreateByName(String name) async {
    final existing = await findByName(name);
    if (existing == null) {
      final person = Person(
        id: const Uuid().v4(),
        displayName: _titleCase(name.trim()),
        createdAt: DateTime.now(),
      );
      await insertPerson(person);
      return person;
    }

    // A fuller name (more tokens — e.g. a middle name this document adds)
    // is a strict upgrade over what's stored; keep the record complete.
    final candidate = _titleCase(name.trim());
    final existingTokens = existing.displayName.split(RegExp(r'\s+')).length;
    final candidateTokens = candidate.split(RegExp(r'\s+')).length;
    if (candidateTokens > existingTokens) {
      final updated = existing.copyWith(displayName: candidate);
      await updatePerson(updated);
      return updated;
    }
    return existing;
  }

  Future<void> insertPerson(Person person) async {
    final db = await AppDatabase.instance;
    await db.insert('persons', {
      'id': person.id,
      'display_name': person.displayName,
      'is_user': person.isUser ? 1 : 0,
      'created_at': person.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> updatePerson(Person person) async {
    final db = await AppDatabase.instance;
    await db.update(
      'persons',
      {'display_name': person.displayName, 'is_user': person.isUser ? 1 : 0},
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  Future<void> deletePerson(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  /// Folds [dropId] into [keepId]: re-points that person's documents, facts,
  /// and relationships to the kept person, drops now-redundant edges, then
  /// deletes the merged-away person. Runs in one transaction.
  Future<void> mergePersons(String keepId, String dropId) async {
    if (keepId == dropId) return;
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.update(
        'documents',
        {'person_id': keepId},
        where: 'person_id = ?',
        whereArgs: [dropId],
      );

      // Move facts, but don't create a duplicate (person, fact_key): keep the
      // one already on the kept person.
      final dropFacts = await txn.query(
        'facts',
        where: 'person_id = ?',
        whereArgs: [dropId],
      );
      for (final row in dropFacts) {
        final exists = await txn.query(
          'facts',
          where: 'person_id = ? AND fact_key = ?',
          whereArgs: [keepId, row['fact_key']],
          limit: 1,
        );
        if (exists.isEmpty) {
          await txn.update(
            'facts',
            {'person_id': keepId},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } else {
          await txn.delete('facts', where: 'id = ?', whereArgs: [row['id']]);
        }
      }

      await txn.update(
        'relationships',
        {'from_person_id': keepId},
        where: 'from_person_id = ?',
        whereArgs: [dropId],
      );
      await txn.update(
        'relationships',
        {'to_person_id': keepId},
        where: 'to_person_id = ?',
        whereArgs: [dropId],
      );
      // A merge can create a person-to-themselves edge — drop those.
      await txn.delete(
        'relationships',
        where: 'from_person_id = to_person_id',
      );

      await txn.delete('persons', where: 'id = ?', whereArgs: [dropId]);
    });
  }

  // --- Facts -----------------------------------------------------------------

  Future<List<PersonFact>> getFacts(String personId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'facts',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'fact_key ASC',
    );
    return rows.map(_factFromRow).toList();
  }

  Future<List<PersonFact>> getAllFacts() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('facts');
    return rows.map(_factFromRow).toList();
  }

  /// Insert-or-improve: a new value replaces the old one only when the old
  /// one isn't user-verified and the new confidence is at least as high.
  Future<void> upsertFact(PersonFact fact) async {
    final db = await AppDatabase.instance;
    final existing = await db.query(
      'facts',
      where: 'person_id = ? AND fact_key = ?',
      whereArgs: [fact.personId, fact.factKey],
    );

    if (existing.isEmpty) {
      await db.insert('facts', _factToRow(fact));
      return;
    }

    final current = _factFromRow(existing.first);
    if (current.verified && !fact.verified) return;
    if (!fact.verified && fact.confidence < current.confidence) return;

    await db.update(
      'facts',
      _factToRow(fact.copyWith(updatedAt: DateTime.now())),
      where: 'id = ?',
      whereArgs: [current.id],
    );
  }

  Future<void> deleteFact(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('facts', where: 'id = ?', whereArgs: [id]);
  }

  // --- Relationships -----------------------------------------------------------

  Future<List<Relationship>> getRelationships({
    RelationshipStatus? status,
  }) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'relationships',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.name] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(_relFromRow).toList();
  }

  /// True if an edge between the two people already exists (either way).
  Future<bool> relationshipExists(String personA, String personB) async {
    return (await findRelationship(personA, personB)) != null;
  }

  /// Returns an existing edge between the two people (either direction), or
  /// null. Prefers a directed [from]→[to] match when several exist.
  Future<Relationship?> findRelationship(String from, String to) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'relationships',
      where:
          '(from_person_id = ? AND to_person_id = ?) OR '
          '(from_person_id = ? AND to_person_id = ?)',
      whereArgs: [from, to, to, from],
    );
    if (rows.isEmpty) return null;
    final rels = rows.map(_relFromRow).toList();
    return rels.firstWhere(
      (r) => r.fromPersonId == from && r.toPersonId == to,
      orElse: () => rels.first,
    );
  }

  /// Strengthens a pending relationship when another document corroborates
  /// it: raises confidence and appends the new evidence line.
  Future<void> upgradeRelationship(
    String id, {
    required double confidence,
    required String evidence,
  }) async {
    final db = await AppDatabase.instance;
    await db.update(
      'relationships',
      {'confidence': confidence, 'evidence': evidence},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertRelationship(Relationship rel) async {
    final db = await AppDatabase.instance;
    await db.insert('relationships', {
      'id': rel.id,
      'from_person_id': rel.fromPersonId,
      'to_person_id': rel.toPersonId,
      'rel_type': rel.type.name,
      'status': rel.status.name,
      'confidence': rel.confidence,
      'evidence': rel.evidence,
      'source_document_id': rel.sourceDocumentId,
      'created_at': rel.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> setRelationshipStatus(
    String id,
    RelationshipStatus status, {
    RelationshipType? type,
  }) async {
    final db = await AppDatabase.instance;
    await db.update(
      'relationships',
      {
        'status': status.name,
        if (type != null) 'rel_type': type.name,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRelationship(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('relationships', where: 'id = ?', whereArgs: [id]);
  }

  // --- Row mapping ---------------------------------------------------------

  Person _personFromRow(Map<String, Object?> row) => Person(
    id: row['id'] as String,
    displayName: row['display_name'] as String,
    isUser: (row['is_user'] as int? ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    documentCount: (row['doc_count'] as int?) ?? 0,
  );

  PersonFact _factFromRow(Map<String, Object?> row) => PersonFact(
    id: row['id'] as String,
    personId: row['person_id'] as String,
    factKey: row['fact_key'] as String,
    value: row['value'] as String,
    confidence: (row['confidence'] as num?)?.toDouble() ?? 1,
    sourceDocumentId: row['source_document_id'] as String?,
    verified: (row['verified'] as int? ?? 0) == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );

  Map<String, Object?> _factToRow(PersonFact fact) => {
    'id': fact.id,
    'person_id': fact.personId,
    'fact_key': fact.factKey,
    'value': fact.value,
    'confidence': fact.confidence,
    'source_document_id': fact.sourceDocumentId,
    'verified': fact.verified ? 1 : 0,
    'updated_at': fact.updatedAt.millisecondsSinceEpoch,
  };

  Relationship _relFromRow(Map<String, Object?> row) => Relationship(
    id: row['id'] as String,
    fromPersonId: row['from_person_id'] as String,
    toPersonId: row['to_person_id'] as String,
    type: RelationshipType.fromName(row['rel_type'] as String),
    status: RelationshipStatus.fromName(row['status'] as String),
    confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
    evidence: row['evidence'] as String? ?? '',
    sourceDocumentId: row['source_document_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );

  static String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}
