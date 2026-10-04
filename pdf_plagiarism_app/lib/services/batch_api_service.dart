import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/batch_report_model.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

/// Abstract contract for Batch Plagiarism API interaction.
abstract class IBatchApiService {
  Future<String> startBatchJob({
    required List<String> userIds,
    required String assignmentTag,
  });

  Future<BatchReportModel> fetchBatchResults(String batchJobId);

  void dispose();
}

/// REST API Client for Batch Plagiarism Evaluation.
/// Compatible with standard REST backends and accepts an injectable [http.Client].
class BatchApiService implements IBatchApiService {
  final String baseUrl;
  final http.Client _client;
  final Map<String, String>? defaultHeaders;

  BatchApiService({
    this.baseUrl = const String.fromEnvironment(
      'BATCH_API_BASE_URL',
      defaultValue: 'https://api.plagiarismchecker.internal/api/v1',
    ),
    http.Client? client,
    this.defaultHeaders,
  }) : _client = client ?? http.Client();

  /// Starts a batch evaluation job for a list of student user IDs and an assignment tag.
  /// Returns the assigned [batchJobId].
  @override
  Future<String> startBatchJob({
    required List<String> userIds,
    required String assignmentTag,
  }) async {
    final uri = Uri.parse('$baseUrl/batches/evaluations');

    final headers = {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
      ...?defaultHeaders,
    };

    final body = jsonEncode({
      'userIds': userIds,
      'assignmentTag': assignmentTag,
    });

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        final jobId = payload['batchJobId'] ??
            payload['batch_job_id'] ??
            payload['jobId'] ??
            payload['id'];

        if (jobId != null && jobId.toString().isNotEmpty) {
          return jobId.toString();
        }
        throw const FormatException('Server response missing "batchJobId".');
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to start batch job: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      throw ApiException(statusCode: 0, message: 'Network connection error: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException(statusCode: 0, message: 'HTTP client error: ${e.message}');
    }
  }

  /// Fetches the latest status, progress, and results for a given [batchJobId].
  @override
  Future<BatchReportModel> fetchBatchResults(String batchJobId) async {
    final uri = Uri.parse('$baseUrl/batches/evaluations/$batchJobId');

    final headers = {
      HttpHeaders.acceptHeader: 'application/json',
      ...?defaultHeaders,
    };

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        return BatchReportModel.fromJson(payload);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to fetch batch results: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      throw ApiException(statusCode: 0, message: 'Network connection error: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException(statusCode: 0, message: 'HTTP client error: ${e.message}');
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
