import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asb_house_hub/models/campus_event.dart';
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

    test('local mode synthesizes an id when the caller leaves it empty',
        () async {
      final ok = await auth.createCampusEvent(event(id: ''));

      expect(ok, isTrue);
      final cached = AuthService.getCachedEvents();
      expect(cached, hasLength(1));
      expect(cached.single.id, startsWith('event_'));
    });

    test('a denied live write returns false and never caches the event',
        () async {
      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated =
          Exception('permission-denied');

      final ok = await auth.createCampusEvent(event());

      expect(ok, isFalse);
      expect(AuthService.getCachedEvents(), isEmpty);
    });

    test('a denied live write does not disturb existing cached events',
        () async {
      final existing = event(id: 'event_existing', title: 'Existing Event');
      await AuthService.cacheEvents([existing]);

      AuthService.isFirebaseLiveOverride = true;
      AuthService.firestoreFailureSimulated =
          Exception('permission-denied');

      final ok = await auth.createCampusEvent(event());

      expect(ok, isFalse);
      final cached = AuthService.getCachedEvents();
      expect(cached, hasLength(1));
      expect(cached.single.id, 'event_existing');
      expect(cached.single.title, 'Existing Event');
    });

    test('a live write to a missing Firebase app returns false, not a phantom',
        () async {
      AuthService.isFirebaseLiveOverride = true;

      final ok = await auth.createCampusEvent(event());

      expect(ok, isFalse);
      expect(AuthService.getCachedEvents(), isEmpty);
    });
  });
}
