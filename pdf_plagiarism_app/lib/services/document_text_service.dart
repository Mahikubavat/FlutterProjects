import 'dart:typed_data';
import 'dart:async';

import '../models/document_extraction.dart';
import '../models/document_page.dart';
import 'image_preprocessing_service.dart';
import 'ocr_service.dart';
import 'pdf_service.dart';
import 'vision_ocr_service.dart';

class DocumentTextService {
  static const extractionTimeout = Duration(minutes: 5);

  static Future<DocumentExtraction> extract({
    required String fileName,
    required Uint8List bytes,
    required VisionOcrService visionOcr,
    void Function(double progress, String message)? onProgress,
  }) async {
    // PlatformFile exposes bytes rather than a seekable stream. Reusing this
    // immutable buffer gives each extractor the equivalent of seek(0).
    final input = Uint8List.fromList(bytes);
    return _extractUnbounded(
      fileName: fileName,
      bytes: input,
      visionOcr: visionOcr,
      onProgress: onProgress,
    ).timeout(extractionTimeout);
  }

  static Future<DocumentExtraction> _extractUnbounded({
    required String fileName,
    required Uint8List bytes,
    required VisionOcrService visionOcr,
    void Function(double progress, String message)? onProgress,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      final pages = await PdfService.extractPages(
        bytes,
        printedRecognizer: OcrService.recognizeImage,
        handwritingRecognizer:
            visionOcr.isConfigured ? visionOcr.recognizeHandwriting : null,
        onProgress: (page, total, message) =>
            onProgress?.call(page / total, message),
      );
      return _resultFromPages(pages);
    }

    if (!{'jpg', 'jpeg', 'png', 'webp', 'bmp'}.contains(extension)) {
      throw UnsupportedError('Unsupported document type: .$extension');
    }

    final prepared = await ImagePreprocessingService.prepareAsync(bytes);
    onProgress?.call(0.35, 'Preprocessing image');
    final printedText = await OcrService.recognizeImage(prepared);
    onProgress?.call(0.8, 'Recognizing image text');
    var rawText = printedText;
    if (!OcrService.isLowConfidence(printedText) || !visionOcr.isConfigured) {
      return _resultFromPages([_page(1, rawText, 'printed OCR')]);
    }

    final handwritingText = await visionOcr.recognizeHandwriting(prepared);
    onProgress?.call(1, 'Finished handwriting recognition');
    if (handwritingText != null && handwritingText.trim().isNotEmpty) {
      rawText = handwritingText;
      return _resultFromPages([_page(1, rawText, 'handwriting OCR')]);
    }
    return _resultFromPages([_page(1, rawText, 'printed OCR')]);
  }

  static DocumentExtraction _resultFromPages(List<DocumentPage> pages) {
    // Only pages that produced text count. Otherwise a fully failed file would
    // still contain "Page 1" and be saved as if extraction had worked.
    final withText = pages.where((page) => page.cleanedText.isNotEmpty);
    final raw = withText
        .map((page) => 'Page ${page.pageNumber}\n${page.rawText}')
        .join('\n\n');
    final cleaned = withText
        .map((page) => 'Page ${page.pageNumber}\n${page.cleanedText}')
        .join('\n\n');
    final errors = pages
        .where((page) => page.error != null)
        .map((page) => page.error!)
        .toList(growable: false);
    return DocumentExtraction(
      rawText: raw.trim(),
      cleanedText: cleaned.trim(),
      pages: pages,
      errors: errors,
    );
  }

  static DocumentPage _page(int pageNumber, String text, String source) =>
      DocumentPage(
        pageNumber: pageNumber,
        rawText: text,
        cleanedText: PdfService.normalizeText(text),
        source: source,
      );
}
