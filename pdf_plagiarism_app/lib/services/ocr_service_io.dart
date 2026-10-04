import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';

Future<String> recognizeImage(Uint8List imageBytes) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Tesseract native plugin is compiled for Android/iOS/Web, but not bundled
    // for desktop C++. Return empty string so fallback to vision model or selectable
    // text layer can proceed without crashing.
    return '';
  }
  final directory = await getTemporaryDirectory();
  final file = File(
      '${directory.path}/plagiarism_page_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await file.writeAsBytes(imageBytes, flush: true);
  try {
    return await FlutterTesseractOcr.extractText(
      file.path,
      language: 'eng',
      args: {'preserve_interword_spaces': '1'},
    );
  } on MissingPluginException {
    return '';
  } catch (_) {
    return '';
  } finally {
    await file.delete().catchError((_) => file);
  }
}
