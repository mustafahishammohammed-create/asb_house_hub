import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/class_group.dart';
import 'package:asb_house_hub/screens/class_group_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/class_group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClassGroupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    ClassGroupService.firestoreFailureSimulated = null;
    service = ClassGroupService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    ClassGroupService.firestoreFailureSimulated = null;
  });

  Map<String, dynamic> profile({
    String uid = 'uid_student_1',
    String scholar = '2310911',
    String name = 'Ayaan Mohammed',
    String role = 'student',
    String classId = '11D',
    bool classVerified = true,
    String house = 'ruby',
  }) {
    return {
      'uid': uid,
      'scholar_no': scholar,
      'full_name': name,
      'role': role,
      'class_id': classId,
      'class_verified': classVerified,
      'class_level': 'Grade 11',
      'division': 'D',
      'house_name': house,
    };
  }

  AcademicClass academicClass({
    String classId = '11D',
    String teacherUid = 'uid_teacher_1',
    List<String> subjectUids = const ['uid_subject_1'],
    bool studentPosting = false,
    bool active = true,
  }) {
    final parsed = AcademicStructure.parseClassId(classId)!;
    return AcademicClass(
      classId: classId,
      grade: parsed.$1,
      section: parsed.$2,
      active: active,
      classTeacher: 'Ms. Fatima',
      classTeacherUid: teacherUid,
      subjectTeacherUids: subjectUids,
      studentPostingEnabled: studentPosting,
    );
  }

  Future<void> seed(
    Map<String, dynamic> person,
    AcademicClass cls,
  ) async {
    await AuthService.cacheProfile(person);
    await AuthService.cacheAcademicClasses([cls]);
  }

  ClassGroupMessage message({
    String id = 'msg_1',
    String senderId = 'uid_teacher_1',
    String senderName = 'Ms. Fatima',
    String senderRole = 'Faculty Lead',
    String senderClass = '11D',
    String text = 'Homework is due Sunday.',
    String category = 'announcement',
    String attachmentUrl = '',
    bool pinned = false,
    bool hidden = false,
    DateTime? timestamp,
  }) {
    return ClassGroupMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      senderClass: senderClass,
      text: text,
      category: category,
      attachmentUrl: attachmentUrl,
      isPinned: pinned,
      isHidden: hidden,
      timestamp: timestamp ?? DateTime(2026, 11, 8, 9, 30),
    );
  }

  Future<void> pumpGroup(
    WidgetTester tester, {
    String? classId,
    Stream<List<ClassGroupMessage>>? messages,
    AcademicClass? academicClass,
    Key? key,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassGroupScreen(
          key: key,
          initialClassId: classId,
          messagesStream: messages,
          initialAcademicClass: academicClass,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('M5a: auto-membership and sender roles (tests 50-53)', () {
    test('50: a verified 11D student auto-joins the 11D class group', () {
      final student = profile(classId: '11D');
      expect(ClassGroupAccess.resolveClassId(student), '11D');
      expect(ClassGroupAccess.isVerifiedMember(student, '11D'), isTrue);
      expect(ClassGroupAccess.canView(student, '11D'), isTrue);
      expect(ClassGroup.defaultsFor('11D').name, '11D Class Group');
      expect(ClassGroup.defaultsFor('11D').description, contains('Grade 11'));
    });

    test('unverified or missing class placement cannot join', () {
      expect(
        ClassGroupAccess.canView(
          profile(classVerified: false),
          '11D',
          academicClass(),
        ),
        isFalse,
      );
      expect(
        ClassGroupAccess.canView(profile(classId: ''), '11D'),
        isFalse,
      );
      expect(ClassGroupAccess.resolveClassId(profile(classId: '99Z')), '');
    });

    test('51: the assigned class teacher can publish in their own class', () {
      final teacher = profile(
        uid: 'uid_teacher_1',
        role: 'teacher',
        classId: '',
        classVerified: false,
      );
      final cls = academicClass();
      expect(ClassGroupAccess.canView(teacher, '11D', cls), isTrue);
      expect(ClassGroupAccess.canSend(teacher, '11D', cls), isTrue);
      expect(ClassGroupAccess.canModerate(teacher, '11D', cls), isTrue);
      expect(
        ClassGroupAccess.canSend(
          teacher,
          '11C',
          academicClass(
            classId: '11C',
            teacherUid: 'uid_teacher_2',
            subjectUids: const [],
          ),
        ),
        isFalse,
      );
    });

    test('a different teacher is not the class teacher', () {
      final other = profile(
        uid: 'uid_teacher_2',
        role: 'teacher',
        classId: '',
        classVerified: false,
      );
      expect(ClassGroupAccess.canSend(other, '11D', academicClass()), isFalse);
    });

    test('52: an assigned subject teacher can post to that class only', () {
      final subject = profile(
        uid: 'uid_subject_1',
        role: 'subject_teacher',
        classId: '',
        classVerified: false,
      );
      expect(ClassGroupAccess.canView(subject, '11D', academicClass()), isTrue);
      expect(ClassGroupAccess.canSend(subject, '11D', academicClass()), isTrue);
      expect(ClassGroupAccess.canModerate(subject, '11D', academicClass()), isFalse);
      expect(
        ClassGroupAccess.canSend(
          subject,
          '11C',
          academicClass(
            classId: '11C',
            teacherUid: 'uid_teacher_2',
            subjectUids: const ['uid_subject_2'],
          ),
        ),
        isFalse,
      );
    });

    test('an unassigned subject teacher cannot post', () {
      final subject = profile(
        uid: 'uid_subject_9',
        role: 'subject_teacher',
        classId: '',
        classVerified: false,
      );
      expect(ClassGroupAccess.canSend(subject, '11D', academicClass()), isFalse);
    });

    test('53: student posting is disabled by default and enabled by the school', () {
      final student = profile();
      expect(ClassGroupAccess.canSend(student, '11D', academicClass()), isFalse);
      expect(
        ClassGroupAccess.canSend(
          student,
          '11D',
          academicClass(studentPosting: true),
        ),
        isTrue,
      );
      expect(
        ClassGroupAccess.canAttach(
          student,
          '11D',
          academicClass(studentPosting: true),
        ),
        isTrue,
      );
    });

    test('class representative and vice representative can always post', () {
      for (final role in ['class_representative', 'vice_class_representative']) {
        final rep = profile(role: role);
        expect(
          ClassGroupAccess.canSend(rep, '11D', academicClass()),
          isTrue,
          reason: '$role must be able to send without student posting',
        );
        expect(
          ClassGroupAccess.canSend(rep, '11C', academicClass(classId: '11C')),
          isFalse,
        );
      }
    });

    test('a prefect can post only when student posting is enabled', () {
      final prefect = profile(role: 'prefect');
      expect(ClassGroupAccess.canSend(prefect, '11D', academicClass()), isFalse);
      expect(
        ClassGroupAccess.canSend(
          prefect,
          '11D',
          academicClass(studentPosting: true),
        ),
        isTrue,
      );
    });

    test('a parent is read-only and a teacher is not a member without assignment', () {
      final parent = profile(role: 'parent');
      expect(ClassGroupAccess.canView(parent, '11D'), isTrue);
      expect(ClassGroupAccess.canSend(parent, '11D', academicClass()), isFalse);

      final teacher = profile(
        uid: 'uid_teacher_9',
        role: 'teacher',
        classId: '',
        classVerified: false,
      );
      expect(ClassGroupAccess.canView(teacher, '11D', academicClass()), isFalse);
    });
  });

  group('M5b: cross-class isolation and transfer (test 54)', () {
    test('54: students and class teachers cannot read another class', () {
      final student = profile(classId: '11D');
      final teacher = profile(
        uid: 'uid_teacher_1',
        role: 'teacher',
        classId: '',
        classVerified: false,
      );
      final other = academicClass(
        classId: '11C',
        teacherUid: 'uid_teacher_2',
        subjectUids: const ['uid_subject_2'],
      );
      expect(ClassGroupAccess.canView(student, '11C', other), isFalse);
      expect(ClassGroupAccess.canView(teacher, '11C', other), isFalse);
      expect(ClassGroupAccess.canView(student, '11D'), isTrue);
    });

    test('a class transfer revokes the old group and grants the new one', () async {
      await AuthService.cacheProfile(profile(classId: '11D'));
      expect(service.myClassId, '11D');
      expect(
        ClassGroupAccess.canView(AuthService.getCachedProfile(), '11D'),
        isTrue,
      );
      expect(
        ClassGroupAccess.canView(AuthService.getCachedProfile(), '11C'),
        isFalse,
      );

      await AuthService.cacheProfile(profile(classId: '11C'));
      expect(service.myClassId, '11C');
      expect(
        ClassGroupAccess.canView(AuthService.getCachedProfile(), '11D'),
        isFalse,
      );
      expect(
        ClassGroupAccess.canView(AuthService.getCachedProfile(), '11C'),
        isTrue,
      );
    });

    test('senior admins may view/moderate across classes but not send', () {
      final admin = profile(
        uid: 'uid_admin_1',
        role: 'principal',
        classId: '',
        classVerified: false,
      );
      final other = academicClass(classId: '11C');
      expect(ClassGroupAccess.canView(admin, '11C', other), isTrue);
      expect(ClassGroupAccess.canModerate(admin, '11C', other), isTrue);
      expect(ClassGroupAccess.canSend(admin, '11C', other), isFalse);
      expect(ClassGroupAccess.canView(profile(classId: '11D'), '11C', other), isFalse);
    });
  });

  group('M5c: class group message model', () {
    test('message round-trips through Firestore-shaped maps', () {
      final original = message(
        pinned: true,
        hidden: true,
        attachmentUrl: 'https://example.com/homework.jpg',
      );
      final restored =
          ClassGroupMessage.fromMap(original.id, original.toMap());

      expect(restored.senderId, original.senderId);
      expect(restored.senderName, original.senderName);
      expect(restored.senderRole, original.senderRole);
      expect(restored.senderClass, '11D');
      expect(restored.text, original.text);
      expect(restored.category, 'announcement');
      expect(restored.attachmentUrl, original.attachmentUrl);
      expect(restored.isPinned, isTrue);
      expect(restored.isHidden, isTrue);
      expect(restored.timestamp, original.timestamp);
    });

    test('invalid categories normalize to general and labels stay safe', () {
      final msg = message(category: 'not-a-category');
      expect(msg.category, 'general');
      expect(msg.categoryLabel, 'General');
      expect(normalizeClassGroupCategory('SPORTS'), 'sports');
      expect(classGroupCategoryLabel('event'), 'Events');
    });

    test('attachment-only messages have a useful preview', () {
      final msg = message(
        text: '',
        attachmentUrl: 'data:image/png;base64,abc',
      );
      expect(msg.hasText, isFalse);
      expect(msg.hasAttachment, isTrue);
      expect(msg.previewText, 'Photo attachment');
    });

    test('group defaults and copyWith serialize safely', () {
      final group = ClassGroup.defaultsFor('11D').copyWith(
        name: '11D Homeroom',
        lastMessage: 'Science fair at 08:00',
        createdAt: DateTime(2026, 11, 8),
      );
      final restored = ClassGroup.fromMap('11D', group.toMap());
      expect(restored.name, '11D Homeroom');
      expect(restored.classId, '11D');
      expect(restored.lastMessage, 'Science fair at 08:00');
      expect(restored.createdAt, DateTime(2026, 11, 8));
    });

    test('academic class serializes class-group assignments', () {
      final cls = academicClass(
        subjectUids: const ['uid_subject_1', 'uid_subject_2'],
        studentPosting: true,
      );
      final restored = AcademicClass.fromMap(cls.toMap());
      expect(restored.classTeacherUid, 'uid_teacher_1');
      expect(
        restored.subjectTeacherUids,
        ['uid_subject_1', 'uid_subject_2'],
      );
      expect(restored.studentPostingEnabled, isTrue);
    });

    test('clearing the class teacher UID revokes access in the cache', () async {
      final cls = academicClass();
      await AuthService.cacheAcademicClasses([cls]);

      final cleared = cls.copyWith(classTeacherUid: '', classTeacher: '');
      expect(await AuthService().saveAcademicClass(cleared), isTrue);

      final cached = AuthService.getCachedAcademicClasses()
          .firstWhere((c) => c.classId == '11D');
      expect(cached.classTeacherUid ?? '', '');
      expect(
        ClassGroupAccess.canSend(
          profile(
            uid: 'uid_teacher_1',
            role: 'teacher',
            classId: '',
            classVerified: false,
          ),
          '11D',
          cached,
        ),
        isFalse,
        reason: 'a cleared assignment must revoke send access',
      );
    });
  });

  group('M5d: truthful service writes', () {
    test('student send is denied when student posting is off', () async {
      await seed(profile(), academicClass());
      AuthService.isFirebaseLiveOverride = true;
      final ok = await service.sendClassMessage(
        classId: '11D',
        text: 'I should not be able to post.',
      );
      expect(ok, isFalse);
    });

    test('student posting enabled still surfaces a denied write as false', () async {
      await seed(profile(), academicClass(studentPosting: true));
      AuthService.isFirebaseLiveOverride = true;
      ClassGroupService.firestoreFailureSimulated =
          Exception('permission-denied');
      expect(
        await service.sendClassMessage(
          classId: '11D',
          text: 'This write must fail truthfully.',
        ),
        isFalse,
      );
    });

    test('authorised class teacher surfaces a denied write as false', () async {
      await seed(
        profile(uid: 'uid_teacher_1', role: 'teacher', classId: '', classVerified: false),
        academicClass(),
      );
      AuthService.isFirebaseLiveOverride = true;
      ClassGroupService.firestoreFailureSimulated =
          Exception('permission-denied');
      expect(
        await service.sendClassMessage(
          classId: '11D',
          text: 'Homework moved.',
        ),
        isFalse,
      );
    });

    test('student moderation and deletion are denied', () async {
      await seed(profile(), academicClass());
      AuthService.isFirebaseLiveOverride = true;
      expect(
        await service.setMessagePinned(
          classId: '11D',
          messageId: 'msg_1',
          pinned: true,
        ),
        isFalse,
      );
      expect(
        await service.setMessageHidden(
          classId: '11D',
          messageId: 'msg_1',
          hidden: true,
        ),
        isFalse,
      );
      expect(
        await service.deleteClassMessage(
          classId: '11D',
          messageId: 'msg_1',
        ),
        isFalse,
      );
    });

    test('denied moderation by the class teacher is truthful', () async {
      await seed(
        profile(uid: 'uid_teacher_1', role: 'teacher', classId: '', classVerified: false),
        academicClass(),
      );
      AuthService.isFirebaseLiveOverride = true;
      ClassGroupService.firestoreFailureSimulated =
          Exception('permission-denied');
      expect(
        await service.setMessagePinned(
          classId: '11D',
          messageId: 'msg_1',
          pinned: true,
        ),
        isFalse,
      );
    });

    test('offline reads return empty streams instead of throwing', () async {
      await seed(profile(), academicClass());
      expect(await service.getClassMessagesStream('11D').isEmpty, isTrue);
      expect(await service.getClassGroupStream('11D').isEmpty, isTrue);
      expect(await service.getAcademicClassStream('11D').isEmpty, isTrue);
    });

    test('students and subject teachers cannot bootstrap the group header', () async {
      await seed(profile(), academicClass());
      AuthService.isFirebaseLiveOverride = true;
      expect(await service.ensureClassGroup('11D'), isFalse);

      await seed(
        profile(
          uid: 'uid_subject_1',
          role: 'subject_teacher',
          classId: '',
          classVerified: false,
        ),
        academicClass(),
      );
      expect(await service.ensureClassGroup('11D'), isFalse);
    });

    test('class teacher header bootstrap is truthful on denial', () async {
      await seed(
        profile(uid: 'uid_teacher_1', role: 'teacher', classId: '', classVerified: false),
        academicClass(),
      );
      AuthService.isFirebaseLiveOverride = true;
      ClassGroupService.firestoreFailureSimulated =
          Exception('permission-denied');
      expect(await service.ensureClassGroup('11D'), isFalse);
    });
  });

  group('M5e: rules source contract', () {
    String rules() => File('firestore.rules').readAsStringSync();

    String classGroupBlock() {
      final source = rules();
      final start = source.indexOf('match /class_groups/{classId}');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('// 10. chats', start);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    String helperBlock(String name) {
      final source = rules();
      final start = source.indexOf('function $name(');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final end = source.indexOf('function ', start + 10);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    test('membership requires verified class_id, not a join document', () {
      final source = rules();
      expect(source, contains('function isVerifiedClassMember(classId)'));
      expect(source, contains("getUserData().class_id.upper() == classId.upper()"));
      expect(source, contains("getUserData().class_verified == true"));
      expect(source, isNot(contains('class_group_members')));
    });

    test('sender helper includes teacher, subject teacher, rep, and student flag', () {
      final helper = helperBlock('isClassSender');
      expect(helper, contains('isClassTeacher(classId)'));
      expect(helper, contains('isClassSubjectTeacher(classId)'));
      expect(helper, contains('isClassRepresentative(classId)'));
      expect(helper, contains('isClassStudentSender(classId)'));
    });

    test('subject teachers are scoped by the academic_classes registry', () {
      final helper = helperBlock('isClassSubjectTeacher');
      expect(helper, contains('subject_teacher_uids'));
      expect(helper, contains('request.auth.uid in getClassData(classId).subject_teacher_uids'));
    });

    test('student posting is a server-checked school flag', () {
      final helper = helperBlock('isClassStudentSender');
      expect(helper, contains('student_posting_enabled == true'));
      expect(helper, contains("'student', 'prefect'"));
    });

    test('students cannot read across classes or create messages', () {
      final block = classGroupBlock();
      expect(block, contains('allow read: if isClassViewer(classId)'));
      expect(block, contains('allow create: if isClassSender(classId)'));
      expect(block, contains('request.resource.data.sender_id == request.auth.uid'));
      expect(block, contains('isValidClassGroupMessage(classId, request.resource.data)'));
      expect(block, isNot(contains('allow read: if isSignedIn();')));
      expect(block, isNot(contains('allow create: if isSignedIn()')));
    });

    test('attachment and category contract is sender-only', () {
      final source = rules();
      final start = source.indexOf('function isValidClassGroupMessage(classId, data)');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('function isValidAttendance', start);
      final validator = source.substring(start, end);
      expect(validator, contains("'attachment_url'"));
      expect(validator, contains('attachment_url.size() <= 900000'));
      expect(validator, contains("'general', 'announcement', 'event', 'sports'"));
      expect(validator, contains("'is_pinned'"));
      expect(validator, contains("'is_hidden'"));
    });

    test('moderation is limited to pin/hide/delete by moderators', () {
      final block = classGroupBlock();
      expect(block, contains('allow update: if isClassModerator(classId)'));
      expect(
        block,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly([\n            'is_pinned', 'is_hidden', 'moderated_by', 'moderated_at'",
        ),
      );
      expect(block, contains('allow delete: if isClassModerator(classId)'));
    });

    test('academic class validator accepts class-group settings', () {
      final source = rules();
      final start = source.indexOf('function isValidAcademicClass(data)');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('function isValidTimetableSlot', start);
      final validator = source.substring(start, end);
      expect(validator, contains("'subject_teacher_uids'"));
      expect(validator, contains("'student_posting_enabled'"));
    });

    test('user role whitelist includes all M5 roles', () {
      final source = rules();
      final start = source.indexOf('data.role is string && data.role in [');
      expect(start, greaterThanOrEqualTo(0));
      final rolesBlock = source.substring(start, start + 900);
      for (final role in [
        'class_teacher',
        'subject_teacher',
        'class_representative',
        'vice_class_representative',
        'parent',
      ]) {
        expect(
          rolesBlock,
          contains("'$role'"),
          reason: '$role must be a valid profile role',
        );
      }
    });
  });

  group('M5f: class group UI', () {
    testWidgets('verified student auto-joins and sees a read-only group', (tester) async {
      final cls = academicClass();
      await seed(profile(), cls);
      await pumpGroup(tester, classId: '11D', academicClass: cls);

      expect(find.text('11D Class Group'), findsOneWidget);
      expect(find.byKey(const Key('class_group_membership_banner')), findsOneWidget);
      expect(find.textContaining('Auto-joined via verified class'), findsOneWidget);
      expect(find.byKey(const Key('class_group_read_only_banner')), findsOneWidget);
      expect(find.byKey(const Key('class_group_composer')), findsNothing);
      expect(find.byKey(const Key('class_group_attach_button')), findsNothing);
      expect(find.byKey(const Key('class_group_send_button')), findsNothing);
    });

    testWidgets('student posting enabled shows the composer', (tester) async {
      final cls = academicClass(studentPosting: true);
      await seed(profile(), cls);
      await pumpGroup(tester, classId: '11D', academicClass: cls);

      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('class_group_read_only_banner')), findsNothing);
    });

    testWidgets('class teacher sees the composer and moderation controls', (tester) async {
      final cls = academicClass();
      await seed(
        profile(
          uid: 'uid_teacher_1',
          role: 'teacher',
          classId: '',
          classVerified: false,
        ),
        cls,
      );
      await pumpGroup(tester, classId: '11D', academicClass: cls);

      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('class_group_attach_button')), findsOneWidget);
      expect(find.byKey(const Key('class_group_send_button')), findsOneWidget);
      expect(find.byKey(const Key('class_group_category_selector')), findsOneWidget);
      expect(find.byKey(const Key('class_group_read_only_banner')), findsNothing);
      expect(find.textContaining('Staff access via class assignment'), findsOneWidget);
    });

    testWidgets('assigned subject teacher sees the composer', (tester) async {
      final cls = academicClass();
      await seed(
        profile(
          uid: 'uid_subject_1',
          role: 'subject_teacher',
          classId: '',
          classVerified: false,
        ),
        cls,
      );
      await pumpGroup(tester, classId: '11D', academicClass: cls);

      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('class_group_read_only_banner')), findsNothing);
    });

    testWidgets('class representative sees the composer and role banner', (tester) async {
      final cls = academicClass();
      await seed(profile(role: 'class_representative'), cls);
      await pumpGroup(tester, classId: '11D', academicClass: cls);

      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.textContaining('Posting as Class Representative'), findsOneWidget);
    });

    testWidgets('cross-class opens an access-denied screen', (tester) async {
      await seed(profile(classId: '11D'), academicClass());
      await pumpGroup(tester, classId: '11C');

      expect(find.byKey(const Key('class_group_access_denied')), findsOneWidget);
      expect(find.text('This class group is private'), findsOneWidget);
      expect(find.byKey(const Key('class_group_composer')), findsNothing);
      expect(find.byKey(const Key('class_group_membership_banner')), findsNothing);
    });

    testWidgets('missing class placement shows the no-class state', (tester) async {
      await seed(profile(classId: ''), academicClass());
      await pumpGroup(tester, classId: '');

      expect(find.byKey(const Key('class_group_no_class')), findsOneWidget);
      expect(find.text('No verified class on this account'), findsOneWidget);
    });

    testWidgets('staff without a class can pick an assigned class', (tester) async {
      final cls = academicClass();
      await seed(
        profile(
          uid: 'uid_teacher_1',
          role: 'teacher',
          classId: '',
          classVerified: false,
        ),
        cls,
      );
      await pumpGroup(tester, academicClass: cls);

      expect(find.byKey(const Key('class_group_picker_11D')), findsOneWidget);
      await tester.tap(find.byKey(const Key('class_group_picker_11D')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('class_group_composer')), findsOneWidget);
      expect(find.text('11D Class Group'), findsOneWidget);
    });

    testWidgets('messages render category, pin, and hidden moderation', (tester) async {
      final cls = academicClass();
      await seed(
        profile(
          uid: 'uid_teacher_1',
          role: 'teacher',
          classId: '',
          classVerified: false,
        ),
        cls,
      );
      final messages = [
        message(id: 'pinned', text: 'Pinned homework', pinned: true),
        message(
          id: 'hidden',
          text: 'Hidden note',
          hidden: true,
          category: 'general',
        ),
      ];
      await pumpGroup(
        tester,
        classId: '11D',
        academicClass: cls,
        messages: Stream.value(messages),
      );

      expect(find.text('Pinned homework'), findsOneWidget);
      expect(find.byKey(const Key('class_group_pinned_pinned')), findsOneWidget);
      expect(find.text('Hidden note'), findsOneWidget);
      expect(find.text('HIDDEN'), findsOneWidget);
      expect(find.byKey(const Key('class_group_message_menu_pinned')), findsOneWidget);
    });

    testWidgets('hidden messages are filtered out for regular students', (tester) async {
      final cls = academicClass();
      await seed(profile(), cls);
      final messages = [
        message(id: 'visible', text: 'Visible update'),
        message(id: 'hidden', text: 'Hidden note', hidden: true),
      ];
      await pumpGroup(
        tester,
        classId: '11D',
        academicClass: cls,
        messages: Stream.value(messages),
      );

      expect(find.text('Visible update'), findsOneWidget);
      expect(find.text('Hidden note'), findsNothing);
      expect(find.text('HIDDEN'), findsNothing);
    });

    testWidgets('category filters narrow the visible messages', (tester) async {
      final cls = academicClass();
      await seed(profile(), cls);
      final messages = [
        message(id: 'announcement', text: 'Exam timetable released', category: 'announcement'),
        message(id: 'general', text: 'General class update', category: 'general'),
      ];
      await pumpGroup(
        tester,
        classId: '11D',
        academicClass: cls,
        messages: Stream.value(messages),
      );

      expect(find.text('Exam timetable released'), findsOneWidget);
      expect(find.text('General class update'), findsOneWidget);

      await tester.tap(find.byKey(const Key('class_group_filter_announcement')));
      await tester.pumpAndSettle();

      expect(find.text('Exam timetable released'), findsOneWidget);
      expect(find.text('General class update'), findsNothing);
    });
  });
}
