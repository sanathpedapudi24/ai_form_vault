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

  // --- Search -----------------------------------------------------------

  static const int searchMaxResults = 30;

  // --- Confidence bands (UI) ---------------------------------------------

  static const double confidenceHigh = 0.85;
  static const double confidenceMedium = 0.6;
}
