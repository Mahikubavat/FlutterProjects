import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_plagiarism_app/similarity_engine.dart';

void main() {
  group('SimilarityEngine Unit Tests', () {
    test('calculateCosineSimilarity returns 100% for identical texts', () {
      const text1 = "The quick brown fox jumps over the lazy dog";
      const text2 = "The quick brown fox jumps over the lazy dog";

      final score = SimilarityEngine.calculateCosineSimilarity(text1, text2);
      expect(score, closeTo(100.0, 0.01));
    });

    test('calculateCosineSimilarity returns 0% for completely disjoint texts', () {
      const text1 = "apple banana orange";
      const text2 = "cat dog elephant";

      final score = SimilarityEngine.calculateCosineSimilarity(text1, text2);
      expect(score, equals(0.0));
    });

    test('normalizeWord converts numeric strings removing leading zeros', () {
      expect(SimilarityEngine.normalizeWord("05"), equals("5"));
      expect(SimilarityEngine.normalizeWord("00123"), equals("123"));
      expect(SimilarityEngine.normalizeWord("Hello"), equals("hello"));
    });

    test('getMatchingWords ignores stopwords and normalizes numbers', () {
      const text1 = "The project number is 05 and sample item.";
      const text2 = "A project with item number 5 and another sample.";

      final matches = SimilarityEngine.getMatchingWords(text1, text2);

      expect(matches, containsAll(['project', 'number', '5', 'sample', 'item']));
      expect(matches.contains('the'), isFalse);
      expect(matches.contains('and'), isFalse);
    });
  });
}
