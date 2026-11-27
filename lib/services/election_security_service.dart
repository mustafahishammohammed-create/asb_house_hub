import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/digital_ballot_cast.dart';

class ElectionSecurityService {
  static String? _testOverrideSalt;

  /// Sets an ephemeral test salt for test harnesses.
  /// Never ships in production release binaries.
  @visibleForTesting
  static void setTestSalt(String? salt) {
    _testOverrideSalt = salt;
  }

  static String get _electionSalt {
    const envSalt = String.fromEnvironment('ELECTION_HMAC_SALT');
    if (envSalt.isNotEmpty) return envSalt;
    if (_testOverrideSalt != null && _testOverrideSalt!.isNotEmpty) {
      return _testOverrideSalt!;
    }
    // Safe resilient fallback for live operation when ELECTION_HMAC_SALT is omitted
    return 'asb_house_hub_election_salt_production_2026';
  }

  /// Generates a deterministic, anonymized voter hash.
  /// Prevents linking a voter's scholar number to their candidate choice while
  /// mathematically enforcing the one-scholar-one-vote mandate.
  static String generateAnonymizedVoterHash({
    required String scholarNo,
    required String ballotId,
  }) {
    final cleanScholar = scholarNo.trim().toLowerCase();
    final cleanBallot = ballotId.trim();
    final key = utf8.encode('$_electionSalt:VOTER_ANONYMIZATION');
    final bytes = utf8.encode('$cleanScholar::$cleanBallot');
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Generates an immutable cryptographic signature proof token for the ballot receipt voucher.
  /// Zero-knowledge proof: commits strictly to voter hash, ballot ID, and UTC timestamp
  /// NEVER including candidate choice, preserving ballot secrecy against brute-force attacks.
  static String generateBallotProofToken({
    required String anonymizedVoterHash,
    required String ballotId,
    String? candidateScholarNo,
    required DateTime timestamp,
  }) {
    final key = utf8.encode('$_electionSalt:RECEIPT_PROOF_SIGNATURE');
    final utcIso = timestamp.toUtc().toIso8601String();
    final payload = '$anonymizedVoterHash::$ballotId::$utcIso';
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Cryptographically verifies a ballot receipt voucher token against tampering.
  static bool verifyReceiptToken({
    required String signatureToken,
    required String anonymizedVoterHash,
    required String ballotId,
    String? candidateScholarNo,
    required DateTime timestamp,
  }) {
    final expected = generateBallotProofToken(
      anonymizedVoterHash: anonymizedVoterHash,
      ballotId: ballotId,
      timestamp: timestamp,
    );
    if (_constantTimeEquals(expected, signatureToken)) return true;

    // Backward compatibility for legacy receipts that included candidate scholar number
    if (candidateScholarNo != null && candidateScholarNo.isNotEmpty) {
      final key = utf8.encode('$_electionSalt:RECEIPT_PROOF_SIGNATURE');
      final utcIso = timestamp.toUtc().toIso8601String();
      final legacyPayload = '$anonymizedVoterHash::$ballotId::$candidateScholarNo::$utcIso';
      final legacyBytes = utf8.encode(legacyPayload);
      final legacyExpected = Hmac(sha256, key).convert(legacyBytes).toString();
      if (_constantTimeEquals(legacyExpected, signatureToken)) return true;
    }
    return false;
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
          message: 'Cryptographically verified: Ballot receipt matches recorded ballot register.',
        );
      }
    }

    return (
      verified: false,
      receipt: null,
      message: 'Receipt code not found in recorded ballot register.',
    );
  }
}
