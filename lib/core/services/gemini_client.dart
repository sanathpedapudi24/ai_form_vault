import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../config/app_config.dart';

/// Why a Gemini call failed — lets the UI say something useful.
enum GeminiErrorReason { noApiKey, network, rateLimited, badResponse, blocked }

class GeminiException implements Exception {
  final GeminiErrorReason reason;
  final String message;
  const GeminiException(this.reason, this.message);

  @override
  String toString() => 'GeminiException(${reason.name}): $message';
}

/// Thin REST client for the Gemini API. Knows nothing about documents —
/// only how to talk JSON to Google, walk the model fallback chain, and
/// retry transient failures once.
class GeminiClient {
  GeminiClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  bool get isConfigured => AppConfig.aiEnabled;

  /// Sends [prompt] (optionally with an image) and returns the decoded JSON
  /// the model produced. `responseMimeType: application/json` is enforced.
  Future<dynamic> generateJson({
    required String prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    double temperature = 0.1,
  }) async {
    _requireKey();

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imageBytes != null)
        {
          'inline_data': {
            'mime_type': imageMimeType,
            'data': base64Encode(imageBytes),
          },
        },
    ];

    final body = jsonEncode({
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
      },
    });

    Object? lastError;
    for (final model in AppConfig.geminiModels) {
      final uri = Uri.parse(
        '${AppConfig.geminiBaseUrl}/models/$model:generateContent',
      );
      try {
        final response = await _postWithRetry(uri, body, AppConfig.llmTimeout);
        return _extractJson(response);
      } on GeminiException catch (e) {
        // Try the next model for capacity/availability problems only.
        if (e.reason == GeminiErrorReason.rateLimited ||
            e.reason == GeminiErrorReason.badResponse) {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastError as GeminiException? ??
        const GeminiException(GeminiErrorReason.badResponse, 'All models failed');
  }

  /// Embeds [texts]; returns one vector per input, in order.
  Future<List<List<double>>> embed(List<String> texts) async {
    _requireKey();
    if (texts.isEmpty) return [];

    final model = AppConfig.embeddingModel;
    final uri = Uri.parse(
      '${AppConfig.geminiBaseUrl}/models/$model:batchEmbedContents',
    );
    final body = jsonEncode({
      'requests': [
        for (final text in texts)
          {
            'model': 'models/$model',
            'content': {
              'parts': [
                {'text': text},
              ],
            },
            'outputDimensionality': AppConfig.embeddingDimensions,
          },
      ],
    });

    final json = await _postWithRetry(uri, body, AppConfig.embeddingTimeout);
    final embeddings = json['embeddings'] as List?;
    if (embeddings == null) {
      throw const GeminiException(
        GeminiErrorReason.badResponse,
        'No embeddings in response',
      );
    }
    return embeddings
        .map(
          (e) => ((e as Map)['values'] as List)
              .map((v) => (v as num).toDouble())
              .toList(),
        )
        .toList();
  }

  // --- internals -------------------------------------------------------------

  void _requireKey() {
    if (!isConfigured) {
      throw const GeminiException(
        GeminiErrorReason.noApiKey,
        'No Gemini API key configured',
      );
    }
  }

  Future<Map<String, dynamic>> _postWithRetry(
    Uri uri,
    String body,
    Duration timeout,
  ) async {
    GeminiException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      try {
        final response = await _http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': ApiKeys.gemini,
              },
              body: body,
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        if (response.statusCode == 429 || response.statusCode >= 500) {
          lastError = GeminiException(
            GeminiErrorReason.rateLimited,
            'HTTP ${response.statusCode}: ${_errorMessage(response.body)}',
          );
          continue; // retry once, then bubble up
        }
        throw GeminiException(
          GeminiErrorReason.badResponse,
          'HTTP ${response.statusCode}: ${_errorMessage(response.body)}',
        );
      } on TimeoutException {
        lastError = const GeminiException(
          GeminiErrorReason.network,
          'Request timed out',
        );
      } on http.ClientException catch (e) {
        lastError = GeminiException(GeminiErrorReason.network, e.message);
      }
    }
    throw lastError!;
  }

  dynamic _extractJson(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final block = response['promptFeedback']?['blockReason'];
      throw GeminiException(
        block != null ? GeminiErrorReason.blocked : GeminiErrorReason.badResponse,
        block != null ? 'Blocked: $block' : 'Empty response',
      );
    }
    final parts = candidates.first['content']?['parts'] as List?;
    final text = parts
        ?.map((p) => (p as Map)['text'] as String? ?? '')
        .join()
        .trim();
    if (text == null || text.isEmpty) {
      throw const GeminiException(
        GeminiErrorReason.badResponse,
        'No text in response',
      );
    }
    try {
      return jsonDecode(_stripCodeFences(text));
    } on FormatException {
      throw GeminiException(
        GeminiErrorReason.badResponse,
        'Model returned invalid JSON: ${text.length > 200 ? text.substring(0, 200) : text}',
      );
    }
  }

  /// Models occasionally wrap JSON in ```json fences despite JSON mode.
  static String _stripCodeFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      return json['error']?['message'] as String? ?? body;
    } catch (_) {
      return body.length > 300 ? body.substring(0, 300) : body;
    }
  }

  void dispose() => _http.close();
}
