import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/models/academic_report_card.dart';
import 'package:asb_house_hub/models/medical_leave_request.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/models/timetable_period.dart';
import 'package:asb_house_hub/models/attendance_record.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/screens/admin_claims_screen.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    await GamificationSecurityService.initPreferences();
    await GamificationSecurityService.clearCooldowns();
    GamificationSecurityService.resetConsumedNoncesForTesting();
    GamificationSecurityService.setTestSecret('test-secret-key-12345');
    AuthService.firestoreFailureSimulated = null;
    AuthService.isFirebaseLiveOverride = null;
  });

  tearDown(() {
    AuthService.firestoreFailureSimulated = null;
    AuthService.isFirebaseLiveOverride = null;
    GamificationSecurityService.setTestSecret(null);
  });

  group('P0-1 (A1): Report Cards Read Rules & Stream Error Fallback', () {
    test('firestore.rules restricts report-card reads to admin or scholar owner', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match = RegExp(
        r'match /report_cards/\{reportCardId\} \{([\s\S]*?)\}',
      ).firstMatch(rules);
      expect(match, isNotNull, reason: 'report_cards match block not found');
      final body = match!.group(1)!;

      // Must NOT allow blanket isSignedIn()
      expect(
        body.contains('allow read: if isSignedIn();'),
        isFalse,
        reason: 'Report cards must not be world-readable to all signed in users',
      );

      // Must require isAdmin() or isScholarOwner
      expect(
        body.contains('isAdmin()'),
        isTrue,
        reason: 'Report cards must allow admin reads',
      );
      expect(
        body.contains('isScholarOwner'),
        isTrue,
        reason: 'Report cards must allow owner reads scoped by scholar_no',
      );
    });

    test('getReportCardsStream returns cached cards when stream errors', () async {
      final auth = AuthService();
      final card = AcademicReportCard(
        id: 'rep_fallback_test',
        scholarNo: '11209',
        studentName: 'Fallback Student',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.85,
        overallPercentage: 92.0,
        publishedAt: DateTime(2026, 11, 1),
      );
      await AuthService.cacheReportCards([card], classLevel: 'Grade 10', scholarNo: '11209', termName: 'Term 1 Mid-Term');

      // Offline / non-live mode returns cached stream
      final stream = auth.getReportCardsStream(classLevel: 'Grade 10', scholarNo: '11209', term: 'Term 1 Mid-Term');
      final result = await stream.first;
      expect(result.length, 1);
      expect(result.first.id, 'rep_fallback_test');
    });
  });

  group('P0-2 (A3): Medical Leaves Truthful Writes & Real Errors', () {
    test('submitMedicalLeaveRequest returns false on Firestore failure and does not cache', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Test Student',
        'house': 'ruby',
        'role': 'student',
        'class_id': '10A',
        'class_verified': true,
      });

      // Simulate live failure
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.submitMedicalLeaveRequest(
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        reason: 'Severe flu',
        doctorName: 'Dr. Smith',
      );

      expect(ok, isFalse, reason: 'Must return false on Firestore error');
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached, isEmpty, reason: 'Cache must not record failed leave submissions');
    });

    test('submitMedicalLeaveRequest succeeds and updates cache on acknowledged write', () async {
      final auth = AuthService();
      AuthService.firestoreFailureSimulated = null;

      final ok = await auth.submitMedicalLeaveRequest(
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        reason: 'Severe flu',
        doctorName: 'Dr. Smith',
      );

      expect(ok, isTrue);
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached.length, 1);
      expect(cached.first.reason, 'Severe flu');
      expect(cached.first.status, MedicalLeaveStatus.pending);
    });

    test('approveMedicalLeave returns false on Firestore failure and does not mutate cache', () async {
      final auth = AuthService();
      final initialRequest = MedicalLeaveRequest(
        id: 'med_test_1',
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        reason: 'Flu',
        doctorName: 'Dr. Smith',
        submittedAt: DateTime.now(),
        status: MedicalLeaveStatus.pending,
      );
      await AuthService.cacheMedicalLeaves([initialRequest]);

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Admin permission required',
      );

      final ok = await auth.approveMedicalLeave(
        leaveId: 'med_test_1',
        reviewerName: 'Mr. Teacher',
      );

      expect(ok, isFalse);
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached.first.status, MedicalLeaveStatus.pending, reason: 'Status must stay pending on failure');
      expect(cached.first.reviewedBy, isNull);
    });

    test('rejectMedicalLeave returns false on Firestore failure and does not mutate cache', () async {
      final auth = AuthService();
      final initialRequest = MedicalLeaveRequest(
        id: 'med_test_2',
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        reason: 'Flu',
        doctorName: 'Dr. Smith',
        submittedAt: DateTime.now(),
        status: MedicalLeaveStatus.pending,
      );
      await AuthService.cacheMedicalLeaves([initialRequest]);

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Admin permission required',
      );

      final ok = await auth.rejectMedicalLeave(
        leaveId: 'med_test_2',
        reviewerName: 'Mr. Teacher',
      );

      expect(ok, isFalse);
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached.first.status, MedicalLeaveStatus.pending, reason: 'Status must stay pending on failure');
    });

    test('getMedicalLeavesStream returns cached list on fallback', () async {
      final auth = AuthService();
      final request = MedicalLeaveRequest(
        id: 'med_cached_stream',
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        reason: 'Dentist visit',
        doctorName: 'Dr. White',
        submittedAt: DateTime.now(),
        status: MedicalLeaveStatus.pending,
      );
      await AuthService.cacheMedicalLeaves([request]);

      final stream = auth.getMedicalLeavesStream(scholarNo: '11209');
      final emitted = await stream.first;
      expect(emitted.length, 1);
      expect(emitted.first.id, 'med_cached_stream');
    });
  });

  group('P0-3 (A3): Hide Medical Reports Tab From Non-Staff', () {
    testWidgets('Council officer or house captain sees only Point Claims tab', (tester) async {
      // Set role to captain / council
      await AuthService.cacheProfile({
        'scholar_no': '231001',
        'full_name': 'Captain Alice',
        'house': 'ruby',
        'role': 'captain',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminClaimsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Point Claims must be visible
      expect(find.byType(TabBar), findsNothing, reason: 'Single tab mode should not render TabBar');
      expect(find.text('Medical Reports'), findsNothing, reason: 'Captains/council must NOT see Medical Reports');
    });

    testWidgets('Teachers see their workspace without claim review controls', (tester) async {
      // Set role to teacher / faculty
      await AuthService.cacheProfile({
        'scholar_no': 'FACULTY_01',
        'full_name': 'Professor McGonagall',
        'house': 'emerald',
        'role': 'teacher',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminClaimsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teacher Workspace'), findsOneWidget);
      expect(find.text('Point Claims'), findsNothing);
      expect(find.textContaining('assigned class teacher'), findsOneWidget);
      expect(find.byTooltip('1-on-1 Chats'), findsOneWidget);
    });
  });

  group('P0-4 (A3): Medical Leave Rules Validator & Transition Guard', () {
    test('firestore.rules contains isValidMedicalLeave with whitelist and photo cap', () {
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules.contains('function isValidMedicalLeave(data)'), isTrue);

      final fnMatch = RegExp(r'function isValidMedicalLeave\(data\) \{([\s\S]*?)\}').firstMatch(rules);
      expect(fnMatch, isNotNull);
      final body = fnMatch!.group(1)!;

      // Whitelist check
      expect(body.contains('hasOnlyAllowedFields'), isTrue);
      expect(body.contains('hasRequiredFields'), isTrue);
      expect(body.contains('certificate_photo'), isTrue);
      expect(body.contains('500000'), isTrue, reason: 'Certificate photo must be capped at 500k bytes/chars');

      // Status values check
      expect(body.contains("'pending', 'approved', 'rejected'"), isTrue);
    });

    test('firestore.rules enforces pending transition guard and immutable fields on medical_leaves update', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match = RegExp(r'match /medical_leaves/\{leaveId\} \{([\s\S]*?)\}').firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;

      // Create rule requires pending status
      expect(body.contains("request.resource.data.status == 'pending'"), isTrue);
      expect(body.contains('isValidMedicalLeave(request.resource.data)'), isTrue);

      // Update rule requires existing status == 'pending' and new status in ['approved', 'rejected']
      expect(body.contains("resource.data.status == 'pending'"), isTrue);
      expect(body.contains("request.resource.data.status in ['approved', 'rejected']"), isTrue);

      // Core fields cannot be modified during review
      expect(
        body.contains("affectedKeys().hasOnly(['status', 'reviewed_by', 'reviewed_at', 'admin_remark'])"),
        isTrue,
        reason: 'Review updates must only touch review fields',
      );
    });
  });

  group('P0-5 (A3): Real Reviewer Identity Recorded', () {
    test('approveMedicalLeave records authenticated reviewer name', () async {
      final auth = AuthService();
      final request = MedicalLeaveRequest(
        id: 'med_test_reviewer',
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        reason: 'Dental',
        doctorName: 'Dr. Green',
        submittedAt: DateTime.now(),
        status: MedicalLeaveStatus.pending,
      );
      await AuthService.cacheMedicalLeaves([request]);

      final ok = await auth.approveMedicalLeave(
        leaveId: 'med_test_reviewer',
        reviewerName: 'Vice Principal John Doe',
        adminRemark: 'Approved per medical note.',
      );

      expect(ok, isTrue);
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached.first.reviewedBy, 'Vice Principal John Doe');
      expect(cached.first.adminRemark, 'Approved per medical note.');
      expect(cached.first.status, MedicalLeaveStatus.approved);
    });

    test('rejectMedicalLeave records authenticated reviewer name', () async {
      final auth = AuthService();
      final request = MedicalLeaveRequest(
        id: 'med_test_reviewer_rej',
        scholarNo: '11209',
        studentName: 'Test Student',
        house: 'ruby',
        classLevel: 'Grade 10',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        reason: 'Headache',
        doctorName: 'Dr. Green',
        submittedAt: DateTime.now(),
        status: MedicalLeaveStatus.pending,
      );
      await AuthService.cacheMedicalLeaves([request]);

      final ok = await auth.rejectMedicalLeave(
        leaveId: 'med_test_reviewer_rej',
        reviewerName: 'Head of House Sapphire',
        adminRemark: 'Doctor certificate missing.',
      );

      expect(ok, isTrue);
      final cached = AuthService.getCachedMedicalLeaves();
      expect(cached.first.reviewedBy, 'Head of House Sapphire');
      expect(cached.first.adminRemark, 'Doctor certificate missing.');
      expect(cached.first.status, MedicalLeaveStatus.rejected);
    });
  });

  group('P1-1 (A2): Assignment Publish/Delete Truthful Writes & Gate', () {
    test('publishAssignment returns false on simulated Firestore failure and does not cache', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Teacher Staff',
        'role': 'teacher',
      });

      final assignment = AcademicAssignment(
        id: 'hw_test_fail',
        title: 'Failing Math Task',
        subject: 'Mathematics',
        teacherName: 'Teacher Staff',
        dueDateTime: DateTime.now().add(const Duration(days: 2)),
        pointsReward: 30,
        status: AssignmentStatus.pending,
        description: 'Test failure handling',
        classLevel: 'Grade 10',
      );

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.publishAssignment(
        assignment: assignment,
        classLevel: 'Grade 10',
      );

      expect(ok, isFalse, reason: 'publishAssignment must return false on Firestore error');
      final cached = AuthService.getCachedAssignments(classLevel: 'Grade 10');
      expect(cached.any((a) => a.id == 'hw_test_fail'), isFalse, reason: 'Cache must not be mutated on failed write');
    });

    test('deleteAssignment returns false on simulated Firestore failure and does not remove from cache', () async {
      final auth = AuthService();
      final assignment = AcademicAssignment(
        id: 'hw_test_del_fail',
        title: 'Do Not Delete Me',
        subject: 'Mathematics',
        teacherName: 'Teacher Staff',
        dueDateTime: DateTime.now().add(const Duration(days: 2)),
        pointsReward: 30,
        status: AssignmentStatus.pending,
        description: 'Testing delete denial',
        classLevel: 'Grade 10',
      );
      await AuthService.cacheAssignments([assignment], classLevel: 'Grade 10');

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.deleteAssignment(
        assignmentId: 'hw_test_del_fail',
        classLevel: 'Grade 10',
        subject: 'Mathematics',
      );

      expect(ok, isFalse, reason: 'deleteAssignment must return false on Firestore error');
      final cached = AuthService.getCachedAssignments(classLevel: 'Grade 10');
      expect(cached.any((a) => a.id == 'hw_test_del_fail'), isTrue, reason: 'Assignment must remain in cache if delete denied');
    });

    testWidgets('Student and Council users see no Add Task or Delete Assignment buttons', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Student User',
        'role': 'student',
        'house': 'ruby',
      });

      final assignment = AcademicAssignment(
        id: 'hw_student_view',
        title: 'Read Only Task',
        subject: 'Mathematics',
        teacherName: 'Staff Member',
        dueDateTime: DateTime.now().add(const Duration(days: 2)),
        pointsReward: 20,
        status: AssignmentStatus.pending,
        description: 'Solve problems 1-10',
        classLevel: 'Grade 10',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademicsScreen(
              initialTab: 'homework',
              classLevel: 'Grade 10',
              initialAssignments: [assignment],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_assignment_button')), findsNothing);
      expect(find.byKey(const Key('empty_add_assignment_button')), findsNothing);
      expect(find.byKey(Key('delete_assignment_${assignment.id}')), findsNothing);
    });

    testWidgets('Staff users see Add Task and Delete Assignment buttons', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Teacher Staff',
        'role': 'teacher',
        'house': 'ruby',
      });

      final assignment = AcademicAssignment(
        id: 'hw_teacher_view',
        title: 'Manageable Task',
        subject: 'Mathematics',
        teacherName: 'Teacher Staff',
        dueDateTime: DateTime.now().add(const Duration(days: 2)),
        pointsReward: 20,
        status: AssignmentStatus.pending,
        description: 'Solve problems 1-10',
        classLevel: 'Grade 10',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademicsScreen(
              initialTab: 'homework',
              classLevel: 'Grade 10',
              initialAssignments: [assignment],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_assignment_button')), findsOneWidget);
      expect(find.byKey(Key('delete_assignment_${assignment.id}')), findsOneWidget);
    });
  });

  group('P1-2 (A5): Timetable Bulk Ops Truthful Writes & Gate', () {
    test('clearTimetableForDay returns false on simulated Firestore failure and does not clear cache', () async {
      final auth = AuthService();
      final period = TimetablePeriod(
        periodNumber: 1,
        subject: 'Mathematics',
        teacherName: 'Mr. Ramanujan',
        room: 'Room 201',
        timeSlot: '08:00 - 08:45',
        dayOfWeek: 'Sunday',
        classLevel: 'Grade 10',
      );
      await AuthService.cacheTimetable([period], classLevel: 'Grade 10', dayOfWeek: 'Sunday');

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.clearTimetableForDay(dayOfWeek: 'Sunday', classLevel: 'Grade 10');

      expect(ok, isFalse, reason: 'clearTimetableForDay must return false on Firestore error');
      final cached = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
      expect(cached.isNotEmpty, isTrue, reason: 'Cache must not be wiped if delete was denied');
    });

    test('populateDefaultCBSEWeeklyTimetable returns false on simulated Firestore failure and does not update cache', () async {
      final auth = AuthService();
      await AuthService.cacheTimetable([], classLevel: 'Grade 10', dayOfWeek: 'Sunday');

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.populateDefaultCBSEWeeklyTimetable(classLevel: 'Grade 10');

      expect(ok, isFalse, reason: 'populateDefaultCBSEWeeklyTimetable must return false on Firestore error');
      final cached = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
      expect(cached.isEmpty, isTrue, reason: 'Cache must not be populated if batch write was denied');
    });

    testWidgets('Student sees read-only timetable without mutation affordances', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Student User',
        'role': 'student',
      });

      final period = TimetablePeriod(
        periodNumber: 1,
        subject: 'Mathematics',
        teacherName: 'Mr. Ramanujan',
        room: 'Room 201',
        timeSlot: '08:00 - 08:45',
        dayOfWeek: 'Sunday',
        classLevel: 'Grade 10',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademicsScreen(
              initialTab: 'timetable',
              initialDay: 'Sunday',
              classLevel: 'Grade 10',
              initialPeriods: [period],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_period_button')), findsNothing);
      expect(find.byKey(const Key('empty_add_period_button')), findsNothing);
      expect(find.byKey(const Key('populate_cbse_button')), findsNothing);
      expect(find.byKey(Key('edit_period_${period.periodNumber}')), findsNothing);
      expect(find.byKey(Key('delete_period_${period.periodNumber}')), findsNothing);
    });
  });

  group('P1-3 (A6): Faculty Role Lists Alignment Contract', () {
    test('firestore.rules isAdmin role list exactly matches HierarchyService.isTeacherOrFaculty roles', () {
      final rules = File('firestore.rules').readAsStringSync();
      final match =
          RegExp(r"function _hasStaffAdminRole\(\) \{([\s\S]*?)\}").firstMatch(rules) ??
              RegExp(r"function isAdmin\(\) \{([\s\S]*?)\}").firstMatch(rules);
      expect(match, isNotNull, reason: 'isAdmin/_hasStaffAdminRole function not found in firestore.rules');
      final body = match!.group(1)!;

      // Extract roles from request.auth.token.role in [...]
      final tokenMatch = RegExp(r"role in \[([^\]]+)\]").firstMatch(body);
      expect(tokenMatch, isNotNull, reason: 'role array not found in isAdmin()');
      final rawRoles = tokenMatch!.group(1)!;
      final rulesRoles = RegExp(r"'([^']+)'")
          .allMatches(rawRoles)
          .map((m) => m.group(1)!)
          .toSet();

      // HierarchyService.isTeacherOrFaculty known roles
      const clientFacultyRoles = {
        'teacher',
        'faculty',
        'principal',
        'staff',
        'faculty_advisor',
        'teacher_lead',
        'class_teacher',
        'subject_teacher',
      };

      for (final r in clientFacultyRoles) {
        expect(
          rulesRoles.contains(r),
          isTrue,
          reason: 'Role "$r" recognized by client HierarchyService must be authorized in firestore.rules isAdmin()',
        );
        expect(
          HierarchyService.isTeacherOrFaculty(role: r),
          isTrue,
          reason: 'HierarchyService must authorize role "$r"',
        );
      }
      expect(rulesRoles, equals(clientFacultyRoles));
    });
  });

  group('P1-4 (A6): Attendance Save Error Handling', () {
    test('markStudentAttendance returns false on simulated Firestore failure and does not update cache', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Teacher Staff',
        'role': 'teacher',
      });

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );

      final ok = await auth.markStudentAttendance(
        classLevel: 'Grade 10',
        scholarNo: '99999',
        status: AttendanceStatus.present,
        remarks: 'Test denial',
      );

      expect(ok, isFalse, reason: 'markStudentAttendance must return false on Firestore error');
      final cached = AuthService.getCachedAttendanceRecords(classLevel: 'Grade 10', scholarNo: '99999');
      expect(cached.isEmpty, isTrue, reason: 'Cache must not be updated if attendance save failed');
    });
  });

  group('P1-5 (A4): Honours Merit Claim Interim Hardening', () {
    test('claimReportCardHonoursMerit validates GPA against card doc and rejects spoofed caller GPA', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Honours Student',
        'house': 'ruby',
        'role': 'student',
      });

      // Card has GPA 3.50 (below 3.80 requirement)
      final card = AcademicReportCard(
        id: 'rep_gpa_low',
        scholarNo: '2310910',
        studentName: 'Honours Student',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.50,
        overallPercentage: 87.5,
        publishedAt: DateTime(2026, 11, 1),
        isMeritClaimed: false,
      );
      await AuthService.cacheReportCards([card], classLevel: 'Grade 10', scholarNo: '2310910');

      // Caller attempts to spoof gpa = 4.0
      final ok = await auth.claimReportCardHonoursMerit(
        reportCardId: 'rep_gpa_low',
        classLevel: 'Grade 10',
        scholarNo: '2310910',
        house: 'ruby',
        gpa: 4.0, // spoofed!
        pointsReward: 50,
      );

      expect(ok, isFalse, reason: 'Claim must be rejected because verified GPA from card is < 3.80');
      final cached = AuthService.getCachedReportCards(classLevel: 'Grade 10', scholarNo: '2310910');
      expect(cached.first.isMeritClaimed, isFalse, reason: 'Card must not be marked as claimed on rejection');
    });

    test('claimReportCardHonoursMerit rejects claim when scholar number mismatches card owner', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Honours Student',
        'house': 'ruby',
        'role': 'student',
      });

      final card = AcademicReportCard(
        id: 'rep_other_student',
        scholarNo: '9999999', // different scholar!
        studentName: 'Another Student',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.95,
        overallPercentage: 96.0,
        publishedAt: DateTime(2026, 11, 1),
        isMeritClaimed: false,
      );
      await AuthService.cacheReportCards([card], classLevel: 'Grade 10', scholarNo: '9999999');

      final ok = await auth.claimReportCardHonoursMerit(
        reportCardId: 'rep_other_student',
        classLevel: 'Grade 10',
        scholarNo: '2310910',
        house: 'ruby',
        gpa: 3.95,
        pointsReward: 50,
      );

      expect(ok, isFalse, reason: 'Claim must be rejected when caller does not own the card');
    });

    test('claimReportCardHonoursMerit rejects claim if distinction already claimed', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Honours Student',
        'house': 'ruby',
        'role': 'student',
      });

      final card = AcademicReportCard(
        id: 'rep_already_claimed',
        scholarNo: '2310910',
        studentName: 'Honours Student',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.90,
        overallPercentage: 95.0,
        publishedAt: DateTime(2026, 11, 1),
        isMeritClaimed: true, // Already claimed!
      );
      await AuthService.cacheReportCards([card], classLevel: 'Grade 10', scholarNo: '2310910');

      final ok = await auth.claimReportCardHonoursMerit(
        reportCardId: 'rep_already_claimed',
        classLevel: 'Grade 10',
        scholarNo: '2310910',
        house: 'ruby',
        gpa: 3.90,
        pointsReward: 50,
      );

      expect(ok, isFalse, reason: 'Claim must be rejected if distinction is already claimed');
    });

    test('claimReportCardHonoursMerit succeeds and awards points for qualifying unclaimed card', () async {
      final auth = AuthService();
      await AuthService.cacheProfile({
        'scholar_no': '2310910',
        'full_name': 'Honours Student',
        'house': 'ruby',
        'role': 'student',
      });

      final card = AcademicReportCard(
        id: 'rep_qualifying',
        scholarNo: '2310910',
        studentName: 'Honours Student',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.88,
        overallPercentage: 94.0,
        publishedAt: DateTime(2026, 11, 1),
        isMeritClaimed: false,
      );
      await AuthService.cacheReportCards([card], classLevel: 'Grade 10', scholarNo: '2310910');

      final ok = await auth.claimReportCardHonoursMerit(
        reportCardId: 'rep_qualifying',
        classLevel: 'Grade 10',
        scholarNo: '2310910',
        house: 'ruby',
        gpa: 3.88,
        pointsReward: 50,
      );

      expect(ok, isTrue, reason: 'Qualifying card claim should succeed');
      final cached = AuthService.getCachedReportCards(classLevel: 'Grade 10', scholarNo: '2310910');
      expect(cached.first.isMeritClaimed, isTrue, reason: 'Card must be marked claimed in cache');
    });
  });

  group('P1-6 (A8): Stop Fabricating Official Report Cards', () {
    test('AcademicReportCard does not fabricate principalRemarks or fixed section', () {
      final card = AcademicReportCard(
        id: 'rep_clean',
        scholarNo: '11209',
        studentName: 'Real Student',
        termName: 'Term 1 Final',
        overallGpa: 3.92,
        overallPercentage: 94.5,
        publishedAt: DateTime(2026, 11, 1),
      );

      expect(card.principalRemarks, isNull, reason: 'Model must not synthesize fake principal remarks');
      expect(card.section, isNull, reason: 'Model must not synthesize fake section');
      expect(card.status, equals('Published'), reason: 'Default status should be Published, not hardcoded Official');

      final map = card.toMap();
      expect(map.containsKey('principal_remarks'), isFalse);
      expect(map.containsKey('section'), isFalse);
    });

    test('AcademicReportCard round-trips stored fields without inventing values', () {
      final cardWithRemarks = AcademicReportCard(
        id: 'rep_with_remarks',
        scholarNo: '11209',
        studentName: 'Real Student',
        termName: 'Term 1 Final',
        overallGpa: 3.92,
        overallPercentage: 94.5,
        publishedAt: DateTime(2026, 11, 1),
        status: 'Official',
        section: 'B',
        principalRemarks: 'Real human endorsement from the Principal',
      );

      final map = cardWithRemarks.toMap();
      expect(map['principal_remarks'], equals('Real human endorsement from the Principal'));
      expect(map['section'], equals('B'));
      expect(map['status'], equals('Official'));

      final reconstructed = AcademicReportCard.fromMap(map);
      expect(reconstructed.principalRemarks, equals('Real human endorsement from the Principal'));
      expect(reconstructed.section, equals('B'));
      expect(reconstructed.status, equals('Official'));
    });
  });
}
