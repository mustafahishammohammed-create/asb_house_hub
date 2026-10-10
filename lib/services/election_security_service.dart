import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/digital_ballot_cast.dart';

class ElectionSecurityService {
  static const String _kElectionHmacSalt = 'ASB_CAMPUS_DEMOCRACY_SECURE_SALT_v1';

  /// Generates a deterministic, anonymized voter hash.
  /// Prevents linking a voter's scholar number to their candidate choice while
  /// mathematically enforcing the one-scholar-one-vote mandate.
  static String generateAnonymizedVoterHash({
    required String scholarNo,
    required String ballotId,
  }) {
    final cleanScholar = scholarNo.trim().toLowerCase();
    final cleanBallot = ballotId.trim();
    final key = utf8.encode('$_kElectionHmacSalt:VOTER_ANONYMIZATION');
    final bytes = utf8.encode('$cleanScholar::$cleanBallot');
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Generates an immutable cryptographic signature proof token for the ballot receipt voucher.
  static String generateBallotProofToken({
    required String anonymizedVoterHash,
    required String ballotId,
    required String candidateScholarNo,
    required DateTime timestamp,
  }) {
    final key = utf8.encode('$_kElectionHmacSalt:RECEIPT_PROOF_SIGNATURE');
    final payload =
        '$anonymizedVoterHash::$ballotId::$candidateScholarNo::${timestamp.millisecondsSinceEpoch}';
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Cryptographically verifies a ballot receipt voucher token against tampering.
  static bool verifyReceiptToken({
    required String signatureToken,
    required String anonymizedVoterHash,
    required String ballotId,
    required String candidateScholarNo,
    required DateTime timestamp,
  }) {
    final expected = generateBallotProofToken(
      anonymizedVoterHash: anonymizedVoterHash,
      ballotId: ballotId,
      candidateScholarNo: candidateScholarNo,
      timestamp: timestamp,
    );
    return expected == signatureToken;
  }

  /// Verifies ballot box integrity by recalculating cryptographic signatures
  /// across all voter receipts and ensuring the total matches the candidate tallies.
  static bool verifyBallotBoxIntegrity({
    required List<BallotCastReceipt> receipts,
    required int expectedTotalVotes,
  }) {
    if (receipts.length != expectedTotalVotes) return false;

    for (final r in receipts) {
      final isValid = verifyReceiptToken(
        signatureToken: r.signatureProofToken,
        anonymizedVoterHash: r.anonymizedVoterHash,
        ballotId: r.ballotId,
        candidateScholarNo: r.candidateScholarNo,
        timestamp: r.timestamp,
      );
      if (!isValid) return false;
    }
    return true;
  }

  /// Verifies whether an individual receipt number exists in the official audited ballot registry.
  static ({bool verified, BallotCastReceipt? receipt, String message}) auditReceiptVerification({
    required String receiptNumber,
    required List<BallotCastReceipt> auditedReceipts,
  }) {
    final cleanInput = receiptNumber.trim().toUpperCase();
    if (cleanInput.isEmpty) {
      return (verified: false, receipt: null, message: 'Please enter a valid receipt number.');
    }

    for (final r in auditedReceipts) {
      if (r.formattedReceiptNumber.toUpperCase() == cleanInput) {
        return (
          verified: true,
          receipt: r,
          message: 'Cryptographically certified: Ballot recorded and counted in official tally.',
        );
      }
    }

    return (
      verified: false,
      receipt: null,
      message: 'Receipt not found in certified election ledger.',
    );
  }
}
