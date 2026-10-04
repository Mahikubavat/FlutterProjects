import 'package:flutter_test/flutter_test.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/services/file_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FileDatabaseService preserves users, documents, and sessions', () async {
    final db = FileDatabaseService();
    await db.ensureInitialized();

    // 1. Default admin and student accounts exist
    final admin = await db.getUserById('admin');
    expect(admin, isNotNull);
    expect(admin!.email, 'admin@example.com');

    final student1 = await db.authenticate('student1@example.com', 'password123');
    expect(student1, isNotNull);
    expect(student1!.email, 'student1@example.com');

    final studentDefault = await db.authenticate('student@example.com', 'password123');
    expect(studentDefault, isNotNull);
    expect(studentDefault!.email, 'student@example.com');

    // 2. Register student user with unique email
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final testEmail = 'student_$timestamp@example.com';
    final student = await db.register(testEmail, 'mypassword123');
    expect(student.email, testEmail);

    // 3. Set active user session
    await db.setActiveUserId(student.id);
    expect(await db.getActiveUserId(), student.id);

    // 4. Save assignment document
    final docId = 'doc-$timestamp';
    final doc = AssignmentDocument(
      id: docId,
      ownerId: student.id,
      fileName: 'alice_chemistry_lab_$timestamp.pdf',
      rawText: 'Experimental analysis of titration curves and pH buffers.',
      cleanedText: 'experimental analysis titration curves ph buffers',
    );
    await db.saveDocument(doc);

    // 5. Verify documents query
    final docs = await db.getDocuments(ownerId: student.id);
    expect(docs.length, 1);
    expect(docs.first.fileName, 'alice_chemistry_lab_$timestamp.pdf');

    // 6. Verify across new service access (simulating restart)
    final db2 = FileDatabaseService();
    final retrieved = await db2.getUserById(student.id);
    expect(retrieved, isNotNull);
    expect(retrieved!.email, testEmail);

    final activeUser = await db2.getActiveUserId();
    expect(activeUser, student.id);

    final retrievedDocs = await db2.getDocuments(ownerId: student.id);
    expect(retrievedDocs.length, 1);
    expect(retrievedDocs.first.fileName, 'alice_chemistry_lab_$timestamp.pdf');

    // 7. Clean up created test user
    await db2.deleteUser(student.id);
    expect(await db2.getUserById(student.id), isNull);
  });
}
