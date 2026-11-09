import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/screens/admin_academics_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/timetable_service.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    CredentialVaultService.setTestSecret('TEST_VAULT_SECRET_2026');
  });

  tearDown(() async {
    CredentialVaultService.setTestSecret(null);
  });

  group('Academic Section Creation & Auto-Assignment', () {
    test('saveAcademicClass auto-assigns saved accounts matching grade and section', () async {
      final auth = AuthService();

      // Setup a test student account in Grade 12 Section E
      final testStudent = SavedAccount(
        scholarNo: '99912',
        fullName: 'Test Scholar 12E',
        houseName: 'ruby',
        uid: 'uid_99912',
        role: 'student',
        classLevel: 'Grade 12',
        division: 'E',
        cachedProfile: {
          'scholar_no': '99912',
          'full_name': 'Test Scholar 12E',
          'house_name': 'ruby',
          'role': 'student',
          'class_level': 'Grade 12',
          'division': 'E',
        },
      );
      await AuthService.saveAccount(testStudent);

      // Verify the account before section creation has no class_id in profile
      final beforeAccounts = AuthService.getSavedAccounts();
      expect(beforeAccounts.first.cachedProfile['class_id'], isNull);

      // Create section 12E
      final ok = await auth.saveAcademicClass(
        const AcademicClass(
          classId: '12E',
          grade: 'Grade 12',
          section: 'E',
          classTeacher: 'Mr. Test',
        ),
      );
      expect(ok, isTrue);

      // Check saved accounts on device were updated to class_id 12E
      final afterAccounts = AuthService.getSavedAccounts();
      final updated = afterAccounts.firstWhere((a) => a.scholarNo == '99912');
      expect(updated.cachedProfile['class_id'], equals('12E'));
    });

    test('getClassRosterStream returns local matching test accounts including case-insensitive checks', () async {
      final auth = AuthService();

      final accountA = SavedAccount(
        scholarNo: '12001',
        fullName: 'Scholar One',
        houseName: 'sapphire',
        uid: 'uid_12001',
        role: 'student',
        classLevel: '12',
        division: 'e',
        cachedProfile: {
          'scholar_no': '12001',
          'full_name': 'Scholar One',
          'house_name': 'sapphire',
          'role': 'student',
          'class_level': '12',
          'division': 'e',
        },
      );

      final accountB = SavedAccount(
        scholarNo: '12002',
        fullName: 'Scholar Two',
        houseName: 'emerald',
        uid: 'uid_12002',
        role: 'student',
        classLevel: 'Grade 12',
        division: 'E',
        cachedProfile: {
          'scholar_no': '12002',
          'full_name': 'Scholar Two',
          'house_name': 'emerald',
          'role': 'student',
          'class_level': 'Grade 12',
          'division': 'E',
          'class_id': '12E',
        },
      );

      await AuthService.saveAllAccounts([accountA, accountB]);

      final roster = await auth.getClassRosterStream('12E').first;
      expect(roster.length, equals(2));
      final scholarNos = roster.map((m) => m['scholar_no'].toString()).toSet();
      expect(scholarNos, containsAll(['12001', '12002']));
    });

    test('Promotion target class resolution avoids assertions when progression class is not registered', () {
      final classes = [
        const AcademicClass(classId: '11A', grade: 'Grade 11', section: 'A'),
        const AcademicClass(classId: '11B', grade: 'Grade 11', section: 'B'),
      ];

      const sourceClass = '11A';
      final autoTarget = AcademicStructure.nextClassId(sourceClass); // '12A'
      expect(autoTarget, equals('12A'));

      // 12A does not exist in classes; ensure fallback picks an existing class or null safely
      final targetClass = (autoTarget != null && classes.any((c) => c.classId == autoTarget))
          ? autoTarget
          : (classes.any((c) => c.classId != sourceClass)
              ? classes.firstWhere((c) => c.classId != sourceClass).classId
              : null);

      expect(targetClass, equals('11B'));
      expect(classes.any((c) => c.classId == targetClass), isTrue);
    });

    test('verifyStudentClass successfully verifies local test account', () async {
      final auth = AuthService();
      final testStudent = SavedAccount(
        scholarNo: '12345',
        fullName: 'test',
        houseName: 'sapphire',
        uid: 'uid_12345',
        role: 'student',
        classLevel: 'Grade 12',
        division: 'E',
        cachedProfile: {
          'scholar_no': '12345',
          'full_name': 'test',
          'house_name': 'sapphire',
          'role': 'student',
          'class_level': 'Grade 12',
          'division': 'E',
          'class_verified': false,
        },
      );
      await AuthService.saveAccount(testStudent);

      final ok = await auth.verifyStudentClass(
        scholarNo: '12345',
        classId: '12E',
      );
      expect(ok, isTrue);

      final accounts = AuthService.getSavedAccounts();
      final verified = accounts.firstWhere((a) => a.scholarNo == '12345');
      expect(verified.cachedProfile['class_verified'], isTrue);
      expect(verified.cachedProfile['class_id'], equals('12E'));

      // Assert verified placements contains the scholar
      final placements = AuthService.getVerifiedClassPlacements();
      expect(placements.containsKey('12345'), isTrue);
      expect(placements['12345']?['class_id'], equals('12E'));

      // Assert pending stream excludes verified test account
      final pending = await auth.getPendingClassVerificationsStream().first;
      expect(pending.any((p) => p['scholar_no'] == '12345'), isFalse);

      // Assert class roster stream includes verified test account
      final roster = await auth.getClassRosterStream('12E').first;
      expect(roster.any((p) => p['scholar_no'] == '12345'), isTrue);
    });

    testWidgets('AdminAcademicsScreen Audit Logs tab mounts and renders without errors', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Admin User',
        'role': 'super_admin',
        'house_name': 'ruby',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AdminAcademicsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Audit Logs tab
      final auditTab = find.text('Audit Logs');
      expect(auditTab, findsOneWidget);
      await tester.tap(auditTab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('All Actions'), findsOneWidget);
      expect(find.text('No audit log records match the current filter.'), findsOneWidget);
    });

    testWidgets('AdminAcademicsScreen full tab navigation between Audits and Classes', (tester) async {
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'full_name': 'Admin User',
        'role': 'super_admin',
        'house_name': 'ruby',
      });

      final auth = AuthService();
      await auth.saveAcademicClass(const AcademicClass(classId: '12E', grade: 'Grade 12', section: 'E'));
      await auth.saveAcademicClass(const AcademicClass(classId: '11A', grade: 'Grade 11', section: 'A'));

      final tt = TimetableService();
      await tt.writeTimetableAudit(
        action: 'publish',
        classId: '12E',
        dayOfWeek: 'Monday',
        actorUid: '11209',
        actorName: 'Admin User',
        details: 'Published timetable for 12E',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AdminAcademicsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Audit Logs
      await tester.tap(find.widgetWithText(Tab, 'Audit Logs'));
      await tester.pumpAndSettle();
      expect(find.text('PUBLISH'), findsOneWidget);

      // Now tap Classes tab
      await tester.tap(find.widgetWithText(Tab, 'Classes'));
      await tester.pumpAndSettle();

      final ex = tester.takeException();
      if (ex != null) {
        debugPrint('CAUGHT EXCEPTION ON TAB SWITCH: $ex');
      }
      expect(ex, isNull);

      // Expect classes tab content
      expect(find.text('12E'), findsWidgets);
      expect(find.text('11A'), findsWidgets);

      // Now tap Promotion tab
      await tester.tap(find.widgetWithText(Tab, 'Promotion'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Academic Year Promotion (Spec §9.5)'), findsOneWidget);

      // Now tap Rosters tab
      await tester.tap(find.widgetWithText(Tab, 'Rosters'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Now tap Verify tab
      await tester.tap(find.widgetWithText(Tab, 'Verify'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Cycle back to Audit Logs and then back to Promotion
      await tester.tap(find.widgetWithText(Tab, 'Audit Logs'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(Tab, 'Promotion'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Academic Year Promotion (Spec §9.5)'), findsOneWidget);
    });

    test('All academic streams allow multiple simultaneous subscriptions as broadcast streams', () async {
      final auth = AuthService();
      final tt = TimetableService();

      // Test getAcademicClassesStream allows multiple listeners
      final classesStream = auth.getAcademicClassesStream();
      final sub1 = classesStream.listen((_) {});
      final sub2 = classesStream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub1.cancel();
      await sub2.cancel();

      // Test getPendingClassVerificationsStream allows multiple listeners
      final pendingStream = auth.getPendingClassVerificationsStream();
      final pSub1 = pendingStream.listen((_) {});
      final pSub2 = pendingStream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pSub1.cancel();
      await pSub2.cancel();

      // Test getClassRosterStream allows multiple listeners
      final rosterStream = auth.getClassRosterStream('12E');
      final rSub1 = rosterStream.listen((_) {});
      final rSub2 = rosterStream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await rSub1.cancel();
      await rSub2.cancel();

      // Test getSubmittedTimetableQueueStream allows multiple listeners
      final queueStream = tt.getSubmittedTimetableQueueStream();
      final qSub1 = queueStream.listen((_) {});
      final qSub2 = queueStream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await qSub1.cancel();
      await qSub2.cancel();

      // Test getAllTimetableAuditsStream allows multiple listeners
      final auditsStream = tt.getAllTimetableAuditsStream();
      final aSub1 = auditsStream.listen((_) {});
      final aSub2 = auditsStream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await aSub1.cancel();
      await aSub2.cancel();
    });

    test('verifyStudentClass preserves full profile metadata in local placements and class roster', () async {
      final auth = AuthService();
      final studentProfile = {
        'scholar_no': '12345',
        'full_name': 'test',
        'house_name': 'sapphire',
        'role': 'student',
        'class_level': 'Grade 12',
        'division': 'E',
        'class_id': '12E',
        'uid': 'uid_test_12345',
      };

      final ok = await auth.verifyStudentClass(
        scholarNo: '12345',
        classId: '12E',
        uid: 'uid_test_12345',
        studentProfile: studentProfile,
      );
      expect(ok, isTrue);

      final placements = AuthService.getVerifiedClassPlacements();
      expect(placements['12345']?['full_name'], equals('test'));
      expect(placements['12345']?['house_name'], equals('sapphire'));
      expect(placements['12345']?['class_id'], equals('12E'));
      expect(placements['12345']?['class_verified'], isTrue);

      // Verify class roster stream includes test with full name
      final roster = await auth.getClassRosterStream('12E').first;
      expect(roster.any((s) => s['scholar_no'] == '12345' && s['full_name'] == 'test'), isTrue);
    });
  });
}
