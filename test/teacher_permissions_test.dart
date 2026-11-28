import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/medical_leave_request.dart';
import 'package:asb_house_hub/screens/admin_academics_screen.dart';
import 'package:asb_house_hub/screens/admin_claims_screen.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/screens/class_group_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/chat_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const classes = [
    AcademicClass(classId: '10A', grade: 'Grade 10', section: 'A', classTeacherUid: 'teacher'),
    AcademicClass(classId: '10B', grade: 'Grade 10', section: 'B', classTeacherUid: 'other'),
    AcademicClass(classId: '10C', grade: 'Grade 10', section: 'C', classTeacherUid: 'other', subjectTeacherUids: ['teacher']),
  ];
  Future<void> signIn(String uid, String role) => AuthService.cacheProfile({
    'uid': uid, 'scholar_no': 's-$uid', 'full_name': uid, 'role': role,
  });
  MedicalLeaveRequest report(String id, String classId) => MedicalLeaveRequest(
    id: id, scholarNo: '12345', studentName: 'Pupil $id', house: 'ruby',
    classLevel: 'Grade 10', classId: classId, startDate: DateTime(2026, 11, 28),
    endDate: DateTime(2026, 11, 28), reason: 'Private diagnosis $id', submittedAt: DateTime(2026, 11, 28),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    await AuthService.cacheAcademicClasses(classes);
  });
  tearDown(() { AuthService.isFirebaseLiveOverride = null; AuthService.firestoreFailureSimulated = null; });

  test('teaching roles retain chat access but never claim review', () {
    for (final role in ['teacher', 'faculty', 'class_teacher', 'subject_teacher', 'teacher_lead', 'staff']) {
      expect(HierarchyService.canReviewClaims(role: role), isFalse);
      expect(ChatService.isCouncilOrAdminRole(role, 'Name'), isTrue);
    }
    for (final role in ['administrator', 'head', 'management', 'principal', 'council', 'captain']) {
      expect(HierarchyService.canReviewClaims(role: role), isTrue);
    }
  });

  test('claim actions reject a teacher before any Firebase write', () async {
    await signIn('teacher', 'teacher');
    await expectLater(AuthService().approveClaim(claimId: 'c', houseName: 'ruby', points: 20), throwsStateError);
    await expectLater(AuthService().rejectClaim('c'), throwsStateError);
  });

  test('medical serialization omits nullable fields and retains trusted class', () {
    final map = report('a', '10A').toMap();
    expect(map['class_id'], '10A');
    for (final key in ['certificate_photo', 'admin_remark', 'reviewed_by', 'reviewed_at']) {
      expect(map.containsKey(key), isFalse);
    }
    expect(MedicalLeaveRequest.fromMap(map).classId, '10A');
  });

  test('medical local cache cannot cross account boundaries', () async {
    await signIn('teacher', 'teacher');
    await AuthService.cacheMedicalLeaves([report('a', '10A')]);
    await signIn('other', 'teacher');
    expect(AuthService.getCachedMedicalLeaves(), isEmpty);
    await signIn('teacher', 'teacher');
    expect(AuthService.getCachedMedicalLeaves().single.id, 'a');
    await AuthService.clearCache();
    await signIn('teacher', 'teacher');
    expect(AuthService.getCachedMedicalLeaves(), isEmpty);
  });

  test('live medical failures never return cached private reports', () async {
    await signIn('head', 'head');
    await AuthService.cacheMedicalLeaves([report('a', '10A')]);
    AuthService.isFirebaseLiveOverride = true;
    await expectLater(AuthService().getMedicalLeavesStream(), emitsError(anything));
  });

  test('canonical placement overrides stale grade and section in roster', () async {
    await AuthService.cacheProfile({'uid': 'student', 'role': 'student', 'scholar_no': '12345',
      'full_name': 'Transferred pupil', 'class_id': '10B', 'class_level': 'Grade 10', 'division': 'A'});
    expect(await AuthService().getClassRosterStream('10A').first, isEmpty);
    expect((await AuthService().getClassRosterStream('10B').first).single['scholar_no'], '12345');
  });

  testWidgets('teacher class picker hides other classes, allows assigned subject classes', (tester) async {
    await signIn('teacher', 'teacher');
    await tester.pumpWidget(const MaterialApp(home: ClassGroupScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('class_group_picker_10A')), findsOneWidget);
    expect(find.byKey(const Key('class_group_picker_10B')), findsNothing);
    expect(find.byKey(const Key('class_group_picker_10C')), findsOneWidget);
  });

  testWidgets('teacher medical workspace exposes only reports for their lead class', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await signIn('teacher', 'teacher');
    await AuthService.cacheMedicalLeaves([report('a', '10A'), report('b', '10B'), report('c', '10C')]);
    await tester.pumpWidget(const MaterialApp(home: AdminClaimsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Teacher Workspace'), findsOneWidget);
    expect(find.text('Point Claims'), findsNothing);
    expect(find.byTooltip('1-on-1 Chats'), findsOneWidget);
    expect(find.textContaining('Pupil a'), findsWidgets);
    expect(find.textContaining('Pupil b'), findsNothing);
    expect(find.textContaining('Pupil c'), findsNothing);
  });

  testWidgets('teacher cannot open academic administration directly', (tester) async {
    await signIn('teacher', 'teacher');
    await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Promotion'), findsNothing);
    expect(find.textContaining('restricted to school management'), findsOneWidget);
  });

  testWidgets('admin can open roster directly from each class menu', (tester) async {
    await signIn('head', 'head');
    await AuthService.saveVerifiedClassPlacement('12345', {
      'uid': 'student', 'scholar_no': '12345', 'full_name': 'Roster pupil',
      'role': 'student', 'class_id': '10A', 'class_verified': true,
    });
    await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen(initialTab: 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Class actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View students'));
    await tester.pumpAndSettle();
    expect(find.text('Roster pupil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed medical submission preserves the form and reports the failure', (tester) async {
    await AuthService.cacheProfile({'uid': 'pupil', 'role': 'student', 'scholar_no': '12345',
      'full_name': 'Pupil', 'class_id': '10A', 'class_verified': true});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AcademicAttendanceTab(
      scholarNo: '12345', classLevel: 'Grade 10', initialAttendance: []))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final reason = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 2000);
    await tester.enterText(reason, 'Private medical reason retained for retry');
    AuthService.isFirebaseLiveOverride = true;
    AuthService.firestoreFailureSimulated = Exception('permission-denied');
    await tester.ensureVisible(find.text('Submit Medical Report'));
    await tester.tap(find.text('Submit Medical Report'));
    await tester.pumpAndSettle();
    expect(find.text('Private medical reason retained for retry'), findsOneWidget);
    expect(find.textContaining('then retry'), findsOneWidget);
    expect(AuthService.getCachedMedicalLeaves(), isEmpty);
  });

}
