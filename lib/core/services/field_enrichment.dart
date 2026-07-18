import '../models/document_model.dart';
import 'search_service.dart';

/// Entities pulled from OCR text (by ML Kit on-device). Kept here — free of
/// any ML Kit import — so the enrichment logic below stays pure and testable.
class ExtractedEntities {
  final List<String> phones;
  final List<String> emails;
  final List<String> addresses;

  const ExtractedEntities({
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
  });

  bool get isEmpty => phones.isEmpty && emails.isEmpty && addresses.isEmpty;
}

/// Cleans up extracted values (normalization) and fills gaps the regex parser
/// missed using ML Kit entities — all pure functions over data.
class FieldEnrichment {
  FieldEnrichment._();

  /// Normalizes then gap-fills [fields].
  static List<ExtractedField> enrich(
    List<ExtractedField> fields,
    ExtractedEntities entities,
  ) {
    final out = fields
        .map((f) => f.copyWith(value: normalizeValue(f.semanticKey, f.value)))
        .toList();

    bool hasKey(String key) =>
        out.any((f) => f.semanticKey == key && f.value.trim().isNotEmpty);

    // Only add an entity value when the parser found nothing for that key —
    // the regex parser is more precise where it does fire.
    if (!hasKey(FactKeys.phone) && entities.phones.isNotEmpty) {
      final v = normalizeValue(FactKeys.phone, entities.phones.first);
      if (v.length == 10) {
        out.add(_entityField('Phone Number', FactKeys.phone, v));
      }
    }
    if (!hasKey(FactKeys.email) && entities.emails.isNotEmpty) {
      out.add(_entityField('Email', FactKeys.email, entities.emails.first));
    }
    if (!hasKey(FactKeys.address) && entities.addresses.isNotEmpty) {
      // Prefer the longest address candidate (usually the most complete).
      final addr = entities.addresses.reduce((a, b) => a.length >= b.length ? a : b);
      out.add(_entityField('Address', FactKeys.address, addr));
    }
    return out;
  }

  static ExtractedField _entityField(
    String label,
    String semanticKey,
    String value,
  ) => ExtractedField(
    label: label,
    value: value,
    semanticKey: semanticKey,
    confidence: 0.6,
    sourceDocument: 'On-device entity detection',
  );

  /// Canonicalizes a value for its kind: title-cased names, digit-only phones
  /// (with the +91/leading-91 country code stripped), canonical dd/MM/yyyy
  /// dates, upper-case PAN, 4-4-4 Aadhaar.
  static String normalizeValue(String semanticKey, String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return value;

    switch (semanticKey) {
      case FactKeys.fullName:
      case FactKeys.fatherName:
      case FactKeys.motherName:
      case FactKeys.spouseName:
      case FactKeys.guardianName:
        return _titleCase(value);

      case FactKeys.phone:
        var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length == 12 && digits.startsWith('91')) {
          digits = digits.substring(2);
        }
        if (digits.length == 11 && digits.startsWith('0')) {
          digits = digits.substring(1);
        }
        return digits.length == 10 ? digits : value;

      case FactKeys.dob:
      case FactKeys.expiryDate:
      case FactKeys.issueDate:
        final d = SearchService.parseFlexibleDate(value);
        if (d == null) return value;
        return '${_two(d.day)}/${_two(d.month)}/${d.year}';

      case FactKeys.panNumber:
        return value.replaceAll(' ', '').toUpperCase();

      case FactKeys.aadhaarNumber:
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length == 12) {
          return '${digits.substring(0, 4)} ${digits.substring(4, 8)} '
              '${digits.substring(8, 12)}';
        }
        return value;

      case FactKeys.pinCode:
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.length == 6 ? digits : value;

      default:
        return value;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty
          ? w
          : (w.length <= 2
              ? w.toUpperCase()
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'))
      .join(' ');
}
