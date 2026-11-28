import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/models/campus_event.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/screens/events_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
  });
  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });
  void viewport(WidgetTester t, double width) {
    t.view.physicalSize = Size(width, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget app(Widget child, double scale) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0, 3.0]) {
      testWidgets('event layout $width dp at $scale text', (t) async {
        viewport(t, width);
        final details = <FlutterErrorDetails>[];
        final handler = FlutterError.onError;
        FlutterError.onError = (d) {
          details.add(d);
          handler?.call(d);
        };
        final now = DateTime.now();
        await AuthService.cacheEvents([
          CampusEvent(
            id: 'probe',
            title: 'Inter-House Athletics Meet Finals',
            description: 'Track and field finals.',
            category: EventCategory.sports,
            startTime: now.add(const Duration(hours: 2)),
            endTime: now.add(const Duration(hours: 5)),
            venue: 'Main Campus Stadium',
            pointsAwarded: 150,
            pointsMultiplier: 1.5,
          ),
        ]);
        await t.pumpWidget(
          app(const EventsScreen(userHouse: 'emerald'), scale),
        );
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Inter-House Athletics Meet Finals'),
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 20,
        );
        await t.pumpAndSettle();
        FlutterError.onError = handler;
        for (final d in details) {
          debugPrint(d.toString());
        }
        expect(t.takeException(), isNull);
        expect(find.text('Inter-House Athletics Meet Finals'), findsOneWidget);
      });
    }
  }
  final now = DateTime(2026, 11, 28, 12);
  AcademicAssignment hw(AssignmentStatus status) => AcademicAssignment(
    id: 'probe_hw',
    title: 'Photosynthesis Worksheet',
    subject: 'Biology',
    teacherName: 'Dr Nair',
    dueDateTime: now.add(const Duration(hours: 3)),
    status: status,
  );
  Future<void> profile() async => AuthService.cacheProfile({
    'role': 'student',
    'scholar_no': '99901',
    'house_name': 'emerald',
    'class_level': 'Grade 10',
  }, syncMemberRecord: false);
  testWidgets(
    'successful local status must yield to refreshed graded assignment',
    (t) async {
      viewport(t, 500);
      await profile();
      Widget screen(AssignmentStatus status) => app(
        AssignmentsTab(
          key: const ValueKey('same_tab'),
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: [hw(status)],
        ),
        1,
      );
      await t.pumpWidget(screen(AssignmentStatus.pending));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('PENDING'));
      await t.tap(find.text('PENDING'));
      await t.pumpAndSettle();
      expect(find.text('SUBMITTED'), findsOneWidget);
      await t.pumpWidget(screen(AssignmentStatus.graded));
      await t.pumpAndSettle();
      expect(
        find.text('GRADED'),
        findsOneWidget,
        reason:
            'Authoritative refresh must override a completed optimistic operation',
      );
    },
  );
  testWidgets('submission notes persist when submission reports success', (
    t,
  ) async {
    viewport(t, 500);
    await profile();
    await AuthService.cacheAssignments([
      hw(AssignmentStatus.pending),
    ], classLevel: 'Grade 10');
    await t.pumpWidget(
      app(
        AssignmentsTab(
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: [hw(AssignmentStatus.pending)],
        ),
        1,
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Submit Work'));
    await t.tap(find.text('Submit Work'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'My completed answer');
    await t.ensureVisible(find.text('Turn In / Submit Homework'));
    await t.tap(find.text('Turn In / Submit Homework'));
    await t.pumpAndSettle();
    expect(find.textContaining('submitted to'), findsOneWidget);
    expect(
      AuthService.getCachedAssignments(
        classLevel: 'Grade 10',
      ).single.submissionNotes,
      'My completed answer',
    );
  });
  testWidgets('homework real media size 360 dp at 2x', (t) async {
    viewport(t, 360);
    await t.pumpWidget(
      app(
        AssignmentsTab(
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: [hw(AssignmentStatus.pending)],
        ),
        2,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'duplicate taps wait for one write and failure preserves the last status',
    (t) async {
      viewport(t, 500);
      await profile();
      final auth = DelayedAssignmentAuth();
      await t.pumpWidget(
        app(
          AssignmentsTab(
            authService: auth,
            classLevel: 'Grade 10',
            mockNow: now,
            initialAssignments: [hw(AssignmentStatus.pending)],
          ),
          1,
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('PENDING'));
      await t.tap(find.text('PENDING'));
      await t.pump();
      await t.tap(find.text('PENDING'));
      await t.pump();
      expect(auth.calls, 1);
      auth.pending.complete(true);
      await t.pumpAndSettle();
      expect(find.text('SUBMITTED'), findsOneWidget);
      auth.pending = Completer<bool>();
      await t.tap(find.text('SUBMITTED'));
      await t.pump();
      auth.pending.complete(false);
      await t.pumpAndSettle();
      expect(find.text('SUBMITTED'), findsOneWidget);
    },
  );
  testWidgets('thrown submission errors remain visible in the sheet', (
    t,
  ) async {
    viewport(t, 500);
    await profile();
    final auth = DelayedAssignmentAuth();
    await t.pumpWidget(
      app(
        AssignmentsTab(
          authService: auth,
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: [hw(AssignmentStatus.pending)],
        ),
        1,
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Submit Work'));
    await t.tap(find.text('Submit Work'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Turn In / Submit Homework'));
    await t.tap(find.text('Turn In / Submit Homework'));
    await t.pump();
    auth.pending.completeError(Exception('connection interrupted'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('homework_submit_error')), findsOneWidget);
    expect(find.textContaining('submitted to'), findsNothing);
  });
  testWidgets('homework empty copy follows status filter and all subjects', (
    t,
  ) async {
    viewport(t, 500);
    await t.pumpWidget(
      app(
        AssignmentsTab(
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: [hw(AssignmentStatus.pending)],
        ),
        1,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Submitted'));
    await t.pumpAndSettle();
    expect(find.text('No submitted homework right now.'), findsOneWidget);
    await t.tap(find.text('Graded'));
    await t.pumpAndSettle();
    expect(find.text('No graded homework right now.'), findsOneWidget);
    await t.pumpWidget(
      app(
        AssignmentsTab(
          key: const ValueKey('empty'),
          classLevel: 'Grade 10',
          mockNow: now,
          initialAssignments: const [],
        ),
        1,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('No homework for this class yet.'), findsOneWidget);
  });
}

class DelayedAssignmentAuth extends AuthService {
  int calls = 0;
  Completer<bool> pending = Completer<bool>();
  @override
  Future<bool> updateAssignmentStatus({
    required String assignmentId,
    required AssignmentStatus newStatus,
    String? classLevel,
    String? scholarNo,
    String? house,
    int pointsReward = 20,
    String? submissionNotes,
  }) {
    calls++;
    return pending.future;
  }
}
