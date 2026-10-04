import 'dart:math';

import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import '../models/match_range.dart';
import '../models/token_span.dart';

/// Local, offline similarity engine. No API key or network access is
/// required, which keeps this prototype runnable anywhere and free to
/// use. See README.md for how to swap/augment this with an LLM-based
/// semantic comparison.
///
/// Technique (a simplified version of shingling used by tools like MOSS):
///  1. Tokenize each document into words, keeping character offsets.
///  2. Build overlapping windows of [shingleSize] consecutive words
///     ("shingles"). Two documents that share a shingle very likely
///     share that exact phrase - a strong copy-paste signal.
///  3. Jaccard similarity over the shingle sets gives a "structural"
///     similarity score, and the matching shingles' offsets tell us
///     exactly which text to highlight.
///  4. Cosine similarity over TF-IDF word vectors (with academic and filler
///     stopwords filtered) gives a "topical" similarity score that detects
///     paraphrases without false positives from generic lab report wording.
///  5. The two scores are blended into one overall score for ranking.
class SimilarityService {
  static const int shingleSize = 6;
  static const double shingleWeight = 0.7;
  static const double cosineWeight = 0.3;

  static List<TokenSpan> _tokenize(String text) {
    final tokens = <TokenSpan>[];
    final regex = RegExp(r"[A-Za-z0-9']+(?:\.[0-9]+)?");
    for (final m in regex.allMatches(text)) {
      tokens.add(TokenSpan(
          text.substring(m.start, m.end).toLowerCase(), m.start, m.end));
    }
    return tokens;
  }

  /// Maps each shingle (as its literal joined text, used as a cheap
  /// hash key) to the character range it occupies in the source text.
  static Map<String, MatchRange> _buildShingleMap(List<TokenSpan> tokens) {
    final map = <String, MatchRange>{};
    if (tokens.isEmpty) return map;

    if (tokens.length < shingleSize) {
      final key = tokens.map((t) => t.text).join(' ');
      map[key] = MatchRange(tokens.first.start, tokens.last.end);
      return map;
    }

    for (int i = 0; i <= tokens.length - shingleSize; i++) {
      final window = tokens.sublist(i, i + shingleSize);
      final key = window.map((t) => t.text).join(' ');
      map[key] = MatchRange(window.first.start, window.last.end);
    }
    return map;
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final union = a.union(b).length;
    if (union == 0) return 0;
    return a.intersection(b).length / union;
  }

  /// Common academic & laboratory report boilerplate words that appear in
  /// almost all reports regardless of subject. Filtering these prevents
  /// unrelated lab reports from falsely registering high cosine similarity.
  static const Set<String> _academicStopWords = {
    'experiment', 'experimentally', 'experiments', 'laboratory', 'lab', 'report',
    'purpose', 'objective', 'aim', 'objectives', 'procedure', 'methodology',
    'method', 'apparatus', 'equipment', 'setup', 'materials', 'measurement',
    'measurements', 'measured', 'measure', 'data', 'recorded', 'recording',
    'records', 'trial', 'trials', 'results', 'result', 'analysis', 'analyzed',
    'discussion', 'conclusion', 'conclusions', 'concluded', 'error', 'errors',
    'sources', 'source', 'percent', 'percentage', 'graph', 'graphs', 'slope',
    'table', 'figure', 'theoretical', 'theory', 'verified', 'verify', 'verifying',
    'calculated', 'calculation', 'calculations', 'observed', 'observations',
    'observe', 'value', 'values', 'accepted', 'consistent', 'relationship',
    'study', 'investigates', 'investigation', 'investigated', 'determine',
    'determining', 'determined', 'using', 'used', 'shows', 'shown', 'derived',
    'hypothesis', 'background', 'abstract', 'introduction',
  };

