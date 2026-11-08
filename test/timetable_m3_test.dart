import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/models/timetable_period.dart';
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

  ClassTimetableVersion buildVersion({
    String classId = '11D',
    String day = 'Wednesday',
    String teacher = '',
    String teacherUid = '',
    String room = '',
    int? period,
    String subjectPrefix = 'Subject',
    DateTime? effectiveFrom,
  }) {
    final template = ClassTimetableVersion.template(
      classId: classId,
      dayOfWeek: day,
      effectiveFrom: effectiveFrom ?? DateTime(2026, 9, 1),
    );
    final slots = template.slots.map((slot) {
      final applies = period == null || slot.periodNumber == period;
      return slot.copyWith(
        subject: '$subjectPrefix ${slot.periodNumber}',
        teacherName: applies ? teacher : '',
        teacherUid: applies ? teacherUid : '',
        room: applies ? room : '',
      );
    }).toList();
    return template.copyWith(slots: slots);
  }

  Future<ClassTimetableVersion> publish(
    ClassTimetableVersion version, {
    bool enforceConflicts = true,
  }) async {
    final ok = await timetableService.publishTimetable(
      version,
      publisherUid: 'uid_admin_1',
      publisherName: 'Principal',
      enforceConflicts: enforceConflicts,
    );
    expect(ok, isTrue, reason: 'seed publish must succeed');
    return timetableService
        .getCachedVersions(version.classId, version.dayOfWeek)
        .firstWhere((v) => v.isPublished);
  }

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
    await AuthService.cacheAcademicClasses([
      AcademicClass(
        classId: classId,
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
        classTeacherUid: 'uid_teacher_fatima',
        timetableEditingEnabled: true,
      ),
    ]);
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

  group('M3a: one-day override model and resolution (test 33)', () {
    test('published override wins for its exact date only', () {
      final recurring = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        effectiveFrom: DateTime(2026, 9, 1),
      ).copyWith(status: TimetableStatus.published, version: 1);

      final override = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        effectiveFrom: DateTime(2026, 11, 18),
      ).copyWith(
        status: TimetableStatus.published,
        version: 2,
        overrideDate: DateTime(2026, 11, 18),
      );

      final versions = [recurring, override];
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 11, 18)),
        same(override),
      );
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 11, 19)),
        same(recurring),
      );
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 11, 11)),
        same(recurring),
      );
    });

    test('override date round-trips through Firestore and cache maps', () {
      final date = DateTime(2026, 11, 18);
      final version = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        effectiveFrom: date,
      ).copyWith(overrideDate: date);

      final map = version.toMap();
      expect(version.isTemporary, isTrue);
      expect(version.appliesOn(date), isTrue);
      expect(version.appliesOn(DateTime(2026, 11, 19)), isFalse);
      expect(map['override_date'], isA<Timestamp>());
      expect(
        ClassTimetableVersion.fromMap(version.toJsonMap()).overrideDate,
        date,
      );
    });

    test('override validation rejects Friday and a mismatched weekday', () {
      final friday = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        effectiveFrom: DateTime(2026, 11, 13),
      ).copyWith(overrideDate: DateTime(2026, 11, 13));
      expect(friday.isValid, isFalse);
      expect(friday.validate().any((e) => e.contains('Friday')), isTrue);

      final mismatched = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        effectiveFrom: DateTime(2026, 11, 19),
      ).copyWith(overrideDate: DateTime(2026, 11, 19));
      expect(mismatched.isValid, isFalse);
      expect(
        mismatched.validate().any((e) => e.contains('must fall on Wednesday')),
        isTrue,
      );
    });
  });

  group('M3b: cross-class conflict detection (tests 18–19)', () {
    test('detects a teacher double-booked across two classes', () async {
      await publish(
        buildVersion(
          classId: '10A',
          teacher: 'Ms. Fatima',
          teacherUid: 'uid_fatima',
          period: 1,
        ),
        enforceConflicts: false,
      );

      final candidate = buildVersion(
        classId: '11D',
        teacher: 'Ms. Fatima',
        teacherUid: 'uid_fatima',
        period: 1,
      );
      final conflicts = await timetableService.findTimetableConflicts(
        candidate,
        date: candidate.effectiveFrom,
      );

      expect(conflicts.length, 1);
      expect(conflicts.first.type, TimetableConflictType.teacher);
      expect(conflicts.first.otherClassId, '10A');
      expect(conflicts.first.message, contains('already booked'));
    });

    test('publish is blocked on a teacher conflict and writes nothing (18)',
        () async {
      await publish(
        buildVersion(
          classId: '10A',
          teacher: 'Ms. Fatima',
          teacherUid: 'uid_fatima',
          period: 2,
        ),
        enforceConflicts: false,
      );

      final candidate = buildVersion(
        classId: '11D',
        teacher: 'Ms. Fatima',
        teacherUid: 'uid_fatima',
        period: 2,
      );
      final ok = await timetableService.publishTimetable(
        candidate,
        publisherUid: 'uid_fatima',
        publisherName: 'Ms. Fatima',
      );

      expect(ok, isFalse);
      expect(
        timetableService
            .getCachedVersions('11D', 'Wednesday')
            .where((v) => v.isPublished),
        isEmpty,
      );
      expect(
        timetableService
            .getCachedVersions('11D', 'Wednesday')
            .where((v) => v.isTemporary),
        isEmpty,
      );
    });

    test('detects a room double-booked across two classes (19)', () async {
      await publish(
        buildVersion(
          classId: '10A',
          teacher: 'Mr. Rao',
          teacherUid: 'uid_rao',
          room: 'Lab 2',
          period: 3,
        ),
        enforceConflicts: false,
      );

      final candidate = buildVersion(
        classId: '11D',
        teacher: 'Ms. Fatima',
        teacherUid: 'uid_fatima',
        room: 'lab 2',
        period: 3,
      );
      final conflicts = await timetableService.findTimetableConflicts(
        candidate,
        date: candidate.effectiveFrom,
      );
      expect(conflicts.any((c) => c.type == TimetableConflictType.room), isTrue);

      final ok = await timetableService.publishTimetable(
        candidate,
        publisherUid: 'uid_fatima',
        publisherName: 'Ms. Fatima',
      );
      expect(ok, isFalse);
    });

    test('allows a conflict-free schedule and ignores adjacent periods',
        () async {
      await publish(
        buildVersion(
          classId: '10A',
          teacher: 'Mr. Rao',
          teacherUid: 'uid_rao',
          room: 'Lab 2',
          period: 1,
        ),
        enforceConflicts: false,
      );

      // Start at 08:30 so Period 1 begins exactly when the other class's
      // Period 1 (07:45–08:30) ends.
      final shiftedTemplate = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        dayStartMinute: 465 + kTeachingPeriodMinutes,
        effectiveFrom: DateTime(2026, 9, 1),
      );
      final candidate = shiftedTemplate.copyWith(
        slots: shiftedTemplate.slots.map((s) => s.copyWith(
              subject: 'Subject ${s.periodNumber}',
              teacherName: s.periodNumber == 1 ? 'Ms. Fatima' : '',
              teacherUid: s.periodNumber == 1 ? 'uid_fatima' : '',
              room: s.periodNumber == 1 ? 'Room 12' : '',
            )).toList(),
      );
      expect(candidate.isValid, isTrue, reason: candidate.validate().join('; '));

      final conflicts = await timetableService.findTimetableConflicts(
        candidate,
        date: candidate.effectiveFrom,
      );
      expect(conflicts, isEmpty);

      final ok = await timetableService.publishTimetable(
        candidate,
        publisherUid: 'uid_fatima',
        publisherName: 'Ms. Fatima',
      );
      expect(ok, isTrue);
    });

    test('the pure detector ignores same-class and unpublished versions', () {
      final candidate = buildVersion(
        teacher: 'Ms. Fatima',
        teacherUid: 'uid_fatima',
        room: 'Lab 2',
        period: 1,
      );
      final sameClass = candidate.copyWith(
        id: 'other-version',
        status: TimetableStatus.published,
        version: 2,
      );
      final draft = buildVersion(classId: '10A', teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1)
          .copyWith(status: TimetableStatus.draft);

      expect(
        ClassTimetableVersion.detectConflicts(
          candidate: candidate,
          otherVersions: [sameClass, draft],
        ),
        isEmpty,
      );
    });
  });

  group('M3c: copy to selected days (tests 31–32)', () {
    test('copies to selected days only and leaves other days untouched',
        () async {
      final source = buildVersion(day: 'Saturday', subjectPrefix: 'Math');

      final results = await timetableService.copyTimetableToDays(
        source: source,
        targetDays: const ['Monday', 'Tuesday'],
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );

      expect(results, {'Monday': true, 'Tuesday': true});
      final monday = timetableService.getCachedVersions('11D', 'Monday');
      final tuesday = timetableService.getCachedVersions('11D', 'Tuesday');
      expect(monday.length, 1);
      expect(tuesday.length, 1);
      expect(monday.first.status, TimetableStatus.draft);
      expect(monday.first.dayOfWeek, 'Monday');
      expect(monday.first.slots.length, 8);
      expect(monday.first.slots.first.subject, 'Math 1');
      expect(monday.first.isTemporary, isFalse);
      expect(timetableService.getCachedVersions('11D', 'Wednesday'), isEmpty);
      expect(timetableService.getCachedVersions('11D', 'Saturday'), isEmpty);

      expect(
        timetableService
            .getCachedAudits('11D')
            .any((a) => a['action'] == 'copy' && a['day_of_week'] == 'Monday'),
        isTrue,
      );
    });

    test('copying never mutates the source day and skips it as a target',
        () async {
      final source = buildVersion(day: 'Saturday');
      await publish(source);

      final results = await timetableService.copyTimetableToDays(
        source: source,
        targetDays: const ['Saturday', 'Thursday'],
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );

      expect(results.containsKey('Saturday'), isFalse);
      expect(results['Thursday'], isTrue);
      final saturday = timetableService.getCachedVersions('11D', 'Saturday');
      expect(saturday.length, 1);
      expect(saturday.first.isPublished, isTrue);
      expect(saturday.first.version, 1);
    });

    test('publishing one copied day leaves the other copy as a draft', () async {
      final source = buildVersion(day: 'Saturday');
      await timetableService.copyTimetableToDays(
        source: source,
        targetDays: const ['Monday', 'Tuesday'],
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );

      final monday = timetableService.getCachedVersions('11D', 'Monday').first;
      final ok = await timetableService.publishTimetable(
        monday,
        publisherUid: 'uid_fatima',
        publisherName: 'Ms. Fatima',
      );
      expect(ok, isTrue);

      expect(
        timetableService.getCachedActiveVersion(
          '11D',
          'Monday',
          DateTime(2026, 9, 15),
        ),
        isNotNull,
      );
      expect(
        timetableService.getCachedActiveVersion(
          '11D',
          'Tuesday',
          DateTime(2026, 9, 15),
        ),
        isNull,
      );
      expect(
        timetableService.getCachedVersions('11D', 'Tuesday').first.status,
        TimetableStatus.draft,
      );
    });
  });

  group('M3d: temporary override service and substitution (test 33)', () {
    test('publishing an override leaves the recurring version intact',
        () async {
      final recurring = await publish(
        buildVersion(teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1),
      );

      final overrideBase = buildVersion(
        teacher: 'Ms. Fatima',
        teacherUid: 'uid_fatima',
        period: 1,
      ).copyWith(
        slots: buildVersion(
          teacher: 'Ms. Fatima',
          teacherUid: 'uid_fatima',
          period: 1,
        ).slots.map((s) {
          if (s.periodNumber != 1) return s;
          return s.copyWith(subject: 'Special Event');
        }).toList(),
      );

      final override = await timetableService.saveTimetableOverride(
        overrideBase,
        date: DateTime(2026, 11, 18),
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
        publish: true,
      );
      expect(override, isNotNull);
      expect(override!.isTemporary, isTrue);
      expect(override.overrideDate, DateTime(2026, 11, 18));

      final cached = timetableService.getCachedVersions('11D', 'Wednesday');
      final onDate = ClassTimetableVersion.activeForDate(
        cached,
        DateTime(2026, 11, 18),
      );
      final nextWeek = ClassTimetableVersion.activeForDate(
        cached,
        DateTime(2026, 11, 25),
      );

      expect(onDate?.id, override.id);
      expect(onDate?.isTemporary, isTrue);
      expect(nextWeek?.id, recurring.id);
      expect(nextWeek?.isTemporary, isFalse);

      final recurringAfter = cached.firstWhere((v) => !v.isTemporary);
      expect(recurringAfter.version, recurring.version);
      expect(recurringAfter.status, TimetableStatus.published);
      expect(recurringAfter.slots.first.subject, 'Subject 1');

      expect(
        timetableService
            .getCachedAudits('11D')
            .any((a) => a['action'] == 'override'),
        isTrue,
      );
    });

    test('substitution is date-specific and never changes the recurring teacher',
        () async {
      final recurring = await publish(
        buildVersion(teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1),
      );

      final overrideBase = recurring.copyWith(
        slots: recurring.slots.map((s) {
          if (s.periodNumber != 1) return s;
          return s.copyWith(
            substituteTeacherName: 'Mr. Ahmed',
            substituteTeacherUid: 'uid_ahmed',
          );
        }).toList(),
      );

      final override = await timetableService.saveTimetableOverride(
        overrideBase,
        date: DateTime(2026, 11, 18),
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
        publish: true,
      );
      expect(override, isNotNull);

      final p1 = override!.toPeriods().firstWhere((p) => p.periodNumber == 1);
      expect(p1.isSubstitute, isTrue);
      expect(p1.teacherName, 'Mr. Ahmed');
      expect(p1.originalTeacherName, 'Ms. Fatima');

      final recurringAfter = timetableService
          .getCachedVersions('11D', 'Wednesday')
          .firstWhere((v) => !v.isTemporary);
      expect(recurringAfter.slots.first.substituteTeacherName, isEmpty);
      expect(recurringAfter.slots.first.teacherName, 'Ms. Fatima');
      expect(
        timetableService
            .getCachedAudits('11D')
            .any((a) => a['action'] == 'substitute'),
        isTrue,
      );

      // Copying an override strips its one-day substitute markers.
      final copyResults = await timetableService.copyTimetableToDays(
        source: override,
        targetDays: const ['Thursday'],
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );
      expect(copyResults['Thursday'], isTrue);
      final thursday = timetableService.getCachedVersions('11D', 'Thursday').first;
      expect(thursday.slots.first.hasSubstitute, isFalse);
      expect(thursday.isTemporary, isFalse);
    });

    test('a denied override write returns null and caches nothing', () async {
      await publish(buildVersion(teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1));

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');

      final saved = await timetableService.saveTimetableOverride(
        buildVersion(teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1),
        date: DateTime(2026, 11, 18),
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
        publish: true,
      );

      expect(saved, isNull);
      expect(
        timetableService
            .getCachedVersions('11D', 'Wednesday')
            .where((v) => v.isTemporary),
        isEmpty,
      );
    });

    test('saveTimetableOverride rejects Friday and wrong-weekday dates', () async {
      final base = buildVersion(teacher: 'Ms. Fatima', period: 1);

      final friday = await timetableService.saveTimetableOverride(
        base,
        date: DateTime(2026, 11, 13), // Friday
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );
      expect(friday, isNull);

      final thursday = await timetableService.saveTimetableOverride(
        base,
        date: DateTime(2026, 11, 19), // Thursday, base is Wednesday
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
      );
      expect(thursday, isNull);
      expect(timetableService.getCachedVersions('11D', 'Wednesday'), isEmpty);
    });
  });

  group('M3e: substitute period model', () {
    test('TimetablePeriod round-trips substitute metadata', () {
      const period = TimetablePeriod(
        periodNumber: 1,
        timeSlot: '07:45 - 08:30',
        subject: 'Mathematics',
        teacherName: 'Mr. Ahmed',
        room: 'Room 12',
        dayOfWeek: 'Wednesday',
        classLevel: '11D',
        isSubstitute: true,
        originalTeacherName: 'Ms. Fatima',
      );
      final restored = TimetablePeriod.fromMap(period.toMap());
      expect(restored, period);
      expect(restored.isSubstitute, isTrue);
      expect(restored.originalTeacherName, 'Ms. Fatima');
    });
  });

  group('M3f: teacher editor UI (copy, override, substitute, conflicts)', () {
    testWidgets('copy dialog copies only the selected days as drafts',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedTeacherProfile();
      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(
            classId: '11D',
            initialDay: 'Saturday',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('copy_timetable_days_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copy_timetable_dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('copy_target_Monday')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('copy_timetable_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Copied to Monday'), findsOneWidget);
      expect(timetableService.getCachedVersions('11D', 'Monday').length, 1);
      expect(timetableService.getCachedVersions('11D', 'Tuesday'), isEmpty);
      expect(timetableService.getCachedVersions('11D', 'Sunday'), isEmpty);
    });

    testWidgets('override mode offers substitute assignment and saves a dated version',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final overrideDate = DateTime(2026, 11, 18);
      await seedTeacherProfile();
      await tester.pumpWidget(
        MaterialApp(
          home: TeacherTimetableEditorScreen(
            classId: '11D',
            initialDay: 'Wednesday',
            initialOverrideDate: overrideDate,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_override_banner')), findsOneWidget);
      expect(find.textContaining('ONE-DAY OVERRIDE'), findsOneWidget);

      await tester.tap(find.byKey(const Key('period_1_substitute_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('substitute_dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('substitute_name_field')),
        'Mr. Ahmed',
      );
      await tester.enterText(
        find.byKey(const Key('substitute_uid_field')),
        'uid_ahmed',
      );
      await tester.tap(find.byKey(const Key('substitute_confirm_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Substitute: Mr. Ahmed'), findsWidgets);

      await tester.tap(find.byKey(const Key('save_timetable_draft_button')));
      await tester.pumpAndSettle();

      final versions = timetableService.getCachedVersions('11D', 'Wednesday');
      expect(versions, isNotEmpty);
      expect(versions.first.isTemporary, isTrue);
      expect(versions.first.overrideDate, overrideDate);
      expect(versions.first.slots.first.substituteTeacherName, 'Mr. Ahmed');
      expect(find.textContaining('One-day override draft'), findsOneWidget);
    });

    testWidgets('student sees temporary banner and substitute indicator',
        (tester) async {
      await seedStudentProfile();
      final recurring = await publish(
        buildVersion(teacher: 'Ms. Fatima', teacherUid: 'uid_fatima', period: 1),
      );
      final overrideBase = recurring.copyWith(
        slots: recurring.slots.map((s) {
          if (s.periodNumber != 1) return s;
          return s.copyWith(
            substituteTeacherName: 'Mr. Ahmed',
            substituteTeacherUid: 'uid_ahmed',
          );
        }).toList(),
      );
      final override = await timetableService.saveTimetableOverride(
        overrideBase,
        date: DateTime(2026, 11, 18),
        actorUid: 'uid_fatima',
        actorName: 'Ms. Fatima',
        publish: true,
      );
      expect(override, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableTab(
              classLevel: '11D',
              initialDay: 'Wednesday',
              mockNow: DateTime(2026, 11, 18, 6),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('temporary_timetable_banner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('substitute_badge_p1')), findsOneWidget);
      expect(find.textContaining('Substitute: Mr. Ahmed'), findsWidgets);
    });

    testWidgets('publishing is blocked with a clear conflict dialog',
        (tester) async {
      await seedTeacherProfile();

      // Load the editor with a real draft that contains the conflicting teacher.
      await timetableService.saveTimetableDraft(
        buildVersion(
          classId: '11D',
          teacher: 'Ms. Fatima',
          teacherUid: 'uid_fatima',
          period: 1,
        ),
      );
      await publish(
        buildVersion(
          classId: '10A',
          teacher: 'Ms. Fatima',
          teacherUid: 'uid_fatima',
          period: 1,
        ),
        enforceConflicts: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherTimetableEditorScreen(
            classId: '11D',
            initialDay: 'Wednesday',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish_timetable_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_conflict_dialog')), findsOneWidget);
      expect(find.textContaining('already booked'), findsWidgets);
      expect(
        timetableService
            .getCachedVersions('11D', 'Wednesday')
            .where((v) => v.isPublished),
        isEmpty,
      );
    });
  });

  group('M3g: rules source contract (client-side conflict caveat)', () {
    late String rulesContent;

    setUpAll(() {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);
      rulesContent = rulesFile.readAsStringSync();
    });

    test('rules whitelist override dates and substitute fields', () {
      expect(rulesContent.contains("'override_date'"), isTrue);
      expect(rulesContent.contains('data.override_date is timestamp'), isTrue);
      expect(rulesContent.contains("'substitute_teacher_name'"), isTrue);
      expect(rulesContent.contains("'substitute_teacher_uid'"), isTrue);
      expect(
        rulesContent.contains('slot.substitute_teacher_name.size() <= 100'),
        isTrue,
      );
      expect(
        rulesContent.contains('slot.substitute_teacher_uid.size() <= 128'),
        isTrue,
      );
    });

    test('rules expose published schedules to signed-in users for cross-class checks',
        () {
      final matchStart = rulesContent.indexOf('match /timetable_versions/{versionId}');
      final createStart = rulesContent.indexOf('allow create:', matchStart);
      expect(matchStart, greaterThanOrEqualTo(0));
      expect(createStart, greaterThan(matchStart));
      final readBlock = rulesContent.substring(matchStart, createStart);
      expect(
        readBlock.contains("resource.data.status == 'published'"),
        isTrue,
      );
      expect(readBlock.contains('isSignedIn()'), isTrue);
    });

    test('rules audit whitelist accepts copy and substitute actions', () {
      expect(rulesContent.contains("'copy'"), isTrue);
      expect(rulesContent.contains("'substitute'"), isTrue);
    });
  });
}
