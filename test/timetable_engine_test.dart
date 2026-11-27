import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
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

  group('M2b: AcademicClass permissions & HierarchyService.canEditTimetable', () {
    test('AcademicClass serialization preserves permission fields and defaults', () {
      const cls = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
        classTeacherUid: 'uid_fatima_123',
        timetableEditorUids: ['uid_editor_1', 'uid_editor_2'],
        timetableEditingEnabled: true,
        timetableRequiresApproval: true,
      );

      final map = cls.toMap();
      expect(map['class_teacher_uid'], 'uid_fatima_123');
      expect(map['timetable_editor_uids'], ['uid_editor_1', 'uid_editor_2']);
      expect(map['timetable_editing_enabled'], isTrue);
      expect(map['timetable_requires_approval'], isTrue);

      final restored = AcademicClass.fromMap(map);
      expect(restored.classTeacherUid, 'uid_fatima_123');
      expect(restored.timetableEditorUids, ['uid_editor_1', 'uid_editor_2']);
      expect(restored.timetableEditingEnabled, isTrue);
      expect(restored.timetableRequiresApproval, isTrue);
    });

    test('AcademicClass.fromMap assigns correct defaults when fields omitted', () {
      final cls = AcademicClass.fromMap({
        'class_id': '10A',
        'grade': 'Grade 10',
        'section': 'A',
      });
      expect(cls.classTeacherUid, isNull);
      expect(cls.timetableEditorUids, isEmpty);
      expect(cls.timetableEditingEnabled, isTrue);
      expect(cls.timetableRequiresApproval, isFalse);
    });

    test('AcademicClass.copyWith updates permission fields', () {
      const cls = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
      );
      final updated = cls.copyWith(
        classTeacherUid: 'uid_new_teacher',
        timetableEditorUids: ['uid_helper'],
        timetableEditingEnabled: false,
        timetableRequiresApproval: true,
      );
      expect(updated.classTeacherUid, 'uid_new_teacher');
      expect(updated.timetableEditorUids, ['uid_helper']);
      expect(updated.timetableEditingEnabled, isFalse);
      expect(updated.timetableRequiresApproval, isTrue);
    });

    test('HierarchyService.isSeniorAdmin recognises super admin, admin, head, and management', () {
      expect(HierarchyService.isSeniorAdmin(role: 'super_admin'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'admin'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'principal'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'vice_principal'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'head'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'school_head'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'management'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'school_management'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'director'), isTrue);
      expect(HierarchyService.isSeniorAdmin(scholarNo: '11209'), isTrue);
      expect(HierarchyService.isSeniorAdmin(scholarNo: 'admin'), isTrue);
      expect(HierarchyService.isSeniorAdmin(role: 'teacher'), isFalse);
      expect(HierarchyService.isSeniorAdmin(role: 'student'), isFalse);
    });

    test('HierarchyService.canEditTimetable authorization matrix (Acceptance Test 35)', () {
      const targetClass = AcademicClass(
        classId: '11D',
        grade: 'Grade 11',
        section: 'D',
        classTeacher: 'Ms. Fatima',
        classTeacherUid: 'uid_fatima',
        timetableEditorUids: ['uid_assistant_teacher'],
        timetableEditingEnabled: true,
        timetableRequiresApproval: false,
      );

      final superAdminProfile = {
        'uid': 'uid_super',
        'role': 'super_admin',
        'scholar_no': 'admin',
      };
      final assignedTeacherProfile = {
        'uid': 'uid_fatima',
        'role': 'teacher',
        'full_name': 'Ms. Fatima',
        'scholar_no': '2310101',
      };
      final assignedEditorProfile = {
        'uid': 'uid_assistant_teacher',
        'role': 'faculty',
        'scholar_no': '2310102',
      };
      final unassignedTeacherProfile = {
        'uid': 'uid_unassigned',
        'role': 'teacher',
        'full_name': 'Mr. Sharma',
        'scholar_no': '2310103',
      };
      final studentProfile = {
        'uid': 'uid_student',
        'role': 'student',
        'scholar_no': '2310910',
      };
      final councilProfile = {
        'uid': 'uid_council',
        'role': 'head_boy',
        'scholar_no': '2310555',
      };
      final captainProfile = {
        'uid': 'uid_captain',
        'role': 'house_captain',
        'scholar_no': '2310666',
      };

      // 1. Super Admin is always authorized
      expect(
        HierarchyService.canEditTimetable(
          profile: superAdminProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isTrue,
      );

      // 2. Assigned Class Teacher is authorized
      expect(
        HierarchyService.canEditTimetable(
          profile: assignedTeacherProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isTrue,
      );

      // 3. Assigned Editor in timetableEditorUids is authorized
      expect(
        HierarchyService.canEditTimetable(
          profile: assignedEditorProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isTrue,
      );

      // 4. Test 35: Unauthorized teacher is REJECTED
      expect(
        HierarchyService.canEditTimetable(
          profile: unassignedTeacherProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isFalse,
      );

      // 5. Regular student is REJECTED
      expect(
        HierarchyService.canEditTimetable(
          profile: studentProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isFalse,
      );

      // 6. Council officers and house captains are REJECTED
      expect(
        HierarchyService.canEditTimetable(
          profile: councilProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isFalse,
      );
      expect(
        HierarchyService.canEditTimetable(
          profile: captainProfile,
          classId: '11D',
          academicClass: targetClass,
        ),
        isFalse,
      );

      // 7. When timetableEditingEnabled is false, even assigned teachers are denied
      final lockedClass = targetClass.copyWith(timetableEditingEnabled: false);
      expect(
        HierarchyService.canEditTimetable(
          profile: assignedTeacherProfile,
          classId: '11D',
          academicClass: lockedClass,
        ),
        isFalse,
      );
      // But super admin can still edit
      expect(
        HierarchyService.canEditTimetable(
          profile: superAdminProfile,
          classId: '11D',
          academicClass: lockedClass,
        ),
        isTrue,
      );
    });

    test('updateClassTimetablePermissions updates local cache and handles failure truthfully', () async {
      final auth = AuthService();
      await auth.saveAcademicClass(
        const AcademicClass(
          classId: '11D',
          grade: 'Grade 11',
          section: 'D',
          classTeacher: 'Ms. Fatima',
        ),
      );

      // Update permissions offline
      final success = await auth.updateClassTimetablePermissions(
        classId: '11D',
        classTeacherUid: 'uid_fatima_123',
        timetableEditorUids: ['uid_assistant_1'],
        timetableEditingEnabled: true,
        timetableRequiresApproval: true,
      );
      expect(success, isTrue);

      final cached = AuthService.getCachedAcademicClasses();
      final cls = cached.firstWhere((c) => c.classId == '11D');
      expect(cls.classTeacherUid, 'uid_fatima_123');
      expect(cls.timetableEditorUids, ['uid_assistant_1']);
      expect(cls.timetableEditingEnabled, isTrue);
      expect(cls.timetableRequiresApproval, isTrue);

      // Test simulated Firestore failure
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');
      final failResult = await auth.updateClassTimetablePermissions(
        classId: '11D',
        timetableEditingEnabled: false,
      );
      expect(failResult, isFalse);
      // Cache should remain unchanged
      final afterFail = AuthService.getCachedAcademicClasses().firstWhere((c) => c.classId == '11D');
      expect(afterFail.timetableEditingEnabled, isTrue);
    });
  });

  group('M2c: TimetableService lifecycle, truthful writes & audit logging', () {
    test('saveTimetableDraft rejects invalid timetable structure', () async {
      // 7 slots instead of 8
      final invalid = ClassTimetableVersion(
        classId: '11D',
        dayOfWeek: 'Saturday',
        effectiveFrom: DateTime(2026, 9, 1),
        slots: const [
          TimetableSlot(periodNumber: 1, startMinute: 465),
          TimetableSlot(periodNumber: 2, startMinute: 510),
        ],
      );
      final result = await timetableService.saveTimetableDraft(invalid);
      expect(result, isFalse);
    });

    test('saveTimetableDraft successfully saves valid draft and logs audit', () async {
      final valid = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Sunday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );
      expect(valid.isValid, isTrue);

      final result = await timetableService.saveTimetableDraft(valid);
      expect(result, isTrue);

      final cached = timetableService.getCachedVersions('11D', 'Sunday');
      expect(cached, isNotEmpty);
      expect(cached.first.status, TimetableStatus.draft);
      expect(cached.first.classId, '11D');

      final audits = timetableService.getCachedAudits('11D');
      expect(audits, isNotEmpty);
      expect(audits.first['action'], 'edit');
      expect(audits.first['actor_uid'], 'uid_teacher_1');
    });

    test('submitTimetable marks status as submitted and records audit', () async {
      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Monday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );

      final submitted = await timetableService.submitTimetable(template);
      expect(submitted, isTrue);

      final cached = timetableService.getCachedVersions('11D', 'Monday');
      expect(cached.first.status, TimetableStatus.submitted);

      final audits = timetableService.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'submit'), isTrue);
    });

    test('publishTimetable activates version and sets publishedAt timestamp', () async {
      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Tuesday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );

      final published = await timetableService.publishTimetable(
        template,
        publisherUid: 'uid_admin_1',
        publisherName: 'Principal Sharma',
      );
      expect(published, isTrue);

      final cached = timetableService.getCachedVersions('11D', 'Tuesday');
      expect(cached.first.status, TimetableStatus.published);
      expect(cached.first.publishedAt, isNotNull);
      expect(cached.first.approvedByUid, 'uid_admin_1');

      final active = timetableService.getCachedActiveVersion('11D', 'Tuesday');
      expect(active, isNotNull);
      expect(active!.status, TimetableStatus.published);

      final audits = timetableService.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'publish'), isTrue);
    });

    test('rejectTimetable records reason and reviewer in audit', () async {
      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );
      await timetableService.submitTimetable(template);
      final submitted = timetableService.getCachedVersions('11D', 'Wednesday').first;

      final rejected = await timetableService.rejectTimetable(
        submitted,
        reason: 'Break timing conflicts with general assembly',
        reviewerUid: 'uid_admin_1',
        reviewerName: 'Vice Principal',
      );
      expect(rejected, isTrue);

      final cached = timetableService.getCachedVersions('11D', 'Wednesday');
      expect(cached.first.status, TimetableStatus.rejected);
      expect(cached.first.rejectionReason, 'Break timing conflicts with general assembly');
      expect(cached.first.toMap()['rejection_reason'],
          'Break timing conflicts with general assembly');

      final audits = timetableService.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'reject' && (a['details'] as String).contains('general assembly')), isTrue);
    });

    test('rejectTimetable returns false and never caches when Firestore denies the write', () async {
      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Wednesday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );
      await timetableService.submitTimetable(template);
      final submitted = timetableService.getCachedVersions('11D', 'Wednesday').first;

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');

      final rejected = await timetableService.rejectTimetable(
        submitted,
        reason: 'Reason must not appear in cache after a denied write',
        reviewerUid: 'uid_admin_1',
        reviewerName: 'Vice Principal',
      );

      expect(rejected, isFalse);
      final cached = timetableService.getCachedVersions('11D', 'Wednesday').first;
      expect(cached.status, TimetableStatus.submitted);
      expect(cached.rejectionReason, isEmpty);
      expect(
        timetableService.getCachedAudits('11D').any((a) => a['action'] == 'reject'),
        isFalse,
      );
    });

    test('restoreTimetableVersion creates a NEW version linked by supersedesId (Test 28)', () async {
      // 1. Publish version 1
      final v1 = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Thursday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
        effectiveFrom: DateTime(2026, 9, 1),
      );
      await timetableService.publishTimetable(
        v1,
        publisherUid: 'uid_admin_1',
        publisherName: 'Principal',
      );

      final initialVersions = timetableService.getCachedVersions('11D', 'Thursday');
      expect(initialVersions.length, 1);
      final originalV1 = initialVersions.first;

      // 2. Restore version 1 as a new version
      final restored = await timetableService.restoreTimetableVersion(
        targetVersion: originalV1,
        newEffectiveFrom: DateTime(2026, 11, 1),
        actorUid: 'uid_admin_1',
        actorName: 'Principal',
        publishImmediately: true,
      );

      expect(restored, isNotNull);
      expect(restored!.version, 2, reason: 'Restoring must increment version number');
      expect(restored.supersedesId, originalV1.id);
      expect(restored.effectiveFrom, DateTime(2026, 11, 1));
      expect(restored.status, TimetableStatus.published);

      // Verify history now contains both versions, with original unmodified
      final updatedHistory = timetableService.getCachedVersions('11D', 'Thursday');
      expect(updatedHistory.length, 2);
      expect(updatedHistory.any((v) => v.version == 1 && v.id == originalV1.id), isTrue);
      expect(updatedHistory.any((v) => v.version == 2 && v.supersedesId == originalV1.id), isTrue);

      final audits = timetableService.getCachedAudits('11D');
      expect(audits.any((a) => a['action'] == 'restore'), isTrue);
    });

    test('getActiveTimetableStream yields active version for target date', () async {
      final v1 = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Saturday',
        effectiveFrom: DateTime(2026, 9, 1),
      );
      await timetableService.publishTimetable(
        v1,
        publisherUid: 'uid_admin',
        publisherName: 'Principal',
      );

      final streamValue = await timetableService
          .getActiveTimetableStream('11D', 'Saturday', DateTime(2026, 9, 15))
          .first;

      expect(streamValue, isNotNull);
      expect(streamValue!.classId, '11D');
      expect(streamValue.dayOfWeek, 'Saturday');
      expect(streamValue.isPublished, isTrue);
    });

    test('Truthful writes return false on simulated Firestore denial', () async {
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');

      final v = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Sunday',
      );

      final draftResult = await timetableService.saveTimetableDraft(v);
      expect(draftResult, isFalse);

      final submitResult = await timetableService.submitTimetable(v);
      expect(submitResult, isFalse);

      final publishResult = await timetableService.publishTimetable(
        v,
        publisherUid: 'uid_admin',
        publisherName: 'Principal',
      );
      expect(publishResult, isFalse);
    });
  });

  group('M2d: Firestore security rules source contract (not emulator denial)', () {
    // These are source-contract assertions. They fail when a validator or
    // matcher regresses, but they do not prove an evaluated denial. No Firebase
    // rules emulator harness exists in this repository (M2 verification V8).
    late String rulesContent;

    setUpAll(() {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue, reason: 'firestore.rules must exist');
      rulesContent = rulesFile.readAsStringSync();
    });

    String timetableUpdateBlock() {
      final matchStart = rulesContent.indexOf('match /timetable_versions/{versionId}');
      final updateStart = rulesContent.indexOf('allow update:', matchStart);
      final deleteStart = rulesContent.indexOf('allow delete:', updateStart);
      expect(matchStart, greaterThanOrEqualTo(0));
      expect(updateStart, greaterThanOrEqualTo(0));
      expect(deleteStart, greaterThan(updateStart));
      return rulesContent.substring(updateStart, deleteStart);
    }

    test('rules defines isSeniorAdmin, isTimetableEditor, and canPublishTimetable', () {
      expect(rulesContent.contains('function isSeniorAdmin()'), isTrue);
      expect(rulesContent.contains('function isTimetableEditor(classId)'), isTrue);
      expect(rulesContent.contains('function canPublishTimetable(classId)'), isTrue);
    });

    test('rules whitelists permissions fields in isValidAcademicClass', () {
      expect(rulesContent.contains("'class_teacher_uid'"), isTrue);
      expect(rulesContent.contains("'timetable_editor_uids'"), isTrue);
      expect(rulesContent.contains("'timetable_editing_enabled'"), isTrue);
      expect(rulesContent.contains("'timetable_requires_approval'"), isTrue);
    });

    test('rules validates all 8 slots, sequential numbering, and no overlap (V1)', () {
      expect(rulesContent.contains('data.slots.size() == 8'), isTrue);
      expect(rulesContent.contains("['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday']"), isTrue);

      for (var i = 0; i < 8; i++) {
        expect(
          rulesContent.contains('isValidTimetableSlot(data.slots[$i])'),
          isTrue,
          reason: 'slot ${i + 1} must be validated, not only first/last',
        );
        expect(
          rulesContent.contains('slots[$i].period_number == ${i + 1}'),
          isTrue,
          reason: 'period number ${i + 1} must be bound to list index $i',
        );
      }

      for (var i = 0; i < 7; i++) {
        expect(
          rulesContent.contains(
            'slots[$i].start_minute + 45 <= slots[${i + 1}].start_minute',
          ),
          isTrue,
          reason: 'periods ${i + 1}/${i + 2} must not overlap',
        );
      }
      expect(rulesContent.contains('slots[7].start_minute + 45 <= 1440'), isTrue,
          reason: 'last period must end by midnight');
    });

    test('rules enforces 30-minute break placement between periods (V1)', () {
      expect(rulesContent.contains('function isValidTimetableBreakPlacement('), isTrue);
      expect(rulesContent.contains('breakStartMinute + 30 <= 1440'), isTrue);
      for (var after = 1; after <= 8; after++) {
        expect(
          rulesContent.contains('breakAfterPeriod != $after ||'),
          isTrue,
          reason: 'break placement after period $after must be checked',
        );
      }
      expect(
        rulesContent.contains(
          'isValidTimetableBreakPlacement(data.slots, data.break_after_period, data.break_start_minute)',
        ),
        isTrue,
      );
    });

    test('rules whitelists rejection_reason and every reject update key (V2)', () {
      expect(rulesContent.contains("'rejection_reason'"), isTrue);
      expect(rulesContent.contains('data.rejection_reason is string'), isTrue);
      expect(rulesContent.contains('data.rejection_reason.size() <= 500'), isTrue);
      for (final key in [
        'status',
        'approved_by_uid',
        'approved_by_name',
        'rejection_reason',
        'updated_at',
      ]) {
        expect(
          rulesContent.contains("'$key'"),
          isTrue,
          reason: 'reject update key $key must be in the version whitelist',
        );
      }
    });

    test('rules freezes published versions against in-place edits, including seniors (V3)', () {
      final updateBlock = timetableUpdateBlock();
      expect(updateBlock.contains("resource.data.status != 'published'"), isTrue,
          reason: 'published versions must never be updated in place');
      expect(updateBlock.contains('isSeniorAdmin()'), isTrue,
          reason: 'senior override remains available for unpublished versions only');
      expect(updateBlock.indexOf("resource.data.status != 'published'"),
          lessThan(updateBlock.indexOf('isSeniorAdmin()')),
          reason: 'the published freeze must guard the senior branch');
    });

    test('test 5: students cannot list another class timetable (rule contract)', () {
      final matchStart =
          rulesContent.indexOf('match /timetable_versions/{versionId}');
      final createStart = rulesContent.indexOf('allow create:', matchStart);
      expect(matchStart, greaterThanOrEqualTo(0));
      expect(createStart, greaterThan(matchStart));
      final readBlock = rulesContent.substring(matchStart, createStart);

      // Students are scoped by their verified profile class, and only see
      // published versions (or drafts for classes they are allowed to edit).
      expect(
        readBlock.contains('isVerifiedClassMember(resource.data.class_id)'),
        isTrue,
      );
      // Staff keep cross-class published/submitted reads for conflict checks
      // and the approval queue; the retired broad clause allowed *any*
      // signed-in user to enumerate every class.
      expect(
        readBlock.contains('(isAdmin() && resource != null'),
        isTrue,
      );
      expect(
        readBlock.contains(
          "resource.data.status in ['published', 'submitted']",
        ),
        isTrue,
      );
      expect(
        readBlock.contains(
          "(isSignedIn() && resource != null && resource.data.status == 'published')",
        ),
        isFalse,
      );
      expect(readBlock.contains('resource == null'), isFalse);
    });

    test('rules defines append-only timetable_audit collection', () {
      expect(rulesContent.contains("match /timetable_audit/{auditId}"), isTrue);
      expect(rulesContent.contains("allow update, delete: if false;"), isTrue);
      expect(rulesContent.contains("data.actor_uid == request.auth.uid"), isTrue);
    });
  });
}
