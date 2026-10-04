import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/assignment_document.dart';
import '../services/ai_detection_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Interactive modal dialog displaying dual-layer classification of AI authorship,
/// clearly separating synthetic generation from grammatical/tone assistance.
class AiAuthorshipDialog extends StatefulWidget {
  final AssignmentDocument document;
  final VoidCallback? onRerunCheck;

  const AiAuthorshipDialog({
    super.key,
    required this.document,
    this.onRerunCheck,
  });

  static Future<void> show(
    BuildContext context, {
    required AssignmentDocument document,
    VoidCallback? onRerunCheck,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AiAuthorshipDialog(
        document: document,
        onRerunCheck: onRerunCheck,
      ),
    );
  }

  @override
  State<AiAuthorshipDialog> createState() => _AiAuthorshipDialogState();
}

class _AiAuthorshipDialogState extends State<AiAuthorshipDialog> {
  late AssignmentDocument _currentDoc;
  bool _isScreening = false;
  String? _screeningMessage;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.document;
    final isUnscreened = _currentDoc.aiClassification == null && _currentDoc.aiProbability == null;
    if (isUnscreened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performScreening();
      });
    }
  }

  Future<void> _performScreening() async {
    if (_isScreening) return;
    setState(() {
      _isScreening = true;
      _screeningMessage = 'Evaluating dual-layer writing markers & burstiness…';
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final updated = await appState.runAiCheck(_currentDoc.id);
      if (mounted) {
        setState(() {
          if (updated != null) {
            _currentDoc = updated;
          } else {
            final docInState = appState.documentById(_currentDoc.id);
            if (docInState != null) _currentDoc = docInState;
          }
          _isScreening = false;
        });
      }
    } catch (_) {
      // Fallback if AppState is unavailable (e.g. standalone test or direct invocation)
      try {
        final text = _currentDoc.cleanedText.isNotEmpty ? _currentDoc.cleanedText : _currentDoc.rawText;
        final service = AiDetectionService(apiKey: '');
        final res = await service.detect(text);
        if (mounted) {
          setState(() {
            _currentDoc = AssignmentDocument(
              id: _currentDoc.id,
              ownerId: _currentDoc.ownerId,
              ownerName: _currentDoc.ownerName,
              fileName: _currentDoc.fileName,
              originalFilePath: _currentDoc.originalFilePath,
              originalFileBase64: _currentDoc.originalFileBase64,
              rawText: _currentDoc.rawText,
              cleanedText: _currentDoc.cleanedText,
              pages: _currentDoc.pages,
              aiProbability: res.probability,
              aiDetectionMethod: res.method,
              aiSyntheticScore: res.syntheticScore,
              aiEditingScore: res.editingScore,
              aiClassification: res.classification.id,
              aiExplanation: res.explanation,
              aiDetectedMarkers: res.detectedMarkers,
              aiBurstinessScore: res.burstinessScore,
              aiVocabularyRichness: res.vocabularyRichness,
            );
            _isScreening = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isScreening = false;
          });
        }
      }
    }

    if (widget.onRerunCheck != null) {
      widget.onRerunCheck!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _currentDoc;
    final isUnscreened = document.aiClassification == null && document.aiProbability == null;
    final classification = AiAuthorshipType.fromId(document.aiClassification);
    final syntheticScore = document.aiSyntheticScore ??
        (document.aiProbability != null ? (document.aiProbability! > 0.6 ? document.aiProbability! : 0.2) : 0.0);
    final editingScore = document.aiEditingScore ??
        (document.aiProbability != null ? (document.aiProbability! <= 0.6 ? document.aiProbability! : 0.3) : 0.0);
    final burstiness = document.aiBurstinessScore ?? 0.55;
    final vocabulary = document.aiVocabularyRichness ?? 0.65;
    final markers = document.aiDetectedMarkers;

    Color themeColor;
    IconData statusIcon;
    String statusTitle;
    String statusBadge;

    switch (classification) {
      case AiAuthorshipType.aiEdited:
        themeColor = const Color(0xFF0284C7); // Sky / Blue
        statusIcon = Icons.edit_note_rounded;
        statusTitle = 'AI-Assisted / Grammatical Polish';
        statusBadge = 'Human Author Preserved';
        break;
      case AiAuthorshipType.aiGenerated:
        themeColor = AppColors.high; // Red
        statusIcon = Icons.smart_toy_outlined;
        statusTitle = 'Synthetic AI Generation';
        statusBadge = 'High AI Authorship';
        break;
      case AiAuthorshipType.hybridCoCreated:
        themeColor = AppColors.review; // Amber
        statusIcon = Icons.auto_awesome_motion_outlined;
        statusTitle = 'Hybrid AI Co-Creation';
        statusBadge = 'Substantial AI Revision';
        break;
      case AiAuthorshipType.humanOriginal:
        themeColor = AppColors.low; // Emerald green
        statusIcon = Icons.person_outline_rounded;
        statusTitle = 'Original Human Writing';
        statusBadge = 'Natural Human Voice';
        break;
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenHeight * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: themeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Authorship & Transparency Inspector',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${document.fileName} • ${document.wordCount} words • ${document.aiDetectionMethod ?? 'Dual-Layer Writing Signal Engine'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (_isScreening)
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppColors.paper,
                color: AppColors.brand,
              )
            else
              const Divider(height: 1, color: AppColors.line),

            // Scrollable Content
            Flexible(
              child: _isScreening && isUnscreened
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.mint.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Screening Authorship Signals…',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 380),
                              child: Text(
                                _screeningMessage ??
                                    'Evaluating lexical variance, burstiness, and dual-layer signals to distinguish synthetic generation from grammatical polish...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Overall Status Banner
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: themeColor.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(statusIcon, color: themeColor, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            statusTitle,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: themeColor,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: themeColor,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusBadge,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  document.aiExplanation ??
                                      'Dual-layer analysis evaluates whether this text was drafted by synthetic AI models or human-written with digital grammar polish.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.text,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Dual-Layer Cards: Synthetic Generation vs Grammatical Polish
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;
                              final cardA = _buildLayerCard(
                                title: 'Layer 1: Synthetic Generation',
                                score: syntheticScore,
                                accentColor: AppColors.high,
                                icon: Icons.smart_toy_outlined,
                                subtitle: 'Ideas and paragraphs authored from scratch by LLM.',
                                badgeText: syntheticScore > 0.4 ? 'High Synthetic' : 'Original Text',
                              );
                              final cardB = _buildLayerCard(
                                title: 'Layer 2: Grammatical & Tone Polish',
                                score: editingScore,
                                accentColor: const Color(0xFF0284C7),
                                icon: Icons.spellcheck_rounded,
                                subtitle: 'Spelling, phrasing, and vocabulary enhancements (e.g. Grammarly).',
                                badgeText: editingScore > 0.4 ? 'Polished' : 'Unassisted',
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    cardA,
                                    const SizedBox(height: 12),
                                    cardB,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cardA),
                                  const SizedBox(width: 14),
                                  Expanded(child: cardB),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // Statistical Linguistics Breakdown
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Linguistic & Stylistic Metrics',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMetricBar(
                                  label: 'Burstiness & Cadence Variance',
                                  value: burstiness,
                                  valueLabel: '${(burstiness * 100).round()}% (${burstiness > 0.6 ? 'Natural Rhythm' : 'Uniform / AI Machine'})',
                                  color: burstiness > 0.6 ? AppColors.low : AppColors.review,
                                ),
                                const SizedBox(height: 10),
                                _buildMetricBar(
                                  label: 'Lexical Diversity (Type-Token Ratio)',
                                  value: vocabulary,
                                  valueLabel: '${(vocabulary * 100).round()}% (${vocabulary > 0.6 ? 'Rich Vocabulary' : 'Constrained'})',
                                  color: AppColors.brand,
                                ),
                                if (markers.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Detected Formulaic AI Transitions & Clichés:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: markers.map((m) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.high.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.high.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '"$m"',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.high,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            const Divider(height: 1, color: AppColors.line),

            // Fixed Footer Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _isScreening
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_isScreening ? 'Screening…' : 'Rerun Screening'),
                    onPressed: _isScreening ? null : _performScreening,
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerCard({
    required String title,
    required double score,
    required Color accentColor,
    required IconData icon,
    required String subtitle,
    required String badgeText,
  }) {
    final pct = (score * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score,
            backgroundColor: AppColors.line,
            color: accentColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar({
    required String label,
    required double value,
    required String valueLabel,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                valueLabel,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: AppColors.line,
          color: color,
          minHeight: 5,
          borderRadius: BorderRadius.circular(2.5),
        ),
      ],
    );
  }
}
