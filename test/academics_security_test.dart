import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/models/academic_report_card.dart';
import 'package:asb_house_hub/models/medical_leave_request.dart';
import 'package:asb_house_hub/screens/admin_claims_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.firestoreFailureSimulated = null;
    AuthService.isFirebaseLiveOverride = null;
  });

  tearDown(() {
    AuthService.firestoreFailureSimulated = null;
    AuthService.isFirebaseLiveOverride = null;
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

    testWidgets('Faculty / SuperAdmin sees both Point Claims and Medical Reports tabs', (tester) async {
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

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Point Claims'), findsOneWidget);
      expect(find.text('Medical Reports'), findsOneWidget);
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
}
