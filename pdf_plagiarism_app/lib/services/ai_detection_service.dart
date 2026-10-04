import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Authorship categorization distinguishing between fully synthetic generation
/// and original human drafts with grammatical/tone polishing.
enum AiAuthorshipType {
  humanOriginal,
  aiEdited,
  aiGenerated,
  hybridCoCreated;

  String get id => switch (this) {
        humanOriginal => 'human',
        aiEdited => 'ai_edited',
        aiGenerated => 'ai_generated',
        hybridCoCreated => 'hybrid',
      };

  String get label => switch (this) {
        humanOriginal => 'Human Original',
        aiEdited => 'AI-Edited / Polished',
        aiGenerated => 'Synthetic AI Generation',
        hybridCoCreated => 'Hybrid / Heavy AI Revision',
      };

  String get shortBadge => switch (this) {
        humanOriginal => 'Human Draft',
        aiEdited => 'AI-Polished',
        aiGenerated => 'AI-Generated',
        hybridCoCreated => 'Hybrid AI',
      };

  static AiAuthorshipType fromId(String? id) => switch (id) {
        'ai_edited' => aiEdited,
        'ai_generated' => aiGenerated,
        'hybrid' => hybridCoCreated,
        _ => humanOriginal,
      };
}

/// Comprehensive dual-layer result separating synthetic creation from grammar/tone polish.
class AiDetectionResult {
  final double probability; // Overall AI footprint (0.0 to 1.0)
  final double syntheticScore; // Layer 1: Content generated from scratch (0.0 to 1.0)
  final double editingScore; // Layer 2: Grammatical / tone assistance (0.0 to 1.0)
  final AiAuthorshipType classification;
  final String explanation;
  final List<String> detectedMarkers;
  final double burstinessScore; // 0.0 (mechanical uniformity) to 1.0 (organic cadence)
  final double vocabularyRichness; // 0.0 to 1.0
  final String method;

  const AiDetectionResult({
    required this.probability,
    required this.syntheticScore,
    required this.editingScore,
    required this.classification,
    required this.explanation,
    required this.detectedMarkers,
    required this.burstinessScore,
    required this.vocabularyRichness,
    required this.method,
  });
}

/// Dual-layer classification engine separating synthetic generation (content created
/// from scratch by AI) from grammatical/tone assistance (human draft polished by AI tools).
class AiDetectionService {
  final String apiKey;
  final String endpoint;
  final String model;
  final http.Client _client;

