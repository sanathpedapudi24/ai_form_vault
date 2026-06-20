/// Types of relationships between people.
enum RelationshipType {
  father('Father'),
  mother('Mother'),
  sister('Sister'),
  brother('Brother'),
  spouse('Spouse'),
  son('Son'),
  daughter('Daughter'),
  friend('Friend'),
  other('Other');

  final String label;
  const RelationshipType(this.label);

  String get name => label.toLowerCase();

  static RelationshipType fromName(String name) {
    return RelationshipType.values.firstWhere(
      (t) => t.name == name.toLowerCase(),
      orElse: () => RelationshipType.other,
    );
  }
}

/// A person node in the identity graph.
class PersonNode {
  final String id;
  final String name;
  final RelationshipType? relationship;
  final bool isUser;
  final String? avatarInitial;
  final int documentCount;

  const PersonNode({
    required this.id,
    required this.name,
    this.relationship,
    this.isUser = false,
    this.avatarInitial,
    this.documentCount = 0,
  });

  String get initial =>
      avatarInitial ?? (name.isNotEmpty ? name[0].toUpperCase() : '?');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'relationship': relationship?.name,
    'isUser': isUser,
    'avatarInitial': avatarInitial,
    'documentCount': documentCount,
  };

  factory PersonNode.fromMap(Map<String, dynamic> map) => PersonNode(
    id: map['id'] as String,
    name: map['name'] as String,
    relationship: map['relationship'] != null
        ? RelationshipType.fromName(map['relationship'] as String)
        : null,
    isUser: map['isUser'] as bool? ?? false,
    avatarInitial: map['avatarInitial'] as String?,
    documentCount: map['documentCount'] as int? ?? 0,
  );
}
