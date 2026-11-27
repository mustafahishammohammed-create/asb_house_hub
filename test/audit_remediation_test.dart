import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/models/election_ballot.dart';
import 'package:asb_house_hub/models/sports_tournament.dart';
import 'package:asb_house_hub/models/sports_trophy.dart';
import 'package:asb_house_hub/screens/home_screen.dart';
import 'package:asb_house_hub/screens/merch_store_tab.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/chat_service.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/services/notification_service.dart';
import 'package:asb_house_hub/services/pass_document_exporter.dart';
import 'package:asb_house_hub/services/voucher_security_service.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GlobalWalletStore.resetSession();
  });

  group('Audit Remediation Regression Tests', () {
    test('SportsTrophyRecord.toMap emits both title and tournament_title', () {
      final record = SportsTrophyRecord(
        trophyId: 'trophy_2026_1',
        tournamentTitle: 'Inter-House Basketball Finals',
        sportType: SportType.basketball,
        winningHouse: 'ruby',
        runnerUpHouse: 'sapphire',
        pointsAwarded: 150,
        runnerUpPoints: 75,
        awardedAt: DateTime.utc(2026, 11, 26),
      );

      final map = record.toMap();
      expect(map['title'], 'Inter-House Basketball Finals');
      expect(map['tournament_title'], 'Inter-House Basketball Finals');
      final decoded = SportsTrophyRecord.fromMap(map);
      expect(decoded.tournamentTitle, 'Inter-House Basketball Finals');
    });

    testWidgets(
      'MerchStoreTab handles empty userHouse without RangeError',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MerchStoreTab(
                userHouse: '',
                houseColor: Colors.red,
                houseDark: Colors.redAccent,
                scholarNo: '12345',
                studentName: 'Test Student',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('For You (House)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test('VoucherSecurityService rejects blank or missing bills', () async {
      final blankRes = await VoucherSecurityService.claimStoreVoucher(
        billNo: '   ',
        evaluatorName: 'Staff Evaluator',
      );
      expect(blankRes.success, isFalse);

      final missingRes = await VoucherSecurityService.claimStoreVoucher(
        billNo: 'ASB-MISSING-9999',
        evaluatorName: 'Staff Evaluator',
      );
      expect(missingRes.success, isFalse);
      expect(missingRes.alreadyClaimed, isFalse);
    });

    test('GamificationSecurityService score-proof nonce blocks replay after consume', () async {
      GamificationSecurityService.setTestSecret('AUDIT_TEST_SECRET');
      GamificationSecurityService.resetConsumedNoncesForTesting();

      final token = GamificationSecurityService.generateScoreProofToken(
        scholarNo: '12345',
        activityId: 'quiz_1',
        points: 25,
      );
      final verified = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '12345',
        expectedActivityId: 'quiz_1',
      );
      expect(verified.isValid, isTrue);
      expect(verified.nonce, isNotNull);

      await GamificationSecurityService.consumeNonce(verified.nonce!);
      final replay = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '12345',
        expectedActivityId: 'quiz_1',
      );
      expect(replay.isValid, isFalse);
    });

    test('GeminiAiService transmits API key in x-goog-api-key header, never URL query', () async {
      http.Request? captured;
      GeminiAiService.httpClientOverride = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'OK'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });
      addTearDown(() => GeminiAiService.httpClientOverride = null);

      final res = await GeminiAiService.validateApiKey('secret_demo_key_999');
      expect(res.isValid, isTrue);
      expect(captured, isNotNull);
      expect(captured!.url.queryParameters.containsKey('key'), isFalse);
      expect(captured!.url.toString(), isNot(contains('secret_demo_key_999')));
      expect(captured!.headers['x-goog-api-key'], 'secret_demo_key_999');
    });

    test('firestore.indexes.json manifest is valid JSON and wired in firebase.json', () {
      final firebaseJson =
          jsonDecode(File('firebase.json').readAsStringSync()) as Map<String, dynamic>;
      final firestoreCfg = firebaseJson['firestore'] as Map<String, dynamic>;
      expect(firestoreCfg['indexes'], 'firestore.indexes.json');

      final indexesJson =
          jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map<String, dynamic>;
      final indexes = indexesJson['indexes'] as List<dynamic>;
      expect(indexes, isNotEmpty);
      final groups = indexes.map((e) => (e as Map<String, dynamic>)['collectionGroup']).toSet();
      expect(groups, containsAll(['events', 'medical_leaves', 'users', 'timetable_versions', 'timetable_audit']));
    });

    test('PassDocumentExporter embeds vector QR rectangles in PDF 1.4 pass bytes', () {
      final bytes = PassDocumentExporter.buildPassPdf(
        title: 'Store Pass #101',
        subtitle: 'Scholar #12345',
        details: '1x Ruby Hoodie (M)',
        totalInfo: 'BHD 12.000',
        qrData: '{"receipt":"ASB-101","sig":"abc123"}',
      );
      final pdfText = utf8.decode(bytes, allowMalformed: true);
      expect(pdfText, startsWith('%PDF-1.4'));
      expect(pdfText, contains('re f'));
      expect(pdfText, contains('Verification Payload:'));
    });

    test('ClassTimetableVersion.validate enforces 700 KB aggregate inline image cap', () {
      final hugeImage = 'data:image/jpeg;base64,${'A' * 100000}';
      final slots = List.generate(
        8,
        (i) => TimetableSlot(
          periodNumber: i + 1,
          startMinute: 480 + i * 45 + (i >= 4 ? 30 : 0),
          subject: 'Subject ${i + 1}',
          imageUrl: hugeImage,
        ),
      );
      final version = ClassTimetableVersion(
        id: 'tt_10A_Monday_v1',
        classId: '10A',
        dayOfWeek: 'Monday',
        version: 1,
        status: TimetableStatus.draft,
        effectiveFrom: DateTime.utc(2026, 11, 26),
        breakAfterPeriod: 4,
        breakStartMinute: 680,
        slots: slots,
      );
      final errors = version.validate();
      expect(errors.any((e) => e.contains('700 KB')), isTrue);
    });

    test('Mobile release targets satisfy FlutterFire iOS 15+ and keystore wiring', () {
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbxproj, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
      expect(pbxproj, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));

      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('signingConfigs.getByName("release")'));
    });

    test('CredentialVaultService uses per-device random secret without static default literal', () {
      CredentialVaultService.setTestSecret(null);
      final tokenA = CredentialVaultService.encrypt('secret_value_1');
      final tokenB = CredentialVaultService.encrypt('secret_value_1');
      expect(tokenA, isNotNull);
      expect(tokenA, isNot(equals(tokenB)));
      expect(CredentialVaultService.decrypt(tokenA), equals('secret_value_1'));
      CredentialVaultService.setTestSecret('TEST_VAULT_SECRET_2026');
    });

    test('ChatService.isCouncilOrAdminRole fails closed for default Student fallback', () {
      expect(ChatService.isCouncilOrAdminRole('student', 'Student', null), isFalse);
      expect(ChatService.isCouncilOrAdminRole('teacher', 'Ms. Smith', '40001'), isTrue);
    });

    test('Batch 1 O44: HierarchyService and ensureSchoolMemberRecord prevent role escalation', () async {
      expect(
        HierarchyService.getRoleDisplayTitle(scholarNo: '2310910', role: 'student'),
        equals('Student Member'),
      );
      expect(
        HierarchyService.getRoleDisplayTitle(scholarNo: '11209', role: 'student'),
        equals('Super Admin'),
      );

      final auth = AuthService();
      final teacherRecord = await auth.ensureSchoolMemberRecord(
        uid: 'teacher_uid_1',
        profile: {
          'scholar_no': '49001',
          'full_name': 'Ms. Rao',
          'house_name': 'ruby',
          'role': 'teacher',
          'status': 'suspended',
        },
      );
      expect(teacherRecord['role'], equals('teacher'));
      expect(teacherRecord['active'], isFalse);
      expect(teacherRecord['capabilities']['manage_elections'], isTrue);
    });

    test('Batch 1 O06: AuthService.clearCache scrubs scoped and prefixed keys', () async {
      SharedPreferences.setMockInitialValues({
        'cached_medical_leaves_list': '[{"id":"ml1"}]',
        'cached_school_notices_list': '[{"id":"n1"}]',
        'cached_timetable_10A_Monday': '[]',
        'saved_wallet_orders_12345': '[]',
        'asb_ai_chat_history': '[{"text":"secret"}]',
      });
      await AuthService.initPreferences();
      await AuthService.clearCache();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_medical_leaves_list'), isNull);
      expect(prefs.getString('cached_school_notices_list'), isNull);
      expect(prefs.getString('cached_timetable_10A_Monday'), isNull);
      expect(prefs.getString('saved_wallet_orders_12345'), isNull);
      expect(prefs.getString('asb_ai_chat_history'), isNull);
    });

    testWidgets('Batch 1 O04: HomeScreen locks suspended accounts with Sign Out', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.initPreferences();
      await AuthService.cacheProfile({
        'uid': 'susp_uid',
        'scholar_no': '41009',
        'full_name': 'Suspended Student',
        'house_name': 'ruby',
        'role': 'student',
        'status': 'suspended',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(mockNow: DateTime(2026, 11, 27, 9, 0)),
        ),
      );
      await tester.pump();

      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    test('Batch 1 O07: NotificationService sets source_id fallback and sender_name', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.initPreferences();
      final payload = NotificationService.buildNotificationPayload(
        title: 'Class Update',
        body: 'Test body',
        type: 'class_announcement',
        category: 'class',
        dedupeKey: 'class_10A_hw_1',
        senderId: 'rep_uid',
        senderName: 'Class Rep',
      );
      expect(payload['source_id'], equals('class_10A_hw_1'));
      expect(payload['sender_name'], equals('Class Rep'));
    });

    test('Election vote accepts candidate whose id equals scholarNo without false not-on-ballot rejection', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.initPreferences();
      final candidate = ElectionCandidate(
        id: '2310910',
        scholarNo: '2310910',
        fullName: 'Aarav Sharma',
        houseName: 'ruby',
        runningPosition: 'House Captain',
        manifesto: 'Unity and effort',
      );
      final res = await AuthService().castDigitalVote(
        ballotId: 'poll_same_id_test',
        ballotTitle: 'House Captain Election',
        candidate: candidate,
        scholarNo: '99887',
      );
      expect(res.success, isTrue);
      expect(res.error, isNull);
    });

    testWidgets('Upgraded House Standings tab renders hero card, podium, and standings cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.initPreferences();
      await AuthService.cacheHouseStandings({
        'ruby': 320,
        'emerald': 290,
        'sapphire': 210,
        'topaz': 180,
      });
      await AuthService.cacheProfile({
        'uid': 'stud_1',
        'scholar_no': '45120',
        'full_name': 'Nadia Ali',
        'house_name': 'emerald',
        'role': 'student',
        'status': 'active',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(mockNow: DateTime(2026, 11, 27, 9, 0)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.emoji_events_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🏆 Live House Standings'), findsOneWidget);
      expect(find.text('School Total'), findsOneWidget);
      expect(find.text('House Leaderboard'), findsOneWidget);
      expect(find.text('House Arena'), findsOneWidget);
      expect(find.text('YOUR HOUSE'), findsOneWidget);
    });
  });
}
