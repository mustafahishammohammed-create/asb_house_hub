import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/screens/admin_academics_screen.dart';

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

  group('M1: AcademicStructure canonical class identity', () {
    test('gradeLevels spans LKG through Grade 12 in order', () {
      expect(AcademicStructure.gradeLevels.first, 'LKG');
      expect(AcademicStructure.gradeLevels[1], 'UKG');
      expect(AcademicStructure.gradeLevels.last, 'Grade 12');
      expect(AcademicStructure.gradeLevels.length, 14);
    });

    test('normalizeGrade accepts raw tokens and rejects out-of-range grades', () {
      expect(AcademicStructure.normalizeGrade('11'), 'Grade 11');
      expect(AcademicStructure.normalizeGrade('Grade 11'), 'Grade 11');
      expect(AcademicStructure.normalizeGrade('grade 5'), 'Grade 5');
      expect(AcademicStructure.normalizeGrade('lkg'), 'LKG');
      expect(AcademicStructure.normalizeGrade('UKG'), 'UKG');
      expect(AcademicStructure.normalizeGrade('13'), isNull);
      expect(AcademicStructure.normalizeGrade('0'), isNull);
      expect(AcademicStructure.normalizeGrade(''), isNull);
      expect(AcademicStructure.normalizeGrade(null), isNull);
      expect(AcademicStructure.normalizeGrade('Staff'), isNull);
    });

    test('classIdFrom builds canonical ids (11D, LKG-A)', () {
      expect(AcademicStructure.classIdFrom('Grade 11', 'D'), '11D');
      expect(AcademicStructure.classIdFrom('11', 'd'), '11D');
      expect(AcademicStructure.classIdFrom('LKG', 'A'), 'LKG-A');
      expect(AcademicStructure.classIdFrom('UKG', 'b'), 'UKG-B');
      expect(AcademicStructure.classIdFrom('Grade 1', 'C'), '1C');
      expect(AcademicStructure.classIdFrom('Grade 12', 'F'), '12F');
      expect(AcademicStructure.classIdFrom('Staff', 'A'), '');
      expect(AcademicStructure.classIdFrom('Grade 11', ''), '');
    });

    test('parseClassId round-trips every grade/section combination', () {
      for (final grade in AcademicStructure.gradeLevels) {
        for (final section in ['A', 'D', 'F']) {
          final id = AcademicStructure.classIdFrom(grade, section);
          final parsed = AcademicStructure.parseClassId(id);
          expect(parsed, isNotNull, reason: 'Failed to parse $id');
          expect(parsed!.$1, grade);
          expect(parsed.$2, section);
        }
      }
      expect(AcademicStructure.parseClassId('13A'), isNull);
      expect(AcademicStructure.parseClassId('garbage'), isNull);
      expect(AcademicStructure.parseClassId(''), isNull);
    });

    test('displayClass renders human-friendly labels', () {
      expect(
        AcademicStructure.displayClass('Grade 11', 'D'),
        'Grade 11 — Section D',
      );
      expect(AcademicStructure.displayClass('LKG', 'A'), 'LKG — Section A');
    });
  });

  group('M1: AcademicClass registry model', () {
    test('toMap/fromMap round-trips all fields', () {
      const cls = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
        academicYear: '2026-2027',
      );
      final restored = AcademicClass.fromMap(cls.toMap());
      expect(restored.classId, '11D');
      expect(restored.grade, 'Grade 11');
      expect(restored.section, 'D');
      expect(restored.active, isTrue);
      expect(restored.classTeacher, 'Ms. Fatima');
      expect(restored.academicYear, '2026-2027');
      expect(restored.displayLabel, 'Grade 11 — Section D');
    });

    test('fromMap normalizes grade/section and derives missing classId', () {
      final cls = AcademicClass.fromMap({
        'grade': '11',
        'section': 'd',
        'active': false,
      }, '11D');
      expect(cls.grade, 'Grade 11');
      expect(cls.section, 'D');
      expect(cls.classId, '11D');
      expect(cls.active, isFalse);
    });

    test('fromMap defaults active to true unless explicitly false', () {
      expect(AcademicClass.fromMap({'grade': 'LKG', 'section': 'A'}).active, isTrue);
      expect(
        AcademicClass.fromMap({'grade': 'LKG', 'section': 'A', 'active': false}).active,
        isFalse,
      );
    });
  });

  group('M1: Firestore rules contracts', () {
    final rules = File('firestore.rules').readAsStringSync();

    test('isValidUser whitelists class_id and class_verified', () {
      final match = RegExp(
        r'function isValidUser\(data\) \{([\s\S]*?)\n    \}',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;
      expect(body.contains("'class_id'"), isTrue);
      expect(body.contains("'class_verified'"), isTrue);
      expect(body.contains('data.class_verified is bool'), isTrue);
    });

    test('self-signup cannot set class_verified=true', () {
      expect(
        rules.contains(
          "(!('class_verified' in request.resource.data) || request.resource.data.class_verified == false || isSuperAdmin())",
        ),
        isTrue,
      );
    });

    test('owner cannot mutate class_id or class_verified on update', () {
      final ownerBlock = RegExp(
        r'isOwner\(userId\) &&\s*request\.resource\.data\.role == resource\.data\.role &&\s*areImmutableFieldsUnchanged\(\[([^\]]*)\]\)',
      ).firstMatch(rules);
      expect(ownerBlock, isNotNull);
      final fields = ownerBlock!.group(1)!;
      expect(fields.contains("'class_id'"), isTrue);
      expect(fields.contains("'class_verified'"), isTrue);
    });

    test('academic_classes registry is admin-write and own-class-read', () {
      final match = RegExp(
        r'match /academic_classes/\{classId\} \{([\s\S]*?)\n    \}',
      ).firstMatch(rules);
      expect(match, isNotNull, reason: 'academic_classes block missing');
      final body = match!.group(1)!;
      expect(body.contains('allow read: if isAdmin() ||'), isTrue);
      expect(body.contains('getUserData().class_id == classId'), isTrue);
      expect(body.contains('allow create: if isAdmin()'), isTrue);
      expect(body.contains('allow update: if isAdmin()'), isTrue);
      expect(body.contains('allow delete: if isAdmin();'), isTrue);
      expect(body.contains('isValidAcademicClass(request.resource.data)'), isTrue);
      expect(
        body.contains("areImmutableFieldsUnchanged(['grade', 'section', 'created_at'])"),
        isTrue,
      );
      // Must NOT be world-readable or world-writable
      expect(body.contains('allow read: if isSignedIn();'), isFalse);
      expect(body.contains('allow write: if isSignedIn();'), isFalse);
    });

    test('isValidAcademicClass restricts grades to LKG-12 and requires core fields', () {
      final match = RegExp(
        r'function isValidAcademicClass\(data\) \{([\s\S]*?)\n    \}',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;
      expect(body.contains("hasRequiredFields(['class_id', 'grade', 'section', 'active'])"), isTrue);
      expect(body.contains("'LKG', 'UKG', 'Grade 1'"), isTrue);
      expect(body.contains("'Grade 12'"), isTrue);
      expect(body.contains('data.active is bool'), isTrue);
    });
  });

  group('M1: Registry service (offline cache + truthful writes)', () {
    test('saveAcademicClass persists to cache and rejects invalid ids', () async {
      final auth = AuthService();
      const cls = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
      );
      expect(await auth.saveAcademicClass(cls), isTrue);
      final cached = AuthService.getCachedAcademicClasses();
      expect(cached.length, 1);
      expect(cached.first.classId, '11D');
      expect(cached.first.classTeacher, 'Ms. Fatima');
      expect(cached.first.createdAt, isNotNull);

      const invalid = AcademicClass(
        classId: 'BOGUS',
        grade: 'Grade 11',
        section: 'D',
      );
      expect(await auth.saveAcademicClass(invalid), isFalse);
      expect(AuthService.getCachedAcademicClasses().length, 1);
    });

    test('saveAcademicClass updates existing entry without duplicating', () async {
      final auth = AuthService();
      const cls = AcademicClass(classId: '11D', grade: 'Grade 11', section: 'D');
      await auth.saveAcademicClass(cls);
      await auth.saveAcademicClass(cls.copyWith(classTeacher: 'Mr. Ahmed'));
      final cached = AuthService.getCachedAcademicClasses();
      expect(cached.length, 1);
      expect(cached.first.classTeacher, 'Mr. Ahmed');
    });

    test('setClassActive toggles the cached entry', () async {
      final auth = AuthService();
      const cls = AcademicClass(classId: 'LKG-A', grade: 'LKG', section: 'A');
      await auth.saveAcademicClass(cls);
      expect(await auth.setClassActive('LKG-A', false), isTrue);
      expect(AuthService.getCachedAcademicClasses().first.active, isFalse);
      expect(await auth.setClassActive('LKG-A', true), isTrue);
      expect(AuthService.getCachedAcademicClasses().first.active, isTrue);
      expect(await auth.setClassActive('', false), isFalse);
    });

    test('registry cache sorts LKG first then by grade number and section', () async {
      final auth = AuthService();
      await auth.saveAcademicClass(
        const AcademicClass(classId: '11D', grade: 'Grade 11', section: 'D'),
      );
      await auth.saveAcademicClass(
        const AcademicClass(classId: 'LKG-B', grade: 'LKG', section: 'B'),
      );
      await auth.saveAcademicClass(
        const AcademicClass(classId: '2A', grade: 'Grade 2', section: 'A'),
      );
      await auth.saveAcademicClass(
        const AcademicClass(classId: 'LKG-A', grade: 'LKG', section: 'A'),
      );
      final ids = AuthService.getCachedAcademicClasses().map((c) => c.classId).toList();
      expect(ids, ['LKG-A', 'LKG-B', '2A', '11D']);
    });

    test('clearCache removes the registry cache', () async {
      final auth = AuthService();
      await auth.saveAcademicClass(
        const AcademicClass(classId: '11D', grade: 'Grade 11', section: 'D'),
      );
      expect(AuthService.getCachedAcademicClasses(), isNotEmpty);
      await AuthService.clearCache();
      expect(AuthService.getCachedAcademicClasses(), isEmpty);
    });

    test('live Firestore denial returns false and leaves cache untouched', () async {
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');
      final auth = AuthService();
      const cls = AcademicClass(classId: '11D', grade: 'Grade 11', section: 'D');
      expect(await auth.saveAcademicClass(cls), isFalse);
      expect(AuthService.getCachedAcademicClasses(), isEmpty);
      expect(await auth.setClassActive('11D', false), isFalse);
    });

    test('getAcademicClassesStream falls back to cache without Firebase', () async {
      final auth = AuthService();
      await auth.saveAcademicClass(
        const AcademicClass(classId: '11D', grade: 'Grade 11', section: 'D'),
      );
      await auth.saveAcademicClass(
        const AcademicClass(classId: '5A', grade: 'Grade 5', section: 'A', active: false),
      );
      final all = await auth.getAcademicClassesStream().first;
      expect(all.map((c) => c.classId), ['5A', '11D']);
      final active = await auth.getAcademicClassesStream(activeOnly: true).first;
      expect(active.map((c) => c.classId), ['11D']);
    });
  });

  group('M1: Classification verification gate', () {
    test('transferStudentClass rejects invalid class ids and empty scholars', () async {
      final auth = AuthService();
      expect(
        await auth.transferStudentClass(scholarNo: '10001', classId: 'BOGUS'),
        isFalse,
      );
      expect(
        await auth.transferStudentClass(scholarNo: '', classId: '11D'),
        isFalse,
      );
      expect(
        await auth.verifyStudentClass(scholarNo: '10001', classId: 'BOGUS'),
        isFalse,
      );
      expect(await auth.verifyStudentClass(scholarNo: ''), isFalse);
    });

    test('verify updates the cached profile when scholar is the current user', () async {
      await AuthService.cacheProfile({
        'uid': 'uid_1',
        'scholar_no': '10001',
        'full_name': 'Aarav Sharma',
        'house_name': 'emerald',
        'role': 'student',
        'class_level': 'Grade 11',
        'division': 'D',
        'class_id': '11D',
        'class_verified': false,
      });
      final auth = AuthService();
      expect(
        await auth.verifyStudentClass(scholarNo: '10001', classId: '11D'),
        isTrue,
      );
      final profile = AuthService.getCachedProfile()!;
      expect(profile['class_verified'], true);
      expect(profile['class_id'], '11D');
    });

    test('transfer rewrites canonical and legacy class fields in cache', () async {
      await AuthService.cacheProfile({
        'uid': 'uid_1',
        'scholar_no': '10001',
        'full_name': 'Aarav Sharma',
        'house_name': 'emerald',
        'role': 'student',
        'class_level': 'Grade 11',
        'division': 'D',
        'class_id': '11D',
        'class_verified': false,
      });
      final auth = AuthService();
      expect(
        await auth.transferStudentClass(scholarNo: '10001', classId: '10B'),
        isTrue,
      );
      final profile = AuthService.getCachedProfile()!;
      expect(profile['class_id'], '10B');
      expect(profile['class_level'], 'Grade 10');
      expect(profile['division'], 'B');
      expect(profile['class_verified'], true);
    });

    test('live denial of verification returns false without touching cache', () async {
      await AuthService.cacheProfile({
        'uid': 'uid_1',
        'scholar_no': '10001',
        'full_name': 'Aarav Sharma',
        'house_name': 'emerald',
        'role': 'student',
        'class_id': '11D',
        'class_verified': false,
      });
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');
      final auth = AuthService();
      expect(
        await auth.verifyStudentClass(scholarNo: '10001', classId: '11D'),
        isFalse,
      );
      expect(AuthService.getCachedProfile()!['class_verified'], false);
    });

    test('roster stream returns empty for invalid class id without Firebase', () async {
      final auth = AuthService();
      expect(await auth.getClassRosterStream('BOGUS').first, isEmpty);
      expect(await auth.getPendingClassVerificationsStream().first, isEmpty);
    });
  });

  group('M1: AdminAcademicsScreen UI', () {
    Future<void> seedStaffProfile() async {
      await AuthService.cacheProfile({
        'uid': 'staff_1',
        'scholar_no': '30003',
        'full_name': 'Ms. Fatima Al Hasan',
        'house_name': 'ruby',
        'role': 'teacher',
      });
    }

    testWidgets('non-staff sees the access-restricted notice', (tester) async {
      await AuthService.cacheProfile({
        'uid': 'u1',
        'scholar_no': '10001',
        'full_name': 'Aarav Sharma',
        'house_name': 'emerald',
        'role': 'student',
      });
      await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen()));
      await tester.pump();
      expect(
        find.textContaining('restricted to school staff'),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('staff sees three tabs and the cached registry', (tester) async {
      await seedStaffProfile();
      final auth = AuthService();
      await auth.saveAcademicClass(
        const AcademicClass(
          classId: '11D',
          grade: 'Grade 11',
          section: 'D',
          classTeacher: 'Ms. Fatima',
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen()));
      await tester.pump();

      expect(find.text('Academic Management'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Rosters'), findsOneWidget);
      expect(find.text('Add Section'), findsOneWidget);

      await tester.tap(find.text('Classes'));
      await tester.pumpAndSettle();
      expect(find.text('Grade 11 — Section D'), findsOneWidget);
      expect(find.textContaining('Class teacher: Ms. Fatima'), findsOneWidget);
    });

    testWidgets('Add Section dialog creates a canonical class end-to-end', (tester) async {
      await seedStaffProfile();
      await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen()));
      await tester.pump();

      await tester.tap(find.text('Add Section'));
      await tester.pump();
      expect(find.text('Add Class Section'), findsOneWidget);
      expect(find.textContaining('Canonical class ID: 11A'), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Section 11A created.'), findsOneWidget);
      final cached = AuthService.getCachedAcademicClasses();
      expect(cached.any((c) => c.classId == '11A'), isTrue);
    });

    testWidgets('pending verification tab renders empty state offline', (tester) async {
      await seedStaffProfile();
      await tester.pumpWidget(const MaterialApp(home: AdminAcademicsScreen()));
      await tester.pump();
      expect(
        find.text('All scholars have verified class placements.'),
        findsOneWidget,
      );
    });
  });
}