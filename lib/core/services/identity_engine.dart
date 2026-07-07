import 'package:uuid/uuid.dart';

import '../models/document_model.dart';
import '../models/person_model.dart';
import '../repositories/person_repository.dart';
import 'document_intelligence.dart';
import 'name_matcher.dart';

/// What one document contributed to the identity graph.
class IngestOutcome {
  final String personId;
  final int factsLearned;
  final int relationshipsSuggested;

  const IngestOutcome({
    required this.personId,
    this.factsLearned = 0,
    this.relationshipsSuggested = 0,
  });
}

/// Turns document extractions into durable knowledge:
///   * canonical facts per person (highest confidence wins, user edits are
///     sacred),
///   * relationship *suggestions* that stay pending until the user confirms
///     them — the app never assumes who your family is.
class IdentityEngine {
  IdentityEngine({PersonRepository? persons})
    : _persons = persons ?? const PersonRepository();

  final PersonRepository _persons;

  /// Ingests an analyzed document. [ownerPersonId] is the person chosen on
  /// the review screen (defaults to the vault owner upstream).
  Future<IngestOutcome> ingest({
    required DocumentModel document,
    required List<PersonMention> mentions,
    required String ownerPersonId,
  }) async {
    var factsLearned = 0;
    var suggested = 0;

    // 1. Facts from canonical fields.
    for (final field in document.extractedFields) {
      if (field.semanticKey.isEmpty || field.value.trim().isEmpty) continue;
      await _persons.upsertFact(
        PersonFact(
          id: const Uuid().v4(),
          personId: ownerPersonId,
          factKey: field.semanticKey,
          value: field.value.trim(),
          confidence: field.confidence,
          sourceDocumentId: document.id,
          verified: field.verified,
          updatedAt: DateTime.now(),
        ),
      );
      factsLearned++;
    }

    // Keep the owner's display name in sync with their best known name.
    final nameField = document.fieldByKey(FactKeys.fullName);
    if (nameField != null && nameField.value.trim().isNotEmpty) {
      final all = await _persons.getAllPersons();
      final owner = all.where((p) => p.id == ownerPersonId).firstOrNull;
      if (owner != null &&
          (owner.displayName == 'You' || owner.displayName.isEmpty)) {
        await _persons.updatePerson(
          owner.copyWith(displayName: _titleCase(nameField.value.trim())),
        );
      }
    }

    // 2. Relationship suggestions from people named on the document.
    for (final mention in mentions) {
      final name = mention.name.trim();
      if (name.isEmpty) continue;
      // Don't create a person for the owner themselves.
      if (NameMatcher.isSameName(name, document.ownerName)) continue;

      final person = await _persons.getOrCreateByName(name);
      if (person.id == ownerPersonId) continue;
      if (await _persons.relationshipExists(person.id, ownerPersonId)) {
        continue;
      }

      final type = _mapRelation(mention.relationToOwner);
      await _persons.insertRelationship(
        Relationship(
          id: const Uuid().v4(),
          // Directed: "[person] is the [type] of [owner]".
          fromPersonId: person.id,
          toPersonId: ownerPersonId,
          type: type,
          status: RelationshipStatus.pending,
          confidence: document.source == ExtractionSource.ai ? 0.75 : 0.6,
          evidence: mention.evidence.isNotEmpty
              ? mention.evidence
              : 'Named on ${document.displayTitle}',
          sourceDocumentId: document.id,
          createdAt: DateTime.now(),
        ),
      );
      suggested++;
    }

    return IngestOutcome(
      personId: ownerPersonId,
      factsLearned: factsLearned,
      relationshipsSuggested: suggested,
    );
  }

  /// Resolves which person a scanned document belongs to *before* saving:
  /// if the extracted owner name matches an existing person (including the
  /// user), reuse them; otherwise create a new person node.
  Future<Person> resolveOwner(String ownerName) async {
    final user = await _persons.getOrCreateUser();
    if (ownerName.trim().isEmpty) return user;

    // First document ever, or the user is still unnamed → assume it's them.
    final existing = await _persons.findByName(ownerName);
    if (existing != null) return existing;

    if (user.displayName == 'You' || user.displayName.isEmpty) {
      return user;
    }
    return _persons.getOrCreateByName(ownerName);
  }

  static RelationshipType _mapRelation(String relation) =>
      switch (relation.toLowerCase()) {
        'father' => RelationshipType.father,
        'mother' => RelationshipType.mother,
        'spouse' || 'husband' || 'wife' => RelationshipType.spouse,
        'guardian' => RelationshipType.guardian,
        'son' => RelationshipType.son,
        'daughter' => RelationshipType.daughter,
        'brother' => RelationshipType.brother,
        'sister' => RelationshipType.sister,
        _ => RelationshipType.other,
      };

  static String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}
