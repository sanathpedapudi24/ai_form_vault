import 'package:intl/intl.dart';

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

  static DocumentCategory fromName(String name) {
    return DocumentCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => DocumentCategory.other,
    );
  }
}

/// How a document's data was extracted.
enum ExtractionSource {
  /// Gemini vision read the document image directly.
  ai,

  /// On-device OCR + regex parser (offline / no API key).
  onDevice,

  /// User typed it in.
  manual;

  static ExtractionSource fromName(String name) =>
      ExtractionSource.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ExtractionSource.onDevice,
      );
}

/// A document stored in the vault.
class DocumentModel {
  final String id;
  final String name;
  final String ownerName;

  /// Person this document belongs to (links into the identity graph).
  final String? personId;
  final DocumentCategory category;
  final String type;
  final String detectedType;
  final DateTime uploadDate;
  final double confidence;
  final List<ExtractedField> extractedFields;
  final String rawText;

  /// One-paragraph AI summary used for semantic search embeddings.
  final String summary;

  /// Encrypted image filename inside the image vault ('' if none).
  final String imageFile;

  /// Encrypted thumbnail filename ('' if none).
  final String thumbFile;
  final ExtractionSource source;

  /// User's free-text note ("used for visa application").
  final String note;

  /// Encrypted filenames of pages beyond the first, for multi-page scans
  /// and PDF imports.
  final List<String> extraPages;

  const DocumentModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.category,
    required this.type,
    required this.uploadDate,
    this.personId,
    this.detectedType = '',
    this.confidence = 0.0,
    this.extractedFields = const [],
    this.rawText = '',
    this.summary = '',
    this.imageFile = '',
    this.thumbFile = '',
    this.source = ExtractionSource.onDevice,
    this.note = '',
    this.extraPages = const [],
  });

  String get dateFormatted => DateFormat('d MMM yyyy').format(uploadDate);

  String get confidenceLabel {
    if (confidence >= 0.85) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }

  /// Best display title: detected type if known, else the given name.
  String get displayTitle => detectedType.isNotEmpty ? detectedType : name;

  ExtractedField? fieldByKey(String semanticKey) {
    for (final f in extractedFields) {
      if (f.semanticKey == semanticKey) return f;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerName': ownerName,
    'personId': personId,
    'category': category.name,
    'type': type,
    'detectedType': detectedType,
    'uploadDate': uploadDate.toIso8601String(),
    'confidence': confidence,
    'extractedFields': extractedFields.map((f) => f.toMap()).toList(),
    'rawText': rawText,
    'summary': summary,
    'imageFile': imageFile,
    'thumbFile': thumbFile,
    'source': source.name,
    'note': note,
    'extraPages': extraPages,
  };

  factory DocumentModel.fromMap(Map<String, dynamic> map) => DocumentModel(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    ownerName: map['ownerName'] as String? ?? '',
    personId: map['personId'] as String?,
    category: DocumentCategory.fromName(map['category'] as String? ?? 'other'),
    type: map['type'] as String? ?? '',
    detectedType: map['detectedType'] as String? ?? '',
    uploadDate: DateTime.tryParse(map['uploadDate'] as String? ?? '') ??
        DateTime.now(),
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    extractedFields:
        (map['extractedFields'] as List?)
            ?.map((f) => ExtractedField.fromMap(f as Map<String, dynamic>))
            .toList() ??
        const [],
    rawText: map['rawText'] as String? ?? '',
    summary: map['summary'] as String? ?? '',
    // Legacy documents stored a raw path under 'imagePath'.
    imageFile: map['imageFile'] as String? ?? map['imagePath'] as String? ?? '',
    thumbFile: map['thumbFile'] as String? ?? '',
    source: ExtractionSource.fromName(map['source'] as String? ?? 'onDevice'),
    note: map['note'] as String? ?? '',
    extraPages:
        (map['extraPages'] as List?)?.map((e) => e as String).toList() ??
        const [],
  );

  DocumentModel copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? personId,
    DocumentCategory? category,
    String? type,
    String? detectedType,
    DateTime? uploadDate,
    double? confidence,
    List<ExtractedField>? extractedFields,
    String? rawText,
    String? summary,
    String? imageFile,
    String? thumbFile,
    ExtractionSource? source,
    String? note,
    List<String>? extraPages,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      personId: personId ?? this.personId,
      category: category ?? this.category,
      type: type ?? this.type,
      detectedType: detectedType ?? this.detectedType,
      uploadDate: uploadDate ?? this.uploadDate,
      confidence: confidence ?? this.confidence,
      extractedFields: extractedFields ?? this.extractedFields,
      rawText: rawText ?? this.rawText,
      summary: summary ?? this.summary,
      imageFile: imageFile ?? this.imageFile,
      thumbFile: thumbFile ?? this.thumbFile,
      source: source ?? this.source,
      note: note ?? this.note,
      extraPages: extraPages ?? this.extraPages,
    );
  }
}

