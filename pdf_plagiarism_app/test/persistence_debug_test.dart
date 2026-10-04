import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/services/database_service_prefs.dart';

void main() {
  test('Test DatabaseServicePrefs persistence across restart simulation', () async {
    SharedPreferences.setMockInitialValues({});

    final db = DatabaseServicePrefs();
    await db.ensureInitialized();

    // 1. Check default admin and student accounts exist
    final admin = await db.getUserById('admin');
    expect(admin, isNotNull);
    expect(admin!.email, 'admin@example.com');

    final student1 = await db.authenticate('student1@example.com', 'password123');
    expect(student1, isNotNull);
    expect(student1!.email, 'student1@example.com');

    final student = await db.authenticate('student@example.com', 'password123');
    expect(student, isNotNull);
    expect(student!.email, 'student@example.com');

    // 2. Register a new user
    final user = await db.register('student_custom@test.com', 'password123');
    expect(user.email, 'student_custom@test.com');

    // 3. Test active user session persistence
    await db.setActiveUserId(user.id);
    expect(await db.getActiveUserId(), user.id);

    // 4. Save a document
    final doc = AssignmentDocument(
      id: 'doc-123',
      ownerId: user.id,
      fileName: 'test.pdf',
      rawText: 'Hello world test content',
    );
    await db.saveDocument(doc);

    // 5. Verify document is saved
    final docs = await db.getDocuments(ownerId: user.id);
    expect(docs.length, 1);
    expect(docs.first.fileName, 'test.pdf');

    // 6. Simulate App Restart (create a brand new DatabaseServicePrefs instance)
    final db2 = DatabaseServicePrefs();
    await db2.ensureInitialized();

    final allUsers = await db2.getAllUsers();
    // admin + student1 + student + student_custom
    expect(allUsers.length, 4);

    final retrievedUser = await db2.getUserById(user.id);
    expect(retrievedUser, isNotNull);
    expect(retrievedUser!.email, 'student_custom@test.com');

    final activeUserAfterRestart = await db2.getActiveUserId();
    expect(activeUserAfterRestart, user.id);

    final docsAfterRestart = await db2.getDocuments(ownerId: user.id);
    expect(docsAfterRestart.length, 1);
    expect(docsAfterRestart.first.fileName, 'test.pdf');
  });
}
