import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/house_group.dart';
import 'package:asb_house_hub/screens/house_group_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/house_group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HouseGroupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    HouseGroupService.firestoreFailureSimulated = null;
    service = HouseGroupService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    HouseGroupService.firestoreFailureSimulated = null;
  });

  Map<String, dynamic> profile({
    String uid = 'uid_student_1',
    String scholar = '2310910',
    String name = 'Ayaan Mohammed',
    String role = 'student',
    String house = 'ruby',
    String classId = '11D',
  }) {
    return {
      'uid': uid,
      'scholar_no': scholar,
      'full_name': name,
      'role': role,
      'house_name': house,
      'class_id': classId,
      'class_level': 'Grade 11',
      'division': 'D',
    };
  }

  HouseGroupMessage message({
    String id = 'msg_1',
    String senderId = 'uid_teacher_1',
    String senderName = 'Ms. Fatima',
    String senderRole = 'Faculty Lead',
    String senderHouse = 'ruby',
    String text = 'House assembly moved to 10:00.',
    String category = 'announcement',
    String attachmentUrl = '',
    bool pinned = false,
    bool hidden = false,
    DateTime? timestamp,
  }) {
    return HouseGroupMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      senderHouse: senderHouse,
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
    String? houseId,
    Stream<List<HouseGroupMessage>>? messages,
    Key? key,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseGroupScreen(
          key: key,
          initialHouseId: houseId,
          messagesStream: messages,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('M4a: auto-membership and sender roles (tests 39-47)', () {
    test('39: a Ruby student auto-joins the Ruby group from the profile', () {
      final student = profile(house: 'ruby');
      expect(HouseGroupAccess.resolveHouse(student), 'ruby');
      expect(HouseGroupAccess.canView(student, 'ruby'), isTrue);
      expect(HouseGroup.defaultsFor('ruby').name, 'Ruby House Group');
      expect(HouseGroup.defaultsFor('ruby').description, contains('Ruby House'));
    });

    test('40: same-house student can read Ruby, other-house student cannot', () {
      final ruby = profile(house: 'ruby');
      final sapphire = profile(house: 'sapphire');
      expect(HouseGroupAccess.canView(ruby, 'ruby'), isTrue);
      expect(HouseGroupAccess.canView(sapphire, 'ruby'), isFalse);
      expect(HouseGroupAccess.canView(sapphire, 'sapphire'), isTrue);
    });

    test('41: regular student and prefect cannot send', () {
      expect(HouseGroupAccess.canSend(profile(), 'ruby'), isFalse);
      expect(
        HouseGroupAccess.canSend(profile(role: 'prefect'), 'ruby'),
        isFalse,
      );
    });

    test('42: regular student cannot attach images', () {
      expect(HouseGroupAccess.canAttach(profile(), 'ruby'), isFalse);
      expect(
        HouseGroupAccess.canAttach(profile(role: 'captain'), 'ruby'),
        isTrue,
      );
    });

    test('43: house captain can send in their own house only', () {
      final captain = profile(role: 'captain');
      expect(HouseGroupAccess.canSend(captain, 'ruby'), isTrue);
      expect(HouseGroupAccess.canSend(captain, 'sapphire'), isFalse);
    });

    test('44: vice-captain can send', () {
      expect(
        HouseGroupAccess.canSend(profile(role: 'vice_captain'), 'ruby'),
        isTrue,
      );
      expect(
        HouseGroupAccess.canSend(profile(role: 'house_vice_captain'), 'ruby'),
        isTrue,
      );
    });

    test('45: sports captain and sports vice-captain can send', () {
      expect(
        HouseGroupAccess.canSend(profile(role: 'sports_captain'), 'ruby'),
        isTrue,
      );
      expect(
        HouseGroupAccess.canSend(profile(role: 'sports_vice_captain'), 'ruby'),
        isTrue,
      );
    });

    test('46: head boy and head girl can send', () {
      expect(
        HouseGroupAccess.canSend(profile(role: 'head_boy'), 'ruby'),
        isTrue,
      );
      expect(
        HouseGroupAccess.canSend(profile(role: 'head_girl'), 'ruby'),
        isTrue,
      );
    });

    test('47: authorised staff, teachers, and faculty can post', () {
      for (final role in [
        'teacher',
        'faculty',
        'principal',
        'staff',
        'faculty_advisor',
        'teacher_lead',
      ]) {
        expect(
          HouseGroupAccess.canSend(profile(role: role), 'ruby'),
          isTrue,
          reason: '$role must be an authorised house sender',
        );
      }
    });

    test('unknown or missing house resolves to no group', () {
      expect(HouseGroupAccess.resolveHouse(profile(house: 'unknown')), '');
      expect(HouseGroupAccess.resolveHouse(null), '');
      expect(HouseGroupAccess.canView(profile(house: 'unknown'), 'ruby'), isFalse);
    });
  });

  group('M4b: cross-house isolation and transfer (tests 48-49)', () {
    test('48: Ruby student cannot access Sapphire group and vice versa', () {
      final ruby = profile(house: 'ruby');
      final sapphire = profile(house: 'sapphire');
      expect(HouseGroupAccess.canView(ruby, 'sapphire'), isFalse);
      expect(HouseGroupAccess.canView(sapphire, 'ruby'), isFalse);
      expect(HouseGroupAccess.canView(ruby, 'emerald'), isFalse);
      expect(HouseGroupAccess.canView(ruby, 'topaz'), isFalse);
    });

    test('49: house transfer revokes the old group and grants the new one', () async {
      await AuthService.cacheProfile(profile(house: 'ruby'));
      expect(service.myHouse, 'ruby');
      expect(HouseGroupAccess.canView(AuthService.getCachedProfile(), 'ruby'), isTrue);
      expect(
        HouseGroupAccess.canView(AuthService.getCachedProfile(), 'sapphire'),
        isFalse,
      );

      await AuthService.cacheProfile(profile(house: 'sapphire', uid: 'uid_student_1'));
      expect(service.myHouse, 'sapphire');
      expect(HouseGroupAccess.canView(AuthService.getCachedProfile(), 'ruby'), isFalse);
      expect(
        HouseGroupAccess.canView(AuthService.getCachedProfile(), 'sapphire'),
        isTrue,
      );
      expect(
        AuthService.getCachedProfile()?['class_id'],
        '11D',
        reason: 'A house transfer must not change the academic class',
      );
    });

    test('senior admins may view across houses but students remain isolated', () {
      final admin = profile(role: 'principal', house: 'ruby');
      expect(HouseGroupAccess.canView(admin, 'sapphire'), isTrue);
      expect(HouseGroupAccess.canSend(admin, 'sapphire'), isFalse);
      expect(HouseGroupAccess.canModerate(admin, 'sapphire'), isTrue);
      expect(HouseGroupAccess.canView(profile(), 'sapphire'), isFalse);
    });
  });

  group('M4c: house group message model', () {
    test('message round-trips through Firestore-shaped maps', () {
      final original = message(
        pinned: true,
        hidden: true,
        attachmentUrl: 'https://example.com/photo.jpg',
      );
      final restored = HouseGroupMessage.fromMap(original.id, original.toMap());

      expect(restored.senderId, original.senderId);
      expect(restored.senderName, original.senderName);
      expect(restored.senderRole, original.senderRole);
      expect(restored.senderHouse, 'ruby');
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
      expect(normalizeHouseGroupCategory('SPORTS'), 'sports');
      expect(houseGroupCategoryLabel('event'), 'Events');
    });

    test('attachment-only messages have a useful preview', () {
      final msg = message(text: '', attachmentUrl: 'data:image/png;base64,abc');
      expect(msg.hasText, isFalse);
      expect(msg.hasAttachment, isTrue);
      expect(msg.previewText, 'Photo attachment');
    });

    test('group defaults and copyWith serialize safely', () {
      final group = HouseGroup.defaultsFor('sapphire').copyWith(
        name: 'Sapphire Blue Crew',
        lastMessage: 'Sports day at 08:00',
        createdAt: DateTime(2026, 11, 8),
      );
      final restored = HouseGroup.fromMap('sapphire', group.toMap());
      expect(restored.name, 'Sapphire Blue Crew');
      expect(restored.houseId, 'sapphire');
      expect(restored.lastMessage, 'Sports day at 08:00');
      expect(restored.createdAt, DateTime(2026, 11, 8));
    });
  });

  group('M4d: truthful service writes', () {
    test('student send is denied before any Firestore write', () async {
      await AuthService.cacheProfile(profile());
      AuthService.isFirebaseLiveOverride = true;
      final ok = await service.sendHouseMessage(
        houseId: 'ruby',
        text: 'I should not be able to post.',
      );
      expect(ok, isFalse);
    });

    test('authorised teacher surfaces a denied Firestore write as false', () async {
      await AuthService.cacheProfile(profile(role: 'teacher'));
      AuthService.isFirebaseLiveOverride = true;
      HouseGroupService.firestoreFailureSimulated =
          Exception('permission-denied');

      final ok = await service.sendHouseMessage(
        houseId: 'ruby',
        text: 'Assembly moved.',
      );
      expect(ok, isFalse);
    });

    test('student moderation and deletion are denied', () async {
      await AuthService.cacheProfile(profile());
      AuthService.isFirebaseLiveOverride = true;
      expect(
        await service.setMessagePinned(
          houseId: 'ruby',
          messageId: 'msg_1',
          pinned: true,
        ),
        isFalse,
      );
      expect(
        await service.setMessageHidden(
          houseId: 'ruby',
          messageId: 'msg_1',
          hidden: true,
        ),
        isFalse,
      );
      expect(
        await service.deleteHouseMessage(
          houseId: 'ruby',
          messageId: 'msg_1',
        ),
        isFalse,
      );
    });

    test('denied moderation by an authorised leader is truthful', () async {
      await AuthService.cacheProfile(profile(role: 'captain'));
      AuthService.isFirebaseLiveOverride = true;
      HouseGroupService.firestoreFailureSimulated =
          Exception('permission-denied');
      expect(
        await service.setMessagePinned(
          houseId: 'ruby',
          messageId: 'msg_1',
          pinned: true,
        ),
        isFalse,
      );
    });

    test('offline reads return an empty stream instead of throwing', () async {
      await AuthService.cacheProfile(profile());
      expect(await service.getHouseMessagesStream('ruby').isEmpty, isTrue);
      expect(await service.getHouseGroupStream('ruby').isEmpty, isTrue);
    });

    test('students cannot bootstrap the group header', () async {
      await AuthService.cacheProfile(profile());
      AuthService.isFirebaseLiveOverride = true;
      expect(await service.ensureHouseGroup('ruby'), isFalse);
    });
  });

  group('M4e: rules source contract', () {
    String rules() => File('firestore.rules').readAsStringSync();

    String houseGroupBlock() {
      final source = rules();
      final start = source.indexOf('match /house_groups/{houseId}');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('// 10. chats', start);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    String senderHelperBlock() {
      final source = rules();
      final start = source.indexOf('function isHouseSender(houseId)');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('function isHouseModerator', start);
      return source.substring(start, end);
    }

    test('rules derive membership from the verified profile house', () {
      final source = rules();
      expect(source, contains('function isSameHouse(houseId)'));
      expect(source, contains("getUserData().house_name.lower() == houseId.lower()"));
      expect(source, isNot(contains('house_group_members')));
    });

    test('sender helper requires same house plus leader/staff roles', () {
      final helper = senderHelperBlock();
      expect(helper, contains('isSameHouse(houseId)'));
      expect(helper, contains('isAdmin()'));
      expect(helper, contains('isCaptain()'));
      expect(helper, contains('isCouncil()'));
    });

    test('students cannot read across houses or send messages', () {
      final block = houseGroupBlock();
      expect(
        block,
        contains(
          'allow read: if isSignedIn() && (isSameHouse(houseId) || isSeniorAdmin())',
        ),
      );
      expect(block, contains('allow create: if isHouseSender(houseId)'));
      expect(block, contains('request.resource.data.sender_id == request.auth.uid'));
      expect(block, contains('isValidHouseGroupMessage(houseId, request.resource.data)'));
      expect(block, isNot(contains('allow read: if isSignedIn();')));
      expect(block, isNot(contains('allow create: if isSignedIn()')));
    });

    test('attachment is a sender-only message field', () {
      final source = rules();
      final start = source.indexOf('function isValidHouseGroupMessage(houseId, data)');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('function isValidAttendance', start);
      final validator = source.substring(start, end);
      expect(validator, contains("'attachment_url'"));
      expect(validator, contains('attachment_url.size() <= 900000'));
      expect(validator, contains("'category'"));
      expect(validator, contains("'general', 'announcement', 'event', 'sports'"));
      expect(validator, contains("'is_pinned'"));
      expect(validator, contains("'is_hidden'"));
    });

    test('moderation is limited to pin/hide/delete by moderators', () {
      final block = houseGroupBlock();
      expect(block, contains('allow update: if isHouseModerator(houseId)'));
      expect(
        block,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly([\n            'is_pinned', 'is_hidden', 'moderated_by', 'moderated_at'",
        ),
      );
      expect(block, contains('allow delete: if isHouseModerator(houseId)'));
    });

    test('user role whitelist includes all M4 sender roles', () {
      final source = rules();
      final start = source.indexOf('data.role is string && data.role in [');
      expect(start, greaterThanOrEqualTo(0));
      final rolesBlock = source.substring(start, start + 800);
      for (final role in [
        'head_boy',
        'head_girl',
        'sports_captain',
        'sports_vice_captain',
        'faculty_advisor',
        'teacher_lead',
        'administrator',
      ]) {
        expect(rolesBlock, contains("'$role'"), reason: '$role must be a valid profile role');
      }
    });
  });

  group('M4f: house group UI', () {
    testWidgets('student auto-joins and sees a read-only group', (tester) async {
      await AuthService.cacheProfile(profile());
      await pumpGroup(tester);

      expect(find.text('Ruby House Group'), findsOneWidget);
      expect(find.byKey(const Key('house_group_membership_banner')), findsOneWidget);
      expect(find.textContaining('Auto-joined via verified house'), findsOneWidget);
      expect(find.byKey(const Key('house_group_read_only_banner')), findsOneWidget);
      expect(find.byKey(const Key('house_group_composer')), findsNothing);
      expect(find.byKey(const Key('house_group_attach_button')), findsNothing);
      expect(find.byKey(const Key('house_group_send_button')), findsNothing);
    });

    testWidgets('house captain sees the composer and attachment control', (tester) async {
      await AuthService.cacheProfile(
        profile(
          role: 'captain',
          name: 'Nayla Captain',
          scholar: '2310201',
        ),
      );
      await pumpGroup(tester);

      expect(find.byKey(const Key('house_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('house_group_message_field')), findsOneWidget);
      expect(find.byKey(const Key('house_group_attach_button')), findsOneWidget);
      expect(find.byKey(const Key('house_group_send_button')), findsOneWidget);
      expect(find.byKey(const Key('house_group_category_selector')), findsOneWidget);
      expect(find.byKey(const Key('house_group_read_only_banner')), findsNothing);
      expect(find.textContaining('Posting as House Captain'), findsOneWidget);
    });

    testWidgets('authorised staff sees the composer', (tester) async {
      await AuthService.cacheProfile(profile(role: 'teacher', name: 'Ms. Fatima'));
      await pumpGroup(tester);

      expect(find.byKey(const Key('house_group_composer')), findsOneWidget);
      expect(find.byKey(const Key('house_group_read_only_banner')), findsNothing);
    });

    testWidgets('cross-house opens an access-denied screen', (tester) async {
      await AuthService.cacheProfile(profile(house: 'ruby'));
      await pumpGroup(tester, houseId: 'sapphire');

      expect(find.byKey(const Key('house_group_access_denied')), findsOneWidget);
      expect(find.text('This house group is private'), findsOneWidget);
      expect(find.byKey(const Key('house_group_composer')), findsNothing);
      expect(find.byKey(const Key('house_group_membership_banner')), findsNothing);
    });

    testWidgets('house transfer opens the new house group', (tester) async {
      await AuthService.cacheProfile(profile(house: 'ruby'));
      await pumpGroup(tester, key: const ValueKey('ruby_group'));
      expect(find.text('Ruby House Group'), findsOneWidget);

      await AuthService.cacheProfile(profile(house: 'sapphire'));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpGroup(tester, key: const ValueKey('sapphire_group'));

      expect(find.text('Sapphire House Group'), findsOneWidget);
      expect(find.text('Ruby House Group'), findsNothing);
      expect(find.byKey(const Key('house_group_membership_banner')), findsOneWidget);
    });

    testWidgets('messages render category, pin, and hidden moderation', (tester) async {
      await AuthService.cacheProfile(profile(role: 'teacher', name: 'Ms. Fatima'));
      final messages = [
        message(id: 'pinned', text: 'Pinned announcement', pinned: true),
        message(
          id: 'hidden',
          text: 'Hidden note',
          hidden: true,
          category: 'general',
        ),
      ];
      await pumpGroup(tester, messages: Stream.value(messages));

      expect(find.text('Pinned announcement'), findsOneWidget);
      expect(find.byKey(const Key('house_group_pinned_pinned')), findsOneWidget);
      expect(find.text('Hidden note'), findsOneWidget);
      expect(find.text('HIDDEN'), findsOneWidget);
      expect(find.byKey(const Key('house_group_message_menu_pinned')), findsOneWidget);
    });

    testWidgets('hidden messages are filtered out for regular students', (tester) async {
      await AuthService.cacheProfile(profile());
      final messages = [
        message(id: 'visible', text: 'Visible update'),
        message(id: 'hidden', text: 'Hidden note', hidden: true),
      ];
      await pumpGroup(tester, messages: Stream.value(messages));

      expect(find.text('Visible update'), findsOneWidget);
      expect(find.text('Hidden note'), findsNothing);
      expect(find.text('HIDDEN'), findsNothing);
    });

    testWidgets('category filters narrow the visible messages', (tester) async {
      await AuthService.cacheProfile(profile());
      final messages = [
        message(id: 'announcement', text: 'Exam timetable released', category: 'announcement'),
        message(id: 'general', text: 'General house update', category: 'general'),
      ];
      await pumpGroup(tester, messages: Stream.value(messages));

      expect(find.text('Exam timetable released'), findsOneWidget);
      expect(find.text('General house update'), findsOneWidget);

      await tester.tap(find.byKey(const Key('house_group_filter_announcement')));
      await tester.pumpAndSettle();

      expect(find.text('Exam timetable released'), findsOneWidget);
      expect(find.text('General house update'), findsNothing);
    });
  });
}
