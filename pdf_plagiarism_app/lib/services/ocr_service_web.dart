import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

Future<String> recognizeImage(Uint8List imageBytes) {
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
  return FlutterTesseractOcr.extractText(
    dataUrl,
    language: 'eng',
    args: {'preserve_interword_spaces': '1'},
  );
}
