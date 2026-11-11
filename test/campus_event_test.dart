import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asb_house_hub/models/campus_event.dart';
import 'package:asb_house_hub/screens/events_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
    auth = AuthService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  CampusEvent event({
    String id = 'event_test_1',
    String title = 'Inter-House Athletics Meet',
  }) {
    final now = DateTime(2026, 11, 10, 9);
    return CampusEvent(
      id: id,
      title: title,
      description: 'Track and field finals on the main oval.',
      category: EventCategory.sports,
      startTime: now.add(const Duration(hours: 2)),
      endTime: now.add(const Duration(hours: 5)),
      venue: 'Main Campus Stadium',
      pointsAwarded: 150,
      pointsMultiplier: 1.5,
    );
  }

  group('createCampusEvent truthfulness', () {
    test('local mode caches the event and returns true', () async {
      final ok = await auth.createCampusEvent(event());

      expect(ok, isTrue);
      final cached = AuthService.getCachedEvents();
      expect(cached, hasLength(1));
      expect(cached.single.id, 'event_test_1');
      expect(cached.single.title, 'Inter-House Athletics Meet');
      expect(cached.single.category, EventCategory.sports);
    });

    test(
      'local mode synthesizes an id when the caller leaves it empty',
      () async {
        final ok = await auth.createCampusEvent(event(id: ''));

        expect(ok, isTrue);
        final cached = AuthService.getCachedEvents();
        expect(cached, hasLength(1));
        expect(cached.single.id, startsWith('event_'));
      },
    );

    test(
      'a denied live write returns false and never caches the event',
      () async {
        AuthService.isFirebaseLiveOverride = true;
        AuthService.firestoreFailureSimulated = Exception('permission-denied');

        final ok = await auth.createCampusEvent(event());

        expect(ok, isFalse);
        expect(AuthService.getCachedEvents(), isEmpty);
      },
    );

    test(
      'a denied live write does not disturb existing cached events',
      () async {
        final existing = event(id: 'event_existing', title: 'Existing Event');
        await AuthService.cacheEvents([existing]);

        AuthService.isFirebaseLiveOverride = true;
        AuthService.firestoreFailureSimulated = Exception('permission-denied');

        final ok = await auth.createCampusEvent(event());

        expect(ok, isFalse);
        final cached = AuthService.getCachedEvents();
        expect(cached, hasLength(1));
        expect(cached.single.id, 'event_existing');
        expect(cached.single.title, 'Existing Event');
      },
    );

    test(
      'a live write to a missing Firebase app returns false, not a phantom',
      () async {
        AuthService.isFirebaseLiveOverride = true;

        final ok = await auth.createCampusEvent(event());

        expect(ok, isFalse);
        expect(AuthService.getCachedEvents(), isEmpty);
      },
    );
  });

  group('CampusEvent lifecycle and serialization', () {
    final base = DateTime(2026, 11, 10, 10);

    CampusEvent lifecycleEvent({
      CampusEventStatus status = CampusEventStatus.published,
      bool isLive = false,
    }) {
      return CampusEvent(
        id: 'event_lifecycle',
        title: 'Lifecycle Event',
        description: 'Lifecycle checks.',
        category: EventCategory.cultural,
        houseScope: 'emerald',
        startTime: base.subtract(const Duration(hours: 1)),
        endTime: base.add(const Duration(hours: 1)),
        venue: 'Auditorium',
        status: status,
        isLive: isLive,
        createdAt: base.subtract(const Duration(days: 1)),
        authorUid: 'staff_1',
        authorName: 'Staff Member',
      );
    }

    test('derives live, ongoing and concluded states from the timetable', () {
      final published = lifecycleEvent(isLive: true);
      expect(published.isOngoingAt(base), isTrue);
      expect(published.isLiveAt(base), isTrue);
      expect(published.isConcludedAt(base), isFalse);
      expect(
        published.isConcludedAt(base.add(const Duration(hours: 1))),
        isTrue,
      );

      final cancelled = lifecycleEvent(
        isLive: true,
        status: CampusEventStatus.cancelled,
      );
      expect(cancelled.isOngoingAt(base), isFalse);
      expect(cancelled.isLiveAt(base), isFalse);
      expect(cancelled.formattedRemaining, 'Cancelled');

      final draft = lifecycleEvent(status: CampusEventStatus.draft);
      expect(draft.isUpcoming, isFalse);
      expect(draft.formattedRemaining, 'Draft');
    });

    test('Firestore map uses timestamps and server timestamps', () {
      final map = lifecycleEvent().toFirestoreMap(
        serverTimestampCreatedAt: true,
      );

      expect(map['start_time'], isA<Timestamp>());
      expect(map['end_time'], isA<Timestamp>());
      expect(map['created_at'], isA<FieldValue>());
      expect(map['status'], 'published');
      expect(map['house_scope'], 'emerald');
      expect(map['author_uid'], 'staff_1');
      expect(map['cancelled_reason'], '');
    });

    test('cancellation reason survives cache and Firestore maps', () {
      final cancelled = lifecycleEvent(
        status: CampusEventStatus.cancelled,
      ).copyWith(cancelledReason: 'Venue unavailable');

      expect(cancelled.toMap()['cancelled_reason'], 'Venue unavailable');
      expect(
        cancelled.toFirestoreMap()['cancelled_reason'],
        'Venue unavailable',
      );

      final roundTripped = CampusEvent.fromMap(cancelled.toMap());
      expect(roundTripped.cancelledReason, 'Venue unavailable');
      expect(roundTripped.status, CampusEventStatus.cancelled);
      expect(roundTripped.isCancelled, isTrue);
    });

    test('fromMap understands lifecycle status and legacy is_published', () {
      final live = CampusEvent.fromMap({
        'title': 'Translated Event',
        'start_time': Timestamp.fromDate(base),
        'end_time': Timestamp.fromDate(base.add(const Duration(hours: 1))),
        'status': 'draft',
      });
      expect(live.status, CampusEventStatus.draft);

      final legacy = CampusEvent.fromMap({
        'title': 'Legacy Event',
        'start_time': Timestamp.fromDate(base),
        'end_time': Timestamp.fromDate(base.add(const Duration(hours: 1))),
        'is_published': false,
      });
      expect(legacy.status, CampusEventStatus.draft);
    });
  });

  group('campus event validation and lifecycle writes', () {
    test(
      'rejects missing title, bad venue, reversed times and category all',
      () async {
        final base = DateTime(2026, 11, 10, 9);
        final invalid = [
          event(title: '   '),
          CampusEvent(
            id: 'bad_venue',
            title: 'Bad Venue',
            description: '',
            category: EventCategory.sports,
            startTime: base,
            endTime: base.add(const Duration(hours: 1)),
            venue: ' ',
          ),
          CampusEvent(
            id: 'bad_time',
            title: 'Bad Time',
            description: '',
            category: EventCategory.sports,
            startTime: base.add(const Duration(hours: 2)),
            endTime: base.add(const Duration(hours: 1)),
            venue: 'Hall',
          ),
          CampusEvent(
            id: 'bad_category',
            title: 'Bad Category',
            description: '',
            category: EventCategory.all,
            startTime: base,
            endTime: base.add(const Duration(hours: 1)),
            venue: 'Hall',
          ),
        ];

        for (final candidate in invalid) {
          expect(
            await auth.createCampusEvent(candidate),
            isFalse,
            reason: '${candidate.id} should be rejected',
          );
        }
        expect(AuthService.getCachedEvents(), isEmpty);
      },
    );

    test('rejects an unknown house scope instead of broadening it', () async {
      final invalid = CampusEvent(
        id: 'bad_scope',
        title: 'Bad Scope',
        description: '',
        category: EventCategory.sports,
        houseScope: 'Mars',
        startTime: DateTime(2026, 11, 10, 9),
        endTime: DateTime(2026, 11, 10, 10),
        venue: 'Hall',
      );

      expect(await auth.createCampusEvent(invalid), isFalse);
      expect(AuthService.getCachedEvents(), isEmpty);
    });

    test('local drafts are never stored in the shared device cache', () async {
      final draft = event().copyWith(status: CampusEventStatus.draft);

      expect(await auth.createCampusEvent(draft), isFalse);
      expect(AuthService.getCachedEvents(), isEmpty);
    });

    test('local updates preserve the event and apply scoped changes', () async {
      await auth.createCampusEvent(event());

      final updated = event(
        title: 'Updated Athletics Meet',
      ).copyWith(venue: 'Sports Complex', houseScope: 'EMERALD');
      expect(await auth.updateCampusEvent(updated), isTrue);

      final cached = AuthService.getCachedEvents().single;
      expect(cached.title, 'Updated Athletics Meet');
      expect(cached.venue, 'Sports Complex');
      expect(cached.houseScope, 'emerald');
    });

    test('local cancellation keeps the event, status, and reason', () async {
      await auth.createCampusEvent(event());

      expect(
        await auth.cancelCampusEvent(
          'event_test_1',
          reason: '  Venue unavailable  ',
        ),
        isTrue,
      );

      final cached = AuthService.getCachedEvents().single;
      expect(cached.status, CampusEventStatus.cancelled);
      expect(cached.isCancelled, isTrue);
      expect(cached.formattedRemaining, 'Cancelled');
      expect(cached.cancelledReason, 'Venue unavailable');
    });

    test('local event stream hides drafts and other houses', () async {
      await AuthService.cacheEvents([
        event(id: 'all_event').copyWith(houseScope: 'all'),
        event(id: 'ruby_event').copyWith(houseScope: 'ruby'),
        event(id: 'topaz_event').copyWith(houseScope: 'topaz'),
        event(id: 'draft_event').copyWith(status: CampusEventStatus.draft),
      ]);

      final ruby = await auth.getEventsStream(house: 'ruby').first;
      expect(ruby.map((e) => e.id), containsAll(['all_event', 'ruby_event']));
      expect(ruby.map((e) => e.id), isNot(contains('topaz_event')));
      expect(ruby.map((e) => e.id), isNot(contains('draft_event')));

      final staff = await auth
          .getEventsStream(house: 'ruby', includeDrafts: true)
          .first;
      expect(staff.map((e) => e.id), contains('draft_event'));
    });
  });

  group('student registration records', () {
    test('local registration writes and clears the device record', () async {
      expect(
        await auth.setEventRegistration(
          eventId: 'event_test_1',
          uid: 'uid_student',
          register: true,
          studentName: 'Aisha',
          scholarNo: '2310101',
        ),
        isTrue,
      );
      expect(
        AuthService.getLocalEventRegistrations(),
        contains('event_test_1'),
      );
      expect(
        await auth
            .getEventRegistrationStream(
              eventId: 'event_test_1',
              uid: 'uid_student',
            )
            .first,
        isTrue,
      );

      expect(
        await auth.setEventRegistration(
          eventId: 'event_test_1',
          uid: 'uid_student',
          register: false,
        ),
        isTrue,
      );
      expect(
        AuthService.getLocalEventRegistrations(),
        isNot(contains('event_test_1')),
      );
    });

    test('a denied live RSVP returns false and records nothing', () async {
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated = Exception('permission-denied');

      final ok = await auth.setEventRegistration(
        eventId: 'event_test_1',
        uid: 'uid_student',
        register: true,
      );

      expect(ok, isFalse);
      expect(AuthService.getLocalEventRegistrations(), isEmpty);
    });

    test('local attendee lists are empty rather than invented', () async {
      final attendees = await auth
          .getEventAttendeesStream('event_test_1')
          .first;
      expect(attendees, isEmpty);
    });
  });

  group('campus event rules contracts', () {
    final rules = File('firestore.rules').readAsStringSync();

    test('dedicated validator enforces lifecycle, venue and time', () {
      final match = RegExp(
        r'function isValidCampusEvent\(data\) \{([\s\S]*?)\n    \}',
      ).firstMatch(rules);
      expect(match, isNotNull);
      final body = match!.group(1)!;

      expect(
        body,
        contains("data.status in ['draft', 'published', 'cancelled']"),
      );
      expect(body, contains('data.end_time > data.start_time'));
      expect(body, contains("data.venue is string"));
      expect(body, contains("'house_scope'"));
      expect(
        body,
        contains(
          "data.house_scope in ['all', 'ruby', 'sapphire', 'emerald', 'topaz']",
        ),
      );
      expect(body, contains('points_awarded'));
    });

    test('events are staff-written and lifecycle-scoped for students', () {
      expect(rules.contains('match /events/{eventId}'), isTrue);
      expect(rules.contains("resource.data.status == 'published'"), isTrue);
      expect(rules.contains('isSameHouse(resource.data.house_scope)'), isTrue);
      expect(
        RegExp(
          r'allow create: if isAdmin\(\) &&\s+isValidCampusEvent\(request\.resource\.data\)',
        ).hasMatch(rules),
        isTrue,
      );
    });

    test('registration creates are lifecycle-gated, self-owned, and immutable', () {
      expect(rules.contains('match /registrations/{registrationUid}'), isTrue);
      expect(rules.contains('function getCampusEvent(eventId)'), isTrue);
      expect(
        rules.contains("getCampusEvent(eventId).status == 'published'"),
        isTrue,
      );
      expect(
        rules.contains('request.time < getCampusEvent(eventId).end_time'),
        isTrue,
      );
      expect(
        rules.contains('isSameHouse(getCampusEvent(eventId).house_scope)'),
        isTrue,
      );
      expect(
        RegExp(
          r'allow create: if isSignedIn\(\) &&\s+request\.auth\.uid == registrationUid',
        ).hasMatch(rules),
        isTrue,
      );
      expect(
        RegExp(
          r'allow delete: if isSignedIn\(\) &&\s+\(request\.auth\.uid == registrationUid \|\| isAdmin\(\)\)',
        ).hasMatch(rules),
        isTrue,
      );
      expect(RegExp(r'allow update: if false;').hasMatch(rules), isTrue);
    });
  });

  group('EventsScreen campus-event gaps', () {
    testWidgets('students see status badges and no staff publish action', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 10, 10);
      await AuthService.cacheEvents([
        CampusEvent(
          id: 'upcoming',
          title: 'Upcoming Debate',
          description: 'Debate finals.',
          category: EventCategory.academic,
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 4)),
          venue: 'Hall A',
        ),
        CampusEvent(
          id: 'concluded',
          title: 'Concluded Relay',
          description: 'Track relay.',
          category: EventCategory.sports,
          startTime: now.subtract(const Duration(hours: 4)),
          endTime: now.subtract(const Duration(hours: 2)),
          venue: 'Track',
        ),
        CampusEvent(
          id: 'cancelled',
          title: 'Cancelled Concert',
          description: 'Concert.',
          category: EventCategory.cultural,
          startTime: now.add(const Duration(days: 1)),
          endTime: now.add(const Duration(days: 1, hours: 2)),
          venue: 'Auditorium',
          status: CampusEventStatus.cancelled,
        ),
      ]);

      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(userHouse: 'ruby', mockNow: now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('CONCLUDED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.byTooltip('Publish Campus Event'), findsNothing);
      expect(find.text('Ruby'), findsOneWidget);
      await tester.tap(find.text('Ruby'));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming Debate'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff can open the preview composer', (tester) async {
      await AuthService.cacheProfile({
        'uid': 'teacher_1',
        'full_name': 'Teacher One',
        'scholar_no': 'T100',
        'role': 'teacher',
        'house_name': 'ruby',
      });

      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: EventsScreen(userHouse: 'ruby')),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Publish Campus Event'), findsOneWidget);
      await tester.tap(find.byTooltip('Publish Campus Event'));
      await tester.pumpAndSettle();

      expect(find.text('Publish Campus Event'), findsOneWidget);
      expect(find.text('Preview & Publish'), findsOneWidget);
      expect(find.text('Save Private Draft'), findsOneWidget);
      expect(find.text('House Scope'), findsOneWidget);
      expect(find.textContaining('Starts\n'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
