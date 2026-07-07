/// TEMPLATE — copy this file to `api_keys.dart` (same folder) and fill in
/// your real keys. `api_keys.dart` is gitignored so keys never reach git.
///
/// Get a free Gemini key at https://aistudio.google.com → "Get API key".
class ApiKeys {
  ApiKeys._();

  /// Google AI Studio (Gemini) API key. Powers document classification,
  /// field extraction, relationship inference, and semantic search
  /// embeddings. Leave empty to run fully on-device (regex + keyword
  /// fallbacks are used automatically).
  static const String gemini = '';
}
