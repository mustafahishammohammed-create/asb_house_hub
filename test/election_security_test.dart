import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/digital_ballot_cast.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/election_security_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Account Cryptographic Vote Receipt Isolation', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

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
}
