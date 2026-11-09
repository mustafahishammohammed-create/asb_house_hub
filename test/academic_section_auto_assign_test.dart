import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
  });
}
