import 'dart:ui';

import 'package:ai_form_vault/core/services/ocr_service.dart';
import 'package:ai_form_vault/core/services/snap_fill_service.dart';
import 'package:flutter_test/flutter_test.dart';

OcrBlock _line(String text) =>
    OcrBlock(text: text, confidence: 1.0, boundingBox: Rect.zero);

void main() {
  test('matches a labeled blank to a known profile fact', () {
    final lines = [
      _line('APPLICATION FORM'),
      _line('Full Name: __________'),
      _line('Date of Birth :'),
      _line('This is just a paragraph of instructions, not a field.'),
    ];
    final facts = {'full_name': 'Jane Doe'};

    final fields = SnapFillService.detectFields(lines, facts);

    expect(fields.length, 2);
    expect(fields[0].label, 'Full Name');
    expect(fields[0].semanticKey, 'full_name');
    expect(fields[0].suggestedValue, 'Jane Doe');
    expect(fields[0].matched, isTrue);

    expect(fields[1].label, 'Date of Birth');
    expect(fields[1].matched, isFalse);
  });

  test('dedupes repeated labels across pages via a shared seen set', () {
    final page1 = [_line('Full Name: ____')];
    final page2 = [_line('Full Name: ____'), _line('Phone: ____')];
    final facts = <String, String>{};
    final seen = <String>{};

    final first = SnapFillService.detectFields(
      page1,
      facts,
      seen: seen,
      pageIndex: 0,
    );
    final second = SnapFillService.detectFields(
      page2,
      facts,
      seen: seen,
      pageIndex: 1,
    );

    expect(first.length, 1);
    expect(second.length, 1);
    expect(second.single.label, 'Phone');
  });

  test('ignores prose lines with no trailing blank or colon/dash', () {
    final lines = [_line('Please read all instructions before signing.')];
    final fields = SnapFillService.detectFields(lines, const {});
    expect(fields, isEmpty);
  });
}
