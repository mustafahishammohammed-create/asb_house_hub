import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/services/sports_security_service.dart';
import 'package:asb_house_hub/models/sports_tournament.dart';
import 'package:asb_house_hub/models/player_sports_stats.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/models/election_gazette.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';

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
      expect(res.isDemo, isTrue);
      expect(AuthService.getCachedHouseStandings()['ruby'], equals(30));
    });
  });

  group('P1 Audit F-1 & G8: Nonce Consumption, Replay Rejection & Format Hardening', () {
    setUp(() {
      GamificationSecurityService.setTestSecret('TEST_KEY_2026');
      GamificationSecurityService.resetConsumedNoncesForTesting();
    });

    test('Raw JSON token string is rejected without fallback (format hardening)', () {
      const rawJson = '{"scholar_no":"11209","activity_id":"quiz","points":20,"nonce":"abc"}';
      final result = GamificationSecurityService.verifyScoreProofToken(
        token: rawJson,
        expectedScholarNo: '11209',
        expectedActivityId: 'quiz',
      );

      expect(result.isValid, isFalse);
      expect(result.isTampered, isTrue);
      expect(result.error, contains('Invalid token encoding'));
    });

    test('Consumed nonce rejects token replay within sliding window', () async {
      final token = GamificationSecurityService.generateScoreProofToken(
        scholarNo: '11209',
        activityId: 'blitz_quiz',
        points: 25,
      );

      // First verification succeeds
      final firstCheck = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '11209',
        expectedActivityId: 'blitz_quiz',
      );
      expect(firstCheck.isValid, isTrue);
      expect(firstCheck.nonce, isNotNull);

      // Consume the nonce
      await GamificationSecurityService.consumeNonce(firstCheck.nonce!);

      // Second verification of same token must be rejected as replay
      final secondCheck = GamificationSecurityService.verifyScoreProofToken(
        token: token,
        expectedScholarNo: '11209',
        expectedActivityId: 'blitz_quiz',
      );
      expect(secondCheck.isValid, isFalse);
      expect(secondCheck.isTampered, isTrue);
      expect(secondCheck.error, contains('replay detected'));
    });
  });

  group('P1 Audit G6: Clock Rollback Fail-Closed Cooldown Protection', () {
    setUp(() async {
      await GamificationSecurityService.clearCooldowns();
    });

    test('canParticipateDaily fails closed when client clock is rolled back into past', () async {
      final baseTime = DateTime(2026, 11, 7, 12, 0);
      await GamificationSecurityService.recordActivityCompletion('11209', 'daily_math', baseTime);

      // Normal future: within 24h -> disallowed
      final checkFuture = GamificationSecurityService.canParticipateDaily(
        '11209',
        'daily_math',
        now: baseTime.add(const Duration(hours: 2)),
      );
      expect(checkFuture.allowed, isFalse);

      // Manipulated clock: rolled back 5 hours prior to recorded completion
      final rolledBackTime = baseTime.subtract(const Duration(hours: 5));
      final checkRollback = GamificationSecurityService.canParticipateDaily(
        '11209',
        'daily_math',
        now: rolledBackTime,
      );
      expect(checkRollback.allowed, isFalse);
      expect(checkRollback.formattedRemaining, contains('Clock rollback detected'));
    });

    test('checkRapidFireThrottle fails closed when client clock is rolled back', () async {
      final baseTime = DateTime(2026, 11, 7, 12, 0);
      await GamificationSecurityService.recordSubmissionAttempt('11209', baseTime);

      // Rolled back 10 seconds into past
      final rolledBack = baseTime.subtract(const Duration(seconds: 10));
      final check = GamificationSecurityService.checkRapidFireThrottle(
        '11209',
        now: rolledBack,
      );
      expect(check.allowed, isFalse);
      expect(check.formattedRemaining, contains('Clock rollback detected'));
    });
  });

  group('P1 Audit F-2 & G11: Content-Derived Trophy Award Idempotency', () {
    setUp(() {
      GamificationSecurityService.setTestSecret('TEST_KEY_2026');
      SportsSecurityService.setTestSalt('SPORTS_SALT_2026');
    });

    test('Repeated award submission for same tournament, sport, and houses is rejected', () async {
      final authService = AuthService();
      await AuthService.cacheSportsTrophies([]);

      // First award
      final res1 = await authService.awardChampionshipTrophyAndPoints(
        tournamentTitle: 'Annual Football Gala 2026',
        sportType: SportType.football,
        winningHouse: 'emerald',
        runnerUpHouse: 'topaz',
        pointsAwarded: 100,
        runnerUpPoints: 50,
        commissionerName: 'Sports Director',
        adminScholarNo: '11209',
        adminRole: 'super_admin',
      );
      expect(res1.success, isTrue);
      expect(res1.record?.trophyId, contains('trophy_football_annual_football_gala_2026_emerald_topaz_'));

      // Duplicate award attempt with same tournament and houses
      final res2 = await authService.awardChampionshipTrophyAndPoints(
        tournamentTitle: 'Annual Football Gala 2026',
        sportType: SportType.football,
        winningHouse: 'emerald',
        runnerUpHouse: 'topaz',
        pointsAwarded: 100,
        runnerUpPoints: 50,
        commissionerName: 'Sports Director',
        adminScholarNo: '11209',
        adminRole: 'super_admin',
      );
      expect(res2.success, isFalse);
      expect(res2.error, contains('already been awarded'));
    });
  });

  group('R1 Council Privileges & G4 Academic Grading Gate', () {
    test('HierarchyService.canGradeAcademics grants staff and council, rejects students and prefects', () {
      // Super Admin
      expect(HierarchyService.canGradeAcademics(scholarNo: '11209', role: 'student'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'super_admin'), isTrue);

      // Staff / Faculty
      expect(HierarchyService.canGradeAcademics(role: 'teacher'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'faculty'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'principal'), isTrue);

      // Executive Council (R1)
      expect(HierarchyService.canGradeAcademics(role: 'council'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'head_boy'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'head_girl'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'deputy_head_boy'), isTrue);
      expect(HierarchyService.canGradeAcademics(role: 'cultural_secretary'), isTrue);

      // Regular Student (strictly rejected)
      expect(HierarchyService.canGradeAcademics(scholarNo: '99999', role: 'student'), isFalse);

      // Prefect (not authorized to grade unilaterally)
      expect(HierarchyService.canGradeAcademics(scholarNo: '99999', role: 'prefect'), isFalse);
    });

    test('updateAssignmentStatus blocks regular student from transitioning assignment to graded', () async {
      await AuthService.cacheProfile({
        'scholar_no': '12345',
        'role': 'student',
        'house_name': 'ruby',
        'full_name': 'Test Student',
      });

      final authService = AuthService();
      final success = await authService.updateAssignmentStatus(
        assignmentId: 'assign_math_1',
        newStatus: AssignmentStatus.graded,
        scholarNo: '12345',
        pointsReward: 20,
      );

      // Must be rejected
      expect(success, isFalse);
    });

    test('updateAssignmentStatus allows council officer to transition assignment to graded', () async {
      GamificationSecurityService.setTestSecret('TEST_KEY_2026');
      await AuthService.cacheProfile({
        'scholar_no': '11209',
        'role': 'head_boy',
        'house_name': 'ruby',
        'full_name': 'Test Head Boy',
      });

      final authService = AuthService();
      final success = await authService.updateAssignmentStatus(
        assignmentId: 'assign_math_2',
        newStatus: AssignmentStatus.graded,
        scholarNo: '11209',
        pointsReward: 20,
      );

      // Must succeed
      expect(success, isTrue);
    });

    test('cacheCertifiedGazette deduplicates duplicate ballotId proclamations', () async {
      final now = DateTime.now();
      final p1 = CertifiedElectionResult(
        ballotId: 'ballot_dup_1',
        ballotTitle: 'Title 1',
        runningPosition: 'Captain',
        winnerScholarNo: '11209',
        winnerName: 'Winner A',
        winnerHouse: 'ruby',
        winnerAvatarUrl: '',
        totalVotesReceived: 50,
        victoryMarginVotes: 10,
        housePointsAwarded: 100,
        commissionerName: 'Returning Officer',
        certifiedAt: now,
        proclamationText: 'Official Proclamation 1',
      );
      final p2 = CertifiedElectionResult(
        ballotId: 'ballot_dup_1', // Duplicate ID
        ballotTitle: 'Title 1 Duplicate',
        runningPosition: 'Captain',
        winnerScholarNo: '11209',
        winnerName: 'Winner A',
        winnerHouse: 'ruby',
        winnerAvatarUrl: '',
        totalVotesReceived: 50,
        victoryMarginVotes: 10,
        housePointsAwarded: 100,
        commissionerName: 'Returning Officer',
        certifiedAt: now,
        proclamationText: 'Official Proclamation 2',
      );

      await AuthService.cacheCertifiedGazette([p1, p2]);
      final cached = AuthService.getCachedCertifiedGazette();
      final matching = cached.where((c) => c.ballotId == 'ballot_dup_1').toList();
      expect(matching.length, equals(1));
    });

    test('migrateLegacyContributorDocs runs without crashing when empty', () async {
      final count = await AuthService.migrateLegacyContributorDocs();
      expect(count, isNonNegative);
    });
  });
}
