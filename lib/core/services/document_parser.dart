// ignore_for_file: curly_braces_in_flow_control_structures

import '../models/document_model.dart';

class ParseResult {
  final DocumentCategory category;
  final String documentType;
  final String detectedType;
  final List<ExtractedField> fields;
  final double overallConfidence;

  const ParseResult({
    required this.category,
    required this.documentType,
    this.detectedType = '',
    required this.fields,
    required this.overallConfidence,
  });
}

class DocumentParser {
  // ---------------------------------------------------------------------------
  // Text normalization
  // ---------------------------------------------------------------------------
  String _normalize(String text) {
    var t = text;
    t = t.replaceAll('\r\n', '\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    t = t.split('\n').map((l) => l.trim()).join('\n');
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    return t.trim();
  }

  bool _textContains(String text, String keyword) {
    if (text.contains(keyword)) return true;
    final noSpaces = text.replaceAll(' ', '');
    final noSpacesKeyword = keyword.replaceAll(' ', '');
    if (noSpaces.contains(noSpacesKeyword)) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Label-based value extraction
  // ---------------------------------------------------------------------------
  String? _extractLabeledValue(String text, List<String> labels) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      for (final label in labels) {
        final escaped = RegExp.escape(label);

        // Attempt 1: label + value on same line (e.g. "Name: John Doe")
        final sameLine = RegExp(
          '$escaped\\s*[:.\\-–—]?\\s*(.+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (sameLine != null) {
          final val = sameLine.group(1)!.trim();
          // Reject if value contains separators that indicate it's not clean
          if (val.isNotEmpty &&
              val.length > 1 &&
              !RegExp(r'[|/\\\[\]{}<>]').hasMatch(val)) {
            return val.replaceAll(RegExp(r'[,;]+$'), '').trim();
          }
        }

        // Attempt 2a: line IS the label (e.g. "Name" → next line)
        final bool labelOnly;
        if (i + 1 < lines.length) {
          labelOnly = RegExp(
            '^$escaped\\s*[:.\\-–—]?\\s*\$',
            caseSensitive: false,
          ).hasMatch(line);
          if (labelOnly) {
            final next = lines[i + 1].trim();
            if (next.isNotEmpty &&
                next.length > 1 &&
                !next.endsWith(':') &&
                !next.endsWith('-')) {
              return next;
            }
          }
        } else {
          labelOnly = false;
        }

        // Attempt 2b: label appears ANYWHERE in the line (e.g. "HIA/ Name",
        // "नाम | Name", "पिता का नाम। Father's Name") → try next line
        if (i + 1 < lines.length && !labelOnly) {
          if (RegExp(escaped, caseSensitive: false).hasMatch(line)) {
            final next = lines[i + 1].trim();
            if (next.isNotEmpty &&
                next.length > 1 &&
                !next.endsWith(':') &&
                !next.endsWith('-') &&
                !RegExp(escaped, caseSensitive: false).hasMatch(next)) {
              return next;
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Category detection (all Indian document types)
  // ---------------------------------------------------------------------------
  /// Weighted keyword signals per category. A document accumulates the weight
  /// of every phrase it contains; the highest-scoring category wins. Weighted
  /// scoring beats the old first-match chain when a document carries words
  /// from several categories (e.g. a PAN card mentions "income tax" but
  /// "permanent account number" outweighs it → identity, not finance).
  static const List<(DocumentCategory, String, double)> _categorySignals = [
    // Identity
    (DocumentCategory.identity, 'AADHAAR', 3),
    (DocumentCategory.identity, 'UIDAI', 3),
    (DocumentCategory.identity, 'VID', 1.5),
    (DocumentCategory.identity, 'PERMANENT ACCOUNT NUMBER', 3),
    (DocumentCategory.identity, 'INCOME TAX', 1.5),
    (DocumentCategory.identity, 'IT DEPARTMENT', 1.5),
    (DocumentCategory.identity, 'ELECTION', 2),
    (DocumentCategory.identity, 'VOTER', 3),
    (DocumentCategory.identity, 'EPIC', 2),
    (DocumentCategory.identity, 'ELECTOR', 2),
    (DocumentCategory.identity, 'DRIVING', 3),
    (DocumentCategory.identity, 'LICENCE', 1.5),
    (DocumentCategory.identity, 'LICENSE', 1.5),
    (DocumentCategory.identity, 'MOTOR', 1),
    (DocumentCategory.identity, 'BIRTH', 2),
    (DocumentCategory.identity, 'CASTE', 2.5),
    // Travel
    (DocumentCategory.travel, 'PASSPORT', 3),
    (DocumentCategory.travel, 'VISA', 3),
    // Education
    (DocumentCategory.education, 'MARKSHEET', 3),
    (DocumentCategory.education, 'MARKS MEMO', 3),
    (DocumentCategory.education, 'GRADE CARD', 2),
    (DocumentCategory.education, 'GRADE SHEET', 2),
    (DocumentCategory.education, 'REPORT CARD', 2),
    (DocumentCategory.education, 'MEMO', 1),
    (DocumentCategory.education, 'RESULT', 1),
    (DocumentCategory.education, 'DEGREE', 2),
    (DocumentCategory.education, 'TRANSCRIPT', 3),
    (DocumentCategory.education, 'DIPLOMA', 2),
    (DocumentCategory.education, 'SSLC', 3),
    (DocumentCategory.education, 'SSC', 1.5),
    (DocumentCategory.education, 'HSC', 2),
    (DocumentCategory.education, '10TH', 1.5),
    (DocumentCategory.education, '12TH', 1.5),
    (DocumentCategory.education, 'SECONDARY', 1),
    (DocumentCategory.education, 'CBSE', 3),
    (DocumentCategory.education, 'ICSE', 3),
    (DocumentCategory.education, 'UNIVERSITY', 2),
    (DocumentCategory.education, 'B.TECH', 2),
    (DocumentCategory.education, 'CERTIFICATE', 0.5),
    (DocumentCategory.education, 'BOARD', 1),
    // Finance
    (DocumentCategory.finance, 'BANK', 3),
    (DocumentCategory.finance, 'SALARY', 2),
    (DocumentCategory.finance, 'PAYSLIP', 3),
    (DocumentCategory.finance, 'TAX', 1.5),
    (DocumentCategory.finance, 'ITR', 3),
    (DocumentCategory.finance, 'FORM 16', 3),
    (DocumentCategory.finance, 'INSURANCE', 3),
    (DocumentCategory.finance, 'INCOME CERTIFICATE', 2.5),
    // Medical
    (DocumentCategory.medical, 'MEDICAL', 3),
    (DocumentCategory.medical, 'PRESCRIPTION', 3),
    (DocumentCategory.medical, 'HEALTH', 2),
    (DocumentCategory.medical, 'HOSPITAL', 2),
    (DocumentCategory.medical, 'LAB', 2),
    // Family
    (DocumentCategory.family, 'RATION', 3),
    (DocumentCategory.family, 'FAMILY', 1.5),
    (DocumentCategory.family, 'MARRIAGE', 3),
    // Property → Other
    (DocumentCategory.other, 'SALE DEED', 3),
    (DocumentCategory.other, 'PROPERTY', 2),
    (DocumentCategory.other, 'RC BOOK', 2),
  ];

  DocumentCategory detectCategory(String text) =>
      classify(text).category;

  /// Classification with a confidence in [0, 1] (winning score relative to the
  /// total signal seen), so callers can tell a confident read from a guess.
  ({DocumentCategory category, double confidence}) classify(String text) {
    final normalized = _normalize(text.toUpperCase());
    final scores = <DocumentCategory, double>{};
    var total = 0.0;
    for (final (category, keyword, weight) in _categorySignals) {
      if (_textContains(normalized, keyword)) {
        scores[category] = (scores[category] ?? 0) + weight;
        total += weight;
      }
    }
    if (scores.isEmpty) {
      return (category: DocumentCategory.other, confidence: 0);
    }
    // Highest score wins; ties break by the category enum's declared order.
    DocumentCategory best = DocumentCategory.other;
    var bestScore = -1.0;
    for (final category in DocumentCategory.values) {
      final s = scores[category] ?? 0;
      if (s > bestScore) {
        bestScore = s;
        best = category;
      }
    }
    final confidence = total <= 0 ? 0.0 : (bestScore / total).clamp(0.0, 1.0);
    return (category: best, confidence: confidence);
  }

  // ---------------------------------------------------------------------------
  // Multi-page parse with field voting
  // ---------------------------------------------------------------------------
  /// Parses a multi-page document by parsing each page independently and
  /// merging the fields, so a value the OCR nailed on one page beats a
  /// garbled read of the same field on another — and a value that agrees
  /// across pages is trusted more (corroboration boost). Classification and
  /// type detection still run on the combined text, which has more context.
  ParseResult parseMultiPage(List<String> pageTexts) {
    final pages = pageTexts.where((t) => t.trim().isNotEmpty).toList();
    if (pages.length <= 1) return parse(pages.isEmpty ? '' : pages.first);

    final base = parse(pages.join('\n\n'));
    final perPage = pages.map(parse).toList();

    // Gather every candidate reading of each labelled field.
    final candidates = <String, List<ExtractedField>>{};
    void collect(List<ExtractedField> fs) {
      for (final f in fs) {
        (candidates.putIfAbsent(f.label, () => <ExtractedField>[])).add(f);
      }
    }
    collect(base.fields);
    for (final r in perPage) {
      collect(r.fields);
    }

    // Keep the combined parse's field order, then any labels only pages saw.
    final order = <String>[
      ...base.fields.map((f) => f.label),
      ...candidates.keys.where((l) => !base.fields.any((f) => f.label == l)),
    ];

    final merged = <ExtractedField>[];
    for (final label in order) {
      final cands = candidates[label];
      if (cands == null || cands.isEmpty) continue;
      merged.add(_voteField(cands));
    }

    final overall = merged.isEmpty
        ? 0.0
        : merged.map((f) => f.confidence).reduce((a, b) => a + b) /
              merged.length;

    return ParseResult(
      category: base.category,
      documentType: base.documentType,
      detectedType: base.detectedType,
      fields: merged,
      overallConfidence: overall,
    );
  }

  /// Picks the best reading among candidates for one field: group by value,
  /// score each group by its strongest reading plus a bonus for how many
  /// pages agreed, and return the winner with the boosted confidence.
  ExtractedField _voteField(List<ExtractedField> candidates) {
    final groups = <String, List<ExtractedField>>{};
    for (final c in candidates) {
      final key = _valueKey(c.value);
      if (key.isEmpty) continue;
      (groups.putIfAbsent(key, () => <ExtractedField>[])).add(c);
    }
    if (groups.isEmpty) return candidates.first;

    ExtractedField? best;
    var bestScore = -1.0;
    for (final group in groups.values) {
      final top = group.reduce((a, b) => a.confidence >= b.confidence ? a : b);
      // Each additional page that agrees adds a little trust, capped so a
      // corroborated read can reach — but not exceed — a verified one.
      final corroboration = (group.length - 1) * 0.08;
      final score = (top.confidence + corroboration).clamp(0.0, 0.98);
      if (score > bestScore) {
        bestScore = score;
        best = top.copyWith(confidence: score);
      }
    }
    return best ?? candidates.first;
  }

  /// Normalizes a value for cross-page comparison — case/spacing/punctuation
  /// insensitive so "Ravi Sharma" and "RAVI  SHARMA" count as agreement.
  String _valueKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // ---------------------------------------------------------------------------
  // Main parse entry point
  // ---------------------------------------------------------------------------
  ParseResult parse(String rawText) {
    final text = _normalize(rawText);
    final category = detectCategory(text);
    final fields = <ExtractedField>[];
    final confidences = <double>[];

    // === Universal extractors (run for ALL document types) ===
    _parseName(text, fields, confidences);
    _parseFatherName(text, fields, confidences);
    _parseDob(text, fields, confidences);
    _parseGender(text, fields, confidences);
    _parseAddress(text, fields, confidences);
    _parseCareOf(text, fields, confidences);
    _parseState(text, fields, confidences);
    _parsePhone(text, fields, confidences);
    _parseEmail(text, fields, confidences);
    _parsePinCode(text, fields, confidences);

    // === Identity document numbers (run universally — patterns are specific) ===
    _parseAadhaar(text, fields, confidences);
    _parsePan(text, fields, confidences);
    _parseVoterId(text, fields, confidences);
    _parseDrivingLicense(text, fields, confidences);
    _parseVehicleRc(text, fields, confidences);
    _parsePassport(text, fields, confidences);

    // === Category-specific extractors ===
    switch (category) {
      case DocumentCategory.education:
        _parseEducation(text, fields, confidences);
        break;
      case DocumentCategory.identity:
      case DocumentCategory.travel:
      case DocumentCategory.finance:
      case DocumentCategory.medical:
      case DocumentCategory.family:
      case DocumentCategory.other:
        break;
    }

    // Deduplicate by label
    _deduplicate(fields, confidences);

    if (fields.isEmpty && rawText.trim().isNotEmpty) {
      _fallbackFields(text, fields, confidences);
    }

    final overallConfidence = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length;

    final detectedType = _detectSpecificType(text, fields);

    return ParseResult(
      category: category,
      documentType: category.label,
      detectedType: detectedType,
      fields: fields,
      overallConfidence: overallConfidence,
    );
  }

  /// Determine the specific document type (e.g. "Aadhaar Card", "PAN Card",
  /// "SSLC Marks Memo") based on extracted fields and text content.
  String _detectSpecificType(String text, List<ExtractedField> fields) {
    final fieldLabels = fields.map((f) => f.label).toSet();
    final n = _normalize(text).toUpperCase();

    // --- Identity ---
    if (fieldLabels.contains('Aadhaar Number')) return 'Aadhaar Card';
    if (fieldLabels.contains('PAN Number')) return 'PAN Card';
    if (fieldLabels.contains('Voter ID (EPIC)') ||
        _textContains(n, 'ELECTION') ||
        _textContains(n, 'VOTER ID'))
      return 'Voter ID';
    if (fieldLabels.contains('Driving License') ||
        _textContains(n, 'DRIVING LICENCE'))
      return 'Driving License';
    if (fieldLabels.contains('Passport Number') || _textContains(n, 'PASSPORT'))
      return 'Passport';
    if (fieldLabels.contains('Vehicle Number') || _textContains(n, 'RC BOOK'))
      return 'Vehicle RC';
    if (_textContains(n, 'BIRTH') && _textContains(n, 'CERTIFICATE'))
      return 'Birth Certificate';
    if (_textContains(n, 'CASTE')) return 'Caste Certificate';
    if (fieldLabels.contains('Aadhaar Number')) return 'Aadhaar Card';

    // --- Education ---
    if (_textContains(n, 'MARKSHEET') ||
        _textContains(n, 'MARKS MEMO') ||
        _textContains(n, 'GRADE CARD') ||
        _textContains(n, 'GRADE SHEET') ||
        _textContains(n, 'REPORT CARD')) {
      if (_textContains(n, 'SSLC') || _textContains(n, '10TH'))
        return 'SSLC Marks Card';
      if (_textContains(n, 'HSC') || _textContains(n, '12TH'))
        return 'HSC Marks Card';
      if (fieldLabels.contains('Degree')) return 'Degree Marks Sheet';
      return 'Marks Memo';
    }
    if (_textContains(n, 'SSLC') || _textContains(n, '10TH'))
      return 'SSLC Certificate';
    if (_textContains(n, 'HSC') || _textContains(n, '12TH'))
      return 'HSC Certificate';
    if (_textContains(n, 'DEGREE') ||
        _textContains(n, 'B.TECH') ||
        _textContains(n, 'BACHELOR'))
      return 'Degree Certificate';
    if (_textContains(n, 'DIPLOMA')) return 'Diploma Certificate';
    if (_textContains(n, 'TRANSCRIPT')) return 'Transcript';
    if (_textContains(n, 'CBSE') || _textContains(n, 'ICSE'))
      return 'Board Certificate';

    // --- Finance ---
    if (_textContains(n, 'ITR') || _textContains(n, 'INCOME TAX'))
      return 'Income Tax Return';
    if (_textContains(n, 'FORM 16')) return 'Form 16';
    if (_textContains(n, 'PAYSLIP') || _textContains(n, 'SALARY SLIP'))
      return 'Salary Slip';
    if (_textContains(n, 'BANK STATEMENT')) return 'Bank Statement';
    if (_textContains(n, 'INSURANCE')) return 'Insurance Document';
    if (_textContains(n, 'INCOME CERTIFICATE')) return 'Income Certificate';

    // --- Travel ---
    if (_textContains(n, 'VISA')) return 'Visa';

    // --- Family ---
    if (_textContains(n, 'RATION')) return 'Ration Card';
    if (_textContains(n, 'MARRIAGE')) return 'Marriage Certificate';

    // --- Medical ---
    if (_textContains(n, 'PRESCRIPTION')) return 'Prescription';
    if (_textContains(n, 'LAB REPORT') || _textContains(n, 'LAB'))
      return 'Lab Report';

    // --- Property ---
    if (_textContains(n, 'SALE DEED')) return 'Sale Deed';

    // --- Fallback based on first extracted field source ---
    for (final f in fields) {
      if (f.sourceDocument.isNotEmpty) return f.sourceDocument;
    }

    return '';
  }

  // ---------------------------------------------------------------------------
  // Aadhaar number (12 digits)
  // ---------------------------------------------------------------------------
  void _parseAadhaar(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final upper = text.toUpperCase();
    final hasAadhaarLabel =
        _textContains(upper, 'AADHAAR') || _textContains(upper, 'UIDAI');

    // Standard 4-4-4 display format (highest confidence)
    final standardMatch = RegExp(
      r'\b\d{4}\s{0,2}\d{4}\s{0,2}\d{4}\b',
    ).firstMatch(text);
    if (standardMatch != null) {
      final raw = standardMatch.group(0)!;
      final cleaned = raw.replaceAll(' ', '');
      if (cleaned.length == 12 &&
          !cleaned.startsWith('0') &&
          !cleaned.startsWith('1')) {
        fields.add(
          ExtractedField(
            label: 'Aadhaar Number',
            value: raw,
            confidence: hasAadhaarLabel ? 0.97 : 0.8,
            sourceDocument: 'Aadhaar Card',
          ),
        );
        confidences.add(hasAadhaarLabel ? 0.97 : 0.8);
        return;
      }
    }

    // Digits-only extraction — ONLY if Aadhaar label is present in text
    if (hasAadhaarLabel) {
      final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
      for (var i = 0; i <= digitsOnly.length - 12; i++) {
        final candidate = digitsOnly.substring(i, i + 12);
        if (!candidate.startsWith('0') && !candidate.startsWith('1')) {
          final formatted =
              '${candidate.substring(0, 4)} ${candidate.substring(4, 8)} ${candidate.substring(8, 12)}';
          fields.add(
            ExtractedField(
              label: 'Aadhaar Number',
              value: formatted,
              confidence: 0.85,
              sourceDocument: 'Aadhaar Card',
            ),
          );
          confidences.add(0.85);
          return;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PAN number (5 letters + 4 digits + 1 letter)
  // ---------------------------------------------------------------------------
  void _parsePan(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final standard = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b').firstMatch(text);
    if (standard != null) {
      fields.add(
        ExtractedField(
          label: 'PAN Number',
          value: standard.group(0)!,
          confidence: 0.97,
          sourceDocument: 'PAN Card',
        ),
      );
      confidences.add(0.97);
      return;
    }

    final fuzzy = RegExp(
      r'\b([A-Z0O5S8B]{5}\d{4}[A-Z0O5S8B])\b',
    ).firstMatch(text);
    if (fuzzy != null) {
      String raw = fuzzy.group(0)!;
      raw = raw.replaceAll('0', 'O').replaceAll('5', 'S').replaceAll('8', 'B');
      if (RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(raw)) {
        fields.add(
          ExtractedField(
            label: 'PAN Number',
            value: raw,
            confidence: 0.85,
            sourceDocument: 'PAN Card',
          ),
        );
        confidences.add(0.85);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Voter ID (EPIC) number (3 letters + 7 digits)
  // ---------------------------------------------------------------------------
  void _parseVoterId(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final match = RegExp(r'\b[A-Z]{3}\d{7}\b').firstMatch(text);
    if (match != null) {
      fields.add(
        ExtractedField(
          label: 'Voter ID (EPIC)',
          value: match.group(0)!,
          confidence: 0.92,
          sourceDocument: 'Voter ID',
        ),
      );
      confidences.add(0.92);
    }
  }

  // ---------------------------------------------------------------------------
  // Driving License number (state + RTO + year + serial)
  // ---------------------------------------------------------------------------
  void _parseDrivingLicense(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    // Common format: HR06 2011 1234567 or HR-06-2011-1234567
    final match = RegExp(
      r'\b([A-Z]{2}\d{2})\s?(\d{4})\s?(\d{7})\b',
    ).firstMatch(text);
    if (match != null) {
      final value = '${match.group(1)} ${match.group(2)} ${match.group(3)}';
      fields.add(
        ExtractedField(
          label: 'Driving License',
          value: value,
          confidence: 0.9,
          sourceDocument: 'Driving License',
        ),
      );
      confidences.add(0.9);
    }
  }

  // ---------------------------------------------------------------------------
  // Vehicle Registration Certificate number
  // ---------------------------------------------------------------------------
  void _parseVehicleRc(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    // Format: KL-07-AB-1234 or KL07AB1234
    final match = RegExp(
      r'\b([A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,4})\b',
    ).firstMatch(text);
    if (match != null) {
      fields.add(
        ExtractedField(
          label: 'Vehicle Number',
          value: match.group(0)!,
          confidence: 0.88,
          sourceDocument: 'Vehicle RC',
        ),
      );
      confidences.add(0.88);
    }
  }

  // ---------------------------------------------------------------------------
  // Passport number
  // ---------------------------------------------------------------------------
  void _parsePassport(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final match = RegExp(r'\b[A-Z]\d{7}\b').firstMatch(text);
    if (match != null) {
      fields.add(
        ExtractedField(
          label: 'Passport Number',
          value: match.group(0)!,
          confidence: 0.95,
          sourceDocument: 'Passport',
        ),
      );
      confidences.add(0.95);
    }
  }

  // ---------------------------------------------------------------------------
  // Phone number (10-digit Indian mobile)
  // ---------------------------------------------------------------------------
  void _parsePhone(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labels = ['Phone', 'Mobile', 'Contact', 'मोबाइल', 'फोन'];
    final labeled = _extractLabeledValue(text, labels);
    if (labeled != null) {
      final digits = labeled.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length == 10) {
        fields.add(
          ExtractedField(
            label: 'Phone Number',
            value: digits,
            confidence: 0.88,
          ),
        );
        confidences.add(0.88);
        return;
      }
    }

    // Fallback: find standalone 10-digit number
    final match = RegExp(r'\b[6-9]\d{9}\b').firstMatch(text);
    if (match != null) {
      fields.add(
        ExtractedField(
          label: 'Phone Number',
          value: match.group(0)!,
          confidence: 0.75,
        ),
      );
      confidences.add(0.75);
    }
  }

  // ---------------------------------------------------------------------------
  // Email address
  // ---------------------------------------------------------------------------
  void _parseEmail(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final match = RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b').firstMatch(text);
    if (match != null) {
      fields.add(
        ExtractedField(label: 'Email', value: match.group(0)!, confidence: 0.9),
      );
      confidences.add(0.9);
    }
  }

  // ---------------------------------------------------------------------------
  // PIN code (6 digits)
  // ---------------------------------------------------------------------------
  void _parsePinCode(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labels = ['PIN', 'Pincode', 'Pin Code', 'Postal', 'ZIP'];
    final labeled = _extractLabeledValue(text, labels);
    if (labeled != null) {
      final digits = labeled.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length == 6) {
        fields.add(
          ExtractedField(label: 'PIN Code', value: digits, confidence: 0.88),
        );
        confidences.add(0.88);
        return;
      }
    }

    // Fallback: standalone 6-digit number (conservative — avoid matching years)
    final match = RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)').firstMatch(text);
    if (match != null) {
      final val = match.group(1)!;
      // Exclude values that look like years (1900-2099)
      if (!RegExp(r'^(19|20)\d{2}$').hasMatch(val)) {
        fields.add(
          ExtractedField(label: 'PIN Code', value: val, confidence: 0.65),
        );
        confidences.add(0.65);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Name extraction (supports ALL CAPS, labels, S/O D/O W/O patterns)
  // ---------------------------------------------------------------------------
  void _parseName(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final nameLabels = [
      'Name',
      'नाम',
      'Applicant Name',
      'Full Name',
      'Employee Name',
      'Student Name',
      "Student'S Name",
      'Candidate Name',
      'Candidate',
      'Holder Name',
      'Card Holder',
      'Cardholder',
      'Owner',
      'Party Name',
    ];

    // Get name candidates from different methods for cross-validation
    String? labeledName;
    String? allCapsName;
    String? soName;

    // 1) Labeled extraction
    final labeled = _extractLabeledValue(text, nameLabels);
    if (labeled != null && labeled.length > 2 && !_containsDigit(labeled)) {
      final cleaned = _cleanName(labeled);
      if (!_looksLikeDocumentType(cleaned)) {
        labeledName = cleaned;
      }
    }

    // 2) S/O D/O W/O pattern
    final soMatch = RegExp(
      r'^(.*?)\s+(S/O|D/O|W/O|S/o|D/o|W/o|s/o|d/o|w/o)\s+',
      multiLine: true,
    ).firstMatch(text);
    if (soMatch != null) {
      final name = soMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && name.length > 2) {
        soName = _cleanName(name);
      }
    }

    // 3) ALL-CAPS name
    allCapsName = _findAllCapsName(text);

    // --- Cross-validation ---
    // Pick the best name and calculate confidence
    String? bestName;
    double confidence = 0.0;

    if (labeledName != null && allCapsName != null) {
      if (_namesMatch(labeledName, allCapsName)) {
        bestName = labeledName;
        confidence = 0.88;
      } else {
        bestName = labeledName.length >= allCapsName.length
            ? labeledName
            : allCapsName;
        confidence = 0.65;
      }
    } else if (soName != null && labeledName != null) {
      if (_namesMatch(soName, labeledName)) {
        bestName = labeledName;
        confidence = 0.85;
      } else {
        bestName = labeledName.length >= soName.length ? labeledName : soName;
        confidence = 0.7;
      }
    } else if (labeledName != null) {
      bestName = labeledName;
      confidence = 0.88;
    } else if (soName != null) {
      bestName = soName;
      confidence = 0.85;
    } else if (allCapsName != null) {
      bestName = allCapsName;
      confidence = 0.7;
    }

    // Penalize confidence if any name part is suspiciously short (≤ 2 chars)
    // which often indicates OCR truncation (e.g. "SAI" → "SA")
    if (bestName != null) {
      final parts = bestName.split(RegExp(r'\s+'));
      if (parts.any((p) => p.length <= 2 && parts.length >= 2)) {
        confidence = (confidence - 0.15).clamp(0.0, 1.0);
      }
    }

    if (bestName != null) {
      fields.add(
        ExtractedField(
          label: 'Full Name',
          value: bestName,
          confidence: confidence,
        ),
      );
      confidences.add(confidence);
      return;
    }

    // 4) Generic label-based fallback
    final generic = RegExp(
      r'(?:Name|नाम)\s*[:\-]\s*(.+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (generic != null) {
      final name = generic.group(1)?.trim() ?? '';
      if (name.isNotEmpty && name.length > 3 && !RegExp(r'\d').hasMatch(name)) {
        fields.add(
          ExtractedField(label: 'Full Name', value: name, confidence: 0.85),
        );
        confidences.add(0.85);
      }
    }
  }

  /// Compare two names to see if they're essentially the same person's name.
  bool _namesMatch(String a, String b) {
    final aNorm = a.toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), '').trim();
    final bNorm = b.toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), '').trim();
    if (aNorm == bNorm) return true;
    // One may be a substring of the other (OCR truncation like "SAI" → "SA")
    if (aNorm.startsWith(bNorm) || bNorm.startsWith(aNorm)) {
      // Only accept if the extra chars are at the end
      final shorter = aNorm.length <= bNorm.length ? aNorm : bNorm;
      final longer = aNorm.length > bNorm.length ? aNorm : bNorm;
      return longer.startsWith(shorter) && longer.length - shorter.length <= 3;
    }
    return false;
  }

  String? _findAllCapsName(String text) {
    final skipWords = [
      'GOVT',
      'GOVERNMENT',
      'INDIA',
      'INCOME TAX',
      'DEPARTMENT',
      'PERMANENT',
      'ELECTION',
      'VOTER',
      'EPIC',
      'DRIVING',
      'LICENCE',
      'LICENSE',
      'AADHAAR',
      'UIDAI',
      'PASSPORT',
      'BIRTH',
      'CERTIFICATE',
      'UNIVERSITY',
      'BOARD',
      'SCHOOL',
      'COLLEGE',
      'MARKS',
      'TOTAL',
      'GRADE',
      'RESULT',
      'SSLC',
      'HSC',
      'CBSE',
      'ICSE',
      'SECTION',
      'FATHER',
      'MOTHER',
      'SPOUSE',
      'HUSBAND',
      'WIFE',
      'ADDRESS',
      'STATE',
      'DIST',
      'DISTRICT',
      'PIN',
      'CODE',
    ];

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length < 5 || trimmed.length > 50) continue;
      if (!RegExp(r'^[A-Z][A-Z .\-]+$').hasMatch(trimmed)) continue;
      final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.length > 1);
      if (parts.length < 2) continue;
      if (RegExp(r'\d').hasMatch(trimmed)) continue;
      if (skipWords.any((w) => _textContains(trimmed, w))) continue;
      return _toTitleCase(trimmed);
    }
    return null;
  }

  String _toTitleCase(String value) {
    return value
        .split(' ')
        .map((word) {
          if (word.length <= 2) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Father's Name
  // ---------------------------------------------------------------------------
  void _parseFatherName(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labels = [
      "Father's Name",
      'Father Name',
      'पिता का नाम',
      "Father'S Name",
      'FATHER NAME',
    ];

    // 1) Labeled extraction (now handles labels at end-of-line thanks to
    //    _extractLabeledValue's third attempt)
    final labeled = _extractLabeledValue(text, labels);
    if (labeled != null && labeled.length > 2 && !_containsDigit(labeled)) {
      final cleaned = _cleanName(labeled);
      // Sanity check: father's name should not look like a document type header
      if (!_looksLikeDocumentType(cleaned)) {
        fields.add(
          ExtractedField(
            label: "Father's Name",
            value: cleaned,
            confidence: 0.88,
          ),
        );
        confidences.add(0.88);
        return;
      }
    }

    // 2) S/O D/O W/O pattern — extract the name after the prefix
    final soMatch = RegExp(
      r'S/O\s+(.+?)(?:\s*$|\s+D/O|\s+W/O)',
      caseSensitive: false,
    ).firstMatch(text);
    if (soMatch != null) {
      final name = soMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && name.length > 2) {
        final cleaned = _cleanName(name);
        if (!_looksLikeDocumentType(cleaned)) {
          fields.add(
            ExtractedField(
              label: "Father's Name",
              value: cleaned,
              confidence: 0.85,
            ),
          );
          confidences.add(0.85);
          return;
        }
      }
    }

    // 3) PAN card layout: look for father-related label ANYWHERE in the text,
    //    then pick the next non-empty line that doesn't look like a header.
    //    This handles cases like "पिता का नाम। Father's Name" on one line and
    //    "SIVA SURYA PRAKASH PONNADA" on the next.
    final fatherLabels = [
      "FATHER'S NAME",
      'FATHER NAME',
      'पिता का नाम',
      'FATHER',
      'F/S/D',
      'S/O',
      'D/O',
      'W/O',
    ];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toUpperCase();
      final hasFatherLabel = fatherLabels.any(
        (l) => line.contains(l.toUpperCase()),
      );
      if (!hasFatherLabel) continue;
      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty &&
            next.length > 3 &&
            !_containsDigit(next) &&
            !next.contains(RegExp(r'[:]\s*$')) &&
            !_looksLikeDocumentType(next) &&
            !RegExp(
              r'^(DOB|Date|Gender|Address|पता|Signature|हस्ताक्षर)',
              caseSensitive: false,
            ).hasMatch(next)) {
          fields.add(
            ExtractedField(
              label: "Father's Name",
              value: _cleanName(next),
              confidence: 0.75,
            ),
          );
          confidences.add(0.75);
          return;
        }
      }
    }

    // 4) Legacy PAN card layout: Name line → next non-header line → DOB line
    final nameIdx = fields.indexWhere((f) => f.label == 'Full Name');
    if (nameIdx >= 0) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim() == fields[nameIdx].value) {
          if (i + 1 < lines.length) {
            final next = lines[i + 1].trim();
            if (next.isNotEmpty &&
                next.length > 3 &&
                !_containsDigit(next) &&
                !next.contains(RegExp(r'[:]\s*$')) &&
                !_looksLikeDocumentType(next) &&
                !RegExp(
                  r'^(DOB|Date|Gender|Address|पता)',
                  caseSensitive: false,
                ).hasMatch(next)) {
              fields.add(
                ExtractedField(
                  label: "Father's Name",
                  value: _cleanName(next),
                  confidence: 0.65,
                ),
              );
              confidences.add(0.65);
              return;
            }
          }
        }
      }
    }
  }

  /// Heuristic: check if a string looks like a document-type header rather than
  /// a person's name (e.g. "Permanent Account Number Card", "Aadhaar Card").
  bool _looksLikeDocumentType(String value) {
    final v = value.toUpperCase();
    final docKeywords = [
      'ACCOUNT NUMBER',
      'PERMANENT',
      'AADHAAR',
      'VOTER',
      'DRIVING',
      'LICENCE',
      'LICENSE',
      'PASSPORT',
      'CARD',
      'CERTIFICATE',
      'INCOME TAX',
      'GOVT',
      'GOVERNMENT',
      'INDIA',
      'DEPARTMENT',
      'ELECTION',
      'MARKS',
      'GRADE',
      'UNIVERSITY',
      'BOARD',
      'SCHOOL',
      'COLLEGE',
    ];
    return docKeywords.any((kw) => v.contains(kw));
  }

  // ---------------------------------------------------------------------------
  // Date of Birth
  // ---------------------------------------------------------------------------
  static const _dobLabels = [
    'DOB',
    'Date of Birth',
    'Birth',
    'जन्म',
    'D.O.B',
    'BIRTH',
  ];

  /// Indian documents print dates as DD/MM/YYYY — reject anything that
  /// can't plausibly be a birth date so a garbled OCR read (or the wrong
  /// date on the page, e.g. an issue/expiry date) doesn't get accepted
  /// silently. This was the direct cause of "DOB extracted incorrectly":
  /// the old fallback took the *first* date-shaped string anywhere in the
  /// document with no validation at all.
  (int, int, int)? _validDob(String raw) {
    final m = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    var year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += (year <= DateTime.now().year % 100) ? 2000 : 1900;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    if (year < 1900 || year > DateTime.now().year) return null;
    try {
      // Catches "31/02/1995"-style dates that pass the range checks above
      // but aren't real calendar dates.
      final d = DateTime(year, month, day);
      if (d.month != month || d.day != day) return null;
    } catch (_) {
      return null;
    }
    return (day, month, year);
  }

  void _parseDob(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labeled = _extractLabeledValue(text, _dobLabels);
    if (labeled != null) {
      final dateMatch = RegExp(
        r'(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
      ).firstMatch(labeled);
      if (dateMatch != null && _validDob(dateMatch.group(1)!) != null) {
        fields.add(
          ExtractedField(
            label: 'Date of Birth',
            value: dateMatch.group(1)!,
            confidence: 0.9,
          ),
        );
        confidences.add(0.9);
        return;
      }
    }

    // Fallback: search near a DOB-ish label first (same or next line) so a
    // document with several dates printed on it — issue date, validity,
    // enrollment — doesn't get the wrong one picked just because it comes
    // first in reading order.
    final lines = text.split('\n');
    final dateRe = RegExp(r'\b(\d{1,2}[/\-.]\d{1,2}[/\-.](?:\d{4}|\d{2}))\b');
    for (var i = 0; i < lines.length; i++) {
      final hasLabel = _dobLabels.any(
        (l) => lines[i].toUpperCase().contains(l.toUpperCase()),
      );
      if (!hasLabel) continue;
      for (final line in [lines[i], if (i + 1 < lines.length) lines[i + 1]]) {
        final match = dateRe.firstMatch(line);
        if (match != null && _validDob(match.group(1)!) != null) {
          fields.add(
            ExtractedField(
              label: 'Date of Birth',
              value: match.group(1)!,
              confidence: 0.82,
            ),
          );
          confidences.add(0.82);
          return;
        }
      }
    }

    // Last resort: first *plausible* date anywhere, lower confidence since
    // we can no longer be sure it's actually the birth date.
    for (final match in dateRe.allMatches(text)) {
      if (_validDob(match.group(1)!) != null) {
        fields.add(
          ExtractedField(
            label: 'Date of Birth',
            value: match.group(1)!,
            confidence: 0.55,
          ),
        );
        confidences.add(0.55);
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Gender
  // ---------------------------------------------------------------------------
  void _parseGender(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labels = ['Gender', 'Sex', 'लिंग'];
    final labeled = _extractLabeledValue(text, labels);
    if (labeled != null) {
      final value = _cleanGender(labeled);
      if (value != null) {
        fields.add(
          ExtractedField(label: 'Gender', value: value, confidence: 0.9),
        );
        confidences.add(0.9);
        return;
      }
    }

    for (final g in ['Male', 'Female', 'पुरुष', 'महिला']) {
      if (text.contains(g)) {
        fields.add(
          ExtractedField(
            label: 'Gender',
            value: g.contains('पुरुष')
                ? 'Male'
                : g.contains('महिला')
                ? 'Female'
                : g,
            confidence: 0.75,
          ),
        );
        confidences.add(0.75);
        return;
      }
    }
  }

  String? _cleanGender(String raw) {
    final cleaned = raw.trim();
    if (RegExp(r'^M(ale)?$', caseSensitive: false).hasMatch(cleaned))
      return 'Male';
    if (RegExp(r'^F(emale)?$', caseSensitive: false).hasMatch(cleaned))
      return 'Female';
    if (RegExp(r'^O(ther)?$', caseSensitive: false).hasMatch(cleaned))
      return 'Other';
    if (cleaned.contains('पुरुष')) return 'Male';
    if (cleaned.contains('महिला')) return 'Female';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Address
  // ---------------------------------------------------------------------------
  static const _otherFieldLabels = [
    'DOB',
    'Date of Birth',
    'Gender',
    'Sex',
    'Mobile',
    'Phone',
    'Aadhaar',
    'VID',
    'PAN',
    'Signature',
    'Email',
  ];

  void _parseAddress(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final labels = ['Address', 'पता', 'Add'];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final isLabelLine = labels.any(
        (l) => RegExp(
          '^${RegExp.escape(l)}\\s*[:.\\-–—]?\\s*',
          caseSensitive: false,
        ).hasMatch(line),
      );
      if (!isLabelLine) continue;

      // Same-line value ("Address: 12 MG Road, ...") starts the block;
      // otherwise the block starts on the next line.
      final sameLine = line.replaceFirst(
        RegExp('^(${labels.map(RegExp.escape).join('|')})\\s*[:.\\-–—]?\\s*',
            caseSensitive: false),
        '',
      );
      final blockLines = <String>[if (sameLine.trim().isNotEmpty) sameLine.trim()];

      // Keep consuming lines until a PIN code (Indian addresses end in one),
      // a blank line, or another known field's label — real multi-line
      // addresses were getting cut after their first line before this.
      var j = i + 1;
      while (j < lines.length && blockLines.length < 6) {
        final next = lines[j].trim();
        if (next.isEmpty) break;
        if (_otherFieldLabels.any(
          (l) => next.toUpperCase().startsWith(l.toUpperCase()),
        )) {
          break;
        }
        blockLines.add(next);
        if (RegExp(r'\b\d{6}\b').hasMatch(next)) {
          j++;
          break;
        }
        j++;
      }

      final addr = blockLines.join(', ').trim();
      if (addr.length > 3) {
        fields.add(
          ExtractedField(label: 'Address', value: addr, confidence: 0.82),
        );
        confidences.add(0.82);
        return;
      }
    }
  }

  static const _careOfLabels = ['C/O', 'S/O', 'D/O', 'W/O', 'Care of'];

  void _parseCareOf(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    for (final label in _careOfLabels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.\\-–—]?\\s*([A-Za-z][A-Za-z .]{2,60})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final value = match.group(1)!.trim();
        if (value.isNotEmpty) {
          fields.add(
            ExtractedField(label: "Care Of", value: value, confidence: 0.78),
          );
          confidences.add(0.78);
          return;
        }
      }
    }
  }

  static const _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan',
    'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh',
    'Uttarakhand', 'West Bengal', 'Andaman and Nicobar', 'Chandigarh',
    'Dadra and Nagar Haveli', 'Daman and Diu', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  /// India has a fixed, small set of states/UTs, which makes this a
  /// reliable lookup — unlike districts (thousands of names, no closed
  /// set), state is worth extracting as its own field.
  void _parseState(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    for (final state in _indianStates) {
      if (RegExp(
        '\\b${RegExp.escape(state)}\\b',
        caseSensitive: false,
      ).hasMatch(text)) {
        fields.add(
          ExtractedField(label: 'State', value: state, confidence: 0.85),
        );
        confidences.add(0.85);
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Education document fields (marks memos, report cards, degrees)
  // ---------------------------------------------------------------------------
  void _parseEducation(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    // --- Roll Number ---
    _tryExtract(
      fields,
      confidences,
      'Roll Number',
      [
        r'(?:Roll No|Roll Number|Registration|Enrollment|Exam Roll)\s*[:\-]\s*(\S+)',
        r'(?:Roll No|Roll Number|Registration|Enrollment)\s{2,}(\S+)',
      ],
      text,
      0.88,
    );

    // --- Degree / Course ---
    _tryExtract(
      fields,
      confidences,
      'Degree',
      [r'(?:Degree|Course|Program)\s*[:\-]\s*(.+)'],
      text,
      0.85,
    );

    // --- University / Board / Institute ---
    _tryExtract(
      fields,
      confidences,
      'University',
      [r'(?:University|College|Institute|Board|School)\s*[:\-]\s*(.+)'],
      text,
      0.85,
    );

    // --- Exam Name (B.Tech 4th Sem, SSLC, HSC, etc.) ---
    _tryExtract(
      fields,
      confidences,
      'Exam Name',
      [
        r'(?:Examination|Exam|Semester|Term)\s*[:\-]\s*(.+)',
        r'(?:B\.?TECH|B\.?E|M\.?TECH|MBA|BCA|BSC|MSC|BA|MA|BCOM|MCOM)\s+[\dA-Za-z]+\s+(?:Semester|Year|Term)',
        r'^(SSLC|SSC|HSC|10TH|12TH|CBSE|ICSE)\b',
      ],
      text,
      0.82,
    );

    // --- Year of Passing / Session ---
    _tryExtract(
      fields,
      confidences,
      'Year',
      [
        r'(?:Year|Passing|Session|Academic)\s*[:\-]\s*(\d{4})',
        r'(?:Year|Passing|Session|Academic)\s+(\d{4})',
      ],
      text,
      0.85,
    );

    // --- Board (CBSE, ICSE, State Board name) ---
    _tryExtract(
      fields,
      confidences,
      'Board',
      [r'(?:Board|Board of)\s*[:\-]\s*(.+)', r'^(CBSE|ICSE|IGCSE|IB)\b'],
      text,
      0.85,
    );

    // --- Total Marks / Max Marks ---
    _tryExtract(
      fields,
      confidences,
      'Total Marks',
      [
        r'(?:Total|Grand Total|Aggregate)\s*[:\-]?\s*(\d{1,4})\s*/\s*(\d{1,4})',
        r'(?:Total|Grand Total|Aggregate)\s*[:\-]?\s*(\d{1,4})\s*(?:out\s*of|OF)\s*(\d{1,4})',
        r'(?:Total|Grand Total|Aggregate)\s*[:\-]?\s*(\d{1,4})',
      ],
      text,
      0.85,
    );

    // --- Percentage / CGPA / Grade ---
    _tryExtract(
      fields,
      confidences,
      'Percentage',
      [
        r'(?:Percentage|CGPA|Grade|GPA)\s*[:\-]\s*([\d.]+)\s*%?',
        r'(?:Percentage|CGPA|Grade|GPA)\s+([\d.]+)\s*%?',
      ],
      text,
      0.85,
    );

    // --- Result (Pass/Fail / Division / Class) ---
    _tryExtract(
      fields,
      confidences,
      'Result',
      [
        r'(?:Result|Status)\s*[:\-]\s*(.+)',
        r'^(PASS|FAIL|PASSED|FAILED|COMPARTMENT)\b',
        r'(?:First|Second|Third)\s+(?:Class|Division)',
        r'(?:DISTINCTION|MERIT)',
      ],
      text,
      0.85,
    );

    // --- Student Name via label ---
    final studentName = _extractLabeledValue(text, [
      'Student Name',
      "Student'S Name",
      'Candidate Name',
      "Candidate'S Name",
      'Name of the Student',
    ]);
    if (studentName != null && studentName.length > 2) {
      fields.add(
        ExtractedField(
          label: 'Student Name',
          value: _cleanName(studentName),
          confidence: 0.88,
          sourceDocument: 'Education Document',
        ),
      );
      confidences.add(0.88);
    }

    // --- Subjects with marks (marks memo specific) ---
    _parseSubjectMarks(lines, fields, confidences);
  }

  void _parseSubjectMarks(
    List<String> lines,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    // Look for lines matching: "Subject Name : 85 / 100" or "Subject 85 100"
    final subjectPattern = RegExp(
      r'^([A-Za-z][A-Za-z\s/&-]+?)\s*[:\-]?\s*(\d{1,3})\s*[/\s]\s*(\d{1,3})\s*$',
    );
    var subjectCount = 0;

    for (final line in lines) {
      if (subjectCount >= 8) break;
      final match = subjectPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final obtained = match.group(2)!;
        final max = match.group(3)!;
        // Skip if the "name" looks like a header/label
        if (RegExp(
          r'^(max|min|total|marks|subject|grade|obtained|pass)',
          caseSensitive: false,
        ).hasMatch(name))
          continue;
        fields.add(
          ExtractedField(
            label: name,
            value: '$obtained / $max',
            confidence: 0.8,
            sourceDocument: 'Marks Memo',
          ),
        );
        confidences.add(0.8);
        subjectCount++;
      }
    }

    // If subjects found, add a separator-like total
    if (subjectCount > 0) {
      // Check for a total line
      for (final line in lines) {
        final totalMatch = RegExp(
          r'(?:Total|Grand Total|Aggregate)\s*[:\-]?\s*(\d{1,4})\s*[/\s]\s*(\d{1,4})',
          caseSensitive: false,
        ).firstMatch(line);
        if (totalMatch != null) {
          // Already handled above, skip
          break;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Fallback
  // ---------------------------------------------------------------------------
  void _fallbackFields(
    String text,
    List<ExtractedField> fields,
    List<double> confidences,
  ) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(8)
        .toList();

    for (final line in lines) {
      final label = _inferLabel(line);
      fields.add(ExtractedField(label: label, value: line, confidence: 0.5));
      confidences.add(0.5);
    }
  }

  String _inferLabel(String line) {
    if (RegExp(r'^[A-Z][A-Z .\-]{4,40}$').hasMatch(line) &&
        line.split(RegExp(r'\s+')).length >= 2) {
      return 'Possible Name';
    }
    if (RegExp(r'\b\d{2}[/\-\.]\d{2}[/\-\.]\d{2,4}\b').hasMatch(line)) {
      return 'Possible Date';
    }
    if (RegExp(r'\b\d{12}\b').hasMatch(line.replaceAll(' ', ''))) {
      return 'Possible Aadhaar';
    }
    if (RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b').hasMatch(line)) {
      return 'Possible PAN';
    }
    if (RegExp(r'\b[A-Z]{3}\d{7}\b').hasMatch(line)) {
      return 'Possible Voter ID';
    }
    if (RegExp(r'\b[A-Z]{2}\d{2}\s?\d{4}\s?\d{7}\b').hasMatch(line)) {
      return 'Possible Driving License';
    }
    if (RegExp(r'\b\d{6}\s?\d{5,7}\b').hasMatch(line)) {
      return 'Possible PIN';
    }
    if (RegExp(r'\b[6-9]\d{9}\b').hasMatch(line)) {
      return 'Possible Phone';
    }
    if (RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b').hasMatch(line)) {
      return 'Possible Email';
    }
    if (RegExp(r'\b\d{1,3}\s*/\s*\d{1,3}\b').hasMatch(line)) {
      return 'Possible Marks';
    }
    return _truncateLabel(line);
  }

  String _truncateLabel(String line) {
    final words = line.split(RegExp(r'\s+'));
    if (words.isEmpty) return 'Content';
    final preview = words.take(5).join(' ');
    return preview.length > 40 ? '${preview.substring(0, 40)}...' : preview;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  bool _containsDigit(String s) => RegExp(r'\d').hasMatch(s);

  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'[,;.\s]+$'), '').trim();
  }

  void _tryExtract(
    List<ExtractedField> fields,
    List<double> confidences,
    String label,
    List<String> patterns,
    String text,
    double confidence,
  ) {
    for (final pattern in patterns) {
      final match = RegExp(
        pattern,
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(text);
      if (match != null) {
        final value = match.groupCount >= 2
            ? '${match.group(1)} / ${match.group(2)}'
            : match.group(1)?.trim() ?? match.group(0)!.trim();
        if (value.isNotEmpty) {
          fields.add(
            ExtractedField(
              label: label,
              value: value,
              confidence: confidence,
              sourceDocument: 'Education Document',
            ),
          );
          confidences.add(confidence);
        }
        return;
      }
    }
  }

  /// Keep only the first occurrence of each label (removes duplicates from
  /// multiple parsers matching the same field).
  void _deduplicate(List<ExtractedField> fields, List<double> confidences) {
    final seen = <String>{};
    var i = 0;
    while (i < fields.length) {
      if (seen.contains(fields[i].label)) {
        fields.removeAt(i);
        if (i < confidences.length) confidences.removeAt(i);
      } else {
        seen.add(fields[i].label);
        i++;
      }
    }
  }
}
