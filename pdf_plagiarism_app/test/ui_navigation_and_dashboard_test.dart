import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:plagiarism_checker/models/app_notification.dart';
import 'package:plagiarism_checker/models/app_user.dart';
import 'package:plagiarism_checker/models/assignment_document.dart';
import 'package:plagiarism_checker/models/comparison_result.dart';
import 'package:plagiarism_checker/sample_data/sample_documents.dart';
import 'package:plagiarism_checker/screens/batch_evaluation_screen.dart';
import 'package:plagiarism_checker/screens/document_viewer_screen.dart';
import 'package:plagiarism_checker/screens/main_navigation_shell.dart';
import 'package:plagiarism_checker/screens/results_screen.dart';
import 'package:plagiarism_checker/screens/upload_screen.dart';
import 'package:plagiarism_checker/state/app_state.dart';
import 'package:plagiarism_checker/theme/app_theme.dart';
import 'package:plagiarism_checker/widgets/ai_authorship_dialog.dart';
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

  testWidgets('Dashboard renders on narrow mobile screens (360x780) with 0 submissions without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
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

    // Must not produce any layout overflow errors
    expect(tester.takeException(), isNull);

    // Verify key elements
    expect(find.text('Cohort Integrity'), findsOneWidget);
    expect(find.text('0 Submissions'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('CLEAN'), findsOneWidget);
    expect(find.text('AI-Polished'), findsWidgets);
    expect(find.text('AI-Generated'), findsWidgets);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('No Submissions Yet'), findsOneWidget);
    expect(find.text('Upload Document'), findsOneWidget);
    expect(find.text('Load Demo Sample Set'), findsOneWidget);

    // Verify loading sample documents on narrow screen also has zero overflow
    await tester.runAsync(() async {
      await state.loadSampleDocuments(SampleDocuments.all);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(state.documents.isNotEmpty, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BatchEvaluationScreen renders on narrow mobile screens (360x780) without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    await tester.runAsync(() async {
      await state.loadSampleDocuments(SampleDocuments.all);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BatchEvaluationScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start Batch Evaluation'), findsOneWidget);
    expect(find.text('Simulate Demo Batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notifications sheet renders without fractional overflow on narrow screen (360x780)', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    // Add an unread notification so 'Mark all as read' button appears
    state.notifications.add(
      AppNotification(
        id: 'notif_1',
        recipientUserId: 'admin_1',
        senderUserId: 'student_1',
        senderName: 'John Doe',
        title: 'New Submission Uploaded',
        message: 'Lab report uploaded for Newton law.',
        type: NotificationType.reuploadCompleted,
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const UploadScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Find and tap notification bell icon
    final bellFinder = find.byIcon(Icons.notifications_outlined);
    expect(bellFinder, findsOneWidget);
    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    // Verify notification bottom sheet header renders cleanly
    expect(find.text('Notifications & Alerts'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AiAuthorshipDialog automatically screens unscreened document on first open without requiring rerun', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    const unscreenedDoc = AssignmentDocument(
      id: 'test_doc_unscreened',
      fileName: 'student_essay.pdf',
      rawText: 'This is a student research paper on physics and experimental dynamics.',
      cleanedText: 'This is a student research paper on physics and experimental dynamics.',
      // aiClassification and scores are null initially
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AiAuthorshipDialog.show(ctx, document: unscreenedDoc),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pump(); // Start dialog open & trigger post-frame callback
    await tester.pumpAndSettle(); // Allow auto-screening to finish

    // Verify dialog displayed results immediately
    expect(find.text('AI Authorship & Transparency Inspector'), findsOneWidget);
    expect(find.text('Layer 1: Synthetic Generation'), findsOneWidget);
    expect(find.text('Layer 2: Grammatical & Tone Polish'), findsOneWidget);
    expect(find.text('Rerun Screening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DocumentViewerScreen supports switching to Extracted Text view without error', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    const testDoc = AssignmentDocument(
      id: 'doc_1',
      fileName: 'student_lab.pdf',
      rawText: 'Introduction to experimental mechanics and acceleration.',
      cleanedText: 'Introduction to experimental mechanics and acceleration.',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: DocumentViewerScreen(document: testDoc),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Extracted Text segment
    final textSegment = find.text('Extracted Text');
    expect(textSegment, findsOneWidget);
    await tester.tap(textSegment);
    await tester.pumpAndSettle();

    expect(find.textContaining('words'), findsOneWidget);
    expect(find.text('Copy Text'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UploadScreen floating selection bar renders with 4 items selected on narrow mobile screen (360x780) without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    for (int i = 1; i <= 4; i++) {
      state.documents.add(AssignmentDocument(
        id: 'doc_$i',
        fileName: 'Lab_Report_0$i.pdf',
        rawText: 'Content of lab report $i',
        cleanedText: 'Content of lab report $i',
      ));
      state.selectedDocumentIds.add('doc_$i');
    }

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

    // Verify selection bar is visible
    expect(find.text('4 selected'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Batch Lab'), findsOneWidget);
    expect(find.text('Compare 1-to-1'), findsOneWidget);

    // Verify 0 render overflows
    expect(tester.takeException(), isNull);
  });

  testWidgets('BatchEvaluationScreen report dashboard renders on narrow mobile screen (360x780) with student cards and no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BatchEvaluationScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Simulate Demo Batch to trigger completed report dashboard
    final demoBtn = find.text('Simulate Demo Batch');
    expect(demoBtn, findsOneWidget);
    await tester.tap(demoBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Check responsive mobile student card elements
    expect(find.text('Student Plagiarism Reports'), findsOneWidget);
    expect(find.text('Student 1 (Alex Rivera)'), findsOneWidget);
    expect(find.text('Inspect Match'), findsWidgets);
    expect(find.text('Notify'), findsWidgets);

    // Verify 0 render flex overflow
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResultsScreen renders pairwise combinations with pair numbering (Pair #1 of 6) and no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );

    // Provide 6 pairwise comparison results
    state.results = [
      const ComparisonResult(
        docAId: 'doc_1',
        docBId: 'doc_2',
        docAName: 'A2_CE023_SDP.pdf',
        docBName: 'CE023_Lab02.pdf',
        shingleSimilarity: 0.72,
        cosineSimilarity: 0.68,
        overallScore: 0.70,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
      const ComparisonResult(
        docAId: 'doc_1',
        docBId: 'doc_3',
        docAName: 'A2_CE023_SDP.pdf',
        docBName: 'CE023_Lab03.pdf',
        shingleSimilarity: 0.55,
        cosineSimilarity: 0.50,
        overallScore: 0.525,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
      const ComparisonResult(
        docAId: 'doc_1',
        docBId: 'doc_4',
        docAName: 'A2_CE023_SDP.pdf',
        docBName: 'CE023_Lab04.pdf',
        shingleSimilarity: 0.20,
        cosineSimilarity: 0.18,
        overallScore: 0.19,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
      const ComparisonResult(
        docAId: 'doc_2',
        docBId: 'doc_3',
        docAName: 'CE023_Lab02.pdf',
        docBName: 'CE023_Lab03.pdf',
        shingleSimilarity: 0.45,
        cosineSimilarity: 0.40,
        overallScore: 0.425,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
      const ComparisonResult(
        docAId: 'doc_2',
        docBId: 'doc_4',
        docAName: 'CE023_Lab02.pdf',
        docBName: 'CE023_Lab04.pdf',
        shingleSimilarity: 0.15,
        cosineSimilarity: 0.12,
        overallScore: 0.135,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
      const ComparisonResult(
        docAId: 'doc_3',
        docBId: 'doc_4',
        docAName: 'CE023_Lab03.pdf',
        docBName: 'CE023_Lab04.pdf',
        shingleSimilarity: 0.10,
        cosineSimilarity: 0.08,
        overallScore: 0.09,
        matchedRangesA: [],
        matchedRangesB: [],
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ResultsScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify clarity banner and pair numbering
    expect(find.textContaining('Showing 6 Document Pair Combinations'), findsOneWidget);
    expect(find.text('Pair #1 of 6'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pair #2 of 6'), findsOneWidget);

    // Verify 0 render flex overflow
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResultsScreen empty state renders guidance and navigation buttons', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.currentUser = const AppUser(
      id: 'admin_1',
      email: 'admin@example.com',
      displayName: 'Administrator',
      role: UserRole.admin,
    );
    state.results = [];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ResultsScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Similarity Comparisons Yet'), findsOneWidget);
    expect(find.text('Go to Documents'), findsOneWidget);
    expect(find.text('Batch Lab'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