  AiDetectionService({
    required this.apiKey,
    this.endpoint = const String.fromEnvironment(
      'AI_DETECTION_ENDPOINT',
      defaultValue: 'https://api.openai.com/v1/chat/completions',
    ),
    this.model = const String.fromEnvironment(
      'AI_DETECTION_MODEL',
      defaultValue: 'gpt-4o-mini',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static final List<String> _aiMarkerPatterns = [
    'delve',
    'delving',
    'multifaceted',
    'tapestry',
    'testament to',
    'crucial role',
    'pivotal role',
    'in conclusion',
    'in summary',
    'furthermore',
    'moreover',
    'it is important to note',
    'it is crucial to remember',
    'paramount',
    'beacon',
    'underscores',
    'fostering',
    'ever-evolving',
    'myriad',
    'interplay',
    'unraveling',
    'at the forefront',
    'poised to',
    'seamlessly',
    'embark on',
    'nuanced understanding',
    'holistic approach',
    'rich tapestry',
    'vital role',
    'significant milestone',
    'resonates deeply',
    'comprehensive overview',
    'meticulous attention',
    'dynamic landscape',
  ];

  static final List<String> _grammarPolishMarkers = [
    'additionally',
    'consequently',
    'subsequently',
    'demonstrating',
    'utilizing',
    'facilitating',
    'notably',
    'specifically',
    'primarily',
    'respectively',
    'illustrates',
    'exhibits',
    'constitutes',
    'nevertheless',
    'further analysis reveals',
    'as depicted in',
    'correspondingly',
  ];

  Future<AiDetectionResult> detect(String text) async {
    if (isConfigured) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'temperature': 0,
                'response_format': {'type': 'json_object'},
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'Classify whether the supplied student writing is AI-generated vs AI-edited. '
                        'Separate synthetic generation (content created from scratch) from grammatical/tone assistance (human draft polished with Grammarly or spellcheck). '
                        'Return JSON with: '
                        '"syntheticScore" (0.0 to 1.0), '
                        '"editingScore" (0.0 to 1.0), '
                        '"classification" ("human" | "ai_edited" | "ai_generated" | "hybrid"), '
                        '"explanation" (string justifying classification and preserving fairness for human drafts), '
                        '"detectedMarkers" (array of strings of AI cliches found).',
                  },
                  {'role': 'user', 'content': text},
                ],
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final content = (((body['choices'] as List).first
                  as Map<String, dynamic>)['message']
              as Map<String, dynamic>)['content'] as String;
          final result = jsonDecode(content) as Map<String, dynamic>;

          final synthetic = (result['syntheticScore'] as num?)?.toDouble() ?? 0.0;
          final editing = (result['editingScore'] as num?)?.toDouble() ?? 0.0;
          final classStr = result['classification'] as String?;
          final explanation = result['explanation'] as String? ??
              'Dual-layer assessment via cloud AI screening.';
          final markers = (result['detectedMarkers'] as List<dynamic>?)
                  ?.map((m) => m.toString())
                  .toList() ??
              const [];

          final classification = AiAuthorshipType.fromId(classStr);
          final overall = math.max(synthetic, editing * 0.5);

          return AiDetectionResult(
            probability: overall.clamp(0.0, 1.0),
            syntheticScore: synthetic.clamp(0.0, 1.0),
            editingScore: editing.clamp(0.0, 1.0),
            classification: classification,
            explanation: explanation,
            detectedMarkers: markers,
            burstinessScore: 0.5,
            vocabularyRichness: 0.5,
            method: 'Cloud Dual-Layer Screening Model',
          );
        }
      } catch (_) {
        // Fall back to the local dual-layer forensic engine
      }
    }

    return _heuristicDualLayerAnalysis(text);
  }

  /// Evaluates writing using linguistic metrics: burstiness (sentence length variance),
  /// vocabulary diversity, AI rhetorical markers, and surface-level grammar polish signals.
  AiDetectionResult _heuristicDualLayerAnalysis(String text) {
    final words = RegExp(r"[A-Za-z']+")
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    if (words.length < 25) {
      return const AiDetectionResult(
        probability: 0.0,
        syntheticScore: 0.0,
        editingScore: 0.0,
        classification: AiAuthorshipType.humanOriginal,
        explanation: 'Document is too brief for statistical authorship analysis (minimum 25 words required).',
        detectedMarkers: [],
        burstinessScore: 1.0,
        vocabularyRichness: 1.0,
        method: 'Local Dual-Layer Writing Signal Engine',
      );
    }

    // 1. Sentence segmentation & burstiness analysis
    final sentences = text
        .split(RegExp(r'[.!?]+(?:\s+|$)'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final sentenceLengths = sentences
        .map((s) => RegExp(r"[A-Za-z']+").allMatches(s).length)
        .where((l) => l > 0)
        .toList();

    double burstiness = 0.5;
    double meanLength = words.length.toDouble();
    double cv = 0.5;

    if (sentenceLengths.length >= 2) {
      meanLength = sentenceLengths.reduce((a, b) => a + b) / sentenceLengths.length;
      final variance = sentenceLengths
              .map((l) => (l - meanLength) * (l - meanLength))
              .reduce((a, b) => a + b) /
          sentenceLengths.length;
      final stdDev = math.sqrt(variance);
      cv = stdDev / (meanLength + 1e-4);
      // Natural human writing has high CV (> 0.55), while AI writing is monotonous (CV < 0.35)
      burstiness = (cv / 0.70).clamp(0.0, 1.0);
    }

    // 2. Vocabulary Richness (Type-Token Ratio)
    final uniqueCount = words.toSet().length;
    final ttr = uniqueCount / words.length;
    final vocabularyRichness = (ttr * 1.2).clamp(0.0, 1.0);

    // 3. AI Marker Cliché Scanning
    final lowerText = text.toLowerCase();
    final detectedAiMarkers = _aiMarkerPatterns
        .where((marker) => lowerText.contains(marker))
        .toList();

    final markerCount = detectedAiMarkers.length;
    final markerFactor = (markerCount * 0.22).clamp(0.0, 1.0);

    // 4. Polish / Assistance Markers (e.g. Grammarly transition smoothing)
    final detectedPolishMarkers = _grammarPolishMarkers
        .where((marker) => lowerText.contains(marker))
        .toList();
    final polishFactor = (detectedPolishMarkers.length * 0.20).clamp(0.0, 0.85);

    // 5. Punctuation Regularity
    final commaMatches = RegExp(r'[,;]').allMatches(text).length;
    final commasPer100 = (commaMatches / (words.length / 100)).clamp(0.0, 15.0);
    final punctuationSmoothness = (commasPer100 >= 3 && commasPer100 <= 10) ? 0.8 : 0.4;

    // =========================================================================
    // LAYER 1: SYNTHETIC GENERATION SCORE
    // High when: Low burstiness (monotonous sentence rhythm) + High AI markers + Low TTR
    // =========================================================================
    double syntheticScore = (
      0.45 * (1.0 - burstiness) +
      0.40 * markerFactor +
      0.15 * (1.0 - vocabularyRichness)
    ).clamp(0.0, 1.0);

    if (markerCount >= 3 && cv < 0.38) {
      syntheticScore = math.max(syntheticScore, 0.75);
    }

    if (burstiness > 0.65 && markerCount == 0) {
      // Strong human rhythm without AI clichés
      syntheticScore = math.min(syntheticScore, 0.20);
    }

    // =========================================================================
    // LAYER 2: GRAMMATICAL / TONE ASSISTANCE (AI-EDITED) SCORE
    // High when: Organic human rhythm (burstiness preserved) + High surface polish
    // =========================================================================
    double editingScore = (
      0.40 * polishFactor +
      0.30 * punctuationSmoothness +
      0.30 * burstiness
    ).clamp(0.0, 1.0);

    // If text was synthetically generated, editing is secondary
    if (syntheticScore >= 0.60) {
      editingScore = math.min(editingScore, 0.35);
    }

    // =========================================================================
    // DUAL-LAYER CLASSIFICATION DECISION
    // =========================================================================
    AiAuthorshipType classification;
    String explanation;

    if (syntheticScore >= 0.52) {
      classification = AiAuthorshipType.aiGenerated;
      final markerStr = detectedAiMarkers.isNotEmpty
          ? ' Detected formulaic markers: ${detectedAiMarkers.take(4).map((m) => '"$m"').join(', ')}.'
          : '';
      explanation =
          'High syntactic uniformity, low rhythm variance (${(burstiness * 100).round()}% burstiness), '
          'and algorithmic phrasing indicate this content was generated from scratch by an AI language model.$markerStr';
    } else if (editingScore >= 0.42 && syntheticScore < 0.35) {
      classification = AiAuthorshipType.aiEdited;
      explanation =
          'Human-authored draft with grammatical and tone assistance. The underlying sentence length '
          'variance (${(burstiness * 100).round()}% burstiness) and structure reflect organic human writing. '
          'Refinements are localized to grammar, spelling, or vocabulary enhancement (e.g. Grammarly). '
          'Original student authorship is preserved.';
    } else if (syntheticScore >= 0.35 && editingScore >= 0.35) {
      classification = AiAuthorshipType.hybridCoCreated;
      explanation =
          'Hybrid authorship: combines original human drafting with substantial AI structural rewriting '
          'and synthetic expansions (${(syntheticScore * 100).round()}% synthetic • ${(editingScore * 100).round()}% polish).';
    } else {
      classification = AiAuthorshipType.humanOriginal;
      explanation =
          'Natural sentence cadence, organic vocabulary, and personal authorial voice indicate '
          'genuine human authorship without artificial generation or automated rewriting.';
    }

    final overallProbability = math.max(syntheticScore, editingScore * 0.5).clamp(0.0, 1.0);

    return AiDetectionResult(
      probability: overallProbability,
      syntheticScore: syntheticScore,
      editingScore: editingScore,
      classification: classification,
      explanation: explanation,
      detectedMarkers: detectedAiMarkers,
      burstinessScore: burstiness,
      vocabularyRichness: vocabularyRichness,
      method: 'Dual-Layer Writing Signal Engine',
    );
  }
}
