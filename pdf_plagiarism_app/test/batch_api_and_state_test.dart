import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:plagiarism_checker/models/batch_report_model.dart';
import 'package:plagiarism_checker/services/batch_api_service.dart';
import 'package:plagiarism_checker/services/batch_repository.dart';
import 'package:plagiarism_checker/state/batch_cubit.dart';

void main() {
  group('Batch Models Tests', () {
    test('StudentReport parses JSON correctly', () {
      final json = {
        'studentId': 'stu_101',
        'studentName': 'Alex Rivera',
        'maxScore': 0.842,
        'topPeerName': 'David Chen',
        'flagged': true,
      };

      final student = StudentReport.fromJson(json);
      expect(student.studentId, 'stu_101');
      expect(student.studentName, 'Alex Rivera');
      expect(student.maxScore, 0.842);
      expect(student.topPeerName, 'David Chen');
      expect(student.flagged, true);

      final serialized = student.toJson();
      expect(serialized['studentId'], 'stu_101');
      expect(serialized['maxScore'], 0.842);
    });

    test('BatchReportModel parses COMPLETED response', () {
      final json = {
        'batchJobId': 'job_123',
        'status': 'COMPLETED',
        'progress': 1.0,
        'reports': [
          {
            'studentId': 'stu_101',
            'studentName': 'Alex Rivera',
            'maxScore': 0.842,
            'topPeerName': 'David Chen',
            'flagged': true,
          }
        ]
      };

      final model = BatchReportModel.fromJson(json);
      expect(model.batchJobId, 'job_123');
      expect(model.isCompleted, true);
      expect(model.isProcessing, false);
      expect(model.progress, 1.0);
      expect(model.reports.length, 1);
      expect(model.reports.first.studentName, 'Alex Rivera');
    });
  });

  group('BatchApiService Tests', () {
    test('startBatchJob returns batchJobId on success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/batches/evaluations')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['assignmentTag'], 'Lab 1');
          expect(body['userIds'], ['stu_1', 'stu_2']);

          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'batchJobId': 'batch_999', 'status': 'QUEUED'}
            }),
            202,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = BatchApiService(
        baseUrl: 'https://test.api/v1',
        client: mockClient,
      );

      final jobId = await service.startBatchJob(
        userIds: ['stu_1', 'stu_2'],
        assignmentTag: 'Lab 1',
      );

      expect(jobId, 'batch_999');
    });

    test('fetchBatchResults returns BatchReportModel', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/batches/evaluations/batch_999')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'batchJobId': 'batch_999',
                'status': 'PROCESSING',
                'progress': 0.45,
                'reports': []
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = BatchApiService(
        baseUrl: 'https://test.api/v1',
        client: mockClient,
      );

      final report = await service.fetchBatchResults('batch_999');
      expect(report.batchJobId, 'batch_999');
      expect(report.isProcessing, true);
      expect(report.progress, 0.45);
    });
  });

  group('BatchCubit State & Polling Tests', () {
    test('State transitions from Initial -> Loading -> Success via polling', () async {
      int pollCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'batchJobId': 'job_abc'}),
            201,
          );
        } else if (request.method == 'GET') {
          pollCount++;
          if (pollCount == 1) {
            // First poll: in progress 50%
            return http.Response(
              jsonEncode({
                'batchJobId': 'job_abc',
                'status': 'PROCESSING',
                'progress': 0.50,
                'reports': [],
              }),
              200,
            );
          } else {
            // Second poll: completed
            return http.Response(
              jsonEncode({
                'batchJobId': 'job_abc',
                'status': 'COMPLETED',
                'progress': 1.0,
                'reports': [
                  {
                    'studentId': 's1',
                    'studentName': 'Alice',
                    'maxScore': 0.72,
                    'topPeerName': 'Bob',
                    'flagged': true,
                  }
                ],
              }),
              200,
            );
          }
        }
        return http.Response('Error', 500);
      });

      final apiService = BatchApiService(
        baseUrl: 'https://test.api/v1',
        client: mockClient,
      );
      final repository = BatchRepositoryImpl(apiService: apiService);
      final cubit = BatchCubit(repository: repository);

      expect(cubit.state, isA<BatchInitial>());

      final states = <BatchState>[];
      cubit.addListener(() {
        states.add(cubit.state);
      });

      await cubit.startBatchEvaluation(
        userIds: ['s1', 's2'],
        assignmentTag: 'Lab 1',
        pollingInterval: const Duration(milliseconds: 50),
      );

      // Allow 2 timer cycles to fire
      await Future<void>.delayed(const Duration(milliseconds: 160));

      expect(cubit.state, isA<BatchSuccess>());
      final success = cubit.state as BatchSuccess;
      expect(success.report.reports.length, 1);
      expect(success.report.reports.first.studentName, 'Alice');

      cubit.close();
    });

    test('BatchCubit emits BatchError on server failure response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiService = BatchApiService(
        baseUrl: 'https://test.api/v1',
        client: mockClient,
      );
      final repository = BatchRepositoryImpl(apiService: apiService);
      final cubit = BatchCubit(repository: repository);

      await cubit.startBatchEvaluation(
        userIds: ['s1'],
        assignmentTag: 'Lab 1',
      );

      expect(cubit.state, isA<BatchError>());
      final error = cubit.state as BatchError;
      expect(error.message, contains('Failed to initiate batch evaluation'));

      cubit.close();
    });
  });
}
