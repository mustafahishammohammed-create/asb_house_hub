import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/sports_tournament.dart';
import 'package:asb_house_hub/models/sports_trophy.dart';
import 'package:asb_house_hub/screens/merch_store_tab.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/voucher_security_service.dart';

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
  });
}
