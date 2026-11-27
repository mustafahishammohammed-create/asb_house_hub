import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/timetable_service.dart';
import 'package:asb_house_hub/screens/admin_academics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    await TimetableService.initPreferences();
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
    TimetableService.firestoreFailureSimulated = null;
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
    TimetableService.firestoreFailureSimulated = null;
  });

  group('M7 Acceptance Test 55: Grade Management LKG–12 & Progression', () {
    test('gradeLevels hierarchy covers all 14 grades in order', () {
      expect(AcademicStructure.gradeLevels.length, 14);
      expect(AcademicStructure.gradeLevels.first, 'LKG');
      expect(AcademicStructure.gradeLevels[1], 'UKG');
      expect(AcademicStructure.gradeLevels[2], 'Grade 1');
      expect(AcademicStructure.gradeLevels.last, 'Grade 12');
    });

    test('nextGrade progresses each grade through LKG to Grade 12', () {
      expect(AcademicStructure.nextGrade('LKG'), 'UKG');
      expect(AcademicStructure.nextGrade('UKG'), 'Grade 1');
      expect(AcademicStructure.nextGrade('Grade 1'), 'Grade 2');
      expect(AcademicStructure.nextGrade('Grade 10'), 'Grade 11');
      expect(AcademicStructure.nextGrade('Grade 11'), 'Grade 12');
      expect(AcademicStructure.nextGrade('Grade 12'), isNull);
      expect(AcademicStructure.nextGrade('invalid'), isNull);
    });

    test('nextClassId advances class id while strictly preserving section letter', () {
      expect(AcademicStructure.nextClassId('LKG-A'), 'UKG-A');
      expect(AcademicStructure.nextClassId('UKG-B'), '1B');
      expect(AcademicStructure.nextClassId('1C'), '2C');
      expect(AcademicStructure.nextClassId('10A'), '11A');
      expect(AcademicStructure.nextClassId('11D'), '12D');
      expect(AcademicStructure.nextClassId('12A'), isNull);
      expect(AcademicStructure.nextClassId('invalid'), isNull);
    });
  });

  group('M7 Acceptance Test 56: Section Management (Create/Activate/Deactivate)', () {
    test('saveAcademicClass creates and stores class section', () async {
      final auth = AuthService();
      const cls = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
        active: true,
      );

      final ok = await auth.saveAcademicClass(cls);
      expect(ok, isTrue);

      final cached = AuthService.getCachedAcademicClasses();
      expect(cached.any((c) => c.classId == '11D' && c.classTeacher == 'Ms. Fatima'), isTrue);
    });

    test('setClassActive toggles active status without deleting section', () async {
      final auth = AuthService();
      const cls = AcademicClass(
        classId: '11B',
        grade: 'Grade 11',
        section: 'B',
        active: true,
      );
      await auth.saveAcademicClass(cls);

      final deactivated = await auth.setClassActive('11B', false);
      expect(deactivated, isTrue);

      final cached = AuthService.getCachedAcademicClasses();
      final section = cached.firstWhere((c) => c.classId == '11B');
      expect(section.active, isFalse);

      final reactivated = await auth.setClassActive('11B', true);
      expect(reactivated, isTrue);
      final sectionReactivated = AuthService.getCachedAcademicClasses().firstWhere((c) => c.classId == '11B');
      expect(sectionReactivated.active, isTrue);
    });

    test('updateClassTimetablePermissions updates assigned editors and approval switch', () async {
      final auth = AuthService();
      const cls = AcademicClass(
        classId: '11C',
        grade: 'Grade 11',
        section: 'C',
        active: true,
      );
      await auth.saveAcademicClass(cls);

      final updated = await auth.updateClassTimetablePermissions(
        classId: '11C',
        timetableEditorUids: ['uid_teacher_1', 'uid_teacher_2'],
        timetableRequiresApproval: true,
      );
      expect(updated, isTrue);

      final cached = AuthService.getCachedAcademicClasses().firstWhere((c) => c.classId == '11C');
      expect(cached.timetableEditorUids, ['uid_teacher_1', 'uid_teacher_2']);
      expect(cached.timetableRequiresApproval, isTrue);
    });
  });

  group('M7 Acceptance Test 57: Approve Class Assignments & Transfers', () {
    test('verifyStudentClass approves student placement and caches ack', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'ruby',
        'class_id': '11D',
        'class_verified': false,
        'role': 'student',
      });

      final ok = await auth.verifyStudentClass(
        scholarNo: '11209',
        classId: '11D',
      );
      expect(ok, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['class_verified'], isTrue);
      expect(profile?['class_id'], '11D');
    });

    test('transferStudentClass moves scholar to target class with auto-verification', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'ruby',
        'class_id': '11D',
        'class_level': 'Grade 11',
        'division': 'D',
        'class_verified': true,
        'role': 'student',
      });

      final ok = await auth.transferStudentClass(
        scholarNo: '11209',
        classId: '11B',
      );
      expect(ok, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['class_id'], '11B');
      expect(profile?['class_level'], 'Grade 11');
      expect(profile?['division'], 'B');
      expect(profile?['class_verified'], isTrue);
      // House must remain strictly unchanged!
      expect(profile?['house_name'], 'ruby');
    });

    test('transferStudentClass rejects invalid canonical class ids', () async {
      final auth = AuthService();
      final ok = await auth.transferStudentClass(
        scholarNo: '11209',
        classId: 'invalid-class',
      );
      expect(ok, isFalse);
    });
  });

  group('M7 Acceptance Test 58: Manage House Assignments', () {
    test('assignStudentHouse updates house and strictly preserves class identity', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'ruby',
        'class_id': '11D',
        'class_level': 'Grade 11',
        'division': 'D',
        'class_verified': true,
        'role': 'student',
      });

      final ok = await auth.assignStudentHouse(
        scholarNo: '11209',
        houseName: 'sapphire',
      );
      expect(ok, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['house_name'], 'sapphire');
      // CRITICAL: Class placement must not be disturbed!
      expect(profile?['class_id'], '11D');
      expect(profile?['class_verified'], isTrue);
    });

    test('assignStudentHouse rejects unknown houses', () async {
      final auth = AuthService();
      final ok = await auth.assignStudentHouse(
        scholarNo: '11209',
        houseName: 'gryffindor',
      );
      expect(ok, isFalse);
    });
  });

  group('M7 Acceptance Test 59: Academic Year Promotion (Spec §9.5)', () {
    test('promoteScholar promotes scholar and strictly preserves house assignment', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'topaz',
        'class_id': '11D',
        'class_level': 'Grade 11',
        'division': 'D',
        'class_verified': true,
        'role': 'student',
      });

      final ok = await auth.promoteScholar(
        scholarNo: '11209',
        targetClassId: '12D',
        academicYear: '2027-2028',
      );
      expect(ok, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['class_id'], '12D');
      expect(profile?['class_level'], 'Grade 12');
      expect(profile?['division'], 'D');
      expect(profile?['class_verified'], isTrue);
      // SPEC §9.5 CRITICAL RULE: House must remain unchanged!
      expect(profile?['house_name'], 'topaz');
    });

    test('promoteClassSection batch promotes students and reports truthful results', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'emerald',
        'class_id': '11A',
        'class_level': 'Grade 11',
        'division': 'A',
        'class_verified': true,
        'role': 'student',
      });

      final result = await auth.promoteClassSection(
        sourceClassId: '11A',
        targetClassId: '12A',
        academicYear: '2027-2028',
      );

      expect(result.total, 1);
      expect(result.promoted, 1);
      expect(result.failed, 0);
      expect(result.isCompleteSuccess, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['class_id'], '12A');
      expect(profile?['house_name'], 'emerald');
    });

    test('promoteClassSection rejects invalid source or target classes', () async {
      final auth = AuthService();
      final result = await auth.promoteClassSection(
        sourceClassId: 'invalid-source',
        targetClassId: '12A',
      );
      expect(result.total, 0);
      expect(result.promoted, 0);
    });

    test('promoteClassSection reports a roster lookup failure truthfully', () async {
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('roster unavailable');

      final result = await AuthService().promoteClassSection(
        sourceClassId: '11A',
        targetClassId: '12A',
      );

      expect(result.hasError, isTrue);
      expect(result.error, contains('roster unavailable'));
      expect(result.isCompleteSuccess, isFalse);
      expect(result.promoted, 0);
      expect(result.failed, 0);
    });

    test('promoteClassSection counts scholars without a scholar number as failed',
        () async {
      await AuthService.cacheProfile({
        'uid': 'uid_no_scholar',
        'full_name': 'Missing Scholar Number',
        'house_name': 'ruby',
        'class_id': '11A',
        'class_verified': true,
        'role': 'student',
      });

      final result = await AuthService().promoteClassSection(
        sourceClassId: '11A',
        targetClassId: '12A',
      );

      expect(result.total, 1);
      expect(result.promoted, 0);
      expect(result.failed, 1);
      expect(result.hasFailures, isTrue);
      expect(result.isCompleteSuccess, isFalse);
      expect(result.failedScholarNumbers, contains('uid_no_scholar'));
    });
  });

  group('M7 Acceptance Test 36: Timetable Approval Queue', () {
    test('submitted timetable is streamable in the approval queue', () async {
      final tt = TimetableService();
      final submitted = ClassTimetableVersion(
        id: 'tt_11D_Monday_v1_sub',
        classId: '11D',
        dayOfWeek: 'Monday',
        version: 1,
        effectiveFrom: DateTime(2026, 11, 1),
        status: TimetableStatus.submitted,
        createdByUid: 'uid_teacher_1',
        createdByName: 'Mr. Sharma',
        slots: [
          const TimetableSlot(
            periodNumber: 1,
            subject: 'Physics',
            teacherName: 'Mr. Sharma',
            teacherUid: 'uid_teacher_1',
            room: 'Lab 2',
            startMinute: 480,
          ),
        ],
      );

      await tt.cacheVersions('11D', 'Monday', [submitted]);
      final queueStream = tt.getSubmittedTimetableQueueStream(classId: '11D');
      final items = await queueStream.first;
      expect(items.length, 1);
      expect(items.first.id, 'tt_11D_Monday_v1_sub');
      expect(items.first.status, TimetableStatus.submitted);
    });

    test('publishTimetable approves submitted version and writes publish audit', () async {
      final tt = TimetableService();
      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Monday',
        effectiveFrom: DateTime(2026, 11, 1),
      );
      final version = template.copyWith(
        id: 'tt_11D_Monday_v1_publish_test',
        status: TimetableStatus.submitted,
        createdByUid: 'uid_teacher_1',
        createdByName: 'Mr. Sharma',
      );

      final ok = await tt.publishTimetable(
        version,
        publisherUid: 'admin_uid',
        publisherName: 'Principal Office',
        enforceConflicts: false,
      );
      expect(ok, isTrue);

      final active = tt.getCachedActiveVersion('11D', 'Monday', DateTime(2026, 11, 2));
      expect(active, isNotNull);
      expect(active?.status, TimetableStatus.published);
      expect(active?.approvedByUid, 'admin_uid');

      final audits = tt.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'publish'), isTrue);
    });

    test('rejectTimetable rejects submitted version with truthful reason', () async {
      final tt = TimetableService();
      final version = ClassTimetableVersion(
        id: 'tt_11D_Monday_v1_reject_test',
        classId: '11D',
        dayOfWeek: 'Monday',
        version: 1,
        effectiveFrom: DateTime(2026, 11, 1),
        status: TimetableStatus.submitted,
        createdByUid: 'uid_teacher_1',
        createdByName: 'Mr. Sharma',
        slots: [],
      );

      final ok = await tt.rejectTimetable(
        version,
        reason: 'Period 3 room assignment conflicts with assembly',
        reviewerUid: 'admin_uid',
        reviewerName: 'Academic Coordinator',
      );
      expect(ok, isTrue);

      final cached = tt.getCachedVersions('11D', 'Monday');
      final rejected = cached.firstWhere((v) => v.id == version.id);
      expect(rejected.status, TimetableStatus.rejected);
      expect(rejected.rejectionReason, contains('conflicts with assembly'));

      final audits = tt.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'reject' && a['details'].contains('conflicts with assembly')), isTrue);
    });

    test('rejectTimetable rejects empty reasons and over-limit reasons', () async {
      final tt = TimetableService();
      final version = ClassTimetableVersion(
        id: 'tt_11D_Monday_v1_reject_validation',
        classId: '11D',
        dayOfWeek: 'Monday',
        version: 1,
        effectiveFrom: DateTime(2026, 11, 1),
        status: TimetableStatus.submitted,
      );

      expect(
        await tt.rejectTimetable(version, reason: '   ', reviewerUid: 'uid', reviewerName: 'name'),
        isFalse,
      );
      expect(
        await tt.rejectTimetable(version, reason: 'a' * 501, reviewerUid: 'uid', reviewerName: 'name'),
        isFalse,
      );
    });
  });

  group('M7 Acceptance Test 37: Timetable Override & Restore', () {
    test('saveTimetableOverride creates one-day temporary override preserving recurring schedule', () async {
      final tt = TimetableService();
      final recurring = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Monday',
        effectiveFrom: DateTime(2026, 11, 1),
      ).copyWith(
        id: 'tt_11D_Monday_v1_recurring',
        status: TimetableStatus.published,
      );
      await tt.cacheVersions('11D', 'Monday', [recurring]);

      final overrideDate = DateTime(2026, 11, 9);
      final override = await tt.saveTimetableOverride(
        recurring,
        date: overrideDate,
        actorUid: 'admin_uid',
        actorName: 'Admin',
        publish: true,
      );

      expect(override, isNotNull);
      expect(override?.isTemporary, isTrue);
      expect(override?.overrideDate, overrideDate);

      // Audits must record override
      final audits = tt.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'override'), isTrue);
    });

    test('restoreTimetableVersion restores prior version into a new version document', () async {
      final tt = TimetableService();
      final v1 = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Monday',
        effectiveFrom: DateTime(2026, 11, 1),
      ).copyWith(
        id: 'tt_11D_Monday_v1_orig',
        status: TimetableStatus.published,
      );
      await tt.cacheVersions('11D', 'Monday', [v1]);

      final restored = await tt.restoreTimetableVersion(
        targetVersion: v1,
        newEffectiveFrom: DateTime(2026, 11, 15),
        actorUid: 'admin_uid',
        actorName: 'Principal',
        publishImmediately: false,
      );

      expect(restored, isNotNull);
      expect(restored?.version, 2);
      expect(restored?.supersedesId, v1.id);
      expect(restored?.status, TimetableStatus.draft);

      final audits = tt.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'restore'), isTrue);
    });
  });

  group('M7 Acceptance Test 63: Audit Log Viewer & Immutable Append-Only Logs', () {
    test('writeTimetableAudit appends immutable entry and streams across filters', () async {
      final tt = TimetableService();
      await tt.writeTimetableAudit(
        action: 'publish',
        classId: '11D',
        dayOfWeek: 'Monday',
        actorUid: 'uid_admin_1',
        actorName: 'Vice Principal',
        details: 'Published recurring version 1',
      );
      await tt.writeTimetableAudit(
        action: 'promotion',
        classId: '11D',
        dayOfWeek: 'Monday',
        actorUid: 'uid_admin_1',
        actorName: 'Vice Principal',
        details: 'Promoted 24 scholars from 11D to 12D',
      );

      final streamAll = tt.getAllTimetableAuditsStream(classId: '11D');
      final allLogs = await streamAll.first;
      expect(allLogs.length, 2);

      final streamPromotionOnly = tt.getAllTimetableAuditsStream(
        classId: '11D',
        actionFilter: 'promotion',
      );
      final promotionLogs = await streamPromotionOnly.first;
      expect(promotionLogs.length, 1);
      expect(promotionLogs.first['action'], 'promotion');
    });

    test('firestore.rules enforces append-only and admin reads on timetable_audit', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match = RegExp(
        r'match /timetable_audit/\{auditId\} \{([\s\S]*?)\}',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;

      expect(body.contains('allow read: if isAdmin();'), isTrue);
      expect(body.contains('allow update, delete: if false;'), isTrue);
      expect(body.contains('isValidTimetableAudit'), isTrue);
    });
  });

  group('M7 Acceptance Test 64: User Status & Unauthorized Admin Blocking', () {
    test('setUserStatus updates user status (active, suspended, deactivated)', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Mustafa Hisham',
        'house_name': 'ruby',
        'role': 'student',
        'status': 'active',
      });

      final ok = await auth.setUserStatus(scholarNo: '11209', status: 'suspended');
      expect(ok, isTrue);

      final profile = AuthService.getCachedProfile();
      expect(profile?['status'], 'suspended');
    });

    test('setUserStatus rejects invalid status strings', () async {
      final auth = AuthService();
      final ok = await auth.setUserStatus(scholarNo: '11209', status: 'banned_forever');
      expect(ok, isFalse);
    });

    testWidgets('unauthorized non-staff roles see lock screen on AdminAcademicsScreen', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '99999',
        'full_name': 'Regular Student',
        'role': 'student',
        'house_name': 'ruby',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminAcademicsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Academic management is restricted to school staff and administrators.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      // Admin action tabs must NOT be present
      expect(find.text('Promotion'), findsNothing);
      expect(find.text('Approvals'), findsNothing);
      expect(find.text('Audit Logs'), findsNothing);
    });

    testWidgets('authorized staff account mounts all 6 tabs in Admin Command Center', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': 'admin_1',
        'full_name': 'Admin User',
        'role': 'principal',
        'house_name': 'ruby',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminAcademicsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Academic Management'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Rosters'), findsOneWidget);
      expect(find.text('Promotion'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);
    });

    testWidgets('admin, head, and management can open and message any class from Classes & Rosters tabs', (tester) async {
      await AuthService.cacheProfile({
        'uid': 'uid_head_1',
        'scholar_no': 'HEAD01',
        'full_name': 'School Head',
        'role': 'head',
        'house_name': 'ruby',
      });
      await AuthService.cacheAcademicClasses([
        const AcademicClass(
          classId: '11D',
          grade: 'Grade 11',
          section: 'D',
          active: true,
          classTeacher: 'Ms. Fatima',
          classTeacherUid: 'uid_teacher_1',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminAcademicsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Classes'));
      await tester.pumpAndSettle();

      final openChatBtn = find.byKey(const Key('admin_open_class_group_11D'));
      expect(openChatBtn, findsOneWidget);
      await tester.tap(openChatBtn);
      await tester.pumpAndSettle();

      expect(find.text('11D Class Group'), findsOneWidget);
      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('class_group_send_button')), findsOneWidget);
    });

    test('firestore.rules restricts academic_classes writes to admin only', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match = RegExp(
        r'match /academic_classes/\{classId\} \{([\s\S]*?)\}',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;

      expect(body.contains('allow create: if isAdmin()'), isTrue);
      expect(body.contains('allow update: if isAdmin()'), isTrue);
      expect(body.contains('allow delete: if isAdmin();'), isTrue);
    });

    test('firestore.rules forbids regular owners from changing status or role', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match = RegExp(
        r'match /users/\{userId\} \{([\s\S]*?)match /notifications',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;

      // isOwner branch must include status, role, class_id in immutable fields
      expect(body.contains("'status'"), isTrue);
      expect(body.contains("'role'"), isTrue);
      expect(body.contains("'class_id'"), isTrue);
    });
  });
}
