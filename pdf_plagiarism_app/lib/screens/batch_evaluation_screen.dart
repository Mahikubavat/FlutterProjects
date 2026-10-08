import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../models/assignment_document.dart';
import '../models/batch_report_model.dart';
import '../models/comparison_result.dart';
import '../services/batch_api_service.dart';
import '../services/batch_repository.dart';
import '../services/similarity_service.dart';
import '../state/app_state.dart';
import '../state/batch_cubit.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'detail_screen.dart';
import 'main_navigation_shell.dart';

/// Screen allowing professors to run and view aggregated batch plagiarism evaluations.
class BatchEvaluationScreen extends StatefulWidget {
  final List<String>? initialUserIds;
  final String? initialAssignmentTag;

  const BatchEvaluationScreen({
    super.key,
    this.initialUserIds,
    this.initialAssignmentTag,
  });

  @override
  State<BatchEvaluationScreen> createState() => _BatchEvaluationScreenState();
}

class _BatchEvaluationScreenState extends State<BatchEvaluationScreen> {
  late final BatchCubit _cubit;
  final TextEditingController _tagController =
      TextEditingController(text: 'lab1');
  final Set<String> _selectedStudentIds = {};
  double _similarityThreshold = 0.25; // 25% default filter
  String _searchQuery = '';
  final Map<String, ComparisonResult> _cachedComparisonMap = {};

