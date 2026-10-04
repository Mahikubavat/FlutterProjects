import 'package:flutter/material.dart';
import '../models/assignment_document.dart';
import '../services/ai_detection_service.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// Interactive modal dialog displaying dual-layer classification of AI authorship,
/// clearly separating synthetic generation from grammatical/tone assistance.
class AiAuthorshipDialog extends StatelessWidget {
  final AssignmentDocument document;
  final VoidCallback? onRerunCheck;

  const AiAuthorshipDialog({
    super.key,
    required this.document,
    this.onRerunCheck,
  });

  static void show(
    BuildContext context, {
    required AssignmentDocument document,
    VoidCallback? onRerunCheck,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AiAuthorshipDialog(
        document: document,
        onRerunCheck: onRerunCheck,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close inspector',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verdict Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeColor.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusBadge.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            document.aiExplanation ??
                                'Dual-layer analysis distinguishes between complete synthetic text generation and grammatical polish tools.',
                            style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dual-Layer Comparison Row
                    const Text(
                      'Dual-Layer Classification Breakdown',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 500;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildLayerCard(
                                title: 'Layer 1: Synthetic Generation',
                                score: syntheticScore,
                                accentColor: syntheticScore >= 0.5 ? AppColors.high : AppColors.low,
                                icon: Icons.smart_toy_outlined,
                                subtitle: 'Content created from scratch by AI (ChatGPT/Claude)',
                                badgeText: syntheticScore >= 0.5 ? 'High Generation' : 'Minimal Generation',
                              ),
                              const SizedBox(height: 10),
                              _buildLayerCard(
                                title: 'Layer 2: Grammatical & Tone Polish',
                                score: editingScore,
                                accentColor: const Color(0xFF0284C7),
                                icon: Icons.spellcheck_rounded,
                                subtitle: 'Grammar, spellcheck & tone assistance (Grammarly)',
                                badgeText: editingScore >= 0.4 ? 'Polished Human Draft' : 'Raw / Unassisted',
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildLayerCard(
                                title: 'Layer 1: Synthetic Generation',
                                score: syntheticScore,
                                accentColor: syntheticScore >= 0.5 ? AppColors.high : AppColors.low,
                                icon: Icons.smart_toy_outlined,
                                subtitle: 'Content created from scratch by AI (ChatGPT/Claude)',
                                badgeText: syntheticScore >= 0.5 ? 'High Generation' : 'Minimal Generation',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildLayerCard(
                                title: 'Layer 2: Grammatical & Tone Polish',
                                score: editingScore,
                                accentColor: const Color(0xFF0284C7),
                                icon: Icons.spellcheck_rounded,
                                subtitle: 'Grammar, spellcheck & tone assistance (Grammarly)',
                                badgeText: editingScore >= 0.4 ? 'Polished Human Draft' : 'Raw / Unassisted',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Forensic Linguistic Signals
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Forensic Stylometric Signals',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 500;
                              if (isNarrow) {
                                return Column(
                                  children: [
                                    _buildMetricBar(
                                      label: 'Sentence Rhythm (Burstiness)',
                                      value: burstiness,
                                      valueLabel: burstiness >= 0.55 ? 'Organic (Human)' : 'Uniform (AI)',
                                      color: burstiness >= 0.55 ? AppColors.low : AppColors.high,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricBar(
                                      label: 'Vocabulary Diversity',
                                      value: vocabulary,
                                      valueLabel: '${(vocabulary * 100).round()}% Diversity',
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricBar(
                                      label: 'Sentence Rhythm (Burstiness)',
                                      value: burstiness,
                                      valueLabel: burstiness >= 0.55 ? 'Organic (Human)' : 'Uniform (AI)',
                                      color: burstiness >= 0.55 ? AppColors.low : AppColors.high,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMetricBar(
                                      label: 'Vocabulary Diversity',
                                      value: vocabulary,
                                      valueLabel: '${(vocabulary * 100).round()}% Diversity',
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (markers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Detected AI Formulaic Transitions:',
                              style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
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
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.high),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onRerunCheck != null) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Rerun Screening'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRerunCheck!();
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
            Text(
              valueLabel,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
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
