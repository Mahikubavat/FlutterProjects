import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plagiarism_checker/models/app_user.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/screens/batch_evaluation_screen.dart';
import 'package:plagiarism_checker/screens/main_navigation_shell.dart';
import 'package:plagiarism_checker/screens/upload_screen.dart';
import 'package:plagiarism_checker/state/app_state.dart';
import 'package:plagiarism_checker/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('MainNavigationShell renders 4 tabs for Admin and supports switching', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Professor Sharma',
      role: UserRole.admin,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MainNavigationShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify admin bottom nav items exist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Batch Lab'), findsOneWidget);
    expect(find.text('Similarity'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Initial tab is Dashboard
    expect(find.text('Document Analysis Workspace'), findsOneWidget);

    // Tap 'Batch Lab'
    await tester.tap(find.text('Batch Lab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now BatchEvaluationScreen should be visible
    expect(find.text('Batch Plagiarism Evaluation'), findsOneWidget);

    // Tap 'Dashboard' back
    await tester.tap(find.text('Dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Document Analysis Workspace'), findsOneWidget);
  });

  testWidgets('MainNavigationShell renders ONLY 2 tabs for Student (no Batch Lab or Similarity)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'student_1',
      email: 'student1@example.com',
      displayName: 'Student One',
      role: UserRole.user,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MainNavigationShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Student should only see 'My Submissions' and 'Profile'
    expect(find.text('My Submissions'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Batch Lab'), findsNothing);
    expect(find.text('Similarity'), findsNothing);

    // Direct access to BatchEvaluationScreen is blocked for student
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BatchEvaluationScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Instructor Access Only'), findsOneWidget);
    expect(find.text('Return to My Submissions'), findsOneWidget);
  });

  testWidgets('Dashboard renders hero progress ring and filter pills', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Prof. Sharma',
      role: UserRole.admin,
    );

    // Add dummy documents
    state.documents.addAll([
      const AssignmentDocument(
        id: 'doc_1',
        fileName: 'Lab1_OS_st1.pdf',
        rawText: 'Sample raw text 1',
        cleanedText: 'Sample text 1',
        ownerName: 'Alice',
        ownerId: 'u1',
        aiClassification: 'ai_edited',
        aiEditingScore: 0.35,
        aiSyntheticScore: 0.10,
      ),
      const AssignmentDocument(
        id: 'doc_2',
        fileName: 'Lab1_OS_st2.pdf',
        rawText: 'Sample raw text 2',
        cleanedText: 'Sample text 2',
        ownerName: 'Bob',
        ownerId: 'u2',
        aiClassification: 'ai_generated',
        aiEditingScore: 0.05,
        aiSyntheticScore: 0.88,
      ),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: UploadScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Greeting and Hero section
    expect(find.text('Prof. Sharma'), findsOneWidget);
    expect(find.text('Cohort Integrity'), findsOneWidget);
    expect(find.text('CLEAN'), findsOneWidget);

    // Verify filter pills
    expect(find.text('All'), findsOneWidget);
    expect(find.text('AI-Polished'), findsWidgets);
    expect(find.text('AI-Generated'), findsWidgets);
    expect(find.text('Clean Draft'), findsOneWidget);

    // Verify document cards rendered
    expect(find.text('Lab1_OS_st1.pdf'), findsOneWidget);
    expect(find.text('Lab1_OS_st2.pdf'), findsOneWidget);

    // Tap on '+' button to open quick upload modal sheet
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Upload New Assignment'), findsOneWidget);
    expect(find.text('Browse files to upload'), findsOneWidget);
    expect(find.text('Load Demo Sample Set'), findsOneWidget);
  });

  testWidgets('Student dashboard hides AI-Polished and AI-Generated metrics and inspector', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'student_1',
      email: 'student@example.com',
      displayName: 'Rahul Patel',
      role: UserRole.user,
    );

    // Add dummy document that has AI classification in database
    state.documents.addAll([
      const AssignmentDocument(
        id: 'doc_1',
        fileName: 'Lab1_OS_Rahul.pdf',
        rawText: 'Student raw lab report text',
        cleanedText: 'Student lab report text',
        ownerName: 'Rahul Patel',
        ownerId: 'student_1',
        aiClassification: 'ai_edited',
        aiEditingScore: 0.40,
        aiSyntheticScore: 0.15,
      ),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: UploadScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Student header
    expect(find.text('Your Submissions'), findsOneWidget);
    expect(find.text('Submission Portfolio'), findsOneWidget);

    // Student MUST NOT see AI-Polished or AI-Generated labels anywhere
    expect(find.text('AI-Polished'), findsNothing);
    expect(find.text('AI-Generated'), findsNothing);
    expect(find.text('Cohort Integrity'), findsNothing);
    expect(find.text('Needs Review'), findsNothing);

    // Student sees format filters
    expect(find.text('All Files'), findsOneWidget);
    expect(find.text('PDF Documents'), findsOneWidget);
    expect(find.text('Scanned Images'), findsOneWidget);

    // Student card shows format badge, NOT AI chip
    expect(find.text('PDF Submission'), findsOneWidget);
    expect(find.textContaining('AI-Polished:'), findsNothing);
  });
}
