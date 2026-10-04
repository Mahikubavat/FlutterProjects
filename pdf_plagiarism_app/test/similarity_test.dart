import 'package:flutter_test/flutter_test.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/sample_data/sample_documents.dart';
import 'package:plagiarism_checker/services/similarity_service.dart';

void main() {
  test('SimilarityService detects plagiarism between Sample A and Sample B', () {
    final docs = SampleDocuments.all;
    expect(docs.length, 3);

    final results = SimilarityService.compareAll(docs);
    expect(results.length, 3);

    final pairAB = results.firstWhere((r) =>
        (r.docAName.contains('student_A') && r.docBName.contains('student_B')) ||
        (r.docAName.contains('student_B') && r.docBName.contains('student_A')));

    final pairAC = results.firstWhere((r) =>
        (r.docAName.contains('student_A') && r.docBName.contains('student_C')) ||
        (r.docAName.contains('student_C') && r.docBName.contains('student_A')));

    // A and B share almost the entire text
    expect(pairAB.overallScore, greaterThan(0.60));
    expect(pairAB.isHighRisk, isTrue);

    // Both documents must have the EXACT SAME number of matches
    expect(pairAB.matchedRangesA.length, equals(pairAB.matchedRangesB.length));
    expect(pairAC.matchedRangesA.length, equals(pairAC.matchedRangesB.length));

    // A and C are completely different lab reports
    expect(pairAC.overallScore, lessThan(0.40));
    expect(pairAC.isFlagged, isFalse);
  });

  test('SimilarityService detects matching tables and numerical data', () {
    const tableTextA = '''
Experiment 3: Reaction Rates and Stoichiometry Measurements
Trial | Concentration (M) | Temperature (K) | Reaction Rate (mol/L*s)
Trial 1 | 0.150 | 298.15 | 0.045
Trial 2 | 0.300 | 298.15 | 0.091
Trial 3 | 0.450 | 298.15 | 0.136
Trial 4 | 0.150 | 308.15 | 0.089
Trial 5 | 0.150 | 318.15 | 0.178
Conclusion: Rate increases linearly with concentration and exponentially with temperature.
''';

    const tableTextB = '''
Lab Submission - Stoichiometry Rate Law Findings
The measured experimental data table is recorded below:
Trial | Concentration (M) | Temperature (K) | Reaction Rate (mol/L*s)
Trial 1 | 0.150 | 298.15 | 0.045
Trial 2 | 0.300 | 298.15 | 0.091
Trial 3 | 0.450 | 298.15 | 0.136
Trial 4 | 0.150 | 308.15 | 0.089
Trial 5 | 0.150 | 318.15 | 0.178
Final remarks: The reaction order with respect to concentration is determined to be 1.
''';

    const doc1 = AssignmentDocument(
      id: 'doc1',
      fileName: 'student_1_data.pdf',
      rawText: tableTextA,
    );
    const doc2 = AssignmentDocument(
      id: 'doc2',
      fileName: 'student_2_data.pdf',
      rawText: tableTextB,
    );

    final res = SimilarityService.compare(doc1, doc2);

    // Verifies that table data is detected and matched
    expect(res.matchedRangesA.isNotEmpty, isTrue);
    expect(res.matchedRangesB.isNotEmpty, isTrue);
    // Verifies that both documents have the exact same match count
    expect(res.matchedRangesA.length, equals(res.matchedRangesB.length));
    expect(res.overallScore, greaterThan(0.35));
  });
}
