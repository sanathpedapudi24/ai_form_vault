import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String text;
  final double averageConfidence;
  final List<OcrBlock> blocks;

  const OcrResult({
    required this.text,
    required this.averageConfidence,
    required this.blocks,
  });
}

class OcrBlock {
  final String text;
  final double confidence;
  final Rect boundingBox;

  const OcrBlock({
    required this.text,
    required this.confidence,
    required this.boundingBox,
  });
}

class OcrService {
  final TextRecognizer _latinRecognizer;
  final TextRecognizer? _devanagariRecognizer;

  OcrService()
    : _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin),
      _devanagariRecognizer = _initDevanagari();

  static TextRecognizer? _initDevanagari() {
    try {
      return TextRecognizer(script: TextRecognitionScript.devanagiri);
    } catch (_) {
      return null;
    }
  }

  Future<OcrResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    final latinResult = await _latinRecognizer.processImage(inputImage);

    RecognizedText? devanagariResult;
    if (_devanagariRecognizer != null) {
      try {
        devanagariResult = await _devanagariRecognizer.processImage(inputImage);
      } catch (_) {
        devanagariResult = null;
      }
    }

    final blocks = <OcrBlock>[];
    var totalConfidence = 0.0;
    var blockCount = 0;

    for (final result in [latinResult, ?devanagariResult]) {
      for (final block in result.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isEmpty) continue;
          blocks.add(
            OcrBlock(
              text: line.text,
              confidence: line.confidence ?? 0.0,
              boundingBox: line.boundingBox,
            ),
          );
          totalConfidence += line.confidence ?? 0.0;
          blockCount++;
        }
      }
    }

    final combinedText =
        devanagariResult != null && latinResult.text.trim().isEmpty
        ? devanagariResult.text
        : devanagariResult != null && devanagariResult.text.trim().isNotEmpty
        ? '${latinResult.text}\n${devanagariResult.text}'
        : latinResult.text;

    return OcrResult(
      text: combinedText,
      averageConfidence: blockCount > 0 ? totalConfidence / blockCount : 0.0,
      blocks: blocks,
    );
  }

  void dispose() {
    _latinRecognizer.close();
    _devanagariRecognizer?.close();
  }
}
