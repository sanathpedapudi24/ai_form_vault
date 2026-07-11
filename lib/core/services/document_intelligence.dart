import 'dart:typed_data';

import '../models/document_model.dart';
import 'document_parser.dart';
import 'gemini_client.dart';

/// A person mentioned on a document, with their relation to the owner.
class PersonMention {
  final String name;

  /// Relation to the document owner: 'father', 'mother', 'spouse',
  /// 'guardian', 'son', 'daughter', 'brother', 'sister', or 'unknown'.
  final String relationToOwner;
  final String evidence;

  const PersonMention({
    required this.name,
    this.relationToOwner = 'unknown',
    this.evidence = '',
  });
}

/// Everything the intelligence layer learned from one document image.
class DocumentAnalysis {
  final DocumentCategory category;
  final String documentType;
  final String ownerName;
  final String summary;
  final List<ExtractedField> fields;
  final List<PersonMention> people;
  final double confidence;
  final ExtractionSource source;

  const DocumentAnalysis({
    required this.category,
    required this.documentType,
    required this.ownerName,
    required this.summary,
    required this.fields,
    required this.people,
    required this.confidence,
    required this.source,
  });
}

/// Orchestrates document understanding.
///
/// Layered by design (swap any layer without breaking the others):
///   1. Gemini vision reads the image directly — best quality.
///   2. If AI is unavailable (no key, offline, quota), the on-device
///      OCR text + regex parser take over. The app always works.
class DocumentIntelligence {
  DocumentIntelligence({GeminiClient? gemini, DocumentParser? parser})
    : _gemini = gemini ?? GeminiClient(),
      _parser = parser ?? DocumentParser();

  final GeminiClient _gemini;
  final DocumentParser _parser;

  /// Analyzes a document. [imageBytes] is the downscaled JPEG; [ocrText] is
  /// on-device OCR output used for the fallback path (and to give Gemini a
  /// second signal for low-quality photos).
  Future<DocumentAnalysis> analyze({
    required Uint8List imageBytes,
    required String ocrText,
  }) async {
    if (_gemini.isConfigured) {
      try {
        return await _analyzeWithGemini(imageBytes, ocrText);
      } on GeminiException {
        // Fall through to on-device — never lose the user's scan.
      }
    }
    return _analyzeOnDevice(ocrText);
  }

  // --- Gemini path ------------------------------------------------------------