  /// Builds term frequency with TF-IDF weighting and boilerplate removal.
  static Map<String, double> _termFrequency(
    List<TokenSpan> tokens, {
    Map<String, double>? idfWeights,
  }) {
    final rawFreq = <String, double>{};
    double total = 0;
    for (final t in tokens) {
      final word = t.text;
      if (_fillerWords.contains(word) ||
          _academicStopWords.contains(word) ||
          _digitsOnly.hasMatch(word)) {
        continue;
      }
      rawFreq[word] = (rawFreq[word] ?? 0) + 1.0;
      total += 1.0;
    }
    if (total == 0) return rawFreq;

    final weighted = <String, double>{};
    for (final entry in rawFreq.entries) {
      final tf = entry.value / total;
      final idf = idfWeights != null ? (idfWeights[entry.key] ?? 1.0) : 1.0;
      weighted[entry.key] = tf * idf;
    }
    return weighted;
  }

  /// Computes Inverse Document Frequency (IDF) over a set of documents.
  static Map<String, double> computeIdf(List<AssignmentDocument> docs) {
    if (docs.isEmpty) return {};
    final docCount = docs.length;
    final docFreq = <String, int>{};
    for (final doc in docs) {
      final tokens = _tokenize(doc.cleanedText);
      final uniqueTerms = tokens.map((t) => t.text).toSet();
      for (final term in uniqueTerms) {
        if (!_fillerWords.contains(term) &&
            !_academicStopWords.contains(term) &&
            !_digitsOnly.hasMatch(term)) {
          docFreq[term] = (docFreq[term] ?? 0) + 1;
        }
      }
    }
    final idf = <String, double>{};
    for (final entry in docFreq.entries) {
      // Smooth IDF formula
      idf[entry.key] = log((docCount + 1.0) / (entry.value + 1.0)) + 1.0;
    }
    return idf;
  }

