import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import '../models/document_page.dart';
import 'database_service_prefs.dart';

/// Ultra-reliable, file-based persistence for Desktop and Mobile platforms.
/// Stores documents, users, sessions, and comparison results directly in the OS
/// application support directory (e.g. %APPDATA% on Windows).
/// Uses atomic file writes with disk flush to prevent data loss on app exit.
class FileDatabaseService {
  static FileDatabaseService? _instance;
  factory FileDatabaseService() => _instance ??= FileDatabaseService._internal();
  FileDatabaseService._internal();

  Map<String, dynamic>? _cache;
  File? _dbFile;
  bool _initialized = false;

  String _hash(String password) =>
      sha256.convert(password.codeUnits).toString();

  Future<File> _resolveDbFile() async {
    if (_dbFile != null) return _dbFile!;
    Directory directory;
    try {
      directory = await getApplicationSupportDirectory();
    } catch (_) {
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (_) {
        directory = Directory.systemTemp;
      }
    }
    final dbDir = Directory(path.join(directory.path, 'plagiarism_checker_data'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    _dbFile = File(path.join(dbDir.path, 'app_database.json'));
    return _dbFile!;
  }

  Future<void> ensureInitialized() async {
    if (_initialized && _cache != null) return;
    final file = await _resolveDbFile();
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _cache = decoded;
          }
        }
      } catch (e) {
        // Try backup file if main file is corrupted
        final bakFile = File('${file.path}.bak');
        if (await bakFile.exists()) {
          try {
            final content = await bakFile.readAsString();
            _cache = jsonDecode(content) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    }

    _cache ??= <String, dynamic>{
      'active_user_id': 'admin',
      'users': <Map<String, dynamic>>[],
      'documents': <Map<String, dynamic>>[],
      'results': <Map<String, dynamic>>[],
      'last_analyzed_at': null,
    };

    // Ensure default admin user always exists
    final users = _getList('users');
    bool modifiedUsers = false;
    final hasAdmin = users.any((u) => u['email'] == 'admin@example.com');
    if (!hasAdmin) {
      users.add({
        'id': 'admin',
        'email': 'admin@example.com',
        'password_hash': _hash('admin123'),
        'role': UserRole.admin.name,
        'display_name': 'Administrator',
        'photo_base64': null,
      });
      modifiedUsers = true;
    }

    final hasStudent1 = users.any((u) => u['email'] == 'student1@example.com');
    if (!hasStudent1) {
      users.add({
        'id': 'student1',
        'email': 'student1@example.com',
        'password_hash': _hash('password123'),
        'role': UserRole.user.name,
        'display_name': 'Student 1',
        'photo_base64': null,
      });
      modifiedUsers = true;
    }

    final hasStudent = users.any((u) => u['email'] == 'student@example.com');
    if (!hasStudent) {
      users.add({
        'id': 'student',
        'email': 'student@example.com',
        'password_hash': _hash('password123'),
        'role': UserRole.user.name,
        'display_name': 'Student',
        'photo_base64': null,
      });
      modifiedUsers = true;
    }

    if (modifiedUsers) {
      _cache!['users'] = users;
    }

    // Check if migration from SharedPreferences is needed (if DB was freshly created)
    if (users.length <= 1 && _getList('documents').isEmpty) {
      await _migrateFromPreferences();
    }

    await _flushToDisk();
    _initialized = true;
  }

  Future<void> _migrateFromPreferences() async {
    try {
      final legacy = DatabaseServicePrefs();
      await legacy.ensureInitialized();
      final legacyUsers = await legacy.getAllUsers();
      final legacyDocs = await legacy.getDocuments();
      final legacyResults = await legacy.getSavedResults();

      if (legacyUsers.isNotEmpty) {
        final users = _getList('users');
        for (final u in legacyUsers) {
          if (!users.any((ex) => ex['id'] == u.id)) {
            users.add({
              'id': u.id,
              'email': u.email,
              'password_hash': _hash(u.id == 'admin' ? 'admin123' : 'password123'),
              'role': u.role.name,
              'display_name': u.displayName,
              'photo_base64': u.photoBase64,
            });
          }
        }
        _cache!['users'] = users;
      }

      if (legacyDocs.isNotEmpty) {
        final docs = _getList('documents');
        for (final doc in legacyDocs) {
          if (!docs.any((ex) => ex['id'] == doc.id)) {
            docs.add(_docToMap(doc));
          }
        }
        _cache!['documents'] = docs;
      }

      if (legacyResults.isNotEmpty) {
        _cache!['results'] = legacyResults.map((r) => r.toMap()).toList();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getList(String key) {
    final list = _cache?[key];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _flushToDisk() async {
    if (_cache == null) return;
    try {
      final file = await _resolveDbFile();
      final jsonString = jsonEncode(_cache);

      // Write to temporary file first for atomic safety
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(jsonString, flush: true);

      // Backup previous version
      if (await file.exists()) {
        try {
          await file.copy('${file.path}.bak');
        } catch (_) {}
      }

      // Atomically replace target file
      await tmpFile.rename(file.path);
    } catch (e) {
      // Direct write fallback
      final file = await _resolveDbFile();
      await file.writeAsString(jsonEncode(_cache), flush: true);
    }
  }

  // --- Session Management ---

  Future<String?> getActiveUserId() async {
    await ensureInitialized();
    return _cache?['active_user_id'] as String?;
  }

  Future<void> setActiveUserId(String? userId) async {
    await ensureInitialized();
    _cache?['active_user_id'] = userId;
    await _flushToDisk();
  }

  // --- Authentication & User Operations ---

  Future<AppUser?> authenticate(String email, String password) async {
    await ensureInitialized();
    final users = _getList('users');
    final normalized = email.trim().toLowerCase();
    final hash = _hash(password);

    final match = users.where(
      (u) => (u['email'] as String).toLowerCase() == normalized && u['password_hash'] == hash,
    );
    if (match.isEmpty) return null;
    final user = AppUser.fromMap(match.first);
    await setActiveUserId(user.id);
    return user;
  }

  Future<AppUser?> getUserById(String id) async {
    await ensureInitialized();
    final users = _getList('users');
    final match = users.where((u) => u['id'] == id);
    return match.isEmpty ? null : AppUser.fromMap(match.first);
  }

  Future<AppUser> register(String email, String password) async {
    await ensureInitialized();
    final users = _getList('users');
    final normalized = email.trim().toLowerCase();

    if (users.any((u) => (u['email'] as String).toLowerCase() == normalized)) {
      throw StateError('An account with this email already exists.');
    }

    final user = AppUser(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      email: normalized,
      role: UserRole.user,
      displayName: normalized.split('@').first,
    );

    users.add({
      ...user.toMap(),
      'password_hash': _hash(password),
    });
    _cache!['users'] = users;
    await setActiveUserId(user.id);
    await _flushToDisk();
    return user;
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await ensureInitialized();
    final users = _getList('users');
    final index = users.indexWhere((u) => u['id'] == userId);
    if (index < 0) throw StateError('User account not found.');

    final user = users[index];
    if (user['password_hash'] != _hash(currentPassword)) {
      throw StateError('Current password is incorrect.');
    }
    if (newPassword.length < 6) {
      throw StateError('New password must be at least 6 characters.');
    }

    users[index]['password_hash'] = _hash(newPassword);
    _cache!['users'] = users;
    await _flushToDisk();
  }

  Future<List<AppUser>> getAllUsers() async {
    await ensureInitialized();
    final users = _getList('users');
    return users.map((u) => AppUser.fromMap(u)).toList();
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await ensureInitialized();
    final users = _getList('users');
    final index = users.indexWhere((u) => u['id'] == userId);
    if (index < 0) throw StateError('User not found.');

    users[index]['role'] = newRole.name;
    _cache!['users'] = users;
    await _flushToDisk();
  }

  Future<void> deleteUser(String userId) async {
    if (userId == 'admin') {
      throw StateError('The primary administrator account cannot be deleted.');
    }
    await ensureInitialized();
    final users = _getList('users');
    users.removeWhere((u) => u['id'] == userId);
    _cache!['users'] = users;

    // Delete documents owned by this user
    final docs = _getList('documents');
    docs.removeWhere((d) => d['owner_id'] == userId);
    _cache!['documents'] = docs;

    if (_cache?['active_user_id'] == userId) {
      _cache?['active_user_id'] = 'admin';
    }

    await _flushToDisk();
  }

  Future<AppUser> updateProfile({
    required String id,
    required String displayName,
    String? photoBase64,
  }) async {
    await ensureInitialized();
    final users = _getList('users');
    final index = users.indexWhere((u) => u['id'] == id);
    if (index < 0) throw StateError('User account was not found.');

    users[index]['display_name'] = displayName.trim();
    if (photoBase64 != null) {
      users[index]['photo_base64'] = photoBase64;
    }
    _cache!['users'] = users;
    await _flushToDisk();
    return AppUser.fromMap(users[index]);
  }

  // --- Document Operations ---

  Map<String, dynamic> _docToMap(AssignmentDocument doc) {
    return {
      'id': doc.id,
      'owner_id': doc.ownerId,
      'file_name': doc.fileName,
      'original_file_path': doc.originalFilePath,
      'original_file_base64': doc.originalFileBase64,
      'raw_text': doc.rawText,
      'cleaned_text': doc.cleanedText,
      'pages': doc.pages.map((p) => p.toMap()).toList(),
      'ai_probability': doc.aiProbability,
      'ai_detection_method': doc.aiDetectionMethod,
      'ai_synthetic_score': doc.aiSyntheticScore,
      'ai_editing_score': doc.aiEditingScore,
      'ai_classification': doc.aiClassification,
      'ai_explanation': doc.aiExplanation,
      'ai_detected_markers': doc.aiDetectedMarkers,
      'ai_burstiness_score': doc.aiBurstinessScore,
      'ai_vocabulary_richness': doc.aiVocabularyRichness,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  Future<List<AssignmentDocument>> getDocuments({String? ownerId}) async {
    await ensureInitialized();
    final rows = _getList('documents');
    final users = _getList('users');

    return rows
        .where((row) => ownerId == null || row['owner_id'] == ownerId)
        .map((row) {
      final userMatch = users.where((u) => u['id'] == row['owner_id']);
      final owner = userMatch.isEmpty ? null : userMatch.first;
      final displayName = owner?['display_name'] as String?;
      final email = owner?['email'] as String?;

      List<DocumentPage> pages = [];
      if (row['pages'] != null) {
        try {
          if (row['pages'] is List) {
            final list = row['pages'] as List<dynamic>;
            pages = list
                .map((p) => DocumentPage.fromMap(Map<String, dynamic>.from(p as Map)))
                .toList();
          } else if (row['pages'] is String) {
            final list = jsonDecode(row['pages'] as String) as List<dynamic>;
            pages = list
                .map((p) => DocumentPage.fromMap(Map<String, dynamic>.from(p as Map)))
                .toList();
          }
        } catch (_) {}
      }

      return AssignmentDocument(
        id: (row['id'] as String?) ?? '${DateTime.now().microsecondsSinceEpoch}',
        ownerId: row['owner_id'] as String?,
        ownerName: (displayName != null && displayName.trim().isNotEmpty)
            ? displayName
            : email,
        fileName: (row['file_name'] as String?) ?? 'Document',
        originalFilePath: row['original_file_path'] as String?,
        originalFileBase64: row['original_file_base64'] as String?,
        rawText: (row['raw_text'] as String?) ?? '',
        cleanedText: (row['cleaned_text'] as String?) ?? (row['raw_text'] as String?) ?? '',
        pages: pages,
        aiProbability: (row['ai_probability'] as num?)?.toDouble(),
        aiDetectionMethod: row['ai_detection_method'] as String?,
        aiSyntheticScore: (row['ai_synthetic_score'] as num?)?.toDouble(),
        aiEditingScore: (row['ai_editing_score'] as num?)?.toDouble(),
        aiClassification: row['ai_classification'] as String?,
        aiExplanation: row['ai_explanation'] as String?,
        aiDetectedMarkers: (row['ai_detected_markers'] as List<dynamic>?)
            ?.map((m) => m.toString())
            .toList(),
        aiBurstinessScore: (row['ai_burstiness_score'] as num?)?.toDouble(),
        aiVocabularyRichness: (row['ai_vocabulary_richness'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<void> saveDocument(AssignmentDocument document) async {
    await ensureInitialized();
    final rows = _getList('documents');

    final clash = rows.any(
      (r) => r['id'] == document.id && r['owner_id'] != document.ownerId,
    );
    if (clash) {
      throw StateError('Document id "${document.id}" already belongs to another user.');
    }

    rows.removeWhere((r) => r['id'] == document.id);
    rows.add(_docToMap(document));
    _cache!['documents'] = rows;
    await _flushToDisk();
  }

  Future<void> deleteDocument(String id) async {
    await ensureInitialized();
    final rows = _getList('documents');
    rows.removeWhere((r) => r['id'] == id);
    _cache!['documents'] = rows;
    await _flushToDisk();
  }

  // --- Comparison Results Operations ---

  Future<void> saveResults(
    List<ComparisonResult> results,
    DateTime? timestamp,
  ) async {
    await ensureInitialized();
    _cache!['results'] = results.map((r) => r.toMap()).toList();
    if (timestamp != null) {
      _cache!['last_analyzed_at'] = timestamp.toIso8601String();
    }
    await _flushToDisk();
  }

  Future<List<ComparisonResult>> getSavedResults() async {
    await ensureInitialized();
    final list = _getList('results');
    return list.map((item) => ComparisonResult.fromMap(item)).toList();
  }

  Future<DateTime?> getSavedResultsTimestamp() async {
    await ensureInitialized();
    final str = _cache?['last_analyzed_at'] as String?;
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // --- Notification Operations ---

  Future<List<AppNotification>> getNotificationsForUser(String userId) async {
    await ensureInitialized();
    final list = _getList('notifications');
    final notifications = list
        .map((item) => AppNotification.fromMap(item))
        .where((n) =>
            n.recipientUserId == userId ||
            (userId == 'admin' && n.recipientUserId == 'admin'))
        .toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<void> saveNotification(AppNotification notification) async {
    await ensureInitialized();
    final rows = _getList('notifications');
    final index = rows.indexWhere((r) => r['id'] == notification.id);
    if (index >= 0) {
      rows[index] = notification.toMap();
    } else {
      rows.add(notification.toMap());
    }
    _cache!['notifications'] = rows;
    await _flushToDisk();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await ensureInitialized();
    final rows = _getList('notifications');
    final index = rows.indexWhere((r) => r['id'] == notificationId);
    if (index >= 0) {
      final updated = AppNotification.fromMap(rows[index]).copyWith(isRead: true);
      rows[index] = updated.toMap();
      _cache!['notifications'] = rows;
      await _flushToDisk();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await ensureInitialized();
    final rows = _getList('notifications');
    rows.removeWhere((r) => r['id'] == notificationId);
    _cache!['notifications'] = rows;
    await _flushToDisk();
  }
}
