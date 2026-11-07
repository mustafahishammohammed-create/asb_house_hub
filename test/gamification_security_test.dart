import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/services/sports_security_service.dart';
import 'package:asb_house_hub/models/sports_tournament.dart';
import 'package:asb_house_hub/models/player_sports_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    await GamificationSecurityService.initPreferences();
    await GamificationSecurityService.clearCooldowns();
  });

  group('P0 Audit G2: Fail-Closed Secrets & Tamper-Proof Cryptography', () {
    test('GamificationSecurityService throws StateError when secret is missing', () {
      GamificationSecurityService.setTestSecret(null);
      expect(
        () => GamificationSecurityService.generateSignature(
          scholarNo: '11209',
          activityId: 'blitz_quiz',
          pointsEarned: 20,
          timestampMillis: DateTime.now().millisecondsSinceEpoch,
          nonce: 'test_nonce',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('SportsSecurityService throws StateError when salt is missing', () {
      SportsSecurityService.setTestSalt(null);
      expect(
        () => SportsSecurityService.generateMatchCertificationToken(
          fixtureId: 'fix_1',
          sportType: 'football',
          houseA: 'ruby',
          houseB: 'sapphire',
          scoreA: 2,
          scoreB: 1,
          refereeScholarNo: '11209',
          timestamp: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Gamification tokens verify and detect altered payloads with constant-time compare', () {
      GamificationSecurityService.setTestSecret('TEST_KEY_2026');
      final token = GamificationSecurityService.generateScoreProofToken(
        scholarNo: '11209',
        activityId: 'blitz_quiz',
        points: 25,
      );

      final validResult = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '11209',
        expectedActivityId: 'blitz_quiz',
      );
      expect(validResult.isValid, isTrue);
      expect(validResult.points, equals(25));

      // Scholar number mismatch
      final mismatchResult = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '99999',
        expectedActivityId: 'blitz_quiz',
      );
      expect(mismatchResult.isValid, isFalse);
    });

    test('Sports certification tokens verify accurately and detect score tampering', () {
      SportsSecurityService.setTestSalt('SPORTS_SALT_2026');
      final now = DateTime.now();
      final token = SportsSecurityService.generateMatchCertificationToken(
        fixtureId: 'fix_championship',
        sportType: 'basketball',
        houseA: 'ruby',
        houseB: 'emerald',
        scoreA: 55,
        scoreB: 50,
        refereeScholarNo: '11209',
        timestamp: now,
      );

      final verified = SportsSecurityService.verifyMatchCertificationToken(
        token: token,
        fixtureId: 'fix_championship',
        sportType: 'basketball',
        houseA: 'ruby',
        houseB: 'emerald',
        scoreA: 55,
        scoreB: 50,
        refereeScholarNo: '11209',
        timestamp: now,
      );
      expect(verified, isTrue);

      // Tampered score
      final tampered = SportsSecurityService.verifyMatchCertificationToken(
        token: token,
        fixtureId: 'fix_championship',
        sportType: 'basketball',
        houseA: 'ruby',
        houseB: 'emerald',
        scoreA: 56, // Tampered
        scoreB: 50,
        refereeScholarNo: '11209',
        timestamp: now,
      );
      expect(tampered, isFalse);
    });
  });

  group('P0 Audit G1, G3, G9: Truthful Outcomes & Bounded Ceilings', () {
    setUp(() {
      GamificationSecurityService.setTestSecret('TEST_KEY_2026');
      SportsSecurityService.setTestSalt('SPORTS_SALT_2026');
    });

    test('awardChampionshipTrophyAndPoints clamps points awarded to documented ceilings', () async {
      final authService = AuthService();
      final res = await authService.awardChampionshipTrophyAndPoints(
        tournamentTitle: 'Inter-House Super Cup',
        sportType: SportType.football,
        winningHouse: 'ruby',
        runnerUpHouse: 'sapphire',
        pointsAwarded: 999999, // Attempted inflation
        runnerUpPoints: 999999,
        commissionerName: 'Administrator',
        adminScholarNo: '11209',
        adminRole: 'super_admin',
      );

      expect(res.success, isTrue);
      expect(res.record?.pointsAwarded, equals(100)); // Clamped to 100
      expect(res.record?.runnerUpPoints, equals(50)); // Clamped to 50
    });

    test('awardPlayerAccoladeCustom clamps meritPoints to max ceiling of 50', () async {
      final authService = AuthService();
      final success = await authService.awardPlayerAccoladeCustom(
        scholarNo: '12428',
        studentName: 'Zaid Test',
        houseName: 'emerald',
        sportType: SportType.football,
        accoladeType: SportAccoladeType.matchMvp,
        goals: 3,
        meritPoints: 500, // Attempted inflation
      );

      expect(success, isTrue);
      final cachedStandings = AuthService.getCachedHouseStandings();
      expect(cachedStandings['emerald'], equals(50)); // Clamped to 50
    });

    test('awardVerifiedGamificationPoints offline/unit test path honors token and updates cache', () async {
      final token = GamificationSecurityService.generateScoreProofToken(
        scholarNo: '11209',
        activityId: 'stem_challenge',
        points: 30,
      );

      final res = await AuthService().awardVerifiedGamificationPoints(
        scholarNo: '11209',
        activityId: 'stem_challenge',
        house: 'ruby',
        token: token,
      );

      expect(res.success, isTrue);
      expect(res.pointsAwarded, equals(30));
      expect(AuthService.getCachedHouseStandings()['ruby'], equals(30));
    });
  });
}
