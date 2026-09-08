import 'dart:ui';

import 'document_intelligence.dart';
import 'ocr_service.dart';

/// A form field detected on a blank/partially-filled document image, with a
/// suggested value pulled from the user's saved profile facts (if matched).
class DetectedFormField {
  final String label;
  final String semanticKey;
  final String suggestedValue;

  /// Index into the capture's image list this field was found on.
  final int pageIndex;

  /// Where the label sits on that page's image, in image pixel coordinates
  /// (as reported by ML Kit) — used to place the answer when exporting a
  /// filled image.
  final Rect? boundingBox;

  const DetectedFormField({
    required this.label,
    required this.semanticKey,
    this.suggestedValue = '',
    this.pageIndex = 0,
    this.boundingBox,
  });

  bool get matched => semanticKey.isNotEmpty && suggestedValue.isNotEmpty;

  DetectedFormField copyWith({String? suggestedValue}) => DetectedFormField(
    label: label,
    semanticKey: semanticKey,
    suggestedValue: suggestedValue ?? this.suggestedValue,
    pageIndex: pageIndex,
    boundingBox: boundingBox,
  );
}

/// Offline heuristic for Snap-to-Fill: finds candidate blank-form field
/// labels among a page's OCR lines and maps each to a known profile fact via
/// [DocumentIntelligence.semanticKeyForLabel].
///
/// ponytail: per-line heuristic (a label and its blank must sit on the same
/// OCR line) — doesn't reconstruct multi-column layouts where a label and
/// its blank are separate OCR blocks side by side. A Gemini-vision prompt
/// (like [DocumentIntelligence.analyze]'s AI path) is the natural upgrade if
/// this proves too weak on real-world forms.
class SnapFillService {
  SnapFillService._();

  static final _trailingBlank = RegExp(r'[_.]{3,}\s*$');
  static final _trailingMark = RegExp(r'[:\-]\s*$');

  /// Detects fields in one page's OCR [lines]. Pass a shared [seen] set
  /// across pages of the same capture to dedupe repeated labels (e.g. a
  /// letterhead reprinted on every page).
  static List<DetectedFormField> detectFields(
    List<OcrBlock> lines,
    Map<String, String> userFacts, {
    Set<String>? seen,
    int pageIndex = 0,
  }) {
    final seenLabels = seen ?? <String>{};
    final results = <DetectedFormField>[];

    for (final line in lines) {
      var label = line.text.trim();
      if (label.isEmpty) continue;

      final hadBlankRun = _trailingBlank.hasMatch(label);
      label = label.replaceFirst(_trailingBlank, '').trim();
      final hadMark = _trailingMark.hasMatch(label);
      label = label.replaceFirst(_trailingMark, '').trim();

      if (!hadBlankRun && !hadMark) continue;
      if (label.isEmpty || label.length > 60) continue;
      if (label.split(RegExp(r'\s+')).length > 6) continue;

      final key = label.toLowerCase();
      if (!seenLabels.add(key)) continue;

      final semanticKey = DocumentIntelligence.semanticKeyForLabel(label);
      results.add(
        DetectedFormField(
          label: label,
          semanticKey: semanticKey,
          suggestedValue: semanticKey.isEmpty
              ? ''
              : (userFacts[semanticKey] ?? ''),
          pageIndex: pageIndex,
          boundingBox: line.boundingBox,
        ),
      );
    }
    return results;
  }
}
