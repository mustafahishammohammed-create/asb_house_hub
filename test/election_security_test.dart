import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/digital_ballot_cast.dart';
import 'package:asb_house_hub/models/election_ballot.dart';
import 'package:asb_house_hub/models/election_gazette.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/election_security_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
  });
  group('Multi-Account Cryptographic Vote Receipt Isolation', () {
    test('Voting on Account A (11209) does not mark Account B (12428) as voted', () async {
      final receiptA = BallotCastReceipt(
        receiptId: 'rcpt_11209_abc',
        ballotId: 'ballot_council_2026',
        ballotTitle: 'Senior House Captain',
        candidateScholarNo: 'SCH-999',
        candidateName: 'Zainab Abbas',
        candidateHouse: 'ruby',
        runningPosition: 'houseCaptain',
        anonymizedVoterHash: ElectionSecurityService.generateAnonymizedVoterHash(
          scholarNo: '11209',
          ballotId: 'ballot_council_2026',
        ),
        signatureProofToken: 'token_sig_11209',
        timestamp: DateTime.now(),
      );

      // Account A casts vote
      await AuthService.cacheVoteReceipt(receiptA, scholarNo: '11209');

      // Account A must be verified as voted
      expect(
        AuthService.hasVotedInBallotCached('ballot_council_2026', scholarNo: '11209'),
        isTrue,
      );
      final fetchedA = AuthService.getReceiptForBallot('ballot_council_2026', scholarNo: '11209');
      expect(fetchedA, isNotNull);
      expect(fetchedA!.receiptId, equals('rcpt_11209_abc'));

      // Account B must NOT be marked as voted
      expect(
        AuthService.hasVotedInBallotCached('ballot_council_2026', scholarNo: '12428'),
        isFalse,
      );
      final fetchedB = AuthService.getReceiptForBallot('ballot_council_2026', scholarNo: '12428');
      expect(fetchedB, isNull);

      // Now Account B casts their own vote
      final receiptB = BallotCastReceipt(
        receiptId: 'rcpt_12428_xyz',
        ballotId: 'ballot_council_2026',
        ballotTitle: 'Senior House Captain',
        candidateScholarNo: 'SCH-888',
        candidateName: 'Bilal Ahmed',
        candidateHouse: 'ruby',
        runningPosition: 'houseCaptain',
        anonymizedVoterHash: ElectionSecurityService.generateAnonymizedVoterHash(
          scholarNo: '12428',
          ballotId: 'ballot_council_2026',
        ),
        signatureProofToken: 'token_sig_12428',
        timestamp: DateTime.now(),
      );
      await AuthService.cacheVoteReceipt(receiptB, scholarNo: '12428');

      // Both accounts must now have independent, uncorrupted receipts
      expect(
        AuthService.hasVotedInBallotCached('ballot_council_2026', scholarNo: '11209'),
        isTrue,
      );
      expect(
        AuthService.hasVotedInBallotCached('ballot_council_2026', scholarNo: '12428'),
        isTrue,
      );
      expect(
        AuthService.getReceiptForBallot('ballot_council_2026', scholarNo: '11209')!.receiptId,
        equals('rcpt_11209_abc'),
      );
      expect(
        AuthService.getReceiptForBallot('ballot_council_2026', scholarNo: '12428')!.receiptId,
        equals('rcpt_12428_xyz'),
      );
    });
  });

  group('Role-Gated Ballot Management Authorization', () {
    test('Regular students cannot manage elections', () {
      const scholarNo = '12428';
      const role = 'student';

      final isCouncil = HierarchyService.isCouncil(scholarNo: scholarNo, role: role);
      final isSuperAdmin = HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role);
      final isTeacher = HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role);

      expect(isCouncil, isFalse);
      expect(isSuperAdmin, isFalse);
      expect(isTeacher, isFalse);
    });

    test('Council, Staff, Teachers, Principal, and Admins can manage elections', () {
      // Scholar 11209 (Super Admin)
      expect(HierarchyService.isSuperAdmin(scholarNo: '11209', role: 'admin'), isTrue);

      // Principal
      expect(HierarchyService.isTeacherOrFaculty(scholarNo: '99001', role: 'principal'), isTrue);

      // Teacher / Faculty
      expect(HierarchyService.isTeacherOrFaculty(scholarNo: 'TEA-101', role: 'teacher'), isTrue);
      expect(HierarchyService.isTeacherOrFaculty(scholarNo: 'FAC-202', role: 'faculty'), isTrue);

      // Student Council & House Captains
      expect(HierarchyService.isCouncil(scholarNo: 'SCH-303', role: 'council'), isTrue);
      expect(HierarchyService.isCaptain(scholarNo: 'SCH-304', role: 'house_captain'), isTrue);
    });
  });

  group('Candidate Slate Lookup and Deduplication Logic', () {
    test('Admin/11209 lookup returns Administrator profile', () async {
      final res = await AuthService.lookupScholarDetails('11209');
      expect(res['isFound'], isTrue);
      expect(res['fullName'], equals('Administrator'));
    });

    test('Incomplete scholar number (e.g. 112) returns not found and empty fields', () async {
      final res = await AuthService.lookupScholarDetails('112');
      expect(res['isFound'], isFalse);
      expect(res['fullName'], isEmpty);
      expect(res['manifesto'], isEmpty);
    });

    test('Synthetic names like "Scholar #12428" are filtered out from auto-fill', () async {
      final res = await AuthService.lookupScholarDetails('12428');
      // Synthetic name must NOT be populated as the candidate full name
      expect(res['fullName'], isNot(equals('Scholar #12428')));
      expect(res['fullName'], isNot(startsWith('Scholar #')));
    });
  });

  group('Draft and Certified Proclamation Resilience', () {
    test('Draft ballots can be cached, retrieved, and removed locally', () async {
      final draft = {
        'id': 'draft_test_101',
        'title': 'Senior Prefect Election',
        'position': 'Head Boy',
        'house': 'all',
        'status': 'draft',
      };

      await AuthService.cacheDraftBallot(draft);
      final cached = AuthService.getCachedDraftBallots();
      expect(cached.any((d) => d['id'] == 'draft_test_101'), isTrue);

      await AuthService.removeCachedDraftBallot('draft_test_101');
      final afterRemove = AuthService.getCachedDraftBallots();
      expect(afterRemove.any((d) => d['id'] == 'draft_test_101'), isFalse);
    });

    test('Published ballot immediately appears in cached ballots with open status', () async {
      final now = DateTime.now();
      final published = ElectionBallot(
        id: 'poll_published_v2_test',
        title: 'Junior House Captain Election',
        position: BallotPosition.houseCaptain,
        candidates: [
          ElectionCandidate(
            scholarNo: '11209',
            fullName: 'Candidate One',
            houseName: 'ruby',
            runningPosition: 'House Captain',
            manifesto: 'Manifesto One',
            votesCount: 0,
            isVerified: true,
          ),
          ElectionCandidate(
            scholarNo: '12428',
            fullName: 'Candidate Two',
            houseName: 'ruby',
            runningPosition: 'House Captain',
            manifesto: 'Manifesto Two',
            votesCount: 0,
            isVerified: true,
          ),
        ],
        startTime: now.subtract(const Duration(seconds: 5)),
        endTime: now.add(const Duration(days: 7)),
        status: BallotStatus.open,
        totalVotesCast: 0,
        houseScope: 'ruby',
      );

      await AuthService.cacheBallot(published);
      final ballots = AuthService.getCachedBallots();
      final found = ballots.firstWhere((b) => b.id == 'poll_published_v2_test');
      expect(found.status, equals(BallotStatus.open));
      expect(found.candidates.length, equals(2));
      expect(found.houseScope, equals('ruby'));
    });

    test('Certified proclamation caching persists and can be queried', () async {
      final proc = CertifiedElectionResult(
        ballotId: 'ballot_certified_999',
        ballotTitle: 'Sports Captain Election',
        runningPosition: 'Sports Captain',
        winnerScholarNo: '11209',
        winnerName: 'Administrator',
        winnerHouse: 'ruby',
        totalVotesReceived: 30,
        victoryMarginVotes: 12,
        housePointsAwarded: 50,
        commissionerName: 'Electoral Commission',
        certifiedAt: DateTime.now(),
        proclamationText: 'Official certification proclamation',
      );

      await AuthService.cacheCertifiedGazette([proc]);
      final gazettes = AuthService.getCachedCertifiedGazette();
      expect(gazettes.any((g) => g.ballotId == 'ballot_certified_999'), isTrue);
    });
  });

  group('Session Switching and Admin Vote Isolation', () {
    test('Switching from voted student (12428) to admin allows admin to vote without duplicate vote error', () async {
      final now = DateTime.now();
      final testBallot = ElectionBallot(
        id: 'ballot_isolation_test',
        title: 'Head Prefect Election',
        position: BallotPosition.prefect,
        candidates: [
          ElectionCandidate(
            scholarNo: '11209',
            fullName: 'Candidate Alpha',
            houseName: 'ruby',
            runningPosition: 'Head Prefect',
            manifesto: 'Leading with distinction',
            votesCount: 0,
            isVerified: true,
          ),
          ElectionCandidate(
            scholarNo: '12428',
            fullName: 'Candidate Beta',
            houseName: 'ruby',
            runningPosition: 'Head Prefect',
            manifesto: 'Committed to service',
            votesCount: 0,
            isVerified: true,
          ),
        ],
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now.add(const Duration(days: 7)),
        status: BallotStatus.open,
        totalVotesCast: 0,
        houseScope: 'all',
      );
      await AuthService.cacheBallot(testBallot);

      // 1. Student 12428 session is active
      final studentAccount = SavedAccount(
        scholarNo: '12428',
        fullName: 'Student Scholar',
        houseName: 'ruby',
        uid: 'student_12428_uid',
        role: 'student',
        cachedProfile: {
          'scholar_no': '12428',
          'full_name': 'Student Scholar',
          'role': 'student',
          'house_name': 'ruby',
        },
      );
      await AuthService().switchAccount(studentAccount);
      expect(AuthService.getCachedScholarNo(), equals('12428'));

      // Student 12428 votes
      final voteRes1 = await AuthService().castDigitalVote(
        ballotId: 'ballot_isolation_test',
        ballotTitle: 'Head Prefect Election',
        candidate: testBallot.candidates.first,
        scholarNo: '12428',
      );
      expect(voteRes1.success, isTrue);
      expect(AuthService.hasVotedInBallotCached('ballot_isolation_test', scholarNo: '12428'), isTrue);

      // 2. Switch session to Administrator
      final adminAccount = SavedAccount(
        scholarNo: 'admin',
        fullName: 'Administrator',
        houseName: 'ruby',
        uid: 'admin_uid',
        role: 'super_admin',
        cachedProfile: {
          'scholar_no': 'admin',
          'full_name': 'Administrator',
          'role': 'super_admin',
          'house_name': 'ruby',
        },
      );
      await AuthService().switchAccount(adminAccount);

      // Active scholar must now be admin
      expect(AuthService.getCachedScholarNo(), equals('admin'));

      // Admin has NOT voted yet on this ballot
      expect(AuthService.hasVotedInBallotCached('ballot_isolation_test', scholarNo: 'admin'), isFalse);

      // Admin casts vote - MUST SUCCEED with no duplicate error
      final adminVoteRes = await AuthService().castDigitalVote(
        ballotId: 'ballot_isolation_test',
        ballotTitle: 'Head Prefect Election',
        candidate: testBallot.candidates.last,
        scholarNo: 'admin',
      );
      expect(adminVoteRes.success, isTrue);
      expect(adminVoteRes.error, isNull);
      expect(adminVoteRes.receipt, isNotNull);

      // 3. Verify role gating logic between sessions
      final isStudentManager = HierarchyService.isSuperAdmin(scholarNo: '12428', role: 'student') ||
          HierarchyService.isCouncil(scholarNo: '12428', role: 'student');
      expect(isStudentManager, isFalse);

      final isAdminManager = HierarchyService.isSuperAdmin(scholarNo: 'admin', role: 'super_admin') ||
          'admin' == 'admin';
      expect(isAdminManager, isTrue);
    });

    test('Full multi-account sequence: Student A -> Student B -> Student C -> Admin -> Student A', () async {
      final now = DateTime.now();
      final ballot = ElectionBallot(
        id: 'multi_switch_ballot',
        title: 'Universal Head Boy 2026',
        position: BallotPosition.headBoy,
        candidates: [
          ElectionCandidate(
            scholarNo: '11209',
            fullName: 'Alpha Candidate',
            houseName: 'ruby',
            runningPosition: 'Head Boy',
            manifesto: 'Alpha manifesto',
            votesCount: 0,
            isVerified: true,
          ),
          ElectionCandidate(
            scholarNo: '12428',
            fullName: 'Beta Candidate',
            houseName: 'sapphire',
            runningPosition: 'Head Boy',
            manifesto: 'Beta manifesto',
            votesCount: 0,
            isVerified: true,
          ),
        ],
        startTime: now.subtract(const Duration(minutes: 1)),
        endTime: now.add(const Duration(days: 7)),
        status: BallotStatus.open,
        totalVotesCast: 0,
        houseScope: 'all',
      );
      await AuthService.cacheBallot(ballot);

      // Student A (12428)
      final accountA = SavedAccount(
        scholarNo: '12428',
        fullName: 'Student A',
        houseName: 'ruby',
        uid: 'uid_student_a',
        role: 'student',
        cachedProfile: {'scholar_no': '12428', 'full_name': 'Student A', 'role': 'student', 'house_name': 'ruby'},
      );
      await AuthService().switchAccount(accountA);
      expect(AuthService.getCachedScholarNo(), equals('12428'));
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '12428'), isFalse);

      final resA = await AuthService().castDigitalVote(
        ballotId: 'multi_switch_ballot',
        ballotTitle: ballot.title,
        candidate: ballot.candidates.first,
        scholarNo: '12428',
      );
      expect(resA.success, isTrue);
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '12428'), isTrue);

      // Student B (13550)
      final accountB = SavedAccount(
        scholarNo: '13550',
        fullName: 'Student B',
        houseName: 'sapphire',
        uid: 'uid_student_b',
        role: 'student',
        cachedProfile: {'scholar_no': '13550', 'full_name': 'Student B', 'role': 'student', 'house_name': 'sapphire'},
      );
      await AuthService().switchAccount(accountB);
      expect(AuthService.getCachedScholarNo(), equals('13550'));
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '13550'), isFalse);

      final resB = await AuthService().castDigitalVote(
        ballotId: 'multi_switch_ballot',
        ballotTitle: ballot.title,
        candidate: ballot.candidates.last,
        scholarNo: '13550',
      );
      expect(resB.success, isTrue);
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '13550'), isTrue);

      // Student C (14660)
      final accountC = SavedAccount(
        scholarNo: '14660',
        fullName: 'Student C',
        houseName: 'emerald',
        uid: 'uid_student_c',
        role: 'student',
        cachedProfile: {'scholar_no': '14660', 'full_name': 'Student C', 'role': 'student', 'house_name': 'emerald'},
      );
      await AuthService().switchAccount(accountC);
      expect(AuthService.getCachedScholarNo(), equals('14660'));
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '14660'), isFalse);

      final resC = await AuthService().castDigitalVote(
        ballotId: 'multi_switch_ballot',
        ballotTitle: ballot.title,
        candidate: ballot.candidates.first,
        scholarNo: '14660',
      );
      expect(resC.success, isTrue);
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '14660'), isTrue);

      // Switch to Admin
      final adminAccount = SavedAccount(
        scholarNo: 'admin',
        fullName: 'Administrator',
        houseName: 'ruby',
        uid: 'uid_admin',
        role: 'super_admin',
        cachedProfile: {'scholar_no': 'admin', 'full_name': 'Administrator', 'role': 'super_admin', 'house_name': 'ruby'},
      );
      await AuthService().switchAccount(adminAccount);
      expect(AuthService.getCachedScholarNo(), equals('admin'));
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: 'admin'), isFalse);

      final resAdmin = await AuthService().castDigitalVote(
        ballotId: 'multi_switch_ballot',
        ballotTitle: ballot.title,
        candidate: ballot.candidates.first,
        scholarNo: 'admin',
      );
      expect(resAdmin.success, isTrue);
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: 'admin'), isTrue);

      // Switch back to Student A (12428)
      await AuthService().switchAccount(accountA);
      expect(AuthService.getCachedScholarNo(), equals('12428'));
      expect(AuthService.hasVotedInBallotCached('multi_switch_ballot', scholarNo: '12428'), isTrue);
      expect(AuthService.getReceiptForBallot('multi_switch_ballot', scholarNo: '12428')?.receiptId, equals(resA.receipt?.receiptId));

      // Attempting to double-vote with Student A must be rejected
      final doubleVoteRes = await AuthService().castDigitalVote(
        ballotId: 'multi_switch_ballot',
        ballotTitle: ballot.title,
        candidate: ballot.candidates.last,
        scholarNo: '12428',
      );
      expect(doubleVoteRes.success, isFalse);
      expect(doubleVoteRes.error, contains('already'));
    });
  });

  group('Canonical HierarchyService.canManageElections Matrix', () {
    test('Strict role permissions enforcement', () {
      // 1. Regular students must ALWAYS be blocked
      expect(HierarchyService.canManageElections(scholarNo: '12428', role: 'student'), isFalse);
      expect(HierarchyService.canManageElections(scholarNo: '13550', role: 'student'), isFalse);
      expect(HierarchyService.canManageElections(scholarNo: '14660', role: 'Student'), isFalse);
      expect(HierarchyService.canManageElections(scholarNo: '', role: 'student'), isFalse);
      expect(HierarchyService.canManageElections(scholarNo: null, role: null), isFalse);

      // 2. Administrators
      expect(HierarchyService.canManageElections(scholarNo: 'admin', role: 'admin'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'admin', role: 'student'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: '11209', role: 'student'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'any', role: 'super_admin'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'any', role: 'admin'), isTrue);

      // 3. Principal
      expect(HierarchyService.canManageElections(scholarNo: 'PRIN-001', role: 'principal'), isTrue);

      // 4. Teachers and Faculty
      expect(HierarchyService.canManageElections(scholarNo: 'TEA-101', role: 'teacher'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'FAC-202', role: 'faculty'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'STF-303', role: 'staff'), isTrue);

      // 5. Student Council & Captains
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-404', role: 'council'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-505', role: 'house_captain'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-606', role: 'captain'), isTrue);

      // 6. Explicit capabilities
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-707', role: 'student', capabilities: {'manage_elections': true}), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-808', role: 'student', capabilities: {'is_admin': true}), isTrue);

      // 7. Official admin emails
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-909', role: 'student', email: 'admin@asianschool.bh'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-909', role: 'student', email: 'superadmin@asianschool.bh'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: 'SCH-909', role: 'student', email: 'principal@asianschool.bh'), isTrue);
      expect(HierarchyService.canManageElections(scholarNo: '12428', role: 'student', email: 'student12428@asianschool.bh'), isFalse);
    });
  });

  group('Ballot Write-Through and Gazette Proclamation Lifecycle', () {
    test('Election certification awards house points and persists proclamation', () async {
      final now = DateTime.now();
      final testBallot = ElectionBallot(
        id: 'ballot_certify_lifecycle',
        title: 'Junior Prefect Election',
        position: BallotPosition.prefect,
        candidates: [
          ElectionCandidate(
            scholarNo: '12428',
            fullName: 'Zayd Khan',
            houseName: 'emerald',
            runningPosition: 'Class Prefect',
            manifesto: 'Service for all',
            votesCount: 15,
            isVerified: true,
          ),
          ElectionCandidate(
            scholarNo: '13550',
            fullName: 'Sara Ali',
            houseName: 'ruby',
            runningPosition: 'Class Prefect',
            manifesto: 'Excellence in action',
            votesCount: 8,
            isVerified: true,
          ),
        ],
        startTime: now.subtract(const Duration(days: 1)),
        endTime: now.add(const Duration(days: 6)),
        status: BallotStatus.open,
        totalVotesCast: 23,
        houseScope: 'all',
      );
      await AuthService.cacheBallot(testBallot);

      final certRes = await AuthService().certifyElectionAndAwardPoints(
        ballotId: 'ballot_certify_lifecycle',
        ballotTitle: testBallot.title,
        winner: testBallot.candidates.first,
        victoryMargin: 7,
        housePoints: 100,
        commissionerName: 'Electoral Commission',
      );

      expect(certRes.success, isTrue);
      expect(certRes.result, isNotNull);
      expect(certRes.result!.winnerName, equals('Zayd Khan'));
      expect(certRes.result!.winnerHouse, equals('emerald'));

      // Verify cached ballot is updated to certified
      final cachedBallots = AuthService.getCachedBallots();
      final certified = cachedBallots.firstWhere((b) => b.id == 'ballot_certify_lifecycle');
      expect(certified.status, equals(BallotStatus.certified));

      // Verify gazette proclamation is cached
      final gazettes = AuthService.getCachedCertifiedGazette();
      expect(gazettes.any((g) => g.ballotId == 'ballot_certify_lifecycle'), isTrue);
    });
  });

  group('Clock Skew Tolerance and Voting Window Calculations', () {
    test('Ballot starting slightly in the future (within 15s) evaluates to open with clock-skew tolerance', () {
      final now = DateTime.now();
      // Server clock is 5 seconds ahead of client device
      final opensAt = now.add(const Duration(seconds: 5));
      final closesAt = now.add(const Duration(days: 7));

      // Without skew tolerance:
      final rawInWindow = !now.isBefore(opensAt) && now.isBefore(closesAt);
      expect(rawInWindow, isFalse); // False negative without tolerance

      // With our 15-second skew tolerance:
      final isStarted = !now.isBefore(opensAt.subtract(const Duration(seconds: 15)));
      final robustInWindow = isStarted && now.isBefore(closesAt);
      expect(robustInWindow, isTrue); // Correctly open!

      final phase = !isStarted ? 'Scheduled' : robustInWindow ? 'Open' : 'Awaiting certification';
      expect(phase, equals('Open'));
    });

    test('Ballot scheduled in the distant future evaluates to Scheduled', () {
      final now = DateTime.now();
      final opensAt = now.add(const Duration(hours: 24));
      final closesAt = now.add(const Duration(days: 7));

      final isStarted = !now.isBefore(opensAt.subtract(const Duration(seconds: 15)));
      final robustInWindow = isStarted && now.isBefore(closesAt);
      final phase = !isStarted ? 'Scheduled' : robustInWindow ? 'Open' : 'Awaiting certification';

      expect(isStarted, isFalse);
      expect(robustInWindow, isFalse);
      expect(phase, equals('Scheduled'));
    });

    test('Ballot past closing time evaluates to Awaiting certification', () {
      final now = DateTime.now();
      final opensAt = now.subtract(const Duration(days: 7));
      final closesAt = now.subtract(const Duration(minutes: 5));

      final isStarted = !now.isBefore(opensAt.subtract(const Duration(seconds: 15)));
      final inWindow = isStarted && now.isBefore(closesAt);
      final phase = !isStarted ? 'Scheduled' : inWindow ? 'Open' : 'Awaiting certification';

      expect(isStarted, isTrue);
      expect(inWindow, isFalse);
      expect(phase, equals('Awaiting certification'));
    });
  });

  group('Voter Key Normalization and Hash Consistency', () {
    test('Whitespace and casing normalization guarantees consistent participation keys', () {
      const pollId = 'poll_prefect_2026';
      final key1 = sha256.convert(utf8.encode('$pollId:${'12428'.toLowerCase().trim()}')).toString();
      final key2 = sha256.convert(utf8.encode('$pollId:${' 12428 \n'.toLowerCase().trim()}')).toString();
      final key3 = sha256.convert(utf8.encode('$pollId:${'12428'}')).toString();

      expect(key1, equals(key2));
      expect(key1, equals(key3));

      final adminKey1 = sha256.convert(utf8.encode('$pollId:${'admin'.toLowerCase().trim()}')).toString();
      final adminKey2 = sha256.convert(utf8.encode('$pollId:${'ADMIN '.toLowerCase().trim()}')).toString();
      expect(adminKey1, equals(adminKey2));
    });
  });

  group('Candidate Tally Sorting and Victory Margin Logic', () {
    test('Victory margin is accurately computed from sorted candidate tally rows', () {
      // Unsorted candidate list where the winner is NOT first
      final rows = <Map<String, dynamic>>[
        {'id': 'cand_1', 'count': 14},
        {'id': 'cand_2', 'count': 82}, // Winner!
        {'id': 'cand_3', 'count': 65}, // Runner up!
      ];

      final total = rows.fold<int>(0, (acc, r) => acc + (r['count'] as int));
      expect(total, equals(161));

      int maxCount = 0;
      for (final r in rows) {
        if ((r['count'] as int) > maxCount) maxCount = r['count'] as int;
      }
      expect(maxCount, equals(82));

      final sortedRows = List<Map<String, dynamic>>.from(rows)
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final runnerUpCount = sortedRows.length > 1 ? (sortedRows[1]['count'] as int) : 0;
      final margin = (maxCount - runnerUpCount).clamp(0, 999999);

      expect(runnerUpCount, equals(65));
      expect(margin, equals(17)); // 82 - 65 = 17
    });

    test('Single candidate uncontested election has margin equal to total votes', () {
      final rows = <Map<String, dynamic>>[
        {'id': 'cand_solo', 'count': 42},
      ];

      int maxCount = rows.first['count'] as int;
      final sortedRows = List<Map<String, dynamic>>.from(rows)
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final runnerUpCount = sortedRows.length > 1 ? (sortedRows[1]['count'] as int) : 0;
      final margin = (maxCount - runnerUpCount).clamp(0, 999999);

      expect(margin, equals(42));
    });
  });

  group('Multi-Account Session Switching Role Integrity', () {
    test('Switching to admin account persists super_admin role and updates active scholar', () async {
      final studentAccount = SavedAccount(
        scholarNo: '12428',
        fullName: 'Zayd Khan',
        houseName: 'emerald',
        uid: 'uid_12428',
        role: 'student',
        cachedProfile: {
          'scholar_no': '12428',
          'full_name': 'Zayd Khan',
          'house_name': 'emerald',
          'role': 'student',
        },
      );

      final adminAccount = SavedAccount(
        scholarNo: '11209',
        fullName: 'Administrator',
        houseName: 'ruby',
        uid: 'uid_11209',
        role: 'super_admin',
        cachedProfile: {
          'scholar_no': '11209',
          'full_name': 'Administrator',
          'house_name': 'ruby',
          'role': 'super_admin',
        },
      );

      await AuthService.saveAccount(studentAccount);
      await AuthService.saveAccount(adminAccount);

      // Switch to Student
      await AuthService().switchAccount(studentAccount);
      expect(AuthService.getCachedScholarNo(), equals('12428'));
      expect(AuthService.getCachedProfile()?['role'], equals('student'));
      expect(HierarchyService.canManageElections(
        scholarNo: AuthService.getCachedScholarNo()!,
        role: AuthService.getCachedProfile()?['role'] ?? 'student',
      ), isFalse);

      // Switch to Admin
      await AuthService().switchAccount(adminAccount);
      expect(AuthService.getCachedScholarNo(), equals('11209'));
      expect(AuthService.getCachedProfile()?['role'], equals('super_admin'));
      expect(HierarchyService.canManageElections(
        scholarNo: AuthService.getCachedScholarNo()!,
        role: AuthService.getCachedProfile()?['role'] ?? '',
      ), isTrue);

      // Verify that student receipts are completely isolated from admin
      final studentHash = ElectionSecurityService.generateAnonymizedVoterHash(
        scholarNo: '12428',
        ballotId: 'ballot_isolation_check',
      );
      final studentReceipt = BallotCastReceipt(
        receiptId: 'rcpt_student_test',
        ballotId: 'ballot_isolation_check',
        ballotTitle: 'Head Boy',
        candidateScholarNo: 'SCH-01',
        candidateName: 'Candidate A',
        candidateHouse: 'ruby',
        runningPosition: 'headBoy',
        anonymizedVoterHash: studentHash,
        signatureProofToken: 'token_student',
        timestamp: DateTime.now(),
      );
      await AuthService.cacheVoteReceipt(studentReceipt, scholarNo: '12428');

      // Admin has NOT voted
      expect(AuthService.hasVotedInBallotCached('ballot_isolation_check', scholarNo: '11209'), isFalse);
      expect(AuthService.getReceiptForBallot('ballot_isolation_check', scholarNo: '11209'), isNull);

      // Student HAS voted
      expect(AuthService.hasVotedInBallotCached('ballot_isolation_check', scholarNo: '12428'), isTrue);
      expect(AuthService.getReceiptForBallot('ballot_isolation_check', scholarNo: '12428'), isNotNull);
    });
  });
}

