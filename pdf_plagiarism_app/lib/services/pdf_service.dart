import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/document_page.dart';
import 'ocr_service.dart';
import 'image_preprocessing_service.dart';

/// Handles turning an uploaded PDF's bytes into plain text.
///
/// The PDF text layer is used as a base, then every page is rendered and OCR
/// is used to add text found only inside images or tables.
class PdfService {
  static Future<List<DocumentPage>> extractPages(
    Uint8List bytes, {
    required Future<String> Function(Uint8List imageBytes) printedRecognizer,
    Future<String?> Function(Uint8List imageBytes)? handwritingRecognizer,
    void Function(int page, int total, String message)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('The PDF is empty.');
    }

    // Step 1: open the text layer. Failures are remembered (not swallowed) so
    // they can be shown to the user if OCR then fails as well.
    PdfDocument? selectableDocument;
    PdfTextExtractor? extractor;
    String? textLayerError;
    var pageCount = 0;
    try {
      selectableDocument = PdfDocument(inputBytes: bytes);
      pageCount = selectableDocument.pages.count;
      if (pageCount > 0) {
        extractor = PdfTextExtractor(selectableDocument);
      }
    } catch (error) {
      textLayerError = 'PDF text layer could not be read ($error)';
    }

    final hasImages = _pdfContainsImages(bytes);

    // The renderer (pdfx) is opened lazily, only when a page needs OCR.
    pdfx.PdfDocument? renderedPdf;
    try {
      if (pageCount < 1) {
        // Syncfusion could not give us a page count, so ask the renderer.
        renderedPdf = await _openRenderer(bytes);
        pageCount = renderedPdf.pagesCount;
      }
      if (pageCount < 1) {
        throw const FormatException('The PDF contains no pages.');
      }

      final pages = <DocumentPage>[];
      for (var index = 0; index < pageCount; index++) {
        final pageNumber = index + 1;
        onProgress?.call(
            pageNumber, pageCount, 'Processing page $pageNumber of $pageCount');

        // Syncfusion uses a zero-based inclusive page range.
        String? embedded;
        if (extractor != null) {
          try {
            embedded = _extractPageText(extractor, index);
          } catch (error) {
            textLayerError ??=
                'text extraction failed on page $pageNumber ($error)';
          }
        }

        // If the document has no embedded images/tables and has clear selectable text,
        // we can safely use the fast text layer directly.
        if (!hasImages && _hasUsableText(embedded ?? '')) {
          pages.add(DocumentPage(
            pageNumber: pageNumber,
            rawText: embedded!,
            cleanedText: normalizeText(embedded),
            source: 'selectable text',
          ));
          continue;
        }

        // Render pages with images, tables, or without usable selectable text for OCR.
        try {
          final renderer = renderedPdf ?? await _openRenderer(bytes);
          renderedPdf = renderer;

          // pdfx uses one-based page numbers.
          final page = await renderer.getPage(pageNumber);
          try {
            if (page.width <= 0 || page.height <= 0) {
              throw StateError('Page has invalid dimensions.');
            }
            final image = await page.render(
              width: page.width * 2,
              height: page.height * 2,
              format: pdfx.PdfPageImageFormat.jpeg,
              backgroundColor: '#FFFFFF',
            );
            if (image == null || image.bytes.isEmpty) {
              throw StateError('Page did not render an image.');
            }
            final prepared =
                await ImagePreprocessingService.prepareAsync(image.bytes);
            final printed = await printedRecognizer(prepared);
            var raw = printed;
            var source = 'printed OCR';
            if (handwritingRecognizer != null &&
                OcrService.isLowConfidence(printed)) {
              final handwriting = await handwritingRecognizer(prepared);
              if (handwriting != null && handwriting.trim().isNotEmpty) {
                raw = handwriting;
                source = 'handwriting OCR';
              }
            }
            if (raw.trim().isEmpty && !_hasSelectableText(embedded ?? '')) {
              throw StateError('OCR returned no text.');
            }
            final combined = _mergeVisualText(embedded, raw);
            pages.add(DocumentPage(
              pageNumber: pageNumber,
              rawText: combined,
              cleanedText: normalizeText(combined),
              source: embedded != null && _hasSelectableText(embedded)
                  ? '$source + selectable text'
                  : source,
            ));
          } finally {
            await page.close();
          }
        } catch (error) {
          // Say why the text layer was unusable AND why OCR failed, so the
          // real cause (e.g. missing Tesseract data) is not hidden.
          final layerNote = textLayerError ?? 'page has no selectable text';
          final message =
              'Page $pageNumber failed: $layerNote; OCR fallback error: $error';
          onProgress?.call(pageNumber, pageCount, '$message Continuing.');
          if (_hasSelectableText(embedded ?? '')) {
            pages.add(DocumentPage(
              pageNumber: pageNumber,
              rawText: embedded!,
              cleanedText: normalizeText(embedded),
              source: 'selectable text',
              error: message,
            ));
          } else {
            pages.add(DocumentPage(
              pageNumber: pageNumber,
              rawText: '',
              cleanedText: '',
              source: 'failed',
              error: message,
            ));
          }
        }
      }
      return pages;
    } finally {
      await renderedPdf?.close();
      selectableDocument?.dispose();
    }
  }

  /// Reads one page's text layer as readable lines and paragraphs.
  ///
  /// The plain `extractText` returns text in the order the PDF producer wrote
  /// it. For many exports (Google Docs, Word, slides) every word is written as
  /// its own object, which comes out as one word per line. Instead, take each
  /// word together with its position on the page and rebuild the lines.
  static String _extractPageText(PdfTextExtractor extractor, int index) {
    try {
      final lines = extractor.extractTextLines(
        startPageIndex: index,
        endPageIndex: index,
      );
      final rebuilt = _rebuildLayout(lines);
      if (_hasSelectableText(rebuilt)) return rebuilt;
    } catch (_) {
      // Fall back to the plain extractor below.
    }
    return extractor.extractText(startPageIndex: index, endPageIndex: index);
  }

