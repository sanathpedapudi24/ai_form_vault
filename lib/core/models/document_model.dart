/// Document categories matching the vault tabs.
enum DocumentCategory {
  identity('ID Proof', 'Identity documents like Aadhaar, PAN, Passport'),
  education('Education', 'Degrees, certificates, transcripts'),
  finance('Finance', 'Tax documents, bank statements, insurance'),
  medical('Medical', 'Health records, prescriptions, reports'),
  travel('Travel', 'Passport, visas, travel documents'),
  family('Family', 'Ration card, family documents'),
  other('Other', 'Miscellaneous documents');

  final String label;
  final String description;
  const DocumentCategory(this.label, this.description);

  String get name {
    switch (this) {
      case DocumentCategory.identity:
        return 'identity';
      case DocumentCategory.education:
        return 'education';
      case DocumentCategory.finance:
        return 'finance';
      case DocumentCategory.medical:
        return 'medical';
      case DocumentCategory.travel:
        return 'travel';
      case DocumentCategory.family:
        return 'family';
      case DocumentCategory.other:
        return 'other';
    }
  }

  static DocumentCategory fromName(String name) {
    return DocumentCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => DocumentCategory.other,
    );
  }
}

/// Represents a document stored in the vault.
class DocumentModel {
  final String id;
  final String name;
  final String ownerName;
  final DocumentCategory category;
  final String type;
  final String detectedType;
  final DateTime uploadDate;
  final double confidence;
  final List<ExtractedField> extractedFields;
  final String rawText;
  final String imagePath;

  const DocumentModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.category,
    required this.type,
    required this.uploadDate,
    this.detectedType = '',
    this.confidence = 0.0,
    this.extractedFields = const [],
    this.rawText = '',
    this.imagePath = '',
  });

  String get dateFormatted {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${uploadDate.day} ${months[uploadDate.month - 1]} ${uploadDate.year}';
  }

  String get confidenceLabel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerName': ownerName,
    'category': category.name,
    'type': type,
    'detectedType': detectedType,
    'uploadDate': uploadDate.toIso8601String(),
    'confidence': confidence,
    'extractedFields': extractedFields.map((f) => f.toMap()).toList(),
    'rawText': rawText,
    'imagePath': imagePath,
  };

  factory DocumentModel.fromMap(Map<String, dynamic> map) => DocumentModel(
    id: map['id'] as String,
    name: map['name'] as String,
    ownerName: map['ownerName'] as String,
    category: DocumentCategory.fromName(map['category'] as String),
    type: map['type'] as String,
    detectedType: map['detectedType'] as String? ?? '',
    uploadDate: DateTime.parse(map['uploadDate'] as String),
    confidence: (map['confidence'] as num).toDouble(),
    extractedFields: (map['extractedFields'] as List)
        .map((f) => ExtractedField.fromMap(f as Map<String, dynamic>))
        .toList(),
    rawText: map['rawText'] as String? ?? '',
    imagePath: map['imagePath'] as String? ?? '',
  );

  DocumentModel copyWith({
    String? id,
    String? name,
    String? ownerName,
    DocumentCategory? category,
    String? type,
    String? detectedType,
    DateTime? uploadDate,
    double? confidence,
    List<ExtractedField>? extractedFields,
    String? rawText,
    String? imagePath,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      category: category ?? this.category,
      type: type ?? this.type,
      detectedType: detectedType ?? this.detectedType,
      uploadDate: uploadDate ?? this.uploadDate,
      confidence: confidence ?? this.confidence,
      extractedFields: extractedFields ?? this.extractedFields,
      rawText: rawText ?? this.rawText,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

/// A single extracted field from a document.
class ExtractedField {
  final String label;
  final String value;
  final double confidence;
  final String sourceDocument;

  const ExtractedField({
    required this.label,
    required this.value,
    this.confidence = 1.0,
    this.sourceDocument = '',
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'value': value,
    'confidence': confidence,
    'sourceDocument': sourceDocument,
  };

  factory ExtractedField.fromMap(Map<String, dynamic> map) => ExtractedField(
    label: map['label'] as String,
    value: map['value'] as String,
    confidence: (map['confidence'] as num).toDouble(),
    sourceDocument: map['sourceDocument'] as String? ?? '',
  );
}
