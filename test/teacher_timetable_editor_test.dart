import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/screens/teacher_timetable_editor_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/timetable_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableService timetableService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
    timetableService = TimetableService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  Future<void> seedTeacherProfile({String classId = '11D'}) async {
    await AuthService.cacheProfile({
      'uid': 'uid_teacher_fatima',
      'scholar_no': '2310101',
      'full_name': 'Ms. Fatima',
      'role': 'teacher',
      'house_name': 'ruby',
      'class_id': classId,
      'class_level': 'Grade 11',
      'division': 'D',
    });
  }

  Future<void> seedStudentProfile({String classId = '11D'}) async {
    await AuthService.cacheProfile({
      'uid': 'uid_student_1',
      'scholar_no': '2310910',
      'full_name': 'Ayaan Mohammed',
      'role': 'student',
      'house_name': 'ruby',
      'class_id': classId,
      'class_level': 'Grade 11',
      'division': 'D',
    });
  }

  group('M2e: Teacher 6-Day Timetable Editor Widget Tests', () {
    testWidgets('renders 6 school days (Saturday to Thursday) and 8 periods', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(classId: '11D', initialDay: 'Saturday'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 6 day chips are visible
      expect(find.text('Saturday'), findsOneWidget);
      expect(find.text('Sunday'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);

      // Verify 8 teaching periods are present
      expect(find.text('Period 1'), findsOneWidget);
      expect(find.text('Period 2'), findsOneWidget);
      expect(find.text('Period 8'), findsOneWidget);

      // Verify break card is present
      expect(find.textContaining('School Break'), findsOneWidget);

      // Verify buttons
      expect(find.byKey(const Key('save_timetable_draft_button')), findsOneWidget);
      expect(find.byKey(const Key('publish_timetable_button')), findsOneWidget);
    });

    testWidgets('Standard 07:45 timing button applies sequential 45m slots and 30m break', (tester) async {
      tester.view.physicalSize = const Size(1080, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(classId: '11D', initialDay: 'Saturday'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Standard 07:45"
      await tester.tap(find.byKey(const Key('load_standard_timing_button')));
      await tester.pumpAndSettle();

      // P1: 07:45 - 08:30
      expect(find.text('07:45 - 08:30'), findsOneWidget);
      // P2: 08:30 - 09:15
      expect(find.text('08:30 - 09:15'), findsOneWidget);
      // P3: 09:15 - 10:00
      expect(find.text('09:15 - 10:00'), findsOneWidget);
      // P4: 10:00 - 10:45
      expect(find.text('10:00 - 10:45'), findsOneWidget);
      // Break: 10:45 - 11:15 (+30m)
      expect(find.text('10:45 - 11:15'), findsOneWidget);

      // Validation status shows valid
      expect(find.textContaining('Timetable Valid'), findsOneWidget);
    });

    testWidgets('Save Draft persists version to cache without publishing to active', (tester) async {
      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(classId: '11D', initialDay: 'Sunday'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save Draft
      await tester.tap(find.byKey(const Key('save_timetable_draft_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('saved successfully'), findsOneWidget);

      // Verify stored in history
      final versions = timetableService.getCachedVersions('11D', 'Sunday');
      expect(versions, isNotEmpty);
      expect(versions.first.status, TimetableStatus.draft);

      // Verify NOT published as active
      final active = timetableService.getCachedActiveVersion('11D', 'Sunday');
      expect(active, isNull);
    });

    testWidgets('Publish button activates recurring timetable version', (tester) async {
      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(classId: '11D', initialDay: 'Monday'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Publish
      await tester.tap(find.byKey(const Key('publish_timetable_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('published and recurring live'), findsOneWidget);

      // Verify active version is now published
      final active = timetableService.getCachedActiveVersion('11D', 'Monday');
      expect(active, isNotNull);
      expect(active!.isPublished, isTrue);
      expect(active.slots.length, 8);
    });

    testWidgets('Full week preview dialog opens and shows week overview', (tester) async {
      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(classId: '11D', initialDay: 'Saturday'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('full_week_preview_button')));
      await tester.pumpAndSettle();

      expect(find.text('11D 6-Day Timetable Preview'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('11D 6-Day Timetable Preview'), findsNothing);
    });
  });

  group('M2e: Student View Migration (6-Day Sat–Thu with Section-Aware Engine)', () {
    testWidgets('TimetableTab renders 6 school days (SAT through THU)', (tester) async {
      await seedStudentProfile(classId: '11D');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimetableTab(classLevel: '11D')),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SAT is rendered first
      expect(find.text('SAT'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('TUE'), findsOneWidget);
      expect(find.text('WED'), findsOneWidget);
      expect(find.text('THU'), findsOneWidget);
      // Friday should not be a school day
      expect(find.text('FRI'), findsNothing);
    });

    testWidgets('Student sees published recurring timetable version with 8 periods + break', (tester) async {
      await seedStudentProfile(classId: '11D');

      // Publish a recurring Tuesday version for 11D
      final version = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Tuesday',
        createdByUid: 'uid_fatima',
      );
      await timetableService.publishTimetable(
        version,
        publisherUid: 'uid_fatima',
        publisherName: 'Ms. Fatima',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimetableTab(classLevel: '11D', initialDay: 'Tuesday'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 8 teaching periods + 1 break = 9 items
      expect(find.text('9 Periods'), findsOneWidget);
      expect(find.textContaining('Tuesday Schedule'), findsOneWidget);

      // Student sees no edit or add affordances
      expect(find.byKey(const Key('manage_recurring_timetable_button')), findsNothing);
      expect(find.byKey(const Key('add_period_button')), findsNothing);
    });

    testWidgets('Staff sees "Edit Timetable" button and can open the recurring editor', (tester) async {
      await seedTeacherProfile(classId: '11D');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimetableTab(classLevel: '11D', initialDay: 'Wednesday'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify staff sees Edit Timetable button
      final editBtn = find.byKey(const Key('manage_recurring_timetable_button'));
      expect(editBtn, findsOneWidget);

      // Tap Edit Timetable opens TeacherTimetableEditorScreen
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('11D Timetable Editor'), findsOneWidget);
      expect(find.byKey(const Key('save_timetable_draft_button')), findsOneWidget);
    });
  });
}
