import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/assignment_document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_authorship_dialog.dart';
import '../widgets/ui_kit.dart';

/// Full viewer for uploaded PDFs and image documents.
/// Accessible to both regular students (for their own files) and administrators
/// (for all student submissions).
class DocumentViewerScreen extends StatefulWidget {
  final AssignmentDocument document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  int _selectedTab = 0; // 0 = Preview, 1 = Extracted Text

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await context
          .read<AppState>()
          .getDocumentBytes(widget.document);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Unable to load document binary preview.';
          _loading = false;
        });
      } else {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load file preview: $e';
        _loading = false;
      });
    }
  }

  bool get _isPdf {
    final name = widget.document.fileName.toLowerCase();
    return name.endsWith('.pdf') ||
        (name.contains('.') &&
            !name.endsWith('.jpg') &&
            !name.endsWith('.jpeg') &&
            !name.endsWith('.png') &&
            !name.endsWith('.webp') &&
            !name.endsWith('.bmp'));
  }

  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.storage[0] *= 1.25;
    matrix.storage[5] *= 1.25;
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.storage[0] *= 0.8;
    matrix.storage[5] *= 0.8;
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final words = doc.cleanedText.trim().isEmpty
        ? 0
        : doc.cleanedText.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: buildAppBar(
        doc.fileName,
        actions: [
          if (doc.ownerName != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: StatPill(
                  label: doc.ownerName!,
                  color: AppColors.ink,
                ),
              ),
            ),
          if (context.watch<AppState>().isAdmin)
            IconButton(
              icon: const Icon(Icons.psychology_outlined, size: 20),
              tooltip: 'Inspect AI Authorship (Edited vs Generated)',
              onPressed: () {
                final appState = context.read<AppState>();
                final currentDoc =
                    appState.documentById(widget.document.id) ?? widget.document;
                AiAuthorshipDialog.show(
                  context,
                  document: currentDoc,
                  onRerunCheck: () => appState.runAiCheck(currentDoc.id),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tab Switcher: Preview vs Extracted Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment<int>(
                        value: 0,
                        icon: Icon(
                          _isPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          size: 16,
                        ),
                        label: Text(_isPdf ? 'PDF Preview' : 'Image Scan'),
                      ),
                      const ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.article_outlined, size: 16),
                        label: Text('Extracted Text'),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedTab = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main View Body
          Expanded(
            child: _selectedTab == 1
                ? _buildExtractedTextViewer(words)
                : _buildPreviewBody(words),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody(int words) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document…', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }

    if (_error != null || _bytes == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48, color: AppColors.review),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Document preview is unavailable.',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'You can view and inspect the complete extracted text directly.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _loadBytes,
                    child: const Text('Retry Preview'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('Read Extracted Text'),
                    onPressed: () {
                      setState(() {
                        _selectedTab = 1;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdf) {
      return PdfPreview(
        build: (format) => _bytes!,
        useActions: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        maxPageWidth: 800,
        pdfFileName: widget.document.fileName,
        onError: (context, error) {
          return _buildPdfFallbackView(error);
        },
      );
    }

    // Image viewer with pan & zoom controls
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          maxScale: 5.0,
          minScale: 0.5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Image.memory(
                _bytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 20),
                  tooltip: 'Zoom Out',
                  onPressed: _zoomOut,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 20),
                  tooltip: 'Reset Zoom',
                  onPressed: _resetZoom,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 20),
                  tooltip: 'Zoom In',
                  onPressed: _zoomIn,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfFallbackView(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.brand,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Native PDF Preview Unavailable',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The device renderer could not render this specific PDF format natively. The full extracted text content is preserved and ready to inspect.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('View Extracted Text'),
                  onPressed: () {
                    setState(() {
                      _selectedTab = 1;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedTextViewer(int words) {
    final doc = widget.document;
    final text = doc.cleanedText.isNotEmpty ? doc.cleanedText : doc.rawText;
    final chars = text.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat and quick actions bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$words words • $chars characters',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Text', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document text copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Clean typography reader
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: text.trim().isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No text could be extracted from this document.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                : SelectableText(
                    text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.65,
                      color: AppColors.text,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
