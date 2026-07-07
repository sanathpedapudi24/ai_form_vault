import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../config/app_config.dart';

/// Image resizing/encoding, run in a background isolate so the UI never
/// stutters while multi-megabyte camera photos are processed.
class ImagePrep {
  ImagePrep._();

  /// Reads [path], downscales to [AppConfig.llmImageMaxDimension] and
  /// re-encodes as JPEG — the payload sent to Gemini and stored in the vault.
  static Future<Uint8List> prepareForUpload(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(_resizeJpeg, _ResizeJob(
      bytes,
      AppConfig.llmImageMaxDimension,
      AppConfig.llmImageQuality,
    ));
  }

  /// Small thumbnail for list views.
  static Future<Uint8List> makeThumbnail(Uint8List sourceJpeg) {
    return compute(_resizeJpeg, _ResizeJob(
      sourceJpeg,
      AppConfig.thumbnailMaxDimension,
      80,
    ));
  }
}

class _ResizeJob {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;
  const _ResizeJob(this.bytes, this.maxDimension, this.quality);
}

Uint8List _resizeJpeg(_ResizeJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return job.bytes;

  img.Image out = decoded;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest > job.maxDimension) {
    out = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? job.maxDimension : null,
      height: decoded.height > decoded.width ? job.maxDimension : null,
      interpolation: img.Interpolation.linear,
    );
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: job.quality));
}
