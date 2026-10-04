import 'document_page.dart';

/// A single uploaded (or sample) assignment: raw extracted text plus
/// enough metadata to identify it in the UI and reports.
class AssignmentDocument {
  final String id;
  final String? ownerId;
  final String? ownerName;
  final String fileName;
  final String? originalFilePath;
  final String? originalFileBase64;
  final String rawText;
  final String cleanedText;
  final List<DocumentPage> pages;
  final double? aiProbability;
  final String? aiDetectionMethod;
  final double? aiSyntheticScore;
  final double? aiEditingScore;
  final String? aiClassification;
  final String? aiExplanation;
  final List<String> aiDetectedMarkers;
  final double? aiBurstinessScore;
  final double? aiVocabularyRichness;

  const AssignmentDocument({
    required this.id,
    this.ownerId,
    this.ownerName,
    required this.fileName,
    this.originalFilePath,
    this.originalFileBase64,
    required this.rawText,
    String? cleanedText,
    List<DocumentPage>? pages,
    this.aiProbability,
    this.aiDetectionMethod,
    this.aiSyntheticScore,
    this.aiEditingScore,
    this.aiClassification,
    this.aiExplanation,
    List<String>? aiDetectedMarkers,
    this.aiBurstinessScore,
    this.aiVocabularyRichness,
  })  : cleanedText = cleanedText ?? rawText,
        pages = pages ?? const [],
        aiDetectedMarkers = aiDetectedMarkers ?? const [];

  int get wordCount => cleanedText.trim().isEmpty
      ? 0
      : cleanedText.trim().split(RegExp(r'\s+')).length;

  bool get isAiEdited => aiClassification == 'ai_edited';
  bool get isAiGenerated => aiClassification == 'ai_generated';
  bool get isHumanOriginal => aiClassification == 'human';
  bool get isHybridAi => aiClassification == 'hybrid';
}
