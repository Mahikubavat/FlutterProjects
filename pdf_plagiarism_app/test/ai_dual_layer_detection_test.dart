import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/services/ai_detection_service.dart';
import 'package:plagiarism_checker/theme/app_theme.dart';
import 'package:plagiarism_checker/widgets/ai_authorship_dialog.dart';

void main() {
  group('Dual-Layer AI Detection Engine Tests', () {
    final service = AiDetectionService(apiKey: ''); // Offline heuristic mode

    test('Identifies purely synthetic AI-generated content (ChatGPT style)', () async {
      // Monotonous sentence length + hallmark AI clichés ("delve", "multifaceted", "tapestry", "in conclusion")
      const syntheticText =
          'In today’s digital era, artificial intelligence plays a crucial role across modern society. '
          'We must delve into the multifaceted tapestry of technological innovation shaping our world. '
          'Furthermore, the dynamic landscape underscores the importance of ethical governance and responsibility. '
          'Moreover, navigating these complexities requires a comprehensive overview and holistic approach. '
          'In conclusion, it is important to remember that fostering a culture of innovation remains paramount.';

      final result = await service.detect(syntheticText);

      expect(result.classification, equals(AiAuthorshipType.aiGenerated));
      expect(result.syntheticScore, greaterThan(0.50));
      expect(result.detectedMarkers, contains('delve'));
      expect(result.detectedMarkers, contains('multifaceted'));
      expect(result.explanation, contains('generated from scratch'));
    });

    test('Identifies human-drafted text with Grammarly / AI polishing (AI-Edited)', () async {
      // High burstiness (human sentence length variance: short punchy statements alternating with long compound observations)
      // but clean grammar and formal transitions ("additionally", "subsequently", "utilizing")
      const aiEditedText =
          'We tested three bacterial cultures yesterday. '
          'Although previous studies claimed that penicillin would immediately inhibit growth at low concentrations, '
          'our laboratory measurements revealed unexpected resistance patterns across all Petri dishes. '
          'This was surprising. '
          'Additionally, by utilizing spectroscopic absorbance sensors, we subsequently tracked optical density curves '
          'over twenty-four consecutive hours to confirm metabolic stability. '
          'The data clearly demonstrated that culture B was unperturbed.';

      final result = await service.detect(aiEditedText);

      expect(result.classification, equals(AiAuthorshipType.aiEdited));
      expect(result.editingScore, greaterThan(0.40));
      expect(result.syntheticScore, lessThan(0.35));
      expect(result.explanation, contains('Human-authored draft'));
      expect(result.explanation, contains('Grammarly'));
    });

    test('Identifies raw human writing as Human Original', () async {
      const rawHumanText =
          'I woke up late and ran straight to the physics lab. '
          'The pendulum was already swinging when my partner arrived with coffee, which we almost spilled. '
          'Our stopwatches disagreed by half a second every single run! '
          'We tried five times, wrote the numbers down on scrap paper, and calculated the standard deviation by hand.';

      final result = await service.detect(rawHumanText);

      expect(result.classification, equals(AiAuthorshipType.humanOriginal));
      expect(result.syntheticScore, lessThan(0.35));
      expect(result.detectedMarkers.isEmpty, isTrue);
    });

    test('AssignmentDocument getters reflect dual-layer classification accurately', () {
      const editedDoc = AssignmentDocument(
        id: 'doc1',
        fileName: 'essay_edited.pdf',
        rawText: 'Sample text',
        aiSyntheticScore: 0.12,
        aiEditingScore: 0.78,
        aiClassification: 'ai_edited',
      );

      expect(editedDoc.isAiEdited, isTrue);
      expect(editedDoc.isAiGenerated, isFalse);
      expect(editedDoc.isHumanOriginal, isFalse);

      const generatedDoc = AssignmentDocument(
        id: 'doc2',
        fileName: 'essay_chatgpt.pdf',
        rawText: 'Sample text',
        aiSyntheticScore: 0.89,
        aiEditingScore: 0.15,
        aiClassification: 'ai_generated',
      );

      expect(generatedDoc.isAiGenerated, isTrue);
      expect(generatedDoc.isAiEdited, isFalse);
    });

    testWidgets('AiAuthorshipDialog renders without overflow on compact viewports', (tester) async {
      // Simulate compact laptop / tablet height where 15px overflow previously occurred
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testDoc = AssignmentDocument(
        id: 'lab2_st1',
        fileName: 'lab2_st1.pdf',
        rawText: 'Test text',
        cleanedText: 'Test text with multiple words for student assignment',
        aiClassification: 'human',
        aiSyntheticScore: 0.21,
        aiEditingScore: 0.34,
        aiBurstinessScore: 0.70,
        aiVocabularyRichness: 0.99,
        aiDetectedMarkers: ['pivotal role'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => AiAuthorshipDialog.show(ctx, document: testDoc),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check title and elements
      expect(find.text('AI Authorship & Transparency Inspector'), findsOneWidget);
      expect(find.text('Original Human Writing'), findsOneWidget);
      expect(find.text('Layer 1: Synthetic Generation'), findsOneWidget);
      expect(find.text('Layer 2: Grammatical & Tone Polish'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });
  });
}
