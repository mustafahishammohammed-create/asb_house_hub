import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/academic_class.dart';
import 'package:asb_house_hub/models/app_notification.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/screens/home_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/notification_service.dart';
import 'package:asb_house_hub/services/timetable_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    await TimetableService.initPreferences();
    AuthService.isFirebaseLiveOverride = false;
    NotificationService.notificationsStreamOverride = null;
    NotificationService.recipientsLoader = null;
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    NotificationService.notificationsStreamOverride = null;
    NotificationService.recipientsLoader = null;
  });

  Future<void> seedStudent({
    String classLevel = 'Grade 11',
    String division = 'D',
    String classId = '11D',
    String scholarNo = '2310910',
    bool verified = true,
    String role = 'student',
    String classTeacher = 'Ms. Fatima',
  }) async {
    await AuthService.cacheProfile({
      'uid': 'uid_$scholarNo',
      'full_name': 'Mariam Al-Sayed',
      'scholar_no': scholarNo,
      'house_name': 'ruby',
      'class_id': classId,
      'class_level': classLevel,
      'division': division,
      'class_verified': verified,
      'role': role,
    });
    await AuthService.cacheHouse('ruby');
    await AuthService().saveAcademicClass(
      AcademicClass(
        classId: classId,
        grade: classLevel,
        section: division,
        classTeacher: classTeacher,
      ),
    );
  }

  Future<void> seedMondayTimetable(String classId) async {
    final version = ClassTimetableVersion.template(
      classId: classId,
      dayOfWeek: 'Monday',
      effectiveFrom: DateTime(2026, 11, 1),
      createdByName: 'Ms. Fatima',
    ).copyWith(
      id: 'tt_${classId}_monday_v1',
      status: TimetableStatus.published,
      version: 1,
      publishedAt: DateTime(2026, 11, 1, 8),
    );
    await TimetableService().cacheVersions(classId, 'Monday', [version]);
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    DateTime? now,
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          initialIndex: 0,
          mockNow: now ?? DateTime(2026, 11, 9, 8, 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('NotificationUnreadBreakdown counts only unread class/house/timetable',
      () {
    final breakdown = NotificationUnreadBreakdown.from([
      AppNotification(title: 'Class 1', body: '', category: 'class'),
      AppNotification(
        title: 'Class read',
        body: '',
        category: 'class',
        isRead: true,
      ),
      AppNotification(title: 'House', body: '', category: 'house'),
      AppNotification(title: 'Timetable', body: '', category: 'timetable'),
      AppNotification(title: 'Points', body: '', category: 'points'),
    ]);

    expect(breakdown.total, 4);
    expect(breakdown.classCount, 1);
    expect(breakdown.houseCount, 1);
    expect(breakdown.timetableCount, 1);
    expect(NotificationUnreadBreakdown.empty.hasAny, isFalse);
  });

  testWidgets(
      'verified class shows badge, class teacher, eight periods, current/next/break',
      (tester) async {
    await seedStudent();
    await seedMondayTimetable('11D');

    await pumpDashboard(tester);

    expect(find.textContaining('Verified Class · 11D'), findsOneWidget);
    expect(find.textContaining('Class Teacher · Ms. Fatima'), findsOneWidget);
    expect(find.text("Today's Timetable"), findsOneWidget);
    expect(find.textContaining('11D · Monday · 8 periods'), findsOneWidget);
    expect(find.textContaining('Now · P1', findRichText: true), findsWidgets);
    expect(find.textContaining('Next · P2', findRichText: true), findsWidgets);
    expect(find.textContaining('Break · ', findRichText: true), findsWidgets);
    expect(find.text('P8'), findsOneWidget);
    expect(find.text('BRK'), findsOneWidget);
    expect(find.text('Period 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified class never renders the class timetable', (tester) async {
    await seedStudent(verified: false);
    await seedMondayTimetable('11D');

    await pumpDashboard(tester);

    expect(find.text('Class not verified'), findsOneWidget);
    expect(find.textContaining('awaiting school verification'), findsOneWidget);
    expect(find.text("Today's Timetable"), findsNothing);
    expect(find.text('BRK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary student gets the simpler interface without council modules',
      (tester) async {
    await seedStudent(
      classLevel: 'Grade 3',
      division: 'C',
      classId: '3C',
      classTeacher: 'Ms. Noor',
    );
    await seedMondayTimetable('3C');

    await pumpDashboard(tester);

    expect(find.textContaining('Verified Class · 3C'), findsOneWidget);
    expect(find.textContaining('Class Teacher · Ms. Noor'), findsOneWidget);
    expect(find.text("Today's Timetable"), findsOneWidget);
    expect(find.text('📸 Live Event Wall'), findsNothing);
    expect(find.text('Inter-House Sports League'), findsNothing);
    expect(find.text('1-on-1 Council & Student Chats'), findsNothing);
    expect(find.text('🗳️ Student Council Elections'), findsNothing);
    expect(find.text('🏫 My Class Group'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renders unread class/house/timetable counts',
      (tester) async {
    await seedStudent();
    await seedMondayTimetable('11D');
    NotificationService.notificationsStreamOverride =
        Stream<List<AppNotification>>.value([
      AppNotification(title: 'Class 1', body: '', category: 'class'),
      AppNotification(title: 'Class 2', body: '', category: 'class'),
      AppNotification(title: 'House', body: '', category: 'house'),
      AppNotification(title: 'Timetable 1', body: '', category: 'timetable'),
      AppNotification(title: 'Timetable 2', body: '', category: 'timetable'),
      AppNotification(title: 'Points', body: '', category: 'points'),
    ]).asBroadcastStream();

    await pumpDashboard(tester);

    expect(find.text('Class 2'), findsOneWidget);
    expect(find.text('House 1'), findsOneWidget);
    expect(find.text('Timetable 2'), findsOneWidget);
    expect(find.text('Unread Announcements'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow mobile viewport renders the timetable without overflow',
      (tester) async {
    await seedStudent();
    await seedMondayTimetable('11D');

    await pumpDashboard(tester, size: const Size(360, 740));

    expect(find.text("Today's Timetable"), findsOneWidget);
    expect(find.text('BRK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