  static String _rebuildLayout(List<TextLine> lines) {
    final words = <_PdfWord>[];
    for (final line in lines) {
      if (line.wordCollection.isEmpty) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          final b = line.bounds;
          words.add(_PdfWord(text, b.left, b.top, b.bottom));
        }
        continue;
      }
      for (final word in line.wordCollection) {
        final text = word.text.trim();
        if (text.isEmpty) continue;
        final b = word.bounds;
        words.add(_PdfWord(text, b.left, b.top, b.bottom));
      }
    }
    if (words.isEmpty) return '';

    // Top to bottom, then left to right.
    words.sort((a, b) {
      final byHeight = a.centerY.compareTo(b.centerY);
      return byHeight != 0 ? byHeight : a.left.compareTo(b.left);
    });

    // Group words that sit on the same horizontal line into rows.
    final rows = <List<_PdfWord>>[];
    final rowCenters = <double>[];
    final rowHeights = <double>[];
    for (final word in words) {
      final height = word.height > 0 ? word.height : 1.0;
      if (rows.isNotEmpty) {
        final last = rows.length - 1;
        final tolerance = 0.5 * math.min(height, rowHeights[last]);
        if ((word.centerY - rowCenters[last]).abs() <= tolerance) {
          final count = rows[last].length;
          rows[last].add(word);
          rowCenters[last] =
              (rowCenters[last] * count + word.centerY) / (count + 1);
          rowHeights[last] = math.max(rowHeights[last], height);
          continue;
        }
      }
      rows.add([word]);
      rowCenters.add(word.centerY);
      rowHeights.add(height);
    }

    // Line spacing inside a paragraph is the small, common gap between rows.
    // A low percentile finds it even when paragraph gaps are frequent.
    final pitches = <double>[];
    for (var i = 1; i < rows.length; i++) {
      final pitch = rowCenters[i] - rowCenters[i - 1];
      if (pitch > 0) pitches.add(pitch);
    }
    pitches.sort();
    final typicalPitch = pitches.isEmpty ? 0.0 : pitches[pitches.length ~/ 4];

    final buffer = StringBuffer();
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        final gap = rowCenters[i] - rowCenters[i - 1];
        final newParagraph = typicalPitch > 0 && gap > typicalPitch * 1.4;
        buffer.write(newParagraph ? '\n\n' : '\n');
      }
      final row = rows[i]..sort((a, b) => a.left.compareTo(b.left));
      final rowBuffer = StringBuffer();
      for (var w = 0; w < row.length; w++) {
        if (w > 0) {
          final prevWord = row[w - 1];
          final prevRight = prevWord.left + (prevWord.text.length * 6.5);
          final hGap = row[w].left - prevRight;
          if (hGap > 18.0) {
            rowBuffer.write(' | ');
          } else {
            rowBuffer.write(' ');
          }
        }
        rowBuffer.write(row[w].text);
      }
      buffer.write(rowBuffer.toString());
    }
    return buffer.toString();
  }

  static Future<pdfx.PdfDocument> _openRenderer(Uint8List bytes) async {
    try {
      return await pdfx.PdfDocument.openData(bytes);
    } catch (error) {
      throw FormatException('Unable to open PDF for rendering: $error');
    }
  }

  static String normalizeText(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _mergeVisualText(String? embedded, String ocr) {
    final selectable = normalizeText(embedded ?? '');
    final visual = normalizeText(ocr);
    if (selectable.isEmpty) return visual;
    if (visual.isEmpty) return selectable;

    final selectableWords = RegExp(r"[\p{L}\p{N}']+", unicode: true)
        .allMatches(selectable.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();
    final visualWords = RegExp(r"[\p{L}\p{N}']+", unicode: true)
        .allMatches(visual.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();
    final newWords = visualWords.difference(selectableWords);
    final overlap = visualWords.isEmpty
        ? 1.0
        : visualWords.intersection(selectableWords).length / visualWords.length;
    if (newWords.length < 3 || overlap >= 0.8) return selectable;
    return '$selectable\n\n[Visual content]\n$visual';
  }

  /// True when the page's text layer holds real text. Counts letters from any
  /// script (Gujarati, Hindi, Arabic, ...), not only A-Z.
  static bool _hasSelectableText(String text) {
    final normalized = text.trim();
    return normalized.isNotEmpty &&
        RegExp(r'\p{L}', unicode: true).allMatches(normalized).length >= 3;
  }

  static bool _hasUsableText(String text) {
    final normalized = text.trim();
    if (!_hasSelectableText(normalized)) return false;
    return normalized.length >= 40;
  }

  static bool _pdfContainsImages(Uint8List bytes) {
    // Fast byte scan for ASCII "/Image" in PDF stream
    final target = [0x2F, 0x49, 0x6D, 0x61, 0x67, 0x65]; // /Image
    final len = bytes.length;
    final tLen = target.length;
    for (var i = 0; i <= len - tLen; i++) {
      var match = true;
      for (var j = 0; j < tLen; j++) {
        if (bytes[i + j] != target[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}

/// One word from a PDF page with the position needed to rebuild lines.
class _PdfWord {
  final String text;
  final double left;
  final double top;
  final double bottom;

  const _PdfWord(this.text, this.left, this.top, this.bottom);

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}
