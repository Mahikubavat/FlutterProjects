import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import '../models/match_range.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/ui_kit.dart';
import 'document_viewer_screen.dart';

/// Side-by-side view of two compared documents with synchronized scrolling
/// and matching passage navigation.
class DetailScreen extends StatefulWidget {
  final ComparisonResult result;

  const DetailScreen({super.key, required this.result});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ScrollController _scrollControllerA = ScrollController();
  final ScrollController _scrollControllerB = ScrollController();

  bool _syncScrolling = true;
  bool _isProgrammaticScroll = false;
  ScrollController? _activeController;
  int _currentMatchIndex = 0;

  @override
  void dispose() {
    _scrollControllerA.dispose();
    _scrollControllerB.dispose();
    super.dispose();
  }

  bool _onNotificationA(ScrollNotification notification) {
    if (!_syncScrolling || _isProgrammaticScroll) return false;
    if (notification is ScrollStartNotification) {
      _activeController ??= _scrollControllerA;
    } else if (notification is ScrollUpdateNotification) {
      _activeController ??= _scrollControllerA;
      if (_activeController == _scrollControllerA &&
          _scrollControllerA.hasClients &&
          _scrollControllerB.hasClients) {
        final maxA = _scrollControllerA.position.maxScrollExtent;
        final maxB = _scrollControllerB.position.maxScrollExtent;
        if (maxA > 0 && maxB > 0) {
          final progress = (_scrollControllerA.offset / maxA).clamp(0.0, 1.0);
          final targetB = progress * maxB;
          if ((_scrollControllerB.offset - targetB).abs() > 0.5) {
            _isProgrammaticScroll = true;
            _scrollControllerB.jumpTo(targetB);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isProgrammaticScroll = false;
            });
          }
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_activeController == _scrollControllerA) {
        _activeController = null;
      }
    }
    return false;
  }

  bool _onNotificationB(ScrollNotification notification) {
    if (!_syncScrolling || _isProgrammaticScroll) return false;
    if (notification is ScrollStartNotification) {
      _activeController ??= _scrollControllerB;
    } else if (notification is ScrollUpdateNotification) {
      _activeController ??= _scrollControllerB;
      if (_activeController == _scrollControllerB &&
          _scrollControllerA.hasClients &&
          _scrollControllerB.hasClients) {
        final maxA = _scrollControllerA.position.maxScrollExtent;
        final maxB = _scrollControllerB.position.maxScrollExtent;
        if (maxA > 0 && maxB > 0) {
          final progress = (_scrollControllerB.offset / maxB).clamp(0.0, 1.0);
          final targetA = progress * maxA;
          if ((_scrollControllerA.offset - targetA).abs() > 0.5) {
            _isProgrammaticScroll = true;
            _scrollControllerA.jumpTo(targetA);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isProgrammaticScroll = false;
            });
          }
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_activeController == _scrollControllerB) {
        _activeController = null;
      }
    }
    return false;
  }

  void _jumpToMatch(int index, int totalMatches, String textA, String textB) {
    if (totalMatches == 0) return;
    final targetIndex = (index + totalMatches) % totalMatches;
    setState(() => _currentMatchIndex = targetIndex);

    final rangesA = widget.result.matchedRangesA;
    final rangesB = widget.result.matchedRangesB;

    _isProgrammaticScroll = true;
    _activeController = null;

    if (targetIndex < rangesA.length && _scrollControllerA.hasClients && textA.isNotEmpty) {
      final range = rangesA[targetIndex];
      final ratio = (range.start / textA.length).clamp(0.0, 1.0);
      final maxA = _scrollControllerA.position.maxScrollExtent;
      _scrollControllerA.animateTo(
        ratio * maxA,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    if (targetIndex < rangesB.length && _scrollControllerB.hasClients && textB.isNotEmpty) {
      final range = rangesB[targetIndex];
      final ratio = (range.start / textB.length).clamp(0.0, 1.0);
      final maxB = _scrollControllerB.position.maxScrollExtent;
      _scrollControllerB.animateTo(
        ratio * maxB,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _isProgrammaticScroll = false;
    });
  }

  void _showReuploadDialog(
    BuildContext context,
    AppState appState,
    AssignmentDocument docA,
    AssignmentDocument docB,
  ) {
    String selectedStudent = docA.ownerId ?? docA.id;
    String selectedDocName = docA.fileName;
    final reasonController = TextEditingController(
      text:
          'High similarity of ${(widget.result.overallScore * 100).toStringAsFixed(1)}% detected with peer submission. Please re-examine your submission and upload your original work.',
    );
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.review.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notification_important_outlined,
                  color: AppColors.review,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Request Re-upload',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notify student to re-examine their submission and upload their original work:',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedStudent,
                  decoration: InputDecoration(
                    labelText: 'Target Student',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: docA.ownerId ?? docA.id,
                      child: Text(
                        'Student A: ${docA.fileName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DropdownMenuItem(
                      value: docB.ownerId ?? docB.id,
                      child: Text(
                        'Student B: ${docB.fileName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedStudent = val;
                        selectedDocName = val == (docA.ownerId ?? docA.id)
                            ? docA.fileName
                            : docB.fileName;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  decoration: InputDecoration(
                    labelText: 'Instructions / Reason for Re-upload',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isSending ? 'Sending...' : 'Send Notice',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: isSending
                        ? null
                        : () async {
                            setDialogState(() => isSending = true);
                            try {
                              await appState.sendReuploadRequest(
                                studentId: selectedStudent,
                                studentName: selectedDocName,
                                documentId: selectedStudent,
                                documentName: selectedDocName,
                                reason: reasonController.text,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Re-upload notification sent to student for "$selectedDocName".'),
                                    backgroundColor: AppColors.ink,
                                  ),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setDialogState(() => isSending = false);
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final docA = appState.documentById(widget.result.docAId) ??
        AssignmentDocument(
          id: widget.result.docAId,
          fileName: widget.result.docAName,
          rawText:
              'Document content for "${widget.result.docAName}" is not stored locally.\n\n'
              'Similarity with peer: ${(widget.result.overallScore * 100).toStringAsFixed(1)}%\n'
              'Shingle phrase match: ${(widget.result.shingleSimilarity * 100).toStringAsFixed(1)}%\n'
              'Cosine topical similarity: ${(widget.result.cosineSimilarity * 100).toStringAsFixed(1)}%\n\n'
              'Use the "Request Re-upload" button in the top bar to notify this student.',
        );
    final docB = appState.documentById(widget.result.docBId) ??
        AssignmentDocument(
          id: widget.result.docBId,
          fileName: widget.result.docBName,
          rawText:
              'Document content for "${widget.result.docBName}" is not stored locally.\n\n'
              'Similarity with peer: ${(widget.result.overallScore * 100).toStringAsFixed(1)}%\n'
              'Shingle phrase match: ${(widget.result.shingleSimilarity * 100).toStringAsFixed(1)}%\n'
              'Cosine topical similarity: ${(widget.result.cosineSimilarity * 100).toStringAsFixed(1)}%\n\n'
              'Use the "Request Re-upload" button in the top bar to notify this student.',
        );

    final totalMatches = math.max(
      widget.result.matchedRangesA.length,
      widget.result.matchedRangesB.length,
    );

    final isNarrowScreen = MediaQuery.sizeOf(context).width < 520;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        title: Text(
          isNarrowScreen ? 'Comparison' : 'Comparison Details',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
            color: AppColors.text,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (appState.isAdmin)
            isNarrowScreen
                ? IconButton(
                    tooltip: 'Request Re-upload',
                    icon: const Icon(Icons.outgoing_mail, color: AppColors.brand, size: 22),
                    onPressed: () => _showReuploadDialog(context, appState, docA, docB),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.outgoing_mail, size: 16),
                      label: const Text('Request Re-upload'),
                      onPressed: () => _showReuploadDialog(context, appState, docA, docB),
                    ),
                  ),
          Tooltip(
            message: _syncScrolling ? 'Sync scrolling enabled' : 'Sync scrolling disabled',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNarrowScreen) ...[
                  Icon(
                    _syncScrolling ? Icons.sync : Icons.sync_disabled,
                    size: 18,
                    color: _syncScrolling ? AppColors.ink : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Sync scroll',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: _syncScrolling,
                    onChanged: (val) => setState(() => _syncScrolling = val),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
      ),
      body: PageFrame(
        maxWidth: 1400,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 800;

            final navBar = _MatchNavigationBar(
              currentIndex: _currentMatchIndex,
              totalMatches: totalMatches,
              onPrevious: () => _jumpToMatch(
                _currentMatchIndex - 1,
                totalMatches,
                docA.cleanedText,
                docB.cleanedText,
              ),
              onNext: () => _jumpToMatch(
                _currentMatchIndex + 1,
                totalMatches,
                docA.cleanedText,
                docB.cleanedText,
              ),
            );

            final panelA = _DocumentPanel(
              document: docA,
              ranges: widget.result.matchedRangesA,
              controller: _scrollControllerA,
              onNotification: _onNotificationA,
            );
            final panelB = _DocumentPanel(
              document: docB,
              ranges: widget.result.matchedRangesB,
              controller: _scrollControllerB,
              onNotification: _onNotificationB,
            );
            final header = _SummaryCard(result: widget.result);

            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 10),
                    navBar,
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: panelA),
                          const SizedBox(width: 12),
                          Expanded(child: panelB),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                header,
                const SizedBox(height: 10),
                navBar,
                const SizedBox(height: 10),
                SizedBox(height: 380, child: panelA),
                const SizedBox(height: 12),
                SizedBox(height: 380, child: panelB),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalMatches;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MatchNavigationBar({
    required this.currentIndex,
    required this.totalMatches,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final matchBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.match.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            totalMatches == 0
                ? 'No shared matches'
                : 'Match ${currentIndex + 1} of $totalMatches',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );

    final prevButton = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.arrow_upward_rounded, size: 15),
      label: const Text('Prev', style: TextStyle(fontSize: 11.5)),
      onPressed: totalMatches > 0 ? onPrevious : null,
    );

    final nextButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.arrow_downward_rounded, size: 15),
      label: const Text('Next', style: TextStyle(fontSize: 11.5)),
      onPressed: totalMatches > 0 ? onNext : null,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 580;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    matchBadge,
                    const Spacer(),
                    prevButton,
                    const SizedBox(width: 6),
                    nextButton,
                  ],
                ),
                if (totalMatches > 0) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Showing synchronized passage across both documents',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              matchBadge,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  totalMatches == 0
                      ? 'Documents show no common passages.'
                      : 'Showing synchronized passage across both documents',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              prevButton,
              const SizedBox(width: 8),
              nextButton,
            ],
          );
        },
      ),
    );
  }
}

/// Score, risk level, and metrics.
class _SummaryCard extends StatelessWidget {
  final ComparisonResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final risk = Risk.of(result);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(score: result.overallScore, color: risk.color, size: 68),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${risk.label}: ${(result.overallScore * 100).round()}% similar',
                      style: TextStyle(
                        color: risk.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    StatPill(
                      label: '${result.matchedRangesA.length} shared matching passages',
                      color: risk.color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MetricRow(result: result),
                const SizedBox(height: 8),
                const Text(
                  'Highlighted sections indicate matching text passages, table rows, and numerical data found in both documents.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPanel extends StatelessWidget {
  final AssignmentDocument document;
  final List<MatchRange> ranges;
  final ScrollController controller;
  final NotificationListenerCallback<ScrollNotification>? onNotification;

  const _DocumentPanel({
    required this.document,
    required this.ranges,
    required this.controller,
    this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    final text = document.cleanedText;
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.brand.withValues(alpha: 0.04),
            child: Row(
              children: [
                Icon(
                  document.fileName.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      '$words words • ${ranges.length} matches',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.brand),
                  tooltip: 'View Document / Original PDF',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentViewerScreen(document: document),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: onNotification,
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: HighlightedText(text: text, ranges: ranges),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
