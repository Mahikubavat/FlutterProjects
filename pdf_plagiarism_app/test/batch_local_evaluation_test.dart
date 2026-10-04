import 'package:flutter_test/flutter_test.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/models/batch_report_model.dart';
import 'package:plagiarism_checker/services/batch_api_service.dart';
import 'package:plagiarism_checker/services/batch_repository.dart';
import 'package:plagiarism_checker/services/similarity_service.dart';
import 'package:plagiarism_checker/state/batch_cubit.dart';

void main() {
  group('Batch Tag Matching & Local Evaluation Tests', () {
    bool matchesTag(String fileName, String tag) {
      final cleanTag = tag.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanTag.isEmpty || cleanTag == 'all' || cleanTag == 'any' || cleanTag == '*') {
        return true;
      }
      final cleanName = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return cleanName.contains(cleanTag);
    }

    test('Tag "lab1" matches various lab 1 file naming conventions', () {
      expect(matchesTag('lab1_st1.pdf', 'lab1'), isTrue);
      expect(matchesTag('lab1_st2.pdf', 'lab1'), isTrue);
      expect(matchesTag('Lab 1 - Final.pdf', 'lab1'), isTrue);
      expect(matchesTag('lab_1_assignment.docx', 'lab1'), isTrue);
      expect(matchesTag('lab2_st1.pdf', 'lab1'), isFalse);
      expect(matchesTag('homework_3.pdf', 'lab1'), isFalse);
    });

    test('Empty, all, or wildcard tag matches all files', () {
      expect(matchesTag('sample1.txt', ''), isTrue);
      expect(matchesTag('lab1_st1.pdf', 'all'), isTrue);
      expect(matchesTag('lab2_st2.pdf', '*'), isTrue);
    });

    test('BatchCubit setLoading and setError update state without network calls', () {
      final repository = BatchRepositoryImpl(apiService: BatchApiService());
      final cubit = BatchCubit(repository: repository);

      expect(cubit.state, isA<BatchInitial>());

      cubit.setLoading(0.35);
      expect(cubit.state, isA<BatchLoading>());
      expect((cubit.state as BatchLoading).progress, 0.35);

      cubit.setError('Local similarity comparison failed');
      expect(cubit.state, isA<BatchError>());
      expect((cubit.state as BatchError).message, 'Local similarity comparison failed');

      cubit.setSuccessReport(
        const BatchReportModel(
          batchJobId: 'batch_test_01',
          status: 'COMPLETED',
          progress: 1.0,
          reports: [
            StudentReport(
              studentId: 'st1',
              studentName: 'Student 1',
              maxScore: 0.95,
              topPeerName: 'Student 2',
              flagged: true,
            ),
          ],
        ),
      );

      expect(cubit.state, isA<BatchSuccess>());
      final success = cubit.state as BatchSuccess;
      expect(success.report.reports.first.studentName, 'Student 1');
      expect(success.report.reports.first.maxScore, 0.95);

      cubit.close();
    });

    test('Pairwise similarity engine correctly evaluates lab documents', () {
      const docA = AssignmentDocument(
        id: 'docA',
        ownerId: 'student1',
        ownerName: 'Student 1',
        fileName: 'lab1_st1.pdf',
        rawText: 'In this physics laboratory experiment we measure gravitational acceleration using a pendulum.',
      );

      const docB = AssignmentDocument(
        id: 'docB',
        ownerId: 'student2',
        ownerName: 'Student 2',
        fileName: 'lab1_st2.pdf',
        rawText: 'In this physics laboratory experiment we measure gravitational acceleration using a pendulum with length L.',
      );

      const docC = AssignmentDocument(
        id: 'docC',
        ownerId: 'student3',
        ownerName: 'Student 3',
        fileName: 'lab1_st3.pdf',
        rawText: 'Cellular respiration occurs in the mitochondria of eukaryotic cells involving ATP synthesis.',
      );

      final compAB = SimilarityService.compare(docA, docB);
      final compAC = SimilarityService.compare(docA, docC);

      expect(compAB.overallScore, greaterThan(0.70));
      expect(compAC.overallScore, lessThan(0.20));
    });
  });
}
