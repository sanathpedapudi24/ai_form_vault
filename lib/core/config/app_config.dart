/// Central app configuration: tunables.
/// Everything that might need turning without hunting through code.
class AppConfig {
  AppConfig._();

  // --- AI availability -------------------------------------------------

  /// Hard privacy guarantee: document images and OCR text must never
  /// leave the device. Every network-touching code path is gated on this.
  static const bool aiEnabled = false;

  // --- Image handling ---------------------------------------------------

  /// Longest side documents are downscaled to before processing.
  static const int llmImageMaxDimension = 1600;

  /// JPEG quality for processing and stored thumbnails.
  static const int llmImageQuality = 85;
  static const int thumbnailMaxDimension = 480;

  /// Longest side the image is scaled to for OCR. Kept larger than the
  /// stored/upload size — smaller text on IDs (Aadhaar, marks memos) needs
  /// the extra resolution for ML Kit to resolve individual characters.
  static const int ocrImageMaxDimension = 2200;

  /// Below this focus score (variance-of-Laplacian on the OCR image) the
  /// scan is likely too blurry to trust — the review screen offers a retake.
  static const double focusBlurThreshold = 90.0;

  /// Below this mean brightness (0–255) the scan is likely too dark.
  static const double lowBrightnessThreshold = 60.0;

  // --- Search -----------------------------------------------------------

  static const int searchMaxResults = 30;

  // --- Confidence bands (UI) ---------------------------------------------

  static const double confidenceHigh = 0.85;
  static const double confidenceMedium = 0.6;
}
