import 'match_range.dart';

/// The outcome of comparing two documents: two independent similarity
/// metrics (blended into an overall score) plus the exact text ranges
/// that matched in each document, for highlighting.
class ComparisonResult {
  final String docAId;
  final String docBId;
  final String docAName;
  final String docBName;

  /// Fraction (0-1) of overlapping 8-word phrases (shingles). Good at
  /// catching copy-pasted / lightly reworded passages.
  final double shingleSimilarity;

  /// Fraction (0-1) cosine similarity over word-frequency vectors. Good
  /// at catching overall topical/structural similarity.
  final double cosineSimilarity;

  /// Weighted blend used for sorting and flagging: 70% shingle + 30% cosine.
  final double overallScore;

  /// Optional LLM score for deep paraphrase detection.
  final double? semanticSimilarity;

  final List<MatchRange> matchedRangesA;
  final List<MatchRange> matchedRangesB;

  const ComparisonResult({
    required this.docAId,
    required this.docBId,
    required this.docAName,
    required this.docBName,
    required this.shingleSimilarity,
    required this.cosineSimilarity,
    required this.overallScore,
    this.semanticSimilarity,
    required this.matchedRangesA,
    required this.matchedRangesB,
  });

  bool get isFlagged => overallScore >= 0.4;
  bool get isHighRisk => overallScore >= 0.6;

  ComparisonResult withSemanticSimilarity(double score) {
    final blended =
        (shingleSimilarity * 0.55) + (cosineSimilarity * 0.15) + (score * 0.30);
    return ComparisonResult(
      docAId: docAId,
      docBId: docBId,
      docAName: docAName,
      docBName: docBName,
      shingleSimilarity: shingleSimilarity,
      cosineSimilarity: cosineSimilarity,
      overallScore: blended,
      semanticSimilarity: score,
      matchedRangesA: matchedRangesA,
      matchedRangesB: matchedRangesB,
    );
  }

  Map<String, dynamic> toMap() => {
        'docAId': docAId,
        'docBId': docBId,
        'docAName': docAName,
        'docBName': docBName,
        'shingleSimilarity': shingleSimilarity,
        'cosineSimilarity': cosineSimilarity,
        'overallScore': overallScore,
        'semanticSimilarity': semanticSimilarity,
        'matchedRangesA': matchedRangesA.map((r) => r.toMap()).toList(),
        'matchedRangesB': matchedRangesB.map((r) => r.toMap()).toList(),
      };

  factory ComparisonResult.fromMap(Map<String, dynamic> map) => ComparisonResult(
        docAId: map['docAId'] as String,
        docBId: map['docBId'] as String,
        docAName: map['docAName'] as String,
        docBName: map['docBName'] as String,
        shingleSimilarity: (map['shingleSimilarity'] as num).toDouble(),
        cosineSimilarity: (map['cosineSimilarity'] as num).toDouble(),
        overallScore: (map['overallScore'] as num).toDouble(),
        semanticSimilarity: (map['semanticSimilarity'] as num?)?.toDouble(),
        matchedRangesA: (map['matchedRangesA'] as List<dynamic>?)
                ?.map((e) => MatchRange.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        matchedRangesB: (map['matchedRangesB'] as List<dynamic>?)
                ?.map((e) => MatchRange.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
