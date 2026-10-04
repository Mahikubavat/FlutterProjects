import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../models/comparison_result.dart';
import 'file_database_service.dart';

/// Primary database service for IO platforms (Windows, macOS, Linux, Android, iOS).
/// Backed by FileDatabaseService which performs atomic, persistent JSON storage
/// in the application's secure support directory (%APPDATA% / Documents).
class DatabaseService {
  final FileDatabaseService _engine = FileDatabaseService();

  Future<void> ensureInitialized() => _engine.ensureInitialized();

  Future<String?> getActiveUserId() => _engine.getActiveUserId();

  Future<void> setActiveUserId(String? userId) => _engine.setActiveUserId(userId);

  Future<AppUser?> authenticate(String email, String password) =>
      _engine.authenticate(email, password);

  Future<AppUser?> getUserById(String id) => _engine.getUserById(id);

  Future<AppUser> register(String email, String password) =>
      _engine.register(email, password);

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) =>
      _engine.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<List<AppUser>> getAllUsers() => _engine.getAllUsers();

  Future<void> updateUserRole(String userId, UserRole newRole) =>
      _engine.updateUserRole(userId, newRole);

  Future<void> deleteUser(String userId) => _engine.deleteUser(userId);

  Future<AppUser> updateProfile({
    required String id,
    required String displayName,
    String? photoBase64,
  }) =>
      _engine.updateProfile(
        id: id,
        displayName: displayName,
        photoBase64: photoBase64,
      );

  Future<List<AssignmentDocument>> getDocuments({String? ownerId}) =>
      _engine.getDocuments(ownerId: ownerId);

  Future<void> saveDocument(AssignmentDocument document) =>
      _engine.saveDocument(document);

  Future<void> deleteDocument(String id) => _engine.deleteDocument(id);

  Future<void> saveResults(
    List<ComparisonResult> results,
    DateTime? timestamp,
  ) =>
      _engine.saveResults(results, timestamp);

  Future<List<ComparisonResult>> getSavedResults() =>
      _engine.getSavedResults();

  Future<DateTime?> getSavedResultsTimestamp() async =>
      _engine.getSavedResultsTimestamp();

  Future<List<AppNotification>> getNotificationsForUser(String userId) =>
      _engine.getNotificationsForUser(userId);

  Future<void> saveNotification(AppNotification notification) =>
      _engine.saveNotification(notification);

  Future<void> markNotificationAsRead(String notificationId) =>
      _engine.markNotificationAsRead(notificationId);

  Future<void> deleteNotification(String notificationId) =>
      _engine.deleteNotification(notificationId);
}
