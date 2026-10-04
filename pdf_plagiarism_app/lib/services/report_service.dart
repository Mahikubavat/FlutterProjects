import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/comparison_result.dart';

/// Builds a downloadable/printable PDF summary report from a set of
/// comparison results and hands it to the OS share/print sheet
/// (works for "Save as PDF", printing, or opening in another app).
class ReportService {
  static Future<void> generateAndShareReport(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'Plagiarism Detection Report'),
          pw.Text('Generated: $generatedAt'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Method: local shingle + cosine similarity, optionally blended '
            'with an LLM semantic similarity score.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Document A',
              'Document B',
              'Shingle %',
              'Cosine %',
              'Semantic %',
              'Overall %',
              'Flag'
            ],
            data: results
                .map((r) => [
                      r.docAName,
                      r.docBName,
                      (r.shingleSimilarity * 100).toStringAsFixed(1),
                      (r.cosineSimilarity * 100).toStringAsFixed(1),
                      r.semanticSimilarity == null
                          ? '-'
                          : (r.semanticSimilarity! * 100).toStringAsFixed(1),
                      (r.overallScore * 100).toStringAsFixed(1),
                      r.isHighRisk
                          ? 'HIGH RISK'
                          : (r.isFlagged ? 'Review' : ''),
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Pairs at or above 40% overall similarity are flagged for manual '
            'review; 60%+ is marked as high risk. These thresholds are '
            'tunable in similarity_service.dart / this report.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
        bytes: await doc.save(), filename: 'plagiarism_report.pdf');
  }
}
