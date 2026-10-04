import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import '../services/ai_detection_service.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/llm_similarity_service.dart';
import '../services/similarity_service.dart';

/// Central app state: the uploaded documents and the latest analysis
/// results. Kept deliberately simple (ChangeNotifier + Provider).
class AppState extends ChangeNotifier {
  final DatabaseService database = DatabaseService();
  final FileStorageService fileStorage = FileStorageService();
  final List<AssignmentDocument> documents = [];
  final Set<String> selectedDocumentIds = <String>{};
  final List<AppNotification> notifications = [];
  List<ComparisonResult> results = [];
  AppUser? currentUser;
  bool isInitializing = true;
  String? authError;
  bool isProcessing = false;
  String processingMessage = '';
  double processingProgress = 0;
  DateTime? lastAnalyzedAt;

  final LlmSimilarityService llmService = LlmSimilarityService(
    apiKey: const String.fromEnvironment('LLM_API_KEY'),
  );
  final AiDetectionService aiDetectionService = AiDetectionService(
    apiKey: const String.fromEnvironment(
      'AI_DETECTION_API_KEY',
      defaultValue: String.fromEnvironment('LLM_API_KEY'),
    ),
  );

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.role == UserRole.admin;

  Future<void> initialize() async {
    await database.ensureInitialized();
    String? userId = await database.getActiveUserId();
    if (userId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('plagiarism_current_user_id');
      } catch (_) {}
    }
    if (userId != null) {
      currentUser = await database.getUserById(userId);
      if (currentUser != null) {
        await _loadDocuments();
        await _loadSavedResults();
      }
    }
    isInitializing = false;
    notifyListeners();
  }

  Future<void> _loadSavedResults() async {
    try {
      results = await database.getSavedResults();
      lastAnalyzedAt = await database.getSavedResultsTimestamp();
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    authError = null;
    try {
      final normalized = email.trim().toLowerCase();
      var user = await database.authenticate(normalized, password);

      // Auto-provision demo accounts if somehow missing from database
      if (user == null) {
        if (normalized == 'student1@example.com' && password == 'password123') {
          try {
            user = await database.register('student1@example.com', 'password123');
            await database.updateProfile(id: user.id, displayName: 'Student 1');
          } catch (_) {
            user = await database.authenticate(normalized, password);
          }
        } else if (normalized == 'student@example.com' && password == 'password123') {
          try {
            user = await database.register('student@example.com', 'password123');
            await database.updateProfile(id: user.id, displayName: 'Student');
          } catch (_) {
            user = await database.authenticate(normalized, password);
          }
        } else if (normalized == 'admin@example.com' && password == 'admin123') {
          await database.ensureInitialized();
          user = await database.authenticate(normalized, password);
        }
      }

      if (user == null) {
        authError = 'Invalid email or password.';
        notifyListeners();
        return false;
      }
      currentUser = user;
      await database.setActiveUserId(user.id);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('plagiarism_current_user_id', user.id);
      } catch (_) {}
      await _loadDocuments();
      await _loadSavedResults();
      notifyListeners();
      return true;
    } catch (error) {
      authError = error.toString().replaceFirst('StateError: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    authError = null;
    try {
      currentUser = await database.register(email, password);
      await database.setActiveUserId(currentUser!.id);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('plagiarism_current_user_id', currentUser!.id);
      } catch (_) {}
      await _loadDocuments();
      await _loadSavedResults();
      notifyListeners();
      return true;
    } catch (error) {
      authError = error.toString().replaceFirst('StateError: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({
    required String displayName,
    String? photoBase64,
  }) async {
    if (currentUser == null) return;
    currentUser = await database.updateProfile(
      id: currentUser!.id,
      displayName: displayName,
      photoBase64: photoBase64,
    );
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser == null) return;
    await database.changePassword(
      userId: currentUser!.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<List<AppUser>> getAllUsers() async {
    return await database.getAllUsers();
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await database.updateUserRole(userId, newRole);
    if (currentUser?.id == userId) {
      currentUser = await database.getUserById(userId);
    }
    notifyListeners();
  }

  Future<void> deleteUser(String userId) async {
    await database.deleteUser(userId);
    await _loadDocuments();
    notifyListeners();
  }

  void logout() {
    database.setActiveUserId(null);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove('plagiarism_current_user_id'),
    );
    currentUser = null;
    documents.clear();
    results = [];
    selectedDocumentIds.clear();
    notifications.clear();
    notifyListeners();
  }

  List<AppNotification> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();

  Future<void> loadNotifications() async {
    if (currentUser == null) {
      notifications.clear();
      return;
    }
    try {
      final loaded = await database.getNotificationsForUser(currentUser!.id);
      notifications
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      await database.markNotificationAsRead(id);
      final index = notifications.indexWhere((n) => n.id == id);
      if (index >= 0) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> dismissNotification(String id) async {
    try {
      await database.deleteNotification(id);
      notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendReuploadRequest({
    required String studentId,
    required String studentName,
    required String documentId,
    required String documentName,
    String? assignmentTag,
    String? reason,
  }) async {
    final notif = AppNotification(
      id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
      recipientUserId: studentId,
      senderUserId: currentUser?.id ?? 'admin',
      senderName: currentUser?.displayName ?? 'Instructor',
      title: 'Re-upload Requested: ${assignmentTag ?? documentName}',
      message: reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : 'Instructor has requested a revised submission for "$documentName". Please re-upload your document.',
      documentId: documentId,
      documentName: documentName,
      assignmentTag: assignmentTag,
      type: NotificationType.reuploadRequested,
      createdAt: DateTime.now(),
    );
    await database.saveNotification(notif);
    await loadNotifications();
  }

  String _ownedId(String id) => '${currentUser!.id}-$id';

  Future<void> _loadDocuments() async {
    documents
      ..clear()
      ..addAll(
        await database.getDocuments(ownerId: isAdmin ? null : currentUser!.id),
      );
    selectedDocumentIds.clear();
    await loadNotifications();
  }

  bool isDocumentSelected(String id) => selectedDocumentIds.contains(id);

  void toggleDocumentSelection(String id) {
    if (selectedDocumentIds.contains(id)) {
      selectedDocumentIds.remove(id);
    } else {
      selectedDocumentIds.add(id);
    }
    notifyListeners();
  }

  void clearDocumentSelection() {
    selectedDocumentIds.clear();
    notifyListeners();
  }

  Future<void> addDocument(
    AssignmentDocument doc, {
    List<int>? originalBytes,
  }) async {
    final ownedId = _ownedId(doc.id);
    String? originalFilePath;
    if (originalBytes != null) {
      originalFilePath = await fileStorage.save(
        documentId: ownedId,
        fileName: doc.fileName,
        bytes: originalBytes,
      );
    }
    // Only store base64 if originalFilePath is null (e.g. web fallback without filesystem)
    final originalFileBase64 = (originalFilePath == null && originalBytes != null)
        ? base64Encode(originalBytes)
        : null;

    // Pre-screen document for AI dual-layer signals so results are ready immediately
    AiDetectionResult? ai;
    final textForAi = doc.cleanedText.isNotEmpty ? doc.cleanedText : doc.rawText;
    if (doc.aiClassification == null && textForAi.trim().isNotEmpty) {
      try {
        ai = await aiDetectionService.detect(textForAi);
      } catch (_) {}
    }

    final ownedDocument = AssignmentDocument(
      id: ownedId,
      ownerId: currentUser!.id,
      ownerName: currentUser!.displayName,
      fileName: doc.fileName,
      originalFilePath: originalFilePath,
      originalFileBase64: originalFileBase64,
      rawText: doc.rawText,
      cleanedText: doc.cleanedText,
      pages: doc.pages,
      aiProbability: doc.aiProbability ?? ai?.probability,
      aiDetectionMethod: doc.aiDetectionMethod ?? ai?.method,
      aiSyntheticScore: doc.aiSyntheticScore ?? ai?.syntheticScore,
      aiEditingScore: doc.aiEditingScore ?? ai?.editingScore,
      aiClassification: doc.aiClassification ?? ai?.classification.id,
      aiExplanation: doc.aiExplanation ?? ai?.explanation,
      aiDetectedMarkers: doc.aiDetectedMarkers.isNotEmpty ? doc.aiDetectedMarkers : (ai?.detectedMarkers ?? const []),
      aiBurstinessScore: doc.aiBurstinessScore ?? ai?.burstinessScore,
      aiVocabularyRichness: doc.aiVocabularyRichness ?? ai?.vocabularyRichness,
    );
    try {
      await database.saveDocument(ownedDocument);
      final existingIndex = documents.indexWhere((d) => d.id == ownedId);
      if (existingIndex >= 0) {
        documents[existingIndex] = ownedDocument;
      } else {
        documents.add(ownedDocument);
      }

      // Check if student was requested to re-upload this document/tag
      if (currentUser != null && !isAdmin) {
        final pendingNotif = notifications.firstWhere(
          (n) =>
              !n.isRead &&
              n.type == NotificationType.reuploadRequested &&
              (n.documentName?.toLowerCase() == doc.fileName.toLowerCase() ||
                  (n.assignmentTag != null &&
                      doc.fileName
                          .toLowerCase()
                          .contains(n.assignmentTag!.toLowerCase()))),
          orElse: () => AppNotification(
            id: '',
            recipientUserId: '',
            senderUserId: '',
            title: '',
            message: '',
            type: NotificationType.generalInfo,
            createdAt: DateTime.now(),
          ),
        );

        if (pendingNotif.id.isNotEmpty) {
          await markNotificationAsRead(pendingNotif.id);
        }

        // Notify Administrator that student has re-uploaded/submitted
        final adminNotif = AppNotification(
          id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
          recipientUserId: 'admin',
          senderUserId: currentUser!.id,
          senderName: currentUser!.displayName,
          title: 'Document Re-uploaded by Student',
          message:
              '${currentUser!.displayName} (${currentUser!.email}) has re-uploaded document: "${doc.fileName}"',
          documentId: ownedId,
          documentName: doc.fileName,
          assignmentTag: pendingNotif.assignmentTag,
          type: NotificationType.reuploadCompleted,
          createdAt: DateTime.now(),
        );
        await database.saveNotification(adminNotif);
      }
    } catch (_) {
      await fileStorage.delete(originalFilePath);
      rethrow;
    }
    notifyListeners();
  }

  Future<AssignmentDocument?> runAiCheck(String documentId) async {
    final index = documents.indexWhere((document) => document.id == documentId);
    if (index < 0 || isProcessing) return null;
    isProcessing = true;
    processingMessage = 'Checking AI writing signals';
    notifyListeners();
    try {
      final document = documents[index];
      final textToScreen = document.cleanedText.isNotEmpty ? document.cleanedText : document.rawText;
      final ai = await aiDetectionService.detect(textToScreen);
      final updated = AssignmentDocument(
        id: document.id,
        ownerId: document.ownerId,
        ownerName: document.ownerName,
        fileName: document.fileName,
        originalFilePath: document.originalFilePath,
        originalFileBase64: document.originalFileBase64,
        rawText: document.rawText,
        cleanedText: document.cleanedText,
        pages: document.pages,
        aiProbability: ai.probability,
        aiDetectionMethod: ai.method,
        aiSyntheticScore: ai.syntheticScore,
        aiEditingScore: ai.editingScore,
        aiClassification: ai.classification.id,
        aiExplanation: ai.explanation,
        aiDetectedMarkers: ai.detectedMarkers,
        aiBurstinessScore: ai.burstinessScore,
        aiVocabularyRichness: ai.vocabularyRichness,
      );
      await database.saveDocument(updated);
      documents[index] = updated;
      return updated;
    } finally {
      isProcessing = false;
      processingMessage = '';
      notifyListeners();
    }
  }

  Future<void> removeDocument(String id) async {
    final document = documents.where((item) => item.id == id).firstOrNull;
    documents.removeWhere((d) => d.id == id);
    selectedDocumentIds.remove(id);
    await database.deleteDocument(id);
    await fileStorage.delete(document?.originalFilePath);
    notifyListeners();
  }

  Future<void> loadSampleDocuments(List<AssignmentDocument> samples) async {
    for (final sample in samples) {
      final textForAi = sample.cleanedText.isNotEmpty ? sample.cleanedText : sample.rawText;
      AiDetectionResult? ai;
      if (sample.aiClassification == null && textForAi.trim().isNotEmpty) {
        try {
          ai = await aiDetectionService.detect(textForAi);
        } catch (_) {}
      }

      await database.saveDocument(
        AssignmentDocument(
          id: _ownedId(sample.id),
          ownerId: currentUser!.id,
          fileName: sample.fileName,
          rawText: sample.rawText,
          cleanedText: sample.cleanedText,
          pages: sample.pages,
          aiProbability: sample.aiProbability ?? ai?.probability,
          aiDetectionMethod: sample.aiDetectionMethod ?? ai?.method,
          aiSyntheticScore: sample.aiSyntheticScore ?? ai?.syntheticScore,
          aiEditingScore: sample.aiEditingScore ?? ai?.editingScore,
          aiClassification: sample.aiClassification ?? ai?.classification.id,
          aiExplanation: sample.aiExplanation ?? ai?.explanation,
          aiDetectedMarkers: sample.aiDetectedMarkers.isNotEmpty ? sample.aiDetectedMarkers : (ai?.detectedMarkers ?? const []),
          aiBurstinessScore: sample.aiBurstinessScore ?? ai?.burstinessScore,
          aiVocabularyRichness: sample.aiVocabularyRichness ?? ai?.vocabularyRichness,
        ),
      );
    }
    await _loadDocuments();
    notifyListeners();
  }

  Future<void> runAnalysis() async {
    isProcessing = true;
    processingMessage = 'Comparing documents';
    processingProgress = 0;
    notifyListeners();

    final comparisonDocuments = selectedDocumentIds.isEmpty
        ? documents
        : documents
            .where((doc) => selectedDocumentIds.contains(doc.id))
            .toList();
    results = await SimilarityService.compareAllAsync(comparisonDocuments);
    if (llmService.isConfigured) {
      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        try {
          final docA = documentById(result.docAId);
          final docB = documentById(result.docBId);
          if (docA != null && docB != null) {
            final score = await llmService.compare(docA.rawText, docB.rawText);
            if (score != null) results[i] = result.withSemanticSimilarity(score);
          }
        } catch (_) {}
      }
      results.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    }
    lastAnalyzedAt = DateTime.now();

    // Persist results across app restarts
    await database.saveResults(results, lastAnalyzedAt);

    isProcessing = false;
    processingProgress = 1;
    processingMessage = '';
    notifyListeners();
  }

  /// Sets analysis results, saves them persistently, and notifies all UI screens
  Future<void> setResults(List<ComparisonResult> newResults, [DateTime? timestamp]) async {
    final time = timestamp ?? DateTime.now();
    await database.saveResults(newResults, time);
    results = List<ComparisonResult>.from(newResults);
    lastAnalyzedAt = time;
    notifyListeners();
  }

  /// Re-syncs latest saved comparisons from persistent database storage
  Future<void> reloadSavedResults() async {
    try {
      final saved = await database.getSavedResults();
      if (saved.isNotEmpty) {
        results = saved;
        lastAnalyzedAt = await database.getSavedResultsTimestamp() ?? DateTime.now();
        notifyListeners();
      }
    } catch (_) {}
  }

  AssignmentDocument? documentById(String id) {
    for (final d in documents) {
      if (d.id == id ||
          d.fileName == id ||
          d.ownerId == id ||
          (d.ownerName != null && d.ownerName == id)) {
        return d;
      }
    }
    return null;
  }

  /// Retrieves the binary bytes of an uploaded PDF or image so it can be viewed.
  /// Falls back to synthesizing a printable PDF for text-only sample documents.
  Future<Uint8List?> getDocumentBytes(AssignmentDocument document) async {
    // 1. Try local file path (Desktop / Mobile)
    if (document.originalFilePath != null) {
      final bytes = await fileStorage.readBytes(document.originalFilePath);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    // 2. Try base64 payload
    if (document.originalFileBase64 != null &&
        document.originalFileBase64!.isNotEmpty) {
      try {
        return base64Decode(document.originalFileBase64!);
      } catch (_) {}
    }

    // 3. Fallback: Synthesize clean PDF document
    return await _generateDocumentPdf(document);
  }

  Future<Uint8List> _generateDocumentPdf(AssignmentDocument document) async {
    final pdf = pw.Document();
    final text = document.rawText.isNotEmpty
        ? document.rawText
        : document.cleanedText;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Header(
            level: 0,
            text: document.fileName,
          ),
          pw.Text(
            'Author: ${document.ownerName ?? 'Student assignment'}',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
          ),
        ],
      ),
    );
    return await pdf.save();
  }
}
