import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Calls the Gemini 2.0 Flash vision API to extract structured fields from a
/// document image. Returns a raw JSON map on success, null on failure.
///
/// The caller (DocumentIntelligence) converts the map into DocumentAnalysis.
/// This avoids a circular import between gemini_service and document_intelligence.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  /// Returns parsed JSON map or null on failure.
  Future<Map<String, dynamic>?> analyze({
    required Uint8List imageBytes,
    String? apiKey,
  }) async {
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final base64Image = base64Encode(imageBytes);

      final response = await _client
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          body['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;

      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

const _prompt = '''
Analyze this document image and extract structured information.

Return a JSON object with these fields:
- "category": one of "identity", "education", "finance", "medical", "travel", "family", "other"
- "documentType": specific type like "Aadhaar Card", "PAN Card", "Passport", "Marks Memo", etc.
- "ownerName": the primary person's full name on the document
- "fields": array of objects with "label", "value", and "semanticKey" (one of: full_name, dob, gender, father_name, mother_name, phone, email, address, aadhaar_number, pan_number, passport_number, voter_id, driving_license, pin_code, state, blood_group, nationality, roll_number, institution, qualification, issue_date, expiry_date)
- "people": array of objects with "name" and "relationToOwner" (father, mother, spouse, guardian, etc.)

Only extract clearly visible text. Use high confidence for certain readings, lower for ambiguous ones.
Return ONLY the JSON, no other text.
''';
