import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class FileStorageService {
  static const _keyPrefix = 'plagiarism_original_file_';

  Future<String> save({
    required String documentId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final key = '$_keyPrefix$documentId';
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'file_name': fileName,
      'bytes_base64': base64Encode(bytes),
    });
    final saved = await prefs.setString(key, payload);
    if (!saved) throw StateError('The browser could not save the uploaded file.');
    return key;
  }

  Future<Uint8List?> readBytes(String? filePath) async {
    if (filePath == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(filePath);
    if (data == null) return null;
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final b64 = decoded['bytes_base64'] as String?;
      return b64 == null ? null : base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String? filePath) async {
    if (filePath == null || !filePath.startsWith(_keyPrefix)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(filePath);
  }
}