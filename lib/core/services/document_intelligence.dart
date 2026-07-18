import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../models/document_model.dart';
import 'document_parser.dart';

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

/// On-device document understanding: OCR text + regex parsing.
class DocumentIntelligence {
  DocumentIntelligence({DocumentParser? parser})
    : _parser = parser ?? DocumentParser();

  final DocumentParser _parser;

  /// Analyzes a document from OCR text. When [pageTexts] holds more than one
  /// page, fields are voted across pages (see [DocumentParser.parseMultiPage]);
  /// otherwise a single-page parse runs on [ocrText].
  Future<DocumentAnalysis> analyze({
    required Uint8List imageBytes,
    required String ocrText,
    List<String> pageTexts = const [],
  }) async {
    return _analyzeOnDevice(ocrText, pageTexts);
  }

  DocumentAnalysis _analyzeOnDevice(String ocrText, List<String> pageTexts) {
    final parsed = pageTexts.length > 1
        ? _parser.parseMultiPage(pageTexts)
        : _parser.parse(ocrText);

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
      summary: _localSummary(type, owner, parsed.category, fields),
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

  /// A richer, human-readable summary that also improves search recall by
  /// naming the key facts the document carries. Sensitive numbers aren't
  /// spelled out here (they live in the fields); this lists what's present.
  static String _localSummary(
    String type,
    String owner,
    DocumentCategory category,
    List<ExtractedField> fields,
  ) {
    final buffer = StringBuffer(type.isEmpty ? 'Document' : type);
    if (owner.isNotEmpty) buffer.write(' for $owner');
    buffer.write('.');

    // Name the notable facts on file (helps both the reader and search).
    const notable = <String, String>{
      FactKeys.aadhaarNumber: 'Aadhaar number',
      FactKeys.panNumber: 'PAN',
      FactKeys.passportNumber: 'passport number',
      FactKeys.voterId: 'voter ID',
      FactKeys.drivingLicense: 'driving licence',
      FactKeys.dob: 'date of birth',
      FactKeys.address: 'address',
      FactKeys.phone: 'phone',
    };
    final present = <String>[];
    for (final entry in notable.entries) {
      if (fields.any(
        (f) => f.semanticKey == entry.key && f.value.trim().isNotEmpty,
      )) {
        present.add(entry.value);
      }
    }
    if (present.isNotEmpty) {
      buffer.write(' Includes ${present.join(', ')}.');
    }

    final expiry = fields
        .where((f) => f.semanticKey == FactKeys.expiryDate)
        .map((f) => f.value)
        .firstOrNull;
    if (expiry != null && expiry.trim().isNotEmpty) {
      buffer.write(' Valid until $expiry.');
    }

    buffer.write(' Category: ${category.label}.');
    return buffer.toString();
  }

  /// Maps the regex parser's human labels onto canonical fact keys so the
  /// offline path feeds the same profile/autofill pipeline.
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
