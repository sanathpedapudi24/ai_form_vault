import 'dart:typed_data';
import 'dart:ui';

import '../models/document_model.dart';
import 'document_intelligence.dart';
import 'gemini_client.dart';
import 'ocr_service.dart';

/// One detected form field, matched (or not) against vault facts.
class FormFillField {
  final String label;
  final String semanticKey;

  /// Value pulled from the vault ('' when nothing matched).
  final String value;
  final double confidence;

  /// Where the label sits on the form image (for overlay rendering).
  /// Null when position is unknown.
  final Rect? labelBox;

  const FormFillField({
    required this.label,
    this.semanticKey = '',
    this.value = '',
    this.confidence = 0,
    this.labelBox,
  });

  bool get matched => value.isNotEmpty;

  FormFillField copyWith({String? value, double? confidence}) => FormFillField(
    label: label,
    semanticKey: semanticKey,
    value: value ?? this.value,
    confidence: confidence ?? this.confidence,
    labelBox: labelBox,
  );
}

class FormAnalysis {
  final List<FormFillField> fields;

  /// Size of the analyzed image, so overlay boxes can be scaled.
  final Size imageSize;
  final ExtractionSource source;

  const FormAnalysis({
    required this.fields,
    required this.imageSize,
    required this.source,
  });

  int get matchedCount => fields.where((f) => f.matched).length;
}

/// Snap-to-Fill: photograph any blank form, detect what it asks for, and
/// fill it from the vault's verified facts.
class FormFillService {
  FormFillService({GeminiClient? gemini}) : _gemini = gemini ?? GeminiClient();

  final GeminiClient _gemini;

  /// [facts] maps canonical fact keys → values for the person filling the
  /// form. [ocr] provides label positions for overlay rendering.
  Future<FormAnalysis> analyzeForm({
    required Uint8List imageBytes,
    required OcrResult ocr,
    required Map<String, String> facts,
    required Size imageSize,
  }) async {
    List<_DetectedField> detected;
    var source = ExtractionSource.onDevice;

    if (_gemini.isConfigured) {
      try {
        detected = await _detectWithGemini(imageBytes, ocr.text);
        source = ExtractionSource.ai;
      } on GeminiException {
        detected = _detectFromOcr(ocr);
      }
    } else {
      detected = _detectFromOcr(ocr);
    }

    final usedBlocks = <OcrBlock>{};
    final fields = detected.map((d) {
      final box = _findLabelBox(d.label, ocr, usedBlocks);
      final value = facts[d.semanticKey] ?? '';
      return FormFillField(
        label: d.label,
        semanticKey: d.semanticKey,
        value: value,
        confidence: value.isEmpty ? 0 : 0.9,
        labelBox: box,
      );
    }).toList();

    return FormAnalysis(fields: fields, imageSize: imageSize, source: source);
  }

  // --- Gemini detection ---------------------------------------------------

  Future<List<_DetectedField>> _detectWithGemini(
    Uint8List imageBytes,
    String ocrText,
  ) async {
    final keys = FactKeys.labels.keys.join(', ');
    final prompt =
        '''
This image is a blank or partially blank form that a person needs to fill in.
List every field the form asks the person to write, top to bottom.
Return ONLY a JSON array:

[
  {"label": "the field's label exactly as printed on the form", "key": "canonical key or empty string"}
]

Rules:
- "key" must be one of [$keys] when the field asks for that concept, else "".
- Include only fields a person fills in (skip office-use-only sections).
- Keep labels short — the printed words next to the blank, not instructions.

OCR text of the form (may contain errors):
"""
${ocrText.length > 4000 ? ocrText.substring(0, 4000) : ocrText}
"""
''';

    final json = await _gemini.generateJson(
      prompt: prompt,
      imageBytes: imageBytes,
    );
    final list = json is List ? json : (json is Map ? json['fields'] : null);
    if (list is! List) {
      throw const GeminiException(
        GeminiErrorReason.badResponse,
        'Expected JSON array of fields',
      );
    }

    final result = <_DetectedField>[];
    for (final item in list) {
      if (item is! Map) continue;
      final label = (item['label'] as String? ?? '').trim();
      if (label.isEmpty) continue;
      final key = (item['key'] as String? ?? '').trim();
      result.add(
        _DetectedField(
          label,
          FactKeys.labels.containsKey(key) ? key : '',
        ),
      );
    }
    return result;
  }

  // --- OCR fallback detection -----------------------------------------------

  List<_DetectedField> _detectFromOcr(OcrResult ocr) {
    final result = <_DetectedField>[];
    final seen = <String>{};
    for (final block in ocr.blocks) {
      final line = block.text.trim();
      if (line.length < 3 || line.length > 60) continue;
      final looksLikeLabel =
          line.endsWith(':') ||
          line.endsWith('_') ||
          RegExp(r'[:.]\s*_*\s*$').hasMatch(line) ||
          DocumentIntelligence.semanticKeyForLabel(line).isNotEmpty;
      if (!looksLikeLabel) continue;

      final label = line.replaceAll(RegExp(r'[:_\s]+$'), '');
      final key = DocumentIntelligence.semanticKeyForLabel(label);
      final dedupe = label.toLowerCase();
      if (seen.contains(dedupe)) continue;
      seen.add(dedupe);
      result.add(_DetectedField(label, key));
    }
    return result;
  }

  // --- Label → position matching ---------------------------------------------

  Rect? _findLabelBox(String label, OcrResult ocr, Set<OcrBlock> used) {
    final target = _normalize(label);
    if (target.isEmpty) return null;
    for (final block in ocr.blocks) {
      if (used.contains(block)) continue;
      final text = _normalize(block.text);
      if (text.contains(target) || target.contains(text) && text.length > 3) {
        used.add(block);
        return block.boundingBox;
      }
    }
    return null;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _DetectedField {
  final String label;
  final String semanticKey;
  const _DetectedField(this.label, this.semanticKey);
}
