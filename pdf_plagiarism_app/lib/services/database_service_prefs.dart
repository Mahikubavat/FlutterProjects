import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import '../models/document_page.dart';

/// Cross-platform document, user, and comparison persistence backed by SharedPreferences.
/// Works consistently on Windows, macOS, Linux, Web, Android, and iOS.
class DatabaseServicePrefs {
  static const _usersKey = 'plagiarism_users';
  static const _documentsKey = 'plagiarism_documents';
  static const _resultsKey = 'plagiarism_saved_results';
  static const _analyzedAtKey = 'plagiarism_saved_analyzed_at';
  static const _activeUserKey = 'plagiarism_active_user_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _hash(String password) =>
      sha256.convert(password.codeUnits).toString();

  Future<String?> getActiveUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_activeUserKey);
  }

  Future<void> setActiveUserId(String? userId) async {
    final prefs = await _prefs;
    if (userId == null) {
      await prefs.remove(_activeUserKey);
    } else {
      await prefs.setString(_activeUserKey, userId);
    }
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final values = (await _prefs).getStringList(key) ?? [];
    return values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> values) async {
    await (await _prefs).setStringList(key, values.map(jsonEncode).toList());
  }

  Future<void> ensureInitialized() async {
    final users = await _readList(_usersKey);
    bool modifiedUsers = false;

    if (!users.any((user) => user['email'] == 'admin@example.com')) {
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

    if (!users.any((user) => user['email'] == 'student1@example.com')) {
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

    if (!users.any((user) => user['email'] == 'student@example.com')) {
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
      await _writeList(_usersKey, users);
    }
  }

  Future<AppUser?> authenticate(String email, String password) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    final match = users.where(
      (user) =>
          user['email'] == email.trim().toLowerCase() &&
          user['password_hash'] == _hash(password),
    );
    return match.isEmpty ? null : AppUser.fromMap(match.first);
  }

  Future<AppUser?> getUserById(String id) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    final matches = users.where((user) => user['id'] == id);
    return matches.isEmpty ? null : AppUser.fromMap(matches.first);
  }

  Future<AppUser> register(String email, String password) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    final normalized = email.trim().toLowerCase();
    if (users.any((user) => user['email'] == normalized)) {
      throw StateError('An account with this email already exists.');
    }
    final user = AppUser(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      email: normalized,
      role: UserRole.user,
    );
    users.add({...user.toMap(), 'password_hash': _hash(password)});
    await _writeList(_usersKey, users);
    return user;
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
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
    await _writeList(_usersKey, users);
  }

  Future<List<AppUser>> getAllUsers() async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    return users.map((u) => AppUser.fromMap(u)).toList();
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    final index = users.indexWhere((u) => u['id'] == userId);
    if (index < 0) throw StateError('User not found.');
    users[index]['role'] = newRole.name;
    await _writeList(_usersKey, users);
  }

  Future<void> deleteUser(String userId) async {
    if (userId == 'admin') {
      throw StateError('The primary administrator account cannot be deleted.');
    }
    await ensureInitialized();
    final users = await _readList(_usersKey);
    users.removeWhere((u) => u['id'] == userId);
    await _writeList(_usersKey, users);

    // Also delete any documents owned by this user
    final docs = await _readList(_documentsKey);
    docs.removeWhere((d) => d['owner_id'] == userId);
    await _writeList(_documentsKey, docs);
  }

  Future<AppUser> updateProfile({
    required String id,
    required String displayName,
    String? photoBase64,
  }) async {
    await ensureInitialized();
    final users = await _readList(_usersKey);
    final index = users.indexWhere((user) => user['id'] == id);
    if (index < 0) throw StateError('User account was not found.');
    users[index]['display_name'] = displayName.trim();
    users[index]['photo_base64'] = photoBase64;
    await _writeList(_usersKey, users);
    return AppUser.fromMap(users[index]);
  }

  Future<List<AssignmentDocument>> getDocuments({String? ownerId}) async {
    await ensureInitialized();
    final rows = await _readList(_documentsKey);
    final users = await _readList(_usersKey);
    return rows
        .where((row) => ownerId == null || row['owner_id'] == ownerId)
        .map((row) {
      final user = users.where((item) => item['id'] == row['owner_id']);
      final owner = user.isEmpty ? null : user.first;
      final displayName =
          owner == null ? null : owner['display_name'] as String?;

      List<DocumentPage> pages = [];
      if (row['pages'] != null) {
        try {
          if (row['pages'] is String) {
            final list = jsonDecode(row['pages'] as String) as List<dynamic>;
            pages = list
                .map((p) => DocumentPage.fromMap(Map<String, dynamic>.from(p as Map)))
                .toList();
          } else if (row['pages'] is List) {
            pages = (row['pages'] as List)
                .map((p) => DocumentPage.fromMap(Map<String, dynamic>.from(p as Map)))
                .toList();
          }
        } catch (_) {}
      }

      return AssignmentDocument(
        id: (row['id'] as String?) ?? '${DateTime.now().microsecondsSinceEpoch}',
        ownerId: row['owner_id'] as String?,
        ownerName: displayName == null || displayName.trim().isEmpty
            ? owner == null
                ? null
                : owner['email'] as String?
            : displayName,
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
    final rows = await _readList(_documentsKey);
    final clash = rows.any(
      (row) => row['id'] == document.id && row['owner_id'] != document.ownerId,
    );
    if (clash) {
      throw StateError(
        'Document id "${document.id}" already belongs to another user.',
      );
    }
    rows.removeWhere((row) => row['id'] == document.id);
    rows.add({
      'id': document.id,
      'owner_id': document.ownerId,
      'file_name': document.fileName,
      'original_file_path': document.originalFilePath,
      'original_file_base64': document.originalFileBase64,
      'raw_text': document.rawText,
      'cleaned_text': document.cleanedText,
      'pages': jsonEncode(document.pages.map((p) => p.toMap()).toList()),
      'ai_probability': document.aiProbability,
      'ai_detection_method': document.aiDetectionMethod,
      'ai_synthetic_score': document.aiSyntheticScore,
      'ai_editing_score': document.aiEditingScore,
      'ai_classification': document.aiClassification,
      'ai_explanation': document.aiExplanation,
      'ai_detected_markers': document.aiDetectedMarkers,
      'ai_burstiness_score': document.aiBurstinessScore,
      'ai_vocabulary_richness': document.aiVocabularyRichness,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _writeList(_documentsKey, rows);
  }

  Future<void> deleteDocument(String id) async {
    final rows = await _readList(_documentsKey)
      ..removeWhere((row) => row['id'] == id);
    await _writeList(_documentsKey, rows);
  }

  Future<void> saveResults(
    List<ComparisonResult> results,
    DateTime? timestamp,
  ) async {
    final prefs = await _prefs;
    final jsonList = results.map((r) => r.toMap()).toList();
    await prefs.setString(_resultsKey, jsonEncode(jsonList));
    if (timestamp != null) {
      await prefs.setString(_analyzedAtKey, timestamp.toIso8601String());
    }
  }

  Future<List<ComparisonResult>> getSavedResults() async {
    final prefs = await _prefs;
    final str = prefs.getString(_resultsKey);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((item) => ComparisonResult.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> getSavedResultsTimestamp() async {
    final prefs = await _prefs;
    final str = prefs.getString(_analyzedAtKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // --- Notification Operations ---

  static const _notificationsKey = 'plagiarism_notifications';

  Future<List<AppNotification>> getNotificationsForUser(String userId) async {
    final rows = await _readList(_notificationsKey);
    final notifications = rows
        .map((item) => AppNotification.fromMap(item))
        .where((n) =>
            n.recipientUserId == userId ||
            (userId == 'admin' && n.recipientUserId == 'admin'))
        .toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<void> saveNotification(AppNotification notification) async {
    final rows = await _readList(_notificationsKey);
    final index = rows.indexWhere((r) => r['id'] == notification.id);
    if (index >= 0) {
      rows[index] = notification.toMap();
    } else {
      rows.add(notification.toMap());
    }
    await _writeList(_notificationsKey, rows);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final rows = await _readList(_notificationsKey);
    final index = rows.indexWhere((r) => r['id'] == notificationId);
    if (index >= 0) {
      final updated = AppNotification.fromMap(rows[index]).copyWith(isRead: true);
      rows[index] = updated.toMap();
      await _writeList(_notificationsKey, rows);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final rows = await _readList(_notificationsKey)
      ..removeWhere((r) => r['id'] == notificationId);
    await _writeList(_notificationsKey, rows);
  }
}
