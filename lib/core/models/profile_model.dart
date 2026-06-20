/// User profile data.
class UserProfile {
  final String name;
  final String email;
  final String phone;
  final double completeness; // 0.0 to 1.0
  final int documentCount;
  final int profileCount;
  final int relationshipCount;
  final int recentScans;
  final List<ProfileSection> sections;

  const UserProfile({
    required this.name,
    required this.email,
    this.phone = '',
    this.completeness = 0.0,
    this.documentCount = 0,
    this.profileCount = 0,
    this.relationshipCount = 0,
    this.recentScans = 0,
    this.sections = const [],
  });

  int get completenessPercent => (completeness * 100).round();

  bool get hasName => name.isNotEmpty;
  bool get hasEmail => email.isNotEmpty;
  bool get hasPhone => phone.isNotEmpty;
  bool get isComplete => hasName && hasEmail && hasPhone;

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'phone': phone,
    'completeness': completeness,
    'documentCount': documentCount,
    'profileCount': profileCount,
    'relationshipCount': relationshipCount,
    'recentScans': recentScans,
    'sections': sections.map((s) => s.toMap()).toList(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    name: map['name'] as String,
    email: map['email'] as String,
    phone: map['phone'] as String? ?? '',
    completeness: (map['completeness'] as num).toDouble(),
    documentCount: map['documentCount'] as int? ?? 0,
    profileCount: map['profileCount'] as int? ?? 0,
    relationshipCount: map['relationshipCount'] as int? ?? 0,
    recentScans: map['recentScans'] as int? ?? 0,
    sections:
        (map['sections'] as List?)
            ?.map((s) => ProfileSection.fromMap(s as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// A section in the user's profile.
class ProfileSection {
  final String name;
  final String iconName;
  final int fieldCount;
  final bool isComplete;

  const ProfileSection({
    required this.name,
    required this.iconName,
    this.fieldCount = 0,
    this.isComplete = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'iconName': iconName,
    'fieldCount': fieldCount,
    'isComplete': isComplete,
  };

  factory ProfileSection.fromMap(Map<String, dynamic> map) => ProfileSection(
    name: map['name'] as String,
    iconName: map['iconName'] as String,
    fieldCount: map['fieldCount'] as int? ?? 0,
    isComplete: map['isComplete'] as bool? ?? false,
  );
}
