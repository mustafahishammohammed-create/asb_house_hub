import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homework Tracker UI & Regression Suite', () {
    testWidgets('orders overdue pending first, shows completion meter, and filters via HUD tiles',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 10, 12, 0);
      final assignments = [
        AcademicAssignment(
          id: 'hw_graded',
          title: 'Cellular Respiration Lab',
          subject: 'Biology',
          teacherName: 'Dr. Nair',
          dueDateTime: now.subtract(const Duration(days: 3)),
          pointsReward: 20,
          status: AssignmentStatus.graded,
        ),
        AcademicAssignment(
          id: 'hw_submitted',
          title: 'Industrial Revolution Essay',
          subject: 'History',
          teacherName: 'Ms. Verma',
          dueDateTime: now.add(const Duration(days: 2)),
          pointsReward: 25,
          status: AssignmentStatus.submitted,
        ),
        AcademicAssignment(
          id: 'hw_upcoming',
          title: 'Quadratic Inequalities Practice',
          subject: 'Mathematics',
          teacherName: 'Mr. Sharma',
          dueDateTime: now.add(const Duration(hours: 8)),
          pointsReward: 30,
          status: AssignmentStatus.pending,
        ),
        AcademicAssignment(
          id: 'hw_overdue',
          title: 'Binary Tree Traversal Worksheet',
          subject: 'Computer Science',
          teacherName: 'Mr. Roy',
          dueDateTime: now.subtract(const Duration(hours: 4)),
          pointsReward: 40,
          status: AssignmentStatus.pending,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AssignmentsTab(
              classLevel: 'Grade 10',
              mockNow: now,
              initialAssignments: assignments,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Editorial Progress HUD shows accurate completion metrics (2 done of 4 = 50%).
      expect(find.text('2 of 4 Tasks Completed'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Overdue pending sorts above upcoming pending, which sorts above submitted.
      final overdueY = tester.getTopLeft(find.byKey(const Key('assignment_card_hw_overdue'))).dy;
      final upcomingY = tester.getTopLeft(find.byKey(const Key('assignment_card_hw_upcoming'))).dy;
      final submittedY = tester.getTopLeft(find.byKey(const Key('assignment_card_hw_submitted'))).dy;
      expect(overdueY, lessThan(upcomingY));
      expect(upcomingY, lessThan(submittedY));

      // Tapping 'Pending' HUD tile filters list to pending assignments only.
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assignment_card_hw_overdue')), findsOneWidget);
      expect(find.byKey(const Key('assignment_card_hw_upcoming')), findsOneWidget);
      expect(find.byKey(const Key('assignment_card_hw_submitted')), findsNothing);
      expect(find.text('Pending ✕'), findsOneWidget);

      // Reset filter via the active filter chip.
      await tester.tap(find.text('Pending ✕'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assignment_card_hw_submitted')), findsOneWidget);
    });

    testWidgets('renders compact 360px viewport at 200% font scale without overflow',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 10, 12, 0);
      final assignments = [
        AcademicAssignment(
          id: 'hw_scale_cs',
          title: 'Operating Systems Semaphores & Mutex Synchronization Lab',
          subject: 'Computer Science',
          teacherName: 'Prof. Kulkarni',
          dueDateTime: now.subtract(const Duration(hours: 2)),
          pointsReward: 50,
          status: AssignmentStatus.pending,
        ),
      ];

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: AssignmentsTab(
                  classLevel: 'Grade 10',
                  mockNow: now,
                  initialAssignments: assignments,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
