import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class VisionOcrService {
  final String apiKey;
  final String endpoint;
  final String model;
  final http.Client _client;

  VisionOcrService({
    required this.apiKey,
    this.endpoint = const String.fromEnvironment(
      'VISION_OCR_ENDPOINT',
      defaultValue: 'https://api.openai.com/v1/chat/completions',
    ),
    this.model = const String.fromEnvironment(
      'VISION_OCR_MODEL',
      defaultValue: 'gpt-4o-mini',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<String?> recognizeHandwriting(Uint8List imageBytes) async {
    if (!isConfigured) return null;

    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0,
            'messages': [
              {
                'role': 'system',
                'content': 'Transcribe the image exactly. Return only the text '
                    'visible in the image. Do not summarize, correct spelling, or '
                    'invent unreadable content.',
              },
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': 'Transcribe this handwritten page.'},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url':
                          'data:image/jpeg;base64,${base64Encode(imageBytes)}',
                      'detail': 'high',
                    },
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;
    final message = choices?.isNotEmpty == true
        ? (choices!.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?
        : null;
    final content = message?['content'];
    return content is String && content.trim().isNotEmpty ? content : null;
  }
}
