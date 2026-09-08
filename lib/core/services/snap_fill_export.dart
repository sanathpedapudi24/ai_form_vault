import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'snap_fill_service.dart';

/// Renders the user's answers back onto the original form photo(s), next to
/// each matched field's label, producing real shareable filled-form JPEGs.
///
/// ponytail: draws plain text near the field's OCR bounding box — no
/// perspective correction, checkbox/signature handling, or PDF wrapping.
/// The `image` package (already a dependency) covers "a real filled file"
/// without pulling in a separate PDF-writing library.
class SnapFillExportService {
  SnapFillExportService._();

  /// Writes one JPEG per page that has at least one answered field, with
  /// each answer drawn below its detected label. Pages with nothing to fill
  /// are skipped.
  static Future<List<File>> exportFilledPages(
    List<String> imagePaths,
    List<DetectedFormField> fields,
  ) async {
    final byPage = <int, List<DetectedFormField>>{};
    for (final f in fields) {
      if (f.suggestedValue.trim().isEmpty || f.boundingBox == null) continue;
      byPage.putIfAbsent(f.pageIndex, () => []).add(f);
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final outputs = <File>[];

    for (var i = 0; i < imagePaths.length; i++) {
      final pageFields = byPage[i];
      if (pageFields == null || pageFields.isEmpty) continue;

      final bytes = await File(imagePaths[i]).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      for (final field in pageFields) {
        final box = field.boundingBox!;
        img.drawString(
          decoded,
          field.suggestedValue,
          font: img.arial24,
          x: box.left.round(),
          y: box.bottom.round() + 4,
          color: img.ColorRgb8(200, 30, 30),
        );
      }

      final file = File(p.join(tempDir.path, 'snap_fill_${stamp}_$i.jpg'));
      await file.writeAsBytes(
        img.encodeJpg(decoded, quality: 90),
        flush: true,
      );
      outputs.add(file);
    }
    return outputs;
  }
}
