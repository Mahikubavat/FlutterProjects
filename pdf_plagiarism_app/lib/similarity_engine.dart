import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SimilarityEngine {
  /// Extracts text from image file
  static Future<String> extractTextFromImagePath(String filePath) async {
    throw UnsupportedError("Use OcrService for OCR text extraction.");
  }

  /// Extracts PDF text and merges fragmented lines into natural paragraphs
  static String extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();

      return text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();
    } catch (e) {
      debugPrint("Error reading PDF bytes: $e");
      return "";
    }
  }

  /// Calculates Cosine Similarity Percentage
  static double calculateCosineSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;

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

  /// Helper to convert numbers like "05" -> "5" so they match regardless of leading zeros
  static String normalizeWord(String word) {
    String clean = word.toLowerCase().trim();
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      return int.parse(clean).toString();
    }
    return clean;
  }

  /// Extracts shared words AND numbers, splitting hyphens and punctuation cleanly
  static Set<String> getMatchingWords(String text1, String text2) {
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'is', 'are', 'was', 'were',
      'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from', 'this',
      'that', 'it', 'as', 'be', 'has', 'have', 'had', 'not', 'you', 'we'
    };

    Set<String> extractWords(String text) {
      return text
      // Split by spaces, hyphens, colons, dots, and punctuation
          .split(RegExp(r'[^\w]+'))
          .map((w) => normalizeWord(w))
          .where((w) => w.isNotEmpty && !stopWords.contains(w))
          .toSet();
    }

    final words1 = extractWords(text1);
    final words2 = extractWords(text2);

    return words1.intersection(words2);
  }
}