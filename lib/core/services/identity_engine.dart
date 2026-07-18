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

      final type = _mapRelation(mention.relationToOwner);
      final evidenceLine = mention.evidence.isNotEmpty
          ? mention.evidence
          : 'Named on ${document.displayTitle}';

      // If an edge already exists, corroborate rather than duplicate: a
      // still-pending suggestion of the same kind gets a confidence bump and
      // the extra evidence, so a relationship named on three documents reads
      // as more trustworthy than one named on a single page. A relationship
      // the user already confirmed or rejected is left untouched.
      final existing =
          await _persons.findRelationship(person.id, ownerPersonId);
      if (existing != null) {
        if (existing.status == RelationshipStatus.pending &&
            existing.type == type) {
          final boosted = (existing.confidence + 0.1).clamp(0.0, 0.97);
          final mergedEvidence = existing.evidence.contains(evidenceLine)
              ? existing.evidence
              : '${existing.evidence}\n$evidenceLine';
          await _persons.upgradeRelationship(
            existing.id,
            confidence: boosted,
            evidence: mergedEvidence,
          );
        }
        continue;
      }

      await _persons.insertRelationship(
        Relationship(
          id: const Uuid().v4(),
          // Directed: "[person] is the [type] of [owner]".
          fromPersonId: person.id,
          toPersonId: ownerPersonId,
          type: type,
          status: RelationshipStatus.pending,
          confidence: document.source == ExtractionSource.ai ? 0.75 : 0.6,
          evidence: evidenceLine,
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

  /// Propagates the graph after the user confirms a relationship: it fills in
  /// the reverse edge (so the family reads correctly both ways) and suggests
  /// siblings among people who share a confirmed parent. Nothing new is
  /// auto-confirmed except the exact reciprocal of what the user just okayed —
  /// derived siblings stay *pending* for the user to confirm.
  Future<void> propagateConfirmed(Relationship rel) async {
    await _ensureReciprocal(rel);
    await _suggestSiblings(rel);
  }

  Future<void> _ensureReciprocal(Relationship rel) async {
    // The reciprocal's subject is the "to" person, so its gender decides the
    // gendered inverse type (e.g. father → son vs daughter).
    final inverse = rel.type.inverse(await _genderOf(rel.toPersonId));
    if (inverse == null) return;

    final existing =
        await _persons.findRelationship(rel.toPersonId, rel.fromPersonId);
    if (existing == null) {
      await _persons.insertRelationship(
        Relationship(
          id: const Uuid().v4(),
          fromPersonId: rel.toPersonId,
          toPersonId: rel.fromPersonId,
          type: inverse,
          status: RelationshipStatus.confirmed,
          confidence: rel.confidence,
          evidence: 'Reverse of the "${rel.type.label}" link you confirmed',
          sourceDocumentId: rel.sourceDocumentId,
          createdAt: DateTime.now(),
        ),
      );
    } else if (existing.status == RelationshipStatus.pending) {
      await _persons.setRelationshipStatus(
        existing.id,
        RelationshipStatus.confirmed,
        type: inverse,
      );
    }
  }

  Future<void> _suggestSiblings(Relationship rel) async {
    final pc = _asParentChild(rel);
    if (pc == null) return;
    final (parentId, childId) = pc;

    final all = await _persons.getRelationships();
    final otherChildren = <String>{};
    for (final r in all) {
      if (r.status != RelationshipStatus.confirmed) continue;
      final opc = _asParentChild(r);
      if (opc == null) continue;
      if (opc.$1 == parentId && opc.$2 != childId) otherChildren.add(opc.$2);
    }
    if (otherChildren.isEmpty) return;

    final all2 = await _persons.getAllPersons();
    final parentName = all2
        .where((p) => p.id == parentId)
        .map((p) => p.displayName)
        .firstOrNull;

    for (final siblingId in otherChildren) {
      if (await _persons.findRelationship(childId, siblingId) != null) continue;
      final gender = await _genderOf(siblingId);
      final type = _siblingTypeForGender(gender);
      await _persons.insertRelationship(
        Relationship(
          id: const Uuid().v4(),
          fromPersonId: siblingId,
          toPersonId: childId,
          type: type,
          status: RelationshipStatus.pending,
          confidence: 0.7,
          evidence: parentName != null
              ? 'Shares a parent ($parentName) with them'
              : 'Shares a confirmed parent with them',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Normalizes a relationship into (parentId, childId) if it encodes a
  /// parent–child link, else null.
  (String, String)? _asParentChild(Relationship rel) {
    if (rel.type.fromIsParent) return (rel.fromPersonId, rel.toPersonId);
    if (rel.type.fromIsChild) return (rel.toPersonId, rel.fromPersonId);
    return null;
  }

  static RelationshipType _siblingTypeForGender(String? gender) {
    final g = gender?.toLowerCase() ?? '';
    if (g.startsWith('m')) return RelationshipType.brother;
    if (g.startsWith('f')) return RelationshipType.sister;
    return RelationshipType.other;
  }

  Future<String?> _genderOf(String personId) async {
    final facts = await _persons.getFacts(personId);
    for (final f in facts) {
      if (f.factKey == FactKeys.gender && f.value.trim().isNotEmpty) {
        return f.value;
      }
    }
    return null;
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
        'grandfather' => RelationshipType.grandfather,
        'grandmother' => RelationshipType.grandmother,
        'grandson' => RelationshipType.grandson,
        'granddaughter' => RelationshipType.granddaughter,
        'uncle' => RelationshipType.uncle,
        'aunt' => RelationshipType.aunt,
        'nephew' => RelationshipType.nephew,
        'niece' => RelationshipType.niece,
        'cousin' => RelationshipType.cousin,
        'father-in-law' || 'father in law' => RelationshipType.fatherInLaw,
        'mother-in-law' || 'mother in law' => RelationshipType.motherInLaw,
        'son-in-law' || 'son in law' => RelationshipType.sonInLaw,
        'daughter-in-law' || 'daughter in law' =>
          RelationshipType.daughterInLaw,
        'brother-in-law' || 'brother in law' => RelationshipType.brotherInLaw,
        'sister-in-law' || 'sister in law' => RelationshipType.sisterInLaw,
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