  static double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    final keys = {...a.keys, ...b.keys};
    double dot = 0, magA = 0, magB = 0;
    for (final k in keys) {
      final va = a[k] ?? 0.0;
      final vb = b[k] ?? 0.0;
      dot += va * vb;
      magA += va * va;
      magB += vb * vb;
    }
    if (magA == 0 || magB == 0) return 0;
    return dot / (sqrt(magA) * sqrt(magB));
  }

  /// Highlighting detects runs of [highlightWords] or more shared words,
  /// including table rows, numerical data, and structural sentences.
  static const int highlightWords = 3;

  /// A shared run must contain at least this many meaningful words.
  /// Numbers and measurements in tables and lab data are valid content words.
  static const int minContentWords = 2;

  static final RegExp _digitsOnly = RegExp(r'^\d+(\.\d+)?$');

  static const Set<String> _fillerWords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'being', 'but', 'by',
    'can', 'could', 'did', 'do', 'does', 'for', 'from', 'had', 'has', 'have',
    'he', 'her', 'his', 'how', 'i', 'if', 'in', 'into', 'is', 'it', 'its',
    'may', 'my', 'not', 'of', 'on', 'or', 'our', 'she', 'should', 'so', 'such',
    'than', 'that', 'the', 'their', 'them', 'then', 'there', 'these', 'they',
    'this', 'those', 'to', 'us', 'was', 'were', 'what', 'when', 'where',
    'which', 'who', 'will', 'with', 'would', 'you', 'your', 'we', 'all', 'any',
    'each', 'also',
    // Every extracted document starts each page with a "Page N" heading.
    'page',
  };

  static String _phraseKey(List<TokenSpan> tokens, int start) {
    final buffer = StringBuffer(tokens[start].text);
    for (var i = start + 1; i < start + highlightWords; i++) {
      buffer.write(' ');
      buffer.write(tokens[i].text);
    }
    return buffer.toString();
  }

  /// Builds reciprocal, paired matching ranges between Document A and Document B.
  /// This guarantees that both documents have the exact same number of matches,
  /// and each match index directly aligns the passage in A with its counterpart in B.
  static (List<MatchRange>, List<MatchRange>) _buildPairedRanges(
    List<TokenSpan> tokensA,
    List<TokenSpan> tokensB,
  ) {
    if (tokensA.length < highlightWords || tokensB.length < highlightWords) {
      return (<MatchRange>[], <MatchRange>[]);
    }

    final mapA = <String, List<int>>{};
    for (var i = 0; i + highlightWords <= tokensA.length; i++) {
      final key = _phraseKey(tokensA, i);
      mapA.putIfAbsent(key, () => []).add(i);
    }

    final mapB = <String, List<int>>{};
    for (var j = 0; j + highlightWords <= tokensB.length; j++) {
      final key = _phraseKey(tokensB, j);
      mapB.putIfAbsent(key, () => []).add(j);
    }

    final sharedKeys = mapA.keys.toSet().intersection(mapB.keys.toSet());
    if (sharedKeys.isEmpty) {
      return (<MatchRange>[], <MatchRange>[]);
    }

    final coveredA = List<bool>.filled(tokensA.length, false);
    for (final key in sharedKeys) {
      for (final startIdx in mapA[key]!) {
        for (var k = 0; k < highlightWords; k++) {
          coveredA[startIdx + k] = true;
        }
      }
    }

    final coveredB = List<bool>.filled(tokensB.length, false);
    for (final key in sharedKeys) {
      for (final startIdx in mapB[key]!) {
        for (var k = 0; k < highlightWords; k++) {
          coveredB[startIdx + k] = true;
        }
      }
    }

    final rawRangesA = <({int tokenStart, int tokenEnd, MatchRange charRange})>[];
    var i = 0;
    while (i < tokensA.length) {
      if (!coveredA[i]) {
        i++;
        continue;
      }
      var end = i;
      while (end + 1 < tokensA.length && coveredA[end + 1]) {
        end++;
      }
      var content = 0;
      for (var k = i; k <= end; k++) {
        if (!_fillerWords.contains(tokensA[k].text)) content++;
      }
      if (content >= minContentWords) {
        rawRangesA.add((
          tokenStart: i,
          tokenEnd: end,
          charRange: MatchRange(tokensA[i].start, tokensA[end].end),
        ));
      }
      i = end + 1;
    }

    final rawRangesB = <({int tokenStart, int tokenEnd, MatchRange charRange})>[];
    var j = 0;
    while (j < tokensB.length) {
      if (!coveredB[j]) {
        j++;
        continue;
      }
      var end = j;
      while (end + 1 < tokensB.length && coveredB[end + 1]) {
        end++;
      }
      var content = 0;
      for (var k = j; k <= end; k++) {
        if (!_fillerWords.contains(tokensB[k].text)) content++;
      }
      if (content >= minContentWords) {
        rawRangesB.add((
          tokenStart: j,
          tokenEnd: end,
          charRange: MatchRange(tokensB[j].start, tokensB[end].end),
        ));
      }
      j = end + 1;
    }

    if (rawRangesA.isEmpty || rawRangesB.isEmpty) {
      return (<MatchRange>[], <MatchRange>[]);
    }

    final pairedA = <MatchRange>[];
    final pairedB = <MatchRange>[];

    final bPhraseSets = rawRangesB.map((segB) {
      final set = <String>{};
      for (var k = segB.tokenStart; k + highlightWords <= segB.tokenEnd + 1; k++) {
        if (k + highlightWords <= tokensB.length) {
          set.add(_phraseKey(tokensB, k));
        }
      }
      return set;
    }).toList();

    final matchedBIndices = <int>{};

    for (final segA in rawRangesA) {
      final aSet = <String>{};
      for (var k = segA.tokenStart; k + highlightWords <= segA.tokenEnd + 1; k++) {
        if (k + highlightWords <= tokensA.length) {
          aSet.add(_phraseKey(tokensA, k));
        }
      }

      int bestBIdx = 0;
      int maxOverlap = -1;
      for (var bIdx = 0; bIdx < rawRangesB.length; bIdx++) {
        final overlap = aSet.intersection(bPhraseSets[bIdx]).length;
        if (overlap > maxOverlap) {
          maxOverlap = overlap;
          bestBIdx = bIdx;
        }
      }

      pairedA.add(segA.charRange);
      pairedB.add(rawRangesB[bestBIdx].charRange);
      matchedBIndices.add(bestBIdx);
    }

    for (var bIdx = 0; bIdx < rawRangesB.length; bIdx++) {
      if (!matchedBIndices.contains(bIdx)) {
        final bSet = bPhraseSets[bIdx];
        int bestAIdx = 0;
        int maxOverlap = -1;
        for (var aIdx = 0; aIdx < rawRangesA.length; aIdx++) {
          final segA = rawRangesA[aIdx];
          final aSet = <String>{};
          for (var k = segA.tokenStart; k + highlightWords <= segA.tokenEnd + 1; k++) {
            if (k + highlightWords <= tokensA.length) {
              aSet.add(_phraseKey(tokensA, k));
            }
          }
          final overlap = bSet.intersection(aSet).length;
          if (overlap > maxOverlap) {
            maxOverlap = overlap;
            bestAIdx = aIdx;
          }
        }
        pairedA.add(rawRangesA[bestAIdx].charRange);
        pairedB.add(rawRangesB[bIdx].charRange);
      }
    }

    return (pairedA, pairedB);
  }

  static ComparisonResult compare(
    AssignmentDocument a,
    AssignmentDocument b, {
    Map<String, double>? idfWeights,
  }) {
    final tokensA = _tokenize(a.cleanedText);
    final tokensB = _tokenize(b.cleanedText);

    final shinglesA = _buildShingleMap(tokensA);
    final shinglesB = _buildShingleMap(tokensB);

    final keysA = shinglesA.keys.toSet();
    final keysB = shinglesB.keys.toSet();
    final jaccard = _jaccard(keysA, keysB);

    final tfA = _termFrequency(tokensA, idfWeights: idfWeights);
    final tfB = _termFrequency(tokensB, idfWeights: idfWeights);
    final cosine = _cosineSimilarity(tfA, tfB);

    final (rangesA, rangesB) = _buildPairedRanges(tokensA, tokensB);

    return ComparisonResult(
      docAId: a.id,
      docBId: b.id,
      docAName: a.fileName,
      docBName: b.fileName,
      shingleSimilarity: jaccard,
      cosineSimilarity: cosine,
      overallScore: (jaccard * shingleWeight) + (cosine * cosineWeight),
      matchedRangesA: rangesA,
      matchedRangesB: rangesB,
    );
  }

  /// Runs every pairwise comparison across the uploaded set (N choose 2)
  /// and returns results sorted by descending overall similarity.
  static List<ComparisonResult> compareAll(List<AssignmentDocument> docs) {
    final idf = computeIdf(docs);
    final results = <ComparisonResult>[];
    for (int i = 0; i < docs.length; i++) {
      for (int j = i + 1; j < docs.length; j++) {
        results.add(compare(docs[i], docs[j], idfWeights: idf));
      }
    }
    results.sort((x, y) => y.overallScore.compareTo(x.overallScore));
    return results;
  }

  static Future<List<ComparisonResult>> compareAllAsync(
      List<AssignmentDocument> docs) async {
    final idf = computeIdf(docs);
    final results = <ComparisonResult>[];
    for (int i = 0; i < docs.length; i++) {
      for (int j = i + 1; j < docs.length; j++) {
        results.add(compare(docs[i], docs[j], idfWeights: idf));
        await Future<void>.delayed(Duration.zero);
      }
    }
    results.sort((x, y) => y.overallScore.compareTo(x.overallScore));
    return results;
  }
}
