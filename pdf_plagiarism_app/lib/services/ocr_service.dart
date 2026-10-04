import 'dart:typed_data';

import 'ocr_service_io.dart' if (dart.library.js_interop) 'ocr_service_web.dart'
    as platform;

class OcrService {
  static Future<String> recognizeImage(Uint8List imageBytes) {
    return platform.recognizeImage(imageBytes);
  }

  static bool isLowConfidence(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return true;
    final words = RegExp(r"[A-Za-z0-9']+").allMatches(normalized).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(normalized).length;
    return words < 8 || letters < 40;
  }
}
