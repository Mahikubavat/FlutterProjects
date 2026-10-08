import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/comparison_result.dart';

/// Builds a professional downloadable/printable PDF summary report
/// and provides robust methods to Print / Save as PDF, Save to Device Storage, or Share.
class ReportService {
  /// Generates the raw PDF bytes for the given comparison results.
  static Future<Uint8List> generateReportBytes(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    final doc = pw.Document();

    final highRisk = results.where((r) => r.isHighRisk).length;
    final review = results.where((r) => r.isFlagged && !r.isHighRisk).length;
    final low = results.length - highRisk - review;

    final dateStr =
        '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
        '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Plagiarism & Similarity Analysis Report',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Header Card
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Plagiarism Detection Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Generated on $dateStr • Total Document Pairs Evaluated: ${results.length}',
                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    _buildStatCard('Total Pairs', '${results.length}', PdfColors.blueGrey800),
                    pw.SizedBox(width: 8),
                    _buildStatCard('High Risk (>=60%)', '$highRisk', PdfColors.red700),
                    pw.SizedBox(width: 8),
                    _buildStatCard('Needs Review', '$review', PdfColors.amber800),
                    pw.SizedBox(width: 8),
                    _buildStatCard('Low / Safe', '$low', PdfColors.green700),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'Pairwise Analysis Breakdown',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),

          // Comparison Table with defined column widths to prevent page overflow
          pw.TableHelper.fromTextArray(
            headers: [
              'Document A',
              'Document B',
              'Phrase Match',
              'Word Overlap',
              'Semantic',
              'Overall',
              'Status',
            ],
            data: results.map((r) {
              final overallPct = (r.overallScore * 100).toStringAsFixed(1);
              final shinglePct = (r.shingleSimilarity * 100).toStringAsFixed(1);
              final cosinePct = (r.cosineSimilarity * 100).toStringAsFixed(1);
              final semPct = r.semanticSimilarity != null
                  ? '${(r.semanticSimilarity! * 100).toStringAsFixed(1)}%'
                  : '-';
              final status = r.isHighRisk
                  ? 'HIGH RISK'
                  : (r.isFlagged ? 'Needs Review' : 'Low / Clean');

              return [
                r.docAName,
                r.docBName,
                '$shinglePct%',
                '$cosinePct%',
                semPct,
                '$overallPct%',
                status,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8.5,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            columnWidths: {
              0: const pw.FlexColumnWidth(3.0),
              1: const pw.FlexColumnWidth(3.0),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FlexColumnWidth(1.4),
              6: const pw.FlexColumnWidth(1.8),
            },
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          ),
          pw.SizedBox(height: 16),

          // Methodology Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Methodology & Scoring System',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '• Phrase Match (Shingle Similarity): Detects verbatim and near-verbatim 8-word sequence overlap.\n'
                  '• Word Overlap (Cosine Similarity): Measures vocabulary and structural term frequency distribution.\n'
                  '• Semantic Similarity: Evaluates deep conceptual paraphrasing through AI language embeddings.\n'
                  '• Thresholds: Scores >= 60% are classified as High Risk; scores 40%-59% require instructor review.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700, lineSpacing: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return await doc.save();
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: color),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  /// Primary Android/iOS/Desktop method: Opens the system Print / "Save as PDF" spooler.
  /// On Android, this opens the standard Android Print Preview which includes "Save as PDF".
  static Future<bool> printOrSaveAsPdf(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    final bytes = await generateReportBytes(results, generatedAt);
    final filename = 'Plagiarism_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return await Printing.layoutPdf(
      name: filename,
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  /// Directly saves the PDF file into the device's Downloads directory (Android) or Documents.
  static Future<String?> savePdfToDevice(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    final bytes = await generateReportBytes(results, generatedAt);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'Plagiarism_Report_$timestamp.pdf';

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$filename');
          await file.writeAsBytes(bytes, flush: true);
          return file.path;
        }
      }
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (_) {
        return null;
      }
    }
  }

  /// Shares the PDF via external apps (WhatsApp, Gmail, Telegram, Google Drive, etc.).
  static Future<void> sharePdf(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    final bytes = await generateReportBytes(results, generatedAt);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'Plagiarism_Report_$timestamp.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Legacy helper for backwards compatibility.
  static Future<void> generateAndShareReport(
    List<ComparisonResult> results,
    DateTime generatedAt,
  ) async {
    // Attempt system Print / Save-as-PDF first, fall back to share
    try {
      await printOrSaveAsPdf(results, generatedAt);
    } catch (_) {
      await sharePdf(results, generatedAt);
    }
  }
}