  @override
  void initState() {
    super.initState();
    final apiService = BatchApiService();
    final repository = BatchRepositoryImpl(apiService: apiService);
    _cubit = BatchCubit(repository: repository);

    if (widget.initialAssignmentTag != null &&
        widget.initialAssignmentTag!.isNotEmpty) {
      _tagController.text = widget.initialAssignmentTag!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      final studentIds = appState.documents
          .map((d) => d.ownerId ?? d.id)
          .where((id) => id.isNotEmpty)
          .toSet();

      setState(() {
        if (widget.initialUserIds != null && widget.initialUserIds!.isNotEmpty) {
          _selectedStudentIds.addAll(widget.initialUserIds!);
        } else if (studentIds.isNotEmpty) {
          _selectedStudentIds.addAll(studentIds);
        } else {
          _selectedStudentIds.addAll(['student1', 'student2']);
        }
      });
    });
  }

  @override
  void dispose() {
    _cubit.close();
    _tagController.dispose();
    super.dispose();
  }

  /// Determines whether a document matches an assignment tag/convention (e.g. "lab1" matches "lab1_st1.pdf").
  bool _matchesTag(String fileName, String tag) {
    final cleanTag = tag.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanTag.isEmpty || cleanTag == 'all' || cleanTag == 'any' || cleanTag == '*') {
      return true;
    }
    final cleanName = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleanName.contains(cleanTag);
  }

  /// Checks if a document matches the tag by filename, id, or student/owner name.
  bool _matchesDoc(AssignmentDocument doc, String tag) {
    final cleanTag = tag.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanTag.isEmpty || cleanTag == 'all' || cleanTag == 'any' || cleanTag == '*') {
      return true;
    }
    if (_matchesTag(doc.fileName, tag)) return true;
    if (_matchesTag(doc.id, tag)) return true;
    if (doc.ownerName != null && _matchesTag(doc.ownerName!, tag)) return true;
    if (doc.ownerId != null && _matchesTag(doc.ownerId!, tag)) return true;
    return false;
  }


  /// Executes batch evaluation across local documents matching the tag and selected students.
  Future<void> _runLocalBatchEvaluation(AppState appState) async {
    final tag = _tagController.text.trim();
    final allDocs = appState.documents;

    // Find documents matching the tag and selected students
    final matchingDocs = allDocs.where((doc) {
      final matchesTag = _matchesDoc(doc, tag);
      final isSelected = _selectedStudentIds.isEmpty ||
          _selectedStudentIds.contains(doc.ownerId ?? doc.id);
      return matchesTag && isSelected;
    }).toList();

    if (matchingDocs.length < 2) {
      // Check if there are matching docs without the student filter
      final anyMatching = allDocs.where((doc) => _matchesDoc(doc, tag)).toList();
      if (anyMatching.length >= 2) {
        // Auto-select their student IDs
        setState(() {
          for (final doc in anyMatching) {
            _selectedStudentIds.add(doc.ownerId ?? doc.id);
          }
        });
        return _runLocalBatchEvaluation(appState);
      }

      // Check if all available documents could be evaluated
      if (allDocs.length >= 2 && tag.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${matchingDocs.length} submission matching "$tag". '
              'Clear or change the tag, or ensure at least 2 files (e.g. lab1_st1.pdf, lab1_st2.pdf) are uploaded.',
            ),
            backgroundColor: AppColors.review,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Evaluate All Files',
              textColor: Colors.white,
              onPressed: () {
                _tagController.text = '';
                setState(() {});
                _runLocalBatchEvaluation(appState);
              },
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found ${matchingDocs.length} document matching "$tag". '
            'Please upload at least 2 submissions matching "$tag" (e.g. lab1_st1.pdf and lab1_st2.pdf).',
          ),
          backgroundColor: AppColors.review,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Set loading directly on the Cubit for local offline execution (never call remote REST endpoint here)
    _cubit.setLoading(0.15);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // Compute pairwise comparisons locally using the forensic similarity engine
    _cachedComparisonMap.clear();
    final comparisons = <ComparisonResult>[];
    final totalPairs = (matchingDocs.length * (matchingDocs.length - 1)) ~/ 2;
    int processedPairs = 0;

    for (int i = 0; i < matchingDocs.length; i++) {
      for (int j = i + 1; j < matchingDocs.length; j++) {
        final docA = matchingDocs[i];
        final docB = matchingDocs[j];

        final res = SimilarityService.compare(docA, docB);
        comparisons.add(res);

        processedPairs++;
        if (totalPairs > 0) {
          _cubit.setLoading(0.2 + (0.6 * (processedPairs / totalPairs)));
        }
      }
    }

    // Save results into app state and notify all listeners
    if (comparisons.isNotEmpty) {
      await appState.setResults(comparisons, DateTime.now());
    }

    // Group matching docs by unique student
    final studentMap = <String, List<AssignmentDocument>>{};
    for (final doc in matchingDocs) {
      final studentId = doc.ownerId ?? doc.id;
      studentMap.putIfAbsent(studentId, () => []).add(doc);
    }

    // Build aggregated student reports: each student's max similarity score & top suspect peer
    final reports = <StudentReport>[];

    for (final entry in studentMap.entries) {
      final studentId = entry.key;
      final studentDocs = entry.value;
      final studentDisplayName = studentDocs.first.ownerName ?? studentDocs.first.fileName;

      ComparisonResult? bestMatch;
      AssignmentDocument? topPeerDoc;

      for (final doc in studentDocs) {
        for (final comp in comparisons) {
          final isA = (comp.docAId == doc.id || comp.docAName == doc.fileName);
          final isB = (comp.docBId == doc.id || comp.docBName == doc.fileName);
          if (!isA && !isB) continue;

          final peerDocId = isA ? comp.docBId : comp.docAId;
          final peerDocName = isA ? comp.docBName : comp.docAName;

          final peerDoc = matchingDocs.firstWhere(
            (d) => d.id == peerDocId || d.fileName == peerDocName,
            orElse: () => allDocs.firstWhere(
              (d) => d.id == peerDocId || d.fileName == peerDocName,
              orElse: () => doc,
            ),
          );

          final peerOwnerId = peerDoc.ownerId ?? peerDoc.id;
          if (peerOwnerId == studentId && studentMap.length > 1) {
            // Ignore comparisons between the same student's files if multiple students exist
            continue;
          }

          if (bestMatch == null || comp.overallScore > bestMatch.overallScore) {
            bestMatch = comp;
            topPeerDoc = peerDoc;
          }
        }
      }

      final maxScore = bestMatch?.overallScore ?? 0.0;
      final topPeerName = topPeerDoc != null
          ? (topPeerDoc.ownerName ?? topPeerDoc.fileName)
          : 'None';

      if (bestMatch != null) {
        _cachedComparisonMap[studentId] = bestMatch;
        _cachedComparisonMap[studentDisplayName] = bestMatch;
        for (final doc in studentDocs) {
          _cachedComparisonMap[doc.fileName] = bestMatch;
          _cachedComparisonMap[doc.id] = bestMatch;
        }
      }

      reports.add(StudentReport(
        studentId: studentId,
        studentName: studentDisplayName,
        maxScore: maxScore,
        topPeerName: topPeerName,
        flagged: maxScore >= 0.40,
      ));
    }

    // Sort descending by highest similarity score
    reports.sort((a, b) => b.maxScore.compareTo(a.maxScore));

    final reportModel = BatchReportModel(
      batchJobId: 'batch_local_${DateTime.now().millisecondsSinceEpoch}',
      status: 'COMPLETED',
      progress: 1.0,
      reports: reports,
    );

    _cubit.setSuccessReport(reportModel);
  }

  /// Triggers a re-upload request notification to a specific student
  void _openReuploadDialog({
    required BuildContext context,
    required AppState appState,
    required String studentId,
    required String studentName,
    required String assignmentTag,
  }) {
    final reasonController = TextEditingController(
      text: 'High similarity detected for $assignmentTag. Please review your work and re-upload your revised lab assignment.',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Request Re-upload',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      'Target: $studentName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A notification will be sent to $studentName requesting a revised submission for "$assignmentTag":',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  decoration: InputDecoration(
                    labelText: 'Reason / Instructions',
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
                                studentId: studentId,
                                studentName: studentName,
                                documentId: studentId,
                                documentName: assignmentTag,
                                assignmentTag: assignmentTag,
                                reason: reasonController.text,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Re-upload notification successfully sent to $studentName.'),
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
    final appState = context.watch<AppState>();

    // Strict access control: batch evaluation is an instructor-only capability
    if (!appState.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          title: const Text('Batch Plagiarism Evaluation'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppCard(
                padding: const EdgeInsets.all(32),
                borderRadius: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 44,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Instructor Access Only',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Batch processing, cohort-wide comparison, and student cross-evaluation are reserved for instructors and administrators.\n\nStudents can upload assignments and inspect their own verified authorship from the submissions dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Return to My Submissions'),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          MainNavigationShell.switchTab(context, 0);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Batch Plagiarism Evaluation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Batch View',
            onPressed: () => _cubit.cancelEvaluation(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ValueListenableBuilder<BatchState>(
            valueListenable: _cubit,
            builder: (context, state, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _buildReuploadAlertBanner(appState),
                  _buildSetupCard(appState, state),
                  const SizedBox(height: 24),
                  switch (state) {
                    BatchInitial() => _buildInitialInfoCard(appState),
                    BatchLoading(:final progress) => _buildLoadingCard(progress),
                    BatchError(:final message) => _buildErrorCard(message, appState),
                    BatchSuccess(:final report) => _buildReportDashboard(report, appState),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReuploadAlertBanner(AppState appState) {
    final reuploadedAlerts = appState.notifications
        .where((n) => !n.isRead && n.type == NotificationType.reuploadCompleted)
        .toList();

    if (reuploadedAlerts.isEmpty) return const SizedBox.shrink();

    final alert = reuploadedAlerts.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppColors.low.withValues(alpha: 0.4),
        color: AppColors.low.withValues(alpha: 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.low, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.low),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => appState.markNotificationAsRead(alert.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.low),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Re-evaluate Batch Now'),
                    onPressed: () {
                      appState.markNotificationAsRead(alert.id);
                      if (alert.assignmentTag != null && alert.assignmentTag!.isNotEmpty) {
                        _tagController.text = alert.assignmentTag!;
                      }
                      _runLocalBatchEvaluation(appState);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard(AppState appState, BatchState state) {
    final isRunning = state is BatchLoading;
    final availableDocs = appState.documents;
    final currentTag = _tagController.text.trim();

    // Group available documents by unique student
    final studentMap = <String, List<AssignmentDocument>>{};
    for (final doc in availableDocs) {
      final studentId = doc.ownerId ?? doc.id;
      studentMap.putIfAbsent(studentId, () => []).add(doc);
    }

    final matchingDocsCount = availableDocs
        .where((d) => _matchesDoc(d, currentTag))
        .length;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_outlined, color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Processing Configuration',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enter an assignment tag (e.g. lab1) to match student submissions like lab1_st1.pdf and lab1_st2.pdf.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final tagField = SizedBox(
                height: 48,
                child: TextField(
                  controller: _tagController,
                  enabled: !isRunning,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Assignment Tag / Convention',
                    hintText: 'e.g. lab1',
                    prefixIcon: Icon(Icons.bookmark_outline, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              );

              final countBadge = Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 18, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedStudentIds.length} Students Selected',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tagField,
                    const SizedBox(height: 10),
                    countBadge,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: tagField),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: countBadge),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            matchingDocsCount > 0
                ? 'Found $matchingDocsCount document(s) matching "$currentTag"'
                : (availableDocs.isNotEmpty
                    ? 'No files matching "$currentTag" (leave empty or click "Clear" to match all)'
                    : 'No documents uploaded yet'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (studentMap.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Students to Include in Batch:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: isRunning
                      ? null
                      : () {
                          setState(() {
                            _selectedStudentIds.addAll(studentMap.keys);
                          });
                        },
                  child: const Text('Select All', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: isRunning
                      ? null
                      : () {
                          setState(() {
                            _selectedStudentIds.clear();
                          });
                        },
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: studentMap.entries.map((entry) {
                final studentId = entry.key;
                final docs = entry.value;
                final studentName = docs.first.ownerName ?? docs.first.fileName;
                final isSelected = _selectedStudentIds.contains(studentId);
                final hasMatch = docs.any((d) => _matchesDoc(d, currentTag));

                return FilterChip(
                  avatar: hasMatch
                      ? const Icon(Icons.check_circle, size: 14, color: AppColors.brand)
                      : null,
                  label: Text(
                    docs.length > 1 ? '$studentName (${docs.length} files)' : studentName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasMatch ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isRunning
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStudentIds.add(studentId);
                            } else {
                              _selectedStudentIds.remove(studentId);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  isRunning ? 'Processing Batch…' : 'Start Batch Evaluation',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: isRunning ? null : () => _runLocalBatchEvaluation(appState),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Simulate Demo Batch'),
                onPressed: isRunning
                    ? null
                    : () {
                        // Pre-populate demo comparison map to ensure Inspect NEVER fails
                        const demoResultA = ComparisonResult(
                          docAId: 'student1',
                          docBId: 'student2',
                          docAName: 'lab1_st1.pdf (Student 1)',
                          docBName: 'lab1_st2.pdf (Student 2)',
                          shingleSimilarity: 0.88,
                          cosineSimilarity: 0.75,
                          overallScore: 0.842,
                          matchedRangesA: [],
                          matchedRangesB: [],
                        );

                        const demoResultB = ComparisonResult(
                          docAId: 'student3',
                          docBId: 'student4',
                          docAName: 'lab1_st3.pdf (Student 3)',
                          docBName: 'lab1_st4.pdf (Student 4)',
                          shingleSimilarity: 0.52,
                          cosineSimilarity: 0.40,
                          overallScore: 0.485,
                          matchedRangesA: [],
                          matchedRangesB: [],
                        );

                        _cachedComparisonMap['student1'] = demoResultA;
                        _cachedComparisonMap['student2'] = demoResultA;
                        _cachedComparisonMap['student3'] = demoResultB;
                        _cachedComparisonMap['student4'] = demoResultB;
                        _cachedComparisonMap['student5'] = demoResultA;

                        _cubit.setSuccessReport(
                          const BatchReportModel(
                            batchJobId: 'batch_sim_demo_01',
                            status: 'COMPLETED',
                            progress: 1.0,
                            reports: [
                              StudentReport(
                                studentId: 'student1',
                                studentName: 'Student 1 (Alex Rivera)',
                                maxScore: 0.842,
                                topPeerName: 'Student 2 (David Chen)',
                                flagged: true,
                              ),
                              StudentReport(
                                studentId: 'student2',
                                studentName: 'Student 2 (David Chen)',
                                maxScore: 0.842,
                                topPeerName: 'Student 1 (Alex Rivera)',
                                flagged: true,
                              ),
                              StudentReport(
                                studentId: 'student3',
                                studentName: 'Student 3 (Maya Lin)',
                                maxScore: 0.485,
                                topPeerName: 'Student 4 (Sophia Taylor)',
                                flagged: true,
                              ),
                              StudentReport(
                                studentId: 'student4',
                                studentName: 'Student 4 (Sophia Taylor)',
                                maxScore: 0.485,
                                topPeerName: 'Student 3 (Maya Lin)',
                                flagged: true,
                              ),
                              StudentReport(
                                studentId: 'student5',
                                studentName: 'Student 5 (Liam Brown)',
                                maxScore: 0.182,
                                topPeerName: 'Student 1',
                                flagged: false,
                              ),
                            ],
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialInfoCard(AppState appState) {
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Batch Plagiarism Engine Ready',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your assignment tag (e.g. "${_tagController.text}") and click "Start Batch Evaluation" to cross-compare all matching student lab files.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(double progress) {
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: AppColors.paper,
            color: AppColors.brand,
            minHeight: 8,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
              ),
              const SizedBox(width: 10),
              Text(
                'Evaluating pairwise similarity across batch... ${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Executing cross-document shingling and TF-IDF cosine comparison.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _cubit.cancelEvaluation(),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message, AppState appState) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.high.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.high, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.high),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Notice: Batch evaluation can run directly on your uploaded files using the local similarity engine without requiring a remote REST server.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run Local Evaluation (Offline)'),
                onPressed: () => _runLocalBatchEvaluation(appState),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _cubit.cancelEvaluation(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportDashboard(BatchReportModel report, AppState appState) {
    final filteredReports = report.reports.where((r) {
      final matchesThreshold = r.maxScore >= _similarityThreshold;
      final matchesSearch = _searchQuery.isEmpty ||
          r.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.topPeerName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesThreshold && matchesSearch;
    }).toList();

    final totalCount = report.reports.length;
    final flaggedCount = report.reports.where((r) => r.maxScore >= 0.40).length;
    final highRiskCount = report.reports.where((r) => r.maxScore >= 0.60).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metric Row (Responsive LayoutBuilder)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 540;
            final cardTotal = _buildMetricCard(
              title: 'Total Evaluated',
              value: '$totalCount',
              subtitle: 'Students in batch',
              color: AppColors.brand,
              icon: Icons.school_outlined,
            );
            final cardFlagged = _buildMetricCard(
              title: 'Flagged Review',
              value: '$flaggedCount',
              subtitle: '> 40% similarity',
              color: AppColors.review,
              icon: Icons.warning_amber_rounded,
            );
            final cardHighRisk = _buildMetricCard(
              title: 'High Risk',
              value: '$highRiskCount',
              subtitle: '> 60% copy match',
              color: AppColors.high,
              icon: Icons.gavel_rounded,
            );

            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: cardTotal),
                      const SizedBox(width: 10),
                      Expanded(child: cardFlagged),
                    ],
                  ),
                  const SizedBox(height: 10),
                  cardHighRisk,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cardTotal),
                const SizedBox(width: 12),
                Expanded(child: cardFlagged),
                const SizedBox(width: 12),
                Expanded(child: cardHighRisk),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Controls Row: Slider Threshold & Search (Responsive LayoutBuilder)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  final titleWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Similarity Threshold: ${(_similarityThreshold * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                  final countWidget = Text(
                    'Showing ${filteredReports.length} of $totalCount students',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 4),
                        countWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleWidget),
                      const SizedBox(width: 8),
                      countWidget,
                    ],
                  );
                },
              ),
              Slider(
                value: _similarityThreshold,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(_similarityThreshold * 100).toStringAsFixed(0)}%',
                activeColor: AppColors.brand,
                onChanged: (val) => setState(() => _similarityThreshold = val),
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search student name or top peer…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (query) => setState(() => _searchQuery = query),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Leaderboard: Responsive Card List on mobile, Table on desktop
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 640;

            if (isMobile) {
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.paper,
                        border: Border(bottom: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.leaderboard_outlined, size: 18, color: AppColors.brand),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Student Plagiarism Reports',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                          Text(
                            '${filteredReports.length} reports',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (filteredReports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No students match the current threshold filter.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredReports.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                        itemBuilder: (context, index) {
                          return _buildMobileStudentCard(filteredReports[index], appState);
                        },
                      ),
                  ],
                ),
              );
            }

            // Desktop / Tablet 5-Column Table
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: AppColors.paper,
                      border: Border(bottom: BorderSide(color: AppColors.line)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text('Student', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Max Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text('Copied Mostly From', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        SizedBox(width: 170, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      ],
                    ),
                  ),
                  if (filteredReports.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No students match the current threshold filter.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredReports.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (context, index) {
                        final item = filteredReports[index];
                        final isHigh = item.maxScore >= 0.60;
                        final isMedium = item.maxScore >= 0.40;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isHigh
                                          ? AppColors.high.withValues(alpha: 0.15)
                                          : isMedium
                                              ? AppColors.review.withValues(alpha: 0.15)
                                              : AppColors.low.withValues(alpha: 0.15),
                                      child: Icon(
                                        isHigh
                                            ? Icons.dangerous_outlined
                                            : isMedium
                                                ? Icons.warning_amber_rounded
                                                : Icons.check,
                                        size: 14,
                                        color: isHigh
                                            ? AppColors.high
                                            : isMedium
                                                ? AppColors.review
                                                : AppColors.low,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.studentName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${(item.maxScore * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isHigh
                                        ? AppColors.high
                                        : isMedium
                                            ? AppColors.review
                                            : AppColors.low,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.topPeerName,
                                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isHigh
                                        ? AppColors.high.withValues(alpha: 0.1)
                                        : isMedium
                                            ? AppColors.review.withValues(alpha: 0.1)
                                            : AppColors.low.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isHigh
                                        ? 'High Risk'
                                        : isMedium
                                            ? 'Review'
                                            : 'Low Risk',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isHigh
                                          ? AppColors.high
                                          : isMedium
                                              ? AppColors.review
                                              : AppColors.low,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: Row(
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Inspect', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _inspectStudentMatch(item, appState),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.outgoing_mail, size: 18, color: AppColors.brand),
                                      tooltip: 'Request Re-upload from Student',
                                      onPressed: () => _openReuploadDialog(
                                        context: context,
                                        appState: appState,
                                        studentId: item.studentId,
                                        studentName: item.studentName,
                                        assignmentTag: _tagController.text.trim(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileStudentCard(StudentReport item, AppState appState) {
    final isHigh = item.maxScore >= 0.60;
    final isMedium = item.maxScore >= 0.40;
    final riskColor = isHigh ? AppColors.high : (isMedium ? AppColors.review : AppColors.low);
    final riskLabel = isHigh ? 'High Risk' : (isMedium ? 'Review' : 'Low Risk');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: riskColor.withValues(alpha: 0.15),
                child: Icon(
                  isHigh
                      ? Icons.dangerous_outlined
                      : isMedium
                          ? Icons.warning_amber_rounded
                          : Icons.check,
                  size: 14,
                  color: riskColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${(item.maxScore * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: AppColors.text),
                    children: [
                      const TextSpan(text: 'Matched with: ', style: TextStyle(color: AppColors.muted)),
                      TextSpan(
                        text: item.topPeerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.search, size: 15),
                  label: const Text('Inspect Match', style: TextStyle(fontSize: 12)),
                  onPressed: () => _inspectStudentMatch(item, appState),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.brand,
                  ),
                  icon: const Icon(Icons.outgoing_mail, size: 15),
                  label: const Text('Notify', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openReuploadDialog(
                    context: context,
                    appState: appState,
                    studentId: item.studentId,
                    studentName: item.studentName,
                    assignmentTag: _tagController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _inspectStudentMatch(StudentReport item, AppState appState) {
    // Retrieve matched comparison safely from cache or create fallback
    ComparisonResult? matchedComparison =
        _cachedComparisonMap[item.studentId] ??
        _cachedComparisonMap[item.studentName];

    matchedComparison ??= appState.results.where((r) =>
        r.docAId == item.studentId ||
        r.docBId == item.studentId ||
        r.docAName == item.studentName ||
        r.docBName == item.studentName ||
        r.docAName == item.topPeerName ||
        r.docBName == item.topPeerName,
    ).firstOrNull;

    matchedComparison ??= (appState.results.isNotEmpty ? appState.results.first : null);

    matchedComparison ??= ComparisonResult(
      docAId: item.studentId,
      docBId: 'peer_${item.studentId}',
      docAName: item.studentName,
      docBName: item.topPeerName,
      shingleSimilarity: item.maxScore,
      cosineSimilarity: item.maxScore,
      overallScore: item.maxScore,
      matchedRangesA: const [],
      matchedRangesB: const [],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(result: matchedComparison!),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
