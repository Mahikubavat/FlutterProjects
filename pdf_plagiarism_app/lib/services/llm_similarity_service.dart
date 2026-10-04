import 'dart:convert';

import 'package:http/http.dart' as http;

class LlmSimilarityService {
  final String apiKey;
  final String endpoint;
  final String model;
  final http.Client _client;

  LlmSimilarityService({
    required this.apiKey,
    this.endpoint = const String.fromEnvironment(
      'LLM_ENDPOINT',
      defaultValue: 'https://api.openai.com/v1/chat/completions',
    ),
    this.model = const String.fromEnvironment(
      'LLM_MODEL',
      defaultValue: 'gpt-4o-mini',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<double?> compare(String textA, String textB) async {
    if (!isConfigured) return null;

    final response = await _client.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content': 'You detect academic plagiarism. Return only JSON with '
                'semantic_similarity (number from 0 to 1). Score shared ideas '
                'and distinctive phrasing, not common facts or topic overlap. '
                'A high score means one text is likely a paraphrase of the other.',
          },
          {
            'role': 'user',
            'content': 'Text A:\n$textA\n\nText B:\n$textB',
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = ((body['choices'] as List).first
        as Map<String, dynamic>)['message']['content'] as String;
    final result = jsonDecode(content) as Map<String, dynamic>;
    final score = (result['semantic_similarity'] as num?)?.toDouble();
    return score?.clamp(0, 1);
  }
}