/// A single extracted field from a document.
class ExtractedField {
  final String label;
  final String value;

  /// Canonical machine key ('full_name', 'dob', 'pan_number', …) — see
  /// [FactKeys]. Empty when the field doesn't map to a known concept.
  final String semanticKey;
  final double confidence;
  final String sourceDocument;

  /// True once the user has reviewed/edited this value.
  final bool verified;

  const ExtractedField({
    required this.label,
    required this.value,
    this.semanticKey = '',
    this.confidence = 1.0,
    this.sourceDocument = '',
    this.verified = false,
  });

  ExtractedField copyWith({
    String? label,
    String? value,
    String? semanticKey,
    double? confidence,
    String? sourceDocument,
    bool? verified,
  }) => ExtractedField(
    label: label ?? this.label,
    value: value ?? this.value,
    semanticKey: semanticKey ?? this.semanticKey,
    confidence: confidence ?? this.confidence,
    sourceDocument: sourceDocument ?? this.sourceDocument,
    verified: verified ?? this.verified,
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'value': value,
    'semanticKey': semanticKey,
    'confidence': confidence,
    'sourceDocument': sourceDocument,
    'verified': verified,
  };

  factory ExtractedField.fromMap(Map<String, dynamic> map) => ExtractedField(
    label: map['label'] as String? ?? '',
    value: map['value'] as String? ?? '',
    semanticKey: map['semanticKey'] as String? ?? '',
    confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    sourceDocument: map['sourceDocument'] as String? ?? '',
    verified: map['verified'] as bool? ?? false,
  );
}

/// Canonical semantic keys for extracted values. These connect extraction →
/// profile facts → search → autofill; keep them stable.
class FactKeys {
  FactKeys._();

  static const fullName = 'full_name';
  static const dob = 'dob';
  static const gender = 'gender';
  static const fatherName = 'father_name';
  static const motherName = 'mother_name';
  static const spouseName = 'spouse_name';
  static const guardianName = 'guardian_name';
  static const phone = 'phone';
  static const email = 'email';
  static const address = 'address';
  static const careOf = 'care_of';
  static const state = 'state';
  static const pinCode = 'pin_code';
  static const aadhaarNumber = 'aadhaar_number';
  static const panNumber = 'pan_number';
  static const passportNumber = 'passport_number';
  static const voterId = 'voter_id';
  static const drivingLicense = 'driving_license';
  static const vehicleRegistration = 'vehicle_registration';
  static const bloodGroup = 'blood_group';
  static const nationality = 'nationality';
  static const rollNumber = 'roll_number';
  static const institution = 'institution';
  static const qualification = 'qualification';
  static const issueDate = 'issue_date';
  static const expiryDate = 'expiry_date';

  /// Human-friendly labels for canonical keys.
  static const labels = <String, String>{
    fullName: 'Full Name',
    dob: 'Date of Birth',
    gender: 'Gender',
    fatherName: "Father's Name",
    motherName: "Mother's Name",
    spouseName: "Spouse's Name",
    guardianName: "Guardian's Name",
    phone: 'Phone',
    email: 'Email',
    address: 'Address',
    careOf: 'Care Of',
    state: 'State',
    pinCode: 'PIN Code',
    aadhaarNumber: 'Aadhaar Number',
    panNumber: 'PAN',
    passportNumber: 'Passport Number',
    voterId: 'Voter ID',
    drivingLicense: 'Driving License',
    vehicleRegistration: 'Vehicle Registration',
    bloodGroup: 'Blood Group',
    nationality: 'Nationality',
    rollNumber: 'Roll Number',
    institution: 'Institution',
    qualification: 'Qualification',
    issueDate: 'Issue Date',
    expiryDate: 'Expiry Date',
  };

  static String labelFor(String key) => labels[key] ?? key;

  /// Keys that are personal identifiers (masked by default in UI).
  static const sensitive = {
    aadhaarNumber,
    panNumber,
    passportNumber,
    voterId,
    drivingLicense,
  };
}
