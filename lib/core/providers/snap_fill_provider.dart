import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/snap_fill_service.dart';
import 'person_provider.dart';
import 'service_providers.dart';

enum SnapFillStage { idle, scanning, done, error }

class SnapFillState {
  final SnapFillStage stage;
  final List<DetectedFormField> fields;
  final List<String> imagePaths;
  final String error;

  const SnapFillState({
    this.stage = SnapFillStage.idle,
    this.fields = const [],
    this.imagePaths = const [],
    this.error = '',
  });

  int get matchedCount => fields.where((f) => f.matched).length;

  SnapFillState copyWith({
    SnapFillStage? stage,
    List<DetectedFormField>? fields,
    List<String>? imagePaths,
    String? error,
  }) => SnapFillState(
    stage: stage ?? this.stage,
    fields: fields ?? this.fields,
    imagePaths: imagePaths ?? this.imagePaths,
    error: error ?? this.error,
  );
}

/// Drives the Snap-to-Fill flow: OCR each photographed/imported page, then
/// detect and match its fields against the vault owner's saved facts.
class SnapFillNotifier extends StateNotifier<SnapFillState> {
  SnapFillNotifier(this._ref) : super(const SnapFillState());

  final Ref _ref;

  Future<void> process(List<String> imagePaths) async {
    state = const SnapFillState(stage: SnapFillStage.scanning);
    try {
      final ocrService = _ref.read(ocrServiceProvider);
      final userFacts = await _ref.read(userFactsProvider.future);
      final seen = <String>{};
      final fields = <DetectedFormField>[];
      for (var i = 0; i < imagePaths.length; i++) {
        final ocr = await ocrService.processImage(imagePaths[i]);
        fields.addAll(
          SnapFillService.detectFields(
            ocr.blocks,
            userFacts,
            seen: seen,
            pageIndex: i,
          ),
        );
      }
      state = SnapFillState(
        stage: SnapFillStage.done,
        fields: fields,
        imagePaths: imagePaths,
      );
    } catch (e) {
      state = SnapFillState(stage: SnapFillStage.error, error: '$e');
    }
  }

  void updateValue(int index, String value) {
    final fields = [...state.fields];
    fields[index] = fields[index].copyWith(suggestedValue: value);
    state = state.copyWith(fields: fields);
  }

  void reset() => state = const SnapFillState();
}

final snapFillProvider = StateNotifierProvider<SnapFillNotifier, SnapFillState>(
  (ref) => SnapFillNotifier(ref),
);
