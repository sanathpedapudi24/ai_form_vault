import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Result of preparing an image for OCR: the cleaned-up bytes plus quality
/// metrics used to warn the user about a bad scan before they trust it.
class OcrImage {
  /// Path to the preprocessed (grayscale, contrast-stretched) image written
  /// to a temp file — what ML Kit actually reads.
  final String path;

  /// Variance of the Laplacian — a standard focus measure. Higher = sharper.
  /// A blurry photo has little high-frequency detail and scores low.
  final double focusScore;

  /// Mean luminance (0–255) of the source, to catch under-exposed shots.
  final double brightness;

  const OcrImage({
    required this.path,
    required this.focusScore,
    required this.brightness,
  });

  bool get looksBlurry => focusScore < AppConfig.focusBlurThreshold;
  bool get looksDark => brightness < AppConfig.lowBrightnessThreshold;
  bool get looksPoor => looksBlurry || looksDark;
}

/// Image resizing/encoding, run in a background isolate so the UI never
/// stutters while multi-megabyte camera photos are processed.
class ImagePrep {
  ImagePrep._();

  /// Reads [path], downscales to [AppConfig.llmImageMaxDimension] and
  /// re-encodes as JPEG — the payload stored in the vault.
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

  /// Preprocesses [path] for OCR: bakes EXIF orientation, converts to
  /// grayscale, stretches contrast and sharpens so faint or low-contrast
  /// print (faded Aadhaar ink, laminated cards, dim photos) reads reliably.
  /// Also measures focus and brightness so a bad scan can be flagged.
  ///
  /// The heavy pixel work runs in an isolate; the parent only does file IO.
  static Future<OcrImage> prepareForOcr(String path) async {
    final bytes = await File(path).readAsBytes();
    final result = await compute(_preprocessForOcr, _ResizeJob(
      bytes,
      AppConfig.ocrImageMaxDimension,
      92,
    ));

    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(result.bytes, flush: true);

    return OcrImage(
      path: outPath,
      focusScore: result.focusScore,
      brightness: result.brightness,
    );
  }
}

class _ResizeJob {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;
  const _ResizeJob(this.bytes, this.maxDimension, this.quality);
}

class _OcrPrepResult {
  final Uint8List bytes;
  final double focusScore;
  final double brightness;
  const _OcrPrepResult(this.bytes, this.focusScore, this.brightness);
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

/// Runs entirely inside a background isolate (see [ImagePrep.prepareForOcr]).
_OcrPrepResult _preprocessForOcr(_ResizeJob job) {
  var decoded = img.decodeImage(job.bytes);
  if (decoded == null) {
    return _OcrPrepResult(job.bytes, double.infinity, 128);
  }

  // Respect camera orientation before anything else — a sideways scan is
  // both unreadable and skews the focus measure.
  decoded = img.bakeOrientation(decoded);

  // Downscale large photos to a consistent OCR working size.
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > job.maxDimension) {
    decoded = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? job.maxDimension : null,
      height: decoded.height > decoded.width ? job.maxDimension : null,
      interpolation: img.Interpolation.cubic,
    );
  }

  // Grayscale: color carries no signal for text and hurts contrast stretch.
  var gray = img.grayscale(decoded);

  final brightness = _meanBrightness(gray);

  // Contrast stretch + a gentle gamma so mid-tones separate from paper.
  gray = img.normalize(gray, min: 0, max: 255);
  gray = img.adjustColor(gray, contrast: 1.15);

  // Focus measure on the enhanced grayscale (variance of the Laplacian).
  final focus = _laplacianVariance(gray);

  // Light unsharp mask to crisp up edges for the recognizer.
  final sharpened = img.convolution(
    gray,
    filter: <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
    div: 1,
  );

  return _OcrPrepResult(
    Uint8List.fromList(img.encodeJpg(sharpened, quality: job.quality)),
    focus,
    brightness,
  );
}

double _meanBrightness(img.Image gray) {
  var total = 0.0;
  var count = 0;
  // Sample a grid rather than every pixel — plenty for a mean, far cheaper.
  final stepX = math.max(1, gray.width ~/ 200);
  final stepY = math.max(1, gray.height ~/ 200);
  for (var y = 0; y < gray.height; y += stepY) {
    for (var x = 0; x < gray.width; x += stepX) {
      total += gray.getPixel(x, y).r;
      count++;
    }
  }
  return count == 0 ? 128 : total / count;
}

/// Variance of the Laplacian: convolve with a 4-neighbour Laplacian kernel
/// and take the variance of the response. A well-focused document has sharp
/// character edges (high-variance response); a blurry one is smooth (low).
double _laplacianVariance(img.Image gray) {
  final w = gray.width;
  final h = gray.height;
  if (w < 3 || h < 3) return double.infinity;

  // Downsample the working grid for speed — focus is a global property.
  final stepX = math.max(1, w ~/ 500);
  final stepY = math.max(1, h ~/ 500);

  var sum = 0.0;
  var sumSq = 0.0;
  var n = 0;
  for (var y = stepY; y < h - stepY; y += stepY) {
    for (var x = stepX; x < w - stepX; x += stepX) {
      final c = gray.getPixel(x, y).r;
      final up = gray.getPixel(x, y - stepY).r;
      final down = gray.getPixel(x, y + stepY).r;
      final left = gray.getPixel(x - stepX, y).r;
      final right = gray.getPixel(x + stepX, y).r;
      final lap = (4 * c - up - down - left - right).toDouble();
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  if (n == 0) return double.infinity;
  final mean = sum / n;
  return (sumSq / n) - (mean * mean);
}
