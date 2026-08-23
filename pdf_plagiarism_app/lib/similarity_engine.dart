import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SimilarityEngine {
  // 1. Reads raw bytes from a PDF and converts them to plain text
  static String extractTextFromPdf(File pdfFile) {
    final PdfDocument document = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
    final String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  // 2. Compares word frequencies between two text strings
  static double calculateCosineSimilarity(String text1, String text2) {
    Map<String, int> getFrequencies(String text) {
      final words = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));
      final Map<String, int> freq = {};
      for (var word in words) {
        if (word.trim().isEmpty) continue;
        freq[word] = (freq[word] ?? 0) + 1;
      }
      return freq;
    }

    final freq1 = getFrequencies(text1);
    final freq2 = getFrequencies(text2);
    final allWords = {...freq1.keys, ...freq2.keys};

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var word in allWords) {
      final count1 = freq1[word] ?? 0;
      final count2 = freq2[word] ?? 0;
      dotProduct += count1 * count2;
      normA += count1 * count1;
      normB += count2 * count2;
    }

    if (normA == 0 || normB == 0) return 0.0;
    return (dotProduct / (sqrt(normA) * sqrt(normB))) * 100;
  }
}