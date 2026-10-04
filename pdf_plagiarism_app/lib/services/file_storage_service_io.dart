import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  Future<String> save({
    required String documentId,
    required String fileName,
    required List<int> bytes,
  }) async {
    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      try {
        directory = await getApplicationSupportDirectory();
      } catch (_) {
        directory = Directory.systemTemp;
      }
    }
    final filesDirectory = Directory(path.join(directory.path, 'documents'));
    await filesDirectory.create(recursive: true);
    final safeName = path.basename(fileName).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File(path.join(filesDirectory.path, '$documentId-$safeName'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List?> readBytes(String? filePath) async {
    if (filePath == null) return null;
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> delete(String? filePath) async {
    if (filePath == null) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}