  Future<DocumentAnalysis> _analyzeWithGemini(
    Uint8List imageBytes,
    String ocrText,
  ) async {
    final keys = FactKeys.labels.keys.join(', ');
    final categories = DocumentCategory.values.map((c) => c.name).join(', ');

    final prompt =
        '''
You are a document analyst for a personal document vault app used in India.
Read the attached document image carefully and return ONLY a JSON object with this exact shape:

{
  "document_type": "specific type, e.g. 'Aadhaar Card', 'PAN Card', 'Class 12 Marksheet', 'Passport'",
  "category": "one of: $categories",
  "owner_name": "full name of the person this document belongs to, title-cased",
  "summary": "2-3 sentences describing what this document is, who it belongs to, and its key dates or purpose. Do NOT include full ID numbers in the summary.",
  "confidence": 0.0-1.0 overall extraction confidence,
  "fields": [
    {"label": "human label", "value": "exact value as printed", "key": "canonical key or empty string", "confidence": 0.0-1.0}
  ],
  "people": [
    {"name": "person named on the document other than the owner", "relation_to_owner": "father|mother|spouse|guardian|son|daughter|brother|sister|unknown", "evidence": "short phrase quoting where this appears"}
  ]
}

Rules:
- "key" must be one of [$keys] when the field matches one of those concepts, otherwise "".
- Extract every meaningful printed field, including in regional scripts (transliterate values to Latin where a Latin version is not printed, and note the original in the label).
- Dates as printed (do not reformat). Numbers exactly as printed, keeping spaces in Aadhaar numbers.
- If the image is not a document, return category "other" with an empty fields list and explain in summary.
- Set confidence honestly: glare, blur, or partial crops must lower it.

For reference, on-device OCR read the following text (may contain errors):
"""
${ocrText.length > 4000 ? ocrText.substring(0, 4000) : ocrText}
"""
''';

    final json = await _gemini.generateJson(
      prompt: prompt,
      imageBytes: imageBytes,
    );
    if (json is! Map<String, dynamic>) {
      throw const GeminiException(
        GeminiErrorReason.badResponse,
        'Expected JSON object',
      );
    }

    final fields = <ExtractedField>[];
    for (final f in (json['fields'] as List? ?? const [])) {
      if (f is! Map) continue;
      final label = (f['label'] as String? ?? '').trim();
      final value = (f['value'] as String? ?? '').trim();
      if (label.isEmpty || value.isEmpty) continue;
      final key = (f['key'] as String? ?? '').trim();
      fields.add(
        ExtractedField(
          label: label,
          value: value,
          semanticKey: FactKeys.labels.containsKey(key) ? key : '',
          confidence: ((f['confidence'] as num?)?.toDouble() ?? 0.8).clamp(
            0.0,
            1.0,
          ),
        ),
      );
    }

    final people = <PersonMention>[];
    for (final p in (json['people'] as List? ?? const [])) {
      if (p is! Map) continue;
      final name = (p['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      people.add(
        PersonMention(
          name: name,
          relationToOwner:
              (p['relation_to_owner'] as String? ?? 'unknown').toLowerCase(),
          evidence: (p['evidence'] as String? ?? '').trim(),
        ),
      );
    }

    return DocumentAnalysis(
      category: DocumentCategory.fromName(
        (json['category'] as String? ?? 'other').toLowerCase(),
      ),
      documentType: (json['document_type'] as String? ?? 'Document').trim(),
      ownerName: (json['owner_name'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      fields: fields,
      people: people,
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.7).clamp(
        0.0,
        1.0,
      ),
      source: ExtractionSource.ai,
    );
  }

  // --- On-device fallback -----------------------------------------------------

  DocumentAnalysis _analyzeOnDevice(String ocrText) {
    final parsed = _parser.parse(ocrText);

    final fields = parsed.fields
        .map((f) => f.copyWith(semanticKey: semanticKeyForLabel(f.label)))
        .toList();

    final owner = fields
        .firstWhere(
          (f) => f.semanticKey == FactKeys.fullName,
          orElse: () => const ExtractedField(label: '', value: ''),
        )
        .value;

    final father = fields
        .firstWhere(
          (f) => f.semanticKey == FactKeys.fatherName,
          orElse: () => const ExtractedField(label: '', value: ''),
        )
        .value;

    final type = parsed.detectedType.isNotEmpty
        ? parsed.detectedType
        : parsed.documentType;

    return DocumentAnalysis(
      category: parsed.category,
      documentType: type,
      ownerName: owner,
      summary: _localSummary(type, owner, parsed.category),
      fields: fields,
      people: [
        if (father.isNotEmpty)
          PersonMention(
            name: father,
            relationToOwner: 'father',
            evidence: "Printed as father's name on $type",
          ),
      ],
      confidence: parsed.overallConfidence,
      source: ExtractionSource.onDevice,
    );
  }

  static String _localSummary(
    String type,
    String owner,
    DocumentCategory category,
  ) {
    final buffer = StringBuffer(type.isEmpty ? 'Document' : type);
    if (owner.isNotEmpty) buffer.write(' belonging to $owner');
    buffer.write('. Category: ${category.label}.');
    return buffer.toString();
  }

  /// Maps the regex parser's human labels onto canonical fact keys so the
  /// offline path feeds the same profile/autofill pipeline as the AI path.
  static String semanticKeyForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('aadhaar')) return FactKeys.aadhaarNumber;
    if (l.contains('pan')) return FactKeys.panNumber;
    if (l.contains('passport')) return FactKeys.passportNumber;
    if (l.contains('voter')) return FactKeys.voterId;
    if (l.contains('driving') || l.contains('license')) {
      return FactKeys.drivingLicense;
    }
    if (l.contains('vehicle')) return FactKeys.vehicleRegistration;
    if (l.contains("father")) return FactKeys.fatherName;
    if (l.contains("mother")) return FactKeys.motherName;
    if (l.contains('spouse') || l.contains('husband') || l.contains('wife')) {
      return FactKeys.spouseName;
    }
    if (l.contains('student name')) return FactKeys.fullName;
    if (l == 'full name' || l == 'name') return FactKeys.fullName;
    if (l.contains('date of birth') || l == 'dob') return FactKeys.dob;
    if (l.contains('gender') || l.contains('sex')) return FactKeys.gender;
    if (l.contains('phone') || l.contains('mobile')) return FactKeys.phone;
    if (l.contains('email')) return FactKeys.email;
    if (l.contains('pin code') || l.contains('pincode')) return FactKeys.pinCode;
    if (l.contains('address')) return FactKeys.address;
    if (l.contains('care of') || l == 'c/o' || l == 's/o' || l == 'd/o' ||
        l == 'w/o') {
      return FactKeys.careOf;
    }
    if (l == 'state') return FactKeys.state;
    if (l.contains('blood')) return FactKeys.bloodGroup;
    if (l.contains('roll')) return FactKeys.rollNumber;
    if (l.contains('school') || l.contains('college') ||
        l.contains('university') || l.contains('institution') ||
        l.contains('board')) {
      return FactKeys.institution;
    }
    if (l.contains('expiry') || l.contains('valid till') ||
        l.contains('valid until')) {
      return FactKeys.expiryDate;
    }
    if (l.contains('issue')) return FactKeys.issueDate;
    return '';
  }
}
