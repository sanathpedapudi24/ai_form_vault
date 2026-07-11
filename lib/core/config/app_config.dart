/// Central app configuration: model names, endpoints, tunables.
/// Everything that might need turning without hunting through code.
class AppConfig {
  AppConfig._();

  // --- AI availability -------------------------------------------------

  /// Hard privacy guarantee, not a placeholder: document images and OCR
  /// text must never leave the device, full stop. This is a deliberate
  /// product decision (made after weighing it against Gemini-quality
  /// extraction accuracy) — not something that flips on the moment a key
  /// is pasted into `ApiKeys.gemini`.
  ///
  /// Every network-touching code path (DocumentIntelligence, Embedding
  /// Service, FormFillService) is gated on `AppConfig.aiEnabled`, and nothing
  /// else — so this one constant is the single, airtight kill switch for
  /// cloud AI in the whole app. Re-enabling it is a decision to make
  /// deliberately, not a side effect of adding a key: change this back to
  /// `ApiKeys.gemini.trim().isNotEmpty` only if that decision is made again.
  static const bool aiEnabled = false;

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
