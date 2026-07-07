import 'api_keys.dart';

/// Central app configuration: model names, endpoints, tunables.
/// Everything that might need turning without hunting through code.
class AppConfig {
  AppConfig._();

  // --- AI availability -------------------------------------------------

  /// True when a Gemini key is configured. When false the app runs fully
  /// on-device: regex extraction, keyword search, manual relationships.
  static bool get aiEnabled => ApiKeys.gemini.trim().isNotEmpty;

  // --- Gemini models ----------------------------------------------------

  /// Tried in order — if a model returns 404/429 the next one is used.
  static const List<String> geminiModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const String embeddingModel = 'gemini-embedding-001';

  /// Output dimensionality requested from the embedding model. 768 keeps
  /// storage small while retaining strong retrieval quality.
  static const int embeddingDimensions = 768;

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Per-request timeout for LLM calls. Users won't wait forever.
  static const Duration llmTimeout = Duration(seconds: 45);
  static const Duration embeddingTimeout = Duration(seconds: 20);

  // --- Image handling ---------------------------------------------------

  /// Longest side documents are downscaled to before sending to Gemini.
  /// Big enough to read small print, small enough to keep latency low.
  static const int llmImageMaxDimension = 1600;

  /// JPEG quality for LLM uploads and stored thumbnails.
  static const int llmImageQuality = 85;
  static const int thumbnailMaxDimension = 480;

  // --- Search -----------------------------------------------------------

  /// Minimum cosine similarity for a semantic hit to be shown.
  static const double semanticSearchThreshold = 0.35;
  static const int searchMaxResults = 30;

  // --- Confidence bands (UI) ---------------------------------------------

  static const double confidenceHigh = 0.85;
  static const double confidenceMedium = 0.6;
}
