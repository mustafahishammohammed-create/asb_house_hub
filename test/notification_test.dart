import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asb_house_hub/models/app_notification.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/screens/notification_center_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/notification_service.dart';
import 'package:asb_house_hub/services/timetable_service.dart';

class _RecordingNotificationService extends NotificationService {
  List<String> lastRecipients = [];
  String lastTitle = '';
  String lastBody = '';
  String lastType = '';
  String lastCategory = '';
  String lastPriority = '';
  String lastDedupe = '';
  String lastSource = '';
  NotificationFanOutResult result = const NotificationFanOutResult(
    total: 0,
    sent: 0,
    failed: 0,
  );

  @override
  Future<NotificationFanOutResult> fanOutToUsers({
    required Iterable<String> recipientUids,
    required String title,
    required String body,
    required String type,
    required String category,
    required String dedupeKey,
    String priority = 'normal',
    String sourceId = '',
    String roomId = '',
    DateTime? eventTime,
  }) async {
    lastRecipients = recipientUids.toList();
    lastTitle = title;
    lastBody = body;
    lastType = type;
    lastCategory = category;
    lastPriority = priority;
    lastDedupe = dedupeKey;
    lastSource = sourceId;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    NotificationService.firestoreFailureSimulated = null;
    NotificationService.recipientsLoader = null;
    TimetableService.firestoreFailureSimulated = null;
    await AuthService.cacheProfile({
      'uid': 'uid_student_1',
      'scholar_no': '2310911',
      'full_name': 'Ayaan Mohammed',
      'role': 'student',
      'class_id': '11D',
      'class_verified': true,
      'house_name': 'ruby',
    });
    service = NotificationService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    NotificationService.firestoreFailureSimulated = null;
    NotificationService.recipientsLoader = null;
    TimetableService.firestoreFailureSimulated = null;
  });

  AppNotification notification({
    String id = 'n1',
    String title = 'Timetable updated',
    String body = 'A new Tuesday timetable is live.',
    String type = 'timetable_published',
    String category = 'timetable',
    String priority = 'high',
    String dedupeKey = 'timetable_v1',
    String sourceId = 'v1',
    bool isRead = false,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      category: category,
      priority: priority,
      dedupeKey: dedupeKey,
      sourceId: sourceId,
      isRead: isRead,
      timestamp: timestamp ?? DateTime(2026, 11, 8, 9, 30),
    );
  }

  final profiles = <Map<String, dynamic>>[
    {
      'uid': 'uid_student_1',
      'class_id': '11D',
      'class_verified': true,
      'house_name': 'ruby',
    },
    {
      'uid': 'uid_student_2',
      'class_id': '11D',
      'class_verified': true,
      'house_name': 'sapphire',
    },
    {
      'uid': 'uid_unverified',
      'class_id': '11D',
      'class_verified': false,
      'house_name': 'ruby',
    },
    {
      'uid': 'uid_other_class',
      'class_id': '11C',
      'class_verified': true,
      'house_name': 'ruby',
    },
    {
      'uid': 'uid_teacher_1',
      'class_id': '',
      'class_verified': false,
      'house_name': 'ruby',
    },
    {
      'uid': 'uid_parent_1',
      'class_id': '',
      'class_verified': false,
      'house_name': 'ruby',
    },
  ];

  group('M6a: notification model and payload', () {
    test('notification round-trips through a Firestore-shaped map', () {
      final original = notification();
      final restored =
          AppNotification.fromMap(original.id, original.toMap());

      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.type, original.type);
      expect(restored.category, 'timetable');
      expect(restored.priority, 'high');
      expect(restored.dedupeKey, 'timetable_v1');
      expect(restored.sourceId, 'v1');
      expect(restored.timestamp, original.timestamp);
      expect(restored.isRead, isFalse);
    });

    test('a missing is_read field means unread', () {
      final restored = AppNotification.fromMap('n1', {
        'title': 'Class announcement',
        'body': 'Homework moved.',
        'timestamp': DateTime(2026, 11, 8),
      });
      expect(restored.isRead, isFalse);
      expect(restored.isUnread, isTrue);
      expect(restored.category, 'system');
      expect(restored.priority, 'normal');
    });

    test('invalid category and priority normalize safely', () {
      expect(normalizeNotificationCategory('timetable'), 'timetable');
      expect(normalizeNotificationCategory('NOT-A-CATEGORY'), 'system');
      expect(normalizeNotificationCategory(null), 'system');
      expect(normalizeNotificationPriority('urgent'), 'urgent');
      expect(normalizeNotificationPriority('emergency'), 'normal');
      expect(normalizeNotificationPriority(null), 'normal');
    });

    test('unread count is computed from the stream list', () {
      final list = [
        notification(id: 'n1'),
        notification(id: 'n2', isRead: true),
        notification(id: 'n3'),
      ];
      expect(AppNotification.unreadCount(list), 2);
    });

    test('fan-out payload omits is_read and clips long fields', () {
      final payload = NotificationService.buildNotificationPayload(
        title: 'T' * 150,
        body: 'B' * 900,
        type: 'timetable_published',
        category: 'timetable',
        priority: 'high',
        dedupeKey: 'timetable_v1',
        sourceId: 'v1',
        roomId: '11D',
        eventTime: DateTime(2026, 11, 8, 8),
      );

      expect(payload.containsKey('is_read'), isFalse);
      expect((payload['title'] as String).length, 100);
      expect((payload['body'] as String).length, 500);
      expect(payload['category'], 'timetable');
      expect(payload['priority'], 'high');
      expect(payload['dedupe_key'], 'timetable_v1');
      expect(payload['source_id'], 'v1');
      expect(payload['room_id'], '11D');
      expect(payload['timestamp'], isA<Object>());
    });

    test('dedupe document IDs are deterministic per event and recipient', () {
      final first =
          NotificationService.notificationDocId('class_11D_msg1', 'uid_a');
      final retry =
          NotificationService.notificationDocId('class_11D_msg1', 'uid_a');
      final otherUser =
          NotificationService.notificationDocId('class_11D_msg1', 'uid_b');
      final otherEvent =
          NotificationService.notificationDocId('class_11D_msg2', 'uid_a');

      expect(retry, first);
      expect(otherUser, isNot(first));
      expect(otherEvent, isNot(first));
      expect(
        NotificationService.notificationDocId('a/b', 'uid_a'),
        isNot(contains('/')),
      );
    });

    test('fan-out result warns honestly on total and partial failure', () {
      const totalFailure =
          NotificationFanOutResult(total: 10, sent: 0, failed: 10);
      const partial =
          NotificationFanOutResult(total: 10, sent: 8, failed: 2);
      const complete =
          NotificationFanOutResult(total: 10, sent: 10, failed: 0);

      expect(totalFailure.warning, contains('could not be delivered'));
      expect(partial.warning, contains('8 of 10'));
      expect(complete.warning, isNull);
      expect(totalFailure.isComplete, isFalse);
      expect(partial.isPartial, isTrue);
      expect(complete.isComplete, isTrue);
    });
  });

  group('M6b: recipient scoping (tests 60-62)', () {
    test('60: timetable recipients are the verified class only', () async {
      NotificationService.recipientsLoader = (scope, id) async {
        expect(scope, 'class');
        expect(id, '11D');
        return profiles;
      };

      final recipients = await service.resolveRecipients(
        scope: 'class',
        scopeId: '11D',
        excludeUid: 'uid_teacher_1',
      );

      expect(recipients, ['uid_student_1', 'uid_student_2']);
      expect(recipients, isNot(contains('uid_unverified')));
      expect(recipients, isNot(contains('uid_other_class')));
    });

    test('61: house recipients are exactly that house, excluding the sender',
        () async {
      NotificationService.recipientsLoader = (scope, id) async {
        expect(scope, 'house');
        expect(id, 'ruby');
        return profiles;
      };

      final recipients = await service.resolveRecipients(
        scope: 'house',
        scopeId: 'ruby',
        excludeUid: 'uid_student_1',
      );

      expect(recipients, [
        'uid_other_class',
        'uid_parent_1',
        'uid_teacher_1',
        'uid_unverified',
      ]);
      expect(recipients, isNot(contains('uid_student_1')));
      expect(recipients, isNot(contains('uid_student_2')),
          reason: 'uid_student_2 belongs to sapphire house');
    });

    test('62: class recipients are verified 11D members only', () async {
      NotificationService.recipientsLoader = (scope, id) async => profiles;

      final recipients = await service.resolveRecipients(
        scope: 'class',
        scopeId: '11d',
        excludeUid: 'uid_student_1',
      );

      expect(recipients, ['uid_student_2']);
      expect(recipients, isNot(contains('uid_unverified')));
    });

    test('unknown scopes, empty ids, and loader failures yield no recipients',
        () async {
      expect(
        await service.resolveRecipients(scope: 'school', scopeId: 'all'),
        isEmpty,
      );
      expect(
        await service.resolveRecipients(scope: 'class', scopeId: '  '),
        isEmpty,
      );

      NotificationService.recipientsLoader =
          (scope, id) async => throw Exception('offline');
      expect(
        await service.resolveRecipients(scope: 'class', scopeId: '11D'),
        isEmpty,
      );
    });

    test('recipient filter deduplicates repeated UIDs', () async {
      NotificationService.recipientsLoader = (scope, id) async => [
            ...profiles,
            {
              'uid': 'uid_student_2',
              'class_id': '11D',
              'class_verified': true,
              'house_name': 'sapphire',
            },
          ];
      final recipients = await service.resolveRecipients(
        scope: 'class',
        scopeId: '11D',
      );
      expect(recipients.where((uid) => uid == 'uid_student_2').length, 1);
    });
  });

  group('M6c: truthful fan-out', () {
    test('offline fan-out is reported as skipped, never as sent', () async {
      final result = await service.fanOutToUsers(
        recipientUids: const ['uid_student_1', 'uid_student_2'],
        title: 'Timetable updated',
        body: 'Tuesday timetable is live.',
        type: 'timetable_published',
        category: 'timetable',
        dedupeKey: 'timetable_v1',
      );

      expect(result.skipped, isTrue);
      expect(result.sent, 0);
      expect(result.failed, 0);
      expect(result.total, 1, reason: 'the current user is never self-notified');
    });

    test('a denied fan-out reports every recipient as failed', () async {
      AuthService.isFirebaseLiveOverride = true;
      NotificationService.firestoreFailureSimulated =
          Exception('permission-denied');

      final result = await service.fanOutToUsers(
        recipientUids: const ['uid_student_2', 'uid_student_3'],
        title: 'Class announcement',
        body: 'Homework moved.',
        type: 'class_announcement',
        category: 'class',
        dedupeKey: 'class_11D_msg1',
      );

      expect(result.failed, 2);
      expect(result.sent, 0);
      expect(result.isComplete, isFalse);
      expect(result.warning, contains('could not be delivered'));
    });

    test('an empty roster is complete and does not touch Firestore', () async {
      AuthService.isFirebaseLiveOverride = true;
      final result = await service.fanOutToUsers(
        recipientUids: const [],
        title: 'No recipients',
        body: 'Nothing to send.',
        type: 'class_announcement',
        category: 'class',
        dedupeKey: 'class_11D_empty',
      );
      expect(result.total, 0);
      expect(result.isComplete, isTrue);
      expect(result.skipped, isFalse);
    });

    test('read state is not part of the fan-out payload', () {
      final payload = NotificationService.buildNotificationPayload(
        title: 'House announcement',
        body: 'Sports day moved.',
        type: 'house_announcement',
        category: 'house',
        dedupeKey: 'house_ruby_msg1',
        sourceId: 'msg1',
      );
      expect(payload.containsKey('is_read'), isFalse);
    });
  });

  group('M6d: event conveniences and publish hook', () {
    setUp(() {
      NotificationService.recipientsLoader = (scope, id) async => profiles;
    });

    test('60: timetable notification targets the verified class', () async {
      final recorder = _RecordingNotificationService();
      final result = await recorder.notifyTimetablePublished(
        classId: '11D',
        versionId: 'v3',
        dayOfWeek: 'Tuesday',
        version: 3,
        publisherUid: 'uid_teacher_1',
        publisherName: 'Ms. Fatima',
      );

      expect(result.isComplete, isTrue);
      expect(recorder.lastRecipients, ['uid_student_1', 'uid_student_2']);
      expect(recorder.lastCategory, 'timetable');
      expect(recorder.lastType, 'timetable_published');
      expect(recorder.lastPriority, 'high');
      expect(recorder.lastTitle, contains('11D'));
      expect(recorder.lastBody, contains('Ms. Fatima'));
      expect(recorder.lastDedupe, 'timetable_v3');
      expect(recorder.lastSource, 'v3');
    });

    test('61: house announcement targets the house and excludes the sender',
        () async {
      final recorder = _RecordingNotificationService();
      await recorder.notifyHouseAnnouncement(
        houseId: 'ruby',
        messageId: 'msg1',
        senderUid: 'uid_student_1',
        senderName: 'Ayaan',
        preview: 'Sports day moved to Thursday.',
      );

      expect(recorder.lastRecipients, [
        'uid_other_class',
        'uid_parent_1',
        'uid_teacher_1',
        'uid_unverified',
      ]);
      expect(recorder.lastRecipients, isNot(contains('uid_student_1')));
      expect(recorder.lastRecipients, isNot(contains('uid_student_2')),
          reason: 'a sapphire student must never receive a ruby announcement');
      expect(recorder.lastCategory, 'house');
      expect(recorder.lastType, 'house_announcement');
      expect(recorder.lastTitle, contains('RUBY'));
      expect(recorder.lastDedupe, 'house_ruby_msg1');
      expect(recorder.lastSource, 'msg1');
    });

    test('62: class announcement targets the verified class only', () async {
      final recorder = _RecordingNotificationService();
      await recorder.notifyClassAnnouncement(
        classId: '11D',
        messageId: 'msg2',
        senderUid: 'uid_student_1',
        senderName: 'Ayaan',
        preview: 'Bring the physics lab report.',
      );

      expect(recorder.lastRecipients, ['uid_student_2']);
      expect(recorder.lastCategory, 'class');
      expect(recorder.lastType, 'class_announcement');
      expect(recorder.lastTitle, contains('11D'));
      expect(recorder.lastDedupe, 'class_11D_msg2');
      expect(recorder.lastSource, 'msg2');
    });

    test('publishTimetable invokes the M6 fan-out after a successful publish',
        () async {
      final recorder = _RecordingNotificationService()
        ..result = const NotificationFanOutResult(
          total: 2,
          sent: 2,
          failed: 0,
        );
      final timetable = TimetableService(notifications: recorder);
      AuthService.isFirebaseLiveOverride = true;

      final template = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Tuesday',
        createdByUid: 'uid_teacher_1',
        createdByName: 'Ms. Fatima',
      );
      final ok = await timetable.publishTimetable(
        template,
        publisherUid: 'uid_teacher_1',
        publisherName: 'Ms. Fatima',
        enforceConflicts: false,
      );

      expect(ok, isTrue);
      expect(recorder.lastCategory, 'timetable');
      expect(recorder.lastType, 'timetable_published');
      expect(recorder.lastTitle, contains('11D'));
      expect(timetable.lastNotificationResult?.sent, 2);
    });
  });

  group('M6e: rules source contract', () {
    String rules() => File('firestore.rules').readAsStringSync();

    String notificationValidator() {
      final source = rules();
      final start = source.indexOf('function isValidNotification(data)');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('function isValidAcademicClass', start);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    test('validator accepts the M6 fields and optional read state', () {
      final validator = notificationValidator();
      for (final field in [
        'category',
        'priority',
        'dedupe_key',
        'source_id',
        'is_read',
      ]) {
        expect(validator, contains("'$field'"));
      }
      expect(validator, contains("hasRequiredFields(['title', 'body', 'timestamp'])"));
      expect(validator, contains("['timetable', 'house', 'class', 'chat', 'points', 'system']"));
      expect(validator, contains("['normal', 'high', 'urgent']"));
    });

    test('read marking is owner-only and limited to is_read', () {
      final source = rules();
      expect(
        source,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['is_read'])",
        ),
      );
      expect(source, contains('allow read: if isOwner(userId) || isAdmin();'));
    });

    test('deduplicated fan-out retries cannot change read state', () {
      final source = rules();
      final start = source.indexOf('match /notifications/{notificationId}');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('allow delete: if isOwner(userId) || isAdmin();', start);
      final block = source.substring(start, end);
      expect(block, contains("'dedupe_key' in resource.data"));
      expect(block, contains("'source_id' in resource.data"));
      expect(block, contains('request.resource.data.dedupe_key == resource.data.dedupe_key'));
      expect(block, contains('request.resource.data.source_id == resource.data.source_id'));
      expect(block, isNot(contains("'is_read', 'title'")));
    });

    test('notification create requires a signed-in validated writer', () {
      final source = rules();
      expect(
        source,
        contains(
          'allow create: if isSignedIn() && isValidNotification(request.resource.data);',
        ),
      );
    });
  });

  group('M6f: notification center UI', () {
    Future<void> pumpCenter(
      WidgetTester tester, {
      required Stream<List<AppNotification>> stream,
      Future<bool> Function(AppNotification)? onMarkRead,
      Future<bool> Function(List<AppNotification>)? onMarkAllRead,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCenterScreen(
            notificationsStream: stream,
            onMarkRead: onMarkRead,
            onMarkAllRead: onMarkAllRead,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders unread and read notifications with priority', (tester) async {
      final messages = [
        notification(id: 'n1', title: 'Timetable updated'),
        notification(
          id: 'n2',
          title: 'Class announcement',
          category: 'class',
          priority: 'normal',
          isRead: true,
        ),
      ];
      await pumpCenter(tester, stream: Stream.value(messages));

      expect(find.text('Timetable updated'), findsOneWidget);
      expect(find.text('Class announcement'), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_n1')), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_n2')), findsNothing);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.byKey(const Key('notification_mark_all')), findsOneWidget);
    });

    testWidgets('tapping an unread notification marks it read', (tester) async {
      final tapped = <String>[];
      final messages = [notification(id: 'n1')];
      await pumpCenter(
        tester,
        stream: Stream.value(messages),
        onMarkRead: (n) async {
          tapped.add(n.id);
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('notification_tile_n1')));
      await tester.pumpAndSettle();

      expect(tapped, ['n1']);
    });

    testWidgets('tap on an already-read notification does nothing', (tester) async {
      var calls = 0;
      final messages = [notification(id: 'n1', isRead: true)];
      await pumpCenter(
        tester,
        stream: Stream.value(messages),
        onMarkRead: (n) async {
          calls++;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('notification_tile_n1')));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('mark all read sends the full list to the service', (tester) async {
      List<AppNotification>? received;
      final messages = [
        notification(id: 'n1'),
        notification(id: 'n2'),
      ];
      await pumpCenter(
        tester,
        stream: Stream.value(messages),
        onMarkAllRead: (list) async {
          received = list;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('notification_mark_all')));
      await tester.pumpAndSettle();

      expect(received?.length, 2);
      expect(received?.every((n) => n.isUnread), isTrue);
    });

    testWidgets('empty stream shows the empty state', (tester) async {
      await pumpCenter(tester, stream: const Stream.empty());
      expect(find.byKey(const Key('notification_center_empty')), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('failed read marking surfaces an error', (tester) async {
      await pumpCenter(
        tester,
        stream: Stream.value([notification(id: 'n1')]),
        onMarkRead: (n) async => false,
      );

      await tester.tap(find.byKey(const Key('notification_tile_n1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not mark the notification as read. Try again.'),
        findsOneWidget,
      );
    });
  });
}
