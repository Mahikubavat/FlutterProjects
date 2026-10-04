import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../models/document_extraction.dart';
import '../sample_data/sample_documents.dart';
import '../services/ai_detection_service.dart';
import '../services/document_text_service.dart';
import '../services/vision_ocr_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_authorship_dialog.dart';
import '../widgets/ui_kit.dart';
import 'document_viewer_screen.dart';
import 'main_navigation_shell.dart';

/// Executive Integrity Dashboard matching Design 1 (Forest Emerald & Mint).
/// Features:
/// - Greeting header with user avatar, notification badge, and circular '+' upload button.
/// - Hero gradient progress card with circular integrity ring and dual-layer statistics.
/// - Segmented horizontal filter pills (All, Flagged, AI-Polished, AI-Generated, Clean).
/// - Clean submission cards with priority indicators, student avatars, dual-layer AI chips, and actions.
/// - Modal quick upload sheet and bottom compare dock.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isPicking = false;
  String _ocrMessage = '';
  double _ocrProgress = 0;
  String _activeFilter = 'all'; // 'all', 'flagged', 'ai_edited', 'ai_generated', 'clean'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final _visionOcr = VisionOcrService(
    apiKey: const String.fromEnvironment('VISION_OCR_API_KEY'),
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _pickDocuments() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;

      final appState = context.read<AppState>();
      int skipped = 0;
      int withoutText = 0;
      int timedOut = 0;
      final errors = <String>[];

      for (final file in result.files) {
        if (file.bytes == null) continue;
        String text;
        DocumentExtraction? extraction;
        try {
          extraction = await DocumentTextService.extract(
            fileName: file.name,
            bytes: file.bytes!,
            visionOcr: _visionOcr,
            onProgress: (progress, message) {
              if (!mounted) return;
              setState(() {
                _ocrProgress = progress;
                _ocrMessage = '${file.name}: $message';
              });
            },
          );
          text = extraction.cleanedText;
          errors.addAll(extraction.errors);
        } on TimeoutException {
          timedOut++;
          continue;
        } catch (error) {
          errors.add('${file.name}: $error');
          skipped++;
          continue;
        }
        if (text.trim().isEmpty) {
          withoutText++;
        }
        try {
          await appState.addDocument(
            AssignmentDocument(
              id: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
              fileName: file.name,
              rawText: extraction.rawText,
              cleanedText: extraction.cleanedText,
              pages: extraction.pages,
            ),
            originalBytes: file.bytes,
          );
        } catch (error) {
          errors.add('${file.name}: $error');
          skipped++;
        }
      }

      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$skipped file(s) had no extractable text, even after OCR.',
            ),
          ),
        );
      }
      if (withoutText > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$withoutText file(s) were saved, but no extractable text was found.',
            ),
          ),
        );
      }
      if (timedOut > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$timedOut file(s) exceeded the 5-minute OCR limit and were skipped.',
            ),
          ),
        );
      }
      if (errors.isNotEmpty && mounted) {
        final hasScanOrRenderIssue = errors.any((e) =>
            e.contains('PlatformException') ||
            e.contains('channel-error') ||
            e.contains('Unable to open PDF') ||
            e.contains('page has no selectable text') ||
            e.contains('OCR fallback error'));
        final message = hasScanOrRenderIssue
            ? 'Notice: Document contains scanned pages without selectable text. Text was extracted from digital pages.'
            : 'Notice: Some pages could not be processed. Text was extracted where available.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
          _ocrProgress = 0;
          _ocrMessage = '';
        });
      }
    }
  }

  void _showQuickUploadSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: AppColors.brand,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload New Assignment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Select PDF or scanned assignments to screen',
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickDocuments();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.file_upload_outlined,
                          size: 32,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Browse files to upload',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Supports PDF, JPG, PNG, WEBP, BMP documents',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Load Demo Sample Set'),
                      onPressed: () {
                        context
                            .read<AppState>()
                            .loadSampleDocuments(SampleDocuments.all);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sample documents loaded successfully!'),
                            backgroundColor: AppColors.brand,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context, AppState appState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final notifications = appState.notifications;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.brand, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Notifications & Alerts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      if (notifications.any((n) => !n.isRead)) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Mark all as read', style: TextStyle(fontSize: 12.5)),
                          onPressed: () {
                            for (final n in notifications) {
                              appState.markNotificationAsRead(n.id);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(
                          child: Text(
                            'No notifications at this time.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            final isReupload =
                                item.type == NotificationType.reuploadRequested;
                            final isCompleted =
                                item.type == NotificationType.reuploadCompleted;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isReupload
                                    ? AppColors.high.withValues(alpha: 0.15)
                                    : isCompleted
                                        ? AppColors.low.withValues(alpha: 0.15)
                                        : AppColors.brand.withValues(alpha: 0.15),
                                child: Icon(
                                  isReupload
                                      ? Icons.warning_amber_rounded
                                      : isCompleted
                                          ? Icons.mark_email_read_outlined
                                          : Icons.info_outline,
                                  color: isReupload
                                      ? AppColors.high
                                      : isCompleted
                                          ? AppColors.low
                                          : AppColors.brand,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight:
                                      item.isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(item.message, style: const TextStyle(fontSize: 12.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')} • ${item.senderName}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => appState.dismissNotification(item.id),
                              ),
                              onTap: () {
                                appState.markNotificationAsRead(item.id);
                                Navigator.of(ctx).pop();
                                if (isReupload) {
                                  _pickDocuments();
                                } else if (isCompleted && appState.isAdmin) {
                                  MainNavigationShell.switchTab(context, 1);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;
    final currentUser = appState.currentUser;
    final documents = appState.documents;
    final selectedCount = appState.selectedDocumentIds.length;

    // Filter documents based on active filter pill and search query
    final filteredDocuments = documents.where((doc) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = doc.fileName.toLowerCase().contains(q);
        final studentMatch =
            (doc.ownerName ?? '').toLowerCase().contains(q);
        if (!nameMatch && !studentMatch) return false;
      }

      if (_activeFilter == 'all') return true;

      // Student filters (strictly format-based, no AI metrics exposed)
      if (!isAdmin) {
        if (_activeFilter == 'pdf') {
          return doc.fileName.toLowerCase().endsWith('.pdf');
        }
        if (_activeFilter == 'image') {
          return !doc.fileName.toLowerCase().endsWith('.pdf');
        }
        return true;
      }

      // Instructor/Admin AI-specific filters
      if (_activeFilter == 'flagged') {
        final isAiGen = doc.aiClassification == AiAuthorshipType.aiGenerated.id;
        final hasHighAi = (doc.aiSyntheticScore ?? 0.0) >= 0.65;
        return isAiGen || hasHighAi;
      }
      if (_activeFilter == 'ai_edited') {
        return doc.aiClassification == AiAuthorshipType.aiEdited.id ||
            (doc.aiEditingScore ?? 0.0) >= 0.25;
      }
      if (_activeFilter == 'ai_generated') {
        return doc.aiClassification == AiAuthorshipType.aiGenerated.id ||
            (doc.aiSyntheticScore ?? 0.0) >= 0.50;
      }
      if (_activeFilter == 'clean') {
        final isHuman = doc.aiClassification == AiAuthorshipType.humanOriginal.id;
        final lowSynth = (doc.aiSyntheticScore ?? 0.0) < 0.30;
        return isHuman || (doc.aiClassification == null && lowSynth);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Executive Bar (Design 1)
            _buildExecutiveTopBar(context, appState, currentUser, isAdmin),

            // Scrollable Content
            Expanded(
              child: PageFrame(
                maxWidth: 980,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: [
                    // Title section
                    _buildSectionHeader(isAdmin),
                    const SizedBox(height: 16),

                    // Unread alert banner (if student reupload or instructor update)
                    if (appState.unreadNotifications.isNotEmpty) ...[
                      _buildNotificationBanner(appState),
                      const SizedBox(height: 16),
                    ],

                    // Live extraction progress banner when picking/parsing files
                    if (_isPicking) ...[
                      _buildExtractionProgressCard(),
                      const SizedBox(height: 16),
                    ],

                    // Hero Progress Card ("Today's Integrity" / "% Clean")
                    _buildHeroProgressCard(documents, isAdmin),
                    const SizedBox(height: 20),

                    // Search and Filter Pills
                    _buildFilterRow(documents, isAdmin),
                    const SizedBox(height: 18),

                    // Active Document Cards
                    if (documents.isEmpty)
                      _buildEmptyState(isAdmin)
                    else if (filteredDocuments.isEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded, size: 36, color: AppColors.muted),
                              const SizedBox(height: 10),
                              Text(
                                'No submissions match "$_activeFilter"',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try clearing filters or search keywords.',
                                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredDocuments.map((doc) => _buildSubmissionCard(doc, appState, isAdmin)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: isAdmin && selectedCount > 0
          ? _buildBottomCompareDock(appState, selectedCount)
          : null,
    );
  }

  /// Top Bar with Avatar greeting, Notification bell, and dark '+' Upload button.
  Widget _buildExecutiveTopBar(
    BuildContext context,
    AppState appState,
    AppUser? currentUser,
    bool isAdmin,
  ) {
    final unread = appState.unreadNotifications.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          // User Avatar & Greeting
          Expanded(
            child: InkWell(
              onTap: () => MainNavigationShell.goToProfile(context),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  _UserAvatar(user: currentUser, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                currentUser?.displayName.isNotEmpty == true
                                    ? currentUser!.displayName
                                    : currentUser?.email.split('@').first ?? 'Instructor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? AppColors.brand.withValues(alpha: 0.08)
                                    : AppColors.muted.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin ? 'ADMIN' : 'STUDENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isAdmin ? AppColors.brand : AppColors.muted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell
          IconButton(
            tooltip: 'Notifications & Alerts',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.high,
              child: const Icon(
                Icons.notifications_outlined,
                size: 22,
                color: AppColors.text,
              ),
            ),
            onPressed: () => _showNotificationsSheet(context, appState),
          ),
          const SizedBox(width: 6),

          // Quick Upload '+' Button (matching Design 1)
          Material(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(20),
            elevation: 1,
            shadowColor: AppColors.brand.withValues(alpha: 0.3),
            child: Tooltip(
              message: 'Upload Assignment',
              child: InkWell(
                onTap: () => _showQuickUploadSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section Title & Subtitle
  Widget _buildSectionHeader(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          isAdmin ? 'Document Analysis Workspace' : 'Your Submissions',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAdmin
              ? 'Real-time plagiarism screening, pairwise comparison & AI dual-layer verification.'
              : 'Uploaded assignments, laboratory reports, and personal submission records.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Hero Card with Forest Emerald gradient, circular integrity ring gauge, and dual-layer metrics
  Widget _buildHeroProgressCard(List<AssignmentDocument> documents, bool isAdmin) {
    final total = documents.length;

    // Student View: Focus on submission portfolio & format metrics (No AI metrics exposed)
    if (!isAdmin) {
      int pdfCount = 0;
      int imageCount = 0;
      int totalWords = 0;

      for (final doc in documents) {
        if (doc.fileName.toLowerCase().endsWith('.pdf')) {
          pdfCount++;
        } else {
          imageCount++;
        }
        totalWords += doc.wordCount;
      }

      final wordsFormatted = totalWords > 999
          ? '${(totalWords / 1000).toStringAsFixed(1)}k'
          : '$totalWords';

      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF09281E), Color(0xFF133E30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.mint.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF09281E).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Category Title + Submissions Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          size: 15,
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Submission Portfolio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: total == 0 ? Colors.white38 : AppColors.mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$total Uploaded',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Middle: Ring Gauge + Status Description
            Row(
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0.0 : 1.0,
                          strokeWidth: 7.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mint),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Text(
                            'FILES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total == 0 ? 'Portfolio Ready' : '$total Assignment(s) Uploaded',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total == 0
                            ? 'Upload assignments to check formatting and stage them for evaluation.'
                            : 'All uploaded files are preserved in your secure workspace.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bottom: 3 Full-Width Stat Pills
            Row(
              children: [
                _buildHeroStatPill('PDF Files', '$pdfCount', Colors.white70),
                const SizedBox(width: 8),
                _buildHeroStatPill('Scanned', '$imageCount', AppColors.mint),
                const SizedBox(width: 8),
                _buildHeroStatPill('Total Words', wordsFormatted, const Color(0xFFFBBF24)),
              ],
            ),
          ],
        ),
      );
    }

    // Instructor/Admin View: Full AI dual-layer cohort metrics
    int highRisk = 0;
    int aiEdited = 0;
    int aiGenerated = 0;
    int humanClean = 0;

    for (final doc in documents) {
      final cls = doc.aiClassification;
      if (cls == AiAuthorshipType.aiGenerated.id || (doc.aiSyntheticScore ?? 0) >= 0.50) {
        aiGenerated++;
      } else if (cls == AiAuthorshipType.aiEdited.id || (doc.aiEditingScore ?? 0) >= 0.25) {
        aiEdited++;
      } else {
        humanClean++;
      }
      if ((doc.aiSyntheticScore ?? 0) >= 0.65) {
        highRisk++;
      }
    }

    final atRiskCount = (aiGenerated + highRisk).clamp(0, total);
    final cleanPercentage = total > 0
        ? (((total - atRiskCount) / total) * 100).clamp(0, 100).round()
        : 100;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF09281E), Color(0xFF133E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.mint.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF09281E).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Category Title + Submissions Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        "Cohort Integrity",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: total == 0 ? Colors.white38 : AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$total Submissions',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Middle: Ring Gauge + Status Description
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 1.0 : (cleanPercentage / 100),
                        strokeWidth: 7.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mint),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$cleanPercentage%',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'CLEAN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mint,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'Screening Ready'
                          : atRiskCount == 0
                              ? 'Optimal Integrity'
                              : '$atRiskCount Flagged for Review',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'Upload student documents to begin dual-layer AI and pairwise plagiarism screening.'
                          : atRiskCount == 0
                              ? 'All current submissions match original human-authored writing standards.'
                              : 'Synthetic AI patterns detected in $atRiskCount document(s).',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom: 3 Full-Width Stat Pills
          Row(
            children: [
              _buildHeroStatPill('AI-Polished', '$aiEdited', const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildHeroStatPill('AI-Generated', '$aiGenerated', const Color(0xFFFB7185)),
              const SizedBox(width: 8),
              _buildHeroStatPill('Original', '$humanClean', AppColors.mint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatPill(String label, String count, Color indicatorColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented Horizontal Filter Pills (Design 1)
  Widget _buildFilterRow(List<AssignmentDocument> documents, bool isAdmin) {
    final allCount = documents.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (documents.isNotEmpty) ...[
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isAdmin
                    ? 'Search by file name or student…'
                    : 'Search your submissions…',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                ),
              ),
            ),
          ),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: isAdmin
                ? [
                    _buildFilterPill('All', 'all', allCount, icon: Icons.layers_outlined),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'Needs Review',
                      'flagged',
                      documents.where((d) =>
                          d.aiClassification == AiAuthorshipType.aiGenerated.id ||
                          (d.aiSyntheticScore ?? 0) >= 0.50).length,
                      alertColor: AppColors.high,
                      icon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'AI-Polished',
                      'ai_edited',
                      documents.where((d) =>
                          d.aiClassification == AiAuthorshipType.aiEdited.id ||
                          (d.aiEditingScore ?? 0) >= 0.25).length,
                      alertColor: const Color(0xFF0284C7),
                      icon: Icons.auto_awesome_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'AI-Generated',
                      'ai_generated',
                      documents.where((d) =>
                          d.aiClassification == AiAuthorshipType.aiGenerated.id ||
                          (d.aiSyntheticScore ?? 0) >= 0.50).length,
                      alertColor: AppColors.high,
                      icon: Icons.psychology_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'Clean Draft',
                      'clean',
                      documents.where((d) =>
                          d.aiClassification == AiAuthorshipType.humanOriginal.id ||
                          (d.aiClassification == null && (d.aiSyntheticScore ?? 0) < 0.30)).length,
                      alertColor: AppColors.low,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ]
                : [
                    _buildFilterPill('All Files', 'all', allCount, icon: Icons.layers_outlined),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'PDF Documents',
                      'pdf',
                      documents.where((d) => d.fileName.toLowerCase().endsWith('.pdf')).length,
                      alertColor: Colors.red.shade700,
                      icon: Icons.picture_as_pdf_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'Scanned Images',
                      'image',
                      documents.where((d) => !d.fileName.toLowerCase().endsWith('.pdf')).length,
                      alertColor: AppColors.brand,
                      icon: Icons.image_outlined,
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtractionProgressCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.brand.withValues(alpha: 0.3),
      color: AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
              ),
              SizedBox(width: 10),
              Text(
                'Extracting & Processing Document Text…',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _ocrProgress == 0 ? null : _ocrProgress,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          if (_ocrMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _ocrMessage,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPill(
    String title,
    String key,
    int count, {
    Color? alertColor,
    IconData? icon,
  }) {
    final isSelected = _activeFilter == key;

    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.line,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : (alertColor ?? AppColors.muted),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : (alertColor?.withValues(alpha: 0.12) ?? AppColors.paper),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : (alertColor ?? AppColors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Submission Card (Design 1)
  Widget _buildSubmissionCard(
    AssignmentDocument doc,
    AppState appState,
    bool isAdmin,
  ) {
    final isSelected = appState.isDocumentSelected(doc.id);
    final isPdf = doc.fileName.toLowerCase().endsWith('.pdf');

    // Determine status dot color (AI severity for admin, clean status for student)
    Color statusDotColor = AppColors.mint;
    if (isAdmin) {
      if (doc.aiClassification == AiAuthorshipType.aiGenerated.id || (doc.aiSyntheticScore ?? 0) >= 0.5) {
        statusDotColor = AppColors.high;
      } else if (doc.aiClassification == AiAuthorshipType.aiEdited.id || (doc.aiEditingScore ?? 0) >= 0.25) {
        statusDotColor = const Color(0xFF0284C7);
      } else if (doc.aiClassification == AiAuthorshipType.hybridCoCreated.id) {
        statusDotColor = AppColors.review;
      } else {
        statusDotColor = AppColors.low;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        borderColor: isSelected ? AppColors.brand : AppColors.line,
        color: isSelected ? AppColors.mint.withValues(alpha: 0.05) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority / Category Status Dot
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                    color: statusDotColor,
                    shape: BoxShape.circle,
                  ),
                ),

                // Multi-select Checkbox (for Admins / Teachers)
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.brand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (_) => appState.toggleDocumentSelection(doc.id),
                      ),
                    ),
                  ),

                // Icon Badge
                IconBadge(
                  icon: isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  size: 38,
                  color: isPdf ? Colors.red.shade700 : AppColors.brand,
                ),
                const SizedBox(width: 12),

                // Document Title & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            doc.ownerName ?? 'Student Submission',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          Text(
                            '${doc.wordCount} words',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          if (doc.pages.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            Text(
                              '${doc.pages.length} pages',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick Action Pop-up Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) {
                    if (action == 'view') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(document: doc),
                        ),
                      );
                    } else if (action == 'ai_check') {
                      appState.runAiCheck(doc.id);
                    } else if (action == 'delete') {
                      appState.removeDocument(doc.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('View Document / PDF'),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      const PopupMenuItem(
                        value: 'ai_check',
                        child: Row(
                          children: [
                            Icon(Icons.psychology_outlined, size: 18, color: AppColors.brand),
                            SizedBox(width: 10),
                            Text('Screen AI Dual-Layer'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete Document', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI Dual-Layer Status Chip (for Admin) vs Format Tag (for Student)
            Row(
              children: [
                if (isAdmin)
                  Flexible(
                    child: _AiAuthorshipChip(
                      document: doc,
                      onTap: () => AiAuthorshipDialog.show(
                        context,
                        document: doc,
                        onRerunCheck: () => appState.runAiCheck(doc.id),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                            size: 13,
                            color: isPdf ? Colors.red.shade700 : AppColors.brand,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isPdf ? 'PDF Submission' : 'Scanned Image OCR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View Text', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(document: doc),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State with clear calls to action and compact responsive spacing
  Widget _buildEmptyState(bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.mint.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isAdmin ? Icons.folder_open_outlined : Icons.cloud_upload_outlined,
                size: 30,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isAdmin ? 'No Submissions Yet' : 'No Documents Uploaded',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                isAdmin
                    ? 'Uploaded documents from students will appear here automatically.'
                    : 'Upload a PDF, research document, or scanned image to start, or load sample assignments.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  onPressed: () => _showQuickUploadSheet(context),
                ),
                if (isAdmin)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.line, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.science_outlined, size: 17),
                    label: const Text('Load Demo Sample Set', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    onPressed: () {
                      context.read<AppState>().loadSampleDocuments(SampleDocuments.all);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sample documents loaded successfully!'),
                          backgroundColor: AppColors.brand,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Unread Notification Alert Card
  Widget _buildNotificationBanner(AppState appState) {
    final unread = appState.unreadNotifications;
    if (unread.isEmpty) return const SizedBox.shrink();

    final isAdmin = appState.isAdmin;
    final item = unread.first;
    final isReuploadReq = item.type == NotificationType.reuploadRequested;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: isReuploadReq
          ? AppColors.high.withValues(alpha: 0.4)
          : AppColors.low.withValues(alpha: 0.4),
      color: isReuploadReq
          ? AppColors.high.withValues(alpha: 0.06)
          : AppColors.low.withValues(alpha: 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReuploadReq ? Icons.warning_amber_rounded : Icons.mark_email_read_outlined,
            color: isReuploadReq ? AppColors.high : AppColors.low,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isReuploadReq ? AppColors.high : AppColors.low,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => appState.markNotificationAsRead(item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(item.message, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 10),
                if (!isAdmin && isReuploadReq)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.high),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Re-upload Revised Document Now'),
                    onPressed: _pickDocuments,
                  )
                else if (isAdmin)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.low),
                    icon: const Icon(Icons.hub_outlined, size: 16),
                    label: const Text('Open Batch Lab'),
                    onPressed: () {
                      appState.markNotificationAsRead(item.id);
                      MainNavigationShell.switchTab(context, 1);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Selection Dock for Pairwise and Batch operations
  Widget _buildBottomCompareDock(AppState appState, int selectedCount) {
    final canCompare = selectedCount >= 2 && !appState.isProcessing;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.line, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final isNarrow = constraints.maxWidth < 460;

            final selectionBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCount >= 2
                    ? AppColors.brand.withValues(alpha: 0.1)
                    : AppColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedCount >= 2 ? AppColors.brand : AppColors.line,
                ),
              ),
              child: Text(
                '$selectedCount selected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selectedCount >= 2 ? AppColors.brand : AppColors.muted,
                ),
              ),
            );

            final clearBtn = TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: appState.clearDocumentSelection,
              child: const Text('Clear'),
            );

            final batchBtn = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.hub_outlined, size: 16, color: AppColors.brand),
              label: const Text('Batch Lab', style: TextStyle(fontSize: 12.5)),
              onPressed: () => MainNavigationShell.switchTab(context, 1),
            );

            final compareBtn = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canCompare ? AppColors.brand : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: appState.isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compare_arrows_rounded, size: 16),
              label: Text(
                appState.isProcessing ? 'Analyzing…' : 'Compare 1-to-1',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              onPressed: canCompare
                  ? () async {
                      await appState.runAnalysis();
                      if (!mounted) return;
                      MainNavigationShell.switchTab(context, 2);
                    }
                  : null,
            );

            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      selectionBadge,
                      const SizedBox(width: 8),
                      clearBtn,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: batchBtn),
                      const SizedBox(width: 8),
                      Expanded(child: compareBtn),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                selectionBadge,
                const SizedBox(width: 10),
                clearBtn,
                const Spacer(),
                batchBtn,
                const SizedBox(width: 10),
                compareBtn,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dual-layer AI authorship chip showing AI-Polished vs AI-Generated distinction
class _AiAuthorshipChip extends StatelessWidget {
  final AssignmentDocument document;
  final VoidCallback onTap;

  const _AiAuthorshipChip({required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasScreeningData = document.aiClassification != null || document.aiProbability != null;
    final classification = AiAuthorshipType.fromId(document.aiClassification);
    final synthetic = document.aiSyntheticScore ?? 0.0;
    final editing = document.aiEditingScore ?? 0.0;

    Color color;
    String label;
    IconData icon;

    if (!hasScreeningData) {
      color = AppColors.brand;
      label = 'Run AI Screening';
      icon = Icons.auto_awesome_outlined;
    } else {
      switch (classification) {
        case AiAuthorshipType.aiEdited:
          color = const Color(0xFF0284C7); // Sky Blue
          label = 'AI-Polished: ${(editing * 100).round()}% (Human Draft)';
          icon = Icons.edit_note_rounded;
          break;
        case AiAuthorshipType.aiGenerated:
          color = AppColors.high;
          label = 'AI-Generated: ${(synthetic * 100).round()}%';
          icon = Icons.smart_toy_outlined;
          break;
        case AiAuthorshipType.hybridCoCreated:
          color = AppColors.review;
          label = 'Hybrid: ${(synthetic * 100).round()}% Gen • ${(editing * 100).round()}% Edit';
          icon = Icons.auto_awesome_motion_outlined;
          break;
        case AiAuthorshipType.humanOriginal:
          color = AppColors.low;
          label = 'Human Original';
          icon = Icons.person_outline_rounded;
          break;
      }
    }

    return Tooltip(
      message: 'Click to open AI Dual-Layer Authorship Inspector',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, size: 14, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;

  const _UserAvatar({required this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoBase64;
    if (photo != null && photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(photo)),
        );
      } catch (_) {}
    }
    final initial = (user?.displayName.isNotEmpty == true
            ? user!.displayName[0]
            : user?.email.isNotEmpty == true
                ? user!.email[0]
                : 'U')
        .toUpperCase();

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.14),
            AppColors.mint.withValues(alpha: 0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w800,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
