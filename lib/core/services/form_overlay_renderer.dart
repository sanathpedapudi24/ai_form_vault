import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'form_fill_service.dart';

/// Draws matched Snap-to-Fill values onto the photographed form so
/// "share" produces an actually filled form, not the blank original.
///
/// Fields whose label position was found get their value drawn right next
/// to that label. Matched fields with no known position (the OCR-to-label
/// match failed, but the value is still correct) are listed in a footer
/// strip appended below the image instead of silently dropped.
class FormOverlayRenderer {
  FormOverlayRenderer._();

  static const _labelColor = 20; // near-black text
  static final _fillFont = img.arial24;
  static final _footerFont = img.arial14;

  static Uint8List render(Uint8List originalJpeg, List<FormFillField> fields) {
    final decoded = img.decodeImage(originalJpeg);
    if (decoded == null) return originalJpeg;

    final positioned = <FormFillField>[];
    final unpositioned = <FormFillField>[];
    for (final field in fields) {
      if (!field.matched) continue;
      if (field.labelBox != null) {
        positioned.add(field);
      } else {
        unpositioned.add(field);
      }
    }

    var canvas = decoded;
    for (final field in positioned) {
      canvas = _drawInline(canvas, field);
    }
    if (unpositioned.isNotEmpty) {
      canvas = _appendFooter(canvas, unpositioned);
    }

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  static img.Image _drawInline(img.Image canvas, FormFillField field) {
    final box = field.labelBox!;
    final text = field.value;
    final x = box.right.round() + 12;
    final y = box.top.round();

    // No exact text-metrics API on BitmapFont — a per-character estimate
    // is close enough for a background strip that only needs to comfortably
    // contain the text, not hug it exactly.
    final approxWidth = (text.length * 13) + 12;
    final approxHeight = _fillFont.lineHeight + 6;
    final x2 = (x + approxWidth).clamp(0, canvas.width).toInt();
    final y2 = (y + approxHeight).clamp(0, canvas.height).toInt();
    if (x >= canvas.width || y >= canvas.height) return canvas;

    img.fillRect(
      canvas,
      x1: (x - 6).clamp(0, canvas.width),
      y1: (y - 3).clamp(0, canvas.height),
      x2: x2,
      y2: y2,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.drawRect(
      canvas,
      x1: (x - 6).clamp(0, canvas.width),
      y1: (y - 3).clamp(0, canvas.height),
      x2: x2,
      y2: y2,
      color: img.ColorRgb8(217, 119, 87), // accent terracotta
      thickness: 2,
    );
    img.drawString(
      canvas,
      text,
      font: _fillFont,
      x: x,
      y: y,
      color: img.ColorRgb8(_labelColor, _labelColor, _labelColor),
    );
    return canvas;
  }

  static img.Image _appendFooter(img.Image canvas, List<FormFillField> fields) {
    const padding = 16;
    const lineHeight = 24;
    final headerHeight = 32;
    final footerHeight =
        headerHeight + fields.length * lineHeight + padding * 2;

    final extended = img.Image(
      width: canvas.width,
      height: canvas.height + footerHeight,
    );
    img.fill(extended, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(extended, canvas, dstX: 0, dstY: 0);

    img.drawString(
      extended,
      'Also filled (position not found on form):',
      font: img.arial14,
      x: padding,
      y: canvas.height + padding,
      color: img.ColorRgb8(120, 120, 115),
    );

    var y = canvas.height + padding + headerHeight;
    for (final field in fields) {
      img.drawString(
        extended,
        '${field.label}: ${field.value}',
        font: _footerFont,
        x: padding,
        y: y,
        color: img.ColorRgb8(_labelColor, _labelColor, _labelColor),
      );
      y += lineHeight;
    }
    return extended;
  }
}
