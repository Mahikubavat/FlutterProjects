import 'dart:typed_data';
import 'package:flutter/material.dart';
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
          _error = 'Unable to load document contents.';
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
        _error = 'Failed to load file: $e';
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  size: 15,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 4),
                Text(
                  _isPdf ? 'PDF Document' : 'Image Scan',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (doc.ownerName != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                final currentDoc = appState.documentById(widget.document.id) ?? widget.document;
                if (currentDoc.aiClassification == null && currentDoc.aiProbability == null) {
                  appState.runAiCheck(currentDoc.id).then((_) {
                    final updated = appState.documentById(widget.document.id) ?? widget.document;
                    if (context.mounted) {
                      AiAuthorshipDialog.show(context, document: updated);
                    }
                  });
                } else {
                  AiAuthorshipDialog.show(
                    context,
                    document: currentDoc,
                    onRerunCheck: () => appState.runAiCheck(currentDoc.id),
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(words),
    );
  }

  Widget _buildBody(int words) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.high),
            const SizedBox(height: 12),
            Text(
              _error ?? 'File not available',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadBytes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isPdf) {
      return PdfPreview(
        build: (format) => _bytes!,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        maxPageWidth: 800,
        pdfFileName: widget.document.fileName,
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
}
