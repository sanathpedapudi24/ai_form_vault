/// Identity graph models: people, their facts, and relationships.
library;

/// Types of relationships between people.
enum RelationshipType {
  father('Father'),
  mother('Mother'),
  sister('Sister'),
  brother('Brother'),
  spouse('Spouse'),
  son('Son'),
  daughter('Daughter'),
  guardian('Guardian'),
  friend('Friend'),
  other('Related');

  final String label;
  const RelationshipType(this.label);

  static RelationshipType fromName(String name) {
    return RelationshipType.values.firstWhere(
      (t) => t.name == name.toLowerCase(),
      orElse: () => RelationshipType.other,
    );
  }
}

/// Lifecycle of an AI-suggested relationship. Nothing is treated as real
/// until the user confirms it — consent-first by design.
enum RelationshipStatus {
  pending,
  confirmed,
  rejected;

  static RelationshipStatus fromName(String name) =>
      RelationshipStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RelationshipStatus.pending,
      );
}

/// A person node in the identity graph.
class Person {
  final String id;
  final String displayName;

  /// True for the vault owner (exactly one).
  final bool isUser;
  final DateTime createdAt;

  /// Derived, filled by queries: how many documents belong to this person.
  final int documentCount;

  const Person({
    required this.id,
    required this.displayName,
    this.isUser = false,
    required this.createdAt,
    this.documentCount = 0,
  });

  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  Person copyWith({String? displayName, bool? isUser, int? documentCount}) =>
      Person(
        id: id,
        displayName: displayName ?? this.displayName,
        isUser: isUser ?? this.isUser,
        createdAt: createdAt,
        documentCount: documentCount ?? this.documentCount,
      );
}

/// A canonical fact about a person ("dob" → "12/08/1998"), aggregated from
/// documents. One row per (person, key); the highest-confidence source wins
/// unless the user verified a value manually.
class PersonFact {
  final String id;
  final String personId;

  /// Canonical key — see [FactKeys] in document_model.dart.
  final String factKey;
  final String value;
  final double confidence;
  final String? sourceDocumentId;

  /// True when the user confirmed or hand-edited the value.
  final bool verified;
  final DateTime updatedAt;

  const PersonFact({
    required this.id,
    required this.personId,
    required this.factKey,
    required this.value,
    this.confidence = 1.0,
    this.sourceDocumentId,
    this.verified = false,
    required this.updatedAt,
  });

  PersonFact copyWith({
    String? value,
    double? confidence,
    String? sourceDocumentId,
    bool? verified,
    DateTime? updatedAt,
  }) => PersonFact(
    id: id,
    personId: personId,
    factKey: factKey,
    value: value ?? this.value,
    confidence: confidence ?? this.confidence,
    sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
    verified: verified ?? this.verified,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// A directed relationship edge: [fromPersonId] is the [type] of
/// [toPersonId] — e.g. "Ramesh is the father of Charan".
class Relationship {
  final String id;
  final String fromPersonId;
  final String toPersonId;
  final RelationshipType type;
  final RelationshipStatus status;
  final double confidence;

  /// Human-readable justification shown in the confirm sheet, e.g.
  /// "Named as father on Charan's Aadhaar card".
  final String evidence;
  final String? sourceDocumentId;
  final DateTime createdAt;

  const Relationship({
    required this.id,
    required this.fromPersonId,
    required this.toPersonId,
    required this.type,
    this.status = RelationshipStatus.pending,
    this.confidence = 0.0,
    this.evidence = '',
    this.sourceDocumentId,
    required this.createdAt,
  });

  Relationship copyWith({
    RelationshipType? type,
    RelationshipStatus? status,
    double? confidence,
    String? evidence,
  }) => Relationship(
    id: id,
    fromPersonId: fromPersonId,
    toPersonId: toPersonId,
    type: type ?? this.type,
    status: status ?? this.status,
    confidence: confidence ?? this.confidence,
    evidence: evidence ?? this.evidence,
    sourceDocumentId: sourceDocumentId,
    createdAt: createdAt,
  );
}